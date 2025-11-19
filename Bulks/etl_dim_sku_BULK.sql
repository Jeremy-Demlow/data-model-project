-- ============================================
-- ETL: Dim_SKU - BULK LOAD
-- ============================================
-- Purpose: Full refresh of SKU dimension (Type 1)
-- Source: tenant_lake.raw_real.material, equipment
-- NOTE: Only ID used in original SQL for existence checks
-- ============================================

USE DATABASE ENG_STAGING;USE SCHEMA BRANDT_REPORT_DM;UPDATE ETL_Watermark
SET LastRunStart = CURRENT_TIMESTAMP(), LastRunStatus = 'RUNNING'
WHERE ProcessName = 'Dim_SKU';
COMMIT;

TRUNCATE TABLE Dim_SKU;

-- Material SKUs
INSERT INTO Dim_SKU (
    SKUId, SKUType, TenantId,
    IsActive, LoadDateTime, UpdatedDateTime
)
SELECT
    m.id AS SKUId,
    1 AS SKUType,  -- 1 = Material
    m._tenant_id AS TenantId,
    1 AS IsActive,  -- Implied in source filtering
    CURRENT_TIMESTAMP() AS LoadDateTime,
    CURRENT_TIMESTAMP() AS UpdatedDateTime
FROM tenant_lake.raw_real.material m
WHERE m._tenant_id IN (3457543957);

-- Equipment SKUs
INSERT INTO Dim_SKU (
    SKUId, SKUType, TenantId,
    IsActive, LoadDateTime, UpdatedDateTime
)
SELECT
    e.id AS SKUId,
    2 AS SKUType,  -- 2 = Equipment
    e._tenant_id AS TenantId,
    1 AS IsActive,  -- Implied in source filtering
    CURRENT_TIMESTAMP() AS LoadDateTime,
    CURRENT_TIMESTAMP() AS UpdatedDateTime
FROM tenant_lake.raw_real.equipment e
WHERE e._tenant_id IN (3457543957);

COMMIT;UPDATE ETL_Watermark
SET LastRunEnd = CURRENT_TIMESTAMP(), LastRunStatus = 'SUCCESS',
    LastSuccessfulRunEnd = CURRENT_TIMESTAMP(),
    RowsProcessed = (SELECT COUNT(*) FROM Dim_SKU),
    UpdatedDateTime = CURRENT_TIMESTAMP()
WHERE ProcessName = 'Dim_SKU';
COMMIT;
