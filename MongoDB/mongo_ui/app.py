from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from time import perf_counter
from typing import Any

import pandas as pd
import streamlit as st
from bson.decimal128 import Decimal128
from pymongo import MongoClient
from pymongo.errors import PyMongoError, ServerSelectionTimeoutError


st.set_page_config(
    page_title="E-Commerce MongoDB Reports",
    page_icon="M",
    layout="wide",
)

REPORTS = {
    "Top purchase regions": "Purchase totals grouped by customer state",
    "Shipping delays": "Delivered orders exceeding a delay threshold",
    "Payment methods": "Collected value and installments by payment type",
    "Top product categories": "Units sold and revenue by category",
    "Top reviewed orders": "Orders ranked by average review score",
    "Region allocation": "Seller and customer distribution by state",
}
SUMMARY_REPORTS = {
    "Top purchase regions (summary)": "Top purchase regions",
    "Region allocation (summary)": "Region allocation",
}


def get_database(uri: str, database_name: str):
    client = MongoClient(uri, serverSelectionTimeoutMS=3000)
    client.admin.command("ping")
    return client[database_name]


def money(value: Any) -> Any:
    if isinstance(value, Decimal128):
        return value.to_decimal()
    return value


def normalize_value(value: Any) -> Any:
    if isinstance(value, Decimal128):
        return float(value.to_decimal())
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, datetime):
        return value.replace(tzinfo=None)
    if isinstance(value, list):
        return [normalize_value(item) for item in value]
    if isinstance(value, dict):
        return {key: normalize_value(item) for key, item in value.items()}
    return value


def dataframe(rows: list[dict[str, Any]]) -> pd.DataFrame:
    return pd.DataFrame([{key: normalize_value(value) for key, value in row.items()} for row in rows])


def purchase_regions(limit: int, direction: int) -> list[dict[str, Any]]:
    return list(db.orders_collection.aggregate([
        {"$project": {"customer_id": 1, "order_id": 1, "order_items": 1}},
        {"$lookup": {
            "from": "customers_collection",
            "localField": "customer_id",
            "foreignField": "customer_id",
            "as": "customer",
        }},
        {"$unwind": "$customer"},
        {"$unwind": "$order_items"},
        {"$group": {
            "_id": "$customer.customer_state",
            "Order_Ids": {"$addToSet": "$order_id"},
            "Total_Purchase_Price": {"$sum": {"$ifNull": ["$order_items.price", 0]}},
        }},
        {"$project": {
            "_id": 0,
            "Region": "$_id",
            "Order_Count": {"$size": "$Order_Ids"},
            "Total_Purchase_Price": 1,
        }},
        {"$sort": {"Total_Purchase_Price": direction, "Region": 1}},
        {"$limit": limit},
    ], allowDiskUse=True))


def purchase_regions_summary(limit: int, direction: int) -> list[dict[str, Any]]:
    return list(db.region_summary_collection.aggregate([
        {"$project": {
            "_id": 0,
            "Region": 1,
            "Order_Count": 1,
            "Total_Purchase_Price": 1,
        }},
        {"$sort": {"Total_Purchase_Price": direction, "Region": 1}},
        {"$limit": limit},
    ], allowDiskUse=True))


def shipping_delays(min_days: int) -> list[dict[str, Any]]:
    return list(db.orders_collection.aggregate([
        {"$project": {
            "order_status": 1,
            "customer_id": 1,
            "order_estimated_delivery_date": 1,
            "order_delivered_customer_date": 1,
        }},
        {"$match": {"order_status": "delivered"}},
        {"$set": {"days_late": {"$cond": [
            {"$and": [
                {"$ne": ["$order_estimated_delivery_date", None]},
                {"$ne": ["$order_delivered_customer_date", None]},
            ]},
            {"$dateDiff": {
                "startDate": "$order_estimated_delivery_date",
                "endDate": "$order_delivered_customer_date",
                "unit": "day",
            }},
            0,
        ]}}},
        {"$match": {"days_late": {"$gte": min_days}}},
        {"$lookup": {
            "from": "customers_collection",
            "localField": "customer_id",
            "foreignField": "customer_id",
            "as": "customer",
        }},
        {"$unwind": "$customer"},
        {"$group": {
            "_id": "$customer.customer_state",
            "Total_Delayed_Orders": {"$sum": 1},
            "Avg_Days_Late": {"$avg": "$days_late"},
        }},
        {"$project": {
            "_id": 0,
            "Customer_State": "$_id",
            "Total_Delayed_Orders": 1,
            "Avg_Days_Late": {"$round": ["$Avg_Days_Late", 1]},
        }},
        {"$sort": {"Total_Delayed_Orders": -1}},
    ], allowDiskUse=True))


