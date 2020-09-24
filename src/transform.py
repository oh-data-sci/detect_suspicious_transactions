import logging
import pandas as pd

product_name_to_group_dict = {
    'CRS-Vanilla'          : 'CIRS',
    'Deal Related Payment' : 'Miscellaneous Payments',
    'FX Forwards'          : 'FX TRADES',
    'FX NDFs'              : 'FX TRADES',    
    'FX Options'           : 'FX DERIV',
    'FX Spots'             : 'FX TRADES',
    'FX Swaps'             : 'FX TRADES',
    'IRS-ON Index Swap'    : 'IRS',
    'IRS-Vanilla'          : 'IRS',
    'Swaptions'            : 'Swaptions',
}

def product_name_to_group(transactions_df: pd.DataFrame, 
                          translate_dict=product_name_to_group_dict: dict):
"""
    imputes product group where missing, using the translation dict
    from product name to product group.
"""
    for key in translate_dict:
        transactions_df.loc[
            (transactions_df['Product Group'].isna()) 
            & (transactions_df['Product Name'] == key), 'Product Group'] =         translate_dict.get(key)
    return transactions_df


product_name_to_type_dict = \
{
    'CRS-Vanilla'          : 'other',
    'Deal Related Payment' : 'other',
    'FX Forwards'          : 'fx_forwards',
    'FX NDFs'              : 'fx_other',    
    'FX Options'           : 'fx_other',
    'FX Spots'             : 'fx_spots',
    'FX Swaps'             : 'fx_swaps',
    'IRS-ON Index Swap'    : 'irs',
    'IRS-Vanilla'          : 'irs',
    'Swaptions'            : 'other',
}
def product_name_to_group(transactions_df: pd.DataFrame, 
                          translate_dict=product_name_to_type_dict: dict):

"""
    map from 'Product Name' to new categorization variable: "product_type" which is less imbalanced.
"""
    temp_df = pd.DataFrame(
        {'product_name':product_name_to_product_type.keys(),
        'product_type': product_name_to_product_type.values()})
    transactions_df = pd.merge(transactions_df, temp_df, left_on='Product Name', right_on='product_name', how='left')
    return transactions_df


# convert from notional amount currency to a simplified currency_feature.
currency_to_currency_simplified = {
    'AED': 'AED',
    'AUD': 'AUD',
    'BRL': 'other',
    'CAD': 'CAD',
    'CHF': 'other',
    'CNH': 'other',
    'CZK': 'other',
    'DKK': 'DKK',
    'EUR': 'EUR',
    'HKD': 'other',
    'HUF': 'other',
    'ILS': 'other',
    'INR': 'other',
    'JPY': 'JPY',
    'MAD': 'other',
    'MXN': 'MXN',
    'NOK': 'other',
    'NZD': 'NZD',
    'PLN': 'PLN',
    'RUB': 'other',
    'SEK': 'SEK',
    'SGD': 'other',
    'THB': 'other',
    'TRY': 'other',
    'USD': 'USD',
    'ZAR': 'ZAR',
}
def simplify_currency(transactions_df: pd.DataFrame, translation_dict = currency_to_currency_simplified : dict):
    """
    
    """
    temp_df = pd.DataFrame({'currency_all':translation_dict.keys(), 
                            'currency_reduced': translation_dict.values()})
    transactions = \
        pd.merge(transactions, temp_df,
                 left_on='Notional Amount Currency',
                 right_on='currency_all',
                 how='left')\
            .drop(columns=['Notional Amount Currency', 'currency_all', ])




def augment_date_columns(transactions_df: pd.DataFrame):
    """
    add information derived from transaction date into new feature columns. 
    """
    # augment the date column:
    transactions_df['date'] = pd.to_datetime(transactions_df['Trade Date'], format='%d/%m/%Y')
    # print('there are', sum(transactions_df['date'].isnull()), 'nonsensical date strings')
    # display(transactions_df['Trade Date'].describe())
    # display(transactions_df['date'].describe(datetime_is_numeric=True))
    transactions_df['month'] = transactions_df['date'].dt.month
    transactions_df['is_month_start'] = transactions_df['date'].dt.is_month_start
    transactions_df['is_month_end'] = transactions_df['date'].dt.is_month_end
    transactions_df['weekday'] = transactions_df['date'].dt.weekday
    transactions_df['quarter'] = transactions_df['date'].dt.quarter
    return transactions_df


def add_log_amount(transactions_df:pd.DataFrame):    
    """augment by adding log_amount column"""
    # first verify that no zero value/negative amount are found
    criteria = (transactions_df['gbp_log_amount'] < 0.01) | (transactions_df['gbp_log_amount'].isna())
    if any(criteria):
        print(sum(criteria), 'missing or vanishing transaction values found')
        transactions_df.loc[criteria, 'gbp_log_amount'] = 0.01
    transactions_df['gbp_log_amount'] = np.log10(transactions_df['Gbp Notional Amount'])        
