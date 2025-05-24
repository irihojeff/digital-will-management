-- ======================================
-- Trigger: trg_block_weekend_holiday_transfer
-- Purpose: No changes allowed on weekends or holidays
-- ======================================

-- Fixed trigger to handle NLS issues and provide better error messages
CREATE OR REPLACE TRIGGER trg_block_weekend_holiday_transfer 
BEFORE INSERT ON transfer_logs 
FOR EACH ROW 
DECLARE
    v_day_number NUMBER;
    v_is_holiday NUMBER;
    v_holiday_name VARCHAR2(100);
    v_transfer_date DATE := NVL(:NEW.transfer_date, SYSDATE);
BEGIN
    -- Get the day of week as number (1=Sunday, 2=Monday, ..., 7=Saturday)
    -- Using TO_CHAR with 'D' format which is NLS-independent
    v_day_number := TO_NUMBER(TO_CHAR(v_transfer_date, 'D'));
    
    -- Block transfers on weekends (1=Sunday, 7=Saturday)
    IF v_day_number IN (1, 7) THEN
        RAISE_APPLICATION_ERROR(-20001, 
            'Weekend Transfer Blocked: Asset transfers are not allowed on weekends. ' ||
            'Today is ' || TO_CHAR(v_transfer_date, 'Day') || 
            '. Please try again on a weekday (Monday-Friday).');
    END IF;
    
    -- Check for holidays (both exact and recurring)
    BEGIN
        SELECT COUNT(*), MAX(description) 
        INTO v_is_holiday, v_holiday_name
        FROM holidays
        WHERE (TRUNC(holiday_date) = TRUNC(v_transfer_date)) -- Exact match
           OR (is_recurring = 'Y' AND 
               TO_CHAR(holiday_date, 'MM-DD') = TO_CHAR(v_transfer_date, 'MM-DD'));
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_is_holiday := 0;
            v_holiday_name := NULL;
    END;
    
    IF v_is_holiday > 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 
            'Holiday Transfer Blocked: Asset transfers are not allowed on public holidays. ' ||
            'Today is ' || NVL(v_holiday_name, 'a public holiday') || 
            ' (' || TO_CHAR(v_transfer_date, 'DD-MON-YYYY') || '). ' ||
            'Please try again on a regular business day.');
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        -- If it's our custom errors, re-raise them
        IF SQLCODE IN (-20001, -20002) THEN
            RAISE;
        ELSE
            -- For any other errors, provide a generic message
            RAISE_APPLICATION_ERROR(-20099, 
                'Transfer Validation Error: Unable to validate transfer timing. ' ||
                'Please contact system administrator. Error: ' || SQLERRM);
        END IF;
END;
/

-- Also let's create a simple test procedure to check weekend blocking
CREATE OR REPLACE PROCEDURE test_weekend_blocking 
IS
    v_day_number NUMBER;
    v_day_name VARCHAR2(20);
    v_is_weekend VARCHAR2(10);
