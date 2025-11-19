-- ============================================
-- ETL: Fact_InvoiceItem - BULK LOAD
-- ============================================
-- Purpose: Full refresh of invoice line item fact
-- Source: Direct from invoiceitem table
-- ============================================

USE DATABASE ENG_STAGING;
USE SCHEMA BRANDT_REPORT_DM;

UPDATE ETL_Watermark 
SET LastRunStart = CURRENT_TIMESTAMP(), LastRunStatus = 'RUNNING'
WHERE ProcessName = 'Fact_InvoiceItem';
COMMIT;

TRUNCATE TABLE Fact_InvoiceItem;

INSERT INTO Fact_InvoiceItem (
    InvoiceItemId, InvoiceId, JobId, TenantId,
    DateKey, CustomerKey, LocationKey, BusinessUnitKey, JobTypeKey, JobKey, SKUKey, GLAccountKey,
    InvoicedOn, PostedDate, InvoiceDate, ItemDescription, ItemSequence, SKUType,
    ItemRevenue, ItemQuantity, ItemUnitPrice, ItemCost,
    IsIncome, IsPOItem, POItemId,
    LoadDateTime, UpdatedDateTime
)
SELECT 
    ii.id AS InvoiceItemId,
    ii.invoice_id AS InvoiceId,
    i.job_id AS JobId,
    ii._tenant_id AS TenantId,
    
    -- Dimension Keys
    dd.DateKey,
    dc.CustomerKey,
    dl.LocationKey,
    dbu.BusinessUnitKey,
    djt.JobTypeKey,
    dj.JobKey,
    ds.SKUKey,
    dgl.GLAccountKey,
    
    -- Date attributes (from invoice)
    CAST(i.invoicedon AS DATE) AS InvoicedOn,    
    CAST(i.invoicedon AS DATE) AS PostedDate,
    CAST(i.invoicedon AS DATE) AS InvoiceDate,
    
    -- Degenerate dimensions
    ii.description AS ItemDescription,
    NULL /*ii.sequence*/ AS ItemSequence,
    ii.skureference_skutype AS SKUType,
    
    -- Base measures
    ii.total AS ItemRevenue,
    ii.quantity AS ItemQuantity,
    NULL /*ii.price*/ AS ItemUnitPrice,
    ii.totalcost AS ItemCost,
    
    -- Flags
    CASE WHEN gat.name IS NULL OR LOWER(gat.name) LIKE '%income%' THEN TRUE ELSE FALSE END AS IsIncome,
    CASE WHEN ii.procurementsource_purchaseorderitemid IS NOT NULL THEN TRUE ELSE FALSE END AS IsPOItem,
    ii.procurementsource_purchaseorderitemid AS POItemId,
    
    CURRENT_TIMESTAMP() AS LoadDateTime,
    CURRENT_TIMESTAMP() AS UpdatedDateTime
FROM tenant_lake.raw_real.invoiceitem ii
INNER JOIN tenant_lake.raw_real.invoice i
    ON i.id = ii.invoice_id
   AND i.active = 1
   AND i.status = 2  -- Posted
   AND i._tenant_id = ii._tenant_id
INNER JOIN tenant_lake.raw_real.job j
    ON j.id = i.job_id
   AND j.active = 1
   AND j._tenant_id = i._tenant_id
LEFT JOIN tenant_lake.raw_real.generalledgeraccount ga
    ON ga.id = ii.generalledgeraccount_id
   AND ga._tenant_id = ii._tenant_id
LEFT JOIN tenant_lake.raw_real.generalledgeraccounttype gat
    ON gat.id = ga.type_id
   AND gat._tenant_id = ga._tenant_id
-- Dimension joins
LEFT JOIN Dim_Date dd ON dd.Date = CAST(i.invoicedon AS DATE)
LEFT JOIN Dim_Customer dc ON dc.CustomerId = j.customer_id AND dc.TenantId = ii._tenant_id
LEFT JOIN Dim_Location dl ON dl.LocationId = j.location_id AND dl.TenantId = ii._tenant_id
LEFT JOIN Dim_BusinessUnit dbu ON dbu.BusinessUnitId = j.businessunit_id AND dbu.TenantId = ii._tenant_id
LEFT JOIN Dim_JobType djt ON djt.JobTypeId = j.type_id AND djt.TenantId = ii._tenant_id
LEFT JOIN Dim_Job dj ON dj.JobId = j.id AND dj.TenantId = ii._tenant_id
LEFT JOIN Dim_SKU ds 
    ON ds.SKUId = ii.skureference_skuid 
   AND ds.SKUType = ii.skureference_skutype 
   AND ds.TenantId = ii._tenant_id
LEFT JOIN Dim_GLAccount dgl ON dgl.GLAccountId = ga.id AND dgl.TenantId = ii._tenant_id
WHERE ii.active = 1
  AND ii._tenant_id IN (3457543957)
  AND CAST(i.invoicedon AS DATE) BETWEEN '2025-10-01' AND '2025-10-31'; --BETWEEN CAST(:From AS DATE) AND CAST(:To AS DATE);

COMMIT;

UPDATE ETL_Watermark 
SET LastRunEnd = CURRENT_TIMESTAMP(), LastRunStatus = 'SUCCESS',
    LastSuccessfulRunEnd = CURRENT_TIMESTAMP(),
    RowsProcessed = (SELECT COUNT(*) FROM Fact_InvoiceItem),
    UpdatedDateTime = CURRENT_TIMESTAMP()
WHERE ProcessName = 'Fact_InvoiceItem';
COMMIT;

