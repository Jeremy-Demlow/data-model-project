-- ============================================
-- Replicate Original SQL Output Using New Dimensional Model
-- ============================================
-- Purpose: Query the new Fact_Invoice, Fact_ServiceAgreement, and Dims to produce
--          the same output as 0_Original data.sql (lines 1191-1233)
-- Updated: November 14, 2025 - Uses separate Fact_ServiceAgreement table
-- ============================================

WITH
-- =========================================================
-- Jobs Side: Invoice-level records with job context
-- =========================================================
jobs_side AS (
    SELECT
        -- Job Identifiers
        j.JobId,
        fi.TransactionNumber,
        bu.BusinessUnitName AS BusinessUnit,
        jt.JobTypeName AS JobType,
        j.JobSummary,
        c.CustomerName AS JobCustomer,
        c.CustomerId AS JobCustomerId,
        l.LocationName AS JobLocation,
        l.LocationId AS JobLocationId,

        -- Job Measures (calculated from invoice base measures)
        fi.IncomeRevenue AS JobRevenue,
        (fi.TotalItemCost + fi.TotalPOCost + fi.TotalLaborCost + COALESCE(jr.TotalReturnCredit, 0)) AS JobCost,
        (fi.IncomeRevenue - (fi.TotalItemCost + fi.TotalPOCost + fi.TotalLaborCost + COALESCE(jr.TotalReturnCredit, 0))) AS JobMargin,
        ((fi.IncomeRevenue - (fi.TotalItemCost + fi.TotalPOCost + fi.TotalLaborCost + COALESCE(jr.TotalReturnCredit, 0)))
         * COALESCE(ecr.JobCommissionPct, 0) / 100) AS JobCommission,

        -- Invoice Identifiers
        fi.InvoiceId AS InvoiceId,
        fi.TransactionNumber AS InvoiceNumber,
        fi.IsAdjustment AS InvoiceIsAdjustment,

        -- Service Agreement (NULL for jobs side)
        CAST(NULL AS BIGINT) AS ServiceAgreementId,
        CAST(NULL AS VARCHAR) AS ServiceAgreementTemplateType,
        CAST(NULL AS DATE) AS ServiceAgreementStartDate,
        CAST(NULL AS VARCHAR) AS ServiceAgreementCustomer,
        CAST(NULL AS BIGINT) AS ServiceAgreementCustomerId,
        CAST(NULL AS VARCHAR) AS ServiceAgreementLocation,
        CAST(NULL AS BIGINT) AS ServiceAgreementLocationId,
        CAST(NULL AS DECIMAL(20,2)) AS CostFromJobs,
        CAST(NULL AS DECIMAL(20,2)) AS ServiceAgreementRevenue,
        CAST(NULL AS INTEGER) AS ServiceAgreementRenewalYear,
        CAST(NULL AS DECIMAL(20,2)) AS ServiceAgreementCommission,
        CAST(NULL AS DECIMAL(20,2)) AS ServiceAgreementMargin,

        -- Link Path
        'EditInvoice/' || fi.InvoiceId::STRING AS LinkPath,

        -- Employee/Salesperson
        e.EmployeeName,
        e.EmployeeType,
        e.EmployeeId,

        -- Commission Rates
        ecr.CommissionType AS CommissionTypeEmployee,
        ecr.JobCommissionPct AS JobCommissionPctEmployee,
        ecr.SAYear1CommissionPct AS SAYear1CommissionPctEmployee,
        ecr.SAYear2CommissionPct AS SAYear2CommissionPctEmployee,
        ecr.SAYear3PlusCommissionPct AS SAYear3PlusCommissionPctEmployee,

        -- For filtering/ordering
        fi.TenantId AS _TenantId

    FROM Fact_Invoice fi
    INNER JOIN Dim_Job j
        ON j.JobKey = fi.JobKey
       AND j.IsActive = 1
    INNER JOIN Dim_Customer c
        ON c.CustomerKey = fi.CustomerKey
       AND c.IsActive = 1
    INNER JOIN Dim_Location l
        ON l.LocationKey = fi.LocationKey
       AND l.IsActive = 1
    INNER JOIN Dim_BusinessUnit bu
        ON bu.BusinessUnitKey = fi.BusinessUnitKey
       AND bu.IsActive = 1
    INNER JOIN Dim_JobType jt
        ON jt.JobTypeKey = fi.JobTypeKey
       AND jt.IsActive = 1
    LEFT JOIN Dim_Employee e
        ON e.EmployeeKey = fi.EmployeeKey
       AND e.IsActive = 1
    LEFT JOIN Mat_Employee_CommissionRates ecr
        ON ecr.EmployeeId = e.EmployeeId
       AND ecr.TenantId = e.TenantId
    LEFT JOIN Mat_Job_Returns jr
        ON jr.JobId = j.JobId
       AND jr.TenantId = j.TenantId
    WHERE fi.PostedDate BETWEEN :From AND :To
      AND fi.TenantId IN :TenantIds
      AND fi.InvoiceStatus = 2  -- Posted
      AND (:EmployeeIdSpecified = 0 OR e.EmployeeId IN :EmployeeIds)
      AND (:FilterStatusSpecified = 0 OR fi.InvoiceStatus IN :FilterStatus)
      -- Exclude jobs that are SA visits (handled in sa_side)
      AND NOT EXISTS (
          SELECT 1
          FROM Dim_Job j2
          WHERE j2.JobId = j.JobId
            AND j2.ServiceAgreementId IS NOT NULL
      )
),

