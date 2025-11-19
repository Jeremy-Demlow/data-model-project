"""
Execute bulk load SQL files in proper dependency order.

This script orchestrates the execution of all bulk load files with proper
dependency resolution, error handling, and progress tracking.
"""

import sys
import os
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent
sys.path.append(str(project_root))

import yaml
import logging
from typing import List, Dict, Set
from datetime import datetime
from snowflake.snowpark import Session

# Import connection module
from utils.snowflake_connection import SnowflakeConnection

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class BulkLoadRunner:
    """Execute bulk load files with dependency management."""
    
    def __init__(self, config_path: str = None):
        """Initialize with configuration."""
        if config_path is None:
            config_path = project_root / "config.yaml"
        
        with open(config_path, 'r') as f:
            self.config = yaml.safe_load(f)
        
        self.bulks_dir = project_root / "Bulks"
        self.conn = None
        self.session = None
        
        # Define execution phases with dependencies
        self.load_phases = {
            # Phase 1: Dimensions (no dependencies)
            "dimensions": [
                "etl_dim_date_BULK.sql",  # Date first - other tables reference it
                "etl_dim_tenant_BULK.sql",
                "etl_dim_businessunit_BULK.sql",
                "etl_dim_customer_BULK.sql",
                "etl_dim_employee_BULK.sql",
                "etl_dim_glaccount_BULK.sql",
                "etl_dim_job_BULK.sql",
                "etl_dim_jobtype_BULK.sql",
                "etl_dim_location_BULK.sql",
                "etl_dim_serviceagreement_BULK.sql",
                "etl_dim_sku_BULK.sql",
            ],
            
            # Phase 2: Materialized measure tables (depend on dimensions and source)
            "measures": [
                "etl_mat_employee_commissionrates_BULK.sql",
                "etl_mat_invoice_revenue_BULK.sql",
                "etl_mat_invoice_materialcosts_BULK.sql",
                "etl_mat_invoice_pocosts_BULK.sql",
                "etl_mat_invoice_laborcosts_BULK.sql",
                "etl_mat_job_returns_BULK.sql",
            ],
            
            # Phase 3: Fact tables (depend on dimensions and measures)
            "facts": [
                "etl_fact_invoice_BULK.sql",
                "etl_fact_invoiceitem_BULK.sql",
                "etl_fact_serviceagreement_BULK.sql",
            ],
            
            # Phase 4: Service agreement period measures (depend on facts)
            "sa_measures": [
                "etl_mat_sa_period_measures_BULK.sql",
            ],
        }
    
    def connect(self):
        """Connect to Snowflake."""
        logger.info("Connecting to Snowflake...")
        self.conn = SnowflakeConnection.from_snow_cli(
            connection_name=self.config['snowflake']['connection_name']
        )
        self.session = self.conn.session
        logger.info("Connected successfully")
    
    def execute_bulk_file(self, file_path: Path) -> Dict[str, any]:
        """Execute a single bulk load file."""
        result = {
            'file': file_path.name,
            'status': 'FAILED',
            'rows_processed': 0,
            'duration_seconds': 0,
            'error': None
        }
        
        try:
            logger.info(f"  Executing {file_path.name}...")
            start_time = datetime.now()
            
            with open(file_path, 'r') as f:
                sql_content = f.read()
            
            # Simple approach: split by semicolon and execute each statement
            statements = sql_content.split(';')
            
            for stmt in statements:
                stmt = stmt.strip()
                
                # Skip empty or comment-only statements
                if not stmt:
                    continue
                    
                # Remove comment lines but keep code
                lines = [line for line in stmt.split('\n') if line.strip() and not line.strip().startswith('--')]
                clean_stmt = '\n'.join(lines).strip()
                
                if clean_stmt:  # Only execute if there's actual code
                    try:
                        self.conn.execute(clean_stmt)
                    except Exception as e:
                        # Ignore "does not exist" errors, raise others
                        if "does not exist" not in str(e).lower():
                            raise
            
            end_time = datetime.now()
            duration = (end_time - start_time).total_seconds()
            
            # Mark as success - will verify row counts after all loads complete
            result['status'] = 'SUCCESS'
            result['duration_seconds'] = duration
            result['table_name'] = file_path.stem.replace('etl_', '').replace('_BULK', '')
            logger.info(f"    ✓ {file_path.name} completed in {duration:.2f}s")
            
        except Exception as e:
            logger.error(f"    ✗ {file_path.name} failed: {e}")
            result['error'] = str(e)
        
        return result
    
    def run_phase(self, phase_name: str, file_list: List[str]) -> List[Dict]:
        """Execute all bulk loads in a phase."""
        logger.info(f"\n{'='*60}")
        logger.info(f"Phase: {phase_name.upper()}")
        logger.info(f"{'='*60}")
        
        results = []
        
        for bulk_file in file_list:
            file_path = self.bulks_dir / bulk_file
            
            if not file_path.exists():
                logger.warning(f"  Bulk file not found: {bulk_file} - Skipping")
                results.append({
                    'file': bulk_file,
                    'status': 'SKIPPED',
                    'error': 'File not found'
                })
                continue
            
            result = self.execute_bulk_file(file_path)
            results.append(result)
            
            # Stop if critical failure
            if result['status'] == 'FAILED' and phase_name in ['dimensions', 'measures']:
                logger.error(f"Critical failure in {phase_name} phase. Stopping execution.")
                break
        
        return results
    
    def run_all_loads(self):
        """Execute all bulk loads in proper order."""
        logger.info("Starting bulk load execution...")
        start_time = datetime.now()
        
        all_results = {}
        
        # Execute each phase in order
        for phase_name, file_list in self.load_phases.items():
            phase_results = self.run_phase(phase_name, file_list)
            all_results[phase_name] = phase_results
            
            # Check for failures
            failed = [r for r in phase_results if r['status'] == 'FAILED']
            if failed:
                logger.error(f"Phase {phase_name} had {len(failed)} failures")
                if phase_name in ['dimensions', 'measures']:
                    logger.error("Stopping execution due to critical phase failure")
                    break
        
        end_time = datetime.now()
        total_duration = (end_time - start_time).total_seconds()
        
        # Verify row counts after all loads complete
        logger.info("\n" + "="*60)
        logger.info("VERIFYING DATA LOADED")
        logger.info("="*60)
        self.verify_row_counts(all_results)
        
        # Print summary
        self.print_summary(all_results, total_duration)
        
        # Check overall success
        all_failed = []
        for phase_results in all_results.values():
            all_failed.extend([r for r in phase_results if r['status'] == 'FAILED'])
        
        return len(all_failed) == 0
    
    def verify_row_counts(self, all_results: Dict[str, List[Dict]]):
        """Verify row counts after all loads complete."""
        # Wait a moment for transactions to fully commit
        import time
        time.sleep(1)
        
        for phase_name, phase_results in all_results.items():
            for result in phase_results:
                if result['status'] == 'SUCCESS' and 'table_name' in result:
                    table_name = result['table_name']
                    try:
                        # Force a new query to get latest committed data
                        count_result = self.session.sql(f"SELECT COUNT(*) as cnt FROM {table_name}").collect()
                        if count_result:
                            rows = count_result[0]['CNT']
                            result['rows_processed'] = rows
                            if rows == 0:
                                result['status'] = 'SUCCESS_NO_DATA'
                                logger.warning(f"⚠ {table_name}: 0 rows loaded")
                            else:
                                logger.info(f"✓ {table_name}: {rows:,} rows")
                    except Exception as e:
                        logger.debug(f"Could not verify {table_name}: {e}")
    
    def print_summary(self, all_results: Dict[str, List[Dict]], total_duration: float):
        """Print execution summary."""
        logger.info("\n" + "="*60)
        logger.info("BULK LOAD EXECUTION SUMMARY")
        logger.info("="*60)
        
        total_success = 0
        total_failed = 0
        total_skipped = 0
        
        for phase_name, phase_results in all_results.items():
            logger.info(f"\nPhase: {phase_name.upper()}")
            logger.info("-" * 60)
            
            for result in phase_results:
                status = result['status']
                symbol = "✓" if status == "SUCCESS" else ("✗" if status == "FAILED" else "⊘")
                
                if status == "SUCCESS":
                    total_success += 1
                    logger.info(f"{symbol} {result['file']}: {status} ({result['duration_seconds']:.2f}s)")
                elif status == "FAILED":
                    total_failed += 1
                    logger.info(f"{symbol} {result['file']}: {status} - {result['error']}")
                else:
                    total_skipped += 1
                    logger.info(f"{symbol} {result['file']}: {status}")
        
        logger.info("\n" + "="*60)
        logger.info(f"Total Duration: {total_duration:.2f}s")
        logger.info(f"Success: {total_success}, Failed: {total_failed}, Skipped: {total_skipped}")
        logger.info("="*60)
    
    def close(self):
        """Close the Snowflake connection."""
        if self.session:
            self.session.close()
            logger.info("Connection closed")


def main():
    """Main execution function."""
    try:
        runner = BulkLoadRunner()
        runner.connect()
        success = runner.run_all_loads()
        runner.close()
        
        if success:
            logger.info("\n✓ All bulk loads executed successfully!")
            return 0
        else:
            logger.error("\n✗ Some bulk loads failed")
            return 1
            
    except Exception as e:
        logger.error(f"Error during bulk load execution: {e}", exc_info=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())

