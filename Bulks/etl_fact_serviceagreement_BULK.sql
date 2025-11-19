-- ============================================
-- ETL: Fact_ServiceAgreement - BULK LOAD
-- ============================================
-- Purpose: Full refresh of service agreement fact for a reporting period
-- Prerequisite: Mat_SA_Period_Measures must be loaded first for the period
-- Parameters: '2025-09-01', '2025-11-30'(defines the period), :TenantIds
-- ============================================

USE DATABASE ENG_STAGING;
USE SCHEMA BRANDT_REPORT_DM;

UPDATE ETL_Watermark 
SET LastRunStart = CURRENT_TIMESTAMP(), LastRunStatus = 'RUNNING'
WHERE ProcessName = 'Fact_ServiceAgreement';
COMMIT;

-- Delete existing records for this period (allows reprocessing)
DELETE FROM Fact_ServiceAgreement
WHERE PeriodStartDate = CAST('2025-09-01' AS DATE)
  AND PeriodEndDate = CAST('2025-11-30'AS DATE)
  AND TenantId IN (3457543957);

INSERT INTO Fact_ServiceAgreement (
    ServiceAgreementId, PeriodStartDate, PeriodEndDate, TenantId,
    DateKey, CustomerKey, LocationKey, BusinessUnitKey, EmployeeKey, ServiceAgreementDimKey,
    SAName, SATemplateType, SAStartDate, SAEndDate, SARenewalYear, SAStatus,
    RevenueRecognitionAmount, LaborCost, BurdenCost, MaterialCost, EquipmentCost,
    SoldByEmployeeId, JobCommissionPct, SAYear1CommissionPct, SAYear2CommissionPct, SAYear3PlusCommissionPct,
    LoadDateTime, UpdatedDateTime
)
WITH
-- Calculate renewal year for each SA
sa_renewal AS (
    SELECT 
        sa.id AS ServiceAgreementId,
        sa._tenant_id,
        ROW_NUMBER() OVER (
            PARTITION BY sa._tenant_id, sa.renewalgroupinitialagreement_id 
            ORDER BY sa.startdate ASC
        ) AS RenewalYear
    FROM tenant_lake.raw_real.serviceagreement sa
    WHERE sa.active = 1
      AND sa._tenant_id IN (3457543957)
),
-- Get sold by employee for each SA
sa_soldby AS (
    SELECT 
        sa.id AS ServiceAgreementId,
        sa._tenant_id,
        de.EMPLOYEE_ID AS SoldByEmployeeId,
        de.EMPLOYEE_SK AS EmployeeKey
    FROM tenant_lake.raw_real.serviceagreement sa
    LEFT JOIN tenant_app_dm.report.dim_employee de
        ON de.user_id = sa.soldbyid
       AND de._tenant_id = sa._tenant_id
    WHERE sa.active = 1
      AND sa._tenant_id IN (3457543957)
),
-- Get primary location for each SA (first active location)
sa_primary_location AS (
    SELECT 
        sal.serviceagreement_id AS ServiceAgreementId,
        sal._tenant_id,
        MIN(sal.locationid) AS PrimaryLocationId  -- Use MIN for deterministic selection
    FROM tenant_lake.raw_real.serviceagreementlocation sal
    WHERE sal.active = 1
      AND sal._tenant_id IN (3457543957)
    GROUP BY sal.serviceagreement_id, sal._tenant_id
)
SELECT 
    -- Natural keys and period
    sa.id AS ServiceAgreementId,
    mat.PeriodStartDate,
    mat.PeriodEndDate,
    sa._tenant_id AS TenantId,
    
    -- Dimension Keys (surrogate keys from dimension tables)
    dd.DateKey,
    dc.CustomerKey,
    dl.LocationKey,
    dbu.BusinessUnitKey,
    de.EmployeeKey,
    dsa.ServiceAgreementKey AS ServiceAgreementDimKey,
    
    -- SA Attributes
    sa.name AS SAName,
    sat.name AS SATemplateType,
    CAST(sa.startdate AS DATE) AS SAStartDate,
    CAST(sa.enddate AS DATE) AS SAEndDate,
    COALESCE(sr.RenewalYear, 1) AS SARenewalYear,
    sa.status AS SAStatus,
    
    -- Base Measures (from Mat_SA_Period_Measures)
    COALESCE(mat.RevenueRecognitionAmount, 0) AS RevenueRecognitionAmount,
    COALESCE(mat.LaborCost, 0) AS LaborCost,
    COALESCE(mat.BurdenCost, 0) AS BurdenCost,
    COALESCE(mat.MaterialCost, 0) AS MaterialCost,
    COALESCE(mat.EquipmentCost, 0) AS EquipmentCost,
    
    -- Commission calculation inputs
    sb.SoldByEmployeeId,
    ecr.JobCommissionPct,
    ecr.SAYear1CommissionPct,
    ecr.SAYear2CommissionPct,
    ecr.SAYear3PlusCommissionPct,
    
    CURRENT_TIMESTAMP() AS LoadDateTime,
    CURRENT_TIMESTAMP() AS UpdatedDateTime

