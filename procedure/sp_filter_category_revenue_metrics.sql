USE assignment1;

-- Checking
SHOW CREATE PROCEDURE sp_prepare_category_revenue_metrics;
SHOW CREATE PROCEDURE sp_filter_category_revenue_metrics;

DROP PROCEDURE IF EXISTS sp_prepare_category_revenue_metrics;
DROP PROCEDURE IF EXISTS sp_filter_category_revenue_metrics;

-- Pre-aggregates volume and revenue by category
DELIMITER $$
CREATE PROCEDURE sp_prepare_category_revenue_metrics()
COMMENT 'Calculate produts sold and revenue for each category'
BEGIN
    DROP TEMPORARY TABLE IF EXISTS tmp_category_revenue_summary;
    
    -- Process the counts and totals entirely within the procedure
    CREATE TEMPORARY TABLE tmp_category_revenue_summary AS
    SELECT 
        p.product_category_name AS Category,
        COUNT(oi.order_id) AS Total_Units_Sold, -- "How many sold"
        SUM(fn_calculate_order_total(oi.price, oi.freight_value)) AS Total_Revenue -- "How much earned"
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    WHERE p.product_category_name IS NOT NULL
    GROUP BY p.product_category_name;    
END$$
DELIMITER ;
------------------------------------------------------------------------------ 
CALL sp_prepare_category_revenue_metrics;

SELECT * FROM tmp_category_revenue_summary 
ORDER BY Total_Revenue DESC 
LIMIT 10;

SELECT * FROM tmp_category_revenue_summary 
WHERE Total_Units_Sold < 50 
ORDER BY Total_Units_Sold ASC;

SELECT Category, (Total_Revenue / Total_Units_Sold) AS Avg_Value_Per_Item 
FROM tmp_category_revenue_summary;

------------------------------------------------------------------------------ 
-- Version 2: allow filter by specific category
-- Pre-aggregates volume and revenue with optional category filtering
DELIMITER $$
CREATE PROCEDURE sp_filter_category_revenue_metrics(IN p_category_name VARCHAR(255))
COMMENT 'Calculate produts sold and revenue for specific category'
BEGIN
    DROP TEMPORARY TABLE IF EXISTS tmp_category_revenue_summary;
    
    CREATE TEMPORARY TABLE tmp_category_revenue_summary AS
    SELECT 
        p.product_category_name AS Category,
        COUNT(oi.order_id) AS Total_Units_Sold, -- "How many"
        SUM(fn_calculate_order_total(oi.price, oi.freight_value)) AS Total_Revenue -- "How much"
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    WHERE p.product_category_name IS NOT NULL
      -- If parameter is NULL, it returns TRUE for all rows. Otherwise, it filters exactly.
      AND (p.product_category_name = p_category_name OR p_category_name IS NULL)
    GROUP BY p.product_category_name;
    
END$$
DELIMITER ;
------------------------------------------------------------------------------ 
CALL sp_filter_category_revenue_metrics('beleza_saude');
-- OR show from all
CALL sp_filter_category_revenue_metrics(NULL);
