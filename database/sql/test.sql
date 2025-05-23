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

COMMIT;