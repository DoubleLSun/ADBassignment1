-- check and set default values for negative inputs 
DELIMITER $$
CREATE TRIGGER trg_bi_order_payments
BEFORE INSERT 
ON order_payments
FOR EACH ROW
BEGIN
	IF NEW.payment_sequential < 0 THEN SET NEW.payment_sequential = 1; END IF;
    IF NEW.payment_installments < 0 THEN SET NEW.payment_installments = 1; END IF;
    IF NEW.payment_value < 0 THEN SET NEW.payment_value = 0; END IF;
END$$
DELIMITER ;

-- send payment log to audit log
DELIMITER $$
CREATE TRIGGER trg_ai_order_payments
AFTER INSERT 
ON order_payments
FOR EACH ROW
BEGIN
	INSERT INTO audit_log(at_table, action_desc,action_date)VALUES(
    "order_payments",
    CONCAT("Added order payment: ",NEW.order_id),
    NOW()
    );
END$$
DELIMITER ;

-- test INSERT triggers
INSERT INTO order_payments(order_id, payment_sequential, payment_type, payment_installments, payment_value) VALUES (
"666",
-1,
"test payment",
-1,
-1
);
SELECT * from order_payments WHERE order_id = "666";
SELECT * from audit_log WHERE at_table = "order_payments";

-- check and set default values for negative inputs 
DELIMITER $$
CREATE TRIGGER trg_bu_order_payments
BEFORE UPDATE 
ON order_payments
FOR EACH ROW
BEGIN
	IF NEW.payment_installments < 0 
    OR NEW.payment_value < 0 THEN
		SIGNAL SQLSTATE "45000" SET MESSAGE_TEXT = "Cannot put negative values in installment and value";
	END IF;
END$$
DELIMITER ;

-- send updated payment log to audit log
DELIMITER $$
CREATE TRIGGER trg_au_order_payments
AFTER UPDATE
ON order_payments
FOR EACH ROW
BEGIN
	DECLARE install_msg VARCHAR(255) DEFAULT NULL;
    DECLARE value_msg VARCHAR(255) DEFAULT NULL;
	IF OLD.payment_installments != NEW.payment_installments THEN SET install_msg = CONCAT("New installment: ",NEW.payment_installments);
    END IF;
    IF OLD.payment_value != NEW.payment_value THEN SET value_msg = CONCAT("New value: ", NEW.payment_value); END IF;
    IF install_msg IS NOT NULL OR value_msg IS NOT NULL THEN
		INSERT INTO audit_log(at_table, action_desc, action_date) VALUES (
			"order_payments",
			CONCAT_wS(",","Payment updated on id ",OLD.order_id,install_msg,value_msg),
            NOW()
		); 
    END IF;
END$$
DELIMITER ;

-- test UPDATE triggers
UPDATE order_payments SET payment_installments = -1 WHERE order_id = "666";
UPDATE order_payments SET payment_value = -1 WHERE order_id = "666";
UPDATE order_payments SET payment_value = 100 WHERE order_id = "666";
SELECT * from order_payments WHERE order_id = "666";
SELECT * from audit_log WHERE at_table = "order_payments";

DELIMITER $$
CREATE TRIGGER trg_ad_order_payments
AFTER DELETE
ON order_payments
FOR EACH ROW
BEGIN
	INSERT INTO audit_log(at_table, action_desc,action_date)VALUES(
    "order_payments",
    CONCAT("Deleted order payment: ",OLD.order_id),
    NOW()
    );
END$$
DELIMITER ;

-- test DELETE trigger
DELETE FROM order_payments WHERE order_id = "666";
SELECT * from order_payments WHERE order_id = "666";
SELECT * from audit_log WHERE at_table = "order_payments";