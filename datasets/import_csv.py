import os
import csv
import tkinter as tk
from tkinter import filedialog
import mysql.connector

print("========== CSV Import ==========")

# ============================================
# 2b: Prompt user to enter table name
# ============================================
table = input("Enter table name : ").strip()

# ============================================
# 2b: Prompt user to enter CSV file path
# ============================================

def get_csv_file_path():
    print("\n" + "-"*60)
    print("Select CSV file:")
    print("  1. Browse and select file (GUI)")
    print("  2. Enter file path manually")
    print("-"*60)
    
    choice = input("Choose option (1 or 2): ").strip()
    
    if choice == '1':
        root = tk.Tk()
        root.withdraw()
        
        file_path = filedialog.askopenfilename(
            title="Select CSV File",
            filetypes=[("CSV files", "*.csv")]
        )
        root.destroy()
        
        if file_path:
            print(f"Selected: {file_path}")
            return file_path
        else:
            print("No file selected. Try again.")
            return get_csv_file_path()
    
    elif choice == '2':
        file_path = input("Enter CSV file path: ").strip()
        return file_path
    
    else:
        print("Invalid choice. Please enter 1 or 2.")
        return get_csv_file_path()

path = get_csv_file_path()

# ============================================
# 2c: Validate file existence
# ============================================
if not os.path.isfile(path):
    print("ERROR : File does not exist.")
    exit()

# ============================================
# Validate file format
# ============================================
if not path.lower().endswith(".csv"):
    print("ERROR : Only CSV files are allowed.")
    exit()

# ============================================
# Validate empty CSV file
# ============================================
if os.path.getsize(path) == 0:
    print("ERROR : CSV file is empty.")
    exit()

conn = None
cursor = None

