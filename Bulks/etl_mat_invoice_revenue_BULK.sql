-- ============================================
-- ETL: Mat_Invoice_Revenue - BULK LOAD
-- ============================================
-- Purpose: Full refresh of invoice revenue measures
-- Run: Initial load or when full refresh needed
-- Parameters: :From, :To (date range), :TenantIds
-- ============================================

-- Update watermark: Start
USE DATABASE ENG_STAGING;
USE SCHEMA BRANDT_REPORT_DM;

UPDATE ETL_Watermark 
SET LastRunStart = CURRENT_TIMESTAMP(),
    LastRunStatus = 'RUNNING'
WHERE ProcessName = 'Mat_Invoice_Revenue';

COMMIT;

-- ============================================
-- Main ETL Logic
-- ============================================

-- Truncate and reload
TRUNCATE TABLE Mat_Invoice_Revenue;

INSERT INTO Mat_Invoice_Revenue (
    InvoiceId,
    TenantId,
    JobId,
    InvoicedOn,
    InvoiceDate,
    PostedDate,
    InvoiceModifiedOn,
    TransactionNumber,
    InvoiceStatus,
    TotalRevenue,
    IncomeRevenue,
    LineItemCount,
    LoadDateTime,
    UpdatedDateTime
)
SELECT 
    i.id AS InvoiceId,
    i._tenant_id AS TenantId,
    i.job_id AS JobId,
    CAST(i.invoicedon AS DATE) AS InvoicedOn,    
    CAST(i.invoicedon AS DATE) AS InvoiceDate,
    CAST(i.invoicedon AS DATE) AS PostedDate,
    i.modifiedon AS InvoiceModifiedOn,
    i.trans_number AS TransactionNumber,
    i.status AS InvoiceStatus,
    
    -- Total Revenue: Sum all invoice items
    COALESCE(SUM(ii.total), 0) AS TotalRevenue,
    
    -- Income Revenue: Sum only items with income GL account type
    COALESCE(SUM(
        CASE 
            WHEN gat.name IS NULL OR LOWER(gat.name) LIKE '%income%' 
            THEN ii.total 
            ELSE 0 
        END
    ), 0) AS IncomeRevenue,
    
    -- Line Item Count
    COUNT(DISTINCT ii.id) AS LineItemCount,
    
    CURRENT_TIMESTAMP() AS LoadDateTime,
    CURRENT_TIMESTAMP() AS UpdatedDateTime
FROM tenant_lake.raw_real.invoice i
LEFT JOIN tenant_lake.raw_real.invoiceitem ii
    ON ii.invoice_id = i.id
   AND ii.active = 1
   AND ii._tenant_id = i._tenant_id
LEFT JOIN tenant_lake.raw_real.generalledgeraccount ga
    ON ga.id = ii.generalledgeraccount_id
   AND ga._tenant_id = ii._tenant_id
LEFT JOIN tenant_lake.raw_real.generalledgeraccounttype gat
    ON gat.id = ga.type_id
   AND gat._tenant_id = ga._tenant_id
WHERE i.active = 1
  AND i._tenant_id IN (3457543957)
  AND i.status = 2  -- Posted
  AND CAST(i.invoicedon AS DATE) BETWEEN '2023-01-01' AND '2024-12-31'
GROUP BY 
    i.id,
    i._tenant_id,
    i.job_id,
    i.invoicedon,
    i.modifiedon,
    i.trans_number,
    i.status;

COMMIT;

-- ============================================
-- Update watermark: Success
-- ============================================

USE DATABASE ENG_STAGING;
USE SCHEMA BRANDT_REPORT_DM;

UPDATE ETL_Watermark 
SET LastRunEnd = CURRENT_TIMESTAMP(),
    LastRunStatus = 'SUCCESS',
    LastSuccessfulRunEnd = CURRENT_TIMESTAMP(),
    RowsProcessed = (SELECT COUNT(*) FROM Mat_Invoice_Revenue),
    UpdatedDateTime = CURRENT_TIMESTAMP()
WHERE ProcessName = 'Mat_Invoice_Revenue';

COMMIT;

