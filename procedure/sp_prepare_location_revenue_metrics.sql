USE assignment1;

-- Checking
SHOW CREATE PROCEDURE sp_prepare_location_revenue_metrics;

DROP PROCEDURE IF EXISTS sp_prepare_location_revenue_metrics;
-- Pre-aggregates volume and revenue by customer location
DELIMITER $$
CREATE PROCEDURE sp_prepare_location_revenue_metrics(
    IN p_target_state CHAR(2),   -- Optional: filter by state abbreviation (e.g., 'SP')
    IN p_target_city VARCHAR(255) -- Optional: filter by city name (e.g., 'sao paulo')
)
COMMENT 'Computes totals by location with dynamic filters'
BEGIN
    DROP TEMPORARY TABLE IF EXISTS tmp_location_revenue_summary;
    
    CREATE TEMPORARY TABLE tmp_location_revenue_summary AS
    SELECT 
        c.customer_state AS State,
        c.customer_city AS City,
        COUNT(oi.order_id) AS Total_Units_Sold,
        SUM(fn_calculate_order_total(oi.price, oi.freight_value)) AS Total_Revenue
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE (c.customer_state = p_target_state OR p_target_state IS NULL)
      AND (c.customer_city = p_target_city OR p_target_city IS NULL)
    GROUP BY c.customer_state, c.customer_city;
    
END$$
DELIMITER ;
------------------------------------------------------------------------------
-- specific to one state, one city
CALL sp_prepare_location_revenue_metrics('SP', 'sao paulo');
-- for all metrics inside the state of RJ
CALL sp_prepare_location_revenue_metrics('RJ', NULL);
-- use null to see everything
CALL sp_prepare_location_revenue_metrics(NULL,NULL);
