------------------------------------------------------------------------
.mode tabs
.separator '|'
.headers on
.echo on

-- load the transactions
DROP TABLE IF EXISTS transactions;
CREATE TABLE transactions (
	trans_date DATE,
	currency VARCHAR(50)
);
.import data/raw/trans_days.csv transactions --skip 1
-- check what we've got
SELECT 
	COUNT(*) AS num_rows, 
	COUNT(DISTINCT currency) AS num_currencies,
	COUNT(DISTINCT trans_date) AS num_dates,
	MIN(trans_date) AS earliest_trans_date,
	MAX(trans_date) AS last_trans_date,
	MAX(trans_date) - MIN(trans_date) AS range_days
FROM transactions;
-- 10286 rows, contains 28 currencies, 866 distinct dates, from "2014-06-16" to ""2020-05-07" which spans 2152 days.
-- no transactions for 2/3 of dates in span.

-- summarize transaction data per currency
DROP TABLE IF EXISTS trans_currency_summary;
CREATE TABLE trans_currency_summary AS 
SELECT
	currency, 
	COUNT(*) AS num_rows, 
	COUNT(DISTINCT currency) AS num_currencies,
	COUNT(DISTINCT trans_date) AS num_dates,
	MIN(trans_date) AS earliest_trans_date,
	MAX(trans_date) AS latest_trans_date,
	MAX(trans_date) - MIN(trans_date) AS range_days,
	COUNT (*) AS num_records
FROM transactions
GROUP BY currency
ORDER BY currency
;

SELECT COUNT(*) FROM trans_currency_summary WHERE num_dates != num_records;
-- none. good!

------------------------------------------------------------------------------------

-- now load the currency exchange look up table
DROP TABLE IF EXISTS currency_exchange;
CREATE TABLE currency_exchange (
	exchange_date DATE,
	currency VARCHAR(50),
	exchange_rate NUMERIC
);
.import exch_rates2.csv currency_exchange --skip 1
-- check what we've got
SELECT 
	COUNT(*)                                AS num_rows, 
	COUNT(DISTINCT currency)                AS num_currencies,
	COUNT(DISTINCT exchange_date)           AS num_dates,
	MIN(exchange_date)                      AS earliest_exchange_date,
	MAX(exchange_date)                      AS last_exchange_date,
	MAX(exchange_date) - MIN(exchange_date) AS range_days
FROM currency_exchange;
-- 376,956 rows, 53 currencies, 2898 distinct dates, from 2007-10-26 to 2020-05-15, which spans 4585 days. 
-- check: exchange date span covers the range of transactions. 
-- good, but now check that this is true on a per-currency basis.
------------------------------------------------------------------------------------

DROP TABLE IF EXISTS exchange_rate_summary;
CREATE TABLE exchange_rate_summary AS 
SELECT
	currency, 
	MAX(exchange_rate)                      AS max_rate,
	AVG(exchange_rate)                      AS mean_rate,
	MIN(exchange_rate)                      AS min_rate, 
	-- STDDEV_POP(exchange_rate)               AS rate_stdev, --postgres, not sqlite
	MIN(exchange_date)                      AS earliest_exchange_date,
	MAX(exchange_date)                      AS latest_exchange_date,
	MAX(exchange_date) - MIN(exchange_date) AS range_days,
	COUNT (DISTINCT exchange_date)          AS num_dates,
	COUNT(*)                                AS num_records
FROM currency_exchange
GROUP BY currency
ORDER BY currency
;
-- earliest date varies quite a bit between currencies.
-- now we verify that for every currency, there exists a known rate earlier or on the earliest transaction date.
SELECT
	tran.currency AS currency,
	tran.earliest_trans_date AS first_transaction,
	exch.earliest_exchange_date AS first_exchange_data
FROM trans_currency_summary tran
	LEFT JOIN exchange_rate_summary exch
		ON tran.currency = exch.currency
WHERE tran.earliest_trans_date < exch.earliest_exchange_date;

-- good, that means we won't need to extrapolate the rate of any currency to dates earlier 
-- than its earliest available exchange rate. 

