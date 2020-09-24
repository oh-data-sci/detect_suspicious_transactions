DROP TABLE IF EXISTS dates_expanded;
CREATE TABLE dates_expanded AS
SELECT
	alldates.the_date  AS the_date,
	exch.currency      AS currency,
	exch.exchange_rate AS exchange_date
	-- CASE
	-- 	WHEN exch.exchange_rate is NULL THEN
	-- 		LAG(exch.exchange_rate,1)
	-- 			OVER(PARTITION BY exch.currency
	--				  ORDER BY alldates.the_date)
FROM
(
	WITH RECURSIVE dates(date) AS
	(
		VALUES((SELECT MIN(exchange_date) FROM currency_exchange_daily)) -- '2007-10-26'
		UNION ALL
		SELECT date(date, '+1 day')
		FROM dates
		WHERE date < ((SELECT MAX(exchange_date) FROM currency_exchange_daily )) -- '2020-05-15'
	)
	SELECT
		date AS the_date
	FROM
		dates
	ORDER BY
		date
) alldates
LEFT JOIN
	currency_exchange_daily exch
	ON exch.exchange_date = alldates.the_date
;
SELECT * FROM dates_expanded LIMIT 100;
