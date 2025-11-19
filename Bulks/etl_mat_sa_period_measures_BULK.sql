-- ============================================
-- ETL: Mat_SA_Period_Measures - BULK LOAD
-- ============================================
-- Purpose: Full refresh of SA measures by period
-- Source: Service agreement, journal entries, visit jobs
-- Parameters: '2025-09-01', '2025-11-30'(defines the period), :TenantIds
-- ============================================

USE DATABASE ENG_STAGING;USE SCHEMA BRANDT_REPORT_DM;UPDATE ETL_Watermark
SET LastRunStart = CURRENT_TIMESTAMP(), LastRunStatus = 'RUNNING'
WHERE ProcessName = 'Mat_SA_Period_Measures';
COMMIT;

-- Delete existing records for this period (allows reprocessing)
DELETE FROM Mat_SA_Period_Measures
WHERE PeriodStartDate = CAST('2025-09-01' AS DATE)
  AND PeriodEndDate = CAST('2025-11-30'AS DATE)
  AND TenantId IN (3457543957);

-- ============================================
-- Insert SA measures for the specified period
-- ============================================

INSERT INTO Mat_SA_Period_Measures (
    ServiceAgreementId,
    PeriodStartDate,
    PeriodEndDate,
    TenantId,
    RevenueRecognitionAmount,
    LaborCost,
    BurdenCost,
    MaterialCost,
    EquipmentCost,
    LoadDateTime,
    UpdatedDateTime
)
WITH
-- Revenue recognition from journal entries
sa_revenue AS (
    SELECT
        sa.id AS ServiceAgreementId,
        sa._tenant_id AS TenantId,
        SUM(jei.amount) AS RevenueRecognitionAmount
    FROM tenant_lake.raw_real.serviceagreement sa
    INNER JOIN tenant_app_dm.generalledger.journalentryitem jei
        ON jei.serviceagreementid = sa.id
       AND jei.transactiontype = 11  -- Revenue recognition
       AND jei.entrytype = 1          -- Credit
       AND jei._tenant_id = sa._tenant_id
    INNER JOIN tenant_app_dm.generalledger.journalentry je
        ON je.id = jei.journalentryid
       AND je._tenant_id = jei._tenant_id
       AND CAST(je.postdate AS DATE) >= CAST('2025-09-01' AS DATE)
       AND CAST(je.postdate AS DATE) < CAST('2025-11-30'AS DATE)
    WHERE sa.active = 1
      AND sa._tenant_id IN (3457543957)
    GROUP BY sa.id, sa._tenant_id
),
-- Labor and burden from visit jobs (using grosspayitem union)
sa_labor AS (
    SELECT
        sa.id AS ServiceAgreementId,
        sa._tenant_id AS TenantId,
        SUM(gp.amount) AS LaborCost,
        SUM(COALESCE(gp.burdencostamount, 0)) AS BurdenCost
    FROM tenant_lake.raw_real.serviceagreement sa
    INNER JOIN tenant_lake.raw_real.serviceagreementlocation sal
        ON sal.serviceagreement_id = sa.id AND sal.active = 1 AND sal._tenant_id = sa._tenant_id
    INNER JOIN tenant_lake.raw_real.serviceagreementvisit sav
        ON sav.serviceagreementlocation_id = sal.id AND sav.active = 1 AND sav._tenant_id = sal._tenant_id
    INNER JOIN tenant_lake.raw_real.job j
        ON j.id = sav.jobid AND j.active = 1 AND j._tenant_id = sav._tenant_id
    INNER JOIN (
        SELECT g.job_id, g._tenant_id, g.amount, g.burdencostamount
        FROM tenant_lake.raw_real.grosspayitem g WHERE g.active = 1
        UNION ALL
        SELECT eg.job_id, eg._tenant_id, eg.amount, 0
        FROM tenant_lake.raw_real.employeegrosspayitem eg WHERE eg.active = 1
    ) gp ON gp.job_id = j.id AND gp._tenant_id = j._tenant_id
    WHERE sa.active = 1 AND sa._tenant_id IN (3457543957)
    GROUP BY sa.id, sa._tenant_id
),
-- Material and equipment costs from visit jobs
sa_items AS (
    SELECT
        sa.id AS ServiceAgreementId,
        sa._tenant_id AS TenantId,
        SUM(CASE WHEN ii.skureference_skutype = 1 THEN ii.totalcost ELSE 0 END) AS MaterialCost,
        SUM(CASE WHEN ii.skureference_skutype = 2 THEN ii.totalcost ELSE 0 END) AS EquipmentCost
    FROM tenant_lake.raw_real.serviceagreement sa
    INNER JOIN tenant_lake.raw_real.serviceagreementlocation sal
        ON sal.serviceagreement_id = sa.id AND sal.active = 1 AND sal._tenant_id = sa._tenant_id
    INNER JOIN tenant_lake.raw_real.serviceagreementvisit sav
        ON sav.serviceagreementlocation_id = sal.id AND sav.active = 1 AND sav._tenant_id = sal._tenant_id
    INNER JOIN tenant_lake.raw_real.job j
        ON j.id = sav.jobid AND j.active = 1 AND j._tenant_id = sav._tenant_id
    INNER JOIN tenant_lake.raw_real.invoice inv
        ON inv.job_id = j.id AND inv.active = 1 AND inv._tenant_id = j._tenant_id
    INNER JOIN tenant_lake.raw_real.invoiceitem ii
        ON ii.invoice_id = inv.id AND ii.active = 1 AND ii._tenant_id = inv._tenant_id
    WHERE sa.active = 1 AND sa._tenant_id IN (3457543957)
    GROUP BY sa.id, sa._tenant_id
)
SELECT
    sa.id AS ServiceAgreementId,
    CAST('2025-09-01' AS DATE) AS PeriodStartDate,
    CAST('2025-11-30'AS DATE) AS PeriodEndDate,
    sa._tenant_id AS TenantId,
    COALESCE(rev.RevenueRecognitionAmount, 0) AS RevenueRecognitionAmount,
    COALESCE(lab.LaborCost, 0) AS LaborCost,
    COALESCE(lab.BurdenCost, 0) AS BurdenCost,
    COALESCE(itm.MaterialCost, 0) AS MaterialCost,
    COALESCE(itm.EquipmentCost, 0) AS EquipmentCost,
    CURRENT_TIMESTAMP() AS LoadDateTime,
    CURRENT_TIMESTAMP() AS UpdatedDateTime
FROM tenant_lake.raw_real.serviceagreement sa
LEFT JOIN sa_revenue rev ON rev.ServiceAgreementId = sa.id
LEFT JOIN sa_labor lab ON lab.ServiceAgreementId = sa.id
LEFT JOIN sa_items itm ON itm.ServiceAgreementId = sa.id
WHERE sa.active = 1
  AND sa._tenant_id IN (3457543957)
  AND (rev.RevenueRecognitionAmount IS NOT NULL
       OR lab.LaborCost IS NOT NULL
       OR itm.MaterialCost IS NOT NULL);

COMMIT;UPDATE ETL_Watermark
SET LastRunEnd = CURRENT_TIMESTAMP(), LastRunStatus = 'SUCCESS',
    LastSuccessfulRunEnd = CURRENT_TIMESTAMP(),
    RowsProcessed = (SELECT COUNT(*) FROM Mat_SA_Period_Measures
                     WHERE PeriodStartDate = CAST('2025-09-01' AS DATE) AND PeriodEndDate = CAST('2025-11-30'AS DATE)),
    UpdatedDateTime = CURRENT_TIMESTAMP()
WHERE ProcessName = 'Mat_SA_Period_Measures';
COMMIT;
