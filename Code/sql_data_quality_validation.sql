-- Synapse Serverless SQL post-write data-quality checks
-- Run in ecommerce_db AFTER the PySpark notebook writes cleaned/ecommerce_cleaned.
-- Ensure the EcommerceLake external data source has been configured.
-- These checks validate the persisted output; they do not execute the PySpark notebook.

WITH source_data AS (
    SELECT
        *,
        TRY_CAST(Price AS FLOAT) AS dq_price,
        TRY_CAST(Quantity AS FLOAT) AS dq_quantity,
        TRY_CAST(Revenue AS FLOAT) AS dq_revenue
    FROM OPENROWSET(
        BULK 'cleaned/ecommerce_cleaned/**',
        DATA_SOURCE = 'EcommerceLake',
        FORMAT = 'PARQUET'
    ) AS data
),
checks AS (
    SELECT
        'output_row_count' AS check_name,
        COUNT_BIG(*) AS observed_count,
        CAST(0 AS BIGINT) AS failure_threshold,
        'INFO' AS severity,
        'Total records read from cleaned Parquet output.' AS details
    FROM source_data

    UNION ALL

    SELECT
        'missing_region',
        SUM(CAST(CASE WHEN Region IS NULL OR LTRIM(RTRIM(CAST(Region AS VARCHAR(4000)))) = '' THEN 1 ELSE 0 END AS BIGINT)),
        CAST(0 AS BIGINT),
        'FAIL',
        'Required Region values should not be null or blank.'
    FROM source_data

    UNION ALL

    SELECT
        'missing_category',
        SUM(CAST(CASE WHEN Category IS NULL OR LTRIM(RTRIM(CAST(Category AS VARCHAR(4000)))) = '' THEN 1 ELSE 0 END AS BIGINT)),
        CAST(0 AS BIGINT),
        'FAIL',
        'Required Category values should not be null or blank.'
    FROM source_data

    UNION ALL

    SELECT
        'missing_product',
        SUM(CAST(CASE WHEN Product IS NULL OR LTRIM(RTRIM(CAST(Product AS VARCHAR(4000)))) = '' THEN 1 ELSE 0 END AS BIGINT)),
        CAST(0 AS BIGINT),
        'FAIL',
        'Required Product values should not be null or blank.'
    FROM source_data

    UNION ALL

    SELECT
        'invalid_price_or_quantity',
        SUM(CAST(CASE WHEN dq_price IS NULL OR dq_quantity IS NULL THEN 1 ELSE 0 END AS BIGINT)),
        CAST(0 AS BIGINT),
        'FAIL',
        'Price and Quantity must be readable as numeric values.'
    FROM source_data

    UNION ALL

    SELECT
        'missing_or_invalid_revenue',
        SUM(CAST(CASE WHEN dq_revenue IS NULL THEN 1 ELSE 0 END AS BIGINT)),
        CAST(0 AS BIGINT),
        'FAIL',
        'Revenue must be present and numeric.'
    FROM source_data

    UNION ALL

    SELECT
        'revenue_calculation_mismatch',
        SUM(CAST(
            CASE
                WHEN dq_price IS NOT NULL
                 AND dq_quantity IS NOT NULL
                 AND dq_revenue IS NOT NULL
                 AND ABS(dq_revenue - (dq_price * dq_quantity)) > 0.000001
                THEN 1 ELSE 0
            END AS BIGINT
        )),
        CAST(0 AS BIGINT),
        'FAIL',
        'Saved Revenue should equal Price multiplied by Quantity within tolerance 0.000001.'
    FROM source_data

    UNION ALL

    SELECT
        'negative_price_review',
        SUM(CAST(CASE WHEN dq_price < 0 THEN 1 ELSE 0 END AS BIGINT)),
        CAST(0 AS BIGINT),
        'REVIEW',
        'Negative prices are flagged for business review; they are not automatically invalid.'
    FROM source_data

    UNION ALL

    SELECT
        'negative_quantity_review',
        SUM(CAST(CASE WHEN dq_quantity < 0 THEN 1 ELSE 0 END AS BIGINT)),
        CAST(0 AS BIGINT),
        'REVIEW',
        'Negative quantities are flagged for business review; they may represent returns.'
    FROM source_data
)
SELECT
    check_name,
    COALESCE(observed_count, 0) AS observed_count,
    severity,
    CASE
        WHEN severity = 'INFO' THEN 'INFO'
        WHEN severity = 'REVIEW' AND COALESCE(observed_count, 0) > failure_threshold THEN 'REVIEW'
        WHEN severity = 'REVIEW' THEN 'PASS'
        WHEN COALESCE(observed_count, 0) > failure_threshold THEN 'FAIL'
        ELSE 'PASS'
    END AS status,
    details
FROM checks
ORDER BY
    CASE severity WHEN 'FAIL' THEN 1 WHEN 'REVIEW' THEN 2 ELSE 3 END,
    check_name;

-- Optional aggregate reconciliation for quick comparison with the PySpark report.
SELECT
    COUNT_BIG(*) AS sql_output_row_count,
    SUM(TRY_CAST(Price AS FLOAT) * TRY_CAST(Quantity AS FLOAT)) AS sql_recalculated_revenue,
    SUM(TRY_CAST(Revenue AS FLOAT)) AS sql_stored_revenue,
    SUM(TRY_CAST(Revenue AS FLOAT))
        - SUM(TRY_CAST(Price AS FLOAT) * TRY_CAST(Quantity AS FLOAT)) AS revenue_difference
FROM OPENROWSET(
    BULK 'cleaned/ecommerce_cleaned/**',
    DATA_SOURCE = 'EcommerceLake',
    FORMAT = 'PARQUET'
) AS data;
