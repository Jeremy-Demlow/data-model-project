-- ============================================
-- Job Metrics View
-- ============================================
-- Purpose: Extract job-level metrics from the report query
-- Source: Derived from QUERY_ReplicateOriginalOutput.sql
-- ============================================

CREATE OR REPLACE TEMPORARY VIEW job_metrics AS
WITH
-- Jobs Side: Invoice-level records with job context
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
        
        -- Employee/Salesperson
        e.EmployeeName,
        e.EmployeeType,
        e.EmployeeId,
        
        -- For filtering
        fi.TenantId AS _TenantId,
        fi.PostedDate
        
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
    WHERE fi.InvoiceStatus = 2  -- Posted
      -- Exclude jobs that are SA visits
      AND NOT EXISTS (
          SELECT 1 
          FROM Dim_Job j2 
          WHERE j2.JobId = j.JobId 
            AND j2.ServiceAgreementId IS NOT NULL
      )
)
SELECT * FROM jobs_side;

