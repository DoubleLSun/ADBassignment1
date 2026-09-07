// Top purchase regions from the maintained region summary collection.
// Refresh the collection with refresh_region_summary.js after source data changes.

use("ecommerce_db");

const regionLimit = 20;
const sortDirection = -1; // -1 = highest purchase first, 1 = lowest purchase first

db.region_summary_collection.aggregate([
  {
    $project: {
      _id: 0,
      Region: 1,
      Order_Count: 1,
      Total_Purchase_Price: 1
    }
  },
  { $sort: { Total_Purchase_Price: sortDirection, Region: 1 } },
  { $limit: regionLimit }
], { allowDiskUse: true }).forEach(printjson);
