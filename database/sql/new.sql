-- Create your PDB
CREATE PLUGGABLE DATABASE tues_27066_japhet_digitalwill_db 
ADMIN USER tues_27066_japhet_digitalwill_db IDENTIFIED BY japhet
FILE_NAME_CONVERT = (
    'C:\APP\HP\PRODUCT\21C\ORADATA\XE\PDBSEED\', 
    'C:\APP\HP\PRODUCT\21C\ORADATA\XE\tues_27066_japhet_digitalwill_db\'
);

-- Open it
ALTER PLUGGABLE DATABASE tues_27066_japhet_digitalwill_db OPEN;

-- Save state
ALTER PLUGGABLE DATABASE tues_27066_japhet_digitalwill_db SAVE STATE;

-- Grant privileges
ALTER SESSION SET CONTAINER = tues_27066_japhet_digitalwill_db;
GRANT DBA TO tues_27066_japhet_digitalwill_db;
GRANT UNLIMITED TABLESPACE TO tues_27066_japhet_digitalwill_db;


SELECT 
    USER AS current_user,
    sys_context('USERENV', 'CON_NAME') AS container_name,
    sys_context('USERENV', 'SERVICE_NAME') AS service_name,
    SYSDATE AS current_time
FROM dual;