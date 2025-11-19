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
