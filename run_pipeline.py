"""
Main Pipeline Orchestrator

This script provides a single entry point to execute the entire ETL pipeline
or individual phases as needed.
"""

import sys
import os
from pathlib import Path
import argparse
import logging
from datetime import datetime
import subprocess

# Add project root to path
project_root = Path(__file__).parent
sys.path.append(str(project_root))

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class PipelineOrchestrator:
    """Orchestrate the execution of all pipeline phases."""
    
    def __init__(self):
        """Initialize the orchestrator."""
        self.project_root = project_root
        self.start_time = None
        self.phase_results = {}
        
    def run_python_script(self, script_path: Path, description: str) -> bool:
        """Run a Python script and return success status."""
        logger.info(f"\n{'='*60}")
        logger.info(f"Running: {description}")
        logger.info(f"Script: {script_path}")
        logger.info(f"{'='*60}\n")
        
        try:
            result = subprocess.run(
                [sys.executable, str(script_path)],
                cwd=self.project_root,
                capture_output=False,
                check=True
            )
            return result.returncode == 0
        except subprocess.CalledProcessError as e:
            logger.error(f"Script failed with exit code {e.returncode}")
            return False
        except Exception as e:
            logger.error(f"Error running script: {e}")
            return False
    
    def run_sql_script(self, script_path: Path, description: str) -> bool:
        """Run a SQL script using snowsql or Snowflake CLI."""
        logger.info(f"\n{'='*60}")
        logger.info(f"Running: {description}")
        logger.info(f"Script: {script_path}")
        logger.info(f"{'='*60}\n")
        
        try:
            # Use Snowflake CLI
            result = subprocess.run(
                ['snow', 'sql', '-f', str(script_path), '-c', 'demo_data'],
                cwd=self.project_root,
                capture_output=False,
                check=True
            )
            return result.returncode == 0
        except subprocess.CalledProcessError as e:
            logger.error(f"Script failed with exit code {e.returncode}")
            return False
        except FileNotFoundError:
            logger.error("Snowflake CLI (snow) not found. Please install snowflake-cli-labs")
            return False
        except Exception as e:
            logger.error(f"Error running SQL script: {e}")
            return False
    
    def phase_setup(self) -> bool:
        """Phase 1: Setup - Create databases and schemas."""
        logger.info("\n" + "█"*60)
        logger.info("PHASE 1: SETUP")
        logger.info("█"*60)
        
        script = self.project_root / "02_Setup" / "create_databases.sql"
        success = self.run_sql_script(script, "Database and Schema Creation")
        
        # Create external database
        logger.info("Creating external database...")
        ext_script = self.project_root / "02_Setup" / "create_external_db.sql"
        if ext_script.exists():
            ext_result = self.run_sql_script(ext_script, "External Database Creation")
            if not ext_result:
                logger.warning("External DB creation failed, continuing anyway...")
        
        self.phase_results['setup'] = success
        return success
    
    def phase_ddl(self) -> bool:
        """Phase 2: DDL - Create all tables."""
        logger.info("\n" + "█"*60)
        logger.info("PHASE 2: DDL CREATION")
        logger.info("█"*60)
        
        script = self.project_root / "02_Setup" / "run_ddls.py"
        success = self.run_python_script(script, "DDL Table Creation")
        
        self.phase_results['ddl'] = success
        return success
    
    def phase_generate(self) -> bool:
        """Phase 3: Generate - Create fake data."""
        logger.info("\n" + "█"*60)
        logger.info("PHASE 3: DATA GENERATION")
        logger.info("█"*60)
        
        # Pre-create source schemas for timestamp tables
        logger.info("Pre-creating source table schemas with TIMESTAMP columns...")
        script = self.project_root / "01_Data_Generate" / "create_source_schemas.sql"
        if script.exists():
            result = self.run_sql_script(script, "Source Table Schema Creation")
            if not result:
                logger.warning("Source schema creation failed, continuing anyway...")
        
        script = self.project_root / "01_Data_Generate" / "generate_fake_data.py"
        success = self.run_python_script(script, "Fake Data Generation")
        
        # Populate external database
        logger.info("Populating external database...")
        ext_script = self.project_root / "01_Data_Generate" / "populate_external_db.py"
        if ext_script.exists():
            ext_result = self.run_python_script(ext_script, "External DB Population")
            if not ext_result:
                logger.warning("External DB population failed, continuing anyway...")
        
        self.phase_results['generate'] = success
        return success
    
    def phase_etl(self) -> bool:
        """Phase 4: ETL - Run bulk loads."""
        logger.info("\n" + "█"*60)
        logger.info("PHASE 4: ETL EXECUTION")
        logger.info("█"*60)
        
        script = self.project_root / "03_ETL_Run" / "run_bulk_loads.py"
        success = self.run_python_script(script, "Bulk Load Execution")
        
        self.phase_results['etl'] = success
        return success
    
    def phase_metrics(self) -> bool:
        """Phase 5: Metrics - Calculate and track metrics."""
        logger.info("\n" + "█"*60)
        logger.info("PHASE 5: METRICS TRACKING")
        logger.info("█"*60)
        
        script = self.project_root / "04_Metrics" / "run_metrics.py"
        success = self.run_python_script(script, "Metrics Calculation")
        
        self.phase_results['metrics'] = success
        return success
    
    def phase_cleanup(self) -> bool:
        """Phase 6: Cleanup - Remove all resources."""
        logger.info("\n" + "█"*60)
        logger.info("PHASE 6: CLEANUP")
        logger.info("█"*60)
        
        script = self.project_root / "99_Cleanup" / "run_cleanup.py"
        success = self.run_python_script(script, "Resource Cleanup")
        
        self.phase_results['cleanup'] = success
        return success
    
    def run_all(self) -> bool:
        """Run all phases in sequence."""
        self.start_time = datetime.now()
        
        logger.info("\n" + "█"*60)
        logger.info("PIPELINE EXECUTION - ALL PHASES")
        logger.info("█"*60)
        logger.info(f"Start Time: {self.start_time.strftime('%Y-%m-%d %H:%M:%S')}")
        logger.info("█"*60)
        
        phases = [
            ('setup', self.phase_setup),
            ('ddl', self.phase_ddl),
            ('generate', self.phase_generate),
            ('etl', self.phase_etl),
            ('metrics', self.phase_metrics),
        ]
        
        for phase_name, phase_func in phases:
            success = phase_func()
            if not success:
                logger.error(f"\n✗ Phase '{phase_name}' failed. Stopping pipeline.")
                self.print_summary()
                return False
        
        self.print_summary()
        return all(self.phase_results.values())
    
    def run_customer(self) -> bool:
        """Run customer/production pipeline (skips setup and data generation)."""
        self.start_time = datetime.now()
        
        logger.info("\n" + "█"*60)
        logger.info("PIPELINE EXECUTION - CUSTOMER MODE")
        logger.info("█"*60)
        logger.info("Skipping: setup (database creation) and generate (fake data)")
        logger.info("Running: DDL, ETL, Metrics")
        logger.info(f"Start Time: {self.start_time.strftime('%Y-%m-%d %H:%M:%S')}")
        logger.info("█"*60)
        
        phases = [
            ('ddl', self.phase_ddl),
            ('etl', self.phase_etl),
            ('metrics', self.phase_metrics),
        ]
        
        for phase_name, phase_func in phases:
            success = phase_func()
            if not success:
                logger.error(f"\n✗ Phase '{phase_name}' failed. Stopping pipeline.")
                self.print_summary()
                return False
        
        self.print_summary()
        return all(self.phase_results.values())
    
    def run_phase(self, phase: str) -> bool:
        """Run a specific phase."""
        self.start_time = datetime.now()
        
        phase_map = {
            'setup': self.phase_setup,
            'ddl': self.phase_ddl,
            'generate': self.phase_generate,
            'etl': self.phase_etl,
            'metrics': self.phase_metrics,
            'cleanup': self.phase_cleanup,
        }
        
        if phase not in phase_map:
            logger.error(f"Unknown phase: {phase}")
            logger.info(f"Available phases: {', '.join(phase_map.keys())}")
            return False
        
        success = phase_map[phase]()
        self.print_summary()
        return success
    
    def print_summary(self):
        """Print execution summary."""
        end_time = datetime.now()
        duration = (end_time - self.start_time).total_seconds() if self.start_time else 0
        
        logger.info("\n" + "█"*60)
        logger.info("PIPELINE EXECUTION SUMMARY")
        logger.info("█"*60)
        
        if self.start_time:
            logger.info(f"Start Time:    {self.start_time.strftime('%Y-%m-%d %H:%M:%S')}")
            logger.info(f"End Time:      {end_time.strftime('%Y-%m-%d %H:%M:%S')}")
            logger.info(f"Duration:      {duration:.2f} seconds ({duration/60:.2f} minutes)")
        
        logger.info("\nPhase Results:")
        logger.info("-" * 60)
        
        for phase_name, success in self.phase_results.items():
            status = "✓ SUCCESS" if success else "✗ FAILED"
            logger.info(f"  {phase_name.upper():<15} {status}")
        
        logger.info("█"*60)
        
        all_success = all(self.phase_results.values())
        if all_success:
            logger.info("✓ PIPELINE COMPLETED SUCCESSFULLY")
        else:
            logger.info("✗ PIPELINE COMPLETED WITH ERRORS")
        logger.info("█"*60)


