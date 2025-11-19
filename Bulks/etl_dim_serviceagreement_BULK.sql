-- ============================================
-- ETL: Dim_ServiceAgreement - BULK LOAD
-- ============================================
-- Purpose: Full refresh of service agreement dimension with renewal year calculation
-- Source: tenant_lake.raw_real.serviceagreement, serviceagreementtemplate
-- ============================================

USE DATABASE ENG_STAGING;USE SCHEMA BRANDT_REPORT_DM;UPDATE ETL_Watermark
SET LastRunStart = CURRENT_TIMESTAMP(), LastRunStatus = 'RUNNING'
WHERE ProcessName = 'Dim_ServiceAgreement';
COMMIT;

TRUNCATE TABLE Dim_ServiceAgreement;

INSERT INTO Dim_ServiceAgreement (
    ServiceAgreementId, TenantId, ServiceAgreementName,
    CustomerId, LocationId, BusinessUnitId, SoldById,
    TemplateId, TemplateName, TemplateType, StartDate, EndDate,
    RenewalYear, RenewalGroupInitialAgreementId, RenewedById,
    Status, StatusName, IsActive, LoadDateTime, UpdatedDateTime
)
WITH sa_renewal AS (
    SELECT
        sa.id AS ServiceAgreementId,
        ROW_NUMBER() OVER (
            PARTITION BY sa._tenant_id, sa.renewalgroupinitialagreement_id
            ORDER BY sa.startdate ASC
        ) AS renewal_year
    FROM tenant_lake.raw_real.serviceagreement sa
    WHERE sa.active = 1
      AND sa._tenant_id IN (3457543957)
)
SELECT
    sa.id AS ServiceAgreementId,
    sa._tenant_id AS TenantId,
    sa.name AS ServiceAgreementName,
    sa.customerid AS CustomerId,
    sal.locationid AS LocationId,
    sa.businessunitid AS BusinessUnitId,
    sa.soldbyid AS SoldById,
    sat.id AS TemplateId,
    sat.name AS TemplateName,
    sat.name AS TemplateType,
    CAST(sa.startdate AS DATE) AS StartDate,
    CAST(sa.enddate AS DATE) AS EndDate,
    COALESCE(sar.renewal_year, 1) AS RenewalYear,
    sa.renewalgroupinitialagreement_id AS RenewalGroupInitialAgreementId,
    sa.renewedby_id AS RenewedById,
    sa.status AS Status,
    CASE sa.status
        WHEN 1 THEN 'Draft'
        WHEN 2 THEN 'Pending'
        WHEN 3 THEN 'Active'
        WHEN 4 THEN 'Complete'
        WHEN 5 THEN 'Cancelled'
        ELSE 'Unknown'
    END AS StatusName,
    sa.active AS IsActive,
    CURRENT_TIMESTAMP() AS LoadDateTime,
    CURRENT_TIMESTAMP() AS UpdatedDateTime
FROM tenant_lake.raw_real.serviceagreement sa
LEFT JOIN tenant_lake.raw_real.serviceagreementtemplate sat
    ON sat.id = sa.templateinstance_id
   AND sat._tenant_id = sa._tenant_id
LEFT JOIN tenant_lake.raw_real.serviceagreementlocation sal
    ON sal.serviceagreement_id = sa.id
   AND sal.active = 1
   AND sal._tenant_id = sa._tenant_id
LEFT JOIN sa_renewal sar
    ON sar.ServiceAgreementId = sa.id
WHERE sa._tenant_id IN (3457543957);

COMMIT;UPDATE ETL_Watermark
SET LastRunEnd = CURRENT_TIMESTAMP(), LastRunStatus = 'SUCCESS',
    LastSuccessfulRunEnd = CURRENT_TIMESTAMP(),
    RowsProcessed = (SELECT COUNT(*) FROM Dim_ServiceAgreement),
    UpdatedDateTime = CURRENT_TIMESTAMP()
WHERE ProcessName = 'Dim_ServiceAgreement';
COMMIT;
