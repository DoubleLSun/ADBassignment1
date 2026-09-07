/**
 * transform_pdm.js
 * =============================================================================
 * UECS3203 Advanced Database Systems - Assignment 2
 * MongoDB Aggregation Pipeline: Staging to Physical Data Model (PDM)
 *
 * This script transforms the 9 raw staging collections into the finalized
 * 5-collection Physical Data Model (PDM) design:
 *   1. products_collection     (with embedded category lookup & dimensions)
 *   2. customers_collection    (referenced high-growth collection)
 *   3. sellers_collection      (referenced merchant collection)
 *   4. geolocation_collection  (with 2dsphere GeoJSON Point & Decimal128 coords)
 *   5. orders_collection       (composite core with embedded items, payments, reviews)
 *
 * It enforces:
 *   - Strict BSON typing (Decimal128 for financial/coordinates, Int32, Date)
 *   - Graceful null/empty handling using $convert
 *   - High-performance staging indexes to optimize $lookup execution
 *   - Production compound, multikey, and geospatial indexes
 * =============================================================================
 */

const startTime = new Date();
print("\n===============================================================");
print("=== Starting MongoDB Physical Data Model (PDM) Transformation ===");
print("=== Target Database: " + db.getName() + " ===");
print("===============================================================\n");

// -----------------------------------------------------------------------------
// STEP 0: PRE-AGGREGATION INDEXES ON STAGING COLLECTIONS
// -----------------------------------------------------------------------------
// Critical performance step: Building indexes on foreign key `order_id` in staging
// prevents 11+ billion comparisons during $lookup stages across 99k+ orders.
print("[STEP 0/5] Creating performance indexes on staging collections for $lookup...");
try {
  db.stage_order_items.createIndex({ order_id: 1 });
  db.stage_order_payments.createIndex({ order_id: 1 });
  db.stage_order_reviews.createIndex({ order_id: 1 });
  db.stage_category_translation.createIndex({ product_category_name: 1 });
  db.stage_products.createIndex({ product_category_name: 1 });
  print("   ✓ Pre-aggregation staging indexes ready.\n");
} catch (err) {
  print("   ! Note on staging indexes: " + err.message + "\n");
}

// -----------------------------------------------------------------------------
// STEP 1: TRANSFORM & EMBED PRODUCTS COLLECTION
// -----------------------------------------------------------------------------
print("[STEP 1/5] Transforming stage_products -> products_collection...");
print("           Joining stage_category_translation and embedding dimensions/category...");

db.stage_products.aggregate([
  {
    $lookup: {
      from: "stage_category_translation",
      localField: "product_category_name",
      foreignField: "product_category_name",
      as: "cat_lookup"
    }
  },
  {
    $project: {
      _id: 1,
      product_id: "$product_id",
      category: {
        category_name: "$product_category_name",
        category_name_english: {
          $ifNull: [
            { $arrayElemAt: ["$cat_lookup.product_category_name_english", 0] },
            null
          ]
        }
      },
      product_name_length: {
        $convert: { input: "$product_name_lenght", to: "int", onError: null, onNull: null }
      },
      product_description_length: {
        $convert: { input: "$product_description_lenght", to: "int", onError: null, onNull: null }
      },
      product_photos_qty: {
        $convert: { input: "$product_photos_qty", to: "int", onError: null, onNull: null }
      },
      dimensions: {
        weight_g: {
          $convert: { input: "$product_weight_g", to: "int", onError: null, onNull: null }
        },
        length_cm: {
          $convert: { input: "$product_length_cm", to: "int", onError: null, onNull: null }
        },
        height_cm: {
          $convert: { input: "$product_height_cm", to: "int", onError: null, onNull: null }
        },
        width_cm: {
          $convert: { input: "$product_width_cm", to: "int", onError: null, onNull: null }
        }
      }
    }
  },
  { $out: "products_collection" }
], { allowDiskUse: true });

