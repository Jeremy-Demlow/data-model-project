-- ============================================
-- ETL: Dim_Customer - BULK LOAD
-- ============================================
-- Purpose: Full refresh of customer dimension (Type 1)
-- Source: tenant_lake.raw_real.customer
-- ============================================

USE DATABASE ENG_STAGING;
USE SCHEMA BRANDT_REPORT_DM;

UPDATE ETL_Watermark
SET LastRunStart = CURRENT_TIMESTAMP(), LastRunStatus = 'RUNNING'
WHERE ProcessName = 'Dim_Customer';
COMMIT;

TRUNCATE TABLE Dim_Customer;

INSERT INTO Dim_Customer (
    CustomerId, TenantId, CustomerName,
    IsActive, LoadDateTime, UpdatedDateTime
)
SELECT
    c.id AS CustomerId,
    c._tenant_id AS TenantId,
    c.name AS CustomerName,
    c.active AS IsActive,
    CURRENT_TIMESTAMP() AS LoadDateTime,
    CURRENT_TIMESTAMP() AS UpdatedDateTime
FROM tenant_lake.raw_real.customer c
WHERE c._tenant_id IN (3457543957);

COMMIT;

UPDATE ETL_Watermark
SET LastRunEnd = CURRENT_TIMESTAMP(), LastRunStatus = 'SUCCESS',
    LastSuccessfulRunEnd = CURRENT_TIMESTAMP(),
    RowsProcessed = (SELECT COUNT(*) FROM Dim_Customer),
    UpdatedDateTime = CURRENT_TIMESTAMP()
WHERE ProcessName = 'Dim_Customer';
COMMIT;
