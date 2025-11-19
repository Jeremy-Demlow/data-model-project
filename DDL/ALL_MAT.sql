-- =============================
-- MAT_EMPLOYEE_COMMISSIONRATES.sql
-- =============================
create or replace TRANSIENT TABLE ENG_STAGING.BRANDT_REPORT_DM.MAT_EMPLOYEE_COMMISSIONRATES (
	EMPLOYEEID NUMBER(38,0) NOT NULL,
	TENANTID NUMBER(38,0) NOT NULL,
	EMPLOYEENAME VARCHAR(250),
	EMPLOYEETYPE VARCHAR(50),
	COMMISSIONTYPE NUMBER(38,0) COMMENT 'From CommissionTypeEmployee custom field',
	JOBCOMMISSIONPCT NUMBER(10,4) COMMENT 'Job Commission% custom field',
	SAYEAR1COMMISSIONPCT NUMBER(10,4) COMMENT 'SA Year 1 Commission% custom field',
	SAYEAR2COMMISSIONPCT NUMBER(10,4) COMMENT 'SA Year 2 Commission% custom field',
	SAYEAR3PLUSCOMMISSIONPCT NUMBER(10,4) COMMENT 'SA Year 3+ Commission% custom field',
	LOADDATETIME TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	UPDATEDDATETIME TIMESTAMP_NTZ(9),
	primary key (EMPLOYEEID)
)COMMENT='Employee commission rates (Type 1 - current state only)'
;



-- =============================
-- MAT_INVOICE_LABORCOSTS.sql
-- =============================
create or replace TRANSIENT TABLE ENG_STAGING.BRANDT_REPORT_DM.MAT_INVOICE_LABORCOSTS (
	INVOICEID NUMBER(38,0) NOT NULL,
	TENANTID NUMBER(38,0) NOT NULL,
	JOBID NUMBER(38,0),
	POSTEDDATE DATE,
	INVOICEMODIFIEDON TIMESTAMP_NTZ(9),
	LASTLABORMODIFIEDON TIMESTAMP_NTZ(9),
	REGULARLABORCOST NUMBER(20,2) COMMENT 'Regular and overtime labor (grosspayitemtype 2,4)',
	PIECEWORKCOST NUMBER(20,2) COMMENT 'Piecework and performance pay (grosspayitemtype 1,3)',
	LABORBURDENCOST NUMBER(20,2) COMMENT 'Burden calculated from technician.burdenrate × hours',
	PAYROLLADJUSTMENTCOST NUMBER(20,2) COMMENT 'Payroll adjustments from payrolladjustment table',
	TOTALLABORCOST NUMBER(20,2),
	REGULARLABORHOURS NUMBER(20,2),
	PIECEWORKHOURS NUMBER(20,2),
	LOADDATETIME TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	UPDATEDDATETIME TIMESTAMP_NTZ(9),
	primary key (INVOICEID)
)COMMENT='Labor costs - refreshed when gross pay items added/modified'
;



-- =============================
-- MAT_INVOICE_MATERIALCOSTS.sql
-- =============================
create or replace TRANSIENT TABLE ENG_STAGING.BRANDT_REPORT_DM.MAT_INVOICE_MATERIALCOSTS (
	INVOICEID NUMBER(38,0) NOT NULL,
	TENANTID NUMBER(38,0) NOT NULL,
	JOBID NUMBER(38,0),
	POSTEDDATE DATE,
	INVOICEMODIFIEDON TIMESTAMP_NTZ(9),
	EQUIPMENTCOST NUMBER(20,2) COMMENT 'Sum of invoice items from equipment SKUs (non-PO)',
	MATERIALCOST NUMBER(20,2) COMMENT 'Sum of invoice items from material SKUs (non-PO)',
	TOTALITEMCOST NUMBER(20,2) COMMENT 'Equipment + Material',
	LOADDATETIME TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	UPDATEDDATETIME TIMESTAMP_NTZ(9),
	primary key (INVOICEID)
)COMMENT='Equipment and material costs - refreshed when invoices posted/modified'
;



