-- ============================================
-- ETL: Mat_Invoice_MaterialCosts - BULK LOAD
-- ============================================
-- Purpose: Full refresh of equipment and material costs
-- Source: invoiceitem (non-PO), equipment, material
-- ============================================

USE DATABASE ENG_STAGING;
USE SCHEMA BRANDT_REPORT_DM;

UPDATE ETL_Watermark 
SET LastRunStart = CURRENT_TIMESTAMP(), LastRunStatus = 'RUNNING'
WHERE ProcessName = 'Mat_Invoice_MaterialCosts';
COMMIT;

TRUNCATE TABLE Mat_Invoice_MaterialCosts;

INSERT INTO Mat_Invoice_MaterialCosts (
    InvoiceId,
    TenantId,
    JobId,
    PostedDate,
    InvoiceModifiedOn,
    EquipmentCost,
    MaterialCost,
    TotalItemCost,
    LoadDateTime,
    UpdatedDateTime
)
SELECT 
    i.id AS InvoiceId,
    i._tenant_id AS TenantId,
    i.job_id AS JobId,
    CAST(i.invoicedon AS DATE) AS PostedDate,
    i.modifiedon AS InvoiceModifiedOn,
    
    -- Equipment Cost (skutype = 2)
    COALESCE(SUM(CASE WHEN e.id IS NOT NULL THEN ii.totalcost ELSE 0 END), 0) AS EquipmentCost,
    
    -- Material Cost (skutype = 1)
    COALESCE(SUM(CASE WHEN m.id IS NOT NULL THEN ii.totalcost ELSE 0 END), 0) AS MaterialCost,
    
    -- Total Item Cost
    COALESCE(SUM(ii.totalcost), 0) AS TotalItemCost,
    
    CURRENT_TIMESTAMP() AS LoadDateTime,
    CURRENT_TIMESTAMP() AS UpdatedDateTime
FROM tenant_lake.raw_real.invoice i
INNER JOIN tenant_lake.raw_real.invoiceitem ii
    ON ii.invoice_id = i.id
   AND ii.active = 1
   AND ii.procurementsource_purchaseorderitemid IS NULL  -- Exclude PO items
   AND ii._tenant_id = i._tenant_id
LEFT JOIN tenant_lake.raw_real.equipment e
    ON e.id = ii.skureference_skuid
   AND ii.skureference_skutype = 2
   AND e._tenant_id = ii._tenant_id
LEFT JOIN tenant_lake.raw_real.material m
    ON m.id = ii.skureference_skuid
   AND ii.skureference_skutype = 1
   AND m._tenant_id = ii._tenant_id
WHERE i.active = 1
  AND i.status = 2  -- Posted
  AND i._tenant_id IN (3457543957)
  AND CAST(i.invoicedon AS DATE) BETWEEN '2025-10-01' AND '2025-10-31'--BETWEEN CAST(:From AS DATE) AND CAST(:To AS DATE)
  AND (e.id IS NOT NULL OR m.id IS NOT NULL)
GROUP BY 
    i.id,
    i._tenant_id,
    i.job_id,
    i.invoicedon,
    i.modifiedon;

COMMIT;

UPDATE ETL_Watermark 
SET LastRunEnd = CURRENT_TIMESTAMP(),
    LastRunStatus = 'SUCCESS',
    LastSuccessfulRunEnd = CURRENT_TIMESTAMP(),
    RowsProcessed = (SELECT COUNT(*) FROM Mat_Invoice_MaterialCosts),
    UpdatedDateTime = CURRENT_TIMESTAMP()
WHERE ProcessName = 'Mat_Invoice_MaterialCosts';
COMMIT;

