-- ============================================
-- ETL: Mat_Invoice_LaborCosts - BULK LOAD
-- ============================================
-- Purpose: Full refresh of labor costs
-- Source: grosspayitem, employeegrosspayitem, technician, payrolladjustment, employeepayrolladjustment
-- ============================================

USE DATABASE ENG_STAGING;
USE SCHEMA BRANDT_REPORT_DM;

UPDATE ETL_Watermark 
SET LastRunStart = CURRENT_TIMESTAMP(), LastRunStatus = 'RUNNING'
WHERE ProcessName = 'Mat_Invoice_LaborCosts';
COMMIT;

TRUNCATE TABLE Mat_Invoice_LaborCosts;

INSERT INTO Mat_Invoice_LaborCosts (
    InvoiceId, TenantId, JobId, PostedDate, InvoiceModifiedOn, LastLaborModifiedOn,
    RegularLaborCost, PieceworkCost, LaborBurdenCost, PayrollAdjustmentCost, TotalLaborCost,
    RegularLaborHours, PieceworkHours, LoadDateTime, UpdatedDateTime
)
WITH grosspay AS (
    -- Union grosspayitem and employeegrosspayitem
    SELECT 
        g.job_id, g.invoice_id, g._tenant_id, g.amount, g.paiddurationhours, 
        g.grosspayitemtype, g.burdencostamount, g.technician_id, g._record_updated_ts_utc
    FROM tenant_lake.raw_real.grosspayitem g
    WHERE g.active = 1 AND g._tenant_id IN (3457543957)
    UNION ALL
    SELECT 
        eg.job_id, eg.invoice_id, eg._tenant_id, eg.amount, eg.paiddurationhours,
        eg.grosspayitemtype, 0 AS burdencostamount, eg.employee_id AS technician_id, eg._record_updated_ts_utc
    FROM tenant_lake.raw_real.employeegrosspayitem eg
    WHERE eg.active = 1 AND eg._tenant_id IN (3457543957)
),
payroll_adj AS (
    -- Union payrolladjustment and employeepayrolladjustment
    SELECT pa.invoice_id, pa._tenant_id, pa.amount, pa._record_updated_ts_utc
    FROM tenant_lake.raw_real.payrolladjustment pa
    WHERE pa.active = 1 AND pa._tenant_id IN (3457543957)
    UNION ALL
    SELECT epa.invoice_id, epa._tenant_id, epa.amount, epa._record_updated_ts_utc
    FROM tenant_lake.raw_real.employeepayrolladjustment epa
    WHERE epa.active = 1 AND epa._tenant_id IN (3457543957)
)
SELECT 
    i.id AS InvoiceId,
    i._tenant_id AS TenantId,
    i.job_id AS JobId,
    CAST(i.invoicedon AS DATE) AS PostedDate,
    i.modifiedon AS InvoiceModifiedOn,
    MAX(COALESCE(gp._record_updated_ts_utc, pa._record_updated_ts_utc)) AS LastLaborModifiedOn,
    
    -- Regular Labor (grosspayitemtype 2,4)
    COALESCE(SUM(CASE WHEN gp.grosspayitemtype IN (2,4) THEN gp.amount ELSE 0 END), 0) AS RegularLaborCost,
    
    -- Piecework (grosspayitemtype 1,3)
    COALESCE(SUM(CASE WHEN gp.grosspayitemtype IN (1,3) THEN gp.amount ELSE 0 END), 0) AS PieceworkCost,
    
    -- Labor Burden (from grosspayitem.burdencostamount or technician.burdenrate × hours)
    COALESCE(SUM(
        CASE 
            WHEN gp.burdencostamount IS NOT NULL AND gp.burdencostamount > 0 THEN gp.burdencostamount
            WHEN t.burdenrate IS NOT NULL THEN t.burdenrate * gp.paiddurationhours
            ELSE 0 
        END
    ), 0) AS LaborBurdenCost,
    
    -- Payroll Adjustments
    COALESCE(SUM(pa.amount), 0) AS PayrollAdjustmentCost,
    
    -- Total Labor Cost
    COALESCE(SUM(gp.amount), 0) + COALESCE(SUM(pa.amount), 0) + 
    COALESCE(SUM(
        CASE 
            WHEN gp.burdencostamount IS NOT NULL AND gp.burdencostamount > 0 THEN gp.burdencostamount
            WHEN t.burdenrate IS NOT NULL THEN t.burdenrate * gp.paiddurationhours
            ELSE 0 
        END
    ), 0) AS TotalLaborCost,
    
    -- Hours
    COALESCE(SUM(CASE WHEN gp.grosspayitemtype IN (2,4) THEN gp.paiddurationhours ELSE 0 END), 0) AS RegularLaborHours,
    COALESCE(SUM(CASE WHEN gp.grosspayitemtype IN (1,3) THEN gp.paiddurationhours ELSE 0 END), 0) AS PieceworkHours,
    
    CURRENT_TIMESTAMP() AS LoadDateTime,
    CURRENT_TIMESTAMP() AS UpdatedDateTime
FROM tenant_lake.raw_real.invoice i
LEFT JOIN grosspay gp ON gp.invoice_id = i.id AND gp._tenant_id = i._tenant_id
LEFT JOIN tenant_lake.raw_real.technician t ON t.id = gp.technician_id AND t._tenant_id = gp._tenant_id
LEFT JOIN payroll_adj pa ON pa.invoice_id = i.id AND pa._tenant_id = i._tenant_id
WHERE i.active = 1
  AND i.status = 2
  AND i._tenant_id IN (3457543957)
  AND CAST(i.invoicedon AS DATE) BETWEEN '2025-10-01' AND '2025-10-31' --BETWEEN CAST(:From AS DATE) AND CAST(:To AS DATE)
  AND (gp.invoice_id IS NOT NULL OR pa.invoice_id IS NOT NULL)
GROUP BY i.id, i._tenant_id, i.job_id, i.invoicedon, i.modifiedon;

COMMIT;

UPDATE ETL_Watermark 
SET LastRunEnd = CURRENT_TIMESTAMP(), LastRunStatus = 'SUCCESS',
    LastSuccessfulRunEnd = CURRENT_TIMESTAMP(),
    RowsProcessed = (SELECT COUNT(*) FROM Mat_Invoice_LaborCosts),
    UpdatedDateTime = CURRENT_TIMESTAMP()
WHERE ProcessName = 'Mat_Invoice_LaborCosts';
COMMIT;

