# Data Quality and Validation Report

## Purpose and execution status

This report describes the automated quality controls now implemented in the Synapse PySpark notebook. The changes are committed to GitHub, but the notebook must still be run in the configured Azure Synapse workspace to validate them against the actual source data and workspace runtime.

## Pipeline scope

`Source CSV files in ADLS Gen2 → Azure Data Factory ingestion/orchestration → Synapse PySpark cleaning and validation → cleaned Parquet in ADLS Gen2 → Synapse Serverless SQL analytics`

The notebook reads CSV fields as strings to make invalid numeric values detectable before casting. It validates the columns expected by the included analytics SQL, identifies exact duplicate rows, retains reason-coded rejected rows, transforms accepted records, writes Parquet, reads the cleaned output back, and records a run-level quality summary.

## Automated checks implemented

| Check | Current behavior | Result handling |
|---|---|---|
| Required source columns | Requires `Price`, `Quantity`, `Region`, `Category`, and `Product`. | Stops early with the missing column names if the source header does not contain them. Update the notebook configuration if your source uses different names. |
| Exact duplicate rows | Calls `dropDuplicates()` across all columns and computes the excess duplicate count. | Writes the excess copies to the run-specific `exact_duplicates` folder with `_DQ_REASONS=EXACT_DUPLICATE`. Business-key duplicates are not inferred. |
| Missing required values | Detects null/blank Price, Quantity, Region, Category, and Product values. | Rejects the row and records one or more reason codes. Optional fields are not automatically required just because they are blank. |
| Invalid numeric values | Casts Price to double and Quantity to integer after reading as strings; flags values that cannot be cast and non-finite prices. | Rejected records retain their original source values and `_DQ_REASONS`. Price values such as formatted strings with unsupported separators may need input normalization. |
| Transaction date | If `Transaction Date` exists, checks blank values and parses with Spark's default `to_date` behavior. | Missing or unparseable date records are rejected with reason codes. If the source does not contain this optional column, date-derived fields are skipped and the notebook prints a warning. Confirm your input's date format against the Synapse Spark runtime. |
| Revenue calculation | Derives `Revenue = Price × Quantity` from validated numeric inputs and detects null/non-finite results. | Invalid revenue rows are rejected. |
| Negative values | Counts negative prices and quantities among otherwise accepted records. | Emits `REVIEW` metrics but does not automatically reject them because refunds, credits, and returns can legitimately produce negatives. |
| Output readback | Reads the written cleaned Parquet data back from the same path used by the SQL scripts. | Reports output row count and checks expected analytics columns and saved revenue against `Price × Quantity`. A failed readback check raises an error after the quality report is written. |

## Output locations

The paths are configured near the top of `Code/ecommerce_data_cleaning.ipynb`. Replace the sample account/container paths with those from your environment before executing the notebook.

| Output | Purpose |
|---|---|
| `cleaned/ecommerce_cleaned` | Accepted, transformed Parquet records; this is the existing path used by the supplied SQL scripts. |
| `gold/ecommerce_sales_powerbi` | Secondary output retained from the original notebook. It uses `coalesce(1)`, which can bottleneck larger datasets; prefer partitioned output at scale. |
| `rejected/ecommerce_sales/run_id=<UTC run ID>/exact_duplicates` | Extra copies of exact full-row duplicates, with a rejection reason. Written only when duplicates are found. |
| `rejected/ecommerce_sales/run_id=<UTC run ID>/invalid_records` | Deduplicated records that fail validation, including their original source fields and `_DQ_REASONS`. Written only when rejections are found. |
| `quality/ecommerce_sales` | Latest run's CSV quality summary. This location is overwritten on each run; rejected rows are instead retained under run-specific folders. |

The CSV summary includes the run ID, check name, status, count, and details. Reason counts can overlap because one row may have multiple validation issues. For a complete rejection total, use `rows_rejected_by_quality_rules`; duplicate excess rows are reported separately as `exact_duplicate_rows`.

## Recommended execution procedure

1. Review the input path, output paths, and required column list before running.
2. Execute the notebook in Synapse with an identity that can read the input and write to the configured output folders.
3. Review the displayed quality-summary table. Investigate any `WARN`, `REVIEW`, or `FAIL` result.
4. Inspect samples in the run-specific duplicate and invalid-record folders when they exist. Confirm rejection reasons match the business rules.
5. Confirm the cleaned output count equals the reported accepted row count and that revenue consistency and output-column checks pass.
6. Run `Code/sql_analytics.sql` separately. Confirm the preview, row count, total revenue, region/category summaries, and top-product query complete and produce plausible results.
7. Retain the run ID and review the report/rejects before treating an ingestion as accepted for downstream use.

## Current limitations and production recommendations

- The required column list is explicit and fail-fast, but the notebook does not yet define a fully typed source schema for every field.
- Exact duplicates mean identical values across the entire row. A business key is needed to detect logically duplicated transactions with differing attributes.
- Spark's default date parser may not match every source format. Confirm the expected format and explicitly configure parsing where necessary.
- Rejected rows and summary counts are recorded, but long-term retention, alerting, and historical trend tracking must be configured in your Azure environment.
- Negative prices/quantities are review signals, not universal errors. Final acceptance rules should be documented with the data owner.
- The notebook still writes the optional secondary output using `coalesce(1)`. Avoid single-partition output for high-volume production data.
- Serverless SQL queries are not automatically executed by the notebook; validate them separately.
- These GitHub updates are code/documentation changes only. They do not prove that a fresh Azure run has succeeded or that the configured Azure resources are currently available.

## Related source files

- [PySpark cleaning notebook](../Code/ecommerce_data_cleaning.ipynb)
- [External data source and view setup](../Code/external_data_source_setup.sql)
- [Serverless SQL analytics](../Code/sql_analytics.sql)
- [Project README](../README.md)
