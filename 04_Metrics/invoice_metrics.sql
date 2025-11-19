-- ============================================
-- Invoice Metrics View
-- ============================================
-- Purpose: Extract invoice-level metrics
-- ============================================

CREATE OR REPLACE TEMPORARY VIEW invoice_metrics AS
SELECT
    fi.InvoiceId,
    fi.InvoiceDate,
    fi.PostedDate,
    fi.TransactionNumber,
    fi.TotalRevenue,
    fi.IncomeRevenue,
    fi.LineItemCount,
    fi.IsAdjustment,
    j.JobId,
    c.CustomerId,
    c.CustomerName,
    l.LocationId,
    l.LocationName,
    bu.BusinessUnitName,
    fi.TenantId
FROM Fact_Invoice fi
INNER JOIN Dim_Job j
    ON j.JobKey = fi.JobKey
   AND j.IsActive = 1
LEFT JOIN Dim_Customer c
    ON c.CustomerKey = fi.CustomerKey
   AND c.IsActive = 1
LEFT JOIN Dim_Location l
    ON l.LocationKey = fi.LocationKey
   AND l.IsActive = 1
LEFT JOIN Dim_BusinessUnit bu
    ON bu.BusinessUnitKey = fi.BusinessUnitKey
   AND bu.IsActive = 1
WHERE fi.InvoiceStatus = 2;  -- Posted