print("   Creating indexes on products_collection...");
db.products_collection.createIndex({ product_id: 1 }, { unique: true });
db.products_collection.createIndex({ "category.category_name": 1 });
db.products_collection.createIndex({ "category.category_name_english": 1 });
print("   ✓ products_collection successfully created.\n");

// -----------------------------------------------------------------------------
// STEP 2: TRANSFORM CUSTOMERS & SELLERS COLLECTIONS
// -----------------------------------------------------------------------------
print("[STEP 2/5] Transforming stage_customers & stage_sellers...");

db.stage_customers.aggregate([
  {
    $project: {
      _id: 1,
      customer_id: "$customer_id",
      customer_unique_id: "$customer_unique_id",
      customer_zip_code_prefix: { $toString: "$customer_zip_code_prefix" },
      customer_city: "$customer_city",
      customer_state: "$customer_state"
    }
  },
  { $out: "customers_collection" }
], { allowDiskUse: true });

db.customers_collection.createIndex({ customer_id: 1 }, { unique: true });
db.customers_collection.createIndex({ customer_unique_id: 1 });
db.customers_collection.createIndex({ customer_zip_code_prefix: 1 });
db.customers_collection.createIndex({ customer_city: 1 });
db.customers_collection.createIndex({ customer_state: 1 });
print("   ✓ customers_collection successfully created.");

db.stage_sellers.aggregate([
  {
    $project: {
      _id: 1,
      seller_id: "$seller_id",
      seller_zip_code_prefix: { $toString: "$seller_zip_code_prefix" },
      seller_city: "$seller_city",
      seller_state: "$seller_state"
    }
  },
  { $out: "sellers_collection" }
], { allowDiskUse: true });

db.sellers_collection.createIndex({ seller_id: 1 }, { unique: true });
db.sellers_collection.createIndex({ seller_zip_code_prefix: 1 });
db.sellers_collection.createIndex({ seller_city: 1 });
db.sellers_collection.createIndex({ seller_state: 1 });
print("   ✓ sellers_collection successfully created.\n");

// -----------------------------------------------------------------------------
// STEP 3: TRANSFORM GEOLOCATION COLLECTION (GEOJSON & DECIMAL128)
// -----------------------------------------------------------------------------
print("[STEP 3/5] Transforming stage_geolocation -> geolocation_collection...");
print("           Building GeoJSON 2dsphere coordinates and Decimal128 bounds...");

db.stage_geolocation.aggregate([
  {
    $project: {
      _id: 1,
      geolocation_zip_code_prefix: { $toString: "$geolocation_zip_code_prefix" },
      geolocation_lat: {
        $convert: { input: "$geolocation_lat", to: "decimal", onError: null, onNull: null }
      },
      geolocation_lng: {
        $convert: { input: "$geolocation_lng", to: "decimal", onError: null, onNull: null }
      },
      geolocation_city: "$geolocation_city",
      geolocation_state: "$geolocation_state",
      location: {
        type: "Point",
        coordinates: [
          { $convert: { input: "$geolocation_lng", to: "double", onError: 0.0, onNull: 0.0 } },
          { $convert: { input: "$geolocation_lat", to: "double", onError: 0.0, onNull: 0.0 } }
        ]
      }
    }
  },
  { $out: "geolocation_collection" }
], { allowDiskUse: true });

print("   Creating indexes on geolocation_collection...");
db.geolocation_collection.createIndex({ geolocation_zip_code_prefix: 1 });
db.geolocation_collection.createIndex({ "location": "2dsphere" });
db.geolocation_collection.createIndex({ geolocation_city: 1 });
db.geolocation_collection.createIndex({ geolocation_state: 1 });
print("   ✓ geolocation_collection successfully created.\n");

// -----------------------------------------------------------------------------
// STEP 4: TRANSFORM & EMBED ORDERS COLLECTION (THE CORE ECOSYSTEM)
// -----------------------------------------------------------------------------
print("[STEP 4/5] Compiling orders_collection (embedding items, payments, reviews)...");
print("           Executing 3-way $lookup and nested array $map transformations...");

