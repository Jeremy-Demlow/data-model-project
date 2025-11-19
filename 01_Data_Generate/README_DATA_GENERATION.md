# Data Generation Strategy

## Phase 1: Source Data Generation (TENANT_LAKE + TENANT_APP_DM)

Generate ALL source operational data FIRST, validate it exists, THEN run ETL.

### Source Databases

1. **TENANT_LAKE.RAW_REAL** - Operational source data
   - customer, employee, job, invoice, invoiceitem
   - serviceagreement, serviceagreementlocation, serviceagreementtemplate, serviceagreementvisit
   - material, equipment, customfield, customfieldtype
   - purchaseorder, inventorybill, inventoryshipment, inventoryreturn
   - grosspayitem, employeegrosspayitem, technician
   - payrolladjustment, employeepayrolladjustment
   - businessunit, jobtype, location, generalledgeraccount, generalledgeraccounttype

2. **TENANT_APP_DM** - External reference database
   - report.dim_employee (for cross-reference)
   - generalledger.journalentry (for revenue recognition)
   - generalledger.journalentryitem (for SA revenue)

### Phase 2: Target Schema (BRANDT_REPORT_DM)

Create dimensional model tables (DDLs)

### Phase 3: ETL

Run bulk loads that transform source → dimensional model

## Key Insights

- COMMITs in bulk SQL might be unnecessary with autocommit
- Source tables should be validated BEFORE running bulk loads
- Bulk loads CREATE the analytical model FROM source data
- Dim_Date should be a bulk load, not manually populated

