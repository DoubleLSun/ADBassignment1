USE assignment1;

SHOW CREATE PROCEDURE sp_order_create;
SHOW CREATE PROCEDURE sp_order_retrieve;
SHOW CREATE PROCEDURE sp_order_update;
SHOW CREATE PROCEDURE sp_order_delete;

DROP PROCEDURE IF EXISTS sp_order_create;
DROP PROCEDURE IF EXISTS sp_order_retrieve;
DROP PROCEDURE IF EXISTS sp_order_update;
DROP PROCEDURE IF EXISTS sp_order_delete;

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