def main():
    """Main execution function."""
    parser = argparse.ArgumentParser(
        description='ETL Pipeline Orchestrator',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Run entire pipeline (with fake data generation)
  python run_pipeline.py --phase all
  
  # Run customer/production mode (skip setup and fake data generation)
  python run_pipeline.py --phase customer
  
  # Run specific phase
  python run_pipeline.py --phase generate
  python run_pipeline.py --phase etl
  python run_pipeline.py --phase metrics
  
  # Cleanup resources
  python run_pipeline.py --phase cleanup
        """
    )
    
    parser.add_argument(
        '--phase',
        choices=['all', 'customer', 'setup', 'ddl', 'generate', 'etl', 'metrics', 'cleanup'],
        default='all',
        help='Pipeline phase to execute (default: all). Use "customer" for production mode (skips setup/generate)'
    )
    
    args = parser.parse_args()
    
    try:
        orchestrator = PipelineOrchestrator()
        
        if args.phase == 'all':
            success = orchestrator.run_all()
        elif args.phase == 'customer':
            success = orchestrator.run_customer()
        else:
            success = orchestrator.run_phase(args.phase)
        
        return 0 if success else 1
        
    except KeyboardInterrupt:
        logger.info("\n\nPipeline execution interrupted by user")
        return 130
    except Exception as e:
        logger.error(f"Pipeline execution failed: {e}", exc_info=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())

