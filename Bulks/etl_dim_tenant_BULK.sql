-- ETL: Dim_Tenant - BULK LOAD
-- Purpose: Load tenant dimension with hardcoded test tenant

USE DATABASE ENG_STAGING;
USE SCHEMA BRANDT_REPORT_DM;

UPDATE ETL_Watermark 
SET LastRunStart = CURRENT_TIMESTAMP(), LastRunStatus = 'RUNNING'
WHERE ProcessName = 'Dim_Tenant';

TRUNCATE TABLE Dim_Tenant;

INSERT INTO Dim_Tenant (TenantId, TenantName, TenantOfficialName, IsActive, LoadDateTime, UpdatedDateTime)
VALUES (3457543957, 'Demo Tenant', 'Demo Tenant Corp', TRUE, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP());

UPDATE ETL_Watermark 
SET LastRunEnd = CURRENT_TIMESTAMP(), LastRunStatus = 'SUCCESS',
    LastSuccessfulRunEnd = CURRENT_TIMESTAMP(),
    RowsProcessed = (SELECT COUNT(*) FROM Dim_Tenant),
    UpdatedDateTime = CURRENT_TIMESTAMP()
WHERE ProcessName = 'Dim_Tenant';

