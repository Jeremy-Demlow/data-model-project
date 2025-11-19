# Snowflake ETL Pipeline with Versioned Metrics

A complete, iterative ETL pipeline that generates fake data, loads it through dimensional models, tracks metrics across runs, and provides full cleanup capabilities.

## Overview

This pipeline implements a dimensional data model with:
- Fake data generation using Faker
- DDL creation for dimensions, facts, and materialized tables
- Bulk load orchestration with dependency management
- Metric tracking and versioning across ETL runs
- Complete cleanup for demo environments

## Prerequisites

- Python 3.11+
- Snowflake account with ACCOUNTADMIN privileges
- Snowflake CLI configured (`~/.snowflake/config.toml`)
- Conda (optional, for environment management)

## Setup

### 1. Install Dependencies

Using pip:
```bash
pip install -r requirements.txt
```

Using conda:
```bash
conda env create -f environment.yml
conda activate data-model-pipeline
```

### 2. Configure Snowflake Connection

Ensure your `~/.snowflake/config.toml` has a connection configured. By default, the pipeline uses the `blackline` connection. Update `config.yaml` if you need a different connection:

```yaml
snowflake:
  connection_name: "your_connection_name"
```

### 3. Review Configuration

Edit `config.yaml` to adjust:
- Database and schema names
- Row counts for fake data generation
- Date ranges
- Metric definitions

## Usage

### Run Complete Pipeline

Execute all phases in sequence:
```bash
python run_pipeline.py --phase all
```

This runs:
1. **Setup** - Create databases and schemas
2. **DDL** - Create all tables
3. **Generate** - Create fake source data
4. **ETL** - Run bulk loads
5. **Metrics** - Calculate and track metrics

### Run Individual Phases

Setup databases:
```bash
python run_pipeline.py --phase setup
```

Create DDL tables:
```bash
python run_pipeline.py --phase ddl
```

Generate fake data:
```bash
python run_pipeline.py --phase generate
```

Run ETL bulk loads:
```bash
python run_pipeline.py --phase etl
```

Calculate metrics:
```bash
python run_pipeline.py --phase metrics
```

### Cleanup

Remove all created databases and resources:
```bash
python run_pipeline.py --phase cleanup
```

Or run directly with automatic confirmation:
```bash
python 99_Cleanup/run_cleanup.py --yes
```

## Directory Structure

```
.
├── utils/                   # Utility modules
│   └── snowflake_connection.py
├── 01_Data_Generate/        # Fake data generation
│   └── generate_fake_data.py
├── 02_Setup/                # Database and DDL setup
│   ├── create_databases.sql
│   └── run_ddls.py
├── 03_ETL_Run/              # Bulk load orchestration
│   └── run_bulk_loads.py
├── 04_Metrics/              # Metric tracking
│   ├── metric_config.yaml
│   ├── run_metrics.py
│   ├── job_metrics.sql
│   ├── sa_metrics.sql
│   ├── invoice_metrics.sql
│   └── employee_metrics.sql
├── 99_Cleanup/              # Cleanup scripts
│   ├── cleanup_all.sql
│   └── run_cleanup.py
├── Bulks/                   # ETL bulk load SQL files
├── DDL/                     # Table creation DDL files
├── report/                  # Report queries
├── config.yaml              # Main configuration
├── environment.yml          # Conda environment
├── requirements.txt         # Python dependencies
└── run_pipeline.py          # Main orchestrator
```

## Iterative Workflow

The pipeline is designed for iterative development:

1. **Initial Run**: Generate baseline metrics
```bash
python run_pipeline.py --phase all
```

2. **Make Changes**: Modify DDL or ETL logic
```bash
# Edit files in DDL/ or Bulks/
```

3. **Update Version**: Edit `04_Metrics/metric_config.yaml`
```yaml
version: "1.0.1"
description: "After fixing margin calculation"
```

4. **Re-run Pipeline**: (skipping data generation)
```bash
python run_pipeline.py --phase ddl
python run_pipeline.py --phase etl
python run_pipeline.py --phase metrics
```

5. **Compare Results**: Metrics automatically compare to previous runs

6. **Cleanup When Done**:
```bash
python run_pipeline.py --phase cleanup
```

## Metric Tracking

Metrics are tracked in `MAT_METRIC_SUMMARY` table with:
- Version numbers
- Current vs. previous values
- Differences and percentages
- Run dates and descriptions

Baseline reports stored in `MAT_REPORT_BASELINE` for full output comparison.

## Configuration

### Data Generation (`config.yaml`)

```yaml
data_generation:
  row_counts:
    customer: 500
    employee: 50
    job: 5000
    invoice: 8000
    # ... more counts
  
  date_ranges:
    start_date: "2023-01-01"
    end_date: "2024-12-31"
```

### Metrics (`04_Metrics/metric_config.yaml`)

```yaml
version: "1.0.0"
run_date: "2024-11-18"
description: "Initial baseline"

metrics:
  - name: job_revenue_total
    category: "job"
    query: |
      SELECT SUM(JobRevenue) as metric_value,
             COUNT(*) as metric_count
      FROM job_metrics
```

## Databases Created

- **TENANT_LAKE.RAW_REAL**: Source data (fake generated)
- **ENG_STAGING.BRANDT_REPORT_DM**: Analytics dimensional model

## Key Tables

### Dimensions
- Dim_BusinessUnit, Dim_Customer, Dim_Employee, Dim_Location
- Dim_Job, Dim_JobType, Dim_SKU, Dim_ServiceAgreement
- Dim_Tenant, Dim_Date, Dim_GLAccount

### Facts
- Fact_Invoice, Fact_InvoiceItem, Fact_ServiceAgreement

### Materialized Tables
- Mat_Employee_CommissionRates
- Mat_Invoice_Revenue, Mat_Invoice_MaterialCosts, Mat_Invoice_LaborCosts, Mat_Invoice_POCosts
- Mat_Job_Returns
- Mat_SA_Period_Measures
- Mat_Report_Baseline (for comparisons)
- Mat_Metric_Summary (for tracking)

## Troubleshooting

### Connection Issues
- Verify `~/.snowflake/config.toml` exists and has valid credentials
- Check connection name in `config.yaml` matches your config
- Ensure Snowflake CLI is installed: `pip install snowflake-cli-labs`

### Data Generation Issues
- Check row counts in `config.yaml` - large values may take time
- Verify source database exists before running
- Ensure sufficient Snowflake warehouse size

### ETL Issues
- Check DDL files exist in `DDL/` directory
- Verify bulk load files exist in `Bulks/` directory
- Review ETL_Watermark table for process status

### Metric Issues
- Ensure ETL has completed successfully
- Check that report query runs without errors
- Verify metric views are created properly

## Support

For issues or questions:
1. Check logs for detailed error messages
2. Review configuration files
3. Verify Snowflake connection and permissions

## License

See LEGAL.md for license information.

