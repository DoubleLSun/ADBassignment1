// Report-supporting indexes for the final MongoDB collections.
// Run once with:
// load("C:/Users/Jerry/Desktop/school/Git/gitclone/ADBassignment1/MongoDB/mongo_queries/create_report_indexes.js")
//
// The primary lookup indexes are created by transform_pdm.js. These additional
// indexes support the optimized category and shipping reports.

use("ecommerce_db");

db.orders_collection.createIndex(
  { "order_items.category_name": 1 },
  { name: "order_items_category_name" }
);

db.orders_collection.createIndex(
  {
    order_status: 1,
    customer_id: 1,
    order_estimated_delivery_date: 1,
    order_delivered_customer_date: 1
  },
  {
    name: "delivered_shipping_report",
    partialFilterExpression: { order_status: "delivered" }
  }
);

print("Report indexes are ready.");
