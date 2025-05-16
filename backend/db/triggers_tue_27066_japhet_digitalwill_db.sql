-- ======================================
-- Trigger: trg_block_weekend_holiday_transfer
-- Purpose: No changes allowed on weekends or holidays
-- ======================================

CREATE OR REPLACE TRIGGER trg_block_weekend_holiday_transfer 
BEFORE INSERT ON transfer_logs 
FOR EACH ROW 
DECLARE
    v_day VARCHAR2(10);
    v_is_holiday NUMBER;
    v_holiday_name VARCHAR2(100);
BEGIN
    -- Get the day of week for the transfer date
    SELECT TO_CHAR(:NEW.transfer_date, 'DY', 'NLS_DATE_LANGUAGE=EN') 
    INTO v_day FROM dual;
    
    -- Block transfers on weekends
    IF v_day IN ('SAT', 'SUN') THEN
        RAISE_APPLICATION_ERROR(-20001, 
            'Transfers are not allowed on weekends. Attempted date: ' || 
            TO_CHAR(:NEW.transfer_date, 'DD-MON-YYYY'));
    END IF;
    
    -- Check for holidays (both exact and recurring)
    SELECT COUNT(*), MAX(description) INTO v_is_holiday, v_holiday_name
    FROM holidays
    WHERE (TRUNC(holiday_date) = TRUNC(:NEW.transfer_date)) -- Exact match
       OR (is_recurring = 'Y' AND 
           TO_CHAR(holiday_date, 'MM-DD') = TO_CHAR(:NEW.transfer_date, 'MM-DD'));
    
    IF v_is_holiday > 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 
            'Transfers are not allowed on holidays. ' || 
            v_holiday_name || ' (' || TO_CHAR(:NEW.transfer_date, 'DD-MON-YYYY') || ')');
    END IF;
END;
/

-- ======================================
-- Trigger: trg_status_change_log
-- Purpose: Track status changes on wills and insert into will_status_history
-- ======================================

CREATE OR REPLACE TRIGGER trg_status_change_log 
AFTER UPDATE OF status ON wills 
FOR EACH ROW
DECLARE
    v_user VARCHAR2(100);
    v_client_info VARCHAR2(100);
    v_ip_address VARCHAR2(15);
    v_reason VARCHAR2(255);
    v_valid_transition BOOLEAN := TRUE;
    
    -- Custom exception for invalid status transitions
    e_invalid_transition EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_invalid_transition, -20003);
    
BEGIN
    -- Only proceed if status actually changed
    IF :OLD.status != :NEW.status THEN
        -- Get user context information
        v_user := SYS_CONTEXT('USERENV', 'SESSION_USER');
        v_client_info := SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER');
        v_ip_address := SYS_CONTEXT('USERENV', 'IP_ADDRESS');
        
        -- Get reason from context if provided, otherwise use default
        v_reason := NVL(SYS_CONTEXT('WILL_CTX', 'STATUS_CHANGE_REASON'), 
                        'Status changed by ' || v_user);
        
        -- Validate status transitions
        -- Prevent moving back from Executed status
        IF :OLD.status = 'Executed' THEN
            RAISE_APPLICATION_ERROR(-20003, 
                'Cannot change status from Executed to ' || :NEW.status);
        END IF;
        
        -- Prevent skipping the Approved status when moving from Draft to Executing
        IF :OLD.status = 'Draft' AND :NEW.status = 'Executing' THEN
            RAISE_APPLICATION_ERROR(-20004, 
                'Cannot change directly from Draft to Executing. Must be Approved first.');
        END IF;
        
        -- Update last_updated_at via autonomous transaction to avoid mutating table issues
        BEGIN
            EXECUTE IMMEDIATE 
                'UPDATE wills SET last_updated_at = SYSDATE WHERE will_id = :1'
                USING :NEW.will_id;
        EXCEPTION
            WHEN OTHERS THEN
                -- Log error but continue with status history recording
                INSERT INTO audit_log (
                    user_name, action, action_table, record_id, 
                    old_values, new_values, status, ip_address
                ) VALUES (
                    v_user, 'UPDATE', 'WILLS', :NEW.will_id,
                    'Failed to update last_updated_at', SQLERRM, 
                    'ERROR', v_ip_address
                );
        END;
        
        -- Insert status change history record
        INSERT INTO will_status_history (
            will_id,
            old_status,
            new_status,
            changed_by,
            change_date,
            reason
        ) VALUES (
            :NEW.will_id,
            :OLD.status,
            :NEW.status,
            v_user,
            SYSDATE,
            v_reason
        );
        
        -- Additional logging in audit_log for comprehensive auditing
        INSERT INTO audit_log (
            user_name,
            action,
            action_table,
            record_id,
            old_values,
            new_values,
            timestamp,
            status,
            ip_address
        ) VALUES (
            v_user,
            'UPDATE',
            'WILLS',
            :NEW.will_id,
            '{"status":"' || :OLD.status || '"}',
            '{"status":"' || :NEW.status || '"}',
            SYSDATE,
            'ALLOWED',
            v_ip_address
        );
        
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        -- Log error in audit_log
        INSERT INTO audit_log (
            user_name,
            action,
            action_table,
            record_id,
            old_values,
            new_values,
            timestamp,
            status,
            ip_address
        ) VALUES (
            NVL(v_user, 'UNKNOWN'),
            'UPDATE',
            'WILLS',
            :NEW.will_id,
            '{"status":"' || :OLD.status || '"}',
            '{"status":"' || :NEW.status || '"}',
            SYSDATE,
            'ERROR: ' || SQLERRM,
            NVL(v_ip_address, 'UNKNOWN')
        );
        
        -- Re-raise the exception to inform the application
        RAISE;
