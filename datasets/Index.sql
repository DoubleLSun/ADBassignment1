USE assignment1;

-- ============================================
-- Indexes for orders table
-- ============================================

-- For customer order lookup and JOIN with customers
CREATE INDEX idx_order_customer_id 
ON orders(customer_id);

-- For date range queries (monthly/yearly reports)
CREATE INDEX idx_order_purchase_date 
ON orders(order_purchase_timestamp);


-- ============================================
-- Indexes for order_items table
-- ============================================

-- For product sales analysis and JOIN with products
CREATE INDEX idx_order_items_product_id 
ON order_items(product_id);

-- For seller performance analysis
CREATE INDEX idx_order_items_seller_id 
ON order_items(seller_id);

-- ============================================
-- Indexes for products table
-- ============================================

-- For category-based product filtering
CREATE INDEX idx_product_category 
ON products(product_category_name);