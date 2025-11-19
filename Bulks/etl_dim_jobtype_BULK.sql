-- ============================================
-- ETL: Dim_JobType - BULK LOAD
-- ============================================
-- Purpose: Full refresh of job type dimension (Type 1)
-- Source: tenant_lake.raw_real.jobtype
-- ============================================

USE DATABASE ENG_STAGING;USE SCHEMA BRANDT_REPORT_DM;UPDATE ETL_Watermark
SET LastRunStart = CURRENT_TIMESTAMP(), LastRunStatus = 'RUNNING'
WHERE ProcessName = 'Dim_JobType';
COMMIT;

TRUNCATE TABLE Dim_JobType;

INSERT INTO Dim_JobType (
    JobTypeId, TenantId, JobTypeName,
    IsActive, LoadDateTime, UpdatedDateTime
)
SELECT
    jt.id AS JobTypeId,
    jt._tenant_id AS TenantId,
    jt.name AS JobTypeName,
    1 AS IsActive,  -- Implied in source filtering
    CURRENT_TIMESTAMP() AS LoadDateTime,
    CURRENT_TIMESTAMP() AS UpdatedDateTime
FROM tenant_lake.raw_real.jobtype jt
WHERE jt._tenant_id IN (3457543957);

COMMIT;UPDATE ETL_Watermark
SET LastRunEnd = CURRENT_TIMESTAMP(), LastRunStatus = 'SUCCESS',
    LastSuccessfulRunEnd = CURRENT_TIMESTAMP(),
    RowsProcessed = (SELECT COUNT(*) FROM Dim_JobType),
    UpdatedDateTime = CURRENT_TIMESTAMP()
WHERE ProcessName = 'Dim_JobType';
COMMIT;