BEGIN
    -- Get current day info
    v_day_number := TO_NUMBER(TO_CHAR(SYSDATE, 'D'));
    v_day_name := TRIM(TO_CHAR(SYSDATE, 'Day'));
    
    IF v_day_number IN (1, 7) THEN
        v_is_weekend := 'YES';
        DBMS_OUTPUT.PUT_LINE('Weekend Blocking Test Results:');
        DBMS_OUTPUT.PUT_LINE('Current Day: ' || v_day_name || ' (Day #' || v_day_number || ')');
        DBMS_OUTPUT.PUT_LINE('Status: WEEKEND - Transfers would be BLOCKED');
        DBMS_OUTPUT.PUT_LINE('Message: Asset transfers are not allowed on weekends');
    ELSE
        v_is_weekend := 'NO';
        DBMS_OUTPUT.PUT_LINE('Weekend Blocking Test Results:');
        DBMS_OUTPUT.PUT_LINE('Current Day: ' || v_day_name || ' (Day #' || v_day_number || ')');
        DBMS_OUTPUT.PUT_LINE('Status: WEEKDAY - Transfers would be ALLOWED');
        DBMS_OUTPUT.PUT_LINE('Message: Normal business day, transfers permitted');
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
    
    -- Procedure for logging in audit_log
    PROCEDURE log_audit(
        p_user IN VARCHAR2,
        p_action IN VARCHAR2,
        p_table IN VARCHAR2,
        p_id IN NUMBER,
        p_old IN VARCHAR2,
        p_new IN VARCHAR2,
        p_status IN VARCHAR2,
        p_ip IN VARCHAR2 DEFAULT NULL
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO audit_log (
            user_name, action, action_table, record_id, 
            old_values, new_values, status, ip_address
        ) VALUES (
            p_user, p_action, p_table, p_id,
            p_old, p_new, p_status, p_ip
        );
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
    END log_audit;
    
    -- Procedure for updating timestamp
    PROCEDURE update_timestamp(p_id IN NUMBER) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        v_sql VARCHAR2(200);
    BEGIN
        v_sql := 'UPDATE wills SET last_updated_at = SYSDATE WHERE will_id = :1';
        
        EXECUTE IMMEDIATE v_sql USING p_id;
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END update_timestamp;
    
    -- Procedure for inserting status history
    PROCEDURE insert_status_history(
        p_will_id IN NUMBER,
        p_old_status IN VARCHAR2,
        p_new_status IN VARCHAR2,
        p_user IN VARCHAR2,
        p_reason IN VARCHAR2
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO will_status_history (
            will_id, old_status, new_status,
            changed_by, change_date, reason
        ) VALUES (
            p_will_id, p_old_status, p_new_status,
            p_user, SYSDATE, p_reason
        );
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END insert_status_history;
    
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
        
        -- Update last_updated_at via autonomous transaction
        BEGIN
            update_timestamp(:NEW.will_id);
        EXCEPTION
            WHEN OTHERS THEN
                -- Log error but continue with status history recording
                log_audit(
                    v_user, 'UPDATE', 'WILLS', :NEW.will_id,
                    'Failed to update last_updated_at', SQLERRM, 
                    'ERROR', v_ip_address
                );
        END;
        
        -- Insert status change history record
        BEGIN
            insert_status_history(
                :NEW.will_id,
                :OLD.status,
                :NEW.status,
                v_user,
                v_reason
            );
        EXCEPTION
            WHEN OTHERS THEN
                log_audit(
                    v_user, 'UPDATE', 'WILLS', :NEW.will_id,
                    'Failed to insert status history', SQLERRM, 
                    'ERROR', v_ip_address
                );
        END;
        
        -- Additional logging in audit_log for comprehensive auditing
        BEGIN
            log_audit(
                v_user, 'UPDATE', 'WILLS', :NEW.will_id,
                '{"status":"' || :OLD.status || '"}',
                '{"status":"' || :NEW.status || '"}',
                'ALLOWED', v_ip_address
            );
        EXCEPTION
            WHEN OTHERS THEN
                NULL; -- Ignore errors in audit logging
        END;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        -- Log error in audit_log
        BEGIN
            log_audit(
                NVL(v_user, 'UNKNOWN'), 'UPDATE', 'WILLS', :NEW.will_id,
                '{"status":"' || :OLD.status || '"}',
                '{"status":"' || :NEW.status || '"}',
                'ERROR: ' || SQLERRM, NVL(v_ip_address, 'UNKNOWN')
            );
        EXCEPTION
            WHEN OTHERS THEN
                NULL; -- Ignore errors in error logging
        END;
        
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
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    IF v_will_id IS NOT NULL THEN
        BEGIN
            EXECUTE IMMEDIATE 
                'UPDATE wills SET last_updated_at = SYSDATE WHERE will_id = :1'
                USING v_will_id;
            COMMIT; -- Must commit in autonomous transaction
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                -- Log error through separate insert to avoid recursion
                EXECUTE IMMEDIATE
                    'INSERT INTO audit_log (user_name, action, action_table, record_id, old_values, new_values, status) 
                     VALUES (:1, :2, :3, :4, :5, :6, :7)'
                    USING 
                    SYS_CONTEXT('USERENV', 'SESSION_USER'),
                    'UPDATE', 
                    'ASSETS', 
                    NVL(TO_CHAR(:NEW.asset_id), TO_CHAR(:OLD.asset_id)),
                    'Error updating wills.last_updated_at', 
                    SQLERRM, 
                    'ERROR';
                COMMIT;
        END;
    END IF;
END;
/

-- Executor trigger with exception handling
CREATE OR REPLACE TRIGGER trg_update_last_modified_on_executors
AFTER INSERT OR UPDATE OR DELETE ON executors
FOR EACH ROW
DECLARE
    v_will_id NUMBER := NVL(:NEW.will_id, :OLD.will_id);
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    IF v_will_id IS NOT NULL THEN
        BEGIN
            EXECUTE IMMEDIATE 
                'UPDATE wills SET last_updated_at = SYSDATE WHERE will_id = :1'
                USING v_will_id;
            COMMIT; -- Must commit in autonomous transaction
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                -- Log error through separate insert to avoid recursion
                EXECUTE IMMEDIATE
                    'INSERT INTO audit_log (user_name, action, action_table, record_id, old_values, new_values, status) 
                     VALUES (:1, :2, :3, :4, :5, :6, :7)'
                    USING 
                    SYS_CONTEXT('USERENV', 'SESSION_USER'),
                    'UPDATE', 
                    'EXECUTORS', 
                    NVL(TO_CHAR(:NEW.executor_id), TO_CHAR(:OLD.executor_id)),
                    'Error updating wills.last_updated_at', 
                    SQLERRM, 
                    'ERROR';
                COMMIT;
        END;
    END IF;
END;
/

-- Asset-beneficiary trigger with improved error handling and efficiency
CREATE OR REPLACE TRIGGER trg_update_last_modified_on_asset_beneficiaries
AFTER INSERT OR UPDATE OR DELETE ON will_asset_beneficiaries
FOR EACH ROW
DECLARE
    v_will_id NUMBER;
    v_asset_id NUMBER := NVL(:NEW.asset_id, :OLD.asset_id);
    v_mapping_id VARCHAR2(30) := NVL(TO_CHAR(:NEW.mapping_id), TO_CHAR(:OLD.mapping_id));
    
    -- Procedure for updating last_updated_at in autonomous transaction
    PROCEDURE update_will_timestamp(p_will_id IN NUMBER) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        EXECUTE IMMEDIATE 
            'UPDATE wills SET last_updated_at = SYSDATE WHERE will_id = :1'
            USING p_will_id;
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END update_will_timestamp;
    
    -- Procedure for logging errors in autonomous transaction
    PROCEDURE log_error(
        p_action IN VARCHAR2,
        p_record_id IN VARCHAR2,
        p_old_values IN VARCHAR2,
        p_new_values IN VARCHAR2,
        p_status IN VARCHAR2
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO audit_log (
            user_name, action, action_table, record_id, 
            old_values, new_values, status
        ) VALUES (
            SYS_CONTEXT('USERENV', 'SESSION_USER'),
            p_action, 'WILL_ASSET_BENEFICIARIES', p_record_id,
            p_old_values, p_new_values, p_status
        );
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
    END log_error;
    
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
                update_will_timestamp(v_will_id);
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- Asset no longer exists, log the error
                log_error(
                    'UPDATE',
                    v_mapping_id,
                    'Asset ID ' || v_asset_id || ' not found',
                    NULL,
                    'WARNING'
                );
            WHEN OTHERS THEN
                -- Other errors, log them
                log_error(
                    'UPDATE',
                    v_mapping_id,
                    'Error updating wills.last_updated_at',
                    SQLERRM,
                    'ERROR'
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
    v_will_id NUMBER;
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
    
    -- Get the will_id first, then check status in a separate query
    BEGIN
        SELECT will_id INTO v_will_id
        FROM assets
        WHERE asset_id = v_current_asset_id;
        
        IF v_will_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20013, 
                'Asset ID ' || v_current_asset_id || ' is not associated with a valid will');
        END IF;
        
        -- Now check the will status
        SELECT status INTO v_will_status
        FROM wills
        WHERE will_id = v_will_id;
        
        IF v_will_status = 'Executed' THEN
            RAISE_APPLICATION_ERROR(-20012, 
                'Cannot modify beneficiary shares for asset ID ' || v_current_asset_id || 
                ' because the associated will has been executed');
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20013, 
                'Asset ID ' || v_current_asset_id || ' is not associated with a valid will');
    END;
    
    -- Calculate the total assigned share for the asset excluding the current mapping (if update)
    BEGIN
        SELECT NVL(SUM(share_percent), 0)
        INTO v_total_share
        FROM will_asset_beneficiaries
        WHERE asset_id = v_current_asset_id
          AND ((:NEW.mapping_id IS NULL AND mapping_id IS NOT NULL) OR 
               (mapping_id != :NEW.mapping_id));
    EXCEPTION
        WHEN OTHERS THEN
            v_total_share := 0; -- Default if the query fails
    END;
    
    -- Add the new/updated share value
    v_total_share := v_total_share + NVL(:NEW.share_percent, 0);
    
    -- Validate total share does not exceed 100%
    IF v_total_share > 100 THEN
        RAISE_APPLICATION_ERROR(-20005,
            'Total share for asset ID ' || v_current_asset_id || 
            ' exceeds 100%. Current total: ' || v_total_share || '%');
    END IF;
    
    -- Warn if total share is significantly under 100% (e.g., less than 90%)
    IF v_total_share < 90 THEN
        -- Use DBMS_OUTPUT instead of trying to INSERT, which can cause issues in BEFORE triggers
        DBMS_OUTPUT.PUT_LINE('Warning: Asset ID ' || v_current_asset_id || 
            ' is only allocated at ' || v_total_share || '% of its value');
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        -- This would occur if the asset exists but no will is associated
        RAISE_APPLICATION_ERROR(-20013, 
            'Asset ID ' || v_current_asset_id || ' is not associated with a valid will');
    WHEN OTHERS THEN
        -- For BEFORE triggers, it's best to avoid INSERTs as these can cause recursive issues
        -- Just raise the error with some context
        RAISE_APPLICATION_ERROR(-20099, 
            'Error in share percentage validation for asset ' || 
            v_current_asset_id || ': ' || SQLERRM);
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