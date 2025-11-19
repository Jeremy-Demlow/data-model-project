-- ============================================
-- Employee Metrics View
-- ============================================
-- Purpose: Extract employee-level commission metrics
-- ============================================

CREATE OR REPLACE TEMPORARY VIEW employee_metrics AS
WITH job_commissions AS (
    SELECT
        e.EmployeeId,
        e.EmployeeName,
        e.EmployeeType,
        SUM((fi.IncomeRevenue - (fi.TotalItemCost + fi.TotalPOCost + fi.TotalLaborCost + COALESCE(jr.TotalReturnCredit, 0))) 
            * COALESCE(ecr.JobCommissionPct, 0) / 100) AS JobCommission
    FROM Fact_Invoice fi
    INNER JOIN Dim_Job j ON j.JobKey = fi.JobKey AND j.IsActive = 1
    LEFT JOIN Dim_Employee e ON e.EmployeeKey = fi.EmployeeKey AND e.IsActive = 1
    LEFT JOIN Mat_Employee_CommissionRates ecr
        ON ecr.EmployeeId = e.EmployeeId AND ecr.TenantId = e.TenantId
    LEFT JOIN Mat_Job_Returns jr
        ON jr.JobId = j.JobId AND jr.TenantId = j.TenantId
    WHERE fi.InvoiceStatus = 2
      AND NOT EXISTS (
          SELECT 1 FROM Dim_Job j2 
          WHERE j2.JobId = j.JobId AND j2.ServiceAgreementId IS NOT NULL
      )
    GROUP BY e.EmployeeId, e.EmployeeName, e.EmployeeType
),
sa_commissions AS (
    SELECT
        e.EmployeeId,
        e.EmployeeName,
        e.EmployeeType,
        SUM(CASE 
            WHEN fsa.SARenewalYear = 1 THEN 
                (fsa.RevenueRecognitionAmount - COALESCE(sa_costs.CostFromJobs, 0)) 
                * COALESCE(fsa.SAYear1CommissionPct, 0) / 100
            WHEN fsa.SARenewalYear = 2 THEN 
                (fsa.RevenueRecognitionAmount - COALESCE(sa_costs.CostFromJobs, 0)) 
                * COALESCE(fsa.SAYear2CommissionPct, 0) / 100
            WHEN fsa.SARenewalYear > 2 THEN 
                (fsa.RevenueRecognitionAmount - COALESCE(sa_costs.CostFromJobs, 0)) 
                * COALESCE(fsa.SAYear3PlusCommissionPct, 0) / 100
            ELSE 0
        END) AS SACommission
    FROM Fact_ServiceAgreement fsa
    LEFT JOIN Dim_Employee e ON e.EmployeeKey = fsa.EmployeeKey AND e.IsActive = 1
    LEFT JOIN (
        SELECT 
            j.ServiceAgreementId,
            j.TenantId,
            AVG(fi.TotalItemCost + fi.TotalPOCost + fi.TotalLaborCost + COALESCE(jr.TotalReturnCredit, 0)) AS CostFromJobs
        FROM Fact_Invoice fi
        INNER JOIN Dim_Job j ON j.JobKey = fi.JobKey AND j.ServiceAgreementId IS NOT NULL
        LEFT JOIN Mat_Job_Returns jr ON jr.JobId = j.JobId AND jr.TenantId = j.TenantId
        WHERE fi.InvoiceStatus = 2
        GROUP BY j.ServiceAgreementId, j.TenantId
    ) sa_costs ON sa_costs.ServiceAgreementId = fsa.ServiceAgreementId
                 AND sa_costs.TenantId = fsa.TenantId
    GROUP BY e.EmployeeId, e.EmployeeName, e.EmployeeType
)
SELECT
    COALESCE(jc.EmployeeId, sc.EmployeeId) AS EmployeeId,
    COALESCE(jc.EmployeeName, sc.EmployeeName) AS EmployeeName,
    COALESCE(jc.EmployeeType, sc.EmployeeType) AS EmployeeType,
    COALESCE(jc.JobCommission, 0) AS JobCommission,
    COALESCE(sc.SACommission, 0) AS SACommission,
    COALESCE(jc.JobCommission, 0) + COALESCE(sc.SACommission, 0) AS TotalCommission
FROM job_commissions jc
FULL OUTER JOIN sa_commissions sc 
    ON jc.EmployeeId = sc.EmployeeId;

