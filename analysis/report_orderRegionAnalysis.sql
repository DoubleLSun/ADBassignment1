USE assignment;

-- Get top 50 orders by their highest average review score 
DROP PROCEDURE IF EXISTS sp_report_top_reviewed_orders;

DELIMITER $$
CREATE PROCEDURE sp_report_top_reviewed_orders()
BEGIN
    SELECT
        o.order_id AS Order_ID,
        ROUND(review_totals.Average_Review_Score, 2) AS Average_Review_Score,
        review_totals.Review_Count,
        COALESCE(item_totals.Total_Purchase_Price, 0) AS Total_Purchase_Price
    FROM orders o
    JOIN (
        SELECT
            order_id,
            AVG(review_score) AS Average_Review_Score,
            COUNT(review_id) AS Review_Count
        FROM order_reviews
        GROUP BY order_id
    ) AS review_totals ON review_totals.order_id = o.order_id
    LEFT JOIN (
        SELECT
            order_id,
            SUM(COALESCE(price, 0)) AS Total_Purchase_Price
        FROM order_items
        GROUP BY order_id
    ) AS item_totals ON item_totals.order_id = o.order_id
    ORDER BY Average_Review_Score DESC, Review_Count DESC, o.order_id
    LIMIT 50;
END$$
DELIMITER ;

-- Get 20 customer regions by their highest total item purchase price
DROP PROCEDURE IF EXISTS sp_report_top_purchase_regions;

DELIMITER $$
CREATE PROCEDURE sp_report_top_purchase_regions()
BEGIN
    SELECT
        c.customer_state AS Region,
        COUNT(DISTINCT o.order_id) AS Order_Count,
        SUM(COALESCE(oi.price, 0)) AS Total_Purchase_Price
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    JOIN order_items oi ON oi.order_id = o.order_id
    GROUP BY c.customer_state
    ORDER BY Total_Purchase_Price DESC, c.customer_state
    LIMIT 20;
END$$
DELIMITER ;

-- Show percentage of Seller/customer allocation and purchase cost by region
DROP PROCEDURE IF EXISTS sp_report_region_allocation;

DELIMITER $$
CREATE PROCEDURE sp_report_region_allocation()
BEGIN
    SELECT
        regions.Region,
        ROUND(
            100.0 * COALESCE(seller_counts.Seller_Count, 0) /
            NULLIF((SELECT COUNT(*) FROM sellers), 0),
            2
        ) AS Seller_Percentage,
        ROUND(
            100.0 * COALESCE(customer_counts.Customer_Count, 0) /
            NULLIF((SELECT COUNT(*) FROM customers), 0),
            2
        ) AS Customer_Percentage,
        COALESCE(purchase_totals.Total_Purchase_Price, 0) AS Total_Purchase_Price
    FROM (
        SELECT seller_state AS Region FROM sellers
        UNION
        SELECT customer_state AS Region FROM customers
    ) AS regions
    LEFT JOIN (
        SELECT seller_state AS Region, COUNT(*) AS Seller_Count
        FROM sellers
        GROUP BY seller_state
    ) AS seller_counts ON seller_counts.Region = regions.Region
    LEFT JOIN (
        SELECT customer_state AS Region, COUNT(*) AS Customer_Count
        FROM customers
        GROUP BY customer_state
    ) AS customer_counts ON customer_counts.Region = regions.Region
    LEFT JOIN (
        SELECT
            c.customer_state AS Region,
            SUM(COALESCE(oi.price, 0)) AS Total_Purchase_Price
        FROM orders o
        JOIN customers c ON c.customer_id = o.customer_id
        JOIN order_items oi ON oi.order_id = o.order_id
        GROUP BY c.customer_state
    ) AS purchase_totals ON purchase_totals.Region = regions.Region
    WHERE regions.Region IS NOT NULL
    ORDER BY regions.Region;
END$$
DELIMITER ;

-- Example calls:
-- CALL sp_report_top_reviewed_orders();
-- CALL sp_report_top_purchase_regions();
-- CALL sp_report_region_allocation();
