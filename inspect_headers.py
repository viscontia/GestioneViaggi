import pandas as pd
import sys

try:
    df = pd.read_excel('inp_Excel/mov_clienti_alloggi.xlsx')
    print("HEADERS:")
    for col in df.columns:
        print(f"- {col}")

    if 'CREATED' in df.columns:
        print("\nFIRST 5 CREATED VALUES:")
        print(df['CREATED'].head(5))
        print("\nFIRST 5 CREATED TYPES:")
        print(df['CREATED'].head(5).apply(type))
except Exception as e:
    print(f"Error reading excel: {e}")
