/*
================================================================================
 GLOBAL SUPERSTORE — SALES & PROFITABILITY ANALYSIS
 SQL Server (T-SQL) | Data Profiling -> Cleaning Views -> KPI Logic -> Final Model
 Author : Hafiz Arslan Shafique
 Source : Global Superstore dataset (2011-2014)

 Source tables:
   dbo.Orders   -> Fact table  (51,291 rows | order-line grain)
   dbo.People   -> Dimension   (14 regional managers)
   dbo.Returns  -> Fact/flag   (~800+ returned Order IDs)
================================================================================
*/

-- =========================================================
-- 1. DATA PROFILING (EDA)
-- =========================================================
-- Before trusting any number, the raw tables are audited for volume,
-- structure, nulls and duplicates.

-- Row counts across all three source tables
SELECT 'Orders'  AS TableName, COUNT(*) AS TotalRows FROM dbo.Orders
UNION ALL
SELECT 'Returns', COUNT(*) FROM dbo.Returns
UNION ALL
SELECT 'People',  COUNT(*) FROM dbo.People;

-- Schema check — column names, data types and lengths (Orders)
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Orders'
ORDER BY ORDINAL_POSITION;

-- Null audit on the fields that drive the financial KPIs
SELECT
    SUM(CASE WHEN Order_ID      IS NULL THEN 1 ELSE 0 END) AS Null_OrderID,
    SUM(CASE WHEN Order_Date    IS NULL THEN 1 ELSE 0 END) AS Null_OrderDate,
    SUM(CASE WHEN Sales         IS NULL THEN 1 ELSE 0 END) AS Null_Sales,
    SUM(CASE WHEN Profit        IS NULL THEN 1 ELSE 0 END) AS Null_Profit,
    SUM(CASE WHEN Shipping_Cost IS NULL THEN 1 ELSE 0 END) AS Null_ShipCost,
    SUM(CASE WHEN Customer_ID   IS NULL THEN 1 ELSE 0 END) AS Null_CustomerID,
    SUM(CASE WHEN Region        IS NULL THEN 1 ELSE 0 END) AS Null_Region
FROM dbo.Orders;

-- Duplicate check on the Orders grain key (Row_ID)
SELECT
    COUNT(*)                          AS Total_Rows,
    COUNT(DISTINCT Row_ID)            AS Unique_RowID,
    COUNT(*) - COUNT(DISTINCT Row_ID) AS Duplicate_Count
FROM dbo.Orders;

-- Duplicate check on Returns (an Order_ID should only appear once)
SELECT Order_ID, COUNT(*) AS Dup_Count
FROM dbo.Returns
GROUP BY Order_ID
HAVING COUNT(*) > 1;


-- =========================================================
-- 2. DATA CLEANING (VIEW LAYER)
-- =========================================================
-- Raw tables are never edited directly. Power BI reads only from these
-- views, so the source data stays untouched and every transform is auditable.

-- 2.1 Clean Orders — drops missing/invalid financial rows, trims Order_ID,
--     and derives Delivery_Days for shipping-performance analysis.
DROP VIEW IF EXISTS dbo.vw_CleanOrders;
GO
CREATE VIEW dbo.vw_CleanOrders AS
SELECT
    Row_ID,
    LTRIM(RTRIM(Order_ID))               AS Order_ID,
    Order_Date,
    Ship_Date,
    DATEDIFF(DAY, Order_Date, Ship_Date) AS Delivery_Days,
    Customer_ID,
    Customer_Name,
    Segment,
    City, State, Country, Postal_Code, Market, Region,
    Product_ID, Category, Sub_Category, Product_Name,
    Sales, Quantity, Discount, Profit, Shipping_Cost,
    Ship_Mode, Order_Priority
FROM dbo.Orders
WHERE Profit IS NOT NULL   -- removes rows with missing profit
  AND Sales  IS NOT NULL
  AND Sales  > 0;          -- removes zero/negative sales lines
GO

-- 2.2 Clean Returns — de-duplicated, trimmed Order_ID lookup used to flag
--     "was this order returned?" in the final model.
DROP VIEW IF EXISTS dbo.vw_CleanReturns;
GO
CREATE VIEW dbo.vw_CleanReturns AS
SELECT DISTINCT
    LTRIM(RTRIM(Order_ID)) AS Order_ID
FROM dbo.Returns
WHERE Order_ID IS NOT NULL;
GO

-- 2.3 Clean People — trimmed manager/region lookup with the header row
--     that leaked into the raw import removed.
DROP VIEW IF EXISTS dbo.vw_CleanPeople;
GO
CREATE VIEW dbo.vw_CleanPeople AS
SELECT
    LTRIM(RTRIM(Region)) AS Region,
    LTRIM(RTRIM(Person)) AS Person
FROM dbo.People
WHERE Person IS NOT NULL
  AND Region IS NOT NULL
  AND Person <> 'Person'
  AND Region <> 'Region';
GO

