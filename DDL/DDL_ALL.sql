/* =============================================== */
/* FILE: ddl_dim_businessunit.sql                              */
/* =============================================== */

-- ============================================
-- Dim_BusinessUnit
-- ============================================
-- Grain: One row per business unit (current state)
-- Purpose: Business unit attributes and hierarchy
-- Type: Type 1 (overwrite on change)
-- Source: tenant_app_dm.dbo.businessunit
-- ============================================

-- 1. Drop schema if it already exists
DROP SCHEMA IF EXISTS ENG_STAGING.BRANDT_REPORT_DM;

-- 2. Create transient schema
CREATE OR REPLACE TRANSIENT SCHEMA ENG_STAGING.BRANDT_REPORT_DM
    COMMENT = 'Schema for Brandt Report Data Mart models (FACT/DIM tables)';

USE DATABASE ENG_STAGING;
USE SCHEMA BRANDT_REPORT_DM;


CREATE TABLE Dim_BusinessUnit (
    -- Surrogate Key
    BusinessUnitKey INT PRIMARY KEY IDENTITY,

    -- Natural Key
    BusinessUnitId BIGINT NOT NULL,
    TenantId INT NOT NULL,

    UNIQUE (BusinessUnitId, TenantId),

    -- Attributes (minimal - only fields that exist in source)
    BusinessUnitName VARCHAR(250),  -- businessunit.name

    -- Status
    IsActive BOOLEAN,  -- Implied in source filtering

    -- Audit
    LoadDateTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    UpdatedDateTime TIMESTAMP

    -- --INDEXes
    --INDEX idx_bu_id (BusinessUnitId),
    --INDEX idx_tenant (TenantId),
    --INDEX idx_name (BusinessUnitName),
    --INDEX idx_is_active (IsActive)
);

COMMENT ON TABLE Dim_BusinessUnit IS 'Business unit dimension (Type 1 - current state only)';
COMMENT ON COLUMN Dim_BusinessUnit.BusinessUnitKey IS 'Surrogate key';
COMMENT ON COLUMN Dim_BusinessUnit.BusinessUnitId IS 'Natural key from source system';




/* =============================================== */
/* FILE: ddl_dim_customer.sql                              */
/* =============================================== */

-- ============================================
-- Dim_Customer
-- ============================================
-- Grain: One row per customer (current state)
-- Purpose: Customer attributes
-- Type: Type 1 (overwrite on change)
-- Source: tenant_app_dm.dbo.customer
-- ============================================

CREATE TABLE Dim_Customer (
    -- Surrogate Key
    CustomerKey INT PRIMARY KEY IDENTITY,

    -- Natural Key
    CustomerId BIGINT NOT NULL,
    TenantId INT NOT NULL,

    UNIQUE (CustomerId, TenantId),

    -- Attributes (minimal - only fields that exist in source)
    CustomerName VARCHAR(250),  -- customer.name

    -- Status
    IsActive BOOLEAN,  -- customer.active

    -- Audit
    LoadDateTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    UpdatedDateTime TIMESTAMP

    -- --INDEXes
    --INDEX idx_customer_id (CustomerId),
    --INDEX idx_tenant (TenantId),
    --INDEX idx_name (CustomerName),
    --INDEX idx_is_active (IsActive)
);

COMMENT ON TABLE Dim_Customer IS 'Customer dimension (Type 1 - current state only)';
COMMENT ON COLUMN Dim_Customer.CustomerKey IS 'Surrogate key';
COMMENT ON COLUMN Dim_Customer.CustomerId IS 'Natural key from source system';




/* =============================================== */
/* FILE: ddl_dim_date.sql                              */
/* =============================================== */

-- ============================================
-- Dim_Date
-- ============================================
-- Grain: One row per calendar day
-- Purpose: Standard date dimension for time-based analysis
-- Type: Type 1 (static, no updates)
-- ============================================

CREATE TABLE Dim_Date (
    DateKey INT PRIMARY KEY,  -- YYYYMMDD format
    Date DATE UNIQUE NOT NULL,

    -- Day attributes
    DayOfWeek INT,           -- 1=Sunday, 7=Saturday
    DayName VARCHAR(10),     -- Sunday, Monday, etc.
    DayOfMonth INT,
    DayOfYear INT,

    -- Week attributes
    WeekOfYear INT,
    WeekBeginDate DATE,
    WeekEndDate DATE,

    -- Month attributes
    MonthNumber INT,
    MonthName VARCHAR(10),
    MonthBeginDate DATE,
    MonthEndDate DATE,
    MonthYear VARCHAR(7),    -- YYYY-MM

    -- Quarter attributes
    Quarter INT,
    QuarterName VARCHAR(6),  -- Q1, Q2, Q3, Q4
    QuarterBeginDate DATE,
    QuarterEndDate DATE,

    -- Year attributes
    Year INT,

    -- Fiscal attributes (adjust as needed)
    FiscalYear INT,
    FiscalQuarter INT,
    FiscalMonth INT,

    -- Flags
    IsWeekday BOOLEAN,
    IsWeekend BOOLEAN,
    IsHoliday BOOLEAN,
    HolidayName VARCHAR(50),

    -- Relative indicators
    IsCurrentDay BOOLEAN,
    IsCurrentWeek BOOLEAN,
    IsCurrentMonth BOOLEAN,
    IsCurrentQuarter BOOLEAN,
    IsCurrentYear BOOLEAN,

    -- Audit
    LoadDateTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    UpdatedDateTime TIMESTAMP

    -- --INDEXes
    --INDEX idx_date (Date),
    --INDEX idx_year_month (Year, MonthNumber),
    --INDEX idx_year_quarter (Year, Quarter)
);

COMMENT ON TABLE Dim_Date IS 'Standard date dimension - populated once for multiple years';
COMMENT ON COLUMN Dim_Date.DateKey IS 'Surrogate key in YYYYMMDD format (e.g. 20240101)';
COMMENT ON COLUMN Dim_Date.FiscalYear IS 'Adjust based on company fiscal year start';




/* =============================================== */
/* FILE: ddl_dim_employee.sql                              */
/* =============================================== */

-- ============================================
-- Dim_Employee
-- ============================================
-- Grain: One row per employee (current state)
-- Purpose: Employee/salesperson attributes
-- Type: Type 1 (overwrite on change)
-- Source: tenant_app_dm.dbo.employee, salesperson logic
-- ============================================