db.stage_orders.aggregate([
  // 1. Join Order Items (1-to-many)
  {
    $lookup: {
      from: "stage_order_items",
      localField: "order_id",
      foreignField: "order_id",
      as: "raw_items"
    }
  },
  // 2. Join Order Payments (1-to-many)
  {
    $lookup: {
      from: "stage_order_payments",
      localField: "order_id",
      foreignField: "order_id",
      as: "raw_payments"
    }
  },
  // 3. Join Order Reviews (1-to-many)
  {
    $lookup: {
      from: "stage_order_reviews",
      localField: "order_id",
      foreignField: "order_id",
      as: "raw_reviews"
    }
  },
  // 4. Map BSON formatting, casting, and nested subdocument schema
  {
    $project: {
      _id: 1,
      order_id: "$order_id",
      customer_id: "$customer_id",
      order_status: "$order_status",
      order_purchase_timestamp: {
        $convert: { input: "$order_purchase_timestamp", to: "date", onError: null, onNull: null }
      },
      order_approved_at: {
        $convert: { input: "$order_approved_at", to: "date", onError: null, onNull: null }
      },
      order_delivered_carrier_date: {
        $convert: { input: "$order_delivered_carrier_date", to: "date", onError: null, onNull: null }
      },
      order_delivered_customer_date: {
        $convert: { input: "$order_delivered_customer_date", to: "date", onError: null, onNull: null }
      },
      order_estimated_delivery_date: {
        $convert: { input: "$order_estimated_delivery_date", to: "date", onError: null, onNull: null }
      },
      
      // Nested Array 1: order_items
      order_items: {
        $map: {
          input: "$raw_items",
          as: "item",
          in: {
            order_item_id: {
              $convert: { input: "$$item.order_item_id", to: "int", onError: null, onNull: null }
            },
            product_id: "$$item.product_id",
            seller_id: "$$item.seller_id",
            shipping_limit_date: {
              $convert: { input: "$$item.shipping_limit_date", to: "date", onError: null, onNull: null }
            },
            price: {
              $convert: { input: "$$item.price", to: "decimal", onError: null, onNull: null }
            },
            freight_value: {
              $convert: { input: "$$item.freight_value", to: "decimal", onError: null, onNull: null }
            }
          }
        }
      },

      // Nested Array 2: order_payments
      order_payments: {
        $map: {
          input: "$raw_payments",
          as: "pmt",
          in: {
            payment_sequential: {
              $convert: { input: "$$pmt.payment_sequential", to: "int", onError: null, onNull: null }
            },
            payment_type: "$$pmt.payment_type",
            payment_installments: {
              $convert: { input: "$$pmt.payment_installments", to: "int", onError: null, onNull: null }
            },
            payment_value: {
              $convert: { input: "$$pmt.payment_value", to: "decimal", onError: null, onNull: null }
            }
          }
        }
      },

      // Nested Array 3: order_reviews
      order_reviews: {
        $map: {
          input: "$raw_reviews",
          as: "rev",
          in: {
            review_id: "$$rev.review_id",
            review_score: {
              $convert: { input: "$$rev.review_score", to: "int", onError: null, onNull: null }
            },
            review_comment_title: { $ifNull: ["$$rev.review_comment_title", ""] },
            review_comment_message: { $ifNull: ["$$rev.review_comment_message", ""] },
            review_creation_date: {
              $convert: { input: "$$rev.review_creation_date", to: "date", onError: null, onNull: null }
            },
            review_answer_timestamp: {
              $convert: { input: "$$rev.review_answer_timestamp", to: "date", onError: null, onNull: null }
            }
          }
        }
      }
    }
  },
  { $out: "orders_collection" }
], { allowDiskUse: true });