-- =========================================================
-- SA Side: Service Agreement-level records (from Fact_ServiceAgreement)
-- =========================================================
sa_side AS (
    SELECT
        -- Job (NULL for SA side)
        CAST(NULL AS BIGINT) AS JobId,
        fsa.SAName AS TransactionNumber,
        bu.BusinessUnitName AS BusinessUnit,
        CAST(NULL AS VARCHAR) AS JobType,
        CAST(NULL AS STRING) AS JobSummary,
        CAST(NULL AS VARCHAR) AS JobCustomer,
        CAST(NULL AS BIGINT) AS JobCustomerId,
        CAST(NULL AS VARCHAR) AS JobLocation,
        CAST(NULL AS BIGINT) AS JobLocationId,
        CAST(NULL AS DECIMAL(20,2)) AS JobRevenue,
        CAST(NULL AS DECIMAL(20,2)) AS JobCost,
        CAST(NULL AS DECIMAL(20,2)) AS JobMargin,
        CAST(NULL AS DECIMAL(20,2)) AS JobCommission,

        -- Invoice (aggregated from SA visits)
        sa_inv.InvoiceIds AS InvoiceId,
        sa_inv.InvoiceNumbers AS InvoiceNumber,
        CAST(NULL AS INTEGER) AS InvoiceIsAdjustment,

        -- Service Agreement
        fsa.ServiceAgreementId,
        fsa.SATemplateType AS ServiceAgreementTemplateType,
        fsa.SAStartDate AS ServiceAgreementStartDate,
        c.CustomerName AS ServiceAgreementCustomer,
        c.CustomerId AS ServiceAgreementCustomerId,
        l.LocationName AS ServiceAgreementLocation,
        l.LocationId AS ServiceAgreementLocationId,
        sa_costs.TotalCostFromJobs AS CostFromJobs,
        fsa.TotalRevenue AS ServiceAgreementRevenue,
        fsa.SARenewalYear AS ServiceAgreementRenewalYear,
        CASE
            WHEN fsa.SARenewalYear = 1 THEN (fsa.TotalRevenue - COALESCE(sa_costs.TotalCostFromJobs, 0)) * COALESCE(fsa.SAYear1CommissionPct, 0) / 100
            WHEN fsa.SARenewalYear = 2 THEN (fsa.TotalRevenue - COALESCE(sa_costs.TotalCostFromJobs, 0)) * COALESCE(fsa.SAYear2CommissionPct, 0) / 100
            WHEN fsa.SARenewalYear > 2 THEN (fsa.TotalRevenue - COALESCE(sa_costs.TotalCostFromJobs, 0)) * COALESCE(fsa.SAYear3PlusCommissionPct, 0) / 100
            ELSE NULL
        END AS ServiceAgreementCommission,
        (fsa.TotalRevenue - COALESCE(sa_costs.TotalCostFromJobs, 0)) AS ServiceAgreementMargin,

        -- Link Path
        'customer/' || c.CustomerId::STRING || '/service-agreement/' || fsa.ServiceAgreementId::STRING AS LinkPath,

        -- Employee/Salesperson
        e.EmployeeName,
        e.EmployeeType,
        e.EmployeeId,

        -- Commission Rates (from Fact_ServiceAgreement)
        CAST(NULL AS DECIMAL(10,2)) AS CommissionTypeEmployee,  -- Note: CommissionType not stored in new model
        fsa.JobCommissionPct AS JobCommissionPctEmployee,
        fsa.SAYear1CommissionPct AS SAYear1CommissionPctEmployee,
        fsa.SAYear2CommissionPct AS SAYear2CommissionPctEmployee,
        fsa.SAYear3PlusCommissionPct AS SAYear3PlusCommissionPctEmployee,

        -- For filtering/ordering
        fsa.TenantId AS _TenantId

    FROM (
        -- Get one row per SA with aggregated measures and latest attribute values
        SELECT
            ServiceAgreementId,
            TenantId,
            MAX(SAName) AS SAName,
            MAX(SATemplateType) AS SATemplateType,
            MAX(SAStartDate) AS SAStartDate,
            MAX(SARenewalYear) AS SARenewalYear,
            MAX(SAStatus) AS SAStatus,
            MAX(CustomerKey) AS CustomerKey,
            MAX(LocationKey) AS LocationKey,
            MAX(BusinessUnitKey) AS BusinessUnitKey,
            MAX(EmployeeKey) AS EmployeeKey,
            MAX(SoldByEmployeeId) AS SoldByEmployeeId,
            MAX(JobCommissionPct) AS JobCommissionPct,
            MAX(SAYear1CommissionPct) AS SAYear1CommissionPct,
            MAX(SAYear2CommissionPct) AS SAYear2CommissionPct,
            MAX(SAYear3PlusCommissionPct) AS SAYear3PlusCommissionPct,
            SUM(RevenueRecognitionAmount) AS TotalRevenue
        FROM Fact_ServiceAgreement
        WHERE PeriodStartDate >= :From
          AND PeriodEndDate <= :To
          AND TenantId IN :TenantIds
        GROUP BY ServiceAgreementId, TenantId
    ) fsa
    INNER JOIN Dim_Customer c
        ON c.CustomerKey = fsa.CustomerKey
       AND c.IsActive = 1
    INNER JOIN Dim_Location l
        ON l.LocationKey = fsa.LocationKey
       AND l.IsActive = 1
    INNER JOIN Dim_BusinessUnit bu
        ON bu.BusinessUnitKey = fsa.BusinessUnitKey
       AND bu.IsActive = 1
    LEFT JOIN Dim_Employee e
        ON e.EmployeeKey = fsa.EmployeeKey
       AND e.IsActive = 1
    -- Aggregate costs from SA visit jobs (from Fact_Invoice + Dim_Job link)
    LEFT JOIN (
        SELECT
            j.ServiceAgreementId,
            j.TenantId,
            SUM(fi.TotalItemCost + fi.TotalPOCost + fi.TotalLaborCost + COALESCE(jr.TotalReturnCredit, 0)) AS TotalCostFromJobs
        FROM Fact_Invoice fi
        INNER JOIN Dim_Job j
            ON j.JobKey = fi.JobKey
           AND j.ServiceAgreementId IS NOT NULL
        LEFT JOIN Mat_Job_Returns jr
            ON jr.JobId = j.JobId
           AND jr.TenantId = j.TenantId
        WHERE fi.PostedDate BETWEEN :From AND :To
          AND fi.TenantId IN :TenantIds
        GROUP BY j.ServiceAgreementId, j.TenantId
    ) sa_costs
        ON sa_costs.ServiceAgreementId = fsa.ServiceAgreementId
       AND sa_costs.TenantId = fsa.TenantId
    -- Aggregate invoice IDs/numbers for SA visits
    LEFT JOIN (
        SELECT
            j.ServiceAgreementId,
            j.TenantId,
            LISTAGG(DISTINCT fi.InvoiceId, ', ') WITHIN GROUP (ORDER BY fi.InvoiceId) AS InvoiceIds,
            LISTAGG(DISTINCT fi.TransactionNumber, ', ') WITHIN GROUP (ORDER BY fi.TransactionNumber) AS InvoiceNumbers
        FROM Fact_Invoice fi
        INNER JOIN Dim_Job j
            ON j.JobKey = fi.JobKey
           AND j.ServiceAgreementId IS NOT NULL
        WHERE fi.PostedDate BETWEEN :From AND :To
          AND fi.TenantId IN :TenantIds
          AND fi.InvoiceStatus = 2  -- Posted
        GROUP BY j.ServiceAgreementId, j.TenantId
    ) sa_inv
        ON sa_inv.ServiceAgreementId = fsa.ServiceAgreementId
       AND sa_inv.TenantId = fsa.TenantId
    WHERE (:EmployeeIdSpecified = 0 OR e.EmployeeId IN :EmployeeIds)
),

