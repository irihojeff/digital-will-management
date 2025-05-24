-- Clear existing data
DELETE FROM transfer_logs;
DELETE FROM will_asset_beneficiaries;
DELETE FROM documents;
DELETE FROM assets;
DELETE FROM executors;
DELETE FROM will_status_history;
DELETE FROM wills;
DELETE FROM beneficiaries;
DELETE FROM users;
DELETE FROM audit_log;
COMMIT;

-- Users
INSERT INTO users (user_id, full_name, email, password_hash, phone_number, address, initial_role) 
VALUES (1, 'System Administrator', 'admin@digitalwill.rw', NULL, '+250788123456', 'Kigali, Rwanda', 'admin');

INSERT INTO users (user_id, full_name, email, password_hash, phone_number, date_of_birth, address, initial_role) 
VALUES (2, 'Jean Claude Uwimana', 'jean.claude@example.rw', NULL, '+250788234567', DATE '1975-03-15', 'Kacyiru, Gasabo, Kigali', 'testator');

INSERT INTO users (user_id, full_name, email, password_hash, phone_number, date_of_birth, address, initial_role) 
VALUES (3, 'Marie Rose Mukamana', 'marie.rose@example.rw', NULL, '+250788345678', DATE '1980-07-22', 'Kimisagara, Nyarugenge, Kigali', 'testator');

INSERT INTO users (user_id, full_name, email, password_hash, phone_number, date_of_birth, address, initial_role) 
VALUES (4, 'Solange Mukamana', 'solange.mukamana@lawfirm.rw', NULL, '+250788456789', DATE '1978-11-08', 'Remera, Gasabo, Kigali', 'executor');

INSERT INTO users (user_id, full_name, email, password_hash, phone_number, date_of_birth, address, initial_role) 
VALUES (5, 'Eric Munyaneza', 'eric.munyaneza@example.rw', NULL, '+250788567890', DATE '1995-09-12', 'Gikondo, Kicukiro, Kigali', 'beneficiary');

INSERT INTO users (user_id, full_name, email, password_hash, phone_number, date_of_birth, address, initial_role) 
VALUES (6, 'Grace Uwimana', 'grace.uwimana@example.rw', NULL, '+250788678901', DATE '1998-02-28', 'Nyamirambo, Nyarugenge, Kigali', 'beneficiary');

INSERT INTO users (user_id, full_name, email, password_hash, phone_number, date_of_birth, address, initial_role) 
VALUES (7, 'Dr. David Nzeyimana', 'david.nzeyimana@hospital.rw', NULL, '+250788789012', DATE '1970-06-03', 'Muhima, Nyarugenge, Kigali', 'testator');

-- Beneficiaries
INSERT INTO beneficiaries (beneficiary_id, full_name, relation, email, phone_number, address, date_of_birth, notes) 
VALUES (1, 'Eric Munyaneza', 'Son', 'eric.munyaneza@example.rw', '+250788567890', 'Gikondo, Kicukiro, Kigali', DATE '1995-09-12', 'Eldest son');

INSERT INTO beneficiaries (beneficiary_id, full_name, relation, email, phone_number, address, date_of_birth, notes) 
VALUES (2, 'Grace Uwimana', 'Daughter', 'grace.uwimana@example.rw', '+250788678901', 'Nyamirambo, Nyarugenge, Kigali', DATE '1998-02-28', 'Youngest daughter');

INSERT INTO beneficiaries (beneficiary_id, full_name, relation, email, phone_number, address, date_of_birth, notes) 
VALUES (3, 'Peter Uwimana', 'Son', 'peter.uwimana@gmail.com', '+250788789012', 'Kacyiru, Gasabo, Kigali', DATE '1992-11-05', 'Middle son');

INSERT INTO beneficiaries (beneficiary_id, full_name, relation, email, phone_number, address, date_of_birth, notes) 
VALUES (4, 'Esperance Mukamana', 'Wife', 'esperance.mukamana@yahoo.com', '+250788890123', 'Kacyiru, Gasabo, Kigali', DATE '1978-04-17', 'Beloved wife');

INSERT INTO beneficiaries (beneficiary_id, full_name, relation, email, phone_number, address, notes) 
VALUES (5, 'St. Joseph Orphanage', 'Charity', 'director@stjoseph.rw', '+250788901234', 'Kimisagara, Nyarugenge, Kigali', 'Local orphanage');

