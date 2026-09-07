// Explain report performance with execution statistics.
// Run with:
// load("C:/Users/Jerry/Desktop/school/Git/gitclone/ADBassignment1/MongoDB/mongo_queries/explain_report_performance.js")
//
// Compare executionTimeMillis, totalDocsExamined, totalKeysExamined, and
// usedDisk before and after applying the report optimizations.

use("ecommerce_db");

function explainReport(name, collectionName, pipeline) {
  const result = db.getCollection(collectionName)
    .explain("executionStats")
    .aggregate(pipeline, { allowDiskUse: true });
  const stats = result.executionStats || {};

  print(name);
  printjson({
    executionTimeMillis: stats.executionTimeMillis,
    totalDocsExamined: stats.totalDocsExamined,
    totalKeysExamined: stats.totalKeysExamined,
    usedDisk: stats.usedDisk,
    nReturned: stats.nReturned
  });
  print("");
}

explainReport("Top product categories", "orders_collection", [
  { $project: { order_items: 1 } },
  { $unwind: "$order_items" },
  { $match: { "order_items.category_name": { $ne: null } } },
  {
    $group: {
      _id: "$order_items.category_name",
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
  { $sort: { Total_Revenue: -1 } },
  { $limit: 10 }
]);

explainReport("Payment methods", "orders_collection", [
  { $project: { order_id: 1, order_payments: 1 } },
  { $unwind: "$order_payments" },
  {
    $group: {
      _id: "$order_payments.payment_type",
      Order_Ids: { $addToSet: "$order_id" },
      Total_Collected: { $sum: { $ifNull: ["$order_payments.payment_value", 0] } },
      Avg_Installments: { $avg: "$order_payments.payment_installments" }
    }
  },
  { $sort: { Transaction_Count: -1 } }
]);

explainReport("Top purchase regions", "orders_collection", [
  { $project: { customer_state: 1, order_id: 1, order_items: 1 } },
  { $match: { customer_state: { $ne: null } } },
  { $unwind: "$order_items" },
  {
    $group: {
      _id: "$customer_state",
      Order_Ids: { $addToSet: "$order_id" },
      Total_Purchase_Price: { $sum: { $ifNull: ["$order_items.price", 0] } }
    }
  },
  { $sort: { Total_Purchase_Price: -1 } },
  { $limit: 20 }
]);

explainReport("Shipping delays", "orders_collection", [
  {
    $project: {
      order_status: 1,
      customer_state: 1,
      order_estimated_delivery_date: 1,
      order_delivered_customer_date: 1
    }
  },
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
  { $match: { days_late: { $gte: 5 } } },
  { $match: { customer_state: { $ne: null } } },
  { $group: { _id: "$customer_state", count: { $sum: 1 } } }
]);

explainReport("Top reviewed orders", "orders_collection", [
  { $project: { order_id: 1, order_reviews: 1, order_items: 1 } },
  {
    $set: {
      Total_Purchase_Price: {
        $reduce: {
          input: "$order_items",
          initialValue: 0,
          in: { $add: ["$$value", { $ifNull: ["$$this.price", 0] }] }
        }
      }
    }
  },
  { $unwind: "$order_reviews" },
  {
    $group: {
      _id: "$order_id",
      Average_Review_Score: { $avg: "$order_reviews.review_score" },
      Review_Count: { $sum: 1 },
      Total_Purchase_Price: { $first: "$Total_Purchase_Price" }
    }
  },
  { $sort: { Average_Review_Score: -1, Review_Count: -1, _id: 1 } },
  { $limit: 50 }
]);

print("Region allocation is best measured separately because it uses $unionWith across three collections.");
