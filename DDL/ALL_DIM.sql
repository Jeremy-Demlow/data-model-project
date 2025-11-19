-- =============================
-- DIM_BUSINESSUNIT.sql
-- =============================
create or replace TRANSIENT TABLE ENG_STAGING.BRANDT_REPORT_DM.DIM_BUSINESSUNIT (
	BUSINESSUNITKEY NUMBER(38,0) NOT NULL autoincrement start 1 increment 1 noorder COMMENT 'Surrogate key',
	BUSINESSUNITID NUMBER(38,0) NOT NULL COMMENT 'Natural key from source system',
	TENANTID NUMBER(38,0) NOT NULL,
	BUSINESSUNITNAME VARCHAR(250),
	ISACTIVE BOOLEAN,
	LOADDATETIME TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	UPDATEDDATETIME TIMESTAMP_NTZ(9),
	unique (BUSINESSUNITID, TENANTID),
	primary key (BUSINESSUNITKEY)
)COMMENT='Business unit dimension (Type 1 - current state only)'
;



-- =============================
-- DIM_CUSTOMER.sql
-- =============================
create or replace TRANSIENT TABLE ENG_STAGING.BRANDT_REPORT_DM.DIM_CUSTOMER (
	CUSTOMERKEY NUMBER(38,0) NOT NULL autoincrement start 1 increment 1 noorder COMMENT 'Surrogate key',
	CUSTOMERID NUMBER(38,0) NOT NULL COMMENT 'Natural key from source system',
	TENANTID NUMBER(38,0) NOT NULL,
	CUSTOMERNAME VARCHAR(250),
	ISACTIVE BOOLEAN,
	LOADDATETIME TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	UPDATEDDATETIME TIMESTAMP_NTZ(9),
	unique (CUSTOMERID, TENANTID),
	primary key (CUSTOMERKEY)
)COMMENT='Customer dimension (Type 1 - current state only)'
;



-- =============================
-- DIM_DATE.sql
-- =============================
create or replace TRANSIENT TABLE ENG_STAGING.BRANDT_REPORT_DM.DIM_DATE (
	DATEKEY NUMBER(38,0) NOT NULL COMMENT 'Surrogate key in YYYYMMDD format (e.g. 20240101)',
	DATE DATE NOT NULL,
	DAYOFWEEK NUMBER(38,0),
	DAYNAME VARCHAR(10),
	DAYOFMONTH NUMBER(38,0),
	DAYOFYEAR NUMBER(38,0),
	WEEKOFYEAR NUMBER(38,0),
	WEEKBEGINDATE DATE,
	WEEKENDDATE DATE,
	MONTHNUMBER NUMBER(38,0),
	MONTHNAME VARCHAR(10),
	MONTHBEGINDATE DATE,
	MONTHENDDATE DATE,
	MONTHYEAR VARCHAR(7),
	QUARTER NUMBER(38,0),
	QUARTERNAME VARCHAR(6),
	QUARTERBEGINDATE DATE,
	QUARTERENDDATE DATE,
	YEAR NUMBER(38,0),
	FISCALYEAR NUMBER(38,0) COMMENT 'Adjust based on company fiscal year start',
	FISCALQUARTER NUMBER(38,0),
	FISCALMONTH NUMBER(38,0),
	ISWEEKDAY BOOLEAN,
	ISWEEKEND BOOLEAN,
	ISHOLIDAY BOOLEAN,
	HOLIDAYNAME VARCHAR(50),
	ISCURRENTDAY BOOLEAN,
	ISCURRENTWEEK BOOLEAN,
	ISCURRENTMONTH BOOLEAN,
	ISCURRENTQUARTER BOOLEAN,
	ISCURRENTYEAR BOOLEAN,
	LOADDATETIME TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	UPDATEDDATETIME TIMESTAMP_NTZ(9),
	unique (DATE),
	primary key (DATEKEY)
)COMMENT='Standard date dimension - populated once for multiple years'
;



-- =============================
-- DIM_EMPLOYEE.sql
-- =============================
create or replace TRANSIENT TABLE ENG_STAGING.BRANDT_REPORT_DM.DIM_EMPLOYEE (
	EMPLOYEEKEY NUMBER(38,0) NOT NULL autoincrement start 1 increment 1 noorder COMMENT 'Surrogate key',
	EMPLOYEEID NUMBER(38,0) NOT NULL COMMENT 'Natural key from source system',
	TENANTID NUMBER(38,0) NOT NULL,
	EMPLOYEENAME VARCHAR(250),
	EMPLOYEETYPE VARCHAR(50) COMMENT 'Employee, Technician, Salesperson, etc.',
	ISACTIVE BOOLEAN,
	LOADDATETIME TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	UPDATEDDATETIME TIMESTAMP_NTZ(9),
	unique (EMPLOYEEID, TENANTID),
	primary key (EMPLOYEEKEY)
)COMMENT='Employee dimension (Type 1 - current state only)'
;



-- =============================
-- DIM_GLACCOUNT.sql
-- =============================
create or replace TRANSIENT TABLE ENG_STAGING.BRANDT_REPORT_DM.DIM_GLACCOUNT (
	GLACCOUNTKEY NUMBER(38,0) NOT NULL autoincrement start 1 increment 1 noorder COMMENT 'Surrogate key',
	GLACCOUNTID NUMBER(38,0) NOT NULL COMMENT 'Natural key from source system',
	TENANTID NUMBER(38,0) NOT NULL,
	GLACCOUNTTYPE VARCHAR(100) COMMENT 'Type name from generalledgeraccounttype (e.g., Income)',
	GLACCOUNTTYPEID NUMBER(38,0),
	ISACTIVE BOOLEAN,
	LOADDATETIME TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	UPDATEDDATETIME TIMESTAMP_NTZ(9),
	unique (GLACCOUNTID, TENANTID),
	primary key (GLACCOUNTKEY)
)COMMENT='GL account dimension (Type 1 - current state only)'
;



