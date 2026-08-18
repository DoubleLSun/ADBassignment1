USE assignment1;
SHOW TABLES;
-- List all stored procedure
SHOW PROCEDURE STATUS;
-- List stored procedure in specific DB
SHOW PROCEDURE STATUS WHERE db='assignment1';
-- List stored procedures with names containing 'Order'
SHOW PROCEDURE STATUS LIKE '%seller%';
SHOW CREATE PROCEDURE sp_seller_create;
-- information_schema routines table method
SELECT ROUTINE_DEFINITION
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_SCHEMA = 'assignment1' AND ROUTINE_TYPE='PROCEDURE';

-- Consider using TRIGGER to record procedure call

-- Checking
SHOW CREATE PROCEDURE sp_seller_create;
SHOW CREATE PROCEDURE sp_seller_retrieve;
SHOW CREATE PROCEDURE sp_seller_update;
SHOW CREATE PROCEDURE sp_seller_delete;
SHOW CREATE PROCEDURE sp_prepare_category_revenue_metrics;
SHOW CREATE PROCEDURE sp_filter_category_revenue_metrics;
SHOW CREATE PROCEDURE sp_prepare_payment_metrics;
SHOW CREATE PROCEDURE sp_prepare_location_revenue_metrics;
SHOW CREATE PROCEDURE sp_prepare_seller_revenue_metrics;
SHOW CREATE PROCEDURE sp_shipping_delay_data;
SHOW CREATE PROCEDURE sp_prepare_sentiment_metrics;

-- remove before adding it back
DROP PROCEDURE IF EXISTS sp_seller_create;
DROP PROCEDURE IF EXISTS sp_seller_retrieve;
DROP PROCEDURE IF EXISTS sp_seller_update;
DROP PROCEDURE IF EXISTS sp_seller_delete;
DROP PROCEDURE IF EXISTS sp_prepare_category_revenue_metrics;
DROP PROCEDURE IF EXISTS sp_filter_category_revenue_metrics;
DROP PROCEDURE IF EXISTS sp_prepare_payment_metrics;
DROP PROCEDURE IF EXISTS sp_prepare_location_revenue_metrics;
DROP PROCEDURE IF EXISTS sp_prepare_seller_revenue_metrics;
DROP PROCEDURE IF EXISTS sp_shipping_delay_data;
DROP PROCEDURE IF EXISTS sp_prepare_sentiment_metrics;

-- CRUD for seller table
-- Create order
DELIMITER $$ 
CREATE PROCEDURE sp_seller_create(
    IN p_zip_code VARCHAR(10),
    IN p_city VARCHAR(100),
    IN p_state VARCHAR(2)
)
COMMENT 'Create New Seller'
BEGIN
    -- to hold new seller id hash
    DECLARE v_new_id VARCHAR(32);
    DECLARE t_error INT DEFAULT 0;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET t_error = 1;

    -- generate 32 character unique MD5 String
    SET v_new_id = MD5(UUID());

    -- Input validation    
    -- Zip code prefix must not be empty or null
    IF p_zip_code IS NULL OR TRIM(p_zip_code) = '' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Input Validation Failed: Zip Code prefix cannot be null or empty.';
    END IF;
    -- City name must not be empty or null
    IF p_city IS NULL OR TRIM(p_city) = '' THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Input Validation Failed: City name cannot be null or empty.';
    END IF;
    -- Brazilian State must be exactly 2 characters long (e.g., 'SP', 'RJ')
    IF p_state IS NULL OR LENGTH(TRIM(p_state)) != 2 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Input Validation Failed: State must be a valid 2-character abbreviation (e.g., SP).';
    END IF;

    START TRANSACTION;
    SAVEPOINT sv_create;
    -- LOCK TABLES sellers WRITE;
    INSERT INTO sellers (
        seller_id, seller_zip_code_prefix, seller_city, seller_state
    ) VALUES (
        v_new_id, TRIM(p_zip_code), TRIM(p_city), UPPER(TRIM(p_state)) 
    );
    COMMIT;
    -- UNLOCK TABLES;
    IF t_error = 1 THEN
        -- Part b: ROLLBACK to handle errors and roll back changes
        ROLLBACK TO SAVEPOINT sv_create;
        SELECT 'ERROR: Exception caught during seller creation. Transaction rolled back to savepoint.' AS Status;
    ELSE
        COMMIT;
        SELECT v_new_id AS 'Successfully Registered Seller ID';
    END IF;
