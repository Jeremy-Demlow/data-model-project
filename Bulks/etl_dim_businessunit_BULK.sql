-- ============================================
-- ETL: Dim_BusinessUnit - BULK LOAD
-- ============================================
-- Purpose: Full refresh of business unit dimension (Type 1)
-- Source: tenant_lake.raw_real.businessunit
-- ============================================

USE DATABASE ENG_STAGING;
USE SCHEMA BRANDT_REPORT_DM;

UPDATE ETL_Watermark
SET LastRunStart = CURRENT_TIMESTAMP(), LastRunStatus = 'RUNNING'
WHERE ProcessName = 'Dim_BusinessUnit';
COMMIT;

TRUNCATE TABLE Dim_BusinessUnit;

INSERT INTO Dim_BusinessUnit (
    BusinessUnitId, TenantId, BusinessUnitName,
    IsActive, LoadDateTime, UpdatedDateTime
)
SELECT
    bu.id AS BusinessUnitId,
    bu._tenant_id AS TenantId,
    bu.name AS BusinessUnitName,
    1 AS IsActive,  -- Implied in source filtering
    CURRENT_TIMESTAMP() AS LoadDateTime,
    CURRENT_TIMESTAMP() AS UpdatedDateTime
FROM tenant_lake.raw_real.businessunit bu
WHERE bu._tenant_id IN (3457543957);

COMMIT;

USE DATABASE ENG_STAGING;
USE SCHEMA BRANDT_REPORT_DM;

UPDATE ETL_Watermark
SET LastRunEnd = CURRENT_TIMESTAMP(), LastRunStatus = 'SUCCESS',
    LastSuccessfulRunEnd = CURRENT_TIMESTAMP(),
    RowsProcessed = (SELECT COUNT(*) FROM Dim_BusinessUnit),
    UpdatedDateTime = CURRENT_TIMESTAMP()
WHERE ProcessName = 'Dim_BusinessUnit';
COMMIT;