-- =============================
-- DIM_JOB.sql
-- =============================
create or replace TRANSIENT TABLE ENG_STAGING.BRANDT_REPORT_DM.DIM_JOB (
	JOBKEY NUMBER(38,0) NOT NULL autoincrement start 1 increment 1 noorder COMMENT 'Surrogate key',
	JOBID NUMBER(38,0) NOT NULL COMMENT 'Natural key from source system',
	TENANTID NUMBER(38,0) NOT NULL,
	JOBSUMMARY VARCHAR(16777216),
	ISACTIVE BOOLEAN,
	SERVICEAGREEMENTID NUMBER(38,0) COMMENT 'If not null, this job is part of a service agreement',
	LOADDATETIME TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	UPDATEDDATETIME TIMESTAMP_NTZ(9),
	unique (JOBID, TENANTID),
	primary key (JOBKEY)
)COMMENT='Job dimension (Type 1 - current state only)'
;



-- =============================
-- DIM_JOBTYPE.sql
-- =============================
create or replace TRANSIENT TABLE ENG_STAGING.BRANDT_REPORT_DM.DIM_JOBTYPE (
	JOBTYPEKEY NUMBER(38,0) NOT NULL autoincrement start 1 increment 1 noorder COMMENT 'Surrogate key',
	JOBTYPEID NUMBER(38,0) NOT NULL COMMENT 'Natural key from source system',
	TENANTID NUMBER(38,0) NOT NULL,
	JOBTYPENAME VARCHAR(250),
	ISACTIVE BOOLEAN,
	LOADDATETIME TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	UPDATEDDATETIME TIMESTAMP_NTZ(9),
	unique (JOBTYPEID, TENANTID),
	primary key (JOBTYPEKEY)
)COMMENT='Job type dimension (Type 1 - current state only)'
;



-- =============================
-- DIM_LOCATION.sql
-- =============================
create or replace TRANSIENT TABLE ENG_STAGING.BRANDT_REPORT_DM.DIM_LOCATION (
	LOCATIONKEY NUMBER(38,0) NOT NULL autoincrement start 1 increment 1 noorder COMMENT 'Surrogate key',
	LOCATIONID NUMBER(38,0) NOT NULL COMMENT 'Natural key from source system',
	TENANTID NUMBER(38,0) NOT NULL,
	LOCATIONNAME VARCHAR(250),
	ISACTIVE BOOLEAN,
	LOADDATETIME TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	UPDATEDDATETIME TIMESTAMP_NTZ(9),
	unique (LOCATIONID, TENANTID),
	primary key (LOCATIONKEY)
)COMMENT='Service location dimension (Type 1 - current state only)'
;



-- =============================
-- DIM_SERVICEAGREEMENT.sql
-- =============================
create or replace TRANSIENT TABLE ENG_STAGING.BRANDT_REPORT_DM.DIM_SERVICEAGREEMENT (
	SERVICEAGREEMENTKEY NUMBER(38,0) NOT NULL autoincrement start 1 increment 1 noorder COMMENT 'Surrogate key',
	SERVICEAGREEMENTID NUMBER(38,0) NOT NULL COMMENT 'Natural key from source system',
	TENANTID NUMBER(38,0) NOT NULL,
	SERVICEAGREEMENTNAME VARCHAR(250),
	CUSTOMERID NUMBER(38,0),
	LOCATIONID NUMBER(38,0),
	BUSINESSUNITID NUMBER(38,0),
	SOLDBYID NUMBER(38,0),
	TEMPLATEID NUMBER(38,0),
	TEMPLATENAME VARCHAR(250),
	TEMPLATETYPE VARCHAR(250),
	STARTDATE DATE,
	ENDDATE DATE,
	RENEWALYEAR NUMBER(38,0) COMMENT 'Calculated: ROW_NUMBER within renewal group by start date',
	RENEWALGROUPINITIALAGREEMENTID NUMBER(38,0),
	RENEWEDBYID NUMBER(38,0),
	STATUS NUMBER(38,0),
	STATUSNAME VARCHAR(50),
	ISACTIVE BOOLEAN,
	LOADDATETIME TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	UPDATEDDATETIME TIMESTAMP_NTZ(9),
	unique (SERVICEAGREEMENTID, TENANTID),
	primary key (SERVICEAGREEMENTKEY)
)COMMENT='Service agreement dimension (Type 1 - current state only)'
;



-- =============================
-- DIM_SKU.sql
-- =============================
create or replace TRANSIENT TABLE ENG_STAGING.BRANDT_REPORT_DM.DIM_SKU (
	SKUKEY NUMBER(38,0) NOT NULL autoincrement start 1 increment 1 noorder COMMENT 'Surrogate key',
	SKUID NUMBER(38,0) NOT NULL COMMENT 'Natural key from source system (material.id, equipment.id)',
	SKUTYPE NUMBER(38,0) NOT NULL COMMENT '1=Material, 2=Equipment',
	TENANTID NUMBER(38,0) NOT NULL,
	ISACTIVE BOOLEAN,
	LOADDATETIME TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	UPDATEDDATETIME TIMESTAMP_NTZ(9),
	unique (SKUID, SKUTYPE, TENANTID),
	primary key (SKUKEY)
)COMMENT='SKU dimension (Type 1 - current state only)'
;
