-- change state to all capital letters
DELIMITER $$
CREATE TRIGGER trg_bi_sellers
BEFORE INSERT 
ON sellers
FOR EACH ROW
BEGIN
    SET NEW.seller_state = UPPER(NEW.seller_state);
END$$
DELIMITER ;


-- put insert logs into audit log
DELIMITER $$
CREATE TRIGGER trg_ai_sellers
AFTER INSERT ON sellers
FOR EACH ROW
BEGIN
    INSERT INTO audit_log(
    at_table, 
    action_desc, 
    action_date)
    VALUES (
    'sellers', 
    CONCAT('Added new seller: ', NEW.seller_id), 
    NOW());
END$$
DELIMITER ;


-- test INSERT triggers
INSERT INTO sellers (seller_id, seller_zip_code_prefix, seller_city, seller_state)
VALUES ('test_seller_1', '90210', 'beverly hills', 'ca');

SELECT * FROM sellers WHERE seller_id = 'test_seller_1';
SELECT * FROM audit_log WHERE at_table = 'sellers' ORDER BY log_id DESC LIMIT 1;


-- change state to all capital letters
-- check changes to location field, and see if it is partially empty
DELIMITER $$
CREATE TRIGGER trg_bu_sellers
BEFORE UPDATE ON sellers
FOR EACH ROW
BEGIN
    SET NEW.seller_state = UPPER(NEW.seller_state);
    IF OLD.seller_zip_code_prefix != NEW.seller_zip_code_prefix 
    OR OLD.seller_city != NEW.seller_city 
    OR OLD.seller_state != NEW.seller_state THEN
		IF OLD.seller_zip_code_prefix IS NULL
		OR OLD.seller_city IS NULL 
		OR OLD.seller_state IS NULL THEN
			SIGNAL SQLSTATE "45000"
			SET MESSAGE_TEXT = "Update to geolocation fields cannot be partially empty";
		END IF;
	END IF;
END$$
DELIMITER ;



-- check if location fields have changed
DELIMITER $$
CREATE TRIGGER trg_au_sellers
AFTER UPDATE ON sellers
FOR EACH ROW
BEGIN
    DECLARE location_msg VARCHAR(255) DEFAULT NULL;
    
    IF OLD.seller_zip_code_prefix != NEW.seller_zip_code_prefix 
    OR OLD.seller_city != NEW.seller_city 
    OR OLD.seller_state != NEW.seller_state THEN
        SET location_msg = CONCAT('Updated location for id ', OLD.seller_id, ": ", NEW.seller_zip_code_prefix, ',', NEW.seller_city, ',', NEW.seller_state);
    END IF;
    
    IF location_msg IS NOT NULL THEN
        INSERT INTO audit_log(at_table, action_desc, action_date)
        VALUES ('sellers', location_msg, NOW());
    END IF;
END$$
DELIMITER ;

-- test UPDATE triggers
UPDATE sellers
SET seller_city = 'austin', seller_state = 'tx'
WHERE seller_id = 'test_seller_1';

SELECT * FROM sellers WHERE seller_id = 'test_seller_1';
SELECT * FROM audit_log WHERE at_table = 'sellers' ORDER BY log_id DESC LIMIT 1;

-- send delete logs to audit_log
DELIMITER $$
CREATE TRIGGER trg_ad_sellers
AFTER DELETE ON sellers
FOR EACH ROW
BEGIN
    INSERT INTO audit_log(at_table, action_desc, action_date)
    VALUES ('sellers', CONCAT('Deleted seller: ', OLD.seller_id), NOW());
END$$
DELIMITER ;

-- test DELETE triggers
DELETE FROM sellers WHERE seller_id = 'test_seller_1';
SELECT * FROM audit_log WHERE at_table = 'sellers' ORDER BY log_id DESC LIMIT 1;