INSERT INTO beneficiaries (beneficiary_id, full_name, relation, email, phone_number, address, date_of_birth, notes) 
VALUES (6, 'Samuel Nzeyimana', 'Son', 'samuel.nzeyimana@student.ur.ac.rw', '+250788123457', 'UR Campus, Huye', DATE '2000-03-14', 'Medical student');

-- Wills (Fixed status values)
INSERT INTO wills (will_id, user_id, title, description, status) 
VALUES (1, 2, 'Jean Claude Uwimana Last Will and Testament', 'Comprehensive will covering all my assets', 'Draft');

INSERT INTO wills (will_id, user_id, title, description, status, approved_at) 
VALUES (2, 3, 'Marie Rose Mukamana Will', 'Simple will focusing on family business', 'Approved', SYSDATE - 10);

INSERT INTO wills (will_id, user_id, title, description, status, approved_at) 
VALUES (3, 7, 'Dr. David Nzeyimana Medical Practice Will', 'Medical practice and equipment distribution', 'Executed', SYSDATE - 20);

INSERT INTO wills (will_id, user_id, title, description, status) 
VALUES (4, 2, 'Jean Claude Business Assets Will', 'Business assets and commercial properties', 'Draft');

-- Executors
INSERT INTO executors (executor_id, will_id, full_name, email, phone_number, relation, is_primary) 
VALUES (1, 1, 'Solange Mukamana', 'solange.mukamana@lawfirm.rw', '+250788456789', 'Family Lawyer', 'Y');

INSERT INTO executors (executor_id, will_id, full_name, email, phone_number, relation, is_primary) 
VALUES (2, 1, 'Peter Uwimana', 'peter.uwimana@gmail.com', '+250788789012', 'Son', 'N');

INSERT INTO executors (executor_id, will_id, full_name, email, phone_number, relation, is_primary) 
VALUES (3, 2, 'Solange Mukamana', 'solange.mukamana@lawfirm.rw', '+250788456789', 'Legal Advisor', 'Y');

INSERT INTO executors (executor_id, will_id, full_name, email, phone_number, relation, is_primary) 
VALUES (4, 3, 'Solange Mukamana', 'solange.mukamana@lawfirm.rw', '+250788456789', 'Legal Representative', 'Y');

INSERT INTO executors (executor_id, will_id, full_name, email, phone_number, relation, is_primary) 
VALUES (5, 4, 'Solange Mukamana', 'solange.mukamana@lawfirm.rw', '+250788456789', 'Business Lawyer', 'Y');

-- Assets
INSERT INTO assets (asset_id, will_id, name, description, asset_type, value, location, acquisition_date) 
VALUES (1, 1, 'Family Home Kacyiru', 'Four-bedroom family residence', 'Real Estate', 85000000, 'Kacyiru, Gasabo', DATE '2010-06-15');

INSERT INTO assets (asset_id, will_id, name, description, asset_type, value, location, acquisition_date) 
VALUES (2, 1, 'Toyota Land Cruiser V8', '2018 Toyota Land Cruiser', 'Vehicle', 35000000, 'Family Garage', DATE '2018-03-20');

INSERT INTO assets (asset_id, will_id, name, description, asset_type, value, location, acquisition_date) 
VALUES (3, 1, 'Bank Savings Account', 'Primary savings account', 'Financial', 12500000, 'Bank of Kigali', DATE '2008-01-10');

INSERT INTO assets (asset_id, will_id, name, description, asset_type, value, location, acquisition_date) 
VALUES (4, 1, 'Investment Portfolio', 'Mixed investment portfolio', 'Investment', 18700000, 'Rwanda Stock Exchange', DATE '2015-09-12');

INSERT INTO assets (asset_id, will_id, name, description, asset_type, value, location, acquisition_date) 
VALUES (5, 2, 'Commercial Building', 'Three-story commercial building', 'Real Estate', 120000000, 'Kimisagara', DATE '2012-08-30');

INSERT INTO assets (asset_id, will_id, name, description, asset_type, value, location, acquisition_date) 
VALUES (6, 2, 'Business Equipment', 'Restaurant equipment', 'Business', 8500000, 'Kimisagara Restaurant', DATE '2013-02-14');

INSERT INTO assets (asset_id, will_id, name, description, asset_type, value, location, acquisition_date) 
VALUES (7, 3, 'Medical Clinic', 'Private medical clinic', 'Real Estate', 250000000, 'Muhima', DATE '2005-11-20');

