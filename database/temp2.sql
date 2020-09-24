-- 1. build an interim common table expression of all relevant dates.
-- 2. build an interim table of all relevant currencies.
-- 3. cross-join interim tables to form all combinations of (currency, date) pairs
-- 4. left join the combinations table with exchange rate information 
--    + fill in missing values with lagged values, bridging at most a 7 day gap.

DROP TABLE IF EXISTS all_combos;
CREATE TABLE all_combos AS 
WITH RECURSIVE dates(date) AS (
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
	(SELECT DISTINCT currency FROM currency_exchange_daily)
ORDER BY currency, date
;
-- verifying that all combinations are accounted for?:
SELECT
	COUNT(DISTINCT currency) AS num_currencies,
	COUNT(DISTINCT the_date) AS num_dates,
	COUNT(*) AS num_combinations
FROM 
	currency_date_table
;

-- fill in the exchange rate table by bringing forward lagged value, up to one week into the past:
-- (gaps longer than 1 week are not filled in)
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
	CASE WHEN exch.exchange_rate IS NULL THEN 1
		ELSE 0 END     AS is_imputed	
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

-- verify number of imputed records
SELECT 
	COUNT(*) num_records
FROM
	filled_exchange_table
WHERE 
	is_imputed = 1
;