CREATE TABLE Dim_Employee (
    -- Surrogate Key
    EmployeeKey INT PRIMARY KEY IDENTITY,

    -- Natural Key
    EmployeeId BIGINT NOT NULL,
    TenantId INT NOT NULL,

    UNIQUE (EmployeeId, TenantId),

    -- Attributes (minimal - only fields that exist in source)
    EmployeeName VARCHAR(250),  -- employee.name
    EmployeeType VARCHAR(50),   -- 'Employee' (hardcoded in salesperson CTE)

    -- Status
    IsActive BOOLEAN,  -- employee.active

    -- Audit
    LoadDateTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    UpdatedDateTime TIMESTAMP

    -- --INDEXes
    --INDEX idx_employee_id (EmployeeId),
    --INDEX idx_tenant (TenantId),
    --INDEX idx_name (EmployeeName),
    --INDEX idx_type (EmployeeType),
    --INDEX idx_is_active (IsActive)
);

COMMENT ON TABLE Dim_Employee IS 'Employee dimension (Type 1 - current state only)';
COMMENT ON COLUMN Dim_Employee.EmployeeKey IS 'Surrogate key';
COMMENT ON COLUMN Dim_Employee.EmployeeId IS 'Natural key from source system';
COMMENT ON COLUMN Dim_Employee.EmployeeType IS 'Employee, Technician, Salesperson, etc.';




/* =============================================== */
/* FILE: ddl_dim_glaccount.sql                              */
/* =============================================== */

-- ============================================
-- Dim_GLAccount
-- ============================================
-- Grain: One row per GL account (current state)
-- Purpose: General ledger account attributes
-- Type: Type 1 (overwrite on change)
-- Source: tenant_app_dm.dbo.generalledgeraccount, generalledgeraccounttype
-- NOTE: Original SQL only uses type.name for '%income%' filtering
-- ============================================

CREATE TABLE Dim_GLAccount (
    -- Surrogate Key
    GLAccountKey INT PRIMARY KEY IDENTITY,

    -- Natural Key
    GLAccountId BIGINT NOT NULL,
    TenantId INT NOT NULL,

    UNIQUE (GLAccountId, TenantId),

    -- Attributes (minimal - only fields that exist in source)
    GLAccountType VARCHAR(100),  -- generalledgeraccounttype.name (used for '%income%' filter)
    GLAccountTypeId BIGINT,      -- generalledgeraccount.type_id

    -- Status
    IsActive BOOLEAN,  -- Implied in source filtering

    -- Audit
    LoadDateTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    UpdatedDateTime TIMESTAMP

    -- --INDEXes
    --INDEX idx_gl_id (GLAccountId),
    --INDEX idx_tenant (TenantId),
    --INDEX idx_type (GLAccountType),
    --INDEX idx_type_id (GLAccountTypeId),
    --INDEX idx_is_active (IsActive)
);

COMMENT ON TABLE Dim_GLAccount IS 'GL account dimension (Type 1 - current state only)';
COMMENT ON COLUMN Dim_GLAccount.GLAccountKey IS 'Surrogate key';
COMMENT ON COLUMN Dim_GLAccount.GLAccountId IS 'Natural key from source system';
COMMENT ON COLUMN Dim_GLAccount.GLAccountType IS 'Type name from generalledgeraccounttype (e.g., Income)';




/* =============================================== */
/* FILE: ddl_dim_job.sql                              */
/* =============================================== */

-- ============================================
-- Dim_Job
-- ============================================
-- Grain: One row per job (current state)
-- Purpose: Job attributes
-- Type: Type 1 (overwrite on change)
-- Source: tenant_app_dm.dbo.job
-- ============================================

CREATE TABLE Dim_Job (
    -- Surrogate Key
    JobKey INT PRIMARY KEY IDENTITY,

    -- Natural Key
    JobId BIGINT NOT NULL,
    TenantId INT NOT NULL,

    UNIQUE (JobId, TenantId),

    -- Attributes (minimal - only fields that exist in source)
    JobSummary VARCHAR(16777216),  -- job.summary

    -- Status
    IsActive BOOLEAN,  -- job.active

    -- Service Agreement link
    ServiceAgreementId BIGINT,  -- job.service_agreement_id (for SA visit linkage)

    -- Audit
    LoadDateTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    UpdatedDateTime TIMESTAMP

    -- --INDEXes
    --INDEX idx_job_id (JobId),
    --INDEX idx_tenant (TenantId),
    --INDEX idx_sa (ServiceAgreementId),
    --INDEX idx_is_active (IsActive)
);

COMMENT ON TABLE Dim_Job IS 'Job dimension (Type 1 - current state only)';
COMMENT ON COLUMN Dim_Job.JobKey IS 'Surrogate key';
COMMENT ON COLUMN Dim_Job.JobId IS 'Natural key from source system';
COMMENT ON COLUMN Dim_Job.ServiceAgreementId IS 'If not null, this job is part of a service agreement';




/* =============================================== */
/* FILE: ddl_dim_jobtype.sql                              */
/* =============================================== */

-- ============================================
-- Dim_JobType
-- ============================================
-- Grain: One row per job type (current state)
-- Purpose: Job type attributes
-- Type: Type 1 (overwrite on change)
-- Source: tenant_app_dm.dbo.jobtype
-- ============================================

CREATE TABLE Dim_JobType (
    -- Surrogate Key
    JobTypeKey INT PRIMARY KEY IDENTITY,

    -- Natural Key
    JobTypeId BIGINT NOT NULL,
    TenantId INT NOT NULL,

    UNIQUE (JobTypeId, TenantId),

    -- Attributes (minimal - only fields that exist in source)
    JobTypeName VARCHAR(250),  -- jobtype.name

    -- Status
    IsActive BOOLEAN,  -- Implied in source filtering

    -- Audit
    LoadDateTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    UpdatedDateTime TIMESTAMP

    -- --INDEXes
    --INDEX idx_jobtype_id (JobTypeId),
    --INDEX idx_tenant (TenantId),
    --INDEX idx_name (JobTypeName),
    --INDEX idx_is_active (IsActive)
);

