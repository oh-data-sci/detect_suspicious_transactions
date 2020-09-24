import pandas as pd

def check_for_nulls(df: pd.DataFrame):
    columns = df.columns
    print('checking for nulls in', columns)
    columns_to_check = []
    for column in columns:
        numnulls = sum(df[column].isnull())
        if numnulls != 0:
            print('column', column, 'contains', numnulls, 'null values')
            columns_to_check.append(column)
    return columns_to_check


def create_client_score():
    return 0