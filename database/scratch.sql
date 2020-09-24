SELECT
	alldates.the_date, 
	exch.currency,
	exch.echange_rate
FROM
(
	WITH RECURSIVE dates(date) AS 
	(
		VALUES((SELECT MIN(exchange_date) FROM currency_exchange)) -- '2007-10-26'
		UNION ALL
		SELECT date(date, '+1 day')
		FROM dates
		WHERE date < ((SELECT MAX(exchange_date) FROM currency_exchange )) -- '2020-05-15'
	)
	SELECT 
		date AS the_date
	FROM 
		dates
	ORDER BY 
		date 
) alldates
LEFT JOIN
	currency_exchange exch
	ON exch.exchange_date = alldates.the_date
LIMIT 100
;


WITH RECURSIVE dates(date) AS (
  VALUES('2015-10-03')
  UNION ALL
  SELECT date(date, '+1 day')
  FROM dates
  WHERE date < '2015-11-01'
)
SELECT date FROM dates;
