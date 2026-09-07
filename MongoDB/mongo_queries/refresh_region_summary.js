// Rebuild the region report summary from the current PDM collections.
// Run after source collections change, or run transform_pdm.js first.

use("ecommerce_db");

db.customers_collection.aggregate([
  { $match: { customer_state: { $ne: null } } },
  { $group: { _id: "$customer_state", Customer_Count: { $sum: 1 } } },
  {
    $project: {
      _id: 0,
      Region: "$_id",
      Seller_Count: { $literal: 0 },
      Customer_Count: 1,
      Order_Count: { $literal: 0 },
      Total_Purchase_Price: { $literal: 0 }
    }
  },
  {
    $unionWith: {
      coll: "sellers_collection",
      pipeline: [
        { $match: { seller_state: { $ne: null } } },
        { $group: { _id: "$seller_state", Seller_Count: { $sum: 1 } } },
        {
          $project: {
            _id: 0,
            Region: "$_id",
            Seller_Count: 1,
            Customer_Count: { $literal: 0 },
            Order_Count: { $literal: 0 },
            Total_Purchase_Price: { $literal: 0 }
          }
        }
      ]
    }
  },
  {
    $unionWith: {
      coll: "orders_collection",
      pipeline: [
        {
          $lookup: {
            from: "customers_collection",
            localField: "customer_id",
            foreignField: "customer_id",
            pipeline: [{ $project: { _id: 0, customer_state: 1 } }],
            as: "customer"
          }
        },
        {
          $set: {
            customer_state: { $arrayElemAt: ["$customer.customer_state", 0] },
            purchase_total: {
              $reduce: {
                input: { $ifNull: ["$order_items", []] },
                initialValue: 0,
                in: { $add: ["$$value", { $ifNull: ["$$this.price", 0] }] }
              }
            }
          }
        },
        { $match: { customer_state: { $ne: null } } },
        {
          $group: {
            _id: "$customer_state",
            Order_Count: { $sum: 1 },
            Total_Purchase_Price: { $sum: "$purchase_total" }
          }
        },
        {
          $project: {
            _id: 0,
            Region: "$_id",
            Seller_Count: { $literal: 0 },
            Customer_Count: { $literal: 0 },
            Order_Count: 1,
            Total_Purchase_Price: 1
          }
        }
      ]
    }
  },
  {
    $group: {
      _id: "$Region",
      Seller_Count: { $sum: "$Seller_Count" },
      Customer_Count: { $sum: "$Customer_Count" },
      Order_Count: { $sum: "$Order_Count" },
      Total_Purchase_Price: { $sum: "$Total_Purchase_Price" }
    }
  },
  {
    $project: {
      _id: 0,
      Region: "$_id",
      Seller_Count: 1,
      Customer_Count: 1,
      Order_Count: 1,
      Total_Purchase_Price: 1
    }
  },
  { $out: "region_summary_collection" }
], { allowDiskUse: true });

db.region_summary_collection.createIndex({ Region: 1 }, { unique: true });
print("Region summary collection refreshed.");