-- from a glance at exchange_rate_summary, i see that
--     some currencies have more records than distinct dates. 
--     up to 4 measurements in the same day.
--     (don't know which order these go, nor which is the most correct). 

DROP TABLE IF EXISTS currency_exchange_daily;
CREATE TABLE currency_exchange_daily AS 
SELECT
	currency,
	exchange_date,
	AVG(exchange_rate) AS exchange_rate, 
	COUNT(*) num_observations
FROM currency_exchange
GROUP BY currency, exchange_date
ORDER BY currency, exchange_date
;
-- now have collapsed currency rate table to a daily average (arithmetic mean) 
-- for each (available) currency and date pair. 
SELECT * FROM currency_exchange_daily LIMIT 3;
----------------------------------------------------------------------------------------
-- using currency_exchange_daily from now on. 
DROP TABLE currency_exchange;
----------------------------------------------------------------------------------------
-- there are 9655 matching (currency, date) pairs in exchange look up table. however, 
-- there are 631 records with no matching currency exchange information,
-- covering 250 dates and 22 (all but one) currencies. we need to find a way to fill those in. 
----------------------------------------------------------------------------------------

-- plan of attack (impute from most recent lagged values):
-- 1. build an interim common table expression of all relevant dates.
-- 2. build an interim list of all relevant currencies.
-- 3. cross-join interim tables to form all combinations of (currency, date) pairs
-- 4. left join the combinations table with exchange rate information 
--    + fill in missing values with lagged values, bridging at most a 7 day gap.
-- 5. left join transaction table with expanded and filled in exchange rate table
-- 6. verify values.

DROP TABLE IF EXISTS all_combos;
CREATE TABLE all_combos AS 
WITH RECURSIVE dates(date) AS ( -- trick to build a table of all dates
	VALUES((SELECT MIN(exchange_date) FROM currency_exchange_daily)) -- '2007-10-26'
	UNION ALL
	SELECT date(date, '+1 day')
	FROM dates
	WHERE date < ((SELECT MAX(exchange_date) FROM currency_exchange_daily )) -- '2020-05-15'
)
SELECT
	currency AS the_currency,
	date     AS the_date
FROM
	dates
	CROSS JOIN
	(SELECT DISTINCT currency FROM currency_exchange_daily) -- list of all currencies
ORDER BY currency, date
;
-- verifying that all combinations are accounted for?:
SELECT
	COUNT(DISTINCT currency) 		                    AS num_currencies,
	COUNT(DISTINCT the_date) 		                    AS num_dates,
	COUNT(*)                                            AS num_combinations,
	COUNT(DISTINCT currency) * COUNT(DISTINCT the_date) AS the_comparison
FROM 
	currency_date_table
;

-- fill in the exchange rate table by bringing forward a lagged value, up to one week into the past:
-- (gaps longer than 1 week are not filled in).
DROP TABLE IF EXISTS filled_exchange_table;
CREATE TABLE filled_exchange_table AS 
SELECT
	combo.the_currency AS the_currency,
	combo.the_date     AS the_date,
	COALESCE(exch.exchange_rate, -- grab the first non-null exchange rate found
			 LAG(exch.exchange_rate,1) OVER(PARTITION BY combo.the_currency ORDER BY combo.the_date),
			 LAG(exch.exchange_rate,2) OVER(PARTITION BY combo.the_currency ORDER BY combo.the_date),
			 LAG(exch.exchange_rate,3) OVER(PARTITION BY combo.the_currency ORDER BY combo.the_date),
			 LAG(exch.exchange_rate,4) OVER(PARTITION BY combo.the_currency ORDER BY combo.the_date),
			 LAG(exch.exchange_rate,5) OVER(PARTITION BY combo.the_currency ORDER BY combo.the_date),
			 LAG(exch.exchange_rate,6) OVER(PARTITION BY combo.the_currency ORDER BY combo.the_date),
			 LAG(exch.exchange_rate,7) OVER(PARTITION BY combo.the_currency ORDER BY combo.the_date),
			 -1 -- default if gap is greater than 1 week.
			) 	       AS the_rate,
	COALESCE(exch.exchange_date, -- grab the first non-null exchange rate found
			 LAG(exch.exchange_date,1) OVER(PARTITION BY combo.the_currency ORDER BY combo.the_date),
			 LAG(exch.exchange_date,2) OVER(PARTITION BY combo.the_currency ORDER BY combo.the_date),
			 LAG(exch.exchange_date,3) OVER(PARTITION BY combo.the_currency ORDER BY combo.the_date),
			 LAG(exch.exchange_date,4) OVER(PARTITION BY combo.the_currency ORDER BY combo.the_date),
			 LAG(exch.exchange_date,5) OVER(PARTITION BY combo.the_currency ORDER BY combo.the_date),
			 LAG(exch.exchange_date,6) OVER(PARTITION BY combo.the_currency ORDER BY combo.the_date),
			 LAG(exch.exchange_date,7) OVER(PARTITION BY combo.the_currency ORDER BY combo.the_date)
			) 	       AS rate_source_date,
	CASE WHEN exch.exchange_rate IS NULL THEN 1 ELSE 0 END AS is_imputed	
FROM
	all_combos combo
LEFT JOIN
	currency_exchange_daily exch
	ON combo.the_date = exch.exchange_date 
		AND combo.the_currency = exch.currency
ORDER BY 
	the_currency,
	the_date
;

-- verify number of original records is unchanged, and the rest are marked as imputed
SELECT
	is_imputed,
	COUNT(*) AS num_records
FROM
	filled_exchange_table
GROUP BY
	is_imputed
;

-- check how many records could not be filled in due to gap being extremely long
SELECT 
	COUNT(*) num_records
FROM
	filled_exchange_table
WHERE 
	the_rate = -1
;

----------------------------------------------------------------------------------------
-- augment transaction data with filled_exchange_table
DROP TABLE IF EXISTS augmented_transaction;
CREATE TABLE augmented_transaction AS 
SELECT
	tran.trans_date     AS transaction_date,
	tran.currency       AS currency,
	exch.the_rate       AS exchange_rate,
	exch.is_imputed     AS is_imputed
FROM transactions AS tran
	LEFT JOIN
	filled_exchange_table AS exch
	ON tran.currency = exch.the_currency 
		AND tran.trans_date = exch.the_date
ORDER BY 
	currency,
	trans_date
;
-- verify results:
SELECT 
	is_imputed,
	COUNT(*) AS num_records
FROM
	augmented_transaction
GROUP BY is_imputed
;
-- 631 values have been imputed.
-- 9655 were originally present 

.output data/data_products/augmented_transactions.tsv
SELECT * FROM augmented_transaction ORDER BY currency, transaction_date;
.output

.exit
