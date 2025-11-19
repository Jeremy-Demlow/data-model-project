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