END$$
DELIMITER ;

-- retrieve seller
DELIMITER $$
CREATE PROCEDURE sp_seller_retrieve(
    IN p_partial_id VARCHAR(32),
    IN p_state VARCHAR(2)
)
COMMENT 'Retrieve sellers';
BEGIN
    -- Input validation
    IF (p_partial_id IS NOT NULL AND TRIM(p_partial_id) = '') OR (p_state IS NOT NULL AND TRIM(p_state) = '') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation Error: Search fields cannot be empty strings. Pass NULL for open criteria.';
    END IF;
    IF p_state IS NOT NULL AND LENGTH(TRIM(p_state)) != 2 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation Error: State filter criteria must be exactly 2 characters.';
    END IF;
    -- LOCK TABLES sellers READ;
    SELECT seller_id, seller_zip_code_prefix, seller_city, seller_state
    FROM sellers
    WHERE (p_partial_id IS NULL OR seller_id LIKE CONCAT('%', TRIM(p_partial_id), '%'))
        AND (p_state IS NULL OR seller_state = UPPER(TRIM(p_state)));
    -- UNLOCK TABLES;
END$$
DELIMITER ;

-- update seller
DELIMITER $$
CREATE PROCEDURE sp_seller_update(
    IN p_seller_id VARCHAR(32),
    IN p_new_zip_code VARCHAR(10),
    IN p_new_city VARCHAR(100),
    IN p_new_state VARCHAR(2)
)
BEGIN
    DECLARE t_error INT DEFAULT 0;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET t_error = 1;
    -- Input validation
    IF p_seller_id IS NULL OR LENGTH(TRIM(p_seller_id)) != 32 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation Error: Invalid Seller ID. Must be a non-null 32-character hex string.';
    END IF;
    -- Block updating structural information to empty strings
    IF (p_new_zip_code IS NOT NULL AND TRIM(p_new_zip_code) = '') OR 
       (p_new_city IS NOT NULL AND TRIM(p_new_city) = '') OR 
       (p_new_state IS NOT NULL AND TRIM(p_new_state) = '') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation Error: New modification properties cannot be blank text blocks.';
    END IF;

    IF p_new_state IS NOT NULL AND LENGTH(TRIM(p_new_state)) != 2 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation Error: Target modification state code must be exactly 2 characters.';
    END IF;

    START TRANSACTION;
    SAVEPOINT sv_update;

    UPDATE sellers
    SET seller_zip_code_prefix = COALESCE(TRIM(p_new_zip_code), seller_zip_code_prefix),
        seller_city = COALESCE(TRIM(p_new_city), seller_city),
        seller_state = COALESCE(UPPER(TRIM(p_new_state)), seller_state)
    WHERE seller_id = TRIM(p_seller_id);

    IF t_error = 1 THEN
        ROLLBACK TO SAVEPOINT sv_update;
        SELECT 'ERROR encountered during transaction. Rollback executed.' AS Status;
    ELSE
        COMMIT;
        SELECT * FROM sellers WHERE seller_id = TRIM(p_seller_id);
    END IF;
END$$
DELIMITER ;


DELIMITER $$
CREATE PROCEDURE sp_seller_delete(
    IN p_seller_id VARCHAR(32)
)
COMMENT 'Delete an existing seller safely with concurrency safety'
BEGIN
    DECLARE t_error INT DEFAULT 0;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET t_error = 1;

    -- INPUT VALIDATION
    IF p_seller_id IS NULL OR LENGTH(TRIM(p_seller_id)) != 32 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation Error: Deletion halted. Target Seller ID must be exactly 32 characters.';
    END IF;

    START TRANSACTION;    
    SAVEPOINT sv_point;

    DELETE FROM sellers WHERE seller_id = TRIM(p_seller_id);

    IF t_error = 1 THEN
        ROLLBACK TO SAVEPOINT sv_delete;
        SELECT 'ERROR: Cannot delete seller. Row may be locked or linked to foreign keys. Rolled back.' AS Status;
    ELSE
        COMMIT;
        SELECT CONCAT('SUCCESS: Seller ID ', TRIM(p_seller_id), ' successfully removed.') AS Status;
    END IF;
