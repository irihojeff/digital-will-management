-- ================================================
-- Procedure: assign_asset_to_beneficiary
-- Purpose: Assigns a beneficiary to an asset with share % and conditions
-- Validates: asset existence, beneficiary existence, will status, and share cap
-- ================================================

CREATE OR REPLACE PROCEDURE assign_asset_to_beneficiary (
    p_asset_id         IN NUMBER,
    p_beneficiary_id   IN NUMBER,
    p_share_percent    IN NUMBER,
    p_conditions       IN VARCHAR2 DEFAULT NULL
) IS
    v_asset_exists       NUMBER;
    v_beneficiary_exists NUMBER;
    v_total_share        NUMBER;
    v_will_status        VARCHAR2(20);
    v_will_id            NUMBER;
    
    -- Procedure for audit logging with autonomous transaction
    PROCEDURE log_audit(
        p_action IN VARCHAR2,
        p_table IN VARCHAR2,
        p_old_values IN VARCHAR2,
        p_new_values IN VARCHAR2,
        p_status IN VARCHAR2
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO audit_log (
            user_name, action, action_table, record_id,
            old_values, new_values, status, ip_address
        ) VALUES (
            SYS_CONTEXT('USERENV', 'SESSION_USER'),
            p_action, p_table, NULL,
            p_old_values, p_new_values, p_status,
            SYS_CONTEXT('USERENV', 'IP_ADDRESS')
        );
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            -- Silently fail as this is just logging
    END log_audit;
    
BEGIN
    -- Check asset and get will_id
    SELECT COUNT(*), MAX(will_id)
    INTO v_asset_exists, v_will_id
    FROM assets
    WHERE asset_id = p_asset_id;
    
    IF v_asset_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-21001, 'Asset ID ' || p_asset_id || ' does not exist.');
    END IF;
    
    -- Check beneficiary exists
    SELECT COUNT(*) INTO v_beneficiary_exists
    FROM beneficiaries
    WHERE beneficiary_id = p_beneficiary_id;
    
    IF v_beneficiary_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-21002, 'Beneficiary ID ' || p_beneficiary_id || ' does not exist.');
    END IF;
    
    -- Check will is not Executed
    SELECT status INTO v_will_status
    FROM wills
    WHERE will_id = v_will_id;
    
    IF v_will_status = 'Executed' THEN
        RAISE_APPLICATION_ERROR(-21003, 'Cannot assign asset. Will already executed.');
    END IF;
    
    -- Validate share logic
    SELECT NVL(SUM(share_percent), 0)
    INTO v_total_share
    FROM will_asset_beneficiaries
    WHERE asset_id = p_asset_id;
    
    IF v_total_share + p_share_percent > 100 THEN
        RAISE_APPLICATION_ERROR(-21004,
            'Total share for asset ID ' || p_asset_id || 
            ' exceeds 100%. Current total: ' || v_total_share || '%');
    END IF;
    
    -- Insert assignment
    INSERT INTO will_asset_beneficiaries (
        asset_id, beneficiary_id, share_percent, conditions
    ) VALUES (
        p_asset_id, p_beneficiary_id, p_share_percent, p_conditions
    );
    
    DBMS_OUTPUT.PUT_LINE('Asset assigned to beneficiary successfully.');
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log error using autonomous transaction
        log_audit(
            'PROCEDURE', 
            'WILL_ASSET_BENEFICIARIES', 
            'assign_asset_to_beneficiary failed',
            SQLERRM, 
            'ERROR'
        );
        RAISE;
END;
/


-- ================================================
-- Procedure: approve_will
-- Purpose: Sets will status to 'Approved' after verifying executor presence
-- Logs status in will_status_history and handles errors with audit logging
-- ================================================

