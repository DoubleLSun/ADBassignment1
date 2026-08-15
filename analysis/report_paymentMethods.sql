USE assignment1;

-- Checking
SHOW CREATE PROCEDURE sp_report_payments_methods;

DROP PROCEDURE IF EXISTS  sp_report_payments_methods;
-- customer payment preferences
DELIMITER $$
CREATE PROCEDURE sp_report_payment_methods()
BEGIN
    SELECT 
        payment_type AS Payment_Method,
        COUNT(distinct order_id) AS Transaction_Count,
        SUM(payment_value) AS Total_Collected,
        ROUND(AVG(payment_installments), 1) AS Avg_Installments
    FROM order_payments
    GROUP BY payment_type
    ORDER BY Transaction_Count DESC;
END$$
DELIMITER ;
