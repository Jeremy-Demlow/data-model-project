-- ============================================
-- Service Agreement Metrics View
-- ============================================
-- Purpose: Extract SA-level metrics from the report query
-- Source: Derived from QUERY_ReplicateOriginalOutput.sql
-- ============================================

CREATE OR REPLACE TEMPORARY VIEW sa_metrics AS
WITH
-- SA Side: Service Agreement-level records
sa_side AS (
    SELECT
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
        
        -- Employee/Salesperson
        e.EmployeeName,
        e.EmployeeType,
        e.EmployeeId,
        
        -- For filtering
        fsa.TenantId AS _TenantId
        
    FROM (
        -- Get one row per SA with aggregated measures
        SELECT 
            ServiceAgreementId,
            TenantId,
            MAX(SAName) AS SAName,
            MAX(SATemplateType) AS SATemplateType,
            MAX(SAStartDate) AS SAStartDate,
            MAX(SARenewalYear) AS SARenewalYear,
            MAX(CustomerKey) AS CustomerKey,
            MAX(LocationKey) AS LocationKey,
            MAX(BusinessUnitKey) AS BusinessUnitKey,
            MAX(EmployeeKey) AS EmployeeKey,
            MAX(JobCommissionPct) AS JobCommissionPct,
            MAX(SAYear1CommissionPct) AS SAYear1CommissionPct,
            MAX(SAYear2CommissionPct) AS SAYear2CommissionPct,
            MAX(SAYear3PlusCommissionPct) AS SAYear3PlusCommissionPct,
            SUM(RevenueRecognitionAmount) AS TotalRevenue
        FROM Fact_ServiceAgreement
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
    -- Aggregate costs from SA visit jobs
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
        WHERE fi.InvoiceStatus = 2  -- Posted
        GROUP BY j.ServiceAgreementId, j.TenantId
    ) sa_costs
        ON sa_costs.ServiceAgreementId = fsa.ServiceAgreementId
       AND sa_costs.TenantId = fsa.TenantId
)
SELECT * FROM sa_side;

