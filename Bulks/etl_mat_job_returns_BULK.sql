-- ============================================
-- ETL: Mat_Job_Returns - BULK LOAD
-- ============================================
-- Purpose: Full refresh of job-level inventory returns
-- Source: tenant_lake.raw_real.inventoryreturn
-- Note: Returns are at JOB grain, not invoice grain
-- ============================================

USE DATABASE ENG_STAGING;
USE SCHEMA BRANDT_REPORT_DM;

UPDATE ETL_Watermark 
SET LastRunStart = CURRENT_TIMESTAMP(), LastRunStatus = 'RUNNING'
WHERE ProcessName = 'Mat_Job_Returns';
COMMIT;

TRUNCATE TABLE Mat_Job_Returns;

INSERT INTO Mat_Job_Returns (
    JobId,
    TenantId,
    LastReturnDate,
    TotalReturnCredit,
    ReturnCount,
    LoadDateTime,
    UpdatedDateTime
)
SELECT 
    rt.job_id AS JobId,
    rt._tenant_id AS TenantId,
    MAX(CAST(rt.createdon AS DATE)) AS LastReturnDate,
    
    -- Return credit (negative to reduce cost)
    -1 * SUM(rt.amount) AS TotalReturnCredit,
    
    COUNT(*) AS ReturnCount,
    
    CURRENT_TIMESTAMP() AS LoadDateTime,
    CURRENT_TIMESTAMP() AS UpdatedDateTime
FROM tenant_lake.raw_real.inventoryreturn rt
WHERE rt.active = 1
  AND rt._tenant_id IN (3457543957)
  AND rt.job_id IS NOT NULL
  AND rt.datereturned BETWEEN '2025-09-01' AND '2024-11-30'
GROUP BY rt.job_id, rt._tenant_id;

COMMIT;

UPDATE ETL_Watermark 
SET LastRunEnd = CURRENT_TIMESTAMP(),
    LastRunStatus = 'SUCCESS',
    LastSuccessfulRunEnd = CURRENT_TIMESTAMP(),
    RowsProcessed = (SELECT COUNT(*) FROM Mat_Job_Returns),
    UpdatedDateTime = CURRENT_TIMESTAMP()
WHERE ProcessName = 'Mat_Job_Returns';
COMMIT;

