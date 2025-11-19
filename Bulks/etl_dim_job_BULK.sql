-- ============================================
-- ETL: Dim_Job - BULK LOAD
-- ============================================
-- Purpose: Full refresh of job dimension (Type 1)
-- Source: tenant_lake.raw_real.job
-- ============================================

USE DATABASE ENG_STAGING;
USE SCHEMA BRANDT_REPORT_DM;

UPDATE ETL_Watermark
SET LastRunStart = CURRENT_TIMESTAMP(), LastRunStatus = 'RUNNING'
WHERE ProcessName = 'Dim_Job';
COMMIT;

TRUNCATE TABLE Dim_Job;

INSERT INTO Dim_Job (
    JobId, TenantId, JobSummary, ServiceAgreementId,
    IsActive, LoadDateTime, UpdatedDateTime
)
SELECT
    j.id AS JobId,
    j._tenant_id AS TenantId,
    j.summary AS JobSummary,
    CAST(NULL AS NUMBER) /*j.service_agreement_id*/ AS ServiceAgreementId,
    j.active AS IsActive,
    CURRENT_TIMESTAMP() AS LoadDateTime,
    CURRENT_TIMESTAMP() AS UpdatedDateTime
FROM tenant_lake.raw_real.job j
WHERE j._tenant_id IN (3457543957);

COMMIT;

UPDATE ETL_Watermark
SET LastRunEnd = CURRENT_TIMESTAMP(), LastRunStatus = 'SUCCESS',
    LastSuccessfulRunEnd = CURRENT_TIMESTAMP(),
    RowsProcessed = (SELECT COUNT(*) FROM Dim_Job),
    UpdatedDateTime = CURRENT_TIMESTAMP()
WHERE ProcessName = 'Dim_Job';
COMMIT;
