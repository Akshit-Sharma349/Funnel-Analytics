-- Project C: Product & Funnel Analytics
-- Analysis Queries: Funnel, Retention, Cohort, Segmentation
-- Author: Akshit Sharma

USE project_funnel_analytics;

-- 1. Overall funnel drop-off
SELECT event_type, total_users, conversion_rate_pct, step_drop_off_pct
FROM vw_funnel_analysis;

-- 2. Top 3 drop-off steps
SELECT event_type, step_drop_off_pct
FROM vw_funnel_analysis
WHERE step_drop_off_pct IS NOT NULL
ORDER BY step_drop_off_pct DESC
LIMIT 3;

-- 3. DAU trend last 30 days
SELECT activity_date, DAU
FROM vw_dau_wau_mau
ORDER BY activity_date DESC
LIMIT 30;

-- 4. Weekly retention by cohort
SELECT cohort_month, week_number, retention_rate_pct
FROM vw_retention_analysis
ORDER BY cohort_month, week_number;

-- 5. Cohort with highest week 4 retention
SELECT cohort_month, retention_rate_pct
FROM vw_retention_analysis
WHERE week_number = 4
ORDER BY retention_rate_pct DESC
LIMIT 1;

-- 6. Revenue by user segment
SELECT user_segment, COUNT(user_id) AS total_users,
    ROUND(SUM(total_revenue), 2) AS segment_revenue,
    ROUND(AVG(avg_order_value), 2) AS avg_order_value
FROM vw_user_segmentation
GROUP BY user_segment
ORDER BY segment_revenue DESC;

-- 7. Top 5 cities by orders
SELECT city, COUNT(order_id) AS total_orders,
    ROUND(SUM(order_value), 2) AS total_revenue
FROM orders
GROUP BY city
ORDER BY total_orders DESC
LIMIT 5;

-- 8. Payment method breakdown
SELECT payment_method, COUNT(order_id) AS total_orders,
    ROUND(COUNT(order_id) * 100.0 / SUM(COUNT(order_id)) OVER(), 2) AS pct_share
FROM orders
GROUP BY payment_method
ORDER BY total_orders DESC;

-- 9. Cart abandonment summary
SELECT total_sessions, added_to_cart, completed_order,
    abandonment_rate_pct, avg_abandoned_cart_value
FROM vw_cart_abandonment;

-- 10. New vs repeat orders
SELECT
    CASE WHEN is_first_order = 1 THEN 'New' ELSE 'Repeat' END AS order_type,
    COUNT(order_id) AS total_orders,
    ROUND(AVG(order_value), 2) AS avg_order_value
FROM orders
GROUP BY is_first_order;

-- 11. Monthly revenue trend
SELECT DATE_FORMAT(order_date, '%Y-%m') AS month,
    COUNT(order_id) AS total_orders,
    ROUND(SUM(order_value), 2) AS total_revenue
FROM orders
GROUP BY month
ORDER BY month;

-- 12. Conversion rate by acquisition channel
SELECT u.channel,
    COUNT(DISTINCT u.user_id) AS total_users,
    COUNT(DISTINCT o.user_id) AS converted_users,
    ROUND(COUNT(DISTINCT o.user_id) * 100.0 / COUNT(DISTINCT u.user_id), 2) AS conversion_rate_pct
FROM users u
LEFT JOIN orders o ON u.user_id = o.user_id
GROUP BY u.channel
ORDER BY conversion_rate_pct DESC;

-- 13. Power users behavior
SELECT u.user_id, u.city, u.channel,
    COUNT(o.order_id) AS total_orders,
    ROUND(SUM(o.order_value), 2) AS total_spent
FROM users u
JOIN orders o ON u.user_id = o.user_id
GROUP BY u.user_id, u.city, u.channel
HAVING total_orders >= 8
ORDER BY total_spent DESC
LIMIT 20;

-- 14. Device type performance
SELECT e.device_type,
    COUNT(DISTINCT e.user_id) AS total_users,
    COUNT(DISTINCT o.user_id) AS converted_users,
    ROUND(COUNT(DISTINCT o.user_id) * 100.0 / COUNT(DISTINCT e.user_id), 2) AS conversion_rate_pct
FROM events e
LEFT JOIN orders o ON e.user_id = o.user_id
GROUP BY e.device_type
ORDER BY conversion_rate_pct DESC;

-- 15. Churned users (no order in last 60 days)
SELECT COUNT(user_id) AS churned_users
FROM vw_user_segmentation
WHERE days_since_last_order > 60
   OR last_order_date IS NULL;