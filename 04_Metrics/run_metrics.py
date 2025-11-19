"""
Execute metric queries and track results across ETL runs.

This script runs metric queries, compares results to previous runs,
and stores baseline data for future comparisons.
"""

import sys
import os
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent
sys.path.append(str(project_root))

import yaml
import logging
from typing import Dict, List
from datetime import datetime, date
import pandas as pd
from snowflake.snowpark import Session

# Import connection module
from utils.snowflake_connection import SnowflakeConnection

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class MetricsRunner:
    """Execute and track metrics across ETL runs."""
    
    def __init__(self, config_path: str = None, metric_config_path: str = None):
        """Initialize with configuration."""
        if config_path is None:
            config_path = project_root / "config.yaml"
        if metric_config_path is None:
            metric_config_path = Path(__file__).parent / "metric_config.yaml"
        
        with open(config_path, 'r') as f:
            self.config = yaml.safe_load(f)
        
        with open(metric_config_path, 'r') as f:
            self.metric_config = yaml.safe_load(f)
        
        self.metrics_dir = Path(__file__).parent
        self.session = None
        self.db = self.config['databases']['analytics']['name']
        self.schema = self.config['databases']['analytics']['schema']
        
    def connect(self):
        """Connect to Snowflake."""
        logger.info("Connecting to Snowflake...")
        self.conn = SnowflakeConnection.from_snow_cli(
            connection_name=self.config['snowflake']['connection_name']
        )
        self.session = self.conn.session
        self.session.sql(f"USE DATABASE {self.db}").collect()
        self.session.sql(f"USE SCHEMA {self.schema}").collect()
        logger.info("Connected successfully")
    
    def create_metric_views(self):
        """Create temporary views for metric queries."""
        logger.info("Creating metric views...")
        
        view_files = [
            'job_metrics.sql',
            'sa_metrics.sql',
            'invoice_metrics.sql',
            'employee_metrics.sql'
        ]
        
        for view_file in view_files:
            view_path = self.metrics_dir / view_file
            if view_path.exists():
                logger.info(f"  Creating view from {view_file}...")
                with open(view_path, 'r') as f:
                    sql = f.read()
                self.session.sql(sql).collect()
            else:
                logger.warning(f"  View file not found: {view_file}")
    
    def get_previous_metrics(self, metric_name: str) -> Dict:
        """Get the most recent metric value for comparison."""
        try:
            query = f"""
                SELECT RUN_VERSION, METRIC_VALUE, METRIC_COUNT
                FROM MAT_METRIC_SUMMARY
                WHERE METRIC_NAME = '{metric_name}'
                ORDER BY RUN_DATE DESC, LOADDATETIME DESC
                LIMIT 1
            """
            result = self.session.sql(query).collect()
            
            if result:
                return {
                    'version': result[0]['RUN_VERSION'],
                    'value': float(result[0]['METRIC_VALUE']) if result[0]['METRIC_VALUE'] else 0,
                    'count': int(result[0]['METRIC_COUNT']) if result[0]['METRIC_COUNT'] else 0
                }
        except Exception as e:
            logger.debug(f"No previous metrics found for {metric_name}: {e}")
        
        return None
    
    def execute_metric(self, metric_def: Dict) -> Dict:
        """Execute a single metric query."""
        metric_name = metric_def['name']
        logger.info(f"  Executing metric: {metric_name}...")
        
        try:
            # Execute the metric query
            result = self.session.sql(metric_def['query']).collect()
            
            if result and len(result) > 0:
                metric_value = float(result[0]['METRIC_VALUE']) if result[0]['METRIC_VALUE'] else 0
                metric_count = int(result[0]['METRIC_COUNT']) if result[0]['METRIC_COUNT'] else 0
            else:
                metric_value = 0
                metric_count = 0
            
            # Get previous value for comparison
            previous = self.get_previous_metrics(metric_name)
            
            result_dict = {
                'name': metric_name,
                'category': metric_def.get('category', 'general'),
                'value': metric_value,
                'count': metric_count,
                'previous_version': previous['version'] if previous else None,
                'previous_value': previous['value'] if previous else None,
                'difference': metric_value - previous['value'] if previous else None,
                'difference_pct': ((metric_value - previous['value']) / previous['value'] * 100) 
                                  if previous and previous['value'] != 0 else None
            }
            
            logger.info(f"    Value: {metric_value:,.2f}, Count: {metric_count:,}")
            if previous:
                diff = result_dict['difference']
                diff_pct = result_dict['difference_pct']
                logger.info(f"    vs Previous: {diff:+,.2f} ({diff_pct:+.2f}%)")
            
            return result_dict
            
        except Exception as e:
            logger.error(f"    Error executing metric {metric_name}: {e}")
            return {
                'name': metric_name,
                'category': metric_def.get('category', 'general'),
                'value': None,
                'count': None,
                'error': str(e)
            }
    
    def store_metric_summary(self, metric_results: List[Dict]):
        """Store metric results in summary table."""
        logger.info("Storing metric results...")
        
        version = self.metric_config['version']
        run_date = self.metric_config['run_date']
        description = self.metric_config['description']
        
        for result in metric_results:
            if 'error' in result:
                continue
            
            insert_sql = f"""
                INSERT INTO MAT_METRIC_SUMMARY (
                    RUN_VERSION, RUN_DATE, RUN_DESCRIPTION,
                    METRIC_NAME, METRIC_CATEGORY,
                    METRIC_VALUE, METRIC_COUNT,
                    PREVIOUS_RUN_VERSION, PREVIOUS_METRIC_VALUE,
                    VALUE_DIFFERENCE, VALUE_DIFFERENCE_PCT
                )
                VALUES (
                    '{version}', '{run_date}', '{description}',
                    '{result['name']}', '{result['category']}',
                    {result['value']}, {result['count']},
                    {f"'{result['previous_version']}'" if result['previous_version'] else 'NULL'},
                    {result['previous_value'] if result['previous_value'] is not None else 'NULL'},
                    {result['difference'] if result['difference'] is not None else 'NULL'},
                    {result['difference_pct'] if result['difference_pct'] is not None else 'NULL'}
                )
            """
            
            self.session.sql(insert_sql).collect()
        
        logger.info(f"  Stored {len(metric_results)} metric results")
    
    def store_baseline(self):
        """Store full report output as baseline."""
        logger.info("Storing baseline report output...")
        
        version = self.metric_config['version']
        run_date = self.metric_config['run_date']
        description = self.metric_config['description']
        params = self.metric_config['parameters']
        
        # Read and execute the full report query
        report_query_path = project_root / "report" / "QUERY_ReplicateOriginalOutput.sql"
        
        if not report_query_path.exists():
            logger.warning("Report query file not found, skipping baseline storage")
            return
        
        with open(report_query_path, 'r') as f:
            report_sql = f.read()
        
        # Replace parameters in the query
        report_sql = report_sql.replace(':From', f"'{params['from_date']}'")
        report_sql = report_sql.replace(':To', f"'{params['to_date']}'")
        report_sql = report_sql.replace(':TenantIds', f"({params['tenant_ids'][0]})")
        report_sql = report_sql.replace(':EmployeeIdSpecified', str(params['employee_id_specified']))
        report_sql = report_sql.replace(':EmployeeIds', '()' if not params['employee_ids'] else str(tuple(params['employee_ids'])))
        report_sql = report_sql.replace(':FilterStatusSpecified', str(params['filter_status_specified']))
        report_sql = report_sql.replace(':FilterStatus', '()' if not params['filter_status'] else str(tuple(params['filter_status'])))
        
        try:
            # Create a temp table with the report results
            logger.info("  Executing report query...")
            self.session.sql("CREATE OR REPLACE TEMPORARY TABLE temp_report_output AS " + report_sql).collect()
            
            # Insert into baseline with metadata
            insert_baseline = f"""
                INSERT INTO MAT_REPORT_BASELINE
                SELECT 
                    '{version}' AS RUN_VERSION,
                    '{run_date}' AS RUN_DATE,
                    '{description}' AS RUN_DESCRIPTION,
                    *
                FROM temp_report_output
            """
            
            self.session.sql(insert_baseline).collect()
            
            # Get count
            count_result = self.session.sql("SELECT COUNT(*) as cnt FROM temp_report_output").collect()
            row_count = count_result[0]['CNT'] if count_result else 0
            
            logger.info(f"  Stored {row_count} baseline records")
            
        except Exception as e:
            logger.error(f"  Error storing baseline: {e}")
    
    def run_all_metrics(self):
        """Execute all metrics and store results."""
        logger.info("="*60)
        logger.info("METRICS EXECUTION")
        logger.info("="*60)
        logger.info(f"Version: {self.metric_config['version']}")
        logger.info(f"Run Date: {self.metric_config['run_date']}")
        logger.info(f"Description: {self.metric_config['description']}")
        logger.info("="*60)
        
        # Create metric views
        self.create_metric_views()
        
        # Execute each metric
        results = []
        for metric_def in self.metric_config['metrics']:
            result = self.execute_metric(metric_def)
            results.append(result)
        
        # Store results
        self.store_metric_summary(results)
        
        # Store baseline
        self.store_baseline()
        
        # Print summary
        self.print_summary(results)
        
        return results
    
    def print_summary(self, results: List[Dict]):
        """Print execution summary."""
        logger.info("\n" + "="*60)
        logger.info("METRICS SUMMARY")
        logger.info("="*60)
        
        by_category = {}
        for result in results:
            category = result.get('category', 'general')
            if category not in by_category:
                by_category[category] = []
            by_category[category].append(result)
        
        for category, metrics in by_category.items():
            logger.info(f"\n{category.upper()}:")
            logger.info("-" * 60)
            for metric in metrics:
                if 'error' in metric:
                    logger.info(f"  ✗ {metric['name']}: ERROR - {metric['error']}")
                else:
                    value_str = f"{metric['value']:,.2f}"
                    if metric['difference'] is not None:
                        diff_str = f" ({metric['difference']:+,.2f}, {metric['difference_pct']:+.2f}%)"
                    else:
                        diff_str = " (baseline)"
                    logger.info(f"  ✓ {metric['name']}: {value_str}{diff_str}")
        
        logger.info("="*60)
    
    def close(self):
        """Close the Snowflake connection."""
        if self.session:
            self.session.close()
            logger.info("Connection closed")


def main():
    """Main execution function."""
    try:
        runner = MetricsRunner()
        runner.connect()
        results = runner.run_all_metrics()
        runner.close()
        
        # Check for errors
        errors = [r for r in results if 'error' in r]
        if errors:
            logger.error(f"\n✗ {len(errors)} metrics failed")
            return 1
        else:
            logger.info("\n✓ All metrics executed successfully!")
            return 0
            
    except Exception as e:
        logger.error(f"Error during metrics execution: {e}", exc_info=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())

