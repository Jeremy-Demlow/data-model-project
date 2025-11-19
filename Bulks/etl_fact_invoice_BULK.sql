-- ============================================
-- ETL: Fact_Invoice - BULK LOAD
-- ============================================
-- Purpose: Full refresh of invoice fact by joining Layer 1 measure tables
-- Prerequisite: Layer 1 measure tables must be loaded first
-- ============================================

USE DATABASE ENG_STAGING;
USE SCHEMA BRANDT_REPORT_DM;

UPDATE ETL_Watermark
SET LastRunStart = CURRENT_TIMESTAMP(), LastRunStatus = 'RUNNING'
WHERE ProcessName = 'Fact_Invoice';
COMMIT;

-- Truncate fact table
TRUNCATE TABLE Fact_Invoice;

INSERT INTO Fact_Invoice (
    InvoiceId, JobId, TenantId,
    DateKey, CustomerKey, LocationKey, BusinessUnitKey,
    JobTypeKey, EmployeeKey, JobKey,
    -- InvoicedOn,
    -- PostedDate,
    InvoiceDate, TransactionNumber,
    InvoiceStatus, IsAdjustment, AdjustmentToInvoiceId,
    TotalRevenue, IncomeRevenue, LineItemCount,
    EquipmentCost, MaterialCost, TotalItemCost,
    POUnbilledCost, POBilledCost, TotalPOCost, POCount,
    RegularLaborCost, PieceworkCost, LaborBurdenCost, PayrollAdjustmentCost, TotalLaborCost,
    RegularLaborHours, PieceworkHours,
    LoadDateTime, UpdatedDateTime
)
SELECT
    rev.InvoiceId,
    rev.JobId,
    rev.TenantId,

    -- Dimension Keys (surrogate keys from dimension tables)
    dd.DateKey,
    dc.CustomerKey,
    dl.LocationKey,
    dbu.BusinessUnitKey,
    djt.JobTypeKey,
    de.EmployeeKey,
    dj.JobKey,

    -- Date attributes
    -- rev.invoicedon,
    -- rev.PostedDate,
    rev.InvoiceDate,
    rev.TransactionNumber,
    rev.InvoiceStatus,
    IFF(i.adjustmentto_id IS NOT NULL, TRUE, FALSE) AS IsAdjustment,
    i.adjustmentto_id AS AdjustmentToInvoiceId,

    -- Revenue measures (from Mat_Invoice_Revenue)
    COALESCE(rev.TotalRevenue, 0) AS TotalRevenue,
    COALESCE(rev.IncomeRevenue, 0) AS IncomeRevenue,
    COALESCE(rev.LineItemCount, 0) AS LineItemCount,

    -- Material cost measures (from Mat_Invoice_MaterialCosts)
    COALESCE(mat.EquipmentCost, 0) AS EquipmentCost,
    COALESCE(mat.MaterialCost, 0) AS MaterialCost,
    COALESCE(mat.TotalItemCost, 0) AS TotalItemCost,

    -- PO cost measures (from Mat_Invoice_POCosts)
    COALESCE(po.POUnbilledCost, 0) AS POUnbilledCost,
    COALESCE(po.POBilledCost, 0) AS POBilledCost,
    COALESCE(po.TotalPOCost, 0) AS TotalPOCost,
    COALESCE(po.POCount, 0) AS POCount,

    -- Labor cost measures (from Mat_Invoice_LaborCosts)
    COALESCE(lab.RegularLaborCost, 0) AS RegularLaborCost,
    COALESCE(lab.PieceworkCost, 0) AS PieceworkCost,
    COALESCE(lab.LaborBurdenCost, 0) AS LaborBurdenCost,
    COALESCE(lab.PayrollAdjustmentCost, 0) AS PayrollAdjustmentCost,
    COALESCE(lab.TotalLaborCost, 0) AS TotalLaborCost,
    COALESCE(lab.RegularLaborHours, 0) AS RegularLaborHours,
    COALESCE(lab.PieceworkHours, 0) AS PieceworkHours,

    CURRENT_TIMESTAMP() AS LoadDateTime,
    CURRENT_TIMESTAMP() AS UpdatedDateTime
FROM Mat_Invoice_Revenue rev
INNER JOIN tenant_lake.raw_real.invoice i
    ON i.id = rev.InvoiceId AND i._tenant_id = rev.TenantId
INNER JOIN tenant_lake.raw_real.job j
    ON j.id = rev.JobId AND j._tenant_id = rev.TenantId
LEFT JOIN Mat_Invoice_MaterialCosts mat ON mat.InvoiceId = rev.InvoiceId
LEFT JOIN Mat_Invoice_POCosts po ON po.InvoiceId = rev.InvoiceId
LEFT JOIN Mat_Invoice_LaborCosts lab ON lab.InvoiceId = rev.InvoiceId
-- Dimension joins
-- LEFT JOIN Dim_Date dd ON dd.Date = rev.invoicedon
LEFT JOIN Dim_Date dd ON dd.Date = rev.InvoiceDate
LEFT JOIN Dim_Customer dc ON dc.CustomerId = j.customer_id AND dc.TenantId = rev.TenantId
LEFT JOIN Dim_Location dl ON dl.LocationId = j.location_id AND dl.TenantId = rev.TenantId
LEFT JOIN Dim_BusinessUnit dbu ON dbu.BusinessUnitId = j.businessunit_id AND dbu.TenantId = rev.TenantId
LEFT JOIN Dim_JobType djt ON djt.JobTypeId = j.type_id AND djt.TenantId = rev.TenantId
LEFT JOIN Dim_Job dj ON dj.JobId = j.id AND dj.TenantId = rev.TenantId
-- Employee (salesperson) from custom field
LEFT JOIN (
    SELECT DISTINCT
        cf.owner_id AS job_id,
        s.EMPLOYEEID AS employee_id
    FROM tenant_lake.raw_real.customfield cf
    INNER JOIN tenant_lake.raw_real.customfieldtype cft
        ON cft.id = cf.type_id
       AND cft.name ILIKE '%Salesperson%'
       AND cft.active = 1
    INNER JOIN Mat_Employee_CommissionRates s
        ON TRIM(s.EmployeeName) = TRIM(cf.value)
       AND s.TenantId = cf._tenant_id
    WHERE cf.active = 1
) emp
    ON emp.job_id = j.id
LEFT JOIN Dim_Employee de ON de.EmployeeId = emp.employee_id AND de.TenantId = rev.TenantId;

COMMIT;

UPDATE ETL_Watermark
SET LastRunEnd = CURRENT_TIMESTAMP(), LastRunStatus = 'SUCCESS',
    LastSuccessfulRunEnd = CURRENT_TIMESTAMP(),
    RowsProcessed = (SELECT COUNT(*) FROM Fact_Invoice),
    UpdatedDateTime = CURRENT_TIMESTAMP()
WHERE ProcessName = 'Fact_Invoice';
COMMIT;
