// Regional allocation using customer-state-first order lookup.
// Customer states are grouped before orders are joined by indexed customer_id.
// load("C:/Users/Jerry/Desktop/school/Git/gitclone/ADBassignment1/MongoDB/mongo_queries/report_region_allocation_state_first.js")

use("ecommerce_db");

const totalSellerCount = db.sellers_collection.countDocuments();
const totalCustomerCount = db.customers_collection.countDocuments();

db.customers_collection.aggregate([
  { $match: { customer_state: { $ne: null } } },
  { $group: { _id: "$customer_state", Customer_Count: { $sum: 1 } } },
  { $project: {
    _id: 0,
    Region: "$_id",
    Seller_Count: { $literal: 0 },
    Customer_Count: 1,
    Total_Purchase_Price: { $literal: 0 }
  } },
  { $unionWith: {
    coll: "sellers_collection",
    pipeline: [
      { $match: { seller_state: { $ne: null } } },
      { $group: { _id: "$seller_state", Seller_Count: { $sum: 1 } } },
      { $project: {
        _id: 0,
        Region: "$_id",
        Seller_Count: 1,
        Customer_Count: { $literal: 0 },
        Total_Purchase_Price: { $literal: 0 }
      } }
    ]
  } },
  { $unionWith: {
    coll: "customers_collection",
    pipeline: [
      { $match: { customer_state: { $ne: null } } },
      { $group: {
        _id: "$customer_state",
        customer_ids: { $push: "$customer_id" }
      } },
      { $lookup: {
        from: "orders_collection",
        localField: "customer_ids",
        foreignField: "customer_id",
        as: "orders"
      } },
      { $unwind: "$orders" },
      { $unwind: "$orders.order_items" },
      { $group: {
        _id: "$_id",
        Total_Purchase_Price: {
          $sum: { $ifNull: ["$orders.order_items.price", 0] }
        }
      } },
      { $project: {
        _id: 0,
        Region: "$_id",
        Seller_Count: { $literal: 0 },
        Customer_Count: { $literal: 0 },
        Total_Purchase_Price: 1
      } }
    ]
  } },
  { $group: {
    _id: "$Region",
    Seller_Count: { $sum: "$Seller_Count" },
    Customer_Count: { $sum: "$Customer_Count" },
    Total_Purchase_Price: { $sum: "$Total_Purchase_Price" }
  } },
  { $project: {
    _id: 0,
    Region: "$_id",
    Seller_Percentage: {
      $cond: [
        { $gt: [totalSellerCount, 0] },
        { $round: [{ $multiply: [{ $divide: ["$Seller_Count", totalSellerCount] }, 100] }, 2] },
        0
      ]
    },
    Customer_Percentage: {
      $cond: [
        { $gt: [totalCustomerCount, 0] },
        { $round: [{ $multiply: [{ $divide: ["$Customer_Count", totalCustomerCount] }, 100] }, 2] },
        0
      ]
    },
    Total_Purchase_Price: 1
  } },
  { $sort: { Region: 1 } }
], { allowDiskUse: true }).forEach(printjson);
