import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import random
import uuid
import os

random.seed(42)
np.random.seed(42)

# ── CONFIG ──────────────────────────────────────────────
START_DATE     = datetime(2024, 1, 1)
END_DATE       = datetime(2024, 6, 30)
TOTAL_USERS    = 50_000
OUTPUT_DIR     = "data"
os.makedirs(OUTPUT_DIR, exist_ok=True)

CITIES    = ["Delhi","Mumbai","Bangalore","Hyderabad","Chennai","Pune","Kolkata","Jaipur"]
DEVICES   = ["android","ios","web"]
CHANNELS  = ["organic","paid_google","referral","social","email"]
AGE_BUCKETS = ["18-24","25-34","35-44","45+"]
PAYMENT_METHODS = ["upi","card","cod","wallet"]

CITY_WEIGHTS    = [0.22,0.20,0.18,0.12,0.10,0.08,0.06,0.04]
DEVICE_WEIGHTS  = [0.55,0.35,0.10]
CHANNEL_WEIGHTS = [0.30,0.25,0.20,0.15,0.10]
AGE_WEIGHTS     = [0.35,0.40,0.18,0.07]
PAYMENT_WEIGHTS = [0.50,0.25,0.15,0.10]

# Funnel drop-off rates (realistic food delivery)
FUNNEL = {
    "app_open":              1.00,
    "search":                0.72,
    "restaurant_view":       0.58,
    "add_to_cart":           0.38,
    "checkout_initiated":    0.28,
    "payment_attempted":     0.22,
    "order_completed":       0.18,
}

EVENT_ORDER = list(FUNNEL.keys())

# ── HELPERS ─────────────────────────────────────────────
def random_date(start, end):
    delta = (end - start).days
    return start + timedelta(days=random.randint(0, delta))

def is_weekend(dt):
    return dt.weekday() >= 5

def session_base_time(signup_date):
    # Sessions happen after signup
    start = max(signup_date, START_DATE)
    if start >= END_DATE:
        return None
    return random_date(start, END_DATE)

# ── 1. USERS ────────────────────────────────────────────
print("Generating users...")
user_ids    = [f"U{str(i).zfill(6)}" for i in range(1, TOTAL_USERS + 1)]
signup_dates = [random_date(START_DATE, END_DATE) for _ in range(TOTAL_USERS)]

# User type — drives session frequency
user_types  = np.random.choice(
    ["power","regular","casual","low"],
    size=TOTAL_USERS,
    p=[0.10, 0.25, 0.40, 0.25]
)
sessions_map = {"power": (15,30), "regular": (6,14), "casual": (2,5), "low": (1,2)}

users_df = pd.DataFrame({
    "user_id":     user_ids,
    "signup_date": signup_dates,
    "city":        np.random.choice(CITIES,   TOTAL_USERS, p=CITY_WEIGHTS),
    "device_type": np.random.choice(DEVICES,  TOTAL_USERS, p=DEVICE_WEIGHTS),
    "channel":     np.random.choice(CHANNELS, TOTAL_USERS, p=CHANNEL_WEIGHTS),
    "age_bucket":  np.random.choice(AGE_BUCKETS, TOTAL_USERS, p=AGE_WEIGHTS),
    "user_type":   user_types,
})

# ── 2. SESSIONS + EVENTS ────────────────────────────────
print("Generating sessions and events (this takes ~60-90 seconds)...")

all_sessions = []
all_events   = []
all_orders   = []

event_id_counter = 1
order_id_counter = 1
session_id_counter = 1

RESTAURANTS = [f"R{str(i).zfill(4)}" for i in range(1, 501)]
ITEMS       = [f"ITEM{str(i).zfill(5)}" for i in range(1, 2001)]

