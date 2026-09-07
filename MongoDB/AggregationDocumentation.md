# MongoDB Physical Data Model (PDM) Aggregation Pipeline & Ingestion Architecture

**Course**: UECS3203 Advanced Database Systems  
**Module**: Assignment 2 (NoSQL Data Model Design and Development)  
**Database**: `ecommerce_db`  
**Pipeline Orchestration**: `ImportScript.bat` & `transform_pdm.js`

---

## 1. Executive Summary & Design Overview

The goal of this migration is to transition the normalized 3NF relational schema from the Brazilian E-Commerce dataset (9 distinct tables) into an enterprise-grade, high-performance MongoDB **Physical Data Model (PDM)** consisting of **5 core collections**:

```
Relational Sources (9 Tables / CSVs)               Target MongoDB PDM (5 Collections)
┌──────────────────────────────────────┐          ┌─────────────────────────────────────────┐
│ • olist_orders_dataset.csv           │ ───────► │ 1. orders_collection                    │
│ • olist_order_items_dataset.csv      │          │    ├── embedded: order_items (Array)    │
│ • olist_order_payments_dataset.csv   │          │    ├── embedded: order_payments (Array) │
│ • olist_order_reviews_dataset.csv    │          │    └── embedded: order_reviews (Array)  │
├──────────────────────────────────────┤          ├─────────────────────────────────────────┤
│ • olist_products_dataset.csv         │ ───────► │ 2. products_collection                 │
│ • product_category_name_translation  │          │    ├── embedded: category (Subdoc)      │
│                                      │          │    └── embedded: dimensions (Subdoc)    │
├──────────────────────────────────────┤          ├─────────────────────────────────────────┤
│ • olist_customers_dataset.csv        │ ───────► │ 3. customers_collection                 │
├──────────────────────────────────────┤          ├─────────────────────────────────────────┤
│ • olist_sellers_dataset.csv          │ ───────► │ 4. sellers_collection                   │
├──────────────────────────────────────┤          ├─────────────────────────────────────────┤
│ • olist_geolocation_dataset.csv      │ ───────► │ 5. geolocation_collection               │
│                                      │          │    └── embedded: GeoJSON Point          │
└──────────────────────────────────────┘          └─────────────────────────────────────────┘
```

### Key Architectural Decisions:
1. **Bounded Embedding for Orders**: An individual order has a strictly bounded cardinality (average 1.13 items, 1–3 payments, and 1 review). Embedding these child entities directly inside `orders_collection` collapses 4 relational tables into a single document (~2.5 KB average), fitting well within WiredTiger's single cache page read and well under MongoDB's 16MB document boundary limit. This eliminates expensive runtime `$lookup` multi-table joins during critical read paths.
2. **Hybrid Referencing for Master Catalogs**: `customers_collection`, `sellers_collection`, and `products_collection` are maintained as standalone collections and cross-referenced via string IDs (`customer_id`, `seller_id`, `product_id`). This avoids document duplication, unbounded array growth anti-patterns, and catastrophic catalog write cascades.
3. **Strict BSON Data Types**: All financial values (`price`, `freight_value`, `payment_value`) are cast to `BSON_Decimal128` to prevent IEEE 754 floating-point inaccuracies. All timestamps are cast to `BSON_Date` (`ISODate`), and geographic locations are structured as standard GeoJSON `Point` coordinates `[lng, lat]` supporting `2dsphere` spatial indexes.

---

## 2. Ingestion & Pre-Aggregation Index Optimization

### Ingestion Flow (`ImportScript.bat`)
The Windows batch file automates the sequential ingestion using `mongoimport`:
```batch
mongoimport --db="ecommerce_db" --collection="stage_orders" --type=csv --headerline --drop --file="..."
... (repeated for all 9 CSV files)
```
Each staging collection is prefixed with `stage_` and imported with `--drop` to guarantee idempotency.

### The Staging Indexing Requirement
Without indexing the foreign key `order_id` in staging collections, performing a 3-way `$lookup` on 99,441 orders against 112,650 items, 103,886 payments, and 99,224 reviews would trigger **11.2 billion full-scan comparisons**, resulting in query timeouts or memory exhaustion.