-- 2.4 Validation — confirm each cleaned view lands on the expected row count
SELECT 'CleanOrders'  AS ViewName, COUNT(*) AS Rows FROM dbo.vw_CleanOrders
UNION ALL
SELECT 'CleanReturns', COUNT(*) FROM dbo.vw_CleanReturns
UNION ALL
SELECT 'CleanPeople',  COUNT(*) FROM dbo.vw_CleanPeople;


-- =========================================================
-- 3. BUSINESS KPI QUERIES
-- =========================================================
-- Answers the four business questions the dashboard is built around.

-- KPI 1 — Headline company metrics
SELECT
    SUM(Sales)                                                                  AS Total_Sales,
    SUM(Profit)                                                                 AS Total_Profit,
    CAST(ROUND(SUM(Profit) * 100.0 / NULLIF(SUM(Sales), 0), 2) AS DECIMAL(5,2)) AS Profit_Margin_Percent,
    COUNT(DISTINCT Order_ID)                                                    AS Total_Orders,
    SUM(Quantity)                                                               AS Total_Units_Sold
FROM dbo.vw_CleanOrders;

-- KPI 2 — Return impact: how much revenue/profit is at risk from returns
SELECT
    COUNT(DISTINCT r.Order_ID)                                                     AS Returned_Orders,
    SUM(o.Sales)                                                                   AS Returned_Sales_Loss,
    SUM(o.Profit)                                                                  AS Returned_Profit_Loss,
    CAST(COUNT(DISTINCT r.Order_ID) * 100.0
        / NULLIF((SELECT COUNT(DISTINCT Order_ID) FROM dbo.vw_CleanOrders), 0)
        AS DECIMAL(5,2))                                                          AS Return_Rate_Percent
FROM dbo.vw_CleanReturns r
JOIN dbo.vw_CleanOrders  o ON r.Order_ID = o.Order_ID;

-- KPI 3 — Which region is dragging profit margin down?
SELECT
    Region,
    SUM(Sales)                                                                  AS Sales,
    SUM(Profit)                                                                 AS Profit,
    CAST(ROUND(SUM(Profit) * 100.0 / NULLIF(SUM(Sales), 0), 2) AS DECIMAL(5,2)) AS Margin_Pct,
    CAST(AVG(Discount) AS DECIMAL(5,3))                                         AS Avg_Discount
FROM dbo.vw_CleanOrders
GROUP BY Region
ORDER BY Margin_Pct ASC;   -- worst margin surfaces first

-- KPI 4 — Which category / sub-category is dragging profit margin down?
SELECT
    Category,
    Sub_Category,
    SUM(Sales)                                                                  AS Sales,
    SUM(Profit)                                                                 AS Profit,
    CAST(ROUND(SUM(Profit) * 100.0 / NULLIF(SUM(Sales), 0), 2) AS DECIMAL(5,2)) AS Margin_Pct,
    CAST(AVG(Discount) AS DECIMAL(5,3))                                         AS Avg_Discount
FROM dbo.vw_CleanOrders
GROUP BY Category, Sub_Category
ORDER BY Margin_Pct ASC;   -- worst sub-category surfaces first


-- =========================================================
-- 4. FINAL SEMANTIC MODEL FOR POWER BI
-- =========================================================
-- One governed, single-source-of-truth view joining the cleaned fact and
-- dimension layers, ready to plug straight into Power BI.

DROP VIEW IF EXISTS dbo.vw_Final_Superstore_Dashboard;
GO
CREATE VIEW dbo.vw_Final_Superstore_Dashboard AS
SELECT
    o.Order_ID,
    o.Order_Date,
    o.Ship_Date,
    o.Region,
    o.Category,
    o.Sub_Category,
    o.Product_Name,
    o.Sales,
    o.Profit,
    o.Quantity,
    o.Discount,
    o.Segment,
    o.Customer_Name,
    o.Ship_Mode,
    p.Person                                           AS Regional_Manager,
    CASE WHEN r.Order_ID IS NOT NULL THEN 1 ELSE 0 END AS Is_Returned   -- Power BI slicer: 1 = Returned, 0 = Kept
FROM dbo.vw_CleanOrders  o
LEFT JOIN dbo.vw_CleanPeople  p ON o.Region   = p.Region
LEFT JOIN dbo.vw_CleanReturns r ON o.Order_ID = r.Order_ID;
GO

-- Final sanity check before pointing Power BI at the view
SELECT TOP 10 Order_ID, Region, Category, Sub_Category, Sales, Profit, Discount, Is_Returned, Regional_Manager
FROM dbo.vw_Final_Superstore_Dashboard;

-- Confirm server/database before connecting Power BI
SELECT @@SERVERNAME AS Server_Name;
SELECT DB_NAME()    AS Current_Database_Name;

/*
================================================================================
 End of script. dbo.vw_Final_Superstore_Dashboard is the single view imported
 into Power BI (Import mode) to build the dashboard in /03_dashboard_images.
================================================================================
*/
