"""Populate tenant_app_dm external database with required data"""
import sys
from pathlib import Path
project_root = Path(__file__).parent.parent
sys.path.append(str(project_root))

import pandas as pd
import numpy as np
from datetime import datetime, timedelta, date
import logging
from utils.snowflake_connection import SnowflakeConnection
import yaml

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def populate_external_db():
    """Populate tenant_app_dm with required external data"""
    
    # Load config
    with open(project_root / 'config.yaml', 'r') as f:
        config = yaml.safe_load(f)
    
    conn = SnowflakeConnection.from_snow_cli(config['snowflake']['connection_name'])
    
    # Get employees from tenant_lake
    logger.info("Getting employees from TENANT_LAKE...")
    employees = conn.fetch('''
        SELECT id, _tenant_id, name 
        FROM TENANT_LAKE.RAW_REAL.EMPLOYEE 
        WHERE _tenant_id = 3457543957
    ''')
    
    # Populate dim_employee in tenant_app_dm.report
    logger.info(f"Populating tenant_app_dm.report.dim_employee with {len(employees)} employees...")
    conn.execute('USE TENANT_APP_DM.REPORT')
    
    emp_data = []
    for i, emp in enumerate(employees):
        emp_data.append({
            'EMPLOYEE_ID': emp['ID'],
            'EMPLOYEE_SK': i + 1,  # Surrogate key
            'USER_ID': emp['ID'],  # Same as ID for simplicity
            '_TENANT_ID': emp['_TENANT_ID'],
            'EMPLOYEE_NAME': emp['NAME']
        })
    
    emp_df = pd.DataFrame(emp_data)
    conn.session.write_pandas(emp_df, 'DIM_EMPLOYEE', overwrite=True, auto_create_table=False)
    logger.info(f"  ✓ Loaded {len(emp_data)} employees")
    
    # Get service agreements
    logger.info("Getting service agreements...")
    sas = conn.fetch('''
        SELECT id, _tenant_id, startdate, enddate 
        FROM TENANT_LAKE.RAW_REAL.SERVICEAGREEMENT 
        WHERE _tenant_id = 3457543957 AND active = 1
    ''')
    
    # Generate journal entries for revenue recognition
    logger.info(f"Generating journal entries for {len(sas)} service agreements...")
    conn.execute('USE TENANT_APP_DM.GENERALLEDGER')
    
    je_data = []
    jei_data = []
    je_id = 1
    jei_id = 1
    
    for sa in sas:
        # Generate 3-12 months of revenue recognition per SA
        num_months = np.random.randint(3, 13)
        start_date = pd.to_datetime(sa['STARTDATE']).date() if sa['STARTDATE'] else date(2023, 1, 1)
        
        for month_offset in range(num_months):
            post_date = start_date + timedelta(days=30 * month_offset)
            if post_date > date(2024, 12, 31):
                break
            
            # Journal entry
            je_data.append({
                'ID': je_id,
                '_TENANT_ID': sa['_TENANT_ID'],
                'POSTDATE': post_date,
                'ACTIVE': 1
            })
            
            # Journal entry item for revenue recognition
            amount = round(np.random.uniform(500, 2000), 2)
            jei_data.append({
                'ID': jei_id,
                'JOURNALENTRYID': je_id,
                '_TENANT_ID': sa['_TENANT_ID'],
                'SERVICEAGREEMENTID': sa['ID'],
                'AMOUNT': amount,
                'TRANSACTIONTYPE': 11,  # Revenue recognition
                'ENTRYTYPE': 1,  # Credit
                'ACTIVE': 1
            })
            
            je_id += 1
            jei_id += 1
    
    je_df = pd.DataFrame(je_data)
    conn.session.write_pandas(je_df, 'JOURNALENTRY', overwrite=True, auto_create_table=False)
    logger.info(f"  ✓ Loaded {len(je_data)} journal entries")
    
    jei_df = pd.DataFrame(jei_data)
    conn.session.write_pandas(jei_df, 'JOURNALENTRYITEM', overwrite=True, auto_create_table=False)
    logger.info(f"  ✓ Loaded {len(jei_data)} journal entry items")
    
    conn.close()
    logger.info("✓ External database populated successfully!")
    return 0

if __name__ == "__main__":
    sys.exit(populate_external_db())