END$$
DELIMITER ;

-- CRUD for orders table
-- create new orders
DELIMITER $$
CREATE PROCEDURE sp_order_create(
    IN p_customer_id VARCHAR(32),
    IN p_estimated_delivery DATE
)
COMMENT 'CRUD: Create New Order with Dependency Verification'
BEGIN
    DECLARE v_new_order_id VARCHAR(32);
    DECLARE t_error INT DEFAULT 0;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET t_error = 1;

    -- INPUT VALIDATION
    IF p_customer_id IS NULL OR LENGTH(TRIM(p_customer_id)) != 32 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation Error: Customer ID must be a non-null 32-character hex hash.';
    END IF;

    IF p_estimated_delivery IS NULL OR p_estimated_delivery < CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation Error: Estimated delivery date cannot be empty or in the past.';
    END IF;

    -- Verify parent record exists before opening transaction memory
    IF NOT EXISTS (SELECT 1 FROM customers WHERE customer_id = TRIM(p_customer_id)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Integrity Error: Provided Customer ID does not exist in the database.';
    END IF;

    SET v_new_order_id = MD5(UUID());

    START TRANSACTION;
    SAVEPOINT sv_order_create;

    INSERT INTO orders (
        order_id, customer_id, order_status, 
        order_purchase_timestamp, order_estimated_delivery_date
    ) VALUES (
        v_new_order_id, TRIM(p_customer_id), 'created', 
        NOW(), p_estimated_delivery
    );

    IF t_error = 1 THEN
        ROLLBACK TO SAVEPOINT sv_order_create;
        SELECT 'ERROR: Exception caught during order instantiation. Changes rolled back.' AS Status;
    ELSE
        COMMIT;
        SELECT v_new_order_id AS 'Successfully Generated Order ID';
    END IF;
END$$
DELIMITER ;

-- retrieve entire order 
DELIMITER $$
CREATE PROCEDURE sp_order_retrieve(
    IN p_order_id VARCHAR(32),
    IN p_status VARCHAR(50)
)
COMMENT 'CRUD: Filter and Retrieve Orders'
BEGIN
    IF (p_order_id IS NOT NULL AND TRIM(p_order_id) = '') OR (p_status IS NOT NULL AND TRIM(p_status) = '') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation Error: Filters cannot be empty text. Pass NULL for open criteria.';
    END IF;

    SELECT order_id, customer_id, order_status, order_purchase_timestamp, order_delivered_customer_date, order_estimated_delivery_date
    FROM orders
    WHERE (p_order_id IS NULL OR order_id = TRIM(p_order_id))
      AND (p_status IS NULL OR order_status = TRIM(p_status))
    LIMIT 100;
END$$
DELIMITER ;
-- CALL sp_order_retrieve(NULL,NULL);

-- update order
DELIMITER $$
CREATE PROCEDURE sp_order_update(
    IN p_order_id VARCHAR(32),
    IN p_new_status VARCHAR(50),
    IN p_delivered_date DATETIME
)
COMMENT 'CRUD: Update Order Logistical States'
BEGIN
    DECLARE t_error INT DEFAULT 0;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET t_error = 1;

    -- INPUT VALIDATION
    IF p_order_id IS NULL OR LENGTH(TRIM(p_order_id)) != 32 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation Error: Targeted Order ID must be exactly 32 characters.';
    END IF;

    START TRANSACTION;
    SAVEPOINT sv_order_update;

    UPDATE orders
    SET order_status = COALESCE(TRIM(p_new_status), order_status),
        order_delivered_customer_date = COALESCE(p_delivered_date, order_delivered_customer_date)
    WHERE order_id = TRIM(p_order_id);

    IF t_error = 1 THEN
        ROLLBACK TO SAVEPOINT sv_order_update;
        SELECT 'ERROR: Exception caught during operational status modification. Rolled back.' AS Status;
    ELSE
        COMMIT;
        SELECT * FROM orders WHERE order_id = TRIM(p_order_id);
    END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE sp_order_delete(
    IN p_order_id VARCHAR(32)
)
COMMENT 'CRUD: Cascading Delete protecting operational data constraints'
BEGIN
    DECLARE t_error INT DEFAULT 0;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET t_error = 1;

    -- INPUT VALIDATION
    IF p_order_id IS NULL OR LENGTH(TRIM(p_order_id)) != 32 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Validation Error: Target deletion hash length is invalid.';
    END IF;

    START TRANSACTION;
    SAVEPOINT sv_order_purge;

    -- Step 1: Wipe downstream relational rows to clear out Foreign Key barriers
    DELETE FROM order_reviews WHERE order_id = TRIM(p_order_id);
    DELETE FROM order_payments WHERE order_id = TRIM(p_order_id);
    DELETE FROM order_items WHERE order_id = TRIM(p_order_id);

    -- Step 2: Now it is mathematically safe to remove the parent tracking entity
    DELETE FROM orders WHERE order_id = TRIM(p_order_id);

    IF t_error = 1 THEN
        ROLLBACK TO SAVEPOINT sv_order_purge;
        SELECT 'ERROR: Structural dependency breakdown encountered. Cascade deletion rolled back.' AS Status;
    ELSE
        COMMIT;
        SELECT CONCAT('SUCCESS: Order ID ', TRIM(p_order_id), ' and all its sub-records purged cleanly.') AS Status;
    END IF;
END$$
DELIMITER ;

-- Stored Procedure for Topic Analysis
DELIMITER $$
CREATE PROCEDURE sp_prepare_category_revenue_metrics()
COMMENT 'Calculate produts sold and revenue for each category'
BEGIN
    DROP TEMPORARY TABLE IF EXISTS tmp_category_revenue_summary;
    
    -- Process the counts and totals entirely within the procedure
    CREATE TEMPORARY TABLE tmp_category_revenue_summary AS
    SELECT 
        p.product_category_name AS Category,
        COUNT(oi.order_id) AS Total_Units_Sold, -- "How many sold"
        SUM(fn_calculate_order_total(oi.price, oi.freight_value)) AS Total_Revenue -- "How much earned"
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    WHERE p.product_category_name IS NOT NULL
    GROUP BY p.product_category_name;    
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE sp_filter_category_revenue_metrics(IN p_category_name VARCHAR(255))
COMMENT 'Calculate produts sold and revenue for specific category'
BEGIN
    DROP TEMPORARY TABLE IF EXISTS tmp_category_revenue_summary;
    
    CREATE TEMPORARY TABLE tmp_category_revenue_summary AS
    SELECT 
        p.product_category_name AS Category,
        COUNT(oi.order_id) AS Total_Units_Sold, -- "How many"
        SUM(fn_calculate_order_total(oi.price, oi.freight_value)) AS Total_Revenue -- "How much"
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    WHERE p.product_category_name IS NOT NULL
      -- If parameter is NULL, it returns TRUE for all rows. Otherwise, it filters exactly.
      AND (p.product_category_name = p_category_name OR p_category_name IS NULL)
    GROUP BY p.product_category_name;
    
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE sp_prepare_payment_metrics(IN p_payment_type VARCHAR(50))
COMMENT 'Infrastructure: Computes popularity and cash flow by payment type with optional filter'
BEGIN
    DROP TEMPORARY TABLE IF EXISTS tmp_payment_metrics_summary;
    -- Pre-calculate transaction popularity (how many) and volume (how much cash flow)
    CREATE TEMPORARY TABLE tmp_payment_metrics_summary AS
    SELECT 
        op.payment_type AS Payment_Type,
        COUNT(op.order_id) AS Total_Transactions,        -- Popularity: "How many times used"
        SUM(op.payment_value) AS Total_Cash_Flow,        -- Financial: "How much money processed"
        AVG(op.payment_installments) AS Avg_Installments -- Behavioral: "Average installment split"
    FROM olist_order_payments op
    WHERE (op.payment_type = p_payment_type OR p_payment_type IS NULL)
    GROUP BY op.payment_type;
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE sp_prepare_location_revenue_metrics(
    IN p_target_state CHAR(2),   -- Optional: filter by state abbreviation (e.g., 'SP')
    IN p_target_city VARCHAR(255) -- Optional: filter by city name (e.g., 'sao paulo')
)
COMMENT 'Computes totals by location with dynamic filters'
BEGIN
    DROP TEMPORARY TABLE IF EXISTS tmp_location_revenue_summary;
    
    CREATE TEMPORARY TABLE tmp_location_revenue_summary AS
    SELECT 
        c.customer_state AS State,
        c.customer_city AS City,
        COUNT(oi.order_id) AS Total_Units_Sold,
        SUM(fn_calculate_order_total(oi.price, oi.freight_value)) AS Total_Revenue
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE (c.customer_state = p_target_state OR p_target_state IS NULL)
      AND (c.customer_city = p_target_city OR p_target_city IS NULL)
    GROUP BY c.customer_state, c.customer_city;
    
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE sp_prepare_seller_revenue_metrics(IN p_seller_id VARCHAR(50))
COMMENT 'Computes totals by seller ID with an optional filter'
BEGIN
    DROP TEMPORARY TABLE IF EXISTS tmp_seller_revenue_summary;
    
    CREATE TEMPORARY TABLE tmp_seller_revenue_summary AS
    SELECT 
        oi.seller_id AS Seller_ID,
        s.seller_state AS Seller_State,
        s.seller_city AS Seller_City,
        COUNT(oi.order_id) AS Total_Units_Sold,
        SUM(fn_calculate_order_total(oi.price, oi.freight_value)) AS Total_Revenue
    FROM order_items oi
    JOIN sellers s ON oi.seller_id = s.seller_id
    WHERE (oi.seller_id = p_seller_id OR p_seller_id IS NULL)
    GROUP BY oi.seller_id, s.seller_state, s.seller_city;
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE sp_shipping_delay_data(IN p_min_delay_days INT)
COMMENT 'Create temporary table of orders that are delayed'
BEGIN
    -- Drop the session temp table if it already exists 
    DROP TEMPORARY TABLE IF EXISTS tmp_shipping_delays;
    
    CREATE TEMPORARY TABLE tmp_shipping_delays AS
    SELECT 
        o.order_id,
        o.customer_id,
        c.customer_state,
        c.customer_city,
        o.order_purchase_timestamp,
        fn_calculate_delivery_delay(o.order_estimated_delivery_date, o.order_delivered_customer_date) AS days_late
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
      AND fn_calculate_delivery_delay(o.order_estimated_delivery_date, o.order_delivered_customer_date) >= p_min_delay_days; 
END$$
DELIMITER ;

-- product sentiment distributions 
DELIMITER $$
CREATE PROCEDURE sp_prepare_sentiment_metrics(
    IN p_min_review_count INT
)
COMMENT 'Product sentiment data'
BEGIN
    DROP TEMPORARY TABLE IF EXISTS tmp_sentiment_metrics_summary;
    
    CREATE TEMPORARY TABLE tmp_sentiment_metrics_summary AS
    SELECT * FROM (
        SELECT 
            p.product_category_name AS Category,
            SUM(CASE WHEN fn_get_review_sentiment(r.review_score) = 'Positive' THEN 1 ELSE 0 END) AS Positive_Review_Count,
            SUM(CASE WHEN fn_get_review_sentiment(r.review_score) = 'Negative' THEN 1 ELSE 0 END) AS Negative_Review_Count,
            COUNT(r.review_id) AS Total_Review_Count,
            ROUND(AVG(r.review_score), 2) AS Avg_Review_Score
        FROM order_reviews r
        JOIN order_items oi ON r.order_id = oi.order_id
        JOIN products p ON oi.product_id = p.product_id
        WHERE p.product_category_name IS NOT NULL
        GROUP BY p.product_category_name
    ) AS raw_totals
    -- filter out products with less review
    WHERE raw_totals.Total_Review_Count >= COALESCE(p_min_review_count, 1);
    
END$$
DELIMITER ;
