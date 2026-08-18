-- all the queries here only update logs to audit log
-- this is to consider that order_id is 100% tied with review_id
-- and that date and timestamp is atuo generated.
-- the title and message can also be empty
DELIMITER $$
CREATE TRIGGER trg_ai_order_reviews
AFTER INSERT 
ON order_reviews
FOR EACH ROW
BEGIN
	INSERT INTO audit_log(at_table,action_desc,action_date) VALUES (
		"order_reviews",
        CONCAT("Added order review: ",NEW.order_id),
        NOW()
    );
END$$
DELIMITER ;
-- test INSERT trigger
INSERT INTO order_reviews(review_id,order_id,review_score,review_comment_title,review_comment_message,review_creation_date,review_answer_timestamp)VALUES(
	"666",
    "666",
    "666",
    "666",
    "666",
    NOW(),
    NOW()
);
SELECT * from order_reviews WHERE order_id = "666";
SELECT * from audit_log WHERE at_table = "order_reviews";

DELIMITER $$
CREATE TRIGGER trg_au_order_reviews
AFTER UPDATE
ON order_reviews
FOR EACH ROW
BEGIN
	DECLARE score_msg VARCHAR(255) DEFAULT NULL;
	DECLARE title_msg VARCHAR(255) DEFAULT NULL;
	DECLARE message_msg VARCHAR(255) DEFAULT NULL;
	DECLARE date_msg VARCHAR(255) DEFAULT NULL;
	DECLARE timestamp_msg VARCHAR(255) DEFAULT NULL;
    
    IF OLD.review_score != NEW.review_score THEN SET score_msg = CONCAT("New score:",NEW.review_score); END IF;
    IF OLD.review_comment_title != NEW.review_comment_title THEN SET title_msg = CONCAT("New title:",NEW.review_comment_title); END IF;
    IF OLD.review_comment_message != NEW.review_comment_message THEN SET message_msg = CONCAT("New message:",NEW.review_comment_message); END IF;
    IF OLD.review_creation_date != NEW.review_creation_date THEN SET date_msg = CONCAT("New creation date:",NEW.review_creation_date); END IF;
    IF OLD.review_answer_timestamp != NEW.review_answer_timestamp THEN SET timestamp_msg = CONCAT("New answer timestamp:",NEW.review_answer_timestamp); END IF;
    
	IF OLD.review_score != NEW.review_score 
    OR OLD.review_comment_title != NEW.review_comment_title 
    OR OLD.review_comment_message != NEW.review_comment_message 
    OR OLD.review_creation_date != NEW.review_creation_date 
    OR OLD.review_answer_timestamp != NEW.review_answer_timestamp THEN
		INSERT INTO audit_log(at_table, action_desc, action_date) VALUES (
			"order_reviews",
            CONCAT_WS(",",CONCAT("Updated review on id ",OLD.review_id), score_msg, title_msg, message_msg, date_msg, timestamp_msg),
            NOW()
        );
	END IF;
END$$
DELIMITER ;

-- test UPDATE trigger
UPDATE order_reviews SET review_score = 777, review_comment_title = "777", 
review_comment_message = "777", review_creation_date = NOW(), review_answer_timestamp = NOW()
WHERE review_id = "666";
SELECT * from order_reviews WHERE order_id = "666";
SELECT * from audit_log WHERE at_table = "order_reviews";

DELIMITER $$
CREATE TRIGGER trg_ad_order_reviews
AFTER DELETE
ON order_reviews
FOR EACH ROW
BEGIN
	INSERT INTO audit_log(at_table,action_desc,action_date) VALUES (
	"order_reviews",
	CONCAT("Deleted order review: ",OLD.order_id),
	NOW()
    );
END$$
DELIMITER ;

-- test DELETE trigger
DELETE FROM order_reviews WHERE review_id = "666";
SELECT * from order_reviews WHERE order_id = "666";
SELECT * from audit_log WHERE at_table = "order_reviews";
