"""
Validate that ALL source tables exist and have data before running ETL.
This must pass 100% before bulk loads can run.
"""
import sys
from pathlib import Path
project_root = Path(__file__).parent.parent
sys.path.append(str(project_root))

import yaml
import logging
from utils.snowflake_connection import SnowflakeConnection

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def validate_source_data():
    """Validate all source tables exist and have data"""
    
    # Load config
    with open(project_root / 'config.yaml', 'r') as f:
        config = yaml.safe_load(f)
    
    conn = SnowflakeConnection.from_snow_cli(config['snowflake']['connection_name'])
    
    # Required source tables
    tenant_lake_tables = {
        'BUSINESSUNIT': 10,
        'JOBTYPE': 20,
        'CUSTOMER': 500,
        'EMPLOYEE': 50,
        'LOCATION': 300,
        'GENERALLEDGERACCOUNTTYPE': 5,
        'GENERALLEDGERACCOUNT': 100,
        'MATERIAL': 500,
        'EQUIPMENT': 500,
        'CUSTOMFIELDTYPE': 6,
        'SERVICEAGREEMENTTEMPLATE': 5,
        'SERVICEAGREEMENT': 200,
        'SERVICEAGREEMENTLOCATION': 300,
        'JOB': 5000,
        'CUSTOMFIELD': 4000,
        'INVOICE': 8000,
        'INVOICEITEM': 25000,
        'PURCHASEORDER': 4000,
        'INVENTORYBILL': 2000,
        'INVENTORYSHIPMENT': 1500,
        'INVENTORYRETURN': 800,
        'TECHNICIAN': 50,
        'GROSSPAYITEM': 9000,
        'EMPLOYEEGROSSPAYITEM': 2000,
        'PAYROLLADJUSTMENT': 800,
        'EMPLOYEEPAYROLLADJUSTMENT': 400,
        'SERVICEAGREEMENTVISIT': 750,
    }
    
    tenant_app_tables = {
        'REPORT.DIM_EMPLOYEE': 50,
        'GENERALLEDGER.JOURNALENTRY': 1000,
        'GENERALLEDGER.JOURNALENTRYITEM': 1000,
    }
    
    print("="*70)
    print("SOURCE DATA VALIDATION")
    print("="*70)
    
    # Validate TENANT_LAKE
    print("\n1. TENANT_LAKE.RAW_REAL")
    print("-"*70)
    tenant_lake_ok = True
    for table, expected_min in tenant_lake_tables.items():
        try:
            result = conn.fetch(f"SELECT COUNT(*) as cnt FROM TENANT_LAKE.RAW_REAL.{table}")
            actual = result[0]['CNT']
            status = '✓' if actual >= expected_min else '✗'
            if actual < expected_min:
                tenant_lake_ok = False
            print(f"{status} {table:35s}: {actual:6,} rows (min: {expected_min:,})")
        except Exception as e:
            print(f"✗ {table:35s}: ERROR - Table doesn't exist")
            tenant_lake_ok = False
    
    # Validate TENANT_APP_DM
    print("\n2. TENANT_APP_DM")
    print("-"*70)
    tenant_app_ok = True
    for table, expected_min in tenant_app_tables.items():
        try:
            result = conn.fetch(f"SELECT COUNT(*) as cnt FROM TENANT_APP_DM.{table}")
            actual = result[0]['CNT']
            status = '✓' if actual >= expected_min else '✗'
            if actual < expected_min:
                tenant_app_ok = False
            print(f"{status} {table:35s}: {actual:6,} rows (min: {expected_min:,})")
        except Exception as e:
            print(f"✗ {table:35s}: ERROR - Table doesn't exist")
            tenant_app_ok = False
    
    conn.close()
    
    # Summary
    print("\n" + "="*70)
    if tenant_lake_ok and tenant_app_ok:
        print("✓ ALL SOURCE DATA VALIDATED")
        print("="*70)
        print("\nReady to run ETL bulk loads!")
        return 0
    else:
        print("✗ SOURCE DATA VALIDATION FAILED")
        print("="*70)
        if not tenant_lake_ok:
            print("\n⚠ TENANT_LAKE.RAW_REAL has missing or incomplete tables")
        if not tenant_app_ok:
            print("\n⚠ TENANT_APP_DM has missing or incomplete tables")
        print("\nRun data generation first:")
        print("  python 01_Data_Generate/generate_fake_data.py")
        print("  python 01_Data_Generate/populate_external_db.py")
        return 1

if __name__ == "__main__":
    sys.exit(validate_source_data())

