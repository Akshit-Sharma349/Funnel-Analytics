-- Project C: Product & Funnel Analytics
-- Database: project_funnel_analytics
-- Author: Akshit Sharma

CREATE DATABASE IF NOT EXISTS project_funnel_analytics;
USE project_funnel_analytics;

CREATE TABLE users (
    user_id      VARCHAR(20) PRIMARY KEY,
    signup_date  DATE,
    city         VARCHAR(50),
    device_type  VARCHAR(20),
    channel      VARCHAR(30),
    age_bucket   VARCHAR(10)
);

CREATE TABLE sessions (
    session_id    VARCHAR(30) PRIMARY KEY,
    user_id       VARCHAR(20),
    session_start DATETIME,
    session_end   DATETIME,
    session_date  DATE
);

CREATE TABLE events (
    event_id        BIGINT PRIMARY KEY,
    session_id      VARCHAR(30),
    user_id         VARCHAR(20),
    event_type      VARCHAR(40),
    event_timestamp DATETIME,
    restaurant_id   VARCHAR(20),
    item_id         VARCHAR(20),
    cart_value      DECIMAL(8,2),
    city            VARCHAR(50),
    device_type     VARCHAR(20)
);

CREATE TABLE orders (
    order_id        VARCHAR(30) PRIMARY KEY,
    user_id         VARCHAR(20),
    session_id      VARCHAR(30),
    order_date      DATE,
    order_timestamp DATETIME,
    order_value     DECIMAL(8,2),
    payment_method  VARCHAR(20),
    restaurant_id   VARCHAR(20),
    city            VARCHAR(50),
    is_first_order  TINYINT(1)
);

CREATE TABLE user_segments (
    user_id         VARCHAR(20),
    segment_month   DATE,
    segment         VARCHAR(20),
    orders_30d      INT,
    avg_order_value DECIMAL(8,2),
    last_order_date DATE
);
