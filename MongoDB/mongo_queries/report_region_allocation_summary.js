// Seller/customer allocation from the maintained region summary collection.
// Refresh the collection with refresh_region_summary.js after source data changes.

use("ecommerce_db");

const totalSellerCount = db.sellers_collection.countDocuments();
const totalCustomerCount = db.customers_collection.countDocuments();

db.region_summary_collection.aggregate([
  {
    $set: {
      Seller_Percentage: {
        $cond: [
          { $gt: [totalSellerCount, 0] },
          { $round: [{ $multiply: [{ $divide: ["$Seller_Count", totalSellerCount] }, 100] }, 2] },
          null
        ]
      },
      Customer_Percentage: {
        $cond: [
          { $gt: [totalCustomerCount, 0] },
          { $round: [{ $multiply: [{ $divide: ["$Customer_Count", totalCustomerCount] }, 100] }, 2] },
          null
        ]
      }
    }
  },
  { $sort: { Region: 1 } }
], { allowDiskUse: true }).forEach(printjson);
