-- Populate ETL_Watermark with initial records for all processes
USE DATABASE ENG_STAGING;
USE SCHEMA BRANDT_REPORT_DM;

INSERT INTO ETL_Watermark (ProcessName, LastRunStart, LastRunStatus)
VALUES
    ('Dim_Date', NULL, 'NOT_STARTED'),
    ('Dim_Tenant', NULL, 'NOT_STARTED'),
    ('Dim_BusinessUnit', NULL, 'NOT_STARTED'),
    ('Dim_Customer', NULL, 'NOT_STARTED'),
    ('Dim_Employee', NULL, 'NOT_STARTED'),
    ('Dim_GLAccount', NULL, 'NOT_STARTED'),
    ('Dim_Job', NULL, 'NOT_STARTED'),
    ('Dim_JobType', NULL, 'NOT_STARTED'),
    ('Dim_Location', NULL, 'NOT_STARTED'),
    ('Dim_ServiceAgreement', NULL, 'NOT_STARTED'),
    ('Dim_SKU', NULL, 'NOT_STARTED'),
    ('Mat_Employee_CommissionRates', NULL, 'NOT_STARTED'),
    ('Mat_Invoice_Revenue', NULL, 'NOT_STARTED'),
    ('Mat_Invoice_MaterialCosts', NULL, 'NOT_STARTED'),
    ('Mat_Invoice_POCosts', NULL, 'NOT_STARTED'),
    ('Mat_Invoice_LaborCosts', NULL, 'NOT_STARTED'),
    ('Mat_Job_Returns', NULL, 'NOT_STARTED'),
    ('Fact_Invoice', NULL, 'NOT_STARTED'),
    ('Fact_InvoiceItem', NULL, 'NOT_STARTED'),
    ('Fact_ServiceAgreement', NULL, 'NOT_STARTED'),
    ('Mat_SA_Period_Measures', NULL, 'NOT_STARTED');

SELECT 'ETL_Watermark populated with ' || COUNT(*) || ' processes' AS STATUS FROM ETL_Watermark;