def payment_methods() -> list[dict[str, Any]]:
    return list(db.orders_collection.aggregate([
        {"$project": {"order_id": 1, "order_payments": 1}},
        {"$unwind": "$order_payments"},
        {"$group": {
            "_id": "$order_payments.payment_type",
            "Order_Ids": {"$addToSet": "$order_id"},
            "Total_Collected": {"$sum": {"$ifNull": ["$order_payments.payment_value", 0]}},
            "Avg_Installments": {"$avg": "$order_payments.payment_installments"},
        }},
        {"$project": {
            "_id": 0,
            "Payment_Method": "$_id",
            "Transaction_Count": {"$size": "$Order_Ids"},
            "Total_Collected": 1,
            "Avg_Installments": {"$round": ["$Avg_Installments", 1]},
        }},
        {"$sort": {"Transaction_Count": -1}},
    ], allowDiskUse=True))


def product_categories(limit: int) -> list[dict[str, Any]]:
    return list(db.orders_collection.aggregate([
        {"$project": {"order_items": 1}},
        {"$unwind": "$order_items"},
        {"$match": {"order_items.category_name": {"$ne": None}}},
        {"$group": {
            "_id": "$order_items.category_name",
            "Total_Units_Sold": {"$sum": 1},
            "Total_Revenue": {"$sum": {"$add": [
                {"$ifNull": ["$order_items.price", 0]},
                {"$ifNull": ["$order_items.freight_value", 0]},
            ]}},
        }},
        {"$project": {
            "_id": 0,
            "Category": "$_id",
            "Total_Units_Sold": 1,
            "Total_Revenue": 1,
        }},
        {"$sort": {"Total_Revenue": -1}},
        {"$limit": limit},
    ], allowDiskUse=True))


def top_reviewed_orders(limit: int) -> list[dict[str, Any]]:
    return list(db.orders_collection.aggregate([
        {"$project": {"order_id": 1, "order_reviews": 1, "order_items": 1}},
        {"$set": {"Total_Purchase_Price": {"$reduce": {
            "input": "$order_items",
            "initialValue": 0,
            "in": {"$add": ["$$value", {"$ifNull": ["$$this.price", 0]}]},
        }}}},
        {"$unwind": "$order_reviews"},
        {"$group": {
            "_id": "$order_id",
            "Average_Review_Score": {"$avg": "$order_reviews.review_score"},
            "Review_Count": {"$sum": 1},
            "Total_Purchase_Price": {"$first": "$Total_Purchase_Price"},
        }},
        {"$project": {
            "_id": 0,
            "Order_ID": "$_id",
            "Average_Review_Score": {"$round": ["$Average_Review_Score", 2]},
            "Review_Count": 1,
            "Total_Purchase_Price": 1,
        }},
        {"$sort": {"Average_Review_Score": -1, "Review_Count": -1, "Order_ID": 1}},
        {"$limit": limit},
    ], allowDiskUse=True))


