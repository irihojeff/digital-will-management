
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
