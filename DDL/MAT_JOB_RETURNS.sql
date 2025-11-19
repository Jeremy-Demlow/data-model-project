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