def region_allocation() -> list[dict[str, Any]]:
    total_sellers = db.sellers_collection.count_documents({})
    total_customers = db.customers_collection.count_documents({})
    return list(db.customers_collection.aggregate([
        {"$match": {"customer_state": {"$ne": None}}},
        {"$group": {"_id": "$customer_state", "Customer_Count": {"$sum": 1}}},
        {"$project": {
            "_id": 0, "Region": "$_id", "Seller_Count": {"$literal": 0},
            "Customer_Count": 1, "Total_Purchase_Price": {"$literal": 0},
        }},
        {"$unionWith": {"coll": "sellers_collection", "pipeline": [
            {"$match": {"seller_state": {"$ne": None}}},
            {"$group": {"_id": "$seller_state", "Seller_Count": {"$sum": 1}}},
            {"$project": {
                "_id": 0, "Region": "$_id", "Seller_Count": 1,
                "Customer_Count": {"$literal": 0}, "Total_Purchase_Price": {"$literal": 0},
            }},
        ]}},
        {"$unionWith": {"coll": "orders_collection", "pipeline": [
            {"$project": {"customer_id": 1, "order_items": 1}},
            {"$lookup": {
                "from": "customers_collection", "localField": "customer_id",
                "foreignField": "customer_id", "as": "customer",
            }},
            {"$unwind": "$customer"},
            {"$match": {"customer.customer_state": {"$ne": None}}},
            {"$unwind": "$order_items"},
            {"$group": {
                "_id": "$customer.customer_state",
                "Total_Purchase_Price": {"$sum": {"$ifNull": ["$order_items.price", 0]}},
            }},
            {"$project": {
                "_id": 0, "Region": "$_id", "Seller_Count": {"$literal": 0},
                "Customer_Count": {"$literal": 0}, "Total_Purchase_Price": 1,
            }},
        ]}},
        {"$group": {
            "_id": "$Region", "Seller_Count": {"$sum": "$Seller_Count"},
            "Customer_Count": {"$sum": "$Customer_Count"},
            "Total_Purchase_Price": {"$sum": "$Total_Purchase_Price"},
        }},
        {"$project": {
            "_id": 0, "Region": "$_id",
            "Seller_Percentage": {"$cond": [
                {"$gt": [total_sellers, 0]},
                {"$round": [{"$multiply": [{"$divide": ["$Seller_Count", total_sellers]}, 100]}, 2]},
                None,
            ]},
            "Customer_Percentage": {"$cond": [
                {"$gt": [total_customers, 0]},
                {"$round": [{"$multiply": [{"$divide": ["$Customer_Count", total_customers]}, 100]}, 2]},
                None,
            ]},
            "Total_Purchase_Price": 1,
        }},
        {"$sort": {"Region": 1}},
    ], allowDiskUse=True))


def region_allocation_summary() -> list[dict[str, Any]]:
    total_sellers = db.sellers_collection.count_documents({})
    total_customers = db.customers_collection.count_documents({})
    return list(db.region_summary_collection.aggregate([
        {"$set": {
            "Seller_Percentage": {"$cond": [
                {"$gt": [total_sellers, 0]},
                {"$round": [{"$multiply": [{"$divide": ["$Seller_Count", total_sellers]}, 100]}, 2]},
                None,
            ]},
            "Customer_Percentage": {"$cond": [
                {"$gt": [total_customers, 0]},
                {"$round": [{"$multiply": [{"$divide": ["$Customer_Count", total_customers]}, 100]}, 2]},
                None,
            ]},
        }},
        {"$sort": {"Region": 1}},
    ], allowDiskUse=True))


def refresh_region_summary() -> None:
    db.customers_collection.aggregate([
        {"$match": {"customer_state": {"$ne": None}}},
        {"$group": {"_id": "$customer_state", "Customer_Count": {"$sum": 1}}},
        {"$project": {
            "_id": 0, "Region": "$_id", "Seller_Count": {"$literal": 0},
            "Customer_Count": 1, "Order_Count": {"$literal": 0},
            "Total_Purchase_Price": {"$literal": 0},
        }},
        {"$unionWith": {"coll": "sellers_collection", "pipeline": [
            {"$match": {"seller_state": {"$ne": None}}},
            {"$group": {"_id": "$seller_state", "Seller_Count": {"$sum": 1}}},
            {"$project": {
                "_id": 0, "Region": "$_id", "Seller_Count": 1,
                "Customer_Count": {"$literal": 0}, "Order_Count": {"$literal": 0},
                "Total_Purchase_Price": {"$literal": 0},
            }},
        ]}},
        {"$unionWith": {"coll": "orders_collection", "pipeline": [
            {"$lookup": {
                "from": "customers_collection", "localField": "customer_id",
                "foreignField": "customer_id",
                "pipeline": [{"$project": {"_id": 0, "customer_state": 1}}],
                "as": "customer",
            }},
            {"$set": {
                "customer_state": {"$arrayElemAt": ["$customer.customer_state", 0]},
                "purchase_total": {"$reduce": {
                    "input": {"$ifNull": ["$order_items", []]},
                    "initialValue": 0,
                    "in": {"$add": ["$$value", {"$ifNull": ["$$this.price", 0]}]},
                }},
            }},
            {"$match": {"customer_state": {"$ne": None}}},
            {"$group": {
                "_id": "$customer_state", "Order_Count": {"$sum": 1},
                "Total_Purchase_Price": {"$sum": "$purchase_total"},
            }},
            {"$project": {
                "_id": 0, "Region": "$_id", "Seller_Count": {"$literal": 0},
                "Customer_Count": {"$literal": 0}, "Order_Count": 1,
                "Total_Purchase_Price": 1,
            }},
        ]}},
        {"$group": {
            "_id": "$Region", "Seller_Count": {"$sum": "$Seller_Count"},
            "Customer_Count": {"$sum": "$Customer_Count"},
            "Order_Count": {"$sum": "$Order_Count"},
            "Total_Purchase_Price": {"$sum": "$Total_Purchase_Price"},
        }},
        {"$project": {
            "_id": 0, "Region": "$_id", "Seller_Count": 1,
            "Customer_Count": 1, "Order_Count": 1, "Total_Purchase_Price": 1,
        }},
        {"$out": "region_summary_collection"},
    ], allowDiskUse=True)
    db.region_summary_collection.create_index("Region", unique=True)


