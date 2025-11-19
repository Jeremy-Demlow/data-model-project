-- ============================================
-- ETL: Dim_Location - BULK LOAD
-- ============================================
-- Purpose: Full refresh of location dimension (Type 1)
-- Source: tenant_lake.raw_real.location
-- ============================================

USE DATABASE ENG_STAGING;USE SCHEMA BRANDT_REPORT_DM;UPDATE ETL_Watermark
SET LastRunStart = CURRENT_TIMESTAMP(), LastRunStatus = 'RUNNING'
WHERE ProcessName = 'Dim_Location';
COMMIT;

TRUNCATE TABLE Dim_Location;

INSERT INTO Dim_Location (
    LocationId, TenantId, LocationName,
    IsActive, LoadDateTime, UpdatedDateTime
)
SELECT
    l.id AS LocationId,
    l._tenant_id AS TenantId,
    l.name AS LocationName,
    1 AS IsActive,  -- Implied in source filtering
    CURRENT_TIMESTAMP() AS LoadDateTime,
    CURRENT_TIMESTAMP() AS UpdatedDateTime
FROM tenant_lake.raw_real.location l
WHERE l._tenant_id IN (3457543957);

COMMIT;UPDATE ETL_Watermark
SET LastRunEnd = CURRENT_TIMESTAMP(), LastRunStatus = 'SUCCESS',
    LastSuccessfulRunEnd = CURRENT_TIMESTAMP(),
    RowsProcessed = (SELECT COUNT(*) FROM Dim_Location),
    UpdatedDateTime = CURRENT_TIMESTAMP()
WHERE ProcessName = 'Dim_Location';
COMMIT;
