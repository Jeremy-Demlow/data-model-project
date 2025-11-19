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
