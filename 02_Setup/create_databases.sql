-- ============================================
-- Database and Schema Creation Script
-- ============================================
-- Purpose: Create all databases and schemas needed for the ETL pipeline
-- Connection: Uses blackline connection from ~/.snowflake/config.toml
-- ============================================

-- Set role and warehouse
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;

-- ============================================
-- Source Database (for fake generated data)
-- ============================================

-- Create source database if not exists
CREATE DATABASE IF NOT EXISTS TENANT_LAKE
    COMMENT = 'Source database for raw tenant data';

-- Create source schema
CREATE SCHEMA IF NOT EXISTS TENANT_LAKE.RAW_REAL
    COMMENT = 'Schema containing raw operational data';

-- ============================================
-- Analytics Database (for dimensional model)
-- ============================================

-- Create analytics database if not exists
CREATE DATABASE IF NOT EXISTS ENG_STAGING
    COMMENT = 'Engineering staging and analytics database';

-- Create analytics schema
CREATE SCHEMA IF NOT EXISTS ENG_STAGING.BRANDT_REPORT_DM
    COMMENT = 'Brandt dimensional model schema';

-- ============================================
-- Verify Creation
-- ============================================

SHOW DATABASES LIKE 'TENANT_LAKE';
SHOW DATABASES LIKE 'ENG_STAGING';

SHOW SCHEMAS IN DATABASE TENANT_LAKE;
SHOW SCHEMAS IN DATABASE ENG_STAGING;

-- ============================================
-- Grant Permissions (if needed for specific roles)
-- ============================================

-- Grant usage on databases
GRANT USAGE ON DATABASE TENANT_LAKE TO ROLE ACCOUNTADMIN;
GRANT USAGE ON DATABASE ENG_STAGING TO ROLE ACCOUNTADMIN;

-- Grant usage on schemas
GRANT USAGE ON SCHEMA TENANT_LAKE.RAW_REAL TO ROLE ACCOUNTADMIN;
GRANT USAGE ON SCHEMA ENG_STAGING.BRANDT_REPORT_DM TO ROLE ACCOUNTADMIN;

-- Grant all privileges on all tables in schemas
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA TENANT_LAKE.RAW_REAL TO ROLE ACCOUNTADMIN;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA ENG_STAGING.BRANDT_REPORT_DM TO ROLE ACCOUNTADMIN;

-- Grant future privileges
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA TENANT_LAKE.RAW_REAL TO ROLE ACCOUNTADMIN;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA ENG_STAGING.BRANDT_REPORT_DM TO ROLE ACCOUNTADMIN;

SELECT 'Database and schema setup complete!' AS STATUS;