COMMENT ON TABLE Dim_JobType IS 'Job type dimension (Type 1 - current state only)';
COMMENT ON COLUMN Dim_JobType.JobTypeKey IS 'Surrogate key';
COMMENT ON COLUMN Dim_JobType.JobTypeId IS 'Natural key from source system';




/* =============================================== */
/* FILE: ddl_dim_location.sql                              */
/* =============================================== */

-- ============================================
-- Dim_Location
-- ============================================
-- Grain: One row per location (current state)
-- Purpose: Service location attributes
-- Type: Type 1 (overwrite on change)
-- Source: tenant_app_dm.dbo.location
-- ============================================

CREATE TABLE Dim_Location (
    -- Surrogate Key
    LocationKey INT PRIMARY KEY IDENTITY,

    -- Natural Key
    LocationId BIGINT NOT NULL,
    TenantId INT NOT NULL,

    UNIQUE (LocationId, TenantId),

    -- Attributes (minimal - only fields that exist in source)
    LocationName VARCHAR(250),  -- location.name

    -- Status
    IsActive BOOLEAN,  -- Implied in source filtering

    -- Audit
    LoadDateTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    UpdatedDateTime TIMESTAMP

    -- --INDEXes
    --INDEX idx_location_id (LocationId),
    --INDEX idx_tenant (TenantId),
    --INDEX idx_name (LocationName),
    --INDEX idx_is_active (IsActive)
);

COMMENT ON TABLE Dim_Location IS 'Service location dimension (Type 1 - current state only)';
COMMENT ON COLUMN Dim_Location.LocationKey IS 'Surrogate key';
COMMENT ON COLUMN Dim_Location.LocationId IS 'Natural key from source system';




/* =============================================== */
/* FILE: ddl_dim_serviceagreement.sql                              */
/* =============================================== */

-- ============================================
-- Dim_ServiceAgreement
-- ============================================
-- Grain: One row per service agreement (current state)
-- Purpose: Service agreement attributes
-- Type: Type 1 (overwrite on change)
-- Source: tenant_app_dm.dbo.serviceagreement
-- ============================================

CREATE TABLE Dim_ServiceAgreement (
    -- Surrogate Key
    ServiceAgreementKey INT PRIMARY KEY IDENTITY,

    -- Natural Key
    ServiceAgreementId BIGINT NOT NULL,
    TenantId INT NOT NULL,

    UNIQUE (ServiceAgreementId, TenantId),

    -- Attributes (minimal - only fields that exist in source)
    ServiceAgreementName VARCHAR(250),  -- serviceagreement.name

    -- Foreign Key Natural IDs (for joining to other dimensions)
    CustomerId BIGINT,           -- serviceagreement.customerid
    LocationId BIGINT,           -- From serviceagreementlocation.locationid
    BusinessUnitId BIGINT,       -- serviceagreement.businessunitid
    SoldById BIGINT,             -- serviceagreement.soldbyid (resolves to employee)

    -- Template
    TemplateId BIGINT,
    TemplateName VARCHAR(250),
    TemplateType VARCHAR(250),

    -- Dates
    StartDate DATE,
    EndDate DATE,

    -- Renewal
    RenewalYear INT,                      -- Calculated: 1, 2, 3, etc.
    RenewalGroupInitialAgreementId BIGINT,
    RenewedById BIGINT,                   -- If this SA was renewed, link to new SA

    -- Status
    Status INT,
    StatusName VARCHAR(50),
    IsActive BOOLEAN,

    -- Audit
    LoadDateTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    UpdatedDateTime TIMESTAMP

    -- --INDEXes
    --INDEX idx_sa_id (ServiceAgreementId),
    --INDEX idx_tenant (TenantId),
    --INDEX idx_name (ServiceAgreementName),
    --INDEX idx_customer (CustomerId),
    --INDEX idx_location (LocationId),
    --INDEX idx_business_unit (BusinessUnitId),
    --INDEX idx_soldby (SoldById),
    --INDEX idx_template (TemplateId),
    --INDEX idx_renewal_year (RenewalYear),
    --INDEX idx_renewal_group (RenewalGroupInitialAgreementId),
    --INDEX idx_status (Status),
    --INDEX idx_is_active (IsActive),
    --INDEX idx_start_date (StartDate),
    --INDEX idx_end_date (EndDate)
);

COMMENT ON TABLE Dim_ServiceAgreement IS 'Service agreement dimension (Type 1 - current state only)';
COMMENT ON COLUMN Dim_ServiceAgreement.ServiceAgreementKey IS 'Surrogate key';
COMMENT ON COLUMN Dim_ServiceAgreement.ServiceAgreementId IS 'Natural key from source system';
COMMENT ON COLUMN Dim_ServiceAgreement.RenewalYear IS 'Calculated: ROW_NUMBER within renewal group by start date';




/* =============================================== */
/* FILE: ddl_dim_sku.sql                              */
/* =============================================== */

-- ============================================
-- Dim_SKU
-- ============================================
-- Grain: One row per SKU (current state)
-- Purpose: Product/material/equipment attributes
-- Type: Type 1 (overwrite on change)
-- Source: tenant_app_dm.dbo.material, equipment
-- NOTE: Original SQL only uses id for existence checks, no other attributes
-- ============================================

CREATE TABLE Dim_SKU (
    -- Surrogate Key
    SKUKey INT PRIMARY KEY IDENTITY,

    -- Natural Key
    SKUId BIGINT NOT NULL,
    SKUType INT NOT NULL,  -- 1=Material, 2=Equipment
    TenantId INT NOT NULL,

    UNIQUE (SKUId, SKUType, TenantId),

    -- Attributes (minimal - only ID used in source for existence check)
    -- No name/description fields accessed in original SQL

    -- Status
    IsActive BOOLEAN,  -- Implied in source filtering

    -- Audit
    LoadDateTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    UpdatedDateTime TIMESTAMP

    -- --INDEXes
    --INDEX idx_sku_id (SKUId, SKUType),
    --INDEX idx_tenant (TenantId),
    --INDEX idx_type (SKUType),
    --INDEX idx_is_active (IsActive)
);