FROM Mat_SA_Period_Measures mat
INNER JOIN tenant_lake.raw_real.serviceagreement sa
    ON sa.id = mat.ServiceAgreementId
   AND sa._tenant_id = mat.TenantId
   AND sa.active = 1

-- Get renewal year
LEFT JOIN sa_renewal sr 
    ON sr.ServiceAgreementId = sa.id
   AND sr._tenant_id = sa._tenant_id

-- Get sold by employee
LEFT JOIN sa_soldby sb 
    ON sb.ServiceAgreementId = sa.id
   AND sb._tenant_id = sa._tenant_id

-- Get primary location
LEFT JOIN sa_primary_location spl 
    ON spl.ServiceAgreementId = sa.id
   AND spl._tenant_id = sa._tenant_id

-- SA template
LEFT JOIN tenant_lake.raw_real.serviceagreementtemplate sat
    ON sat.id = sa.templateinstance_id
   AND sat._tenant_id = sa._tenant_id

-- Dimension joins (for surrogate keys)
LEFT JOIN Dim_Date dd 
    ON dd.Date = mat.PeriodStartDate

LEFT JOIN Dim_Customer dc 
    ON dc.CustomerId = sa.customerid 
   AND dc.TenantId = sa._tenant_id

LEFT JOIN Dim_Location dl 
    ON dl.LocationId = spl.PrimaryLocationId 
   AND dl.TenantId = sa._tenant_id

LEFT JOIN Dim_BusinessUnit dbu 
    ON dbu.BusinessUnitId = sa.businessunitid 
   AND dbu.TenantId = sa._tenant_id

LEFT JOIN Dim_Employee de 
    ON de.EmployeeId = sb.SoldByEmployeeId 
   AND de.TenantId = sa._tenant_id

LEFT JOIN Dim_ServiceAgreement dsa 
    ON dsa.ServiceAgreementId = sa.id 
   AND dsa.TenantId = sa._tenant_id

-- Get commission rates from employee
LEFT JOIN Mat_Employee_CommissionRates ecr
    ON ecr.EmployeeId = sb.SoldByEmployeeId
   AND ecr.TenantId = sa._tenant_id

WHERE mat.PeriodStartDate = CAST('2025-09-01' AS DATE)
  AND mat.PeriodEndDate = CAST('2025-11-30'AS DATE)
  AND mat.TenantId IN (3457543957);

COMMIT;

UPDATE ETL_Watermark 
SET LastRunEnd = CURRENT_TIMESTAMP(), LastRunStatus = 'SUCCESS',
    LastSuccessfulRunEnd = CURRENT_TIMESTAMP(),
    RowsProcessed = (SELECT COUNT(*) FROM Fact_ServiceAgreement 
                     WHERE PeriodStartDate = CAST('2025-09-01' AS DATE) 
                       AND PeriodEndDate = CAST('2025-11-30'AS DATE)),
    UpdatedDateTime = CURRENT_TIMESTAMP()
WHERE ProcessName = 'Fact_ServiceAgreement';
COMMIT;