for idx, row in users_df.iterrows():
    uid          = row["user_id"]
    signup_dt    = row["signup_date"]
    utype        = row["user_type"]
    city         = row["city"]
    device       = row["device_type"]

    lo, hi       = sessions_map[utype]
    num_sessions = random.randint(lo, hi)

    is_first_order = True

    for s in range(num_sessions):
        # Session timestamp
        sess_start_dt = session_base_time(signup_dt)
        if sess_start_dt is None:
            continue

        # Weekend boost for session activity
        if is_weekend(sess_start_dt):
            pass  # keep as-is, weekend naturally higher due to random spread

        hour        = random.choices(
            range(24),
            weights=[1,1,1,1,1,1,2,3,4,4,4,5,6,5,4,4,5,6,7,7,6,5,4,2],
            k=1
        )[0]
        sess_start  = sess_start_dt.replace(hour=hour, minute=random.randint(0,59))
        session_id  = f"S{str(session_id_counter).zfill(8)}"
        session_id_counter += 1

        # Determine funnel depth for this session
        # Power users go deeper
        depth_probs = {
            "power":   [0.05,0.05,0.10,0.10,0.05,0.05,0.60],
            "regular": [0.10,0.12,0.15,0.13,0.10,0.10,0.30],
            "casual":  [0.20,0.20,0.18,0.15,0.10,0.07,0.10],
            "low":     [0.40,0.25,0.15,0.10,0.05,0.03,0.02],
        }
        depth_idx = np.random.choice(range(7), p=depth_probs[utype])
        funnel_events = EVENT_ORDER[:depth_idx + 1]

        current_time = sess_start
        cart_val     = 0.0
        restaurant   = random.choice(RESTAURANTS)

        for ev in funnel_events:
            # Add some seconds between events
            current_time += timedelta(seconds=random.randint(5, 120))

            if ev == "add_to_cart":
                cart_val = round(random.uniform(80, 1200), 2)
            elif ev in ["checkout_initiated","payment_attempted","order_completed"]:
                pass  # cart_val carries over

            all_events.append({
                "event_id":        event_id_counter,
                "session_id":      session_id,
                "user_id":         uid,
                "event_type":      ev,
                "event_timestamp": current_time,
                "restaurant_id":   restaurant if ev in ["restaurant_view","add_to_cart","checkout_initiated","payment_attempted","order_completed"] else None,
                "item_id":         random.choice(ITEMS) if ev == "add_to_cart" else None,
                "cart_value":      cart_val if ev in ["add_to_cart","checkout_initiated","payment_attempted","order_completed"] else None,
                "city":            city,
                "device_type":     device,
            })
            event_id_counter += 1

        sess_end = current_time + timedelta(seconds=random.randint(10, 60))
        all_sessions.append({
            "session_id":   session_id,
            "user_id":      uid,
            "session_start":sess_start,
            "session_end":  sess_end,
            "session_date": sess_start.date(),
        })

        # If funnel completed → create order
        if funnel_events[-1] == "order_completed":
            order_val = round(cart_val * random.uniform(0.95, 1.05), 2)
            all_orders.append({
                "order_id":        f"ORD{str(order_id_counter).zfill(8)}",
                "user_id":         uid,
                "session_id":      session_id,
                "order_date":      sess_start.date(),
                "order_timestamp": current_time,
                "order_value":     order_val,
                "payment_method":  np.random.choice(PAYMENT_METHODS, p=PAYMENT_WEIGHTS),
                "restaurant_id":   restaurant,
                "city":            city,
                "is_first_order":  is_first_order,
            })
            order_id_counter  += 1
            is_first_order     = False

    if idx % 5000 == 0:
        print(f"  {idx}/{TOTAL_USERS} users processed...")

# ── 3. USER SEGMENTS ────────────────────────────────────
print("Generating user segments...")
orders_df = pd.DataFrame(all_orders)
segments_list = []

for month_offset in range(6):
    month_start = START_DATE + timedelta(days=30*month_offset)
    month_end   = month_start + timedelta(days=29)
    seg_month   = month_start.date().replace(day=1)

    if len(orders_df) == 0:
        break

    month_orders = orders_df[
        (pd.to_datetime(orders_df["order_date"]) >= month_start) &
        (pd.to_datetime(orders_df["order_date"]) <= month_end)
    ]

    user_stats = month_orders.groupby("user_id").agg(
        orders_30d    = ("order_id","count"),
        avg_order_value = ("order_value","mean"),
        last_order_date = ("order_date","max")
    ).reset_index()

    def assign_segment(r):
        if r["orders_30d"] >= 8:  return "power"
        if r["orders_30d"] >= 4:  return "regular"
        if r["orders_30d"] >= 1:  return "casual"
        return "at_risk"

    user_stats["segment"]      = user_stats.apply(assign_segment, axis=1)
    user_stats["segment_month"]= seg_month
    segments_list.append(user_stats)

segments_df = pd.concat(segments_list, ignore_index=True) if segments_list else pd.DataFrame()

# ── 4. SAVE TO CSV ───────────────────────────────────────
print("Saving CSVs...")

users_export = users_df.drop(columns=["user_type"])
users_export.to_csv(f"{OUTPUT_DIR}/users.csv", index=False)

pd.DataFrame(all_sessions).to_csv(f"{OUTPUT_DIR}/sessions.csv", index=False)
pd.DataFrame(all_events).to_csv(f"{OUTPUT_DIR}/events.csv", index=False)
orders_df.to_csv(f"{OUTPUT_DIR}/orders.csv", index=False)

if len(segments_df) > 0:
    segments_df.to_csv(f"{OUTPUT_DIR}/user_segments.csv", index=False)

print("\n✅ DONE! Files saved in /data folder:")
for f in ["users","sessions","events","orders","user_segments"]:
    path = f"{OUTPUT_DIR}/{f}.csv"
    if os.path.exists(path):
        df = pd.read_csv(path)
        print(f"  {f}.csv — {len(df):,} rows")
