-- ============================================
-- Complete Cleanup Script
-- ============================================
-- Purpose: Drop all databases and resources created by this pipeline
-- WARNING: This will delete ALL data and objects created
-- ============================================

-- Set role
USE ROLE ACCOUNTADMIN;

-- ============================================
-- Confirmation Message
-- ============================================
SELECT 'WARNING: This script will delete all databases and data created by the pipeline!' AS WARNING_MESSAGE;
SELECT 'Databases to be dropped: TENANT_LAKE, ENG_STAGING' AS DATABASES;

-- ============================================
-- Drop Analytics Database
-- ============================================
DROP DATABASE IF EXISTS ENG_STAGING CASCADE;
SELECT 'Dropped ENG_STAGING database' AS STATUS;

-- ============================================
-- Drop Source Database
-- ============================================
DROP DATABASE IF EXISTS TENANT_LAKE CASCADE;
SELECT 'Dropped TENANT_LAKE database' AS STATUS;

-- ============================================
-- Verify Cleanup
-- ============================================
SHOW DATABASES LIKE 'TENANT_LAKE';
SHOW DATABASES LIKE 'ENG_STAGING';

SELECT 'Cleanup complete! All pipeline databases have been removed.' AS FINAL_STATUS;

