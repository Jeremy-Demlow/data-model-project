-- ============================================
-- ETL: Dim_Date - BULK LOAD
-- ============================================
-- Purpose: One-time population of date dimension
-- Source: Generated date range 2020-2030
-- ============================================

USE DATABASE ENG_STAGING;
USE SCHEMA BRANDT_REPORT_DM;

UPDATE ETL_Watermark 
SET LastRunStart = CURRENT_TIMESTAMP(), LastRunStatus = 'RUNNING'
WHERE ProcessName = 'Dim_Date';

TRUNCATE TABLE Dim_Date;

-- Generate dates from 2020 to 2030
INSERT INTO Dim_Date (
    DateKey, Date, DayOfWeek, DayName, DayOfMonth, DayOfYear,
    WeekOfYear, MonthNumber, MonthName, Year,
    IsWeekday, IsWeekend, LoadDateTime, UpdatedDateTime
)
WITH RECURSIVE date_range AS (
    SELECT DATE('2020-01-01') AS date_value
    UNION ALL
    SELECT DATEADD(day, 1, date_value)
    FROM date_range
    WHERE date_value < DATE('2030-12-31')
)
SELECT 
    TO_NUMBER(TO_CHAR(date_value, 'YYYYMMDD')) AS DateKey,
    date_value AS Date,
    DAYOFWEEK(date_value) AS DayOfWeek,
    DAYNAME(date_value) AS DayName,
    DAY(date_value) AS DayOfMonth,
    DAYOFYEAR(date_value) AS DayOfYear,
    WEEKOFYEAR(date_value) AS WeekOfYear,
    MONTH(date_value) AS MonthNumber,
    MONTHNAME(date_value) AS MonthName,
    YEAR(date_value) AS Year,
    CASE WHEN DAYOFWEEK(date_value) IN (1,2,3,4,5) THEN TRUE ELSE FALSE END AS IsWeekday,
    CASE WHEN DAYOFWEEK(date_value) IN (0,6) THEN TRUE ELSE FALSE END AS IsWeekend,
    CURRENT_TIMESTAMP() AS LoadDateTime,
    CURRENT_TIMESTAMP() AS UpdatedDateTime
FROM date_range;

UPDATE ETL_Watermark 
SET LastRunEnd = CURRENT_TIMESTAMP(), LastRunStatus = 'SUCCESS',
    LastSuccessfulRunEnd = CURRENT_TIMESTAMP(),
    RowsProcessed = (SELECT COUNT(*) FROM Dim_Date),
    UpdatedDateTime = CURRENT_TIMESTAMP()
WHERE ProcessName = 'Dim_Date';