Before running the core aggregation pipelines, `transform_pdm.js` enforces:
```javascript
db.stage_order_items.createIndex({ order_id: 1 });
db.stage_order_payments.createIndex({ order_id: 1 });
db.stage_order_reviews.createIndex({ order_id: 1 });
db.stage_category_translation.createIndex({ product_category_name: 1 });
db.stage_products.createIndex({ product_category_name: 1 });
```
This reduces `$lookup` computational complexity from $O(N \times M)$ down to $O(N \log M)$, allowing the entire 100,000-order aggregation to complete in seconds.

---

## 3. Aggregation Pipelines to Final PDM Design

### Pipeline 1: `products_collection`

#### Goal:
Merge Portuguese category names with their English translations and bundle physical dimensions into structured subdocuments.

#### Aggregation Pipeline:
```javascript
db.stage_products.aggregate([
  // Stage 1: Left Outer Join with Category Translation
  {
    $lookup: {
      from: "stage_category_translation",
      localField: "product_category_name",
      foreignField: "product_category_name",
      as: "cat_lookup"
    }
  },
  // Stage 2: Shape Document, Cast Types, and Build Embedded Subdocuments
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
  // Stage 3: Materialize into Final Production Collection
  { $out: "products_collection" }
], { allowDiskUse: true });

// Production Indexes:
db.products_collection.createIndex({ product_id: 1 }, { unique: true });
db.products_collection.createIndex({ "category.category_name": 1 });
db.products_collection.createIndex({ "category.category_name_english": 1 });
```

---

### Pipeline 2: `customers_collection` & `sellers_collection`

#### Goal:
Extract and format customer and merchant master records while enforcing unique root identifiers and indexing geographical routing fields.

#### Aggregation Pipelines:
```javascript
// Customers Collection
db.stage_customers.aggregate([
  {
    $project: {
      _id: 1,
      customer_id: "$customer_id",
      customer_unique_id: "$customer_unique_id",
      customer_zip_code_prefix: "$customer_zip_code_prefix",
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

// Sellers Collection
db.stage_sellers.aggregate([
  {
    $project: {
      _id: 1,
      seller_id: "$seller_id",
      seller_zip_code_prefix: "$seller_zip_code_prefix",
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
```

---

### Pipeline 3: `geolocation_collection`

#### Goal:
Preserve IEEE 754-2008 high-precision coordinates (`Decimal128`) while simultaneously synthesizing native GeoJSON `Point` objects (`[Double(lng), Double(lat)]`) to empower MongoDB `2dsphere` spatial proximity searches.

#### Aggregation Pipeline:
```javascript
db.stage_geolocation.aggregate([
  {
    $project: {
      _id: 1,
      geolocation_zip_code_prefix: "$geolocation_zip_code_prefix",
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

// Production Indexes:
db.geolocation_collection.createIndex({ geolocation_zip_code_prefix: 1 });
db.geolocation_collection.createIndex({ "location": "2dsphere" });
db.geolocation_collection.createIndex({ geolocation_city: 1 });
db.geolocation_collection.createIndex({ geolocation_state: 1 });
```

---

### Pipeline 4: `orders_collection` (The Unified Transaction Ecosystem)

#### Goal:
Execute a 3-way consolidation joining `stage_orders` with items, payment transactions, and customer reviews, mapping each child relation into an embedded array of subdocuments with strict BSON type casting.

#### Aggregation Pipeline:
```javascript
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
      
      // Nested Array 1: order_items (Financial values cast to Decimal128)
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

      // Nested Array 2: order_payments (Installments as Int32, Value as Decimal128)
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

      // Nested Array 3: order_reviews (Score as Int32, Dates as Date, Strings normalized)
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
  // Stage 5: Output to Target Collection
  { $out: "orders_collection" }
], { allowDiskUse: true });

// Production Indexes:
db.orders_collection.createIndex({ order_id: 1 }, { unique: true });
db.orders_collection.createIndex({ customer_id: 1, order_purchase_timestamp: -1 });
db.orders_collection.createIndex({ order_status: 1, order_purchase_timestamp: -1 });
db.orders_collection.createIndex({ "order_items.product_id": 1 });
db.orders_collection.createIndex({ "order_items.seller_id": 1 });
db.orders_collection.createIndex({ "order_payments.payment_type": 1 });
db.orders_collection.createIndex({ "order_reviews.review_score": 1 });
```