END;
/

-- Main will update trigger (no changes needed)
CREATE OR REPLACE TRIGGER trg_update_last_modified_on_wills
BEFORE UPDATE ON wills
FOR EACH ROW
BEGIN
    :NEW.last_updated_at := SYSDATE;
END;
/

-- Asset trigger with exception handling
CREATE OR REPLACE TRIGGER trg_update_last_modified_on_assets
AFTER INSERT OR UPDATE OR DELETE ON assets
FOR EACH ROW
DECLARE
    v_will_id NUMBER := NVL(:NEW.will_id, :OLD.will_id);
BEGIN
    IF v_will_id IS NOT NULL THEN
        UPDATE wills
        SET last_updated_at = SYSDATE
        WHERE will_id = v_will_id;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        -- Log error but don't stop the transaction
        INSERT INTO audit_log (
            user_name, action, action_table, record_id, 
            old_values, new_values, status
        ) VALUES (
            SYS_CONTEXT('USERENV', 'SESSION_USER'),
            'UPDATE', 'ASSETS', NVL(:NEW.asset_id, :OLD.asset_id),
            'Error updating wills.last_updated_at', SQLERRM, 'ERROR'
        );
END;
/

-- Executor trigger with exception handling
CREATE OR REPLACE TRIGGER trg_update_last_modified_on_executors
AFTER INSERT OR UPDATE OR DELETE ON executors
FOR EACH ROW
DECLARE
    v_will_id NUMBER := NVL(:NEW.will_id, :OLD.will_id);
BEGIN
    IF v_will_id IS NOT NULL THEN
        UPDATE wills
        SET last_updated_at = SYSDATE
        WHERE will_id = v_will_id;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        -- Log error but don't stop the transaction
        INSERT INTO audit_log (
            user_name, action, action_table, record_id, 
            old_values, new_values, status
        ) VALUES (
            SYS_CONTEXT('USERENV', 'SESSION_USER'),
            'UPDATE', 'EXECUTORS', NVL(:NEW.executor_id, :OLD.executor_id),
            'Error updating wills.last_updated_at', SQLERRM, 'ERROR'
        );
END;
/

-- Asset-beneficiary trigger with improved error handling and efficiency
CREATE OR REPLACE TRIGGER trg_update_last_modified_on_asset_beneficiaries
AFTER INSERT OR UPDATE OR DELETE ON will_asset_beneficiaries
FOR EACH ROW
DECLARE
    v_will_id NUMBER;
    v_asset_id NUMBER := NVL(:NEW.asset_id, :OLD.asset_id);
    e_no_data EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_no_data, -1403);
