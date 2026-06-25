import pandas as pd

df = pd.read_csv("data/events.csv")
df["cart_value"] = pd.to_numeric(df["cart_value"], errors="coerce")
df.to_csv("data/events.csv", index=False)
print("Fixed!")
