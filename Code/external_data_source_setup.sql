-- External Data Source Setup for Synapse Serverless SQL
-- Run inside ecommerce_db

-- Create database if needed
-- CREATE DATABASE ecommerce_db;

-- Create master key if not already created
-- CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'StrongPassword@123456';

-- Optional SAS credential version. Replace token if SAS is used.
-- CREATE DATABASE SCOPED CREDENTIAL EcommerceSAS
-- WITH IDENTITY = 'SHARED ACCESS SIGNATURE',
-- SECRET = 'PASTE_SAS_TOKEN_WITHOUT_QUESTION_MARK';

-- External data source using ADLS Gen2 container
CREATE EXTERNAL DATA SOURCE EcommerceLake
WITH (
    LOCATION = 'https://shinyshastoreacc.dfs.core.windows.net/shinyblobcontainer'
    -- , CREDENTIAL = EcommerceSAS
);

-- External file format for parquet
CREATE EXTERNAL FILE FORMAT ParquetFormat
WITH (
    FORMAT_TYPE = PARQUET
);

-- View for analytics
CREATE OR ALTER VIEW dbo.vw_ecommerce_sales AS
SELECT *
FROM OPENROWSET(
    BULK 'cleaned/ecommerce_cleaned/**',
    DATA_SOURCE = 'EcommerceLake',
    FORMAT = 'PARQUET'
) AS data;
