"""
Execute cleanup script to remove all pipeline resources.

This script provides a safe way to clean up all databases and objects
created by the pipeline, with user confirmation.
"""

import sys
import os
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent
sys.path.append(str(project_root))

import yaml
import logging
from snowflake.snowpark import Session

# Import connection module
from utils.snowflake_connection import SnowflakeConnection

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class CleanupRunner:
    """Execute cleanup operations with safety checks."""
    
    def __init__(self, config_path: str = None):
        """Initialize with configuration."""
        if config_path is None:
            config_path = project_root / "config.yaml"
        
        with open(config_path, 'r') as f:
            self.config = yaml.safe_load(f)
        
        self.cleanup_script = Path(__file__).parent / "cleanup_all.sql"
        self.session = None
        
    def connect(self):
        """Connect to Snowflake."""
        logger.info("Connecting to Snowflake...")
        self.conn = SnowflakeConnection.from_snow_cli(
            connection_name=self.config['snowflake']['connection_name']
        )
        self.session = self.conn.session
        logger.info("Connected successfully")
    
    def check_databases_exist(self):
        """Check which databases exist before cleanup."""
        logger.info("Checking for existing databases...")
        
        source_db = self.config['databases']['source']['name']
        analytics_db = self.config['databases']['analytics']['name']
        
        existing = []
        
        try:
            result = self.session.sql(f"SHOW DATABASES LIKE '{source_db}'").collect()
            if result:
                existing.append(source_db)
                logger.info(f"  ✓ Found: {source_db}")
        except:
            pass
        
        try:
            result = self.session.sql(f"SHOW DATABASES LIKE '{analytics_db}'").collect()
            if result:
                existing.append(analytics_db)
                logger.info(f"  ✓ Found: {analytics_db}")
        except:
            pass
        
        if not existing:
            logger.info("  No pipeline databases found")
        
        return existing
    
    def get_table_counts(self, database: str, schema: str):
        """Get table counts for a database/schema."""
        try:
            self.session.sql(f"USE DATABASE {database}").collect()
            self.session.sql(f"USE SCHEMA {schema}").collect()
            
            tables_result = self.session.sql(f"SHOW TABLES IN SCHEMA {database}.{schema}").collect()
            
            if tables_result:
                logger.info(f"  Tables in {database}.{schema}: {len(tables_result)}")
                return len(tables_result)
        except Exception as e:
            logger.debug(f"Could not get table counts for {database}.{schema}: {e}")
        
        return 0
    
    def confirm_cleanup(self, existing_dbs: list):
        """Ask user for confirmation before cleanup."""
        if not existing_dbs:
            logger.info("No databases to clean up")
            return False
        
        print("\n" + "="*60)
        print("CLEANUP CONFIRMATION")
        print("="*60)
        print("The following databases will be PERMANENTLY DELETED:")
        for db in existing_dbs:
            print(f"  - {db}")
        print("\nThis action CANNOT be undone!")
        print("="*60)
        
        response = input("\nType 'DELETE' to confirm cleanup: ").strip()
        
        return response == "DELETE"
    
    def execute_cleanup(self):
        """Execute the cleanup script."""
        logger.info("Executing cleanup script...")
        
        with open(self.cleanup_script, 'r') as f:
            sql_content = f.read()
        
        # Split by semicolons and execute each statement
        statements = [stmt.strip() for stmt in sql_content.split(';') if stmt.strip()]
        
        for stmt in statements:
            if stmt and not stmt.startswith('--'):
                try:
                    result = self.session.sql(stmt).collect()
                    # Log any status messages
                    if result and len(result) > 0:
                        for row in result:
                            if hasattr(row, 'STATUS'):
                                logger.info(f"  {row.STATUS}")
                            elif hasattr(row, 'WARNING_MESSAGE'):
                                logger.warning(f"  {row.WARNING_MESSAGE}")
                            elif hasattr(row, 'FINAL_STATUS'):
                                logger.info(f"  {row.FINAL_STATUS}")
                except Exception as e:
                    logger.debug(f"Statement execution: {e}")
        
        logger.info("Cleanup script execution complete")
    
    def verify_cleanup(self):
        """Verify that databases were removed."""
        logger.info("Verifying cleanup...")
        
        source_db = self.config['databases']['source']['name']
        analytics_db = self.config['databases']['analytics']['name']
        
        remaining = []
        
        try:
            result = self.session.sql(f"SHOW DATABASES LIKE '{source_db}'").collect()
            if result:
                remaining.append(source_db)
        except:
            pass
        
        try:
            result = self.session.sql(f"SHOW DATABASES LIKE '{analytics_db}'").collect()
            if result:
                remaining.append(analytics_db)
        except:
            pass
        
        if remaining:
            logger.warning(f"  Some databases still exist: {remaining}")
            return False
        else:
            logger.info("  ✓ All databases successfully removed")
            return True
    
    def run_cleanup(self, skip_confirmation: bool = False):
        """Execute full cleanup process."""
        logger.info("="*60)
        logger.info("PIPELINE CLEANUP")
        logger.info("="*60)
        
        # Check what exists
        existing_dbs = self.check_databases_exist()
        
        if not existing_dbs:
            logger.info("\nNo cleanup needed - databases do not exist")
            return True
        
        # Get confirmation unless skipped
        if not skip_confirmation:
            if not self.confirm_cleanup(existing_dbs):
                logger.info("\nCleanup cancelled by user")
                return False
        
        # Execute cleanup
        self.execute_cleanup()
        
        # Verify
        success = self.verify_cleanup()
        
        if success:
            logger.info("\n" + "="*60)
            logger.info("✓ CLEANUP SUCCESSFUL")
            logger.info("="*60)
            logger.info("All pipeline resources have been removed")
        else:
            logger.warning("\n" + "="*60)
            logger.warning("⚠ CLEANUP INCOMPLETE")
            logger.warning("="*60)
            logger.warning("Some resources may still exist")
        
        return success
    
    def close(self):
        """Close the Snowflake connection."""
        if self.session:
            self.session.close()
            logger.info("Connection closed")


def main():
    """Main execution function."""
    import argparse
    
    parser = argparse.ArgumentParser(description='Clean up all pipeline resources')
    parser.add_argument('--yes', action='store_true', 
                       help='Skip confirmation prompt (dangerous!)')
    args = parser.parse_args()
    
    try:
        runner = CleanupRunner()
        runner.connect()
        success = runner.run_cleanup(skip_confirmation=args.yes)
        runner.close()
        
        return 0 if success else 1
            
    except Exception as e:
        logger.error(f"Error during cleanup: {e}", exc_info=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())

