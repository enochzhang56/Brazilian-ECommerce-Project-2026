/* Brazilian E-Commerce Project SQL Code */ 

-- Data downloaded from Kaggle: https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce

CREATE SCHEMA brazilian_commerce_project;

-- Claude Assisted Table Creation -- 

CREATE TABLE customers (                -- olist_customers_dataset.csv
    customer_id              VARCHAR(32) PRIMARY KEY,   -- one per order
    customer_unique_id       VARCHAR(32) NOT NULL,      -- the real person
    customer_zip_code_prefix INT,
    customer_city            VARCHAR(100),
    customer_state           CHAR(2)
);

CREATE TABLE sellers (                  -- olist_sellers_dataset.csv
    seller_id              VARCHAR(32) PRIMARY KEY,
    seller_zip_code_prefix INT,
    seller_city            VARCHAR(100),
    seller_state           CHAR(2)
);

CREATE TABLE products (                 -- olist_products_dataset.csv
    product_id                 VARCHAR(32) PRIMARY KEY,
    product_category_name      VARCHAR(100),
    product_name_lenght        INT,      -- misspelled in the source file; kept so the import maps cleanly
    product_description_lenght INT,
    product_photos_qty         INT,
    product_weight_g           INT,
    product_length_cm          INT,
    product_height_cm          INT,
    product_width_cm           INT
);

CREATE TABLE product_category_translation (   -- product_category_name_translation.csv
    product_category_name         VARCHAR(100) PRIMARY KEY,
    product_category_name_english VARCHAR(100)
);

CREATE TABLE geolocation (              -- olist_geolocation_dataset.csv
    geolocation_zip_code_prefix INT,    -- no PK: zip prefixes repeat many times
    geolocation_lat             NUMERIC(18,15),
    geolocation_lng             NUMERIC(18,15),
    geolocation_city            VARCHAR(100),
    geolocation_state           CHAR(2)
);

CREATE TABLE orders (                   -- olist_orders_dataset.csv
    order_id                      VARCHAR(32) PRIMARY KEY,
    customer_id                   VARCHAR(32) NOT NULL,
    order_status                  VARCHAR(20),
    order_purchase_timestamp      TIMESTAMP,
    order_approved_at             TIMESTAMP,
    order_delivered_carrier_date  TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);

CREATE TABLE order_items (               -- olist_order_items_dataset.csv
    order_id            VARCHAR(32) NOT NULL,
    order_item_id       INT NOT NULL,
    product_id          VARCHAR(32) NOT NULL,
    seller_id           VARCHAR(32) NOT NULL,
    shipping_limit_date TIMESTAMP,
    price               NUMERIC(10,2),
    freight_value       NUMERIC(10,2),
    PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE order_payments (            -- olist_order_payments_dataset.csv
    order_id             VARCHAR(32) NOT NULL,
    payment_sequential   INT NOT NULL,
    payment_type         VARCHAR(20),
    payment_installments INT,
    payment_value        NUMERIC(10,2),
    PRIMARY KEY (order_id, payment_sequential)
);

CREATE TABLE order_reviews (             -- olist_order_reviews_dataset.csv
    review_id               VARCHAR(32) NOT NULL,   -- no PK: review_id repeats in the source data
    order_id                VARCHAR(32) NOT NULL,
    review_score            INT,
    review_comment_title    TEXT,
    review_comment_message  TEXT,
    review_creation_date    TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);

-- Imported Data

ALTER TABLE orders       ADD FOREIGN KEY (customer_id) REFERENCES customers(customer_id);
ALTER TABLE order_items  ADD FOREIGN KEY (order_id)    REFERENCES orders(order_id);
ALTER TABLE order_items  ADD FOREIGN KEY (product_id)  REFERENCES products(product_id);
ALTER TABLE order_items  ADD FOREIGN KEY (seller_id)   REFERENCES sellers(seller_id);
ALTER TABLE order_payments ADD FOREIGN KEY (order_id)  REFERENCES orders(order_id);
ALTER TABLE order_reviews  ADD FOREIGN KEY (order_id)  REFERENCES orders(order_id);


