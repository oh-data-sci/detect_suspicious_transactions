import pandas as pd


filter_valueless(transactions_df):


filter_incomplete(transactions_df):

    # for the rest of the fields, demand that each record is complete. 
    # first save incomplete records to file, to report them as requiring further attention
    incomplete_records = transactions[transactions.isnull().any(axis=1)]
    incomplete_records.to_csv('data/suspicious_records/contain_nulls.csv')
    print('wrote', incomplete_records.shape, 'table of incomplete records to file.')
    # now drop them
    transactions.dropna(axis=0, inplace=True)