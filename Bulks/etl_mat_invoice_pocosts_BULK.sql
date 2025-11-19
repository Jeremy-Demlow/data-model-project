-- ============================================
-- ETL: Mat_Invoice_POCosts - BULK LOAD
-- ============================================
-- Purpose: Full refresh of purchase order costs
-- Source: purchaseorder, inventorybill, inventoryshipment
-- ============================================

USE DATABASE ENG_STAGING;
USE SCHEMA BRANDT_REPORT_DM;

UPDATE ETL_Watermark 
SET LastRunStart = CURRENT_TIMESTAMP(), LastRunStatus = 'RUNNING'
WHERE ProcessName = 'Mat_Invoice_POCosts';
COMMIT;

TRUNCATE TABLE Mat_Invoice_POCosts;

INSERT INTO Mat_Invoice_POCosts (
    InvoiceId, TenantId, JobId, PostedDate, InvoiceModifiedOn, LastPOModifiedOn,
    POUnbilledCost, POBilledCost, TotalPOCost, POCount,
    LoadDateTime, UpdatedDateTime
)
WITH po_unbilled AS (
    SELECT 
        po.invoice_id,
        SUM(po.amount) AS po_unbilled
    FROM tenant_lake.raw_real.purchaseorder po
    WHERE po.active = 1
      AND po._tenant_id IN (3457543957)
      AND NOT EXISTS (
          SELECT 1 FROM tenant_lake.raw_real.inventoryshipment ish
          WHERE ish.active = 1
            AND ish.bill_id IS NOT NULL
            AND ish.purchaseorder_id = po.id
            AND ish._tenant_id = po._tenant_id
      )
    GROUP BY po.invoice_id
),
po_billed AS (
    SELECT 
        po.invoice_id,
        SUM(b.total) AS po_billed
    FROM tenant_lake.raw_real.purchaseorder po
    INNER JOIN tenant_lake.raw_real.inventorybill b
        ON b.purchaseorder_id = po.id
       AND b.active = 1
       AND b._tenant_id = po._tenant_id
    WHERE po.active = 1
      AND po._tenant_id IN (3457543957)
    GROUP BY po.invoice_id
)
SELECT 
    i.id AS InvoiceId,
    i._tenant_id AS TenantId,
    i.job_id AS JobId,
    CAST(i.invoicedon AS DATE) AS PostedDate,
    i.modifiedon AS InvoiceModifiedOn,
    MAX(po.modifiedon) AS LastPOModifiedOn,
    COALESCE(pou.po_unbilled, 0) AS POUnbilledCost,
    COALESCE(pob.po_billed, 0) AS POBilledCost,
    COALESCE(pou.po_unbilled, 0) + COALESCE(pob.po_billed, 0) AS TotalPOCost,
    COUNT(DISTINCT po.id) AS POCount,
    CURRENT_TIMESTAMP() AS LoadDateTime,
    CURRENT_TIMESTAMP() AS UpdatedDateTime
FROM tenant_lake.raw_real.invoice i
INNER JOIN tenant_lake.raw_real.purchaseorder po
    ON po.invoice_id = i.id
   AND po.active = 1
   AND po._tenant_id = i._tenant_id
LEFT JOIN po_unbilled pou ON pou.invoice_id = i.id
LEFT JOIN po_billed pob ON pob.invoice_id = i.id
WHERE i.active = 1
  AND i.status = 2
  AND i._tenant_id IN (3457543957)
  AND CAST(i.invoicedon AS DATE) BETWEEN '2025-10-01' AND '2025-10-31'--BETWEEN CAST(:From AS DATE) AND CAST(:To AS DATE)
GROUP BY i.id, i._tenant_id, i.job_id, i.invoicedon, i.modifiedon, pou.po_unbilled, pob.po_billed;

COMMIT;

UPDATE ETL_Watermark 
SET LastRunEnd = CURRENT_TIMESTAMP(), LastRunStatus = 'SUCCESS',
    LastSuccessfulRunEnd = CURRENT_TIMESTAMP(),
    RowsProcessed = (SELECT COUNT(*) FROM Mat_Invoice_POCosts),
    UpdatedDateTime = CURRENT_TIMESTAMP()
WHERE ProcessName = 'Mat_Invoice_POCosts';
COMMIT;

