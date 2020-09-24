SELECT
	currency AS currency,
	ROUND(max_rate,2) AS maximum,
	ROUND(mean_rate,2) AS mean,
	ROUND(min_rate,2) AS minimum,
	ROUND(rate_stdev,3) AS stdev,
	ROUND(rate_stdev/mean_rate,3) AS proportional_stdev,
	range_days,
	num_dates,
	num_records
FROM exchange_rate_summary
WHERE num_dates < num_records 
ORDER BY num_records-num_dates DESC
;

