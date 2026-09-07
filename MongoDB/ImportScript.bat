@echo off
setlocal enabledelayedexpansion

:: ============================================================================
:: ImportScript.bat
:: UECS3203 Advanced Database Systems - Assignment 2
:: Automated CSV Ingestion and MongoDB Aggregation to Final PDM
:: ============================================================================

title MongoDB PDM Migration Pipeline

:: Configuration Variables
set "DB_NAME=ecommerce_db"
set "SCRIPT_DIR=%~dp0"
set "DATASET_DIR=%SCRIPT_DIR%..\datasets"
set "TRANSFORM_SCRIPT=%SCRIPT_DIR%transform_pdm.js"

echo ===============================================================================
echo        MONGODB PHYSICAL DATA MODEL [PDM] INGESTION AND PIPELINE AUTOMATION
echo ===============================================================================
echo Database Target   : %DB_NAME%
echo Datasets Location : %DATASET_DIR%
echo Transform Script  : %TRANSFORM_SCRIPT%
echo ===============================================================================
echo.
C:\Users\L.L.Sun\Desktop\Y1S123\Y3S3\UECS3203 Advanced Database System\ADBassignment1\MongoDB\ImportScript.bat
:: 1. Validate Prerequisite Tools
echo [*] Checking required tools: mongoimport, mongosh...
where mongoimport >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] mongoimport was not found in PATH!
    echo Please ensure MongoDB Database Tools are installed and added to PATH.
    if not "%1"=="--no-pause" pause
    exit /b 1
)

where mongosh >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] mongosh was not found in PATH!
    echo Please ensure MongoDB Shell is installed and added to PATH.
    if not "%1"=="--no-pause" pause
    exit /b 1
)
echo [OK] mongoimport and mongosh detected.
echo.

:: 2. Validate Datasets Directory
if not exist "%DATASET_DIR%" (
    echo [ERROR] Dataset directory not found at: "%DATASET_DIR%"
    echo Please verify the path to the CSV datasets.
    if not "%1"=="--no-pause" pause
    exit /b 1
)

if not exist "%TRANSFORM_SCRIPT%" (
    echo [ERROR] Aggregation script not found at: "%TRANSFORM_SCRIPT%"
    if not "%1"=="--no-pause" pause
    exit /b 1
)

:: ============================================================================
:: PHASE 1: IMPORT CSV DATASETS INTO MONGODB STAGING COLLECTIONS
:: ============================================================================
echo -------------------------------------------------------------------------------
echo [PHASE 1] Importing 9 CSV Datasets into Staging Collections [--drop]
echo -------------------------------------------------------------------------------

echo [1/9] Importing Orders -^> stage_orders...
mongoimport --db="%DB_NAME%" --collection="stage_orders" --type=csv --headerline --drop --file="%DATASET_DIR%\olist_orders_dataset.csv"
if %ERRORLEVEL% NEQ 0 ( echo [WARNING] Issue importing orders. )

echo [2/9] Importing Order Items -^> stage_order_items...
mongoimport --db="%DB_NAME%" --collection="stage_order_items" --type=csv --headerline --drop --file="%DATASET_DIR%\olist_order_items_dataset.csv"
if %ERRORLEVEL% NEQ 0 ( echo [WARNING] Issue importing order items. )

echo [3/9] Importing Order Payments -^> stage_order_payments...
mongoimport --db="%DB_NAME%" --collection="stage_order_payments" --type=csv --headerline --drop --file="%DATASET_DIR%\olist_order_payments_dataset.csv"
if %ERRORLEVEL% NEQ 0 ( echo [WARNING] Issue importing order payments. )

echo [4/9] Importing Order Reviews -^> stage_order_reviews...
mongoimport --db="%DB_NAME%" --collection="stage_order_reviews" --type=csv --headerline --drop --file="%DATASET_DIR%\olist_order_reviews_dataset.csv"
if %ERRORLEVEL% NEQ 0 ( echo [WARNING] Issue importing order reviews. )

echo [5/9] Importing Products -^> stage_products...
mongoimport --db="%DB_NAME%" --collection="stage_products" --type=csv --headerline --drop --file="%DATASET_DIR%\olist_products_dataset.csv"
if %ERRORLEVEL% NEQ 0 ( echo [WARNING] Issue importing products. )

echo [6/9] Importing Category Translations -^> stage_category_translation...
mongoimport --db="%DB_NAME%" --collection="stage_category_translation" --type=csv --headerline --drop --file="%DATASET_DIR%\product_category_name_translation.csv"
if %ERRORLEVEL% NEQ 0 ( echo [WARNING] Issue importing category translations. )

echo [7/9] Importing Customers -^> stage_customers...
mongoimport --db="%DB_NAME%" --collection="stage_customers" --type=csv --headerline --drop --file="%DATASET_DIR%\olist_customers_dataset.csv"
if %ERRORLEVEL% NEQ 0 ( echo [WARNING] Issue importing customers. )

echo [8/9] Importing Sellers -^> stage_sellers...
mongoimport --db="%DB_NAME%" --collection="stage_sellers" --type=csv --headerline --drop --file="%DATASET_DIR%\olist_sellers_dataset.csv"
if %ERRORLEVEL% NEQ 0 ( echo [WARNING] Issue importing sellers. )

echo [9/9] Importing Geolocation -^> stage_geolocation [1M rows, please wait]...
mongoimport --db="%DB_NAME%" --collection="stage_geolocation" --type=csv --headerline --drop --file="%DATASET_DIR%\olist_geolocation_dataset.csv"
if %ERRORLEVEL% NEQ 0 ( echo [WARNING] Issue importing geolocation. )

echo.
echo [OK] Staging Ingestion Phase Completed Successfully!
echo.

:: ============================================================================
:: PHASE 2: EXECUTE MONGOSH AGGREGATION PIPELINE INTO FINAL PDM
:: ============================================================================
echo -------------------------------------------------------------------------------
echo [PHASE 2] Executing Aggregation Pipelines and Compiling Final PDM
echo -------------------------------------------------------------------------------
echo Running: mongosh "%DB_NAME%" "%TRANSFORM_SCRIPT%"
echo.

mongosh "%DB_NAME%" "%TRANSFORM_SCRIPT%"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] An error occurred during the MongoDB aggregation pipeline execution.
    if not "%1"=="--no-pause" pause
    exit /b %ERRORLEVEL%
)

echo.
echo ===============================================================================
echo [SUCCESS] Complete Migration and Aggregation Pipeline Finished!
echo Final collections are ready for query execution and analysis.
echo ===============================================================================
if not "%1"=="--no-pause" pause
exit /b 0