-- =========================================================
-- Union Jobs and SAs
-- =========================================================
combined AS (
    SELECT * FROM jobs_side
    UNION ALL
    SELECT * FROM sa_side
)

-- =========================================================
-- Final Output
-- =========================================================
SELECT
    c._TenantId AS "_TenantId",
    t.TenantName AS "_TenantName",
    t.TenantOfficialName AS "_TenantOfficialName",
    c.JobId AS "JobId",
    c.TransactionNumber AS "TransactionNumber",
    c.BusinessUnit AS "BusinessUnit",
    c.JobType AS "JobType",
    c.JobSummary AS "JobSummary",
    c.JobCustomer AS "JobCustomer",
    c.JobCustomerId AS "JobCustomerId",
    c.JobLocation AS "JobLocation",
    c.JobLocationId AS "JobLocationId",
    c.JobRevenue AS "JobRevenue",
    c.JobCost AS "JobCost",
    c.JobMargin AS "JobMargin",
    CAST(c.JobCommission AS DECIMAL(10,2)) AS "JobCommission",
    c.InvoiceId AS "InvoiceId",
    c.InvoiceNumber AS "InvoiceNumber",
    c.ServiceAgreementId AS "ServiceAgreementId",
    c.ServiceAgreementTemplateType AS "ServiceAgreementTemplateType",
    c.ServiceAgreementStartDate AS "ServiceAgreementStartDate",
    c.ServiceAgreementCustomer AS "ServiceAgreementCustomer",
    c.ServiceAgreementCustomerId AS "ServiceAgreementCustomerId",
    c.ServiceAgreementLocation AS "ServiceAgreementLocation",
    c.ServiceAgreementLocationId AS "ServiceAgreementLocationId",
    c.CostFromJobs AS "CostFromJobs",
    c.ServiceAgreementRevenue AS "ServiceAgreementRevenue",
    c.ServiceAgreementRenewalYear AS "ServiceAgreementRenewalYear",
    CAST(c.ServiceAgreementCommission AS DECIMAL(10,2)) AS "ServiceAgreementCommission",
    c.ServiceAgreementMargin AS "ServiceAgreementMargin",
    c.LinkPath AS "LinkPath",
    c.EmployeeName AS "EmployeeName",
    c.EmployeeType AS "EmployeeType",
    c.EmployeeId AS "EmployeeId",
    c.CommissionTypeEmployee AS "CommissionTypeEmployee",
    c.JobCommissionPctEmployee AS "JobCommission%Employee",
    c.SAYear1CommissionPctEmployee AS "SAYear1Commission%Employee",
    c.SAYear2CommissionPctEmployee AS "SAYear2Commission%Employee",
    c.SAYear3PlusCommissionPctEmployee AS "SAYear3+Commission%Employee"
