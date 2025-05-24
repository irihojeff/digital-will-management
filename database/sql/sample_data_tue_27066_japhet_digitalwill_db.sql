
-- Sample Data Insertions for tue_27066_japhet_digitalwill_db

-- USERS
INSERT INTO users (full_name, email, phone_number, date_of_birth, address)
VALUES ('Nsengiyumva Jean Claude', 'jean.claude@example.rw', '+250782111222', TO_DATE('1980-03-15', 'YYYY-MM-DD'), 'Kigali, Gasabo');

INSERT INTO users (full_name, email, phone_number, date_of_birth, address)
VALUES ('Uwase Sandrine', 'sandrine.uwase@example.rw', '+250783333444', TO_DATE('1975-07-29', 'YYYY-MM-DD'), 'Huye, Southern Province');

-- WILLS
INSERT INTO wills (user_id, title, description, status)
VALUES (1, 'Family Property Distribution', 'This will includes family house and savings.', 'Approved');

INSERT INTO wills (user_id, title, description, status)
VALUES (2, 'Business Succession', 'Instructions for business handover.', 'Draft');

-- ASSETS
INSERT INTO assets (will_id, name, description, asset_type, value, location, acquisition_date)
VALUES (1, 'Family House in Remera', '3-bedroom house with garden', 'Real Estate', 45000000, 'Remera, Kigali', TO_DATE('2008-05-20', 'YYYY-MM-DD'));

INSERT INTO assets (will_id, name, description, asset_type, value, location, acquisition_date)
VALUES (1, 'BK Savings Account', 'Savings account at Bank of Kigali', 'Financial', 8500000, 'BK Remera Branch', TO_DATE('2010-06-01', 'YYYY-MM-DD'));

INSERT INTO assets (will_id, name, description, asset_type, value, location, acquisition_date)
VALUES (2, 'Butare Boutique Stock', 'Retail stock from clothing boutique', 'Personal', 1200000, 'Butare', TO_DATE('2020-01-12', 'YYYY-MM-DD'));

-- BENEFICIARIES
INSERT INTO beneficiaries (full_name, relation, email, phone_number, address, date_of_birth, notes)
VALUES ('Munyaneza Eric', 'Son', 'eric.munyaneza@example.rw', '+250781234567', 'Kimironko, Kigali', TO_DATE('2005-06-12', 'YYYY-MM-DD'), 'High school graduate');

INSERT INTO beneficiaries (full_name, relation, email, phone_number, address, date_of_birth, notes)
VALUES ('Ishimwe Diane', 'Daughter', 'diane.ishimwe@example.rw', '+250782345678', 'Gikondo, Kigali', TO_DATE('2003-11-22', 'YYYY-MM-DD'), 'University student');

INSERT INTO beneficiaries (full_name, relation, email, phone_number, address, date_of_birth, notes)
VALUES ('Rugamba Pascal', 'Brother', 'pascal.rugamba@example.rw', '+250784567890', 'Gisagara District', TO_DATE('1982-04-04', 'YYYY-MM-DD'), 'Involved in family business');

-- EXECUTORS
INSERT INTO executors (will_id, full_name, email, phone_number, relation, is_primary)
VALUES (1, 'Mukamana Solange', 'solange.mukamana@lawfirm.rw', '+250786000111', 'Family Lawyer', 'Y');

INSERT INTO executors (will_id, full_name, email, phone_number, relation, is_primary)
VALUES (2, 'Nkurunziza Patrick', 'patrick.nk@firm.rw', '+250788999333', 'Friend', 'Y');

-- DOCUMENTS
INSERT INTO documents (related_entity, entity_id, title, description, file_path, file_type)
VALUES ('WILL', 1, 'Scanned Will Document', 'Signed copy of the family property will', '/files/will_1.pdf', 'PDF');

-- HOLIDAYS
INSERT INTO holidays (holiday_date, description, is_recurring)
VALUES (TO_DATE('2025-07-01', 'YYYY-MM-DD'), 'Independence Day', 'Y');


INSERT INTO wills (will_id, user_id, title, status)
VALUES (999, 1, 'Test Will for Approval', 'Draft');

INSERT INTO executors (executor_id, will_id, full_name, email, is_primary)
VALUES (999, 999, 'Executor Test', 'exec@test.com', 'Y');












-- Demo Account Insert Queries for Digital Will Management System
-- Run these after your schema and sample data are loaded

-- ============================================================================
-- DEMO USERS (if not already in your sample data)
-- ============================================================================

-- Testator Account
INSERT INTO users (user_id, full_name, email, phone_number, date_of_birth, address, created_at)
VALUES (1, 'Jean Claude Nsengiyumva', 'jean.claude@example.rw', '+250782111222', 
        TO_DATE('1980-03-15', 'YYYY-MM-DD'), 'Kigali, Gasabo District', SYSDATE);

