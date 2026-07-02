-- Synapse Serverless SQL Analytics Queries
-- Database: ecommerce_db

-- Preview cleaned parquet data
SELECT TOP 10 *
FROM OPENROWSET(
    BULK 'cleaned/ecommerce_cleaned/**',
    DATA_SOURCE = 'EcommerceLake',
    FORMAT = 'PARQUET'
) AS data;

-- Total records
SELECT COUNT(*) AS total_records
FROM OPENROWSET(
    BULK 'cleaned/ecommerce_cleaned/**',
    DATA_SOURCE = 'EcommerceLake',
    FORMAT = 'PARQUET'
) AS data;

-- Total revenue
SELECT SUM(CAST(Price AS FLOAT) * CAST(Quantity AS FLOAT)) AS total_revenue
FROM OPENROWSET(
    BULK 'cleaned/ecommerce_cleaned/**',
    DATA_SOURCE = 'EcommerceLake',
    FORMAT = 'PARQUET'
) AS data;

-- Revenue by region
SELECT Region,
       SUM(CAST(Price AS FLOAT) * CAST(Quantity AS FLOAT)) AS revenue
FROM OPENROWSET(
    BULK 'cleaned/ecommerce_cleaned/**',
    DATA_SOURCE = 'EcommerceLake',
    FORMAT = 'PARQUET'
) AS data
GROUP BY Region
ORDER BY revenue DESC;

-- Revenue by category
SELECT Category,
       SUM(CAST(Price AS FLOAT) * CAST(Quantity AS FLOAT)) AS revenue
FROM OPENROWSET(
    BULK 'cleaned/ecommerce_cleaned/**',
    DATA_SOURCE = 'EcommerceLake',
    FORMAT = 'PARQUET'
) AS data
GROUP BY Category
ORDER BY revenue DESC;

-- Top products
SELECT TOP 10 Product,
       SUM(CAST(Quantity AS FLOAT)) AS total_quantity,
       SUM(CAST(Price AS FLOAT) * CAST(Quantity AS FLOAT)) AS revenue
FROM OPENROWSET(
    BULK 'cleaned/ecommerce_cleaned/**',
    DATA_SOURCE = 'EcommerceLake',
    FORMAT = 'PARQUET'
) AS data
GROUP BY Product
ORDER BY revenue DESC;