BEGIN
    -- Only proceed if we have a valid asset ID
    IF v_asset_id IS NOT NULL THEN
        BEGIN
            -- Get the will_id from assets
            SELECT will_id INTO v_will_id
            FROM assets
            WHERE asset_id = v_asset_id;
            
            -- Update the will's timestamp if we found a valid will_id
            IF v_will_id IS NOT NULL THEN
                UPDATE wills
                SET last_updated_at = SYSDATE
                WHERE will_id = v_will_id;
            END IF;
        EXCEPTION
            WHEN e_no_data THEN
                -- Asset no longer exists, log the error
                INSERT INTO audit_log (
                    user_name, action, action_table, record_id, 
                    old_values, new_values, status
                ) VALUES (
                    SYS_CONTEXT('USERENV', 'SESSION_USER'),
                    'UPDATE', 'WILL_ASSET_BENEFICIARIES', NVL(:NEW.mapping_id, :OLD.mapping_id),
                    'Asset ID ' || v_asset_id || ' not found', NULL, 'WARNING'
                );
            WHEN OTHERS THEN
                -- Other errors, log them
                INSERT INTO audit_log (
                    user_name, action, action_table, record_id, 
                    old_values, new_values, status
                ) VALUES (
                    SYS_CONTEXT('USERENV', 'SESSION_USER'),
                    'UPDATE', 'WILL_ASSET_BENEFICIARIES', NVL(:NEW.mapping_id, :OLD.mapping_id),
                    'Error updating wills.last_updated_at', SQLERRM, 'ERROR'
                );
        END;
    END IF;
END;
/

-- ======================================
-- Trigger: trg_check_asset_share_percent
-- Purpose: Ensure total assigned share for an asset does not exceed 100%
-- ======================================

CREATE OR REPLACE TRIGGER trg_check_asset_share_percent
BEFORE INSERT OR UPDATE ON will_asset_beneficiaries
FOR EACH ROW
DECLARE
    v_total_share NUMBER := 0;
    v_current_asset_id NUMBER := :NEW.asset_id;
    v_asset_exists NUMBER;
    v_will_status VARCHAR2(20);
BEGIN
    -- Validate asset_id is not NULL
    IF v_current_asset_id IS NULL THEN
        RAISE_APPLICATION_ERROR(-20010, 'Asset ID cannot be NULL');
    END IF;
    
    -- Check if the asset exists
    SELECT COUNT(*) INTO v_asset_exists
    FROM assets
    WHERE asset_id = v_current_asset_id;
    
    IF v_asset_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'Asset ID ' || v_current_asset_id || ' does not exist');
    END IF;
    
    -- Check if the will is in a state where modifications are allowed
    SELECT w.status INTO v_will_status
    FROM wills w
    JOIN assets a ON w.will_id = a.will_id
    WHERE a.asset_id = v_current_asset_id;
    
    IF v_will_status = 'Executed' THEN
        RAISE_APPLICATION_ERROR(-20012, 
            'Cannot modify beneficiary shares for asset ID ' || v_current_asset_id || 
            ' because the associated will has been executed');
    END IF;
    
    -- Calculate the total assigned share for the asset excluding the current mapping (if update)
    SELECT NVL(SUM(share_percent), 0)
    INTO v_total_share
    FROM will_asset_beneficiaries
    WHERE asset_id = v_current_asset_id
      AND mapping_id != NVL(:NEW.mapping_id, -1); -- Exclude current row if update
    
    -- Add the new/updated share value
    v_total_share := v_total_share + NVL(:NEW.share_percent, 0);
    
    -- Validate total share does not exceed 100%
    IF v_total_share > 100 THEN
        RAISE_APPLICATION_ERROR(-20005,
            'Total share for asset ID ' || v_current_asset_id || 
            ' exceeds 100%. Current total: ' || v_total_share || '%');
    END IF;
    
    -- Warn if total share is significantly under 100% (e.g., less than 90%)
    -- Using DBMS_OUTPUT for demonstration; in a real app, could log to a table
    IF v_total_share < 90 THEN
        DBMS_OUTPUT.PUT_LINE('Warning: Asset ID ' || v_current_asset_id || 
            ' is only allocated at ' || v_total_share || '% of its value');
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- This would occur if the asset exists but no will is associated
        RAISE_APPLICATION_ERROR(-20013, 
            'Asset ID ' || v_current_asset_id || ' is not associated with a valid will');
    WHEN OTHERS THEN
        -- Log the error for troubleshooting
        INSERT INTO audit_log (
            user_name, action, action_table, record_id, 
            old_values, new_values, status
        ) VALUES (
            SYS_CONTEXT('USERENV', 'SESSION_USER'),
            'INSERT/UPDATE', 'WILL_ASSET_BENEFICIARIES', NVL(:NEW.mapping_id, -1),
            'Error in share percentage validation', SQLERRM, 'ERROR'
        );
        -- Re-raise to prevent the operation
        RAISE;
