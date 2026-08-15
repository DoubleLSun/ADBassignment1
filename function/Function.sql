-- List all functions
SHOW FUNCTION STATUS;
SHOW FUNCTION STATUS WHERE db='assignment1';

SELECT ROUTINE_DEFINITION
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_SCHEMA = 'assignment1' AND ROUTINE_TYPE='FUNCTION';

SHOW CREATE FUNCTION fn_get_review_sentiment;
SHOW CREATE FUNCTION fn_calculate_delivery_delay;
SHOW CREATE FUNCTION fn_calculate_delivery_delay;

DROP FUNCTION IF EXISTS fn_calculate_order_total;
DROP FUNCTION IF EXISTS fn_calculate_delivery_delay;
DROP FUNCTION IF EXISTS fn_get_review_sentiment;

------------------------------------------------------------------------------ 

-- Calculate Total Order Value (including freight)
DELIMITER $$
CREATE FUNCTION fn_calculate_order_total(
    p_price DECIMAL(10,2),
    p_freight_value DECIMAL(10,2)
) 
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    RETURN COALESCE(p_price, 0) + COALESCE(p_freight_value, 0);
END$$
DELIMITER ;

-- Calculate Delivery Delay in Days
DELIMITER $$
CREATE FUNCTION fn_calculate_delivery_delay(
    p_estimated DATETIME,
    p_actual DATETIME
) 
RETURNS INT
DETERMINISTIC
BEGIN
    -- Returns positive days if late, negative/zero if on time
    IF p_actual IS NULL OR p_estimated IS NULL THEN
        RETURN 0;
    END IF;
    RETURN DATEDIFF(p_actual, p_estimated);
END$$
DELIMITER ;
------------------------------------------------------------------------------ 
-- product review sentiment 
DELIMITER $$
CREATE FUNCTION fn_get_review_sentiment(p_review_score INT)
RETURNS VARCHAR(10)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_sentiment VARCHAR(10);
    SET v_sentiment = CASE 
        WHEN p_review_score >= 4 THEN 'Positive'
        WHEN p_review_score = 3  THEN 'Neutral'
        WHEN p_review_score <= 2 THEN 'Negative'
        ELSE 'Unknown'
    END;
    RETURN v_sentiment;
END$$
DELIMITER ;
