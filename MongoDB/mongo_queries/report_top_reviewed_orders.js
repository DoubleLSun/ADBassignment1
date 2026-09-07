// Top 50 orders by average review score
// Wor klike sp_report_top_reviewed_orders in report_orderRegionAnalysis.sql
// This one don't show useful info cause many data have max review score with only 2 review
// copy the query to mongosh or run the query with the command:
// load("C:/Users/Jerry/Desktop/school/Git/gitclone/ADBassignment1/MongoDB/mongo_queries/report_top_reviewed_orders.js")

use("ecommerce_db");

db.orders_collection.aggregate([
  { $unwind: "$order_reviews" },
  {
    $group: {
      _id: "$order_id",
      Average_Review_Score: { $avg: "$order_reviews.review_score" },
      Review_Count: { $sum: 1 }
    }
  },
  {
    $lookup: {
      from: "orders_collection",
      localField: "_id",
      foreignField: "order_id",
      as: "order"
    }
  },
  { $unwind: "$order" },
  {
    $set: {
      Total_Purchase_Price: {
        $reduce: {
          input: "$order.order_items",
          initialValue: 0,
          in: { $add: ["$$value", { $ifNull: ["$$this.price", 0] }] }
        }
      }
    }
  },
  {
    $project: {
      _id: 0,
      Order_ID: "$_id",
      Average_Review_Score: { $round: ["$Average_Review_Score", 2] },
      Review_Count: 1,
      Total_Purchase_Price: 1
    }
  },
  { $sort: { Average_Review_Score: -1, Review_Count: -1, Order_ID: 1 } },
  { $limit: 50 }
]).forEach(printjson);