-- =============================
-- MAT_INVOICE_POCOSTS.sql
-- =============================
create or replace TRANSIENT TABLE ENG_STAGING.BRANDT_REPORT_DM.MAT_INVOICE_POCOSTS (
	INVOICEID NUMBER(38,0) NOT NULL,
	TENANTID NUMBER(38,0) NOT NULL,
	JOBID NUMBER(38,0),
	POSTEDDATE DATE,
	INVOICEMODIFIEDON TIMESTAMP_NTZ(9),
	LASTPOMODIFIEDON TIMESTAMP_NTZ(9),
	POUNBILLEDCOST NUMBER(20,2) COMMENT 'PO amounts without bills (no inventoryshipment with bill_id)',
	POBILLEDCOST NUMBER(20,2) COMMENT 'PO amounts with bills (sum of inventorybill.total)',
	TOTALPOCOST NUMBER(20,2),
	POCOUNT NUMBER(38,0),
	LOADDATETIME TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	UPDATEDDATETIME TIMESTAMP_NTZ(9),
	primary key (INVOICEID)
)COMMENT='Purchase order costs - refreshed when POs created/billed'
;



-- =============================
-- MAT_INVOICE_REVENUE.sql
-- =============================
create or replace TRANSIENT TABLE ENG_STAGING.BRANDT_REPORT_DM.MAT_INVOICE_REVENUE (
	INVOICEID NUMBER(38,0) NOT NULL,
	TENANTID NUMBER(38,0) NOT NULL,
	JOBID NUMBER(38,0),
	INVOICEDATE DATE,
	POSTEDDATE DATE,
	INVOICEMODIFIEDON TIMESTAMP_NTZ(9) COMMENT 'For incremental refresh tracking',
	TRANSACTIONNUMBER VARCHAR(50),
	INVOICESTATUS NUMBER(38,0),
	TOTALREVENUE NUMBER(20,2) COMMENT 'Sum of all invoice items',
	INCOMEREVENUE NUMBER(20,2) COMMENT 'Sum of items with income GL account type',
	LINEITEMCOUNT NUMBER(38,0),
	LOADDATETIME TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	UPDATEDDATETIME TIMESTAMP_NTZ(9),
	primary key (INVOICEID)
)COMMENT='Invoice revenue measures - refreshed when invoices posted/modified'
;



-- =============================
-- MAT_JOB_RETURNS.sql
-- =============================
create or replace TRANSIENT TABLE ENG_STAGING.BRANDT_REPORT_DM.MAT_JOB_RETURNS (
	JOBID NUMBER(38,0) NOT NULL,
	TENANTID NUMBER(38,0) NOT NULL,
	LASTRETURNDATE DATE COMMENT 'Most recent return date for incremental refresh',
	TOTALRETURNCREDIT NUMBER(20,2) COMMENT 'Sum of return amounts (negative, reduces job cost)',
	RETURNCOUNT NUMBER(38,0),
	LOADDATETIME TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	UPDATEDDATETIME TIMESTAMP_NTZ(9),
	primary key (JOBID)
)COMMENT='Job-level inventory returns - refreshed when returns created'
;



-- =============================
-- MAT_SA_PERIOD_MEASURES.sql
-- =============================
create or replace TRANSIENT TABLE ENG_STAGING.BRANDT_REPORT_DM.MAT_SA_PERIOD_MEASURES (
	SERVICEAGREEMENTID NUMBER(38,0) NOT NULL,
	PERIODSTARTDATE DATE NOT NULL,
	PERIODENDDATE DATE NOT NULL,
	TENANTID NUMBER(38,0) NOT NULL,
	REVENUERECOGNITIONAMOUNT NUMBER(20,2) COMMENT 'Revenue from journal entries where postdate in period',
	LABORCOST NUMBER(20,2) COMMENT 'Labor from SA visit jobs in this period',
	BURDENCOST NUMBER(20,2) COMMENT 'Burden cost from SA visit jobs in this period',
	MATERIALCOST NUMBER(20,2) COMMENT 'Material costs from SA visit jobs in this period',
	EQUIPMENTCOST NUMBER(20,2) COMMENT 'Equipment costs from SA visit jobs in this period',
	LOADDATETIME TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	UPDATEDDATETIME TIMESTAMP_NTZ(9),
	primary key (SERVICEAGREEMENTID, PERIODSTARTDATE, PERIODENDDATE)
)COMMENT='SA measures by period - new periods added, historical immutable'
;
