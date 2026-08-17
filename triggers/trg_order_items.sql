-- check for negative inputs for price and freight_value
-- according to dataset source, freight value is a performance 
-- measurement based on specific measures and weight,
-- so it cannot be negative. 
DELIMITER $$
CREATE TRIGGER trg_bi_order_items
BEFORE INSERT 
ON order_items
FOR EACH ROW
BEGIN
	IF NEW.freight_value < 0 THEN SET NEW.freight_value = 0; END IF;
    IF NEW.price < 0 THEN SET NEW.price = 0; END IF;
END$$
DELIMITER ;

-- add order item id into audit log
-- also shows the order id (both are primary key, so show both)
DELIMITER $$
CREATE TRIGGER trg_ai_order_items
AFTER INSERT 
ON order_items
FOR EACH ROW
BEGIN
	INSERT INTO audit_log(at_table,action_desc,action_date)VALUES(
    "order_items",
    CONCAT("Added new order id ", NEW.order_id, "with item id: ", NEW.order_item_id),
    NOW()
    );
END$$
DELIMITER ;

-- test INSERT triggers
INSERT INTO order_items(order_id,order_item_id,product_id,seller_id,shipping_limit_date,price,freight_value)
VALUES(
	"666",
    666,
    "666",
    "666",
    NOW(),
    -100,
    -100
);
select * from order_items where order_id = "666";
select * from audit_log where at_table = "order_items";



-- check if the values are updated to negative, then rejects them
DELIMITER $$
CREATE TRIGGER trg_bu_order_items
BEFORE UPDATE 
ON order_items
FOR EACH ROW
BEGIN
		IF NEW.freight_value < 0 OR NEW.price < 0 THEN
			SIGNAL SQLSTATE "45000"
            SET MESSAGE_TEXT = "Cannot set negative value for freight value and price";
		END IF;
END$$
DELIMITER ;

-- send update logs to audit log
DELIMITER $$
CREATE TRIGGER trg_au_order_items
AFTER UPDATE
ON order_items
FOR EACH ROW
BEGIN
	DECLARE product_msg VARCHAR(255) DEFAULT NULL;
    DECLARE seller_msg VARCHAR(255) DEFAULT NULL;
    DECLARE date_msg VARCHAR(255) DEFAULT NULL;
    DECLARE price_msg VARCHAR(255) DEFAULT NULL;
    DECLARE freight_msg VARCHAR(255) DEFAULT NULL;
    
	IF OLD.product_id != NEW.product_id THEN SET product_msg = CONCAT("Product id: ", NEW.product_id); END IF;
	IF OLD.seller_id != NEW.seller_id THEN SET seller_msg = CONCAT("Seller id: ", NEW.seller_id); END IF;
	IF OLD.shipping_limit_date != NEW.shipping_limit_date THEN SET date_msg = CONCAT("Due Date: ", NEW.shipping_limit_date); END IF;
	IF OLD.price != NEW.price THEN SET price_msg = CONCAT("Price: ", NEW.price); END IF; 
	IF OLD.freight_value != NEW.freight_value THEN SET freight_msg = CONCAT("Freight value: ", NEW.freight_value); END IF;

    
	IF OLD.product_id != NEW.product_id
    OR OLD.seller_id != NEW.seller_id
    OR OLD.shipping_limit_date != NEW.shipping_limit_date
    OR OLD.price != NEW.price
    OR OLD.freight_value != NEW.freight_value THEN
			INSERT INTO audit_log(at_table,action_desc,action_date)
    VALUES(
    "order_items",
    CONCAT_WS(",",CONCAT("Updated order item on id ", OLD.order_item_id), product_msg,seller_msg,date_msg,price_msg,freight_msg),
    NOW()
    );
    END IF;
END$$
DELIMITER ;


-- test UPDATE triggers
UPDATE order_items SET price = -100 WHERE order_id = "666";
UPDATE order_items SET freight_value = -100 WHERE order_id = "666";

UPDATE order_items SET price = 100 WHERE order_id = "666";
UPDATE order_items SET freight_value = 100 WHERE order_id = "666";

select * from order_items where order_id = "666";
select * from audit_log where at_table = "order_items";

-- send delete logs to audit log
DELIMITER $$
CREATE TRIGGER trg_ad_order_items
AFTER DELETE
ON order_items
FOR EACH ROW
BEGIN
	INSERT INTO audit_log(at_table,action_desc,action_date)VALUES(
    "order_items",
    CONCAT("Deleted order id ", OLD.order_id, " with item id: ", OLD.order_item_id),
    NOW()
    );
END$$
DELIMITER ;


-- test DELETE triggers
DELETE FROM order_items WHERE order_id = "666";
select * from order_items where order_id = "666";
select * from audit_log where at_table = "order_items";