USE assignment1;

DROP PROCEDURE IF EXISTS sp_shipping_delay_data;

-- Requirement 3, data filter/cleaning procedure
-- INPUT: min delay days (INT),
-- OUTPUT: table of delayed orders
DELIMITER $$
CREATE PROCEDURE sp_shipping_delay_data(IN p_min_delay_days INT)
COMMENT 'Create temporary table of orders that are delayed'
BEGIN
    -- Drop the session temp table if it already exists 
    DROP TEMPORARY TABLE IF EXISTS tmp_shipping_delays;
    
    CREATE TEMPORARY TABLE tmp_shipping_delays AS
    SELECT 
        o.order_id,
        o.customer_id,
        c.customer_state,
        c.customer_city,
        o.order_purchase_timestamp,
        fn_calculate_delivery_delay(o.order_estimated_delivery_date, o.order_delivered_customer_date) AS days_late
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
      AND fn_calculate_delivery_delay(o.order_estimated_delivery_date, o.order_delivered_customer_date) >= p_min_delay_days; 
END$$
DELIMITER ;

------------------------------------------------------------------------------ 

CALL sp_shipping_delay_data(5); -- give me order delayed by 5 days

-- Example usage, filter by state
SELECT customer_state, COUNT(*), AVG(days_late) 
FROM tmp_shipping_delays 
GROUP BY customer_state;

-- Example usage, filter by city
SELECT customer_city, COUNT(*) 
FROM tmp_shipping_delays 
GROUP BY customer_city;
