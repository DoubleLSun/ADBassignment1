-- make it so that it automatically fill in the blanks on trigger if no input is given
DELIMITER $$
CREATE TRIGGER trg_bi_orders
BEFORE INSERT 
ON orders
FOR EACH ROW
BEGIN
	IF NEW.order_status IS NULL THEN SET NEW.order_status = "invoiced"; END IF;
    IF NEW.order_purchase_timestamp IS NULL THEN SET NEW.order_purchase_timestamp = NOW(); END IF;
    IF NEW.order_estimated_delivery_date IS NULL THEN SET NEW.order_estimated_delivery_date = NOW() + INTERVAL 7 DAY; END IF;
END$$
DELIMITER ;

-- send insert logs to audit log
DELIMITER $$
CREATE TRIGGER trg_ai_orders
AFTER INSERT 
ON orders
FOR EACH ROW
BEGIN
	INSERT INTO audit_log(at_table,action_desc,action_date)VALUES(
		"orders",
        CONCAT("Added order: ", NEW.order_id),
        NOW()
    );
END$$
DELIMITER ;

-- test INSERT triggers
INSERT INTO orders(order_id, customer_id, order_status, order_purchase_timestamp, order_approved_at, order_delivered_carrier_date,
order_delivered_customer_date,order_estimated_delivery_date)VALUES(
	"666",
    "666",
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL
);
SELECT * FROM orders WHERE order_id = "666";
SELECT * FROM audit_log WHERE at_table = "orders";

-- block updates that will turn delivered date into null
-- here you assume you only update the delivered dates
-- you're not allowed to update estimated date, it should be set fixed on INSERT 
-- status filters base on specific text
DELIMITER $$
CREATE TRIGGER trg_bu_orders
BEFORE UPDATE 
ON orders
FOR EACH ROW
BEGIN
	IF OLD.order_approved_at IS NOT NULL AND NEW.order_approved_at IS NULL 
    OR OLD.order_delivered_carrier_date IS NOT NULL AND  NEW.order_delivered_carrier_date IS NULL
    OR OLD.order_delivered_customer_date IS NOT NULL AND  NEW.order_delivered_customer_date IS NULL THEN
		SIGNAL SQLSTATE "45000" SET MESSAGE_TEXT = "Cannot set date to null";
	END IF;
    IF LOWER(NEW.order_status) NOT IN ("delivered","shipped","cancelled","unavailable","invoiced") THEN
		SIGNAL SQLSTATE "45000" SET MESSAGE_TEXT = "Incorrect status message";
	END IF;
END$$
DELIMITER ;
drop trigger trg_bu_orders



-- send update logs to audit log
DELIMITER $$
CREATE TRIGGER trg_au_orders
AFTER UPDATE
ON orders
FOR EACH ROW
BEGIN
	DECLARE status_msg VARCHAR(255) DEFAULT NULL;
    DECLARE approved_msg VARCHAR(255) DEFAULT NULL;
    DECLARE carrier_msg VARCHAR(255) DEFAULT NULL;
    DECLARE customer_msg VARCHAR(255) DEFAULT NULL;
    
    IF OLD.order_status != NEW.order_status THEN SET status_msg = CONCAT("New status: ", NEW.order_status); END IF;
    IF OLD.order_approved_at != NEW.order_approved_at THEN SET approved_msg = CONCAT("New status: ", NEW.order_approved_at); END IF;
    IF OLD.order_delivered_carrier_date != NEW.order_delivered_carrier_date THEN SET carrier_msg = CONCAT("New status: ", NEW.order_delivered_carrier_date); END IF;
    IF OLD.order_delivered_customer_date != NEW.order_delivered_customer_date THEN SET customer_msg = CONCAT("New status: ", NEW.order_delivered_customer_date); END IF;
    
	IF NOT (OLD.order_status <=> NEW.order_status)
    OR NOT (OLD.order_approved_at <=> NEW.order_approved_at) 
    OR NOT (OLD.order_delivered_carrier_date <=> NEW.order_delivered_carrier_date) 
    OR NOT (OLD.order_delivered_customer_date <=> NEW.order_delivered_customer_date) THEN
		INSERT INTO audit_log(at_table,action_desc,action_date)VALUES(
			"orders",
            CONCAT_WS(",","Updated orders on id ",OLD.order_id,status_msg, approved_msg, carrier_msg, customer_msg),
            NOW()
        );
    END IF;
END$$
DELIMITER ;

-- test UPDATE triggers
UPDATE orders SET order_status = "test status" WHERE order_id = "666";
UPDATE orders SET order_delivered_customer_date = NOW() WHERE order_id = "666";
UPDATE orders SET order_delivered_customer_date = NULL WHERE order_id = "666";

SELECT * FROM orders WHERE order_id = "666";
SELECT * FROM audit_log WHERE at_table = "orders";

-- send delete log to audit log

DELIMITER $$
CREATE TRIGGER trg_ad_orders
AFTER DELETE
ON orders
FOR EACH ROW
BEGIN
	INSERT INTO audit_log(at_table,action_desc,action_date)VALUES(
	"orders",
	CONCAT("Deleted order: ", OLD.order_id),
	NOW()
    );
END$$
DELIMITER ;

-- test DELETE trigger
DELETE FROM orders WHERE order_id = "666";
SELECT * FROM orders WHERE order_id = "666";
SELECT * FROM audit_log WHERE at_table = "orders";