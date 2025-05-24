SELECT w.will_id, w.title, w.status, u.full_name as testator_name
FROM wills w
JOIN users u ON w.user_id = u.user_id
ORDER BY w.will_id;

-- Check executors for each will
SELECT w.will_id, w.title, e.executor_id, e.full_name as executor_name, e.email, e.is_primary
FROM wills w
LEFT JOIN executors e ON w.will_id = e.will_id
ORDER BY w.will_id, e.executor_id;

-- Count executors per will
SELECT w.will_id, w.title, COUNT(e.executor_id) as executor_count
FROM wills w
LEFT JOIN executors e ON w.will_id = e.will_id
GROUP BY w.will_id, w.title
ORDER BY w.will_id;


-- Check if the data is properly inserted and linked
SELECT w.will_id, w.title, w.status, 
       e.executor_id, e.full_name, e.email, e.is_primary
FROM wills w
LEFT JOIN executors e ON w.will_id = e.will_id
WHERE w.will_id = 999;

INSERT INTO executors (executor_id, will_id, full_name, email, is_primary)
VALUES (999, 999, 'Executor Test', 'exec@test.com', 'Y');

SELECT COUNT(*) FROM JAPHET_DB.executors WHERE will_id = 999;

SELECT * FROM JAPHET_DB.executors WHERE will_id = 999;

ALTER TABLE users
ADD ( password_hash VARCHAR2(200) );
ALTER TABLE users
  ADD (role VARCHAR2(20)
  );


ALTER TABLE wills
  MODIFY (
    status VARCHAR2(20) DEFAULT 'Draft' NOT NULL
  );


  ALTER TABLE audit_log
  RENAME COLUMN "timestamp" TO event_time;

  ALTER TABLE transfer_logs
  ADD CONSTRAINT chk_transfer_status
    CHECK (transfer_status IN ('Initiated','Completed','Failed'));

    ALTER TABLE documents
  ADD CONSTRAINT chk_doc_entity
    CHECK (related_entity IN ('WILL','ASSET'));

    ALTER TABLE holidays
  MODIFY is_recurring CHAR(1) DEFAULT 'N' NOT NULL;

  CREATE INDEX idx_assets_will_id         ON assets(will_id);
CREATE INDEX idx_executors_will_id      ON executors(will_id);
CREATE INDEX idx_wab_asset_benef        ON will_asset_beneficiaries(asset_id);
CREATE INDEX idx_transfer_logs_asset    ON transfer_logs(asset_id);

SELECT column_name
FROM   user_tab_columns
WHERE  table_name = 'AUDIT_LOG';

ALTER TABLE audit_log
  RENAME COLUMN "TIMESTAMP" TO event_time;

COMMIT;




-- Step 1: First add the column
ALTER TABLE users ADD (initial_role VARCHAR2(20));


ALTER TABLE users ADD CONSTRAINT chk_initial_role 
CHECK (initial_role IN ('testator', 'executor', 'beneficiary', 'admin', 'user'));

-- Step 2: Update existing users
UPDATE users SET initial_role = 'user' WHERE initial_role IS NULL;

-- Step 3: Then add the constraint
ALTER TABLE users ADD CONSTRAINT chk_initial_role 
CHECK (initial_role IN ('testator', 'executor', 'beneficiary', 'admin', 'user'));

-- Step 4: Create index for better performance
CREATE INDEX idx_users_initial_role ON users(initial_role);


-- Step 5: Create an admin user for testing (optional)
INSERT INTO users (
    full_name, email, password_hash, phone_number, 
    address, initial_role, created_at
) VALUES (
    'System Administrator', 
    'admin@digitalwill.rw', 
    NULL,  -- Will work in demo mode (accepts any password)
    '+250788999000',
    'System Office, Kigali',
    'admin',
    SYSDATE
);

SELECT user_id, full_name, email, initial_role FROM users;


UPDATE users 
SET initial_role = 'admin' 
WHERE user_id = 4 AND email = 'admin@digitalwill.rw';


UPDATE users 
SET initial_role = 'testator' 
WHERE email = 'jean.claude@example.rw';

UPDATE users 
SET initial_role = 'executor' 
WHERE email = 'solange.mukamana@lawfirm.rw';

UPDATE users 
SET initial_role = 'beneficiary' 
WHERE email = 'eric.munyaneza@example.rw';

COMMIT;

SELECT name FROM v$database;