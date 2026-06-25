import pandas as pd
import mysql.connector

conn = mysql.connector.connect(
    host="localhost",
    user="root",
    password="password",
    database="project_funnel_analytics",
    allow_local_infile=True,
    connection_timeout=300
)
cursor = conn.cursor()

def import_table(table, filepath, batch_size=500):
    print(f"Importing {table}...")
    df = pd.read_csv(filepath)
    df = df.where(pd.notnull(df), None)
    cols = ",".join(df.columns)
    placeholders = ",".join(["%s"] * len(df.columns))
    sql = f"INSERT IGNORE INTO {table} ({cols}) VALUES ({placeholders})"
    total = len(df)
    for i in range(0, total, batch_size):
        batch = df.iloc[i:i+batch_size]
        data = [tuple(row) for row in batch.values]
        cursor.executemany(sql, data)
        conn.commit()
        print(f"  {min(i+batch_size, total):,}/{total:,} rows done...")
    print(f"  ✅ {table} complete — {total:,} rows\n")

import_table("users",         "data/users.csv")
import_table("sessions",      "data/sessions.csv")
import_table("events",        "data/events.csv",  batch_size=200)
import_table("orders",        "data/orders.csv")
import_table("user_segments", "data/user_segments.csv")

cursor.close()
conn.close()
print("✅ ALL DONE!")