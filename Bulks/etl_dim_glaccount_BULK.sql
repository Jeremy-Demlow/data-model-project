-- ============================================
-- ETL: Dim_GLAccount - BULK LOAD
-- ============================================
-- Purpose: Full refresh of GL account dimension (Type 1)
-- Source: tenant_lake.raw_real.generalledgeraccount, generalledgeraccounttype
-- NOTE: Only type.name used in original SQL for '%income%' filtering
-- ============================================

USE DATABASE ENG_STAGING;
USE SCHEMA BRANDT_REPORT_DM;

UPDATE ETL_Watermark
SET LastRunStart = CURRENT_TIMESTAMP(), LastRunStatus = 'RUNNING'
WHERE ProcessName = 'Dim_GLAccount';
COMMIT;

TRUNCATE TABLE Dim_GLAccount;
INSERT INTO Dim_GLAccount (
    GLAccountId, TenantId, GLAccountTypeId, GLAccountType,
    IsActive, LoadDateTime, UpdatedDateTime
)
SELECT
    ga.id AS GLAccountId,
    ga._tenant_id AS TenantId,
    ga.type_id AS GLAccountTypeId,
    gt.name AS GLAccountType,
    1 AS IsActive,  -- Implied in source filtering
    CURRENT_TIMESTAMP() AS LoadDateTime,
    CURRENT_TIMESTAMP() AS UpdatedDateTime
FROM tenant_lake.raw_real.generalledgeraccount ga
LEFT JOIN tenant_lake.raw_real.generalledgeraccounttype gt
    ON gt.id = ga.type_id
   AND gt._tenant_id = ga._tenant_id
   AND gt._tenant_id IN (3457543957)
WHERE ga._tenant_id IN (3457543957);

COMMIT;

UPDATE ETL_Watermark
SET LastRunEnd = CURRENT_TIMESTAMP(), LastRunStatus = 'SUCCESS',
    LastSuccessfulRunEnd = CURRENT_TIMESTAMP(),
    RowsProcessed = (SELECT COUNT(*) FROM Dim_GLAccount),
    UpdatedDateTime = CURRENT_TIMESTAMP()
WHERE ProcessName = 'Dim_GLAccount';
COMMIT;
