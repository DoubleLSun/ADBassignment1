USE assignment1;

DROP PROCEDURE IF EXISTS sp_prepare_sentiment_metrics;
-- product sentiment distributions 
DELIMITER $$
CREATE PROCEDURE sp_prepare_sentiment_metrics(
    IN p_min_review_count INT
)
COMMENT 'Product sentiment data'
BEGIN
    DROP TEMPORARY TABLE IF EXISTS tmp_sentiment_metrics_summary;
    
    CREATE TEMPORARY TABLE tmp_sentiment_metrics_summary AS
    SELECT * FROM (
        SELECT 
            p.product_category_name AS Category,
            SUM(CASE WHEN fn_get_review_sentiment(r.review_score) = 'Positive' THEN 1 ELSE 0 END) AS Positive_Review_Count,
            SUM(CASE WHEN fn_get_review_sentiment(r.review_score) = 'Negative' THEN 1 ELSE 0 END) AS Negative_Review_Count,
            COUNT(r.review_id) AS Total_Review_Count,
            ROUND(AVG(r.review_score), 2) AS Avg_Review_Score
        FROM order_reviews r
        JOIN order_items oi ON r.order_id = oi.order_id
        JOIN products p ON oi.product_id = p.product_id
        WHERE p.product_category_name IS NOT NULL
        GROUP BY p.product_category_name
    ) AS raw_totals
    -- filter out products with less review
    WHERE raw_totals.Total_Review_Count >= COALESCE(p_min_review_count, 1);
    
END$$
DELIMITER ;
------------------------------------------------------------------------------ 
-- minumum review 
CALL sp_prepare_sentiment_metrics(20);
-- positive review leaderboard
SELECT Category, Positive_Review_Count, Avg_Review_Score 
FROM tmp_sentiment_metrics_summary 
ORDER BY Avg_Review_Score DESC;
-- negative review leaderboard
SELECT Category, Negative_Review_Count, Avg_Review_Score 
FROM tmp_sentiment_metrics_summary 
ORDER BY Avg_Review_Score ASC;

