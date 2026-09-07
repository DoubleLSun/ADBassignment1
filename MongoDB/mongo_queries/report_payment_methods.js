// Show Customer payment preferences from how much revenue by payment method
// work like report_paymentMethods.sql
// copy the query to mongosh or run the query with the command:
// load("C:/Users/Jerry/Desktop/school/Git/gitclone/ADBassignment1/MongoDB/mongo_queries/report_payment_methods.js")    

use("ecommerce_db");

db.orders_collection.aggregate([
  { $unwind: "$order_payments" },
  {
    $group: {
      _id: "$order_payments.payment_type",
      Order_Ids: { $addToSet: "$order_id" },
      Total_Collected: { $sum: { $ifNull: ["$order_payments.payment_value", 0] } },
      Avg_Installments: { $avg: "$order_payments.payment_installments" }
    }
  },
  {
    $project: {
      _id: 0,
      Payment_Method: "$_id",
      Transaction_Count: { $size: "$Order_Ids" },
      Total_Collected: 1,
      Avg_Installments: { $round: ["$Avg_Installments", 1] }
    }
  },
  { $sort: { Transaction_Count: -1 } }
], { allowDiskUse: true }).forEach(printjson);
