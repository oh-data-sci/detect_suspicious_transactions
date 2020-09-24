DROP TABLE IF EXISTS transactions;
CREATE TABLE transactions (
	trans_date DATE,
	currency VARCHAR(50)
);
COPY transactions(trans_date, currency)
FROM '/Users/oh/work/assessment/trans_days.csv'
DELIMITER '|'
CSV HEADER;
----------------------
DROP TABLE IF EXISTS currency_exchange;
CREATE TABLE currency_exchange (
	exchange_date DATE,
	currency VARCHAR(50),
	exchange_rate NUMERIC
);
COPY currency_exchange(exchange_date, currency, exchange_rate)
FROM '/Users/oh/work/assessment/exch_rates2.csv'
DELIMITER '|'
CSV HEADER;
----------------------
DROP TABLE IF EXISTS exchange_rate_summary;
CREATE TABLE exchange_rate_summary AS 
SELECT
	currency, 
	MAX(exchange_rate) AS max_rate,
	AVG(exchange_rate) AS mean_rate,
	MIN(exchange_rate) AS min_rate, 
	STDDEV_POP(exchange_rate) AS rate_stdev,
	MIN(exchange_date) AS earliest_exchange_date,
	MAX(exchange_date) AS latest_exchange_date,
	MAX(exchange_date) - MIN(exchange_date) AS range_days,
	COUNT (DISTINCT exchange_date) AS num_dates,
	COUNT(*) AS num_records
FROM currency_exchange
GROUP BY currency
ORDER BY currency
;
------------------------------
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

----------------------
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

-------
DROP TABLE IF EXISTS augmented_transaction;
CREATE TABLE augmented_transaction AS 
SELECT
	tran.trans_date     AS trans_date,
	tran.currency       AS currency,
	exch.exchange_rate  AS exchange_rate,
	exch.exchange_date  AS exchange_date
FROM transactions AS tran
	LEFT JOIN
	currency_exchange AS exch
	ON tran.currency = exch.currency 
		AND exch.exchange_date = tran.trans_date 
ORDER BY currency, trans_date
;

DROP TABLE IF EXISTS need_to_impute;
CREATE TABLE need_to_impute AS
SELECT
	trans_date,
	currency
FROM augmented_transaction
WHERE exchange_rate IS NULL OR exchange_date IS NULL
ORDER BY currency, trans_date
;

DROP TABLE IF EXISTS available_and_missing;
CREATE TABLE available_and_missing AS
SELECT
	CASE 
		WHEN exch.currency IS NULL AND miss.currency IS NOT NULL THEN miss.currency
		WHEN miss.currency IS NULL AND exch.currency IS NOT NULL THEN exch.currency
		ELSE NULL END AS the_currency,
	CASE 
		WHEN exch.exchange_date IS NULL AND miss.trans_date IS NOT NULL THEN miss.trans_date
		WHEN miss.trans_date IS NULL AND exch.exchange_date IS NOT NULL THEN exch.exchange_date
		ELSE NULL END AS the_date,
	exch.exchange_rate AS exch_rate,
	CASE 
		WHEN exch.exchange_rate IS NULL THEN TRUE
		ELSE FALSE END AS to_impute
FROM 
	currency_exchange_daily exch
	FULL OUTER JOIN
		need_to_impute miss
		ON exch.currency = miss.currency AND exch.exchange_date = miss.trans_date
-- WHERE (exch.currency IS NULL AND miss.currency IS NULL)  
-- 	OR (exch.exchange_date IS NULL AND miss.trans_date IS NULL) 
ORDER BY the_currency, the_date
;

DROP TABLE IF EXISTS available_and_imputed;
CREATE TABLE available_and_imputed AS
SELECT
	the_currency,
	the_date,
	COALESCE(exch_rate, 
			 LAG(exch_rate,1) OVER(PARTITION BY the_currency ORDER BY the_date),
			 LAG(exch_rate,2) OVER(PARTITION BY the_currency ORDER BY the_date),
			 LAG(exch_rate,3) OVER(PARTITION BY the_currency ORDER BY the_date),
			 LAG(exch_rate,4) OVER(PARTITION BY the_currency ORDER BY the_date),
			 LAG(exch_rate,5) OVER(PARTITION BY the_currency ORDER BY the_date),
			 LAG(exch_rate,6) OVER(PARTITION BY the_currency ORDER BY the_date),
			 LAG(exch_rate,7) OVER(PARTITION BY the_currency ORDER BY the_date)
			) AS the_rate,
	to_impute AS imputed
FROM 
	available_and_missing
;