END;
/
-- Ensures all assets are fully allocated (100%) before a will can be executed
CREATE OR REPLACE TRIGGER trg_validate_complete_allocation
BEFORE UPDATE OF status ON wills
FOR EACH ROW
WHEN (NEW.status = 'Executing' OR NEW.status = 'Executed')
DECLARE
    v_incomplete_assets NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_incomplete_assets
    FROM assets a
    WHERE a.will_id = :NEW.will_id
    AND 100 > (
        SELECT NVL(SUM(share_percent), 0)
        FROM will_asset_beneficiaries
        WHERE asset_id = a.asset_id
    );
    
    IF v_incomplete_assets > 0 THEN
        RAISE_APPLICATION_ERROR(-20020, 
            'Cannot execute will. ' || v_incomplete_assets || 
            ' assets do not have 100% allocation.');
    END IF;
END;
/

-- Ensures a will has at least one executor before approval
CREATE OR REPLACE TRIGGER trg_validate_executor_exists
BEFORE UPDATE OF status ON wills
FOR EACH ROW
WHEN (NEW.status = 'Approved')
DECLARE
    v_executor_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_executor_count
    FROM executors
    WHERE will_id = :NEW.will_id;
    
    IF v_executor_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20021, 
            'Cannot approve will without at least one executor.');
    END IF;
END;
/

-- Example for one table - replicate for other important tables
CREATE OR REPLACE TRIGGER trg_audit_wills
AFTER INSERT OR UPDATE OR DELETE ON wills
FOR EACH ROW
DECLARE
    v_action VARCHAR2(10);
    v_old_values CLOB;
    v_new_values CLOB;
BEGIN
    -- Determine the action
    IF INSERTING THEN
        v_action := 'INSERT';
        v_old_values := NULL;
    ELSIF UPDATING THEN
        v_action := 'UPDATE';
        v_old_values := '{"will_id":' || :OLD.will_id || 
                       ',"title":"' || :OLD.title || 
                       '","status":"' || :OLD.status || '"}';
    ELSIF DELETING THEN
        v_action := 'DELETE';
        v_new_values := NULL;
    END IF;
    
    -- Set new values for insert/update
    IF NOT DELETING THEN
        v_new_values := '{"will_id":' || :NEW.will_id || 
                       ',"title":"' || :NEW.title || 
                       '","status":"' || :NEW.status || '"}';
    END IF;
    
    -- Insert audit record
    INSERT INTO audit_log (
        user_name, action, action_table, record_id, 
        old_values, new_values, status, ip_address
    ) VALUES (
        SYS_CONTEXT('USERENV', 'SESSION_USER'),
        v_action, 'WILLS', NVL(:NEW.will_id, :OLD.will_id),
        v_old_values, v_new_values, 'ALLOWED',
        SYS_CONTEXT('USERENV', 'IP_ADDRESS')
    );
END;
/

-- Ensures only one primary executor per will
CREATE OR REPLACE TRIGGER trg_single_primary_executor
BEFORE INSERT OR UPDATE OF is_primary ON executors
FOR EACH ROW
WHEN (NEW.is_primary = 'Y')
DECLARE
    v_primary_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_primary_count
    FROM executors
    WHERE will_id = :NEW.will_id
    AND is_primary = 'Y'
    AND executor_id != NVL(:NEW.executor_id, -1);
    
    IF v_primary_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20022, 
            'Only one primary executor is allowed per will.');
    END IF;
END;
/

-- Validates that document references point to valid entities
CREATE OR REPLACE TRIGGER trg_validate_document_entity
BEFORE INSERT OR UPDATE ON documents
FOR EACH ROW
DECLARE
    v_entity_exists NUMBER;
BEGIN
    IF :NEW.related_entity = 'WILL' THEN
        SELECT COUNT(*) INTO v_entity_exists
        FROM wills WHERE will_id = :NEW.entity_id;
    ELSIF :NEW.related_entity = 'ASSET' THEN
        SELECT COUNT(*) INTO v_entity_exists
        FROM assets WHERE asset_id = :NEW.entity_id;
    END IF;
    
    IF v_entity_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20023, 
            'Referenced ' || :NEW.related_entity || ' with ID ' || 
            :NEW.entity_id || ' does not exist.');
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_validate_email_format
BEFORE INSERT OR UPDATE OF email ON users
FOR EACH ROW
BEGIN
    IF :NEW.email IS NOT NULL AND 
       NOT REGEXP_LIKE(:NEW.email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$') THEN
        RAISE_APPLICATION_ERROR(-20030, 'Invalid email format: ' || :NEW.email);
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_prevent_will_deletion
BEFORE DELETE ON wills
FOR EACH ROW
WHEN (OLD.status IN ('Approved', 'Executing', 'Executed'))
BEGIN
    RAISE_APPLICATION_ERROR(-20031, 
        'Cannot delete will with ID ' || :OLD.will_id || 
        ' because it has been approved or executed.');
END;
/