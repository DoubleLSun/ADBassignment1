USE assignment1;

DROP PROCEDURE IF EXISTS sp_prepare_seller_revenue_metrics;
-- Pre-aggregates volume and revenue by merchant account
DELIMITER $$
CREATE PROCEDURE sp_prepare_seller_revenue_metrics(IN p_seller_id VARCHAR(50))
COMMENT 'Computes totals by seller ID with an optional filter'
BEGIN
    DROP TEMPORARY TABLE IF EXISTS tmp_seller_revenue_summary;
    
    CREATE TEMPORARY TABLE tmp_seller_revenue_summary AS
    SELECT 
        oi.seller_id AS Seller_ID,
        s.seller_state AS Seller_State,
        s.seller_city AS Seller_City,
        COUNT(oi.order_id) AS Total_Units_Sold,
        SUM(fn_calculate_order_total(oi.price, oi.freight_value)) AS Total_Revenue
    FROM order_items oi
    JOIN sellers s ON oi.seller_id = s.seller_id
    WHERE (oi.seller_id = p_seller_id OR p_seller_id IS NULL)
    GROUP BY oi.seller_id, s.seller_state, s.seller_city;
END$$
DELIMITER ;
------------------------------------------------------------------------------
-- show full vendor leaderboard
CALL sp_prepare_seller_revenue_metrics(NULL);
-- not recommended, 
CALL sp_prepare_seller_revenue_metrics('0015a82c2db000af6aaaf3ae2ecb0632');
