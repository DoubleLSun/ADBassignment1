USE assignment1;

-- Checking
SHOW CREATE PROCEDURE sp_report_shipping_delays;

DROP PROCEDURE IF EXISTS sp_report_shipping_delays;

DELIMITER $$
CREATE PROCEDURE sp_report_shipping_delays(IN p_min_delay_days INT)
COMMENT 'States Shipping Stats Dashboard'
BEGIN
    SELECT 
        c.customer_state AS Customer_State,
        SUM(CASE WHEN fn_calculate_delivery_delay(o.order_estimated_delivery_date, o.order_delivered_customer_date) >= p_min_delay_days THEN 1 ELSE 0 END) AS Total_Delayed_Orders,
        ROUND(AVG(CASE WHEN fn_calculate_delivery_delay(o.order_estimated_delivery_date, o.order_delivered_customer_date) >= p_min_delay_days 
                       THEN fn_calculate_delivery_delay(o.order_estimated_delivery_date, o.order_delivered_customer_date) 
                  END), 1) AS Avg_Days_Late,
        ROUND((SUM(CASE WHEN fn_calculate_delivery_delay(o.order_estimated_delivery_date, o.order_delivered_customer_date) >= p_min_delay_days THEN 1 ELSE 0 END) 
               / COUNT(o.order_id)) * 100, 2) AS Delay_Percentage
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'  -- only valid delivered records 
    GROUP BY c.customer_state
    ORDER BY Total_Delayed_Orders DESC;
END$$
DELIMITER ;
