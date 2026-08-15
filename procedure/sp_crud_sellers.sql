USE assignment1;

-- Checking
SHOW CREATE PROCEDURE sp_seller_create;
SHOW CREATE PROCEDURE sp_seller_retrieve;
SHOW CREATE PROCEDURE sp_seller_update;

-- CRUD for seller table
DROP PROCEDURE IF EXISTS sp_seller_create;
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
    -- generate 32 character unique MD5 String
    SET v_new_id = MD5(UUID());

    START TRANSACTION;
    SAVEPOINT sv_create;

    -- LOCK TABLES sellers WRITE;
    INSERT INTO sellers (
        seller_id, seller_zip_code_prefix, seller_city, seller_state
    ) VALUES (
        v_new_id, p_zip_code, p_city, p_state 
    );
    COMMIT;

    -- UNLOCK TABLES;
    
    SELECT v_new_id AS 'Successfully Registered Seller ID';
END$$
DELIMITER ;

-- retrieve seller
DROP PROCEDURE IF EXISTS  sp_seller_retrieve;
DELIMITER $$
CREATE PROCEDURE sp_seller_retrieve(
    IN p_partial_id VARCHAR(32),
    IN p_state VARCHAR(2)
)
COMMENT 'Retrieve sellers';
BEGIN
    -- LOCK TABLES sellers READ;
    SELECT seller_id, seller_zip_code_prefix, seller_city, seller_state
    FROM sellers
    WHERE (p_partial_id IS NULL OR seller_id LIKE CONCAT('%', p_partial_id, '%'))
        AND (p_state IS NULL OR seller_state = p_state);
    -- UNLOCK TABLES;
END$$
DELIMITER ;

-- update seller
DROP PROCEDURE IF EXISTS  sp_seller_update;
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

    START TRANSACTION;
    SAVEPOINT sv_update;

    UPDATE sellers
    SET seller_city = COALESCE(p_new_city, seller_city),
        seller_state = COALESCE(p_new_state, seller_state)
    WHERE seller_id = p_seller_id;

    IF t_error = 1 THEN
        ROLLBACK TO SAVEPOINT sv_update;
        SELECT 'ERROR encountered during transaction. Rollback executed.' AS Status;
    ELSE
        COMMIT;
        SELECT * FROM sellers WHERE seller_id = p_seller_id;
    END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE sp_seller_update(
    IN p_seller_id VARCHAR(32),
    IN p_new_zip_code VARCHAR(10),
    IN p_new_city VARCHAR(100),
    IN p_new_state VARCHAR(2)
)
COMMENT 'Update seller metrics'
BEGIN
    DECLARE t_error INT DEFAULT 0;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET t_error = 1;

    START TRANSACTION;
    -- This prevents a "lost update" race condition if two admins try updating the same seller simultaneously.
    IF EXISTS (SELECT 1 FROM sellers WHERE seller_id = p_seller_id FOR UPDATE) THEN
        -- 2. Execute Update (Fixed: seller_zip_code_prefix is now included)
        UPDATE sellers
        SET seller_zip_code_prefix = COALESCE(p_new_zip_code, seller_zip_code_prefix),
            seller_city = COALESCE(p_new_city, seller_city),
            seller_state = COALESCE(p_new_state, seller_state)
        WHERE seller_id = p_seller_id;

        -- 3. Verify execution safety
        IF t_error = 1 THEN
            ROLLBACK;
            SELECT 'ERROR: Data anomaly or truncation encountered during update. Transaction rolled back.' AS Status;
        ELSE
            COMMIT;
            -- Return the newly updated state of the record
            SELECT * FROM sellers WHERE seller_id = p_seller_id;
        END IF;
        
    ELSE
        ROLLBACK;
        SELECT 'ERROR: Update target failed. Seller ID does not exist.' AS Status;
    END IF;
END$$
DELIMITER ;


DROP PROCEDURE IF EXISTS sp_seller_delete;
DELIMITER $$
CREATE PROCEDURE sp_seller_delete(
    IN p_seller_id VARCHAR(32)
)
COMMENT 'Delete an existing seller safely with concurrency safety'
BEGIN
    DECLARE t_error INT DEFAULT 0;
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET t_error = 1;

    START TRANSACTION;    
    -- Lock the target row exclusively to prevent other sessions from modifying/deleting it concurrently
    IF EXISTS (SELECT 1 FROM sellers WHERE seller_id = p_seller_id FOR UPDATE) THEN        
        DELETE FROM sellers WHERE seller_id = p_seller_id;
        -- Evaluate transaction safety status
        IF t_error = 1 THEN
            ROLLBACK;
            SELECT 'ERROR: Structural constraints violated. Seller may be linked to active order items. Rollback executed.' AS Status;
        ELSE
            COMMIT;
            SELECT CONCAT('SUCCESS: Seller ID ', p_seller_id, ' successfully removed.') AS Status;
        END IF;
    ELSE
        -- Row did not exist to begin with
        ROLLBACK;
        SELECT 'ERROR: Target Seller ID not found. No operation performed.' AS Status;
    END IF;
END$$
DELIMITER ;



------------------------------------------------------------------------------ 
-- Testing
-- Simulate prompt inputs
SET @city  = 'São Paulo';
SET @state = 'SP';
SET @zip   = 01001;

-- Call creation. It will output a 32-character ID hash string.
CALL sp_seller_create(@zip, @city, @state);

-- Find sellers located within a specific state
CALL sp_seller_retrieve(NULL, 'SP');

-- Find a specific seller by just typing part of their hash string
CALL sp_seller_retrieve('a1b2c3', NULL);

-- Simulate user picking the primary key and changing the city
SET @target_pk = 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6'; -- Use the hash from step A
SET @new_city  = 'Campinas';

CALL sp_seller_update(@target_pk, @new_city, NULL);