st.title("E-Commerce MongoDB Reports")
st.caption("Interactive reports over the five final PDM collections")

with st.sidebar:
    st.header("Report")
    selected_report = st.selectbox("Choose a report", [*REPORTS, *SUMMARY_REPORTS])
    if selected_report in REPORTS:
        st.caption(REPORTS[selected_report])
    else:
        st.caption("Fast report using the maintained region summary collection")
    st.divider()
    mongo_uri = st.text_input("MongoDB URI", "mongodb://127.0.0.1:27017")
    database_name = st.text_input("Database", "ecommerce_db")
    run_report = st.button("Run report", type="primary", use_container_width=True)
    refresh_summary = st.button("Refresh region summary", use_container_width=True)

    if selected_report in {"Top purchase regions", "Top purchase regions (summary)"}:
        region_limit = st.number_input("Number of regions", min_value=1, max_value=100, value=20)
        purchase_order = st.radio("Purchase order", ["Highest first", "Lowest first"])
    elif selected_report in {"Top product categories", "Top reviewed orders"}:
        result_limit = st.number_input("Number of results", min_value=1, max_value=500, value=10)
    elif selected_report == "Shipping delays":
        min_delay_days = st.number_input("Minimum delay (days)", min_value=0, max_value=365, value=5)

if "rows" not in st.session_state:
    st.session_state.rows = []
if "error" not in st.session_state:
    st.session_state.error = None
if "query_duration_ms" not in st.session_state:
    st.session_state.query_duration_ms = None

if refresh_summary:
    try:
        db = get_database(mongo_uri, database_name)
        refresh_region_summary()
        st.success("Region summary refreshed.")
    except (PyMongoError, ServerSelectionTimeoutError) as error:
        st.error(f"Could not refresh region summary: {error}")

if run_report:
    try:
        db = get_database(mongo_uri, database_name)
        query_started_at = perf_counter()
        if selected_report == "Top purchase regions":
            rows = purchase_regions(region_limit, -1 if purchase_order == "Highest first" else 1)
        elif selected_report == "Top purchase regions (summary)":
            rows = purchase_regions_summary(region_limit, -1 if purchase_order == "Highest first" else 1)
        elif selected_report == "Shipping delays":
            rows = shipping_delays(min_delay_days)
        elif selected_report == "Payment methods":
            rows = payment_methods()
        elif selected_report == "Top product categories":
            rows = product_categories(result_limit)
        elif selected_report == "Top reviewed orders":
            rows = top_reviewed_orders(result_limit)
        elif selected_report == "Region allocation (summary)":
            rows = region_allocation_summary()
        else:
            rows = region_allocation()
        st.session_state.rows = rows
        st.session_state.query_duration_ms = (perf_counter() - query_started_at) * 1000
        st.session_state.error = None
    except (PyMongoError, ServerSelectionTimeoutError) as error:
        st.session_state.rows = []
        st.session_state.query_duration_ms = None
        st.session_state.error = str(error)

if st.session_state.error:
    st.error(st.session_state.error)

if st.session_state.rows:
    result_frame = dataframe(st.session_state.rows)
    row_metric, duration_metric = st.columns(2)
    row_metric.metric("Rows returned", len(result_frame))
    duration_metric.metric("Query time", f"{st.session_state.query_duration_ms:.2f} ms")
    st.dataframe(result_frame, use_container_width=True, hide_index=True)
    st.download_button(
        "Download CSV",
        result_frame.to_csv(index=False).encode("utf-8"),
        file_name="mongo_report.csv",
        mime="text/csv",
    )
elif not st.session_state.error:
    st.info("Choose a report and select Run report.")
