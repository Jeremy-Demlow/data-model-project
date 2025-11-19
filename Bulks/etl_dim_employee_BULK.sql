-- ============================================
-- ETL: Dim_Employee - BULK LOAD
-- ============================================
-- Purpose: Full refresh of employee dimension (Type 1)
-- Source: tenant_lake.raw_real.employee
-- ============================================

USE DATABASE ENG_STAGING;USE SCHEMA BRANDT_REPORT_DM;UPDATE ETL_Watermark
SET LastRunStart = CURRENT_TIMESTAMP(), LastRunStatus = 'RUNNING'
WHERE ProcessName = 'Dim_Employee';
COMMIT;

TRUNCATE TABLE Dim_Employee;

INSERT INTO Dim_Employee (
    EmployeeId, TenantId, EmployeeName, EmployeeType,
    IsActive, LoadDateTime, UpdatedDateTime
)
SELECT
    e.id AS EmployeeId,
    e._tenant_id AS TenantId,
    e.name AS EmployeeName,
    'Employee' AS EmployeeType,  -- Hardcoded as in salesperson CTE
    e.active AS IsActive,
    CURRENT_TIMESTAMP() AS LoadDateTime,
    CURRENT_TIMESTAMP() AS UpdatedDateTime
FROM tenant_lake.raw_real.employee e
WHERE e._tenant_id IN (3457543957);

COMMIT;UPDATE ETL_Watermark
SET LastRunEnd = CURRENT_TIMESTAMP(), LastRunStatus = 'SUCCESS',
    LastSuccessfulRunEnd = CURRENT_TIMESTAMP(),
    RowsProcessed = (SELECT COUNT(*) FROM Dim_Employee),
    UpdatedDateTime = CURRENT_TIMESTAMP()
WHERE ProcessName = 'Dim_Employee';
COMMIT;
