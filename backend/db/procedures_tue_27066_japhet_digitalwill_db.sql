-- ================================================
-- Procedure: assign_asset_to_beneficiary
-- Purpose: Assigns a beneficiary to an asset with share % and conditions
-- Validates: asset existence, beneficiary existence, will status, and share cap
-- ================================================

CREATE OR REPLACE PROCEDURE assign_asset_to_beneficiary (
    p_asset_id         IN NUMBER,
    p_beneficiary_id   IN NUMBER,
    p_share_percent    IN NUMBER,
    p_conditions       IN VARCHAR2 DEFAULT NULL,
    p_success          OUT BOOLEAN,
    p_message          OUT VARCHAR2
) IS
    v_asset_exists        NUMBER;
    v_beneficiary_exists  NUMBER;
    v_total_share         NUMBER;
    v_will_status         VARCHAR2(20);
    v_will_id             NUMBER;
    v_existing_mapping    NUMBER;
    v_operation           VARCHAR2(10) := 'INSERT';
BEGIN
    p_success := FALSE;
    
    -- Input parameter validation
    IF p_asset_id IS NULL THEN
        p_message := 'Asset ID cannot be NULL';
        RETURN;
    END IF;
    
    IF p_beneficiary_id IS NULL THEN
        p_message := 'Beneficiary ID cannot be NULL';
        RETURN;
    END IF;
    
    IF p_share_percent IS NULL OR p_share_percent <= 0 OR p_share_percent > 100 THEN
        p_message := 'Share percentage must be between 0.01 and 100';
        RETURN;
    END IF;
    
    -- Check if asset exists and get will_id
    SELECT COUNT(*), MAX(will_id)
    INTO v_asset_exists, v_will_id
    FROM assets
    WHERE asset_id = p_asset_id;
    
    IF v_asset_exists = 0 THEN
        p_message := 'Asset ID ' || p_asset_id || ' does not exist.';
        RETURN;
    END IF;
    
    -- Check if beneficiary exists
    SELECT COUNT(*) INTO v_beneficiary_exists
    FROM beneficiaries
    WHERE beneficiary_id = p_beneficiary_id;
    
    IF v_beneficiary_exists = 0 THEN
        p_message := 'Beneficiary ID ' || p_beneficiary_id || ' does not exist.';
        RETURN;
    END IF;
    
    -- Check if this mapping already exists
    SELECT COUNT(*) INTO v_existing_mapping
    FROM will_asset_beneficiaries
    WHERE asset_id = p_asset_id
    AND beneficiary_id = p_beneficiary_id;
    
    -- Check if the will is not executed
    SELECT status INTO v_will_status
    FROM wills
    WHERE will_id = v_will_id
    FOR UPDATE; -- Lock the will row to prevent concurrent status changes
    
    IF v_will_status = 'Executed' THEN
        p_message := 'Cannot assign asset to beneficiary. Will is already executed.';
        RETURN;
    END IF;
    
    -- Calculate total existing share (excluding this beneficiary if it's an update)
    SELECT NVL(SUM(share_percent), 0)
    INTO v_total_share
    FROM will_asset_beneficiaries
    WHERE asset_id = p_asset_id
    AND (v_existing_mapping = 0 OR beneficiary_id != p_beneficiary_id)
    FOR UPDATE; -- Lock rows to prevent concurrent share assignments
    
    IF v_total_share + p_share_percent > 100 THEN
        p_message := 'Cannot assign asset. Total share would exceed 100%. Current total: ' || 
                     v_total_share || '%, Requested: ' || p_share_percent || '%.';
        RETURN;
    END IF;
    
    -- Handle as update or insert based on existing mapping
    IF v_existing_mapping > 0 THEN
        v_operation := 'UPDATE';
        
        UPDATE will_asset_beneficiaries
        SET share_percent = p_share_percent,
            conditions = p_conditions
        WHERE asset_id = p_asset_id
        AND beneficiary_id = p_beneficiary_id;
    ELSE
        -- Insert into mapping table
        INSERT INTO will_asset_beneficiaries (
            asset_id,
            beneficiary_id,
            share_percent,
            conditions
        ) VALUES (
            p_asset_id,
            p_beneficiary_id,
            p_share_percent,
            p_conditions
        );
    END IF;
    
    -- Log successful operation to audit trail
    INSERT INTO audit_log (
        user_name, action, action_table, record_id,
        old_values, new_values, status, ip_address
    ) VALUES (
        SYS_CONTEXT('USERENV', 'SESSION_USER'),
        v_operation,
        'WILL_ASSET_BENEFICIARIES',
        p_asset_id || '-' || p_beneficiary_id,
        NULL,
        '{"asset_id":' || p_asset_id || 
        ',"beneficiary_id":' || p_beneficiary_id || 
        ',"share_percent":' || p_share_percent || 
        ',"conditions":"' || NVL(p_conditions, 'NULL') || '"}',
        'SUCCESS',
        SYS_CONTEXT('USERENV', 'IP_ADDRESS')
    );
    
    p_success := TRUE;
    p_message := 'Successfully ' || CASE WHEN v_operation = 'INSERT' THEN 'assigned' 
                                        ELSE 'updated assignment of' END ||
                 ' Asset ID ' || p_asset_id || ' to Beneficiary ID ' || 
                 p_beneficiary_id || ' (' || p_share_percent || '%)';
                 
    DBMS_OUTPUT.PUT_LINE(p_message);
    
EXCEPTION
    WHEN OTHERS THEN
        p_success := FALSE;
        p_message := SQLERRM;
        
        -- Log error to audit_log
        INSERT INTO audit_log (
            user_name, action, action_table, record_id,
            old_values, new_values, status, ip_address
        ) VALUES (
            SYS_CONTEXT('USERENV', 'SESSION_USER'),
            'PROCEDURE',
            'WILL_ASSET_BENEFICIARIES',
            p_asset_id || '-' || p_beneficiary_id,
            '{"asset_id":' || p_asset_id || 
            ',"beneficiary_id":' || p_beneficiary_id || 
            ',"share_percent":' || p_share_percent || 
            ',"conditions":"' || NVL(p_conditions, 'NULL') || '"}',
            SQLERRM,
            'ERROR',
            SYS_CONTEXT('USERENV', 'IP_ADDRESS')
        );
END;
/

BEGIN
  assign_asset_to_beneficiary(1, 2, 40, 'After graduation');
END;