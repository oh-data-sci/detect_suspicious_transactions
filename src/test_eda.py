import unittest
import eda
import pandas as pd

class TestEDA(unittest.TestCase):

    def test_check_for_nulls(self):
        dataframe = pd.DataFrame(
            {
                'a':[1,2,3,4,5],
                'b':[10,20,NA, NA, 50]
            })
        result = eda.check_for_nulls(dataframe)
        self.assertEqual(['b'], pd.DataFrame())
        return 
        
        
if __name__ == '__main__':
    unittest.main()
    
    