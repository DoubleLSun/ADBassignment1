USE assignment1;

DROP PROCEDURE IF EXISTS sp_prepare_payment_metrics;
-- Pre-aggregates popularity and cash flow volume by payment type
DELIMITER $$
CREATE PROCEDURE sp_prepare_payment_metrics(IN p_payment_type VARCHAR(50))
COMMENT 'Infrastructure: Computes popularity and cash flow by payment type with optional filter'
BEGIN
    DROP TEMPORARY TABLE IF EXISTS tmp_payment_metrics_summary;
    -- Pre-calculate transaction popularity (how many) and volume (how much cash flow)
    CREATE TEMPORARY TABLE tmp_payment_metrics_summary AS
    SELECT 
        op.payment_type AS Payment_Type,
        COUNT(op.order_id) AS Total_Transactions,        -- Popularity: "How many times used"
        SUM(op.payment_value) AS Total_Cash_Flow,        -- Financial: "How much money processed"
        AVG(op.payment_installments) AS Avg_Installments -- Behavioral: "Average installment split"
    FROM olist_order_payments op
    WHERE (op.payment_type = p_payment_type OR p_payment_type IS NULL)
    GROUP BY op.payment_type;
END$$
DELIMITER ;
------------------------------------------------------------------------------ 
CALL sp_prepare_payment_metrics(NULL); -- Pull all transaction types

SELECT Payment_Type, Total_Transactions 
FROM tmp_payment_metrics_summary 
ORDER BY Total_Transactions DESC;

SELECT Payment_Type, Total_Cash_Flow 
FROM tmp_payment_metrics_summary 
ORDER BY Total_Cash_Flow DESC;

-- or specific payment types
CALL sp_prepare_payment_metrics('credit_card');
SELECT * FROM tmp_payment_metrics_summary;


