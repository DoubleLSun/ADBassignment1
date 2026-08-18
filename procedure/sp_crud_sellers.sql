USE assignment1;

-- Checking
SHOW CREATE PROCEDURE sp_seller_create;
SHOW CREATE PROCEDURE sp_seller_retrieve;
SHOW CREATE PROCEDURE sp_seller_update;
SHOW CREATE PROCEDURE sp_seller_delete;

DROP PROCEDURE IF EXISTS sp_seller_create;
DROP PROCEDURE IF EXISTS sp_seller_retrieve;
DROP PROCEDURE IF EXISTS sp_seller_update;
DROP PROCEDURE IF EXISTS sp_seller_delete;

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