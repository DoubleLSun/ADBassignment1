// Top purchase regions using a state-first customer-to-orders lookup.
// The customer_id index on orders_collection is used by $lookup.
// load("C:/Users/Jerry/Desktop/school/Git/gitclone/ADBassignment1/MongoDB/mongo_queries/report_top_purchase_regions_state_first.js")

use("ecommerce_db");

const regionLimit = 20;
const sortDirection = -1; // -1 = highest purchase first, 1 = lowest purchase first

db.customers_collection.aggregate([
  { $match: { customer_state: { $ne: null } } },
  {
    $group: {
      _id: "$customer_state",
      customer_ids: { $push: "$customer_id" }
    }
  },
  {
    $lookup: {
      from: "orders_collection",
      localField: "customer_ids",
      foreignField: "customer_id",
      as: "orders"
    }
  },
  { $unwind: "$orders" },
  { $unwind: "$orders.order_items" },
  {
    $group: {
      _id: "$_id",
      Order_Ids: { $addToSet: "$orders.order_id" },
      Total_Purchase_Price: {
        $sum: { $ifNull: ["$orders.order_items.price", 0] }
      }
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
