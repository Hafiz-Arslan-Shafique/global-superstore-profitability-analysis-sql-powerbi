# 🛒 Global Superstore Profitability Analysis — SQL Server & Power BI

## Project Overview
**End-to-end analysis of $12.64M+ in global retail sales** — from raw, unaudited transactional data to an interactive Power BI dashboard, using SQL Server for cleaning, KPI calculation, and root-cause profitability analysis.

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Hafiz%20Arslan%20Shafique-0A66C2?style=flat&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/hafiz-arslan-shafique-bc240203664/)
[![GitHub](https://img.shields.io/badge/GitHub-Repository-181717?style=flat&logo=github&logoColor=white)](https://github.com/Hafiz-Arslan-Shafique/global-superstore-profitability-analysis-sql-powerbi)
[![Email](https://img.shields.io/badge/Email-hafiz.shafique%40esom.com.sa-D14836?style=flat&logo=gmail&logoColor=white)](mailto:hafiz.shafique@esom.com.sa)
[![Contact](https://img.shields.io/badge/Contact-%2B966%2057%20959%204038-25D366?style=flat&logo=whatsapp&logoColor=white)](tel:+966579594038)

![Global Superstore Dashboard](03_dashboard_images/global-superstore-dashboard.jpg)

---

## 🎯 What This Project Does
I analyzed four years of global retail transaction data to answer one core business question: **where exactly is profit margin being lost, and why?** I used **SQL Server** for data profiling, cleaning, and KPI logic, then built an **interactive Power BI dashboard** to trace an 11.63% profit margin back to its root cause.

| | |
|---|---|
| **Total Sales Analyzed** | $12.64M |
| **Total Profit** | $1.47M |
| **Profit Margin** | 11.63% |
| **Average Discount** | 14.26% |
| **Return Rate** | 12.18% |
| **Timeframe** | 2011–2014 |
| **Tools** | SQL Server, T-SQL, Power BI, DAX, Power Query |

---

## 💡 Key Insights
- **Tables is the single biggest profit leak** — the only sub-category operating at a negative margin (**-8.41%**), losing ~$63.6K on $755.9K in sales, while Paper leads at 24.29%.
- **Discounting and margin move in opposite directions** — Tables also carries the highest average discount (~29%), pointing to over-discounting as a direct driver of the loss.
- **Regional performance is uneven** — Canada leads at 26.62% margin, while Southeast Asia is the weakest performer company-wide at ~2.05%.
- **Consumer is the most valuable segment**, driving 51.06% of total profit — more than Corporate (30.08%) and Home Office (18.86%) combined.
- **Returns are a material cost, not a footnote** — a 12.18% return rate justifies its own filter on the dashboard.

---

## 🛠️ My Process
1. **Profiled** the raw dataset in SQL Server (row counts, schema, data types across `Orders`, `People`, `Returns`).
2. **Audited data quality** — found 41 rows with missing Profit and one duplicate `Order_ID` in Returns before trusting any aggregation.
3. **Cleaned the data** using view-based transformations rather than editing raw tables, keeping every step auditable.
4. **Built reusable SQL views** (`vw_CleanOrders`, `vw_CleanReturns`, `vw_CleanPeople`) to centralize cleaning logic instead of repeating it across queries.
5. **Derived KPIs directly in SQL** — margin %, return rate, and regional/sub-category breakdowns — before a single chart was built.
6. **Modeled a single governed view** (`vw_Final_Superstore_Dashboard`) joining fact and dimension layers, so Power BI reads from one consistent source of truth.
7. **Modeled and visualized results in Power BI**, with DAX measures for Total Sales, Total Profit, Profit Margin %, Average Discount, and Return Rate %, plus a return-status slicer.

<details>
<summary><b>📂 See full SQL queries with explanations</b></summary>

### 1. Row Counts (EDA)
Confirms table volume before anything else is trusted.
```sql
SELECT 'Orders'  AS TableName, COUNT(*) AS TotalRows FROM dbo.Orders
UNION ALL
SELECT 'Returns', COUNT(*) FROM dbo.Returns
UNION ALL
SELECT 'People',  COUNT(*) FROM dbo.People;
```

### 2. Schema Check
Confirms column names, data types, and lengths via the system catalog.
```sql
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Orders'
ORDER BY ORDINAL_POSITION;
```

### 3. Null Audit
Flags missing values on the fields that drive the financial KPIs — this is where the 41 missing-Profit rows were found.
```sql
SELECT
    SUM(CASE WHEN Sales  IS NULL THEN 1 ELSE 0 END) AS Null_Sales,
    SUM(CASE WHEN Profit IS NULL THEN 1 ELSE 0 END) AS Null_Profit,
    SUM(CASE WHEN Region IS NULL THEN 1 ELSE 0 END) AS Null_Region
FROM dbo.Orders;
```

### 4. Duplicate Detection
Confirms `Row_ID` uniqueness in Orders and catches duplicate `Order_ID`s in Returns.
```sql
SELECT COUNT(*) AS Total_Rows, COUNT(DISTINCT Row_ID) AS Unique_RowID
FROM dbo.Orders;

SELECT Order_ID, COUNT(*) AS Dup_Count
FROM dbo.Returns
GROUP BY Order_ID
HAVING COUNT(*) > 1;
```

### 5. Clean Orders View
Removes missing/invalid financial rows, trims `Order_ID`, and derives `Delivery_Days`.
```sql
CREATE VIEW dbo.vw_CleanOrders AS
SELECT
    Row_ID,
    LTRIM(RTRIM(Order_ID))               AS Order_ID,
    DATEDIFF(DAY, Order_Date, Ship_Date) AS Delivery_Days,
    Region, Category, Sub_Category, Segment,
    Sales, Quantity, Discount, Profit
FROM dbo.Orders
WHERE Profit IS NOT NULL AND Sales IS NOT NULL AND Sales > 0;
```

### 6. Clean Returns & Clean People Views
De-duplicated, trimmed lookups used to flag returns and map regional managers.
```sql
CREATE VIEW dbo.vw_CleanReturns AS
SELECT DISTINCT LTRIM(RTRIM(Order_ID)) AS Order_ID
FROM dbo.Returns
WHERE Order_ID IS NOT NULL;

CREATE VIEW dbo.vw_CleanPeople AS
SELECT LTRIM(RTRIM(Region)) AS Region, LTRIM(RTRIM(Person)) AS Person
FROM dbo.People
WHERE Person <> 'Person' AND Region <> 'Region';
```

### 7. KPI 1 — Headline Company Metrics
```sql
SELECT
    SUM(Sales) AS Total_Sales,
    SUM(Profit) AS Total_Profit,
    ROUND(SUM(Profit) * 100.0 / NULLIF(SUM(Sales), 0), 2) AS Profit_Margin_Percent,
    COUNT(DISTINCT Order_ID) AS Total_Orders
FROM dbo.vw_CleanOrders;
```

### 8. KPI 2 — Return Impact
```sql
SELECT
    COUNT(DISTINCT r.Order_ID) AS Returned_Orders,
    SUM(o.Profit) AS Returned_Profit_Loss,
    COUNT(DISTINCT r.Order_ID) * 100.0
        / NULLIF((SELECT COUNT(DISTINCT Order_ID) FROM dbo.vw_CleanOrders), 0) AS Return_Rate_Percent
FROM dbo.vw_CleanReturns r
JOIN dbo.vw_CleanOrders o ON r.Order_ID = o.Order_ID;
```

### 9. KPI 3 & 4 — Weakest Region / Sub-Category by Margin
```sql
SELECT Region,
       SUM(Sales) AS Sales, SUM(Profit) AS Profit,
       ROUND(SUM(Profit) * 100.0 / NULLIF(SUM(Sales), 0), 2) AS Margin_Pct
FROM dbo.vw_CleanOrders
GROUP BY Region
ORDER BY Margin_Pct ASC;

SELECT Category, Sub_Category,
       SUM(Sales) AS Sales, SUM(Profit) AS Profit,
       ROUND(SUM(Profit) * 100.0 / NULLIF(SUM(Sales), 0), 2) AS Margin_Pct
FROM dbo.vw_CleanOrders
GROUP BY Category, Sub_Category
ORDER BY Margin_Pct ASC;
```

### 10. Final Semantic Model for Power BI
The single governed view Power BI connects to — joins cleaned fact and dimension layers and flags returned orders.
```sql
CREATE VIEW dbo.vw_Final_Superstore_Dashboard AS
SELECT
    o.*,
    p.Person AS Regional_Manager,
    CASE WHEN r.Order_ID IS NOT NULL THEN 1 ELSE 0 END AS Is_Returned
FROM dbo.vw_CleanOrders  o
LEFT JOIN dbo.vw_CleanPeople  p ON o.Region = p.Region
LEFT JOIN dbo.vw_CleanReturns r ON o.Order_ID = r.Order_ID;
```

> Full script with every query, comment, and validation step: [`01_sql_queries/01_global_superstore_analysis.sql`](./01_sql_queries/01_global_superstore_analysis.sql)

</details>

<details>
<summary><b>📊 See Power BI DAX measures</b></summary>

```DAX
Total Sales = SUM(vw_Final_Superstore_Dashboard[Sales])

Total Profit = SUM(vw_Final_Superstore_Dashboard[Profit])

Profit Margin % = DIVIDE([Total Profit], [Total Sales])

Average Discount = AVERAGE(vw_Final_Superstore_Dashboard[Discount])

Total Orders = DISTINCTCOUNT(vw_Final_Superstore_Dashboard[Order_ID])

Returned Orders =
CALCULATE(
    DISTINCTCOUNT(vw_Final_Superstore_Dashboard[Order_ID]),
    vw_Final_Superstore_Dashboard[Is_Returned] = 1
)

Return Rate % = DIVIDE([Returned Orders], [Total Orders])
```
*(DAX measures reconstructed to match the dashboard's KPI logic.)*

</details>

---

## 📁 Repository Structure
```text
global-superstore-profitability-analysis-sql-powerbi/
├── 01_sql_queries/
│   └── 01_global_superstore_analysis.sql
├── 02_powerbi_file/
│   └── Global_Superstore_Dashboard.pbix
├── 03_dashboard_images/
│   └── global-superstore-dashboard.jpg
├── 04_dataset/
│   ├── Orders.csv
│   ├── People.csv
│   └── Returns.csv
├── Final Report.pdf
└── README.md
```

---

## 🚀 How to Run

**SQL Server:** Open SSMS → create/select a database → import `Orders.csv`, `People.csv`, `Returns.csv` from `04_dataset/` as `dbo.Orders`, `dbo.People`, `dbo.Returns` → run [`01_global_superstore_analysis.sql`](./01_sql_queries/01_global_superstore_analysis.sql) top to bottom to build the cleaning views and `vw_Final_Superstore_Dashboard`.

**Power BI:** Open `Global_Superstore_Dashboard.pbix` from `02_powerbi_file/` → **Get Data → SQL Server** → point it at `vw_Final_Superstore_Dashboard` (Import mode) → click **Refresh** → explore via the `Is_Returned` slicer and dashboard visuals.

> If the `.pbix` exceeds GitHub's file-size limit, Git LFS may be needed.

---

## 🎓 Skills Demonstrated

**SQL Server:** Data profiling, null/duplicate audits, view-based cleaning, KPI logic, multi-table joins, governed semantic modeling

**Power BI:** Dashboard design, DAX measures, slicers, root-cause visual storytelling (KPI cards, regional map, discount-vs-margin scatter plot)

**Analytical thinking:** Turning a single vague company-wide percentage into a specific, actionable root cause — not just describing numbers, but pointing to the fix

---

## 👨‍💻 Author

**Hafiz Arslan Shafique**
Data Analyst | SQL Server · Power BI

📧 [Email](mailto:hafiz.shafique@esom.com.sa) · 💼 [LinkedIn](https://www.linkedin.com/in/hafiz-arslan-shafique-bc240203664/) · 🗂️ [GitHub](https://github.com/Hafiz-Arslan-Shafique/global-superstore-profitability-analysis-sql-powerbi) · 📞 [Contact](tel:+966579594038)
