-- Project C: Product & Funnel Analytics
-- Views: Funnel, Retention, Cohort, DAU, Segmentation, Cart Abandonment
-- Author: Akshit Sharma

USE project_funnel_analytics;

-- View 1: Funnel Analysis
CREATE VIEW vw_funnel_analysis AS
SELECT
    event_type,
    COUNT(DISTINCT user_id) AS total_users,
    ROUND(COUNT(DISTINCT user_id) * 100.0 /
        FIRST_VALUE(COUNT(DISTINCT user_id))
        OVER (ORDER BY FIELD(event_type,
            'app_open','search','restaurant_view',
            'add_to_cart','checkout_initiated',
            'payment_attempted','order_completed')),2) AS conversion_rate_pct,
    ROUND(COUNT(DISTINCT user_id) * 100.0 /
        LAG(COUNT(DISTINCT user_id)) OVER
        (ORDER BY FIELD(event_type,
            'app_open','search','restaurant_view',
            'add_to_cart','checkout_initiated',
            'payment_attempted','order_completed')),2) AS step_drop_off_pct
FROM events
GROUP BY event_type
ORDER BY FIELD(event_type,
    'app_open','search','restaurant_view',
    'add_to_cart','checkout_initiated',
    'payment_attempted','order_completed');

-- View 2: DAU / WAU / MAU
CREATE VIEW vw_dau_wau_mau AS
SELECT
    DATE(event_timestamp) AS activity_date,
    COUNT(DISTINCT user_id) AS DAU,
    COUNT(DISTINCT CASE
        WHEN event_timestamp >= DATE_SUB(DATE(event_timestamp), INTERVAL 6 DAY)
        THEN user_id END) AS WAU,
    COUNT(DISTINCT CASE
        WHEN MONTH(event_timestamp) = MONTH(DATE(event_timestamp))
        AND YEAR(event_timestamp) = YEAR(DATE(event_timestamp))
        THEN user_id END) AS MAU
FROM events
GROUP BY DATE(event_timestamp)
ORDER BY activity_date;

-- View 3: Retention Analysis
CREATE VIEW vw_retention_analysis AS
WITH cohort_base AS (
    SELECT
        user_id,
        DATE(MIN(event_timestamp)) AS first_seen_date,
        DATE_FORMAT(MIN(event_timestamp), '%Y-%m-01') AS cohort_month
    FROM events
    GROUP BY user_id
),
user_activity AS (
    SELECT
        e.user_id,
        cb.cohort_month,
        TIMESTAMPDIFF(WEEK, cb.first_seen_date, DATE(e.event_timestamp)) AS week_number
    FROM events e
    JOIN cohort_base cb ON e.user_id = cb.user_id
)
SELECT
    cohort_month,
    week_number,
    COUNT(DISTINCT user_id) AS active_users,
    ROUND(COUNT(DISTINCT user_id) * 100.0 /
        FIRST_VALUE(COUNT(DISTINCT user_id))
        OVER (PARTITION BY cohort_month
              ORDER BY week_number), 2) AS retention_rate_pct
FROM user_activity
WHERE week_number BETWEEN 0 AND 4
GROUP BY cohort_month, week_number
ORDER BY cohort_month, week_number;

-- View 4: Cohort Analysis
CREATE VIEW vw_cohort_analysis AS
WITH cohort_base AS (
    SELECT
        user_id,
        DATE_FORMAT(signup_date, '%Y-%m-01') AS cohort_month
    FROM users
),
cohort_orders AS (
    SELECT
        cb.cohort_month,
        DATE_FORMAT(o.order_date, '%Y-%m-01') AS order_month,
        COUNT(DISTINCT o.user_id) AS active_users
    FROM orders o
    JOIN cohort_base cb ON o.user_id = cb.user_id
    GROUP BY cb.cohort_month, order_month
)
SELECT
    cohort_month,
    order_month,
    active_users,
    ROUND(active_users * 100.0 /
        FIRST_VALUE(active_users)
        OVER (PARTITION BY cohort_month
              ORDER BY order_month), 2) AS retention_pct
FROM cohort_orders
ORDER BY cohort_month, order_month;

-- View 5: User Segmentation
CREATE VIEW vw_user_segmentation AS
SELECT
    u.user_id,
    u.city,
    u.device_type,
    u.channel,
    u.age_bucket,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(AVG(o.order_value), 2) AS avg_order_value,
    ROUND(SUM(o.order_value), 2) AS total_revenue,
    MAX(o.order_date) AS last_order_date,
    DATEDIFF(CURDATE(), MAX(o.order_date)) AS days_since_last_order,
    CASE
        WHEN COUNT(DISTINCT o.order_id) >= 8 THEN 'Power'
        WHEN COUNT(DISTINCT o.order_id) >= 4 THEN 'Regular'
        WHEN COUNT(DISTINCT o.order_id) >= 1 THEN 'Casual'
        ELSE 'Churned'
    END AS user_segment
FROM users u
LEFT JOIN orders o ON u.user_id = o.user_id
GROUP BY u.user_id, u.city, u.device_type, u.channel, u.age_bucket
ORDER BY total_revenue DESC;

-- View 6: Cart Abandonment
CREATE VIEW vw_cart_abandonment AS
WITH session_funnel AS (
    SELECT
        session_id,
        user_id,
        MAX(CASE WHEN event_type = 'add_to_cart'        THEN 1 ELSE 0 END) AS reached_cart,
        MAX(CASE WHEN event_type = 'checkout_initiated' THEN 1 ELSE 0 END) AS reached_checkout,
        MAX(CASE WHEN event_type = 'payment_attempted'  THEN 1 ELSE 0 END) AS reached_payment,
        MAX(CASE WHEN event_type = 'order_completed'    THEN 1 ELSE 0 END) AS completed_order,
        MAX(cart_value) AS cart_value
    FROM events
    GROUP BY session_id, user_id
)
SELECT
    COUNT(*) AS total_sessions,
    SUM(reached_cart) AS added_to_cart,
    SUM(reached_checkout) AS reached_checkout,
    SUM(reached_payment) AS reached_payment,
    SUM(completed_order) AS completed_order,
    SUM(CASE WHEN reached_cart = 1 AND completed_order = 0 THEN 1 ELSE 0 END) AS abandoned_sessions,
    ROUND(SUM(CASE WHEN reached_cart = 1 AND completed_order = 0 THEN 1 ELSE 0 END) * 100.0
        / NULLIF(SUM(reached_cart), 0), 2) AS abandonment_rate_pct,
    ROUND(AVG(CASE WHEN reached_cart = 1 AND completed_order = 0 THEN cart_value END), 2) AS avg_abandoned_cart_value
FROM session_funnel;