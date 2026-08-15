USE assignment1;

-- Checking
SHOW CREATE PROCEDURE sp_report_top_categories;

DROP PROCEDURE IF EXISTS  sp_report_top_categories;
-- Top Selling Product Categories
DELIMITER $$
CREATE PROCEDURE sp_report_top_categories(IN p_limit INT)
BEGIN
    SELECT 
        p.product_category_name AS Category,
        COUNT(oi.item_id) AS Total_Units_Sold,
        SUM(fn_calculate_order_total(oi.price, oi.freight_value)) AS Total_Revenue
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    GROUP BY p.product_category_name
    HAVING p.product_category_name IS NOT NULL
    ORDER BY Total_Revenue DESC
    LIMIT p_limit;
END$$
DELIMITER ;