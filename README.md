technical assessment notes
===
# 0. introduction
the assignment description can be found in the document in the `notes/` folder.

	thanks for the exercise! honestly, i had allowed a pass since i coded much or put together a model (i had been on covid furlough since late spring). i started the exercise feeling much rustier than i thought i would be, looking up every other command and code syntax. it's humbling, and eye-opening, how quickly memory fades! eventually, oxygen found its way to the corners of the brain, code returned to the fingertips, and solutions on the screen which was refreshing to see, but slower than i would have liked.


# 1. data imputation in `sql`

- q: how would you fill the missing values?
	+ normally i would solve the problem at the source. i would seek an external data source with the full ground truth of currency data. after all, complete and trustworthy historical currency records do exist. 
	+ however, failing that (and in the spirit of this technical assessment) i could impute the missing currency rate values from the known, available values. depending on the use case (one-off project or repeated use likely? in a rush or not?) it is tempting to fill in the currency rate table once and for all, and keep it henceforth up to date, with imputation if needed, regardless of which transaction dates are currently under consideration. however, for a quick, simple one-off project it would reduce computation and complexity to simply/only fill in the gaps in the transaction data and which we currently need filled. 
	+ for the imputation itself we have options (for the latter options, `sql`, and in particular `sqlite`, is not the most appropriate tool!): 
		1. lagged value (e.g. stock prices which are held in stasis outside of market hours),  
		2. closest value (small intervals, gentle changes), 
		3. linear interpolation (e.g. between temperature measurements),
		4. spline interpolation (when we insist on smooth transitions), 
		5. times series fitting (to account for seasonality etc), 

- q: can you propose a solution that uses the last existing exchange rate for that currency pair?
	+ yes. see below. i will first note that filling in the missing values by lagged values is only a reasonable option if certain assumptions hold (so i first check those):
		 1. for every currency, there exists a known rate earlier or on the earliest transaction date.
		 2. the gaps that need to be filled do not cover extended periods. for normal currency fluctuations, passing on the last known value starts to feel dodgy past a few days.
		 3. the values do not vary extremely from one day to the next.

- q: propose a solution using sql-lite.
 	+ please find my solution in the attached file `imputation.sql`.
	+ in short, i set up `sqlite` and ran the commands in the same order on the prompt, saving them to file as i went along. that code has been tested to work on this version: `sqlite-tools-osx-x86-3330000`. you will also find, in the comments, notes on my thinking towards the solution. 
	+ i checked and noticed that i never needed to bridge over a long period, 3 days at most. the simplest way i found to do that was to use a window function, and `COALESCE` the values of `LAG()` one, two, and three days back, in order. the first non-null thus becomes imputed value. this might be rightly criticized for being fragile. a future data set might have a gap of 4,5,6,.. days that needed to be bridged and then what? without solving the general case, i expanded the code after the fact to cover 7 days back. this code simply should not be used to bridge gaps beyond that. i think that is fair. i would be loathe to trust a forex rate that out much of date.
	+ `sqlite` does not have the full complement of functionality to makes this as simple as it could get in say postgresql. 

![how to solve data problems in sql](../img/data_problems.jpeg)


# 2. machine learning solution for anomaly detection
- please find the `case_study.ipynb` notebook and notes therein for the solution. it uses a small set of utility functions which can be found in the `src` folder. 

### q: perform a basic exploratory analysis and describe the quality of the data
- highly imbalanced data set. contains 30k records, of which only 172 (0.6%) are flagged as suspicious. 
- each record has 13 fields, including the suspicious flag.
- all 12 feature fields are heavily unevenly distributed.
- a much higher proportion of transactions with `Source System = "beta"` are flagged suspicious than `Source System = "alpha"` or `Source System = "gamma"`
- `Leg Type` is useless.
- the two products, `FX Swaps` and `FX Spots` are responsible for the bulk of suspicious transactions, with a relatively high proportion of the former being flagged. both belong to the `FX TRADES` product group. 
- 134 rows lack `Product Group` information, which may be recoverable.
- high relative frequency of suspicious transactions in indian rupees and japanese yen (ca 5%), also, to lesser extent, usd (~<1%). 
- the canadian office `CA` , has a high relative rate of flagged transactions (40%). to lesser extent, so do the french office, `FR` (10%) and the swiss office, `CH`, as well (~2%).  
- a high ml risk rating implies higher relative rate of being flagged suspicious. but little difference between medium and low risk rating.
- 345 records have missing values in at least one field. if these are removed completely the number of records flagged drops to 168. however, it is possible to impute some of the missing values.
- can drop notional amount and fx rate and only use gbp amount (which is comparable across records).
- drop out of consideration these columns:
	+ `Leg Type` (all values `CASH`, except for 30 missing values that i could only impute to be the same type class). this does not help.
	+ `Fx_rate` multiplicative factor, useless. 
	+ `Notional Amount` (use `Gbp Notional Amount` only)
- imputing the missing product group values is feasible.
#### observations from the trade dates
- 299 distinct trade dates, out of 424 distinct dates in the time span of the data. (125 dates have no transactions).
- all trade dates are during the work week. i assume other missing dates are bank holidays etc.
- the second quarter has (suspiciously!?) few suspicious trades labelled. immplying a quiet period in fraud. to a lesser extent so does the 3rd quarter too
- there are about 100 trades per day
- for a long period the rate of suspicous/flagged transactions hovered around 2, but lately is higher and oscillates around 4
- december/january (months 12 and 1) have more suspicious trades, both in raw counts and relative to total frequencies of trades.
- fridays (weekday 4) have more flagged trades, both in raw counts and relative to total frequencies of trades.
#### notes on amounts
- four trade records had no amount information. these also lack currency rate information.
- can drop `Notional Amount` and `FX_rate`. only their multiple, gbp amount is comparable across records.
- log (gbp) amount is approximately lognormal