INSERT INTO assets (asset_id, will_id, name, description, asset_type, value, location, acquisition_date) 
VALUES (8, 3, 'Medical Equipment', 'Medical devices and instruments', 'Medical Equipment', 45000000, 'Medical Clinic', DATE '2006-03-15');

-- Asset Beneficiary Allocations
INSERT INTO will_asset_beneficiaries (asset_id, beneficiary_id, share_percent, conditions) 
VALUES (1, 1, 40, 'Primary residence rights');
INSERT INTO will_asset_beneficiaries (asset_id, beneficiary_id, share_percent, conditions) 
VALUES (1, 2, 35, 'Equal sharing with education priority');
INSERT INTO will_asset_beneficiaries (asset_id, beneficiary_id, share_percent, conditions) 
VALUES (1, 3, 25, 'Business development support');

INSERT INTO will_asset_beneficiaries (asset_id, beneficiary_id, share_percent, conditions) 
VALUES (2, 1, 50, 'Vehicle ownership upon graduation');
INSERT INTO will_asset_beneficiaries (asset_id, beneficiary_id, share_percent, conditions) 
VALUES (2, 3, 30, 'Business use and maintenance');

INSERT INTO will_asset_beneficiaries (asset_id, beneficiary_id, share_percent, conditions) 
VALUES (3, 4, 60, 'Wife support and family maintenance');
INSERT INTO will_asset_beneficiaries (asset_id, beneficiary_id, share_percent, conditions) 
VALUES (3, 2, 40, 'Education fund for medical school');

INSERT INTO will_asset_beneficiaries (asset_id, beneficiary_id, share_percent, conditions) 
VALUES (4, 1, 45, 'Long-term investment growth');
INSERT INTO will_asset_beneficiaries (asset_id, beneficiary_id, share_percent, conditions) 
VALUES (4, 2, 30, 'Educational development');
INSERT INTO will_asset_beneficiaries (asset_id, beneficiary_id, share_percent, conditions) 
VALUES (4, 5, 25, 'Charitable donation');

INSERT INTO will_asset_beneficiaries (asset_id, beneficiary_id, share_percent, conditions) 
VALUES (5, 1, 50, 'Business management');
INSERT INTO will_asset_beneficiaries (asset_id, beneficiary_id, share_percent, conditions) 
VALUES (5, 3, 30, 'Property maintenance');
INSERT INTO will_asset_beneficiaries (asset_id, beneficiary_id, share_percent, conditions) 
VALUES (5, 5, 20, 'Charitable use');

INSERT INTO will_asset_beneficiaries (asset_id, beneficiary_id, share_percent, conditions) 
VALUES (6, 1, 70, 'Restaurant business continuation');
INSERT INTO will_asset_beneficiaries (asset_id, beneficiary_id, share_percent, conditions) 
VALUES (6, 3, 30, 'Equipment upgrade');

INSERT INTO will_asset_beneficiaries (asset_id, beneficiary_id, share_percent, conditions) 
VALUES (7, 6, 60, 'Medical practice continuation');
INSERT INTO will_asset_beneficiaries (asset_id, beneficiary_id, share_percent, conditions) 
VALUES (7, 5, 40, 'Medical research and patient care');

INSERT INTO will_asset_beneficiaries (asset_id, beneficiary_id, share_percent, conditions) 
VALUES (8, 6, 80, 'Medical practice equipment');
INSERT INTO will_asset_beneficiaries (asset_id, beneficiary_id, share_percent, conditions) 
VALUES (8, 5, 20, 'Donated equipment');

-- Transfer Logs
INSERT INTO transfer_logs (transfer_id, asset_id, beneficiary_id, transfer_date, approved_by, transfer_status, notes) 
VALUES (1, 7, 6, SYSDATE - 10, 'solange.mukamana@lawfirm.rw', 'Completed', 'Medical clinic transferred successfully');

INSERT INTO transfer_logs (transfer_id, asset_id, beneficiary_id, transfer_date, approved_by, transfer_status, notes) 
VALUES (2, 8, 5, SYSDATE - 5, 'solange.mukamana@lawfirm.rw', 'Completed', 'Medical equipment donated');

INSERT INTO transfer_logs (transfer_id, asset_id, beneficiary_id, transfer_date, approved_by, transfer_status, notes) 
VALUES (3, 5, 1, SYSDATE - 1, 'solange.mukamana@lawfirm.rw', 'Initiated', 'Commercial building transfer initiated');

COMMIT;