COMMENT ON TABLE Dim_SKU IS 'SKU dimension (Type 1 - current state only)';
COMMENT ON COLUMN Dim_SKU.SKUKey IS 'Surrogate key';
COMMENT ON COLUMN Dim_SKU.SKUId IS 'Natural key from source system (material.id, equipment.id)';
COMMENT ON COLUMN Dim_SKU.SKUType IS '1=Material, 2=Equipment';
--COMMENT ON COMMENT Dim_SKU IS 'NOTE: Source only uses material.id and equipment.id for existence checks - no other attributes accessed';




/* =============================================== */
/* FILE: ddl_etl_watermark.sql                              */
/* =============================================== */

-- ============================================
-- ETL Watermark Table
-- ============================================
-- Purpose: Track last successful run date/time for incremental loads
-- Usage: Each ETL process updates its row after successful completion
-- ============================================

CREATE TABLE IF NOT EXISTS ETL_Watermark (
    ProcessName VARCHAR(100) PRIMARY KEY,
    LastRunStart TIMESTAMP,
    LastRunEnd TIMESTAMP,
    LastRunStatus VARCHAR(20),  -- 'SUCCESS', 'RUNNING', 'FAILED'
    LastSuccessfulRunEnd TIMESTAMP,
    RowsProcessed BIGINT,
    ErrorMessage VARCHAR(1000),
    CreatedDateTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    UpdatedDateTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================
-- View: ETL Status Summary
-- ============================================

CREATE OR REPLACE VIEW vw_ETL_Status AS
SELECT
    ProcessName,
    LastRunStatus,
    LastSuccessfulRunEnd,
    DATEDIFF(minute, LastRunStart, LastRunEnd) AS LastRunDurationMinutes,
    RowsProcessed,
    DATEDIFF(hour, LastSuccessfulRunEnd, CURRENT_TIMESTAMP()) AS HoursSinceLastSuccess,
    UpdatedDateTime
FROM ETL_Watermark
ORDER BY ProcessName;

-- ============================================
-- Initial Setup: Insert process rows
-- ============================================

-- Layer 1: Measure Tables
INSERT INTO ETL_Watermark (ProcessName)
SELECT * FROM (VALUES
    ('Mat_Invoice_Revenue'),
    ('Mat_Invoice_MaterialCosts'),
    ('Mat_Invoice_POCosts'),
    ('Mat_Invoice_LaborCosts'),
    ('Mat_Job_Returns'),
    ('Mat_SA_Period_Measures'),
    ('Mat_Employee_CommissionRates')
) AS processes(ProcessName)
WHERE NOT EXISTS (SELECT 1 FROM ETL_Watermark WHERE ProcessName = processes.ProcessName);

-- Layer 2: Fact Tables
INSERT INTO ETL_Watermark (ProcessName)
SELECT * FROM (VALUES
    ('Fact_Invoice'),
    ('Fact_InvoiceItem')
) AS processes(ProcessName)
WHERE NOT EXISTS (SELECT 1 FROM ETL_Watermark WHERE ProcessName = processes.ProcessName);

-- Dimensions
INSERT INTO ETL_Watermark (ProcessName)
SELECT * FROM (VALUES
    ('Dim_Date'),
    ('Dim_Customer'),
    ('Dim_Location'),
    ('Dim_Employee'),
    ('Dim_BusinessUnit'),
    ('Dim_JobType'),
    ('Dim_Job'),
    ('Dim_ServiceAgreement'),
    ('Dim_SKU'),
    ('Dim_GLAccount')
) AS processes(ProcessName)
WHERE NOT EXISTS (SELECT 1 FROM ETL_Watermark WHERE ProcessName = processes.ProcessName);

COMMIT;




/* =============================================== */
/* FILE: ddl_fact_invoice.sql                              */
/* =============================================== */

-- ============================================
-- Fact_Invoice
-- ============================================
-- Grain: One row per invoice
-- Purpose: Invoice-level denormalized fact with all base measures (NO calculations)
-- Built from: Layer 1 measure tables (Mat_Invoice_*)
-- ============================================

CREATE TABLE Fact_Invoice (
    -- Keys
    InvoiceKey BIGINT PRIMARY KEY IDENTITY,
    InvoiceId BIGINT UNIQUE NOT NULL,
    JobId BIGINT NOT NULL,
    TenantId INT NOT NULL,

    -- Dimension Foreign Keys (surrogate keys to dimensions)
    DateKey INT,            -- FK to Dim_Date (based on PostedDate)
    CustomerKey INT,        -- FK to Dim_Customer
    LocationKey INT,        -- FK to Dim_Location
    BusinessUnitKey INT,    -- FK to Dim_BusinessUnit
    JobTypeKey INT,         -- FK to Dim_JobType
    EmployeeKey INT,        -- FK to Dim_Employee (salesperson)
    JobKey INT,             -- FK to Dim_Job

    -- Date attributes (denormalized for convenience)
	InvoicedOn DATE,
    PostedDate DATE,
    InvoiceDate DATE,

    -- Degenerate dimensions
    TransactionNumber VARCHAR(50),
    InvoiceStatus INT,
    IsAdjustment BOOLEAN,
    AdjustmentToInvoiceId BIGINT,

    -- ========================================
    -- BASE MEASURES ONLY (NO CALCULATIONS)
    -- From Mat_Invoice_Revenue
    -- ========================================
    TotalRevenue DECIMAL(20,2),
    IncomeRevenue DECIMAL(20,2),
    LineItemCount INT,

    -- ========================================
    -- From Mat_Invoice_MaterialCosts
    -- ========================================
    EquipmentCost DECIMAL(20,2),
    MaterialCost DECIMAL(20,2),
    TotalItemCost DECIMAL(20,2),

    -- ========================================
    -- From Mat_Invoice_POCosts
    -- ========================================
    POUnbilledCost DECIMAL(20,2),
    POBilledCost DECIMAL(20,2),
    TotalPOCost DECIMAL(20,2),
    POCount INT,

    -- ========================================
    -- From Mat_Invoice_LaborCosts
    -- ========================================
    RegularLaborCost DECIMAL(20,2),
    PieceworkCost DECIMAL(20,2),
    LaborBurdenCost DECIMAL(20,2),
    PayrollAdjustmentCost DECIMAL(20,2),
    TotalLaborCost DECIMAL(20,2),
    RegularLaborHours DECIMAL(20,2),
    PieceworkHours DECIMAL(20,2),

    -- Audit
    LoadDateTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    UpdatedDateTime TIMESTAMP

    -- --INDEXes
    --INDEX idx_date_key (DateKey),
    --INDEX idx_posted_date (PostedDate),
    --INDEX idx_invoice_date (InvoiceDate),
    --INDEX idx_customer (CustomerKey),
    --INDEX idx_location (LocationKey),
    --INDEX idx_business_unit (BusinessUnitKey),
    --INDEX idx_job_type (JobTypeKey),
    --INDEX idx_employee (EmployeeKey),
    --INDEX idx_job (JobKey),
    --INDEX idx_tenant (TenantId),
    --INDEX idx_status (InvoiceStatus),
    --INDEX idx_is_adjustment (IsAdjustment)
);

COMMENT ON TABLE Fact_Invoice IS 'Invoice-level fact with denormalized base measures from Layer 1';
COMMENT ON COLUMN Fact_Invoice.InvoiceKey IS 'Surrogate key';
COMMENT ON COLUMN Fact_Invoice.InvoiceId IS 'Natural key from source system';
COMMENT ON COLUMN Fact_Invoice.IncomeRevenue IS 'Revenue from income GL accounts only (for job revenue calculation)';
COMMENT ON COLUMN Fact_Invoice.TotalLaborCost IS 'Regular + Piecework + Burden + Adjustments (pre-summed from Mat_Invoice_LaborCosts)';



/* =============================================== */
/* FILE: ddl_fact_invoiceitem.sql                              */
/* =============================================== */

-- ============================================
-- Fact_InvoiceItem
-- ============================================
-- Grain: One row per invoice line item
-- Purpose: Line item-level fact for SKU/product analysis, GL reconciliation
-- Built from: Source invoice item tables directly
-- ============================================

CREATE TABLE Fact_InvoiceItem (
    -- Keys
    InvoiceItemKey BIGINT PRIMARY KEY IDENTITY,
    InvoiceItemId BIGINT UNIQUE NOT NULL,
    InvoiceId BIGINT NOT NULL,
    JobId BIGINT,
    TenantId INT NOT NULL,

    -- Dimension Foreign Keys (surrogate keys to dimensions)
    DateKey INT,         -- FK to Dim_Date (from invoice posted date)
    CustomerKey INT,     -- FK to Dim_Customer
    LocationKey INT,     -- FK to Dim_Location
    BusinessUnitKey INT, -- FK to Dim_BusinessUnit
    JobTypeKey INT,      -- FK to Dim_JobType
    JobKey INT,          -- FK to Dim_Job
    SKUKey INT,          -- FK to Dim_SKU
    GLAccountKey INT,    -- FK to Dim_GLAccount

    -- Date attributes (denormalized from invoice)
	InvoicedOn DATE,
    PostedDate DATE,
    InvoiceDate DATE,

    -- Degenerate dimensions
    ItemDescription VARCHAR(500),
    ItemSequence INT,
    SKUType INT,  -- 1=Material, 2=Equipment, 3=Service, etc.

    -- ========================================
    -- BASE MEASURES ONLY (NO CALCULATIONS)
    -- ========================================

    -- Revenue measures
    ItemRevenue DECIMAL(20,2),       -- invoiceitem.total
    ItemQuantity DECIMAL(20,4),      -- invoiceitem.quantity
    ItemUnitPrice DECIMAL(20,4),     -- invoiceitem.price

    -- Cost measures
    ItemCost DECIMAL(20,2),          -- invoiceitem.totalcost

    -- Flags
    IsIncome BOOLEAN,                -- From GL Account Type = 'Income'
    IsPOItem BOOLEAN,                -- Has PO reference
    POItemId BIGINT,                 -- Reference to PO item

    -- Audit
    LoadDateTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    UpdatedDateTime TIMESTAMP

    -- --INDEXes
    --INDEX idx_invoice (InvoiceId),
    --INDEX idx_invoice_item (InvoiceItemId),
    --INDEX idx_job (JobKey),
    --INDEX idx_date_key (DateKey),
    --INDEX idx_posted_date (PostedDate),
    --INDEX idx_customer (CustomerKey),
    --INDEX idx_sku (SKUKey),
    --INDEX idx_gl_account (GLAccountKey),
    --INDEX idx_sku_type (SKUType),
    --INDEX idx_is_income (IsIncome),
    --INDEX idx_tenant (TenantId)
);

COMMENT ON TABLE Fact_InvoiceItem IS 'Line item-level fact for SKU and product analysis';
COMMENT ON COLUMN Fact_InvoiceItem.InvoiceItemKey IS 'Surrogate key';
COMMENT ON COLUMN Fact_InvoiceItem.InvoiceItemId IS 'Natural key from source system';
COMMENT ON COLUMN Fact_InvoiceItem.SKUType IS '1=Material, 2=Equipment, 3=Service (from invoiceitem.skureference_skutype)';
COMMENT ON COLUMN Fact_InvoiceItem.IsIncome IS 'TRUE if GL Account Type contains "Income"';
COMMENT ON COLUMN Fact_InvoiceItem.IsPOItem IS 'TRUE if invoiceitem.procurementsource_purchaseorderitemid is not null';



/* =============================================== */
/* FILE: ddl_fact_serviceagreement.sql                              */
/* =============================================== */

-- ============================================
-- Fact_ServiceAgreement
-- ============================================
-- Grain: One row per service agreement per reporting period
-- Purpose: Service agreement revenue recognition and costs by period
-- Built from: Mat_SA_Period_Measures
-- ============================================

CREATE TABLE Fact_ServiceAgreement (
    -- Keys
    ServiceAgreementKey BIGINT PRIMARY KEY IDENTITY,
    ServiceAgreementId BIGINT NOT NULL,
    PeriodStartDate DATE NOT NULL,
    PeriodEndDate DATE NOT NULL,
    TenantId INT NOT NULL,

    -- Composite unique constraint (one row per SA per period)
    UNIQUE (ServiceAgreementId, PeriodStartDate, PeriodEndDate, TenantId),

    -- Dimension Foreign Keys (surrogate keys to dimensions)
    DateKey INT,                -- FK to Dim_Date (based on PeriodStartDate)
    CustomerKey INT,            -- FK to Dim_Customer
    LocationKey INT,            -- FK to Dim_Location (primary location)
    BusinessUnitKey INT,        -- FK to Dim_BusinessUnit
    EmployeeKey INT,            -- FK to Dim_Employee (sold by)
    ServiceAgreementDimKey INT, -- FK to Dim_ServiceAgreement

    -- SA Attributes (denormalized for convenience)
    SAName VARCHAR(500),
    SATemplateType VARCHAR(250),
    SAStartDate DATE,
    SAEndDate DATE,
    SARenewalYear INT,
    SAStatus INT,

    -- ========================================
    -- BASE MEASURES (From Mat_SA_Period_Measures)
    -- ========================================
    RevenueRecognitionAmount DECIMAL(20,2),  -- Revenue recognized in this period
    LaborCost DECIMAL(20,2),                 -- Direct labor from visit jobs
    BurdenCost DECIMAL(20,2),                -- Labor burden from visit jobs
    MaterialCost DECIMAL(20,2),              -- Material costs from visit jobs
    EquipmentCost DECIMAL(20,2),             -- Equipment costs from visit jobs

    -- ========================================
    -- COMMISSION CALCULATION INPUTS
    -- (Commission calculated in reporting layer)
    -- ========================================
    SoldByEmployeeId BIGINT,
    JobCommissionPct DECIMAL(10,2),
    SAYear1CommissionPct DECIMAL(10,2),
    SAYear2CommissionPct DECIMAL(10,2),
    SAYear3PlusCommissionPct DECIMAL(10,2),

    -- Audit
    LoadDateTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    UpdatedDateTime TIMESTAMP

    -- --INDEXes
    --INDEX idx_sa (ServiceAgreementId),
    --INDEX idx_period_start (PeriodStartDate),
    --INDEX idx_period_end (PeriodEndDate),
    --INDEX idx_date_key (DateKey),
    --INDEX idx_customer (CustomerKey),
    --INDEX idx_location (LocationKey),
    --INDEX idx_business_unit (BusinessUnitKey),
    --INDEX idx_employee (EmployeeKey),
    --INDEX idx_sa_dim (ServiceAgreementDimKey),
    --INDEX idx_tenant (TenantId),
    --INDEX idx_status (SAStatus),
    --INDEX idx_renewal_year (SARenewalYear)
);

COMMENT ON TABLE Fact_ServiceAgreement IS 'Service agreement periodic fact with revenue recognition and visit job costs';
COMMENT ON COLUMN Fact_ServiceAgreement.ServiceAgreementKey IS 'Surrogate key for this fact';
COMMENT ON COLUMN Fact_ServiceAgreement.ServiceAgreementId IS 'Natural key from source system';
COMMENT ON COLUMN Fact_ServiceAgreement.PeriodStartDate IS 'Start date of reporting period (from ETL parameters)';
COMMENT ON COLUMN Fact_ServiceAgreement.PeriodEndDate IS 'End date of reporting period (from ETL parameters)';
COMMENT ON COLUMN Fact_ServiceAgreement.RevenueRecognitionAmount IS 'Revenue recognized via journal entries in this period';
COMMENT ON COLUMN Fact_ServiceAgreement.LaborCost IS 'Direct labor costs from SA visit jobs';
COMMENT ON COLUMN Fact_ServiceAgreement.BurdenCost IS 'Labor burden costs from SA visit jobs';
COMMENT ON COLUMN Fact_ServiceAgreement.SARenewalYear IS 'Renewal year (1, 2, 3+) based on renewal chain';
COMMENT ON COLUMN Fact_ServiceAgreement.SoldByEmployeeId IS 'Employee who sold the SA (for commission calculation)';




/* =============================================== */
/* FILE: ddl_mat_employee_commissionrates.sql                              */
/* =============================================== */

-- ============================================
-- Mat_Employee_CommissionRates
-- ============================================
-- Grain: One row per employee
-- Purpose: Store employee commission rates (Type 1 - current state only)
-- Change Frequency: Low (when commission rates changed)
-- Source: tenant_app_dm.dbo.customfield (employee custom fields)
-- ============================================

CREATE TABLE Mat_Employee_CommissionRates (
    -- Primary Key
    EmployeeId BIGINT PRIMARY KEY,

    -- Foreign Keys
    TenantId INT NOT NULL,

    -- Employee info
    EmployeeName VARCHAR(250),
    EmployeeType VARCHAR(50),  -- 'Employee', etc.

    -- ========================================
    -- COMMISSION RATE MEASURES (TYPE 1)
    -- ========================================
    CommissionType INT,                       -- From custom field
    JobCommissionPct DECIMAL(10,4),          -- Job commission %
    SAYear1CommissionPct DECIMAL(10,4),      -- SA Year 1 commission %
    SAYear2CommissionPct DECIMAL(10,4),      -- SA Year 2 commission %
    SAYear3PlusCommissionPct DECIMAL(10,4),  -- SA Year 3+ commission %

    -- Audit
    LoadDateTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    UpdatedDateTime TIMESTAMP

    -- --INDEXes
    --INDEX idx_tenant (TenantId),
    --INDEX idx_name (EmployeeName)
);

COMMENT ON TABLE Mat_Employee_CommissionRates IS 'Employee commission rates (Type 1 - current state only)';
COMMENT ON COLUMN Mat_Employee_CommissionRates.CommissionType IS 'From CommissionTypeEmployee custom field';
COMMENT ON COLUMN Mat_Employee_CommissionRates.JobCommissionPct IS 'Job Commission% custom field';
COMMENT ON COLUMN Mat_Employee_CommissionRates.SAYear1CommissionPct IS 'SA Year 1 Commission% custom field';
COMMENT ON COLUMN Mat_Employee_CommissionRates.SAYear2CommissionPct IS 'SA Year 2 Commission% custom field';
COMMENT ON COLUMN Mat_Employee_CommissionRates.SAYear3PlusCommissionPct IS 'SA Year 3+ Commission% custom field';




/* =============================================== */
/* FILE: ddl_mat_invoice_laborcosts.sql                              */
/* =============================================== */

-- ============================================
-- Mat_Invoice_LaborCosts
-- ============================================
-- Grain: One row per invoice
-- Purpose: Store labor cost measures (regular, piecework, burden, adjustments)
-- Change Frequency: High (when gross pay items added/modified)
-- Source: tenant_app_dm.dbo.grosspayitem, employeegrosspayitem, technician, payrolladjustment
-- ============================================

CREATE TABLE Mat_Invoice_LaborCosts (
    -- Primary Key
    InvoiceId BIGINT PRIMARY KEY,

    -- Foreign Keys
    TenantId INT NOT NULL,
    JobId BIGINT,

    -- Date fields for filtering
    PostedDate DATE,
    InvoiceModifiedOn TIMESTAMP,
    LastLaborModifiedOn TIMESTAMP,  -- For incremental refresh

    -- ========================================
    -- LABOR COST MEASURES (BASE ONLY)
    -- ========================================
    RegularLaborCost DECIMAL(20,2),      -- grosspayitemtype in (2,4)
    PieceworkCost DECIMAL(20,2),         -- grosspayitemtype in (1,3)
    LaborBurdenCost DECIMAL(20,2),       -- burdenrate × paiddurationhours
    PayrollAdjustmentCost DECIMAL(20,2), -- From payrolladjustment
    TotalLaborCost DECIMAL(20,2),        -- Sum of all labor components

    -- Detail counts
    RegularLaborHours DECIMAL(20,2),
    PieceworkHours DECIMAL(20,2),

    -- Audit
    LoadDateTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    UpdatedDateTime TIMESTAMP

    -- --INDEXes
    --INDEX idx_tenant (TenantId),
    --INDEX idx_job (JobId),
    --INDEX idx_posted_date (PostedDate),
    --INDEX idx_labor_modified (LastLaborModifiedOn)
);

COMMENT ON TABLE Mat_Invoice_LaborCosts IS 'Labor costs - refreshed when gross pay items added/modified';
COMMENT ON COLUMN Mat_Invoice_LaborCosts.RegularLaborCost IS 'Regular and overtime labor (grosspayitemtype 2,4)';
COMMENT ON COLUMN Mat_Invoice_LaborCosts.PieceworkCost IS 'Piecework and performance pay (grosspayitemtype 1,3)';
COMMENT ON COLUMN Mat_Invoice_LaborCosts.LaborBurdenCost IS 'Burden calculated from technician.burdenrate × hours';
COMMENT ON COLUMN Mat_Invoice_LaborCosts.PayrollAdjustmentCost IS 'Payroll adjustments from payrolladjustment table';




/* =============================================== */
/* FILE: ddl_mat_invoice_materialcosts.sql                              */
/* =============================================== */

-- ============================================
-- Mat_Invoice_MaterialCosts
-- ============================================
-- Grain: One row per invoice
-- Purpose: Store equipment and material cost measures
-- Change Frequency: High (when invoices are posted/modified)
-- Source: tenant_app_dm.dbo.invoiceitem, equipment, material
-- ============================================

CREATE TABLE Mat_Invoice_MaterialCosts (
    -- Primary Key
    InvoiceId BIGINT PRIMARY KEY,

    -- Foreign Keys
    TenantId INT NOT NULL,
    JobId BIGINT,

    -- Date fields for filtering
    PostedDate DATE,
    InvoiceModifiedOn TIMESTAMP,

    -- ========================================
    -- MATERIAL COST MEASURES (BASE ONLY)
    -- ========================================
    EquipmentCost DECIMAL(20,2),  -- From equipment SKUs
    MaterialCost DECIMAL(20,2),   -- From material SKUs
    TotalItemCost DECIMAL(20,2),  -- Equipment + Material

    -- Audit
    LoadDateTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    UpdatedDateTime TIMESTAMP

    -- --INDEXes
    --INDEX idx_tenant (TenantId),
    --INDEX idx_job (JobId),
    --INDEX idx_posted_date (PostedDate),
    --INDEX idx_modified (InvoiceModifiedOn)
);

COMMENT ON TABLE Mat_Invoice_MaterialCosts IS 'Equipment and material costs - refreshed when invoices posted/modified';
COMMENT ON COLUMN Mat_Invoice_MaterialCosts.EquipmentCost IS 'Sum of invoice items from equipment SKUs (non-PO)';
COMMENT ON COLUMN Mat_Invoice_MaterialCosts.MaterialCost IS 'Sum of invoice items from material SKUs (non-PO)';
COMMENT ON COLUMN Mat_Invoice_MaterialCosts.TotalItemCost IS 'Equipment + Material';




/* =============================================== */
/* FILE: ddl_mat_invoice_pocosts.sql                              */
/* =============================================== */

-- ============================================
-- Mat_Invoice_POCosts
-- ============================================
-- Grain: One row per invoice
-- Purpose: Store purchase order cost measures
-- Change Frequency: Medium (when POs are created/billed)
-- Source: tenant_app_dm.dbo.purchaseorder, inventorybill, inventoryshipment
-- ============================================

CREATE TABLE Mat_Invoice_POCosts (
    -- Primary Key
    InvoiceId BIGINT PRIMARY KEY,

    -- Foreign Keys
    TenantId INT NOT NULL,
    JobId BIGINT,

    -- Date fields for filtering
    PostedDate DATE,
    InvoiceModifiedOn TIMESTAMP,
    LastPOModifiedOn TIMESTAMP,  -- For incremental refresh

    -- ========================================
    -- PO COST MEASURES (BASE ONLY)
    -- ========================================
    POUnbilledCost DECIMAL(20,2),  -- POs without bills
    POBilledCost DECIMAL(20,2),    -- POs with bills
    TotalPOCost DECIMAL(20,2),     -- Unbilled + Billed
    POCount INT,

    -- Audit
    LoadDateTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    UpdatedDateTime TIMESTAMP

    -- --INDEXes
    --INDEX idx_tenant (TenantId),
    --INDEX idx_job (JobId),
    --INDEX idx_posted_date (PostedDate),
    --INDEX idx_po_modified (LastPOModifiedOn)
);

COMMENT ON TABLE Mat_Invoice_POCosts IS 'Purchase order costs - refreshed when POs created/billed';
COMMENT ON COLUMN Mat_Invoice_POCosts.POUnbilledCost IS 'PO amounts without bills (no inventoryshipment with bill_id)';
COMMENT ON COLUMN Mat_Invoice_POCosts.POBilledCost IS 'PO amounts with bills (sum of inventorybill.total)';




/* =============================================== */
/* FILE: ddl_mat_invoice_revenue.sql                              */
/* =============================================== */

-- ============================================
-- Mat_Invoice_Revenue
-- ============================================
-- Grain: One row per invoice
-- Purpose: Store invoice revenue measures
-- Change Frequency: High (when invoices are posted/modified)
-- Source: tenant_app_dm.dbo.invoice, invoiceitem
-- ============================================

CREATE TABLE Mat_Invoice_Revenue (
    -- Primary Key
    InvoiceId BIGINT PRIMARY KEY,

    -- Foreign Keys
    TenantId INT NOT NULL,
    JobId BIGINT,

    -- Date fields for filtering
	InvoicedOn DATE,
    InvoiceDate DATE,
    PostedDate DATE,
    InvoiceModifiedOn TIMESTAMP,

    -- Degenerate dimensions
    TransactionNumber VARCHAR(50),
    InvoiceStatus INT,

    -- ========================================
    -- REVENUE MEASURES (BASE ONLY)
    -- ========================================
    TotalRevenue DECIMAL(20,2),
    IncomeRevenue DECIMAL(20,2),  -- Filtered for income GL accounts
    LineItemCount INT,

    -- Audit
    LoadDateTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    UpdatedDateTime TIMESTAMP

    -- --INDEXes
    --INDEX idx_tenant (TenantId),
    --INDEX idx_job (JobId),
    --INDEX idx_posted_date (PostedDate),
    --INDEX idx_modified (InvoiceModifiedOn),
    --INDEX idx_status (InvoiceStatus)
);

COMMENT ON TABLE Mat_Invoice_Revenue IS 'Invoice revenue measures - refreshed when invoices posted/modified';
COMMENT ON COLUMN Mat_Invoice_Revenue.TotalRevenue IS 'Sum of all invoice items';
COMMENT ON COLUMN Mat_Invoice_Revenue.IncomeRevenue IS 'Sum of items with income GL account type';
COMMENT ON COLUMN Mat_Invoice_Revenue.InvoiceModifiedOn IS 'For incremental refresh tracking';




/* =============================================== */
/* FILE: ddl_mat_job_returns.sql                              */
/* =============================================== */

-- ============================================
-- Mat_Job_Returns
-- ============================================
-- Grain: One row per job
-- Purpose: Store inventory return credits at job level
-- Change Frequency: Low (when inventory returned)
-- Source: tenant_app_dm.dbo.inventoryreturn
-- ============================================

CREATE TABLE Mat_Job_Returns (
    -- Primary Key
    JobId BIGINT PRIMARY KEY,

    -- Foreign Keys
    TenantId INT NOT NULL,

    -- Date fields for filtering
    LastReturnDate DATE,  -- Most recent return date

    -- ========================================
    -- RETURN MEASURES (BASE ONLY)
    -- ========================================
    TotalReturnCredit DECIMAL(20,2),  -- Negative value (reduces cost)
    ReturnCount INT,                   -- Number of returns

    -- Audit
    LoadDateTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    UpdatedDateTime TIMESTAMP

    -- --INDEXes
    --INDEX idx_tenant (TenantId),
    --INDEX idx_last_return_date (LastReturnDate)
);

COMMENT ON TABLE Mat_Job_Returns IS 'Job-level inventory returns - refreshed when returns created';
COMMENT ON COLUMN Mat_Job_Returns.TotalReturnCredit IS 'Sum of return amounts (negative, reduces job cost)';
COMMENT ON COLUMN Mat_Job_Returns.LastReturnDate IS 'Most recent return date for incremental refresh';




/* =============================================== */
/* FILE: ddl_mat_sa_period_measures.sql                              */
/* =============================================== */

-- ============================================
-- Mat_SA_Period_Measures
-- ============================================
-- Grain: One row per service agreement per period
-- Purpose: Store SA revenue recognition and direct costs by period
-- Change Frequency: Low (new periods added, historical periods immutable)
-- Source: tenant_app_dm.generalledger.journalentry, serviceagreement, job, invoiceitem, grosspayitem
-- ============================================

CREATE TABLE Mat_SA_Period_Measures (
    -- Composite Primary Key
    ServiceAgreementId BIGINT NOT NULL,
    PeriodStartDate DATE NOT NULL,
    PeriodEndDate DATE NOT NULL,

    PRIMARY KEY (ServiceAgreementId, PeriodStartDate, PeriodEndDate),

    -- Foreign Keys
    TenantId INT NOT NULL,

    -- ========================================
    -- REVENUE MEASURES (BASE ONLY)
    -- ========================================
    RevenueRecognitionAmount DECIMAL(20,2),  -- From journal entries (transactiontype=11, entrytype=1)

    -- ========================================
    -- DIRECT COST MEASURES (BASE ONLY)
    -- ========================================
    LaborCost DECIMAL(20,2),       -- From grosspayitem.amount
    BurdenCost DECIMAL(20,2),      -- From grosspayitem.burdencostamount
    MaterialCost DECIMAL(20,2),    -- From invoiceitem where skutype=1
    EquipmentCost DECIMAL(20,2),   -- From invoiceitem where skutype=2

    -- Audit
    LoadDateTime TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    UpdatedDateTime TIMESTAMP

    -- --INDEXes
    --INDEX idx_sa (ServiceAgreementId),
    --INDEX idx_tenant (TenantId),
    --INDEX idx_period_start (PeriodStartDate),
    --INDEX idx_period_end (PeriodEndDate)
);

COMMENT ON TABLE Mat_SA_Period_Measures IS 'SA measures by period - new periods added, historical immutable';
COMMENT ON COLUMN Mat_SA_Period_Measures.RevenueRecognitionAmount IS 'Revenue from journal entries where postdate in period';
COMMENT ON COLUMN Mat_SA_Period_Measures.LaborCost IS 'Labor from SA visit jobs in this period';
COMMENT ON COLUMN Mat_SA_Period_Measures.BurdenCost IS 'Burden cost from SA visit jobs in this period';
COMMENT ON COLUMN Mat_SA_Period_Measures.MaterialCost IS 'Material costs from SA visit jobs in this period';
COMMENT ON COLUMN Mat_SA_Period_Measures.EquipmentCost IS 'Equipment costs from SA visit jobs in this period';
