// Show Top selling product categories
// work like report_categories.sql
// this one have to wait a bit longer to run 
// copy the query to mongosh or run the query with the command: 
// load("C:/Users/Jerry/Desktop/school/Git/gitclone/ADBassignment1/MongoDB/mongo_queries/report_categories.js")

use("ecommerce_db");

const limit = 10;

db.orders_collection.aggregate([
  { $unwind: "$order_items" },
  {
    $lookup: {
      from: "products_collection",
      localField: "order_items.product_id",
      foreignField: "product_id",
      as: "product"
    }
  },
  { $unwind: "$product" },
  { $match: { "product.category.category_name": { $ne: null } } },
  {
    $group: {
      _id: "$product.category.category_name",
      Total_Units_Sold: { $sum: 1 },
      Total_Revenue: {
        $sum: {
          $add: [
            { $ifNull: ["$order_items.price", 0] },
            { $ifNull: ["$order_items.freight_value", 0] }
          ]
        }
      }
    }
  },
  {
    $project: {
      _id: 0,
      Category: "$_id",
      Total_Units_Sold: 1,
      Total_Revenue: 1
    }
  },
  { $sort: { Total_Revenue: -1 } },
  { $limit: limit }
], { allowDiskUse: true }).forEach(printjson);
