-- ============================================
-- ETL: Mat_Employee_CommissionRates - BULK LOAD
-- ============================================
-- Purpose: Full refresh of employee commission rates (Type 1 - current state)
-- Source: Employee custom fields
-- ============================================

USE DATABASE ENG_STAGING;
USE SCHEMA BRANDT_REPORT_DM;

UPDATE ETL_Watermark 
SET LastRunStart = CURRENT_TIMESTAMP(), LastRunStatus = 'RUNNING'
WHERE ProcessName = 'Mat_Employee_CommissionRates';
COMMIT;

TRUNCATE TABLE Mat_Employee_CommissionRates;

INSERT INTO Mat_Employee_CommissionRates (
    EmployeeId,
    TenantId,
    EmployeeName,
    EmployeeType,
    CommissionType,
    JobCommissionPct,
    SAYear1CommissionPct,
    SAYear2CommissionPct,
    SAYear3PlusCommissionPct,
    LoadDateTime,
    UpdatedDateTime
)
WITH 
-- Get all employees who could be salespeople
salesperson AS (
    SELECT 
        e.id AS EmployeeId,
        e._tenant_id AS TenantId,
        e.name AS EmployeeName,
        'Employee' AS EmployeeType
    FROM tenant_lake.raw_real.employee e
    WHERE e.active = 1
      AND e._tenant_id IN (3457543957)
),
-- Get employee custom fields with commission data
employee_cf_raw AS (
    SELECT 
        cf.owner_id AS EmployeeId,
        cf._tenant_id AS TenantId,
        REPLACE(cft.name, ' ', '') || 'Employee' AS cf_name,
        cf.value AS cf_value,
        ROW_NUMBER() OVER (PARTITION BY cf.owner_id, cft.id ORDER BY cf.createdon DESC) AS rn
    FROM tenant_lake.raw_real.customfield cf
    INNER JOIN tenant_lake.raw_real.customfieldtype cft
        ON cft.id = cf.type_id
       AND cft.active = 1
       AND BITAND(cft.ownertype, 32) = 32  -- Employee owner type
       AND cft._tenant_id = cf._tenant_id
    WHERE cf.active = 1
      AND cf._tenant_id IN (3457543957)
      AND EXISTS (
          SELECT 1 FROM salesperson s 
          WHERE s.EmployeeId = cf.owner_id 
            AND s.TenantId = cf._tenant_id
      )
),
-- Pivot custom fields
employee_cf AS (
    SELECT
        EmployeeId,
        TenantId,
        MAX(CASE WHEN cf_name = 'CommissionTypeEmployee' THEN TRY_TO_DECIMAL(cf_value, 10, 2) END) AS CommissionType,
        MAX(CASE WHEN cf_name = 'JobCommission%Employee' THEN TRY_TO_DECIMAL(cf_value, 10, 2) END) AS JobCommissionPct,
        MAX(CASE WHEN cf_name = 'SAYear1Commission%Employee' THEN TRY_TO_DECIMAL(cf_value, 10, 2) END) AS SAYear1CommissionPct,
        MAX(CASE WHEN cf_name = 'SAYear2Commission%Employee' THEN TRY_TO_DECIMAL(cf_value, 10, 2) END) AS SAYear2CommissionPct,
        MAX(CASE WHEN cf_name = 'SAYear3+Commission%Employee' THEN TRY_TO_DECIMAL(cf_value, 10, 2) END) AS SAYear3PlusCommissionPct
    FROM employee_cf_raw
    WHERE rn = 1
    GROUP BY EmployeeId, TenantId
)
SELECT 
    sp.EmployeeId,
    sp.TenantId,
    sp.EmployeeName,
    sp.EmployeeType,
    COALESCE(ecf.CommissionType, 0) AS CommissionType,
    COALESCE(ecf.JobCommissionPct, 0) AS JobCommissionPct,
    COALESCE(ecf.SAYear1CommissionPct, 0) AS SAYear1CommissionPct,
    COALESCE(ecf.SAYear2CommissionPct, 0) AS SAYear2CommissionPct,
    COALESCE(ecf.SAYear3PlusCommissionPct, 0) AS SAYear3PlusCommissionPct,
    CURRENT_TIMESTAMP() AS LoadDateTime,
    CURRENT_TIMESTAMP() AS UpdatedDateTime
FROM salesperson sp
LEFT JOIN employee_cf ecf 
    ON ecf.EmployeeId = sp.EmployeeId 
   AND ecf.TenantId = sp.TenantId
WHERE ecf.EmployeeId IS NOT NULL;  -- Only include employees with commission rates

COMMIT;

UPDATE ETL_Watermark 
SET LastRunEnd = CURRENT_TIMESTAMP(),
    LastRunStatus = 'SUCCESS',
    LastSuccessfulRunEnd = CURRENT_TIMESTAMP(),
    RowsProcessed = (SELECT COUNT(*) FROM Mat_Employee_CommissionRates),
    UpdatedDateTime = CURRENT_TIMESTAMP()
WHERE ProcessName = 'Mat_Employee_CommissionRates';
COMMIT;

