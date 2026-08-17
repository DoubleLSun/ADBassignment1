-- change state to full capitals
DELIMITER $$
CREATE TRIGGER trg_bi_customers
BEFORE INSERT
ON customers
FOR EACH ROW
BEGIN
    SET NEW.customer_state = UPPER(NEW.customer_state);
END$$
DELIMITER ;

-- Put insert logs into audit_log
DELIMITER $$
CREATE TRIGGER trg_ai_customers
AFTER INSERT
ON customers
FOR EACH ROW
BEGIN
	INSERT INTO audit_log(
	at_table,
    action_desc,
    action_date
    )
	VALUES (
		"customers",
        CONCAT("Added customer with id: ", NEW.customer_id),
        NOW()
	);
END$$
DELIMITER ;

-- test INSERT triggers
INSERT INTO customers(
	customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
)
VALUES(
	"666666",
    "666666",
    "666666",
    "test city",
    "tc"
);
SELECT * FROM audit_log WHERE at_table = "customers";
SELECT * FROM customers WHERE customer_id = "666666";
    


-- check if unique id will be empty on update
-- check if location field will be updated but some of them is null/empty
DELIMITER $$
CREATE TRIGGER trg_bu_customers
BEFORE UPDATE
ON customers
FOR EACH ROW
BEGIN
	IF NEW.customer_unique_id IS NULL THEN
		SIGNAL SQLSTATE "45000"
		SET MESSAGE_TEXT = "Update to unique ID cannot be empty";
	END IF;
    IF OLD.customer_zip_code_prefix != NEW.customer_zip_code_prefix
    OR OLD.customer_city != NEW.customer_city
    OR OLD.customer_state != NEW.customer_state THEN
		IF NEW.customer_zip_code_prefix IS NULL
        OR NEW.customer_city IS NULL
        OR NEW.customer_state IS NULL THEN
			SIGNAL SQLSTATE "45000"
			SET MESSAGE_TEXT = "Update to geolocation fields cannot be partially empty";
		END IF;
	END IF;
	SET NEW.customer_state = UPPER(NEW.customer_state);
END$$
DELIMITER ;



-- put update logs into audit_log
DELIMITER $$
CREATE TRIGGER trg_au_customers
AFTER UPDATE
ON customers
FOR EACH ROW
BEGIN
	DECLARE id_msg VARCHAR(255) DEFAULT NULL;
    DECLARE location_msg VARCHAR(255) DEFAULT NULL;
	IF OLD.customer_unique_id != NEW.customer_unique_id THEN
			SET id_msg = CONCAT("Updated unique id: ", OLD.customer_id);
	END IF;
    IF OLD.customer_zip_code_prefix != NEW.customer_zip_code_prefix
	OR OLD.customer_city != NEW.customer_city
    OR OLD.customer_state != NEW.customer_state THEN
		SET location_msg = CONCAT("Updated location: ",NEW.customer_zip_code_prefix,",",NEW.customer_city,",",NEW.customer_state);
	END IF;
    
	INSERT INTO audit_log(at_table, action_desc, action_date)
	VALUES (
		"customers",
		CONCAT_WS(",", "Updated on ID ", OLD.customer_id, ": ", id_msg, location_msg),
		NOW()
	);
END$$
DELIMITER ;

-- test UPDATE triggers
UPDATE customers
SET customer_unique_id = NULL
WHERE customer_id = "666666";

UPDATE customers
SET customer_unique_id = "777777",
	customer_zip_code_prefix = "666666",
    customer_city = "testing city",
    customer_state = NULL
WHERE customer_id = "666666";

UPDATE customers
SET customer_unique_id = "777777",
	customer_zip_code_prefix = "666666",
    customer_city = "testing city",
    customer_state = "tt"
WHERE customer_id = "666666";

SELECT * FROM audit_log WHERE at_table = "customers";
SELECT * FROM customers WHERE customer_id = "666666";

-- put delete logs into audit_log
DELIMITER $$
CREATE TRIGGER trg_ad_customers
AFTER DELETE
ON customers
FOR EACH ROW
BEGIN
	INSERT INTO audit_log(
	at_table,
    action_desc,
    action_date
    )
	VALUES (
		"customers",
        CONCAT("Deleted customer with the id: ", OLD.customer_id),
        NOW()
	);
END$$
DELIMITER ;

-- test DELETE trigger
DELETE FROM customers
WHERE customer_id = "666666";
SELECT * FROM audit_log WHERE at_table = "customers";
SELECT * FROM customers WHERE customer_id = "666666";