-- check for negative inputs and convert them to a positive value
DELIMITER $$
CREATE TRIGGER trg_bi_products
BEFORE INSERT 
ON products
FOR EACH ROW
BEGIN
	IF NEW.product_name_length < 0 THEN SET NEW.product_name_length = NEW.product_name_length * -1; END IF;
    IF NEW.product_description_length < 0 THEN SET NEW.product_description_length = NEW.product_description_length * -1; END IF;
    IF NEW.product_photos_qty < 0 THEN SET NEW.product_photos_qty = NEW.product_photos_qty * -1; END IF;
    IF NEW.product_weight_g < 0 THEN SET NEW.product_weight_g = NEW.product_weight_g * -1; END IF;
    IF NEW.product_length_cm < 0 THEN SET NEW.product_length_cm = NEW.product_length_cm * -1; END IF;
    IF NEW.product_height_cm < 0 THEN SET NEW.product_height_cm = NEW.product_height_cm * -1; END IF;
    IF NEW.product_width_cm < 0 THEN SET NEW.product_width_cm = NEW.product_width_cm * -1; END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER trg_ai_products
AFTER INSERT 
ON products
FOR EACH ROW
BEGIN
	INSERT INTO audit_log(at_table,action_desc,action_date)VALUES(
		"products",
        CONCAT("Added product id: ",NEW.product_id),
        NOW()
    );
END$$
DELIMITER ;

-- test trigger
INSERT INTO products(
product_id,
product_category_name,
product_name_length,
product_description_length,
product_photos_qty,
product_weight_g,
product_length_cm,
product_height_cm,
product_width_cm)VALUES(
	"666",
    "666",
    -666,
    -666,
    -666,
    -666,
    -666,
    -666,
    -666
);
SELECT * FROM products WHERE product_id = "666";
SELECT * FROM audit_log WHERE at_table = "products";

-- does same stuff like before insert, so this won't be tested 
DELIMITER $$
CREATE TRIGGER trg_bu_products
BEFORE UPDATE 
ON products
FOR EACH ROW
BEGIN
	IF NEW.product_name_length < 0 THEN SET NEW.product_name_length = NEW.product_name_length * -1; END IF;
    IF NEW.product_description_length < 0 THEN SET NEW.product_description_length = NEW.product_description_length * -1; END IF;
    IF NEW.product_photos_qty < 0 THEN SET NEW.product_photos_qty = NEW.product_photos_qty * -1; END IF;
    IF NEW.product_weight_g < 0 THEN SET NEW.product_weight_g = NEW.product_weight_g * -1; END IF;
    IF NEW.product_length_cm < 0 THEN SET NEW.product_length_cm = NEW.product_length_cm * -1; END IF;
    IF NEW.product_height_cm < 0 THEN SET NEW.product_height_cm = NEW.product_height_cm * -1; END IF;
    IF NEW.product_width_cm < 0 THEN SET NEW.product_width_cm = NEW.product_width_cm * -1; END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER trg_au_products
AFTER UPDATE
ON products
FOR EACH ROW
BEGIN
	DECLARE category_msg VARCHAR(255) DEFAULT NULL;
	DECLARE name_msg VARCHAR(255) DEFAULT NULL;
    DECLARE description_msg VARCHAR(255) DEFAULT NULL;
    DECLARE photos_msg VARCHAR(255) DEFAULT NULL;
    DECLARE weight_msg VARCHAR(255) DEFAULT NULL;
    DECLARE length_msg VARCHAR(255) DEFAULT NULL;
    DECLARE height_msg VARCHAR(255) DEFAULT NULL;
    DECLARE width_msg VARCHAR(255) DEFAULT NULL;
    
    IF NOT (OLD.product_category_name <=> NEW.product_category_name) THEN SET category_msg = CONCAT("New category: ",NEW.product_category_name); END IF; 
	IF NOT (OLD.product_name_length <=> NEW.product_name_length) THEN SET name_msg = CONCAT("New name length: ",NEW.product_name_length); END IF; 
    IF NOT (OLD.product_description_length <=> NEW.product_description_length) THEN SET description_msg = CONCAT("New desc length: ",NEW.product_description_length); END IF; 
    IF NOT (OLD.product_photos_qty <=> NEW.product_photos_qty) THEN SET photos_msg = CONCAT("New photo quantity: ",NEW.product_photos_qty); END IF; 
    IF NOT (OLD.product_weight_g <=> NEW.product_weight_g) THEN SET weight_msg = CONCAT("New weight: ",NEW.product_weight_g); END IF; 
    IF NOT (OLD.product_length_cm <=> NEW.product_length_cm) THEN SET length_msg = CONCAT("New length: ",NEW.product_length_cm); END IF; 
    IF NOT (OLD.product_height_cm <=> NEW.product_height_cm) THEN SET height_msg = CONCAT("New height: ",NEW.product_height_cm); END IF; 
    IF NOT (OLD.product_width_cm <=> NEW.product_width_cm) THEN SET width_msg = CONCAT("New width: ",NEW.product_width_cm); END IF; 
    
    IF category_msg IS NOT NULL 
    OR name_msg IS NOT NULL 
    OR description_msg IS NOT NULL
    OR photos_msg IS NOT NULL
    OR weight_msg IS NOT NULL
    OR length_msg IS NOT NULL
    OR height_msg IS NOT NULL
    OR width_msg IS NOT NULL THEN
		INSERT INTO audit_log(at_table, action_desc, action_date)VALUES(
			"products",
            CONCAT_WS(",",CONCAT("Updated on product id ",OLD.product_id),category_msg,name_msg,description_msg,photos_msg,weight_msg,
            length_msg,height_msg,width_msg),
            NOW()
        );
	END IF;
END$$
DELIMITER ;

-- test trigger
UPDATE products SET product_category_name = "test", 
product_name_length = -666,
product_description_length = -666,
product_photos_qty = -666,
product_weight_g = -666,
product_length_cm = -666,
product_height_cm = -666,
product_width_cm = -666
WHERE product_id = "666";
SELECT * FROM products WHERE product_id = "666";
SELECT * FROM audit_log WHERE at_table = "products";

-- send delete logs to audit log
DELIMITER $$
CREATE TRIGGER trg_ad_products
AFTER DELETE
ON products
FOR EACH ROW
BEGIN
	INSERT INTO audit_log(at_table,action_desc,action_date)VALUES(
	"products",
	CONCAT("Deleted product id: ",OLD.product_id),
	NOW()
    );
END$$
DELIMITER ;

-- test delete trigger
DELETE FROM products WHERE product_id = "666";
SELECT * FROM products WHERE product_id = "666";
SELECT * FROM audit_log WHERE at_table = "products";