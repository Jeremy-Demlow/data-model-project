"""
Validation script to verify pipeline setup is complete.

This script checks that all required files and directories exist
before attempting to run the pipeline.
"""

import sys
from pathlib import Path
from typing import List, Tuple

# Colors for terminal output
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
RESET = '\033[0m'


def check_file_exists(file_path: Path, description: str) -> bool:
    """Check if a file exists and print status."""
    exists = file_path.exists()
    status = f"{GREEN}✓{RESET}" if exists else f"{RED}✗{RESET}"
    print(f"  {status} {description}: {file_path}")
    return exists


def check_directory_exists(dir_path: Path, description: str) -> bool:
    """Check if a directory exists and print status."""
    exists = dir_path.exists() and dir_path.is_dir()
    status = f"{GREEN}✓{RESET}" if exists else f"{RED}✗{RESET}"
    print(f"  {status} {description}: {dir_path}")
    return exists


def validate_setup() -> Tuple[List[str], List[str]]:
    """Validate the complete pipeline setup."""
    project_root = Path(__file__).parent
    
    print("="*60)
    print("Pipeline Setup Validation")
    print("="*60)
    
    passed = []
    failed = []
    
    # Check main configuration
    print("\n1. Configuration Files:")
    files = [
        (project_root / "config.yaml", "Main configuration"),
        (project_root / "environment.yml", "Conda environment"),
        (project_root / "requirements.txt", "Python requirements"),
    ]
    for file_path, desc in files:
        if check_file_exists(file_path, desc):
            passed.append(f"{desc}")
        else:
            failed.append(f"{desc}")
    
    # Check directories
    print("\n2. Pipeline Directories:")
    dirs = [
        (project_root / "utils", "Utility modules"),
        (project_root / "01_Data_Generate", "Data generation"),
        (project_root / "02_Setup", "Database setup"),
        (project_root / "03_ETL_Run", "ETL orchestration"),
        (project_root / "04_Metrics", "Metrics tracking"),
        (project_root / "99_Cleanup", "Cleanup scripts"),
        (project_root / "Bulks", "Bulk load files"),
        (project_root / "DDL", "DDL files"),
    ]
    for dir_path, desc in dirs:
        if check_directory_exists(dir_path, desc):
            passed.append(f"{desc} directory")
        else:
            failed.append(f"{desc} directory")
    
    # Check key Python scripts
    print("\n3. Python Scripts:")
    scripts = [
        (project_root / "run_pipeline.py", "Main orchestrator"),
        (project_root / "utils" / "snowflake_connection.py", "Connection module"),
        (project_root / "01_Data_Generate" / "generate_fake_data.py", "Data generator"),
        (project_root / "02_Setup" / "run_ddls.py", "DDL runner"),
        (project_root / "03_ETL_Run" / "run_bulk_loads.py", "Bulk load runner"),
        (project_root / "04_Metrics" / "run_metrics.py", "Metrics runner"),
        (project_root / "99_Cleanup" / "run_cleanup.py", "Cleanup runner"),
    ]
    for file_path, desc in scripts:
        if check_file_exists(file_path, desc):
            passed.append(f"{desc}")
        else:
            failed.append(f"{desc}")
    
    # Check SQL scripts
    print("\n4. SQL Scripts:")
    sql_files = [
        (project_root / "02_Setup" / "create_databases.sql", "Database creation"),
        (project_root / "99_Cleanup" / "cleanup_all.sql", "Cleanup SQL"),
    ]
    for file_path, desc in sql_files:
        if check_file_exists(file_path, desc):
            passed.append(f"{desc}")
        else:
            failed.append(f"{desc}")
    
    # Check metric files
    print("\n5. Metric Configuration:")
    metric_files = [
        (project_root / "04_Metrics" / "metric_config.yaml", "Metric configuration"),
        (project_root / "04_Metrics" / "job_metrics.sql", "Job metrics view"),
        (project_root / "04_Metrics" / "sa_metrics.sql", "SA metrics view"),
        (project_root / "04_Metrics" / "invoice_metrics.sql", "Invoice metrics view"),
        (project_root / "04_Metrics" / "employee_metrics.sql", "Employee metrics view"),
    ]
    for file_path, desc in metric_files:
        if check_file_exists(file_path, desc):
            passed.append(f"{desc}")
        else:
            failed.append(f"{desc}")
    
    # Check key DDL files
    print("\n6. Key DDL Files:")
    ddl_files = [
        (project_root / "DDL" / "ETL_WATERMARK.sql", "ETL Watermark table"),
        (project_root / "DDL" / "DIM_TENANT.sql", "Tenant dimension"),
        (project_root / "DDL" / "MAT_REPORT_BASELINE.sql", "Report baseline table"),
        (project_root / "DDL" / "MAT_METRIC_SUMMARY.sql", "Metric summary table"),
        (project_root / "DDL" / "FACT_INVOICE.sql", "Invoice fact table"),
    ]
    for file_path, desc in ddl_files:
        if check_file_exists(file_path, desc):
            passed.append(f"{desc}")
        else:
            failed.append(f"{desc}")
    
    # Check key bulk load files
    print("\n7. Key Bulk Load Files:")
    bulk_files = [
        (project_root / "Bulks" / "etl_dim_tenant_BULK.sql", "Tenant dimension load"),
        (project_root / "Bulks" / "etl_dim_customer_BULK.sql", "Customer dimension load"),
        (project_root / "Bulks" / "etl_fact_invoice_BULK.sql", "Invoice fact load"),
    ]
    for file_path, desc in bulk_files:
        if check_file_exists(file_path, desc):
            passed.append(f"{desc}")
        else:
            failed.append(f"{desc}")
    
    return passed, failed


def main():
    """Main execution."""
    passed, failed = validate_setup()
    
    print("\n" + "="*60)
    print("Validation Summary")
    print("="*60)
    print(f"{GREEN}Passed:{RESET} {len(passed)}")
    print(f"{RED}Failed:{RESET} {len(failed)}")
    
    if failed:
        print(f"\n{YELLOW}Missing components:{RESET}")
        for item in failed:
            print(f"  - {item}")
        print("\nPlease ensure all files are in place before running the pipeline.")
        return 1
    else:
        print(f"\n{GREEN}✓ All components validated successfully!{RESET}")
        print("\nYou can now run the pipeline:")
        print(f"  {YELLOW}python run_pipeline.py --phase all{RESET}")
        return 0


if __name__ == "__main__":
    sys.exit(main())