-- Executor Account (if you want to test executor login)
INSERT INTO users (user_id, full_name, email, phone_number, date_of_birth, address, created_at)
VALUES (2, 'Solange Mukamana', 'solange.mukamana@lawfirm.rw', '+250786000111', 
        TO_DATE('1975-09-12', 'YYYY-MM-DD'), 'Kigali, Nyarugenge District', SYSDATE);

-- Beneficiary Account (if you want to test beneficiary login)
INSERT INTO users (user_id, full_name, email, phone_number, date_of_birth, address, created_at)
VALUES (3, 'Eric Munyaneza', 'eric.munyaneza@example.rw', '+250781234567', 
        TO_DATE('2005-06-12', 'YYYY-MM-DD'), 'Kimironko, Kigali', SYSDATE);

-- ============================================================================
-- ADDITIONAL DEMO DATA FOR COMPREHENSIVE TESTING
-- ============================================================================

-- Demo Will for testing
INSERT INTO wills (will_id, user_id, title, description, status, created_at)
VALUES (1, 1, 'Family Property Distribution', 'Complete distribution of family assets including house and savings', 'Draft', SYSDATE);

-- Demo Assets
INSERT INTO assets (asset_id, will_id, name, description, asset_type, value, location, acquisition_date)
VALUES (1, 1, 'Family House in Remera', '3-bedroom house with garden and parking', 'Real Estate', 45000000, 'Remera, Kigali', TO_DATE('2008-05-20', 'YYYY-MM-DD'));

INSERT INTO assets (asset_id, will_id, name, description, asset_type, value, location, acquisition_date)
VALUES (2, 1, 'BK Savings Account', 'Primary savings account at Bank of Kigali', 'Financial', 8500000, 'BK Remera Branch', TO_DATE('2010-06-01', 'YYYY-MM-DD'));

INSERT INTO assets (asset_id, will_id, name, description, asset_type, value, location, acquisition_date)
VALUES (3, 1, 'Toyota RAV4 2019', 'Family vehicle in excellent condition', 'Vehicle', 15000000, 'Home Garage, Remera', TO_DATE('2019-03-15', 'YYYY-MM-DD'));

-- Demo Beneficiaries
INSERT INTO beneficiaries (beneficiary_id, full_name, relation, email, phone_number, address, date_of_birth, notes)
VALUES (1, 'Eric Munyaneza', 'Son', 'eric.munyaneza@example.rw', '+250781234567', 'Kimironko, Kigali', TO_DATE('2005-06-12', 'YYYY-MM-DD'), 'Eldest son, university student');

INSERT INTO beneficiaries (beneficiary_id, full_name, relation, email, phone_number, address, date_of_birth, notes)
VALUES (2, 'Diane Ishimwe', 'Daughter', 'diane.ishimwe@example.rw', '+250782345678', 'Gikondo, Kigali', TO_DATE('2003-11-22', 'YYYY-MM-DD'), 'Daughter, high school graduate');

INSERT INTO beneficiaries (beneficiary_id, full_name, relation, email, phone_number, address, date_of_birth, notes)
VALUES (3, 'Pascal Rugamba', 'Brother', 'pascal.rugamba@example.rw', '+250784567890', 'Gisagara District', TO_DATE('1982-04-04', 'YYYY-MM-DD'), 'Brother, manages family business');

-- Demo Executor
INSERT INTO executors (executor_id, will_id, full_name, email, phone_number, relation, is_primary)
VALUES (1, 1, 'Solange Mukamana', 'solange.mukamana@lawfirm.rw', '+250786000111', 'Family Lawyer', 'Y');

-- Demo Asset Assignments (using your stored procedure)
-- Run these one by one to test the procedure

-- Assign house to son (60%)
BEGIN
    assign_asset_to_beneficiary(1, 1, 60, 'Primary residence inheritance');
END;
/

-- Assign house to daughter (40%)
BEGIN
    assign_asset_to_beneficiary(1, 2, 40, 'Shared ownership of family home');
END;
/

-- Assign savings to all three beneficiaries
BEGIN
    assign_asset_to_beneficiary(2, 1, 50, 'For education and future');
END;
/

BEGIN
    assign_asset_to_beneficiary(2, 2, 30, 'For education expenses');
END;
/

BEGIN
    assign_asset_to_beneficiary(2, 3, 20, 'Support for business');
END;
/

-- Assign vehicle to son
BEGIN
    assign_asset_to_beneficiary(3, 1, 100, 'Family vehicle for transportation');
END;
/

-- ============================================================================
-- HOLIDAY DATA FOR TESTING TRANSFER RESTRICTIONS
-- ============================================================================

-- Add some holidays to test the weekend/holiday transfer blocking
INSERT INTO holidays (holiday_date, description, is_recurring)
VALUES (TO_DATE('2025-01-01', 'YYYY-MM-DD'), 'New Year Day', 'Y');

INSERT INTO holidays (holiday_date, description, is_recurring)
VALUES (TO_DATE('2025-07-01', 'YYYY-MM-DD'), 'Independence Day', 'Y');

