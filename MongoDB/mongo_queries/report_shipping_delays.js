// Shipping delay dashboard by customer state
// Equivalent to report_shippingDelays.sql
// copy the query to mongosh or run the query with the command
// load("C:/Users/Jerry/Desktop/school/Git/gitclone/ADBassignment1/MongoDB/mongo_queries/report_shipping_delays.js")

use("ecommerce_db");

const minDelayDays = 5;

db.orders_collection.aggregate([
  { $match: { order_status: "delivered" } },
  {
    $set: {
      days_late: {
        $cond: [
          {
            $and: [
              { $ne: ["$order_estimated_delivery_date", null] },
              { $ne: ["$order_delivered_customer_date", null] }
            ]
          },
          {
            $dateDiff: {
              startDate: "$order_estimated_delivery_date",
              endDate: "$order_delivered_customer_date",
              unit: "day"
            }
          },
          0
        ]
      }
    }
  },
  { $match: { days_late: { $gte: minDelayDays } } },
  {
    $lookup: {
      from: "customers_collection",
      localField: "customer_id",
      foreignField: "customer_id",
      as: "customer"
    }
  },
  { $unwind: "$customer" },
  {
    $group: {
      _id: "$customer.customer_state",
      Total_Delayed_Orders: { $sum: 1 },
      Avg_Days_Late: { $avg: "$days_late" }
    }
  },
  {
    $project: {
      _id: 0,
      Customer_State: "$_id",
      Total_Delayed_Orders: 1,
      Avg_Days_Late: { $round: ["$Avg_Days_Late", 1] }
    }
  },
  { $sort: { Total_Delayed_Orders: -1 } }
]).forEach(printjson);