try:
    conn = mysql.connector.connect(
        host="localhost",
        user="root",
        password="", # "", 123456 etc
        database="assignment1",
        allow_local_infile=True
    )

    cursor = conn.cursor()

    # ============================================
    # Validate CSV header
    # ============================================
    expected_headers = {
        "customers": [
            "customer_id",
            "customer_unique_id",
            "customer_zip_code_prefix",
            "customer_city",
            "customer_state"
        ],
        "orders": [
            "order_id",
            "customer_id",
            "order_status",
            "order_purchase_timestamp",
            "order_approved_at",
            "order_delivered_carrier_date",
            "order_delivered_customer_date",
            "order_estimated_delivery_date"
        ],
        "order_items": [
            "order_id",
            "order_item_id",
            "product_id",
            "seller_id",
            "shipping_limit_date",
            "price",
            "freight_value"
        ],
        "order_payments": [
            "order_id",
            "payment_sequential",
            "payment_type",
            "payment_installments",
            "payment_value"
        ],
        "order_reviews": [
            "review_id",
            "order_id",
            "review_score",
            "review_comment_title",
            "review_comment_message",
            "review_creation_date",
            "review_answer_timestamp"
        ],
        "products": [
            "product_id",
            "product_category_name",
            "product_name_lenght",
            "product_description_lenght",
            "product_photos_qty",
            "product_weight_g",
            "product_length_cm",
            "product_height_cm",
            "product_width_cm"
        ],
        "sellers": [
            "seller_id",
            "seller_zip_code_prefix",
            "seller_city",
            "seller_state"
        ],
        "product_category_name_translation": [
            "product_category_name",
            "product_category_name_english"
        ],
        "geolocation": [
            "geolocation_zip_code_prefix",
            "geolocation_lat",
            "geolocation_lng",
            "geolocation_city",
            "geolocation_state"
        ]
    }

    with open(path, "r", encoding="utf-8-sig", newline="") as csvfile:
        reader = csv.reader(csvfile)

        header = next(reader, None)

        if header is None:
            raise ValueError("CSV file does not contain a header.")

        if table in expected_headers:
            if header != expected_headers[table]:
                raise ValueError(
                    f"Incorrect CSV header for table '{table}'."
                )

        print("CSV Header Validation Passed.")

    # ============================================
    # Create table if not exists
    # ============================================
    create_table_sql = {

        "customers": """
        CREATE TABLE IF NOT EXISTS customers(
            customer_id VARCHAR(50) PRIMARY KEY,
            customer_unique_id VARCHAR(50),
            customer_zip_code_prefix VARCHAR(10),
            customer_city VARCHAR(100),
            customer_state CHAR(2)
        )
        """,

        "orders": """
        CREATE TABLE IF NOT EXISTS orders(
            order_id VARCHAR(50) PRIMARY KEY,
            customer_id VARCHAR(50),
            order_status VARCHAR(20),
            order_purchase_timestamp DATETIME,
            order_approved_at DATETIME,
            order_delivered_carrier_date DATETIME,
            order_delivered_customer_date DATETIME,
            order_estimated_delivery_date DATETIME
        )
        """,

        "order_items": """
        CREATE TABLE IF NOT EXISTS order_items(
            order_id VARCHAR(50),
            order_item_id INT,
            product_id VARCHAR(50),
            seller_id VARCHAR(50),
            shipping_limit_date DATETIME,
            price DECIMAL(10,2),
            freight_value DECIMAL(10,2),
            PRIMARY KEY(order_id,order_item_id)
        )
        """,

        "order_payments": """
        CREATE TABLE IF NOT EXISTS order_payments(
            order_id VARCHAR(50),
            payment_sequential INT,
            payment_type VARCHAR(30),
            payment_installments INT,
            payment_value DECIMAL(10,2),
            PRIMARY KEY(order_id,payment_sequential)
        )
        """,

        "order_reviews": """
        CREATE TABLE IF NOT EXISTS order_reviews(
            review_id VARCHAR(50) PRIMARY KEY,
            order_id VARCHAR(50),
            review_score INT,
            review_comment_title TEXT,
            review_comment_message TEXT,
            review_creation_date DATETIME,
            review_answer_timestamp DATETIME
        )
        """,

        "products": """
        CREATE TABLE IF NOT EXISTS products(
            product_id VARCHAR(50) PRIMARY KEY,
            product_category_name VARCHAR(100),
            product_name_lenght INT,
            product_description_lenght INT,
            product_photos_qty INT,
            product_weight_g INT,
            product_length_cm INT,
            product_height_cm INT,
            product_width_cm INT
        )
        """,

        "sellers": """
        CREATE TABLE IF NOT EXISTS sellers(
            seller_id VARCHAR(50) PRIMARY KEY,
            seller_zip_code_prefix VARCHAR(10),
            seller_city VARCHAR(100),
            seller_state CHAR(2)
        )
        """,

        "product_category_name_translation": """
        CREATE TABLE IF NOT EXISTS product_category_name_translation(
            product_category_name VARCHAR(100),
            product_category_name_english VARCHAR(100)
        )
        """,

        "geolocation": """
        CREATE TABLE IF NOT EXISTS geolocation(
            geolocation_zip_code_prefix VARCHAR(10),
            geolocation_lat DECIMAL(12,8),
            geolocation_lng DECIMAL(12,8),
            geolocation_city VARCHAR(100),
            geolocation_state CHAR(2)
        )
        """
    }

    if table not in create_table_sql:
        print("ERROR : Invalid table name.")
        exit()

    cursor.execute(create_table_sql[table])
    print("Table Ready.")

    # ============================================
    # Build LOAD DATA command
    # ============================================
    file_path = path.replace('\\', '/')

    if table == 'orders':
     load_command = f"""
        LOAD DATA LOCAL INFILE '{file_path}'
        INTO TABLE orders
        CHARACTER SET utf8mb4
        FIELDS TERMINATED BY ','
        OPTIONALLY ENCLOSED BY '"'
        LINES TERMINATED BY '\n'
        IGNORE 1 ROWS
        (order_id, customer_id, order_status,
         @purchase_date, @approved_date, @carrier_date, @customer_date, @estimated_date)
        SET
         order_purchase_timestamp = COALESCE(
             STR_TO_DATE(@purchase_date, '%m/%d/%Y %H:%i'),
             STR_TO_DATE(@purchase_date, '%d/%m/%Y %H:%i')
         ),
         order_approved_at = COALESCE(
             STR_TO_DATE(@approved_date, '%m/%d/%Y %H:%i'),
             STR_TO_DATE(@approved_date, '%d/%m/%Y %H:%i')
         ),
         order_delivered_carrier_date = COALESCE(
             STR_TO_DATE(@carrier_date, '%m/%d/%Y %H:%i'),
             STR_TO_DATE(@carrier_date, '%d/%m/%Y %H:%i')
         ),
         order_delivered_customer_date = COALESCE(
             STR_TO_DATE(@customer_date, '%m/%d/%Y %H:%i'),
             STR_TO_DATE(@customer_date, '%d/%m/%Y %H:%i')
         ),
         order_estimated_delivery_date = COALESCE(
             STR_TO_DATE(@estimated_date, '%m/%d/%Y %H:%i'),
             STR_TO_DATE(@estimated_date, '%d/%m/%Y %H:%i')
         )
     """

    elif table == 'order_reviews':
     load_command = f"""
        LOAD DATA LOCAL INFILE '{file_path}'
        INTO TABLE order_reviews
        CHARACTER SET utf8mb4
        FIELDS TERMINATED BY ','
        OPTIONALLY ENCLOSED BY '"'
        LINES TERMINATED BY '\n'
        IGNORE 1 ROWS
        (review_id, order_id, review_score,
         @title, @message, @creation_date, @answer_timestamp)
        SET
         review_comment_title = NULLIF(@title, ''),
         review_comment_message = NULLIF(@message, ''),
         review_creation_date = COALESCE(
             STR_TO_DATE(@creation_date, '%m/%d/%Y %H:%i'),
             STR_TO_DATE(@creation_date, '%d/%m/%Y %H:%i')
         ),
         review_answer_timestamp = COALESCE(
             STR_TO_DATE(@answer_timestamp, '%m/%d/%Y %H:%i'),
             STR_TO_DATE(@answer_timestamp, '%d/%m/%Y %H:%i')
         )
     """

    else:
     load_command = f"""
        LOAD DATA LOCAL INFILE '{file_path}'
        INTO TABLE {table}
        CHARACTER SET utf8mb4
        FIELDS TERMINATED BY ','
        OPTIONALLY ENCLOSED BY '"'
        LINES TERMINATED BY '\n'
        IGNORE 1 ROWS
     """

    # ============================================
    # Execute with transaction
    # ============================================
    conn.start_transaction()

    try:
        # Get row count before import
        cursor.execute(f"SELECT COUNT(*) FROM {table}")
        before = cursor.fetchone()[0]

        # Import CSV data
        cursor.execute(load_command)

        # Get row count after import
        cursor.execute(f"SELECT COUNT(*) FROM {table}")
        after = cursor.fetchone()[0]

        # Calculate imported rows
        rows_imported = after - before

        # Commit transaction
        conn.commit()

        print(f"Import completed. {rows_imported} rows imported into '{table}'.")

    except Exception:
        conn.rollback()
        raise

except FileNotFoundError:
    print("ERROR: File not found.")

except ValueError as ve:
    print("ERROR: Validation failed -", ve)

except mysql.connector.Error as err:
    print("Database Error:")
    print(err)

except Exception as e:
    print("Unexpected Error:")
    print(e)

finally:
    if cursor:
        cursor.close()
    if conn:
        conn.close()
    print("Connection closed.")