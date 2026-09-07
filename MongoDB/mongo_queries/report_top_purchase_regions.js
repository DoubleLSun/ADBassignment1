// Customer regions by total item purchase price.
// work like to sp_report_top_purchase_regions in report_orderRegionAnalysis.sql
// copy the query to mongosh or run the query with the command:
// load("C:/Users/Jerry/Desktop/school/Git/gitclone/ADBassignment1/MongoDB/mongo_queries/report_top_purchase_regions.js")   


use("ecommerce_db");

// Set these values before running the query.
const regionLimit = 20;
const sortDirection = -1; // -1 = highest purchase first, 1 = lowest purchase first

db.orders_collection.aggregate([
  {
    $lookup: {
      from: "customers_collection",
      localField: "customer_id",
      foreignField: "customer_id",
      as: "customer"
    }
  },
  { $unwind: "$customer" },
  { $unwind: "$order_items" },
  {
    $group: {
      _id: "$customer.customer_state",
      Order_Ids: { $addToSet: "$order_id" },
      Total_Purchase_Price: { $sum: { $ifNull: ["$order_items.price", 0] } }
    }
  },
  {
    $project: {
      _id: 0,
      Region: "$_id",
      Order_Count: { $size: "$Order_Ids" },
      Total_Purchase_Price: 1
    }
  },
  { $sort: { Total_Purchase_Price: sortDirection, Region: 1 } },
  { $limit: regionLimit }
], { allowDiskUse: true }).forEach(printjson);