print("   Creating production compound and multikey indexes on orders_collection...");
db.orders_collection.createIndex({ order_id: 1 }, { unique: true });
db.orders_collection.createIndex({ customer_id: 1, order_purchase_timestamp: -1 });
db.orders_collection.createIndex({ order_status: 1, order_purchase_timestamp: -1 });
db.orders_collection.createIndex({ "order_items.product_id": 1 });
db.orders_collection.createIndex({ "order_items.seller_id": 1 });
db.orders_collection.createIndex({ "order_payments.payment_type": 1 });
db.orders_collection.createIndex({ "order_reviews.review_score": 1 });
print("   ✓ orders_collection successfully created.\n");

print("[STEP 5/5] Refreshing region_summary_collection...");
db.customers_collection.aggregate([
  { $match: { customer_state: { $ne: null } } },
  { $group: { _id: "$customer_state", Customer_Count: { $sum: 1 } } },
  { $project: {
    _id: 0, Region: "$_id", Seller_Count: { $literal: 0 }, Customer_Count: 1,
    Order_Count: { $literal: 0 }, Total_Purchase_Price: { $literal: 0 }
  } },
  { $unionWith: { coll: "sellers_collection", pipeline: [
    { $match: { seller_state: { $ne: null } } },
    { $group: { _id: "$seller_state", Seller_Count: { $sum: 1 } } },
    { $project: {
      _id: 0, Region: "$_id", Seller_Count: 1, Customer_Count: { $literal: 0 },
      Order_Count: { $literal: 0 }, Total_Purchase_Price: { $literal: 0 }
    } }
  ] } },
  { $unionWith: { coll: "orders_collection", pipeline: [
    { $lookup: {
      from: "customers_collection", localField: "customer_id",
      foreignField: "customer_id",
      pipeline: [{ $project: { _id: 0, customer_state: 1 } }], as: "customer"
    } },
    { $set: {
      customer_state: { $arrayElemAt: ["$customer.customer_state", 0] },
      purchase_total: { $reduce: {
        input: { $ifNull: ["$order_items", []] }, initialValue: 0,
        in: { $add: ["$$value", { $ifNull: ["$$this.price", 0] }] }
      } }
    } },
    { $match: { customer_state: { $ne: null } } },
    { $group: {
      _id: "$customer_state", Order_Count: { $sum: 1 },
      Total_Purchase_Price: { $sum: "$purchase_total" }
    } },
    { $project: {
      _id: 0, Region: "$_id", Seller_Count: { $literal: 0 },
      Customer_Count: { $literal: 0 }, Order_Count: 1, Total_Purchase_Price: 1
    } }
  ] } },
  { $group: {
    _id: "$Region", Seller_Count: { $sum: "$Seller_Count" },
    Customer_Count: { $sum: "$Customer_Count" }, Order_Count: { $sum: "$Order_Count" },
    Total_Purchase_Price: { $sum: "$Total_Purchase_Price" }
  } },
  { $project: {
    _id: 0, Region: "$_id", Seller_Count: 1, Customer_Count: 1, Order_Count: 1,
    Total_Purchase_Price: 1
  } },
  { $out: "region_summary_collection" }
], { allowDiskUse: true });
db.region_summary_collection.createIndex({ Region: 1 }, { unique: true });
print("   ✓ region_summary_collection refreshed.\n");

// -----------------------------------------------------------------------------
// STEP 6: VERIFICATION AND SUMMARY
// -----------------------------------------------------------------------------
const endTime = new Date();
const durationSeconds = ((endTime - startTime) / 1000).toFixed(2);

print("===============================================================");
print("=== FINAL PHYSICAL DATA MODEL (PDM) DEPLOYMENT SUMMARY ===");
print("===============================================================");
print("Execution Time: " + durationSeconds + " seconds\n");

const collections = [
  "products_collection",
  "customers_collection",
  "sellers_collection",
  "geolocation_collection",
  "orders_collection"
];

collections.forEach(col => {
  const count = db[col].countDocuments();
  const indexes = db[col].getIndexes().map(idx => idx.name).join(", ");
  print(" Collection: " + col.padEnd(25) + " | Documents: " + count.toString().padStart(9) + " | Indexes: " + indexes);
});

print("\n===============================================================");
print("=== All collections compiled and indexed to production PDM! ===");
print("===============================================================\n");