---

## 4. Indexing & Query Pattern Matrix

| Collection | Index Key | Index Type | Purpose / Query Pattern |
| :--- | :--- | :--- | :--- |
| `orders_collection` | `{ order_id: 1 }` | Unique / Primary | O(1) order lookup and shard key |
| `orders_collection` | `{ customer_id: 1, order_purchase_timestamp: -1 }` | Compound | Fetch customer order history sorted by latest |
| `orders_collection` | `{ order_status: 1, order_purchase_timestamp: -1 }` | Compound | Dashboard operational filtering (e.g. pending shipments) |
| `orders_collection` | `{ "order_items.product_id": 1 }` | Multikey | Product sales & inventory fulfillment analytics |
| `orders_collection` | `{ "order_items.seller_id": 1 }` | Multikey | Merchant revenue and performance tracking |
| `orders_collection` | `{ "order_payments.payment_type": 1 }` | Multikey | Financial transaction and payment breakdown |
| `orders_collection` | `{ "order_reviews.review_score": 1 }` | Multikey | Customer satisfaction and rating distributions |
| `products_collection` | `{ product_id: 1 }` | Unique | Product catalog lookup |
| `products_collection` | `{ "category.category_name": 1 }` | Standard | Category-based catalog browsing |
| `geolocation_collection` | `{ "location": "2dsphere" }` | Geospatial | `$nearSphere`, `$geoWithin` delivery radius queries |
| `geolocation_collection` | `{ geolocation_zip_code_prefix: 1 }` | Standard | Postal route partitioning and address lookup |
| `customers_collection` | `{ customer_id: 1 }` | Unique | Customer identity lookup |
| `sellers_collection` | `{ seller_id: 1 }` | Unique | Merchant profile lookup |

---

## 5. Execution Instructions

### Running via Windows Batch:
Simply double-click `ImportScript.bat` in File Explorer, or open a Command Prompt and run:
```cmd
:: Go to ImportScript.bat 
ImportScript.bat
```

### Running Manually via Command Line:
1. **Import CSVs into Staging**:
   ```cmd
   mongoimport --db=ecommerce_db --collection=stage_orders --type=csv --headerline --drop --file="..\ADBassignment1\datasets\olist_orders_dataset.csv"
   mongoimport --db=ecommerce_db --collection=stage_order_items --type=csv --headerline --drop --file="..\ADBassignment1\datasets\olist_order_items_dataset.csv"
   mongoimport --db=ecommerce_db --collection=stage_order_payments --type=csv --headerline --drop --file="..\ADBassignment1\datasets\olist_order_payments_dataset.csv"
   mongoimport --db=ecommerce_db --collection=stage_order_reviews --type=csv --headerline --drop --file="..\ADBassignment1\datasets\olist_order_reviews_dataset.csv"
   mongoimport --db=ecommerce_db --collection=stage_products --type=csv --headerline --drop --file="..\ADBassignment1\datasets\olist_products_dataset.csv"
   mongoimport --db=ecommerce_db --collection=stage_category_translation --type=csv --headerline --drop --file="..\ADBassignment1\datasets\product_category_name_translation.csv"
   mongoimport --db=ecommerce_db --collection=stage_customers --type=csv --headerline --drop --file="..\ADBassignment1\datasets\olist_customers_dataset.csv"
   mongoimport --db=ecommerce_db --collection=stage_sellers --type=csv --headerline --drop --file="..\ADBassignment1\datasets\olist_sellers_dataset.csv"
   mongoimport --db=ecommerce_db --collection=stage_geolocation --type=csv --headerline --drop --file="..\ADBassignment1\datasets\olist_geolocation_dataset.csv"
   ```

2. **Execute Aggregation Pipeline**:
   ```cmd
   mongosh "ecommerce_db" "transform_pdm.js"
   ```
