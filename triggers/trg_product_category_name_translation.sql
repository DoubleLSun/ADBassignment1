-- this table don't really need validations, so just commit logs

DELIMITER $$
CREATE TRIGGER trg_ai_product_category_name_translation
AFTER INSERT 
ON product_category_name_translation
FOR EACH ROW
BEGIN
	INSERT INTO audit_log(at_table,action_desc,action_date)VALUES(
		"product_category_name_translation",
        CONCAT("Added translation name: ", NEW.product_category_name),
        NOW()
    );
END$$
DELIMITER ;

-- test trigger
INSERT INTO product_category_name_translation(product_category_name,product_category_name_english) VALUES(
	"666", "666"
);
SELECT * FROM product_category_name_translation WHERE product_category_name = "666";
SELECT * from audit_log WHERE at_table = "product_category_name_translation";


DELIMITER $$
CREATE TRIGGER trg_au_product_category_name_translation
AFTER UPDATE
ON product_category_name_translation
FOR EACH ROW
BEGIN
	INSERT INTO audit_log(at_table,action_desc,action_date)VALUES(
	"product_category_name_translation",
	CONCAT("Updated translation for ", NEW.product_category_name),
	NOW()
    );
END$$
DELIMITER ;

-- test trigger
SET SQL_SAFE_UPDATES = 0;
UPDATE product_category_name_translation SET product_category_name_english = "888" WHERE product_category_name = "666";

SELECT * FROM product_category_name_translation WHERE product_category_name = "666";
SELECT * from audit_log WHERE at_table = "product_category_name_translation";
SET SQL_SAFE_UPDATES = 1;


DELIMITER $$
CREATE TRIGGER trg_ad_product_category_name_translation
AFTER DELETE
ON product_category_name_translation
FOR EACH ROW
BEGIN
	INSERT INTO audit_log(at_table,action_desc,action_date)VALUES(
	"product_category_name_translation",
	CONCAT("Deleted translation for ", OLD.product_category_name),
	NOW()
    );
END$$
DELIMITER ;

-- test delete trigger
DELETE FROM product_category_name_translation WHERE product_category_name = "666";
SELECT * FROM product_category_name_translation WHERE product_category_name = "666";
SELECT * from audit_log WHERE at_table = "product_category_name_translation";