FROM combined c
LEFT JOIN Dim_Tenant t  -- TODO: Create Dim_Tenant if needed
    ON t.TenantId = c._TenantId
ORDER BY COALESCE(c.JobId, c.ServiceAgreementId), c.InvoiceId;

-- ============================================
-- NOTES & DESIGN DECISIONS:
-- ============================================
--
-- 1. ✅ ARCHITECTURAL CHANGE (Nov 14, 2025):
--    - Service Agreements now in separate Fact_ServiceAgreement table
--    - Fact_Invoice contains ONLY job-related invoices
--    - Different grains: Invoice-level vs SA-period-level
--    - Removed ServiceAgreementId/Key from Fact_Invoice
--
-- 2. ✅ SA DATA SOURCE:
--    - SA revenue comes from Fact_ServiceAgreement.RevenueRecognitionAmount
--    - SA costs come from visit jobs (still in Fact_Invoice, joined via Dim_Job.ServiceAgreementId)
--    - Commission rates stored in Fact_ServiceAgreement for period-specific calculations
--
-- 3. DATA MODEL SEPARATION:
--    jobs_side: Fact_Invoice (invoice grain) → one row per invoice
--    sa_side: Fact_ServiceAgreement (SA + period grain) → aggregated to one row per SA
--
-- 4. MISSING TENANT DIMENSION:
--    - Need Dim_Tenant table with TenantName, TenantOfficialName
--    - Source: tenant_app_dm.master_db.tenant_status
--    - Currently using placeholder left join
--
-- 5. SA VISIT LINKAGE:
--    - Jobs that are SA visits tracked via Dim_Job.ServiceAgreementId IS NOT NULL
--    - These jobs excluded from jobs_side (WHERE NOT EXISTS clause)
--    - Their costs aggregated into SA costs in sa_side
--
-- 6. INVOICE ADJUSTMENT HANDLING:
--    - IsAdjustment flag in Fact_Invoice (from invoice.adjustmentto_id IS NOT NULL)
--    - Inventory returns only apply to non-adjustment invoices (in Mat_Job_Returns)
--
-- 7. COMMISSION TYPE LIMITATION:
--    - Original SQL has CommissionType field from custom fields
--    - New model stores commission percentages but not the type indicator
--    - Using JobCommissionPct as placeholder for CommissionTypeEmployee
--
-- 8. PERFORMANCE OPTIMIZATION:
--    - sa_side aggregates Fact_ServiceAgreement by SA (handles multiple periods)
--    - Uses MAX() for dimension keys/attributes (assumes they don't change across periods)
--    - Uses SUM() for RevenueRecognitionAmount (aggregates across periods in date range)
--    - sa_costs aggregates visit job costs from Fact_Invoice
--    - Consider adding indexes: Fact_ServiceAgreement(ServiceAgreementId, PeriodStartDate)
--    - Consider adding indexes: Dim_Job(ServiceAgreementId) for cost aggregation
--
-- 9. TIMEZONE HANDLING:
--    - Original SQL uses timezone conversion for SA revenue date filtering
--    - Simplified in new model - assumes dates already in correct timezone
--    - May need to add timezone logic to Mat_SA_Period_Measures ETL
--
-- ============================================