#### clean data
- impute obvious 
- drop rows where 
   + consider flagging all records with missing values as 'suspicious' (in the sense "requiring consideration"). it is not unreasonable to expect the information to be present for all transactions. these fields aren't optional. think about why information is missing from a record? is it because it was entered by hand? or joined from a corrupt data source? shouldn]t the input be sanitised somewhere upstream? whether as an indicator of fraud or failure, missing values should get flagged for further consideration.


### engineer a small number of features 
- expand the `Trade Date` column:
    + is the trade on a weekend?
    + which weekday? (are dates closer to the weekend more likely for fraudulent attempts than mid week dates?)
    + which quarter?
    + which month?
    + is the trade near the end (d>27) of the month?
    + is the trade near the beginning (d<3) of the month?
    + ~~is it on a bank holiday (region dependent, so skip this)~~
    + ~~is it near a bank holiday (region dependent, so skip this)~~

- transform the `Gbp Notional Amount` numerical field:
	+ take log of `Gbp Notional Amount` (power transform). that way you get at normally distributed numerical column.
	+ discretize trade amount into percentile buckets:
        - e.g. (low, mid, high, very high (+extreme?)), 10th percentile, 10-80th, 80-95, 95+ (99-100?).
        - then transform into an ordinal integer variable.
- collapse/redraw the categorical variables:
	- combine product name and product group information into a more meaningful product type variable. 

	+ further collapsing the product specifier into a single column with fewer classes is possible.
		- i.e. product_type: "fx_trade_spots", "fx_trade_swaps", "irs", "other
	+ collapse currency to
		- usd, eur, aed, aud, cad, jpy, pln, sek, other 
- transform categoricals with one hot encoding

- unimplemented feature idea: consider each client's number of previous suspicious transactions.

### develop a machine learning solution to help identify future suspicious trades
- start by splitting the dataset:
    + flagged/unflagged.
    + 80% (ensure contains 80% of flagged records) to training+validation data set.
    + 20% (ensure contains 20% of flagged records) to testing (place in cold storage to avoid leakage).
- pass only training data onwards:
    + split further into multiple balanced training and validation data sets:
        - create multiple sets of 80% training/20% validation 
- choose classification algorithm:
    + consider random forest (usually performs well. handles variety of data formats, resistant to overfitting. handles imbalance. not interpretable)
    + consider logistic regression (perfect for binary output. can give degree of probability for each classification.).
    + consider support vector machine (often performs well).
    + decision tree/cart (interpretable).
- 

### provide an evaluation of your model, explain what metrics you have used, what parameters are used by your model, and any limitations you can think of.
- not fully completed. i studied the confusion matrix, precision, and recall. i think for the use case one would be more concerned with high recall and allow to pay the cost in precision. (it should be cheaper to flag a non-fraud for scrutiny, than to miss a true fraud). 
 
### do best attempts at building a clean data pipeline providing the basis for production code
- not completed

### demonstrate using logging to help debugging in the future
- not completed.

### build at least one unit-test and one validation-test.
- see `src/test_eda.py`


# the plan

## eda and prep
- investigate missing values:
    + impute where unambiguous.
    + rule-based exclusion. actually consider flagging all records with missing values as 'suspicious', in the sense "requiring careful consideration". in this case it does not seem unreasonable to expect all the information to be present for all transactions? (there are no optional fields here?) why is some information missing from a record? is it because the entries were a data type the capture system was not anticipating? whether an indicator of fraud or failure, it gets flagged for further consideration.
    + machine learning identification: continue with only full records for machine learning stage.
 
- investigate feature imbalances
    + drop useless columns.
    + gauge result imbalance.
    
- select numerical column:
    + verify exchange rate translation from source currency to gbp. if correct, skip notational amount in source currency. skip fx rate. go ahead with notational amount in gbp.
    + consider discretizing trade amount into buckets:
        - e.g. (low, mid, high, very high (+extreme?)), 10th percentile, 10-80th, 80-95, 95+ (99-100?).

- select categorical columns:
    + decide whether both product name and product group are necessary (does name imply group? is name too imbalanced, useless?) probably better to skip one of them.
    + consider joining product names/groups for sake of imbalance. 
    + one hot encoding for product name/group, currency, countrycode, risk rating, 

- split dataset:
    + flagged/unflagged.
    + 80% (ensure contains 80% of flagged records) to training+validation data set.
    + 20% (ensure contains 20% of flagged records) to testing (place in cold storage to avoid leakage).

- expand trade date:
    + which quarter?
    + is the trade at the end (d>27) or the beginning (d<3) of the month?
    + which weekday? (are dates closer to the weekend more likely for fraudulent attempts than mid week dates?)
    + is it on a weekend?
    + ~~is it on a bank holiday (region dependent skip this)~~
    + ~~is it near a bank holiday (region dependent skip this)~~

## modeling building pipeline
    
## model perfomance evaluation
- compute model predictions for holdout set
    + compute confusion matrix