CREATE OR REPLACE PROCEDURE approve_will (
    p_will_id IN NUMBER
)
IS
    v_will_exists     NUMBER;
    v_executor_count  NUMBER;
    v_primary_count   NUMBER;
    v_old_status      VARCHAR2(20);
    v_incomplete_assets NUMBER;
    v_user            VARCHAR2(100);
    
    -- Audit subprocedure
    PROCEDURE log_audit(
        p_action IN VARCHAR2,
        p_table IN VARCHAR2,
        p_old_values IN VARCHAR2,
        p_new_values IN VARCHAR2,
        p_status IN VARCHAR2
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO audit_log (
            user_name, action, action_table, record_id,
            old_values, new_values, status, ip_address
        ) VALUES (
            v_user,
            p_action, p_table, p_will_id,
            p_old_values, p_new_values, p_status,
            SYS_CONTEXT('USERENV', 'IP_ADDRESS')
        );
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
    END log_audit;
    
    -- Status history update procedure
    PROCEDURE update_status_history(
        p_old_status IN VARCHAR2,
        p_new_status IN VARCHAR2
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO will_status_history (
            will_id,
            old_status,
            new_status,
            changed_by,
            change_date,
            reason
        ) VALUES (
            p_will_id,
            p_old_status,
            p_new_status,
            v_user,
            SYSDATE,
            'Will approved via approve_will procedure'
        );
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            log_audit(
                'PROCEDURE', 
                'WILL_STATUS_HISTORY', 
                'Failed to update status history',
                SQLERRM, 
                'ERROR'
            );
    END update_status_history;
    
BEGIN
    -- Get user for logging
    v_user := SYS_CONTEXT('USERENV', 'SESSION_USER');

    -- Ensure will exists and get current status
    SELECT COUNT(*), MAX(status)
    INTO v_will_exists, v_old_status
    FROM wills
    WHERE will_id = p_will_id;
    
    IF v_will_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-22001, 'Will ID ' || p_will_id || ' does not exist.');
    END IF;
    
    -- Only allow if current status is Draft
    IF v_old_status != 'Draft' THEN
        RAISE_APPLICATION_ERROR(-22002, 'Only Draft wills can be approved. Current status: ' || v_old_status);
    END IF;
    
    -- Check for at least one executor
    SELECT COUNT(*) INTO v_executor_count
    FROM executors
    WHERE will_id = p_will_id;
    
    IF v_executor_count = 0 THEN
        RAISE_APPLICATION_ERROR(-22003, 'Cannot approve will without at least one executor.');
    END IF;
    
    -- Check for primary executor
    SELECT COUNT(*) INTO v_primary_count
    FROM executors
    WHERE will_id = p_will_id AND is_primary = 'Y';
    
    IF v_primary_count = 0 THEN
        RAISE_APPLICATION_ERROR(-22004, 'Cannot approve will without a primary executor.');
    END IF;
    
    -- Check if all assets are fully allocated (or close to it)
    SELECT COUNT(*) INTO v_incomplete_assets
    FROM assets a
    WHERE a.will_id = p_will_id
    AND 90 > (  -- Using 90% as threshold, adjust as needed
        SELECT NVL(SUM(share_percent), 0)
        FROM will_asset_beneficiaries
        WHERE asset_id = a.asset_id
    );
    
    IF v_incomplete_assets > 0 THEN
        RAISE_APPLICATION_ERROR(-22005, 
            v_incomplete_assets || ' assets have less than 90% allocation. Please review asset allocations before approval.');
    END IF;
    
    -- Start transaction
    SAVEPOINT before_approval;
    
    BEGIN
        -- Update status
        UPDATE wills
        SET status = 'Approved',
            last_updated_at = SYSDATE
        WHERE will_id = p_will_id;
        
        -- Add status history record
        update_status_history(v_old_status, 'Approved');
        
        -- Log the successful update
        log_audit(
            'PROCEDURE',
            'WILLS',
            '{"status":"' || v_old_status || '"}',
            '{"status":"Approved"}',
            'SUCCESS'
        );
        
        DBMS_OUTPUT.PUT_LINE('Will approved successfully.');
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO before_approval;
            log_audit(
                'PROCEDURE',
                'WILLS',
                'approve_will failed while updating status',
                SQLERRM,
                'ERROR'
            );
            RAISE;
    END;
    
EXCEPTION
    WHEN OTHERS THEN
        log_audit(
            'PROCEDURE',
            'WILLS',
            'approve_will failed with error',
            SQLERRM,
            'ERROR'
        );
        RAISE;
END;
/




-- ================================================
-- Procedure: transfer_asset
-- Purpose: Registers a transfer record if valid
-- Tied to triggers that block transfer on weekends/holidays
-- ================================================

CREATE OR REPLACE PROCEDURE transfer_asset (
    p_asset_id        IN NUMBER,
    p_beneficiary_id  IN NUMBER
)
IS
    v_user              VARCHAR2(100);
    v_ip                VARCHAR2(20);
    v_asset_exists      NUMBER;
    v_beneficiary_exists NUMBER;
    v_is_linked         NUMBER;
    v_will_status       VARCHAR2(20);
    v_will_id           NUMBER;
    v_transfer_status   VARCHAR2(20) := 'Initiated';
    v_duplicate_count   NUMBER;
    v_asset_name        VARCHAR2(200);
    -- We'll use a generic beneficiary identifier instead of trying to get the actual name
    v_beneficiary_ref   VARCHAR2(200);
    
    -- Audit helper
    PROCEDURE log_audit(
        p_action IN VARCHAR2,
        p_table IN VARCHAR2,
        p_old_values IN VARCHAR2,
        p_new_values IN VARCHAR2,
        p_status IN VARCHAR2
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO audit_log (
            user_name, action, action_table, record_id,
            old_values, new_values, status, ip_address
        ) VALUES (
            v_user, p_action, p_table, NULL,
            p_old_values, p_new_values, p_status, v_ip
        );
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            -- Silently continue as this is just logging
    END log_audit;
    
BEGIN
    -- Get context
    v_user := SYS_CONTEXT('USERENV', 'SESSION_USER');
    v_ip := SYS_CONTEXT('USERENV', 'IP_ADDRESS');
    
    -- Create a generic beneficiary reference
    v_beneficiary_ref := 'Beneficiary #' || p_beneficiary_id;
    
    -- Validate asset
    SELECT COUNT(*), MAX(will_id), MAX(description)
    INTO v_asset_exists, v_will_id, v_asset_name
    FROM assets
    WHERE asset_id = p_asset_id;
    
    IF v_asset_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-23001, 'Asset ID ' || p_asset_id || ' does not exist.');
    END IF;
    
    -- Validate beneficiary - Simplified to avoid column name issues
    SELECT COUNT(*) INTO v_beneficiary_exists
    FROM beneficiaries
    WHERE beneficiary_id = p_beneficiary_id;
    
    IF v_beneficiary_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-23002, 'Beneficiary ID ' || p_beneficiary_id || ' does not exist.');
    END IF;
    
    -- Validate linkage between asset and beneficiary in will
    SELECT COUNT(*) INTO v_is_linked
    FROM will_asset_beneficiaries
    WHERE asset_id = p_asset_id
      AND beneficiary_id = p_beneficiary_id;
    
    IF v_is_linked = 0 THEN
        RAISE_APPLICATION_ERROR(-23003, 'This beneficiary is not assigned to this asset.');
    END IF;
    
    -- Check will status
    SELECT status INTO v_will_status
    FROM wills
    WHERE will_id = v_will_id;
    
    IF v_will_status NOT IN ('Approved', 'Executing') THEN
        RAISE_APPLICATION_ERROR(-23004, 'Cannot transfer asset unless will is Approved or Executing. Current status: ' || v_will_status);
    END IF;
    
    -- Check for duplicate transfer
    SELECT COUNT(*) INTO v_duplicate_count
    FROM transfer_logs
    WHERE asset_id = p_asset_id
    AND beneficiary_id = p_beneficiary_id
    AND transfer_status = 'Completed';
    
    IF v_duplicate_count > 0 THEN
        RAISE_APPLICATION_ERROR(-23005, 'This transfer has already been completed.');
    END IF;
    
    -- Create a savepoint for transaction control
    SAVEPOINT before_transfer;
    
    BEGIN
        -- Insert transfer log
        INSERT INTO transfer_logs (
            asset_id, 
            beneficiary_id, 
            transfer_date, 
            approved_by, 
            transfer_status, 
            notes
        ) VALUES (
            p_asset_id, 
            p_beneficiary_id, 
            SYSDATE, 
            v_user, 
            v_transfer_status, 
            'Transfer initiated by ' || v_user || ' on ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS')
        );
        
        -- Update will status to Executing if currently Approved
        IF v_will_status = 'Approved' THEN
            UPDATE wills
            SET status = 'Executing',
                last_updated_at = SYSDATE
            WHERE will_id = v_will_id;
            
            -- Add status history record
            INSERT INTO will_status_history (
                will_id,
                old_status,
                new_status,
                changed_by,
                change_date,
                reason
            ) VALUES (
                v_will_id,
                'Approved',
                'Executing',
                v_user,
                SYSDATE,
                'Automatically changed due to asset transfer initiation'
            );
        END IF;
        
        -- Log the successful action
        log_audit(
            'INSERT',
            'TRANSFER_LOGS',
            NULL,
            'Transfer from asset ' || p_asset_id || ' (' || v_asset_name || ') to ' || v_beneficiary_ref,
            'SUCCESS'
        );
        
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Transfer initiated successfully for asset: ' || v_asset_name || 
                            ' to ' || v_beneficiary_ref);
    EXCEPTION
        WHEN OTHERS THEN
            -- Roll back to savepoint
            ROLLBACK TO before_transfer;
            
            -- Log the error
            log_audit(
                'PROCEDURE',
                'TRANSFER_LOGS',
                'transfer_asset failed during execution',
                SQLERRM,
                'ERROR'
            );
            RAISE;
    END;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log any other errors
        log_audit(
            'PROCEDURE',
            'TRANSFER_LOGS',
            'transfer_asset failed with error',
            SQLERRM,
            'ERROR'
        );
        RAISE;
END;
/


-- ================================================
-- Procedure: add_document
-- Purpose: Attaches a document to a will or asset
-- ================================================

CREATE OR REPLACE PROCEDURE add_document (
    p_related_entity IN VARCHAR2,
    p_entity_id      IN NUMBER,
    p_title          IN VARCHAR2,
    p_description    IN VARCHAR2 DEFAULT NULL,
    p_file_path      IN VARCHAR2,
    p_file_type      IN VARCHAR2
)
IS
    v_user VARCHAR2(100) := SYS_CONTEXT('USERENV', 'SESSION_USER');
    v_ip   VARCHAR2(20)  := SYS_CONTEXT('USERENV', 'IP_ADDRESS');
    v_valid_entity NUMBER := 0; -- Changed from BOOLEAN to NUMBER
    v_entity_type VARCHAR2(20);
    -- Audit helper
    PROCEDURE log_audit(
        p_action IN VARCHAR2,
        p_table IN VARCHAR2,
        p_old_values IN VARCHAR2,
        p_new_values IN VARCHAR2,
        p_status IN VARCHAR2
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO audit_log (
            user_name, action, action_table, record_id,
            old_values, new_values, status, ip_address
        ) VALUES (
            v_user, p_action, 'DOCUMENTS', NULL,
            p_old_values, p_new_values, p_status, v_ip
        );
        COMMIT;
    END log_audit;
BEGIN
    -- Normalize entity input
    v_entity_type := UPPER(TRIM(p_related_entity));
    
    -- Validate entity type and ID
    IF v_entity_type = 'WILL' THEN
        SELECT COUNT(*) -- Changed the query to directly return a count
        INTO v_valid_entity
        FROM wills
        WHERE will_id = p_entity_id;
    ELSIF v_entity_type = 'ASSET' THEN
        SELECT COUNT(*) -- Changed the query to directly return a count
        INTO v_valid_entity
        FROM assets
        WHERE asset_id = p_entity_id;
    ELSE
        RAISE_APPLICATION_ERROR(-24001, 'Invalid related_entity: ' || p_related_entity || '. Use ''WILL'' or ''ASSET''.');
    END IF;
    
    IF v_valid_entity = 0 THEN -- Changed from boolean comparison to number comparison
        RAISE_APPLICATION_ERROR(-24002, 'Entity ID ' || p_entity_id || ' does not exist for ' || v_entity_type);
    END IF;
    
    -- Insert the document
    INSERT INTO documents (
        related_entity,
        entity_id,
        title,
        description,
        file_path,
        file_type,
        upload_date
    ) VALUES (
        v_entity_type,
        p_entity_id,
        p_title,
        p_description,
        p_file_path,
        p_file_type,
        SYSDATE
    );
    
    log_audit(
        'INSERT',
        'DOCUMENTS',
        NULL,
        'Added document "' || p_title || '" to ' || v_entity_type || ' ID ' || p_entity_id,
        'SUCCESS'
    );
    
    COMMIT; -- Added explicit commit
    
    DBMS_OUTPUT.PUT_LINE('Document successfully linked to ' || v_entity_type || ' ID ' || p_entity_id);
EXCEPTION
    WHEN OTHERS THEN
        log_audit(
            'PROCEDURE',
            'DOCUMENTS',
            'add_document failed',
            SQLERRM,
            'ERROR'
        );
        ROLLBACK; -- Added explicit rollback
        RAISE;
END;
/


-- ================================================
-- Procedure: set_primary_executor
-- Purpose: Makes one executor primary and unsets others for the same will
-- Version: 2.0
-- Last Modified: 2025-05-18
-- ================================================

CREATE OR REPLACE PROCEDURE set_primary_executor (
    p_executor_id IN NUMBER
)
IS
    v_user         VARCHAR2(100) := SYS_CONTEXT('USERENV', 'SESSION_USER');
    v_ip           VARCHAR2(20)  := SYS_CONTEXT('USERENV', 'IP_ADDRESS');
    v_will_id      NUMBER;
    v_exec_exists  NUMBER;
    v_rows_updated NUMBER;
    v_current_primary NUMBER;
    
    -- Audit helper
    PROCEDURE log_audit(
        p_action IN VARCHAR2,
        p_table IN VARCHAR2,
        p_old_values IN VARCHAR2,
        p_new_values IN VARCHAR2,
        p_status IN VARCHAR2,
        p_record_id IN NUMBER DEFAULT NULL
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        v_record_id NUMBER := NVL(p_record_id, p_executor_id);
    BEGIN
        INSERT INTO audit_log (
            user_name, action, action_table, record_id,
            old_values, new_values, status, ip_address
        ) VALUES (
            v_user, p_action, p_table, v_record_id,
            p_old_values, p_new_values, p_status, v_ip
        );
        COMMIT;
    END log_audit;

BEGIN
    -- Input validation
    IF p_executor_id IS NULL THEN
        RAISE_APPLICATION_ERROR(-25000, 'Executor ID cannot be null.');
    END IF;
    
    -- Verify executor exists and get will_id
    SELECT COUNT(*), MAX(will_id)
    INTO v_exec_exists, v_will_id
    FROM executors
    WHERE executor_id = p_executor_id;

    IF v_exec_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-25001, 'Executor ID ' || p_executor_id || ' does not exist.');
    END IF;
    
    -- Get current primary executor for the will
    v_current_primary := NULL;
    BEGIN
        SELECT executor_id 
        INTO v_current_primary
        FROM executors
        WHERE will_id = v_will_id AND is_primary = 'Y'
        AND ROWNUM = 1; -- Adding ROWNUM to avoid TOO_MANY_ROWS exception
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_current_primary := NULL;
    END;
    
    -- Check if multiple primary executors exist (data inconsistency)
    DECLARE
        v_primary_count NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO v_primary_count
        FROM executors
        WHERE will_id = v_will_id AND is_primary = 'Y';
        
        IF v_primary_count > 1 THEN
            -- Fix data inconsistency: more than one primary executor exists
            UPDATE executors
            SET is_primary = 'N'
            WHERE will_id = v_will_id;
            
            log_audit(
                'DATA_FIX',
                'EXECUTORS',
                'Multiple primary executors found for will ' || v_will_id,
                'Reset all to non-primary',
                'SUCCESS',
                v_will_id
            );
            
            v_current_primary := NULL;
        END IF;
    END;

    -- Create savepoint for rollback safety
    SAVEPOINT before_primary;

    BEGIN
        -- Unset all other primary executors for the same will
        UPDATE executors
        SET is_primary = 'N'
        WHERE will_id = v_will_id
        AND is_primary = 'Y';
        
        v_rows_updated := SQL%ROWCOUNT;

        -- Set the specified executor as primary
        UPDATE executors
        SET is_primary = 'Y'
        WHERE executor_id = p_executor_id
        AND (is_primary IS NULL OR is_primary = 'N');
        
        -- Audit the change with detailed information
        log_audit(
            'UPDATE',
            'EXECUTORS',
            CASE 
                WHEN v_current_primary IS NOT NULL THEN 
                    'Previous primary executor: ID ' || v_current_primary
                ELSE 
                    'No previous primary executor'
            END,
            'Set executor ' || p_executor_id || ' as primary for will ' || v_will_id,
            'SUCCESS'
        );

        DBMS_OUTPUT.PUT_LINE('Executor ' || p_executor_id || ' set as primary for will ' || v_will_id);
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO before_primary;
            log_audit(
                'PROCEDURE',
                'EXECUTORS',
                'set_primary_executor failed during updates',
                'Error: ' || SQLERRM || ' for executor ID ' || p_executor_id,
                'ERROR'
            );
            RAISE;
    END;

EXCEPTION
    WHEN OTHERS THEN
        log_audit(
            'PROCEDURE',
            'EXECUTORS',
            'set_primary_executor failed at top level',
            'Error: ' || SQLERRM || ' for executor ID ' || p_executor_id,
            'ERROR'
        );
        RAISE;
END;
/


-- ================================================
-- Procedure: delete_draft_will
-- Purpose: Deletes a will and all related records if status is 'Draft'
-- Version: 2.0
-- Last Modified: 2025-05-18
-- ================================================
CREATE OR REPLACE PROCEDURE delete_draft_will (
    p_will_id       IN NUMBER,
    p_force_delete  IN BOOLEAN DEFAULT FALSE,
    p_confirm_text  IN VARCHAR2 DEFAULT NULL
)
IS
    v_user            VARCHAR2(100) := SYS_CONTEXT('USERENV', 'SESSION_USER');
    v_ip              VARCHAR2(20)  := SYS_CONTEXT('USERENV', 'IP_ADDRESS');
    v_status          VARCHAR2(20);
    v_exists          NUMBER;
    v_asset_count     NUMBER;
    v_executor_count  NUMBER;
    v_beneficiary_count NUMBER;
    v_doc_count       NUMBER;
    v_deleted_rows    NUMBER := 0;
    v_confirm_required VARCHAR2(20) := 'DELETE-CONFIRM';
    
    -- Audit helper with enhanced details
    PROCEDURE log_audit(
        p_action     IN VARCHAR2,
        p_table      IN VARCHAR2,
        p_old_values IN VARCHAR2,
        p_new_values IN VARCHAR2,
        p_status     IN VARCHAR2,
        p_record_id  IN NUMBER DEFAULT p_will_id
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO audit_log (
            user_name, action, action_table, record_id,
            old_values, new_values, status, ip_address
        ) VALUES (
            v_user, p_action, p_table, p_record_id,
            p_old_values, p_new_values, p_status, v_ip
        );
        COMMIT;
    END log_audit;
    
    -- Helper to track deletion counts
    PROCEDURE delete_and_track(
        p_table_name IN VARCHAR2,
        p_where_clause IN VARCHAR2
    ) IS
        v_sql VARCHAR2(1000);
        v_deleted NUMBER;
    BEGIN
        v_sql := 'DELETE FROM ' || p_table_name || ' WHERE ' || p_where_clause;
        EXECUTE IMMEDIATE v_sql;
        v_deleted := SQL%ROWCOUNT;
        v_deleted_rows := v_deleted_rows + v_deleted;
        
        log_audit(
            'DELETE',
            p_table_name,
            'Deleted ' || v_deleted || ' rows',
            'Condition: ' || p_where_clause,
            'SUCCESS'
        );
    END delete_and_track;

BEGIN
    -- Input validation
    IF p_will_id IS NULL THEN
        RAISE_APPLICATION_ERROR(-26000, 'Will ID cannot be NULL.');
    END IF;

    -- Check existence and get status
    BEGIN
        SELECT status
        INTO v_status
        FROM wills
        WHERE will_id = p_will_id;
        
        v_exists := 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_exists := 0;
            RAISE_APPLICATION_ERROR(-26001, 'Will ID ' || p_will_id || ' does not exist.');
    END;
    
    -- Only allow delete for Draft status unless forced
    IF v_status != 'Draft' AND NOT p_force_delete THEN
        RAISE_APPLICATION_ERROR(-26002, 'Only Draft wills can be deleted. Current status: ' || v_status);
    END IF;
    
    -- For non-draft wills, require confirmation text
    IF v_status != 'Draft' AND p_force_delete THEN
        IF p_confirm_text IS NULL OR p_confirm_text != v_confirm_required THEN
            RAISE_APPLICATION_ERROR(-26004, 'To delete a non-draft will, confirmation is required. Please provide confirmation text: "' || v_confirm_required || '"');
        END IF;
    END IF;
    
    -- Count related records for audit purposes
    SELECT COUNT(*) INTO v_asset_count FROM assets WHERE will_id = p_will_id;
    SELECT COUNT(*) INTO v_executor_count FROM executors WHERE will_id = p_will_id;
    
    BEGIN
        SELECT COUNT(*) INTO v_beneficiary_count 
        FROM will_asset_beneficiaries 
        WHERE asset_id IN (SELECT asset_id FROM assets WHERE will_id = p_will_id);
    EXCEPTION
        WHEN OTHERS THEN
            v_beneficiary_count := 0;
    END;
    
    BEGIN
        SELECT COUNT(*) INTO v_doc_count 
        FROM documents 
        WHERE (related_entity = 'WILL' AND entity_id = p_will_id)
           OR (related_entity = 'ASSET' AND entity_id IN (SELECT asset_id FROM assets WHERE will_id = p_will_id));
    EXCEPTION
        WHEN OTHERS THEN
            v_doc_count := 0;
    END;
    
    -- Log the deletion attempt with counts
    log_audit(
        'DELETE_ATTEMPT',
        'WILLS',
        'Status: ' || v_status,
        'Related counts - Assets: ' || v_asset_count || ', Executors: ' || v_executor_count || 
        ', Beneficiaries: ' || v_beneficiary_count || ', Documents: ' || v_doc_count,
        'STARTED'
    );
    
    SAVEPOINT before_deletion;
    BEGIN
        -- Use dynamic SQL to handle all related tables
        -- Delete related documents
        BEGIN
            delete_and_track('documents', 'related_entity = ''WILL'' AND entity_id = ' || p_will_id);
            delete_and_track('documents', 'related_entity = ''ASSET'' AND entity_id IN (SELECT asset_id FROM assets WHERE will_id = ' || p_will_id || ')');
        EXCEPTION
            WHEN OTHERS THEN
                IF SQLCODE = -942 THEN NULL; ELSE RAISE; END IF;
        END;
        
        -- Delete asset-beneficiary mappings
        BEGIN
            delete_and_track('will_asset_beneficiaries', 'asset_id IN (SELECT asset_id FROM assets WHERE will_id = ' || p_will_id || ')');
        EXCEPTION
            WHEN OTHERS THEN
                IF SQLCODE = -942 THEN NULL; ELSE RAISE; END IF;
        END;
        
        -- Delete transfer logs
        BEGIN
            delete_and_track('transfer_logs', 'asset_id IN (SELECT asset_id FROM assets WHERE will_id = ' || p_will_id || ')');
        EXCEPTION
            WHEN OTHERS THEN
                IF SQLCODE = -942 THEN NULL; ELSE RAISE; END IF;
        END;
        
        -- Delete executors
        BEGIN
            delete_and_track('executors', 'will_id = ' || p_will_id);
        EXCEPTION
            WHEN OTHERS THEN
                IF SQLCODE = -942 THEN NULL; ELSE RAISE; END IF;
        END;
        
        -- Delete assets
        BEGIN
            delete_and_track('assets', 'will_id = ' || p_will_id);
        EXCEPTION
            WHEN OTHERS THEN
                IF SQLCODE = -942 THEN NULL; ELSE RAISE; END IF;
        END;
        
        -- Delete status history
        BEGIN
            delete_and_track('will_status_history', 'will_id = ' || p_will_id);
        EXCEPTION
            WHEN OTHERS THEN
                IF SQLCODE = -942 THEN NULL; ELSE RAISE; END IF;
        END;
        
        -- Finally, delete the will
        delete_and_track('wills', 'will_id = ' || p_will_id);
        
        -- Final audit record with complete summary
        log_audit(
            'DELETE',
            'WILLS',
            'Status before deletion: ' || v_status,
            'Deleted will ID ' || p_will_id || ' with ' || v_deleted_rows || ' related records',
            'SUCCESS'
        );
        
        DBMS_OUTPUT.PUT_LINE('Will ID ' || p_will_id || ' and ' || (v_deleted_rows-1) || ' related records deleted successfully.');
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO before_deletion;
            log_audit(
                'PROCEDURE',
                'WILLS',
                'delete_draft_will failed during cleanup',
                'Error: ' || SQLERRM || ' (error code: ' || SQLCODE || ')',
                'ERROR'
            );
            RAISE_APPLICATION_ERROR(-26005, 'Failed to delete will: ' || SQLERRM);
    END;
EXCEPTION
    WHEN OTHERS THEN
        log_audit(
            'PROCEDURE',
            'WILLS',
            'delete_draft_will failed at top level',
            'Error: ' || SQLERRM || ' (error code: ' || SQLCODE || ')',
            'ERROR'
        );
        RAISE;
END;
/