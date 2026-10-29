# Data Quality and Validation Report

## Purpose

This report documents the data-quality behavior present in the repository's Synapse PySpark notebook and SQL scripts, distinguishes implemented behavior from recommended controls, and provides a repeatable validation checklist. It is documentation of the checked-in code; it is **not evidence that a fresh Azure run has been executed**.

## Pipeline scope

The current workflow is:

`Source CSV files in ADLS Gen2 → Azure Data Factory ingestion/orchestration → Synapse PySpark cleaning → Parquet in ADLS Gen2 → Synapse Serverless SQL analytics`

The notebook reads CSV files with headers and schema inference, transforms the resulting Spark DataFrame, writes the cleaned Parquet output in overwrite mode, and also writes a second Power BI-oriented output path. The SQL scripts query the cleaned Parquet data for counts and revenue summaries.

## Current behavior versus validation gaps

| Area | Implemented in the notebook | Gap / recommended control |
|---|---|---|
| Schema on read | CSV header is enabled and Spark schema inference is enabled. | Inferred types can vary with source data. For repeatable production runs, define and validate an explicit schema and required columns. |
| Initial inspection | Prints the initial row count and column names; displays up to 10 rows. | Record metrics in a durable run log and compare counts with the previous stage. |
| Duplicate handling | Calls `dropDuplicates()` across all columns. | This removes identical full rows, not necessarily duplicate business transactions. Define a business key and decide how conflicting duplicates should be handled. |
| Missing values | Calls `dropna()` without a subset, so rows with a null in any column are dropped. | This may discard otherwise useful records because of an optional field. Define required fields and report rejected rows/reasons instead of silently dropping them. |
| Date handling | If `Transaction Date` exists, creates `Transaction_Date`, `Transaction_Month`, and `Transaction_Year` using Spark date functions. | An unparseable date may become null. The notebook does not subsequently quarantine or remove rows solely because date parsing failed, nor does it report parse-failure counts. |
| Numeric handling | If present, casts `Price` to double and `Quantity` to integer. | Invalid strings can cast to null after the earlier `dropna()` step. There is no subsequent invalid-cast filter or rejection report. Validate ranges, decimals, and casting failures explicitly. |
| Revenue | When both fields are present, derives `Revenue = Price × Quantity`. | No explicit checks for negative values, overflow, unexpected nulls, or reconciliation against a trusted total are implemented. Confirm the business definition of revenue before comparing with external totals. |
| Output | Writes Parquet with overwrite mode to the configured cleaned output path and writes a second output path. | Validate output row count, schema, folder contents, and ability to read files back before marking a run successful. Overwrite mode replaces prior output at each configured destination. |
| SQL analytics | Queries record count, total revenue, revenue by region/category, and top products. | Query success is a useful integration check but is not a complete data-quality test. Add assertions or saved run-level validation results. |

## Recommended validation sequence

Perform these checks after running the notebook in Synapse:

1. **Input check:** Confirm expected source files and required business fields exist. If they do not, stop the run rather than relying only on conditional transformations.
2. **Row-count reconciliation:** Record input rows, rows after duplicate handling, rows after null handling, rows after type conversion, and rows written. Explain every material difference.
3. **Duplicate check:** Capture the count of exact duplicate rows and separately define the business key used to identify duplicate transactions.
4. **Required-value check:** Report null/blank values for required identifiers, transaction dates, price, quantity, and dimensions used in analytics. Do not treat every nullable attribute as automatically invalid.
5. **Type and range check:** Count date parse failures and numeric cast failures. Decide and document whether zero/negative prices or quantities are valid for this dataset; do not assume they are errors without a business rule.
6. **Derived-value check:** Confirm `Revenue` is present when expected and matches `Price × Quantity` within an agreed precision/tolerance.
7. **Output check:** Confirm Parquet files exist at the configured destination, read them back, compare output counts/schema with the transformation results, and inspect a small sample.
8. **SQL integration check:** Run the supplied preview, count, total-revenue, revenue-by-region/category, and top-products queries. Confirm all referenced columns exist and the query results are plausible.
9. **Access and security check:** Verify the configured identity has only the required access. Keep account keys, passwords, and SAS tokens out of notebooks, SQL, screenshots, and Git history.

## Suggested run evidence to retain

For each run, capture the run timestamp/identifier, source location (without secrets), input row count, duplicate count, rows removed for required-field failures, date and numeric conversion failures, final output row count, output path, schema version, SQL validation results, and any warnings or rejected-row counts. Store operational logs in an appropriate Azure location rather than relying on notebook console output alone.

## Acceptance checklist

- [ ] Required columns and expected types are confirmed.
- [ ] Input, intermediate, rejected, and output counts reconcile.
- [ ] Duplicate policy is explicit and measured.
- [ ] Required-field failures and type-conversion failures are counted.
- [ ] Date parse failures are reviewed.
- [ ] Numeric ranges and revenue calculation are validated against documented business rules.
- [ ] Cleaned Parquet data can be read back with the expected schema.
- [ ] All included Serverless SQL analytics queries complete and return plausible results.
- [ ] Run evidence is retained and no credentials are committed.

## Current limitations

The repository currently demonstrates a working learning/portfolio pipeline, not a production-grade data-quality framework. These controls are recommendations; they are not all implemented automatically by the current notebook. The checked-in code and this report alone do not prove that Azure resources are currently running or that the pipeline has been executed successfully in a fresh environment.

## Related source files

- [PySpark cleaning notebook](../Code/ecommerce_data_cleaning.ipynb)
- [External data source and view setup](../Code/external_data_source_setup.sql)
- [Serverless SQL analytics](../Code/sql_analytics.sql)
- [Project README](../README.md)