INSERT INTO holidays (holiday_date, description, is_recurring)
VALUES (TO_DATE('2025-12-25', 'YYYY-MM-DD'), 'Christmas Day', 'Y');

INSERT INTO holidays (holiday_date, description, is_recurring)
VALUES (TO_DATE('2025-04-07', 'YYYY-MM-DD'), 'Genocide Memorial Day', 'Y');

-- ============================================================================
-- ADDITIONAL TEST DATA FOR ADMIN FEATURES
-- ============================================================================

-- Create an admin user for testing admin features
INSERT INTO users (user_id, full_name, email, phone_number, date_of_birth, address, created_at)
VALUES (4, 'System Administrator', 'admin@digitalwill.rw', '+250788999000', 
        TO_DATE('1985-01-01', 'YYYY-MM-DD'), 'System Office, Kigali', SYSDATE);

-- Create a second will for more test data
INSERT INTO wills (will_id, user_id, title, description, status, created_at)
VALUES (2, 1, 'Business Assets Distribution', 'Distribution of business interests and investments', 'Draft', SYSDATE - 10);

-- Business assets
INSERT INTO assets (asset_id, will_id, name, description, asset_type, value, location, acquisition_date)
VALUES (4, 2, 'Retail Shop in Kimironko', 'Clothing and accessories shop', 'Business', 12000000, 'Kimironko Market', TO_DATE('2015-08-20', 'YYYY-MM-DD'));

INSERT INTO assets (asset_id, will_id, name, description, asset_type, value, location, acquisition_date)
VALUES (5, 2, 'Investment Portfolio', 'Stocks and bonds portfolio', 'Investment', 25000000, 'Kigali Stock Exchange', TO_DATE('2018-01-15', 'YYYY-MM-DD'));

-- Second executor for business will
INSERT INTO executors (executor_id, will_id, full_name, email, phone_number, relation, is_primary)
VALUES (2, 2, 'Patrick Nkurunziza', 'patrick.nk@firm.rw', '+250788999333', 'Business Partner', 'Y');

-- ============================================================================
-- COMMIT ALL CHANGES
-- ============================================================================
COMMIT;

-- ============================================================================
-- VERIFICATION QUERIES (Optional - run to verify data)
-- ============================================================================

-- Verify users
SELECT user_id, full_name, email FROM users ORDER BY user_id;

-- Verify wills
SELECT will_id, title, status, user_id FROM wills ORDER BY will_id;

-- Verify assets
SELECT asset_id, will_id, name, asset_type, value FROM assets ORDER BY asset_id;

-- Verify beneficiaries
SELECT beneficiary_id, full_name, relation, email FROM beneficiaries ORDER BY beneficiary_id;

-- Verify executors
SELECT executor_id, will_id, full_name, email, is_primary FROM executors ORDER BY executor_id;

-- Verify asset allocations
SELECT a.name as asset_name, b.full_name as beneficiary_name, wab.share_percent
FROM will_asset_beneficiaries wab
JOIN assets a ON wab.asset_id = a.asset_id
JOIN beneficiaries b ON wab.beneficiary_id = b.beneficiary_id
ORDER BY a.name, wab.share_percent DESC;

-- ============================================================================
-- DEMO TESTING SCENARIOS
-- ============================================================================

/*
After inserting this data, you can test:

1. LOGIN SCENARIOS:
   - Testator: jean.claude@example.rw (any password for demo)
   - Executor: solange.mukamana@lawfirm.rw (any password for demo)
   - Beneficiary: eric.munyaneza@example.rw (any password for demo)
   - Admin: admin@digitalwill.rw (any password for demo)

2. WILL MANAGEMENT:
   - View existing wills
   - Create new wills
   - Add assets to wills
   - Assign executors

3. ASSET ASSIGNMENT:
   - View current allocations
   - Assign remaining percentages
   - Test 100% validation

4. APPROVAL WORKFLOW:
   - Try to approve will (should work - has executor and allocations)
   - Test approval requirements

5. TRANSFER TESTING:
   - Try transfers on weekdays (should work)
   - Try transfers on weekends (should be blocked)
   - Try transfers on holidays (should be blocked)

6. REPORTING:
   - Generate will summary reports
   - View system statistics
   - Check audit logs

7. ERROR TESTING:
   - Try to over-allocate assets (>100%)
   - Try to approve will without executor
   - Try invalid operations
*/





SELECT email FROM users WHERE email IN (
    'jean.claude@example.rw',
    'solange.mukamana@lawfirm.rw', 
    'eric.munyaneza@example.rw'
);

INSERT INTO users (full_name, email, phone_number, date_of_birth, address)
VALUES ('Solange Mukamana', 'solange.mukamana@lawfirm.rw', '+250786000111', 
        TO_DATE('1975-09-12', 'YYYY-MM-DD'), 'Kigali, Nyarugenge District');

COMMIT;