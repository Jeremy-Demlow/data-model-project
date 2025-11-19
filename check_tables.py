from utils.snowflake_connection import SnowflakeConnection

conn = SnowflakeConnection.from_snow_cli('demo_data')
conn.execute('USE DATABASE ENG_STAGING')
conn.execute('USE SCHEMA BRANDT_REPORT_DM')
result = conn.fetch("SHOW TABLES LIKE 'MAT%'")
print(f'MAT tables: {len(result)}')
for r in result:
    print(f'  {r[1]}')
conn.close()

