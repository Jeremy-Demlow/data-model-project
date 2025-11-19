"""Populate Dim_Date dimension table"""
import sys
from pathlib import Path
project_root = Path(__file__).parent.parent
sys.path.append(str(project_root))

from datetime import date, timedelta
import pandas as pd
import logging
from utils.snowflake_connection import SnowflakeConnection
import yaml

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def populate_dim_date():
    """Populate Dim_Date with dates from 2020-2030"""
    
    # Load config
    with open(project_root / 'config.yaml', 'r') as f:
        config = yaml.safe_load(f)
    
    conn = SnowflakeConnection.from_snow_cli(config['snowflake']['connection_name'])
    conn.execute('USE ENG_STAGING.BRANDT_REPORT_DM')
    
    logger.info("Generating date dimension data...")
    
    # Generate dates
    start_date = date(2020, 1, 1)
    end_date = date(2030, 12, 31)
    
    dates = []
    current = start_date
    while current <= end_date:
        datekey = int(current.strftime('%Y%m%d'))
        
        dates.append({
            'DATEKEY': datekey,
            'DATE': current,
            'DAYOFWEEK': current.weekday(),
            'DAYNAME': current.strftime('%A')[:10],
            'DAYOFMONTH': current.day,
            'DAYOFYEAR': current.timetuple().tm_yday,
            'WEEKOFYEAR': current.isocalendar()[1],
            'MONTHNUMBER': current.month,
            'MONTHNAME': current.strftime('%B')[:10],
            'YEAR': current.year,
            'ISWEEKDAY': current.weekday() < 5,
            'ISWEEKEND': current.weekday() >= 5,
        })
        current += timedelta(days=1)
    
    df = pd.DataFrame(dates)
    
    logger.info(f"Loading {len(df)} dates into Dim_Date...")
    conn.session.write_pandas(df, 'DIM_DATE', overwrite=True)
    
    result = conn.fetch('SELECT COUNT(*) as cnt FROM Dim_Date')
    logger.info(f"✓ Loaded {result[0]['CNT']:,} dates")
    
    conn.close()
    return 0

if __name__ == "__main__":
    sys.exit(populate_dim_date())

