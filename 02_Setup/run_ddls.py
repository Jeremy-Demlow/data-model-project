"""
Execute DDL files to create all tables in proper order.

This script executes DDL files in the correct dependency order to create
all dimension, fact, and materialized tables.
"""

import sys
import os
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent
sys.path.append(str(project_root))

import yaml
import logging
from typing import List
from snowflake.snowpark import Session

# Import connection module
from utils.snowflake_connection import SnowflakeConnection

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class DDLRunner:
    """Execute DDL files in proper order."""
    
    def __init__(self, config_path: str = None):
        """Initialize with configuration."""
        if config_path is None:
            config_path = project_root / "config.yaml"
        
        with open(config_path, 'r') as f:
            self.config = yaml.safe_load(f)
        
        self.ddl_dir = project_root / "DDL"
        self.session = None
        
    def connect(self):
        """Connect to Snowflake."""
        logger.info("Connecting to Snowflake...")
        self.conn = SnowflakeConnection.from_snow_cli(
            connection_name=self.config['snowflake']['connection_name']
        )
        self.session = self.conn.session
        logger.info("Connected successfully")
    
    def execute_sql_file(self, file_path: Path) -> bool:
        """Execute a single SQL file."""
        try:
            logger.info(f"  Executing {file_path.name}...")
            
            with open(file_path, 'r') as f:
                sql_content = f.read()
            
            # Split by semicolons and execute each statement
            statements = [stmt.strip() for stmt in sql_content.split(';') if stmt.strip()]
            
            for stmt in statements:
                if stmt and not stmt.startswith('--'):
                    self.session.sql(stmt).collect()
            
            logger.info(f"    Successfully executed {file_path.name}")
            return True
            
        except Exception as e:
            logger.error(f"    Error executing {file_path.name}: {e}")
            return False
    
    def run_ddls(self):
        """Execute DDL files in proper order."""
        logger.info("Starting DDL execution...")
        
        # Define execution order
        ddl_order = [
            # Core utility table
            "ETL_WATERMARK.sql",
            
            # Date dimension (standalone)
            "DIM_DATE.sql",
            
            # Tenant dimension
            "DIM_TENANT.sql",
            
            # All other dimensions (can run in any order)
            "DIM_BUSINESSUNIT.sql",
            "DIM_CUSTOMER.sql",
            "DIM_EMPLOYEE.sql",
            "DIM_GLACCOUNT.sql",
            "DIM_JOB.sql",
            "DIM_JOBTYPE.sql",
            "DIM_LOCATION.sql",
            "DIM_SERVICEAGREEMENT.sql",
            "DIM_SKU.sql",
            
            # Materialized tables for invoice measures (needed by facts)
            "MAT_EMPLOYEE_COMMISSIONRATES.sql",
            "MAT_INVOICE_LABORCOSTS.sql",
            "MAT_INVOICE_MATERIALCOSTS.sql",
            "MAT_INVOICE_POCOSTS.sql",
            "MAT_INVOICE_REVENUE.sql",
            "MAT_JOB_RETURNS.sql",
            
            # Fact tables (depend on dimensions and mat tables)
            "FACT_INVOICE.sql",
            "FACT_INVOICEITEM.sql",
            "FACT_SERVICEAGREEMENT.sql",
            
            # Service agreement period measures (depends on fact)
            "MAT_SA_PERIOD_MEASURES.sql",
            
            # Baseline and metric tracking tables
            "MAT_REPORT_BASELINE.sql",
            "MAT_METRIC_SUMMARY.sql",
        ]
        
        # Track success/failure
        results = {}
        
        for ddl_file in ddl_order:
            file_path = self.ddl_dir / ddl_file
            
            if not file_path.exists():
                logger.warning(f"  DDL file not found: {ddl_file} - Skipping")
                results[ddl_file] = "SKIPPED"
                continue
            
            success = self.execute_sql_file(file_path)
            results[ddl_file] = "SUCCESS" if success else "FAILED"
        
        # Summary
        logger.info("\n" + "="*60)
        logger.info("DDL Execution Summary")
        logger.info("="*60)
        
        success_count = sum(1 for status in results.values() if status == "SUCCESS")
        failed_count = sum(1 for status in results.values() if status == "FAILED")
        skipped_count = sum(1 for status in results.values() if status == "SKIPPED")
        
        for ddl_file, status in results.items():
            status_symbol = "✓" if status == "SUCCESS" else ("✗" if status == "FAILED" else "⊘")
            logger.info(f"{status_symbol} {ddl_file}: {status}")
        
        logger.info("="*60)
        logger.info(f"Total: {len(results)} files")
        logger.info(f"Success: {success_count}, Failed: {failed_count}, Skipped: {skipped_count}")
        logger.info("="*60)
        
        return failed_count == 0
    
    def close(self):
        """Close the Snowflake connection."""
        if self.session:
            self.session.close()
            logger.info("Connection closed")


def main():
    """Main execution function."""
    try:
        runner = DDLRunner()
        runner.connect()
        success = runner.run_ddls()
        
        if success:
            logger.info("All DDLs executed successfully!")
            
            # Populate ETL_Watermark only (Dim_Date will be populated by bulk load)
            logger.info("\nPopulating ETL_Watermark...")
            watermark_sql = Path(__file__).parent / "populate_watermark.sql"
            if watermark_sql.exists():
                with open(watermark_sql, 'r') as f:
                    wm_sql = f.read()
                for stmt in wm_sql.split(';'):
                    if stmt.strip():
                        lines = [l for l in stmt.split('\n') if l.strip() and not l.strip().startswith('--')]
                        if lines:
                            clean_stmt = '\n'.join(lines).strip()
                            runner.conn.execute(clean_stmt)
                verify_result = runner.conn.fetch("SELECT COUNT(*) as cnt FROM ETL_Watermark")
                logger.info(f"  ✓ Loaded {verify_result[0]['CNT']} process records")
            
        runner.close()
        
        if success:
            return 0
        else:
            logger.error("Some DDLs failed to execute")
            return 1
            
    except Exception as e:
        logger.error(f"Error during DDL execution: {e}", exc_info=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())

