-- ================================================================
-- ADY201 - INSTACART MARKET BASKET ANALYSIS
-- FILE SQL TONG HOP - Toan bo query cua du an
-- DBMS: Microsoft SQL Server 
-- ================================================================
-- File gom 3 phan:
--   PHAN 1: Cac query phan tich nghiep vu (Business Insight Queries)
--           - 8 query - chi de chay va xem ket qua, KHONG tao doi
--             tuong co dinh trong database
--   PHAN 2: Cac VIEW phuc vu Python ve bieu do EDA va K-mean
--           - 4 VIEW co dinh trong database
--           - 1 VIEW phuc vu cho K-mean
--   PHAN 3: Cac query xuat du lieu cho R, Power BI va mo hinh ML
--           - 5 query SELECT sau do xuat qua CSV
--           - 1 VIEW feature_table co dinh trong database 
-- ================================================================

USE Project_ADY201m
GO


-- ################################################################
-- PHAN 1: CAC QUERY PHAN TICH NGHIEP VU (BUSINESS INSIGHT QUERIES)
-- ----------------------------------------------------------------
-- Muc dich chung : Khai thac truc tiep du lieu da nap trong SQL
--                  Server de tra loi cac cau hoi kinh doanh cu the
--                  cua Instacart. Cac query minh chung day du cac
--                  ky thuat: Filtering, Grouping, Aggregations,
--                  Multi-table JOIN, Subquery, Window Function.
-- ################################################################


-- ============================================================
-- Query 1: San pham duoc mua nhieu nhat tren Instacart
-- ------------------------------------------------------------
-- Muc dich : Xac dinh 20 san pham co tong so lan xuat hien trong
--            don hang (duoc mua) nhieu nhat tren toan platform.
-- Dau vao  : order_products_prior JOIN products (theo product_id)
-- Dau ra   : 20 dong - product_id, product_name, total_orders
-- Ky thuat : JOIN, GROUP BY, COUNT, ORDER BY, TOP
-- Y nghia  : Co so de uu tien ton kho, dam bao san pham "an
--            khach" khong bao gio het hang.
-- ============================================================
SELECT TOP 20
    p.product_id,
    p.product_name,
    COUNT(*) AS total_orders
FROM order_products_prior opp
JOIN products p
    ON opp.product_id = p.product_id
GROUP BY p.product_id, p.product_name
ORDER BY total_orders DESC;
GO


-- ============================================================
-- Query 2: Nhom hang (Department) co khoi luong mua lon nhat
-- ------------------------------------------------------------
-- Muc dich : Xac dinh department tao ra tong so luong san pham
--            ban ra (sales volume) lon nhat.
-- Dau vao  : order_products_prior JOIN products JOIN departments
-- Dau ra   : 21 dong (toan bo department) - department,
--            total_items_sold
-- Ky thuat : Multi-table JOIN (3 bang), GROUP BY, COUNT, ORDER BY
-- Y nghia  : Phan bo ngan sach marketing va khong gian kho theo
--            dung ty trong dong gop cua tung nhom hang.
-- ============================================================
SELECT
    d.department,
    COUNT(*) AS total_items_sold
FROM order_products_prior opp
JOIN products p
    ON opp.product_id = p.product_id
JOIN departments d
    ON p.department_id = d.department_id
GROUP BY d.department
ORDER BY total_items_sold DESC;
GO


-- ============================================================
-- Query 3: Nhu cau khach hang theo danh muc (Aisle)
-- ------------------------------------------------------------
-- Muc dich : Xac dinh 20 danh muc san pham (aisle) duoc khach
--            hang mua nhieu nhat.
-- Dau vao  : order_products_prior JOIN products JOIN aisles
-- Dau ra   : 20 dong - aisle, total_orders
-- Ky thuat : Multi-table JOIN (3 bang), GROUP BY, COUNT,
--            ORDER BY, TOP
-- Y nghia  : Phuc vu bo tri ke hang va toi uu trai nghiem tim
--            kiem san pham cho khach.
-- ============================================================
SELECT TOP 20
    a.aisle,
    COUNT(*) AS total_orders
FROM order_products_prior opp
JOIN products p
    ON opp.product_id = p.product_id
JOIN aisles a
    ON p.aisle_id = a.aisle_id
GROUP BY a.aisle
ORDER BY total_orders DESC;
GO


-- ============================================================
-- Query 4: Do trung thanh cua khach hang theo Department
-- ------------------------------------------------------------
-- Muc dich : Tinh ty le dat lai (reorder rate) trung binh cho
--            moi department.
-- Dau vao  : order_products_prior JOIN products JOIN departments
-- Dau ra   : 21 dong - department, reorder_rate (%)
-- Ky thuat : Multi-table JOIN, GROUP BY, AVG, CAST, ROUND,
--            ORDER BY
-- Y nghia  : Department co reorder_rate cao la noi khach hang
--            gan bo voi san pham cu the - nen uu tien hien thi
--            tinh nang "mua lai nhanh" (quick reorder) o day.
-- ============================================================
SELECT
    d.department,
    ROUND(AVG(CAST(opp.reordered AS FLOAT)) * 100, 2) AS reorder_rate
FROM order_products_prior opp
JOIN products p
    ON opp.product_id = p.product_id
JOIN departments d
    ON p.department_id = d.department_id
GROUP BY d.department
ORDER BY reorder_rate DESC;
GO


-- ============================================================
-- Query 5: Khach hang co hoat dong mua sam nhieu nhat
-- ------------------------------------------------------------
-- Muc dich : Tim 20 nguoi dung mua tong so san pham (gop tat ca
--            don hang) nhieu nhat - ung vien cho chuong trinh
--            khach hang VIP / loyalty.
-- Dau vao  : orders JOIN order_products_prior (theo order_id)
-- Dau ra   : 20 dong - user_id, total_products
-- Ky thuat : JOIN, GROUP BY, COUNT, ORDER BY, TOP
-- Y nghia  : Danh sach ung vien cho chuong trinh khach hang
--            VIP / loyalty.
-- ============================================================
SELECT TOP 20
    o.user_id,
    COUNT(*) AS total_products
FROM orders o
JOIN order_products_prior opp
    ON o.order_id = opp.order_id
GROUP BY o.user_id
ORDER BY total_products DESC;
GO


-- ============================================================
-- Query 6: Khach hang co tan suat mua cao hon trung binh
-- ------------------------------------------------------------
-- Muc dich : Tim cac nguoi dung co tong so don hang vuot qua so
--            don hang trung binh cua toan bo khach hang.
-- Dau vao  : orders (tu doi chieu voi gia tri trung binh toan
--            he thong, tinh qua subquery long trong HAVING)
-- Dau ra   : N dong - user_id, frequency, avg_days_between_orders
-- Ky thuat : GROUP BY, HAVING, Subquery (long trong HAVING), AVG
-- Y nghia  : Phan biet ro nhom khach hang trung thanh / mua
--            thuong xuyen voi nhom khach hang thong thuong.
-- ============================================================
SELECT
    user_id,
    COUNT(order_id) AS frequency,
    AVG(days_since_prior_order) AS avg_days_between_orders
FROM orders
GROUP BY user_id
HAVING COUNT(order_id) > (
    SELECT AVG(order_count)
    FROM (
        SELECT COUNT(*) AS order_count
        FROM orders
        GROUP BY user_id
    ) x
)
ORDER BY frequency DESC;
GO


-- ============================================================
-- Query 7: Hoat dong mua sam tich luy theo thoi gian
-- ------------------------------------------------------------
-- Muc dich : Voi moi nguoi dung, tinh so san pham mua trong tung
--            don hang VA tong so san pham tich luy (cumulative)
--            tinh den don hang do, theo thu tu order_number.
-- Dau vao  : orders JOIN order_products_prior (theo order_id)
-- Dau ra   : N dong - user_id, order_number, products_in_order,
--            cumulative_products
-- Ky thuat : JOIN, GROUP BY, Window Function
--            SUM(...) OVER (PARTITION BY ... ORDER BY ...)
-- Y nghia  : Theo doi "vong doi tang truong" cua tung khach hang
--            - khach co duong tich luy doc len nhanh la khach
--            gia tri cao, dang gan bo manh voi platform.
-- ============================================================
SELECT
    o.user_id,
    o.order_number,
    COUNT(opp.product_id) AS products_in_order,
    SUM(COUNT(opp.product_id)) OVER (
        PARTITION BY o.user_id
        ORDER BY o.order_number
    ) AS cumulative_products
FROM orders o
JOIN order_products_prior opp
    ON o.order_id = opp.order_id
GROUP BY o.user_id, o.order_number
ORDER BY o.user_id, o.order_number;
GO


-- ============================================================
-- Query 8: Xep hang san pham ban chay nhat trong tung Department
-- ------------------------------------------------------------
-- Muc dich : Voi moi department, xep hang 5 san pham ban chay
--            nhat trong noi bo department do.
-- Dau vao  : order_products_prior JOIN products JOIN departments
-- Dau ra   : ~105 dong (5 san pham x 21 department) - department,
--            product_name, total_sales, ranking_in_department
-- Ky thuat : Multi-table JOIN, GROUP BY, Window Function
--            RANK() OVER (PARTITION BY ... ORDER BY ...),
--            Subquery (derived table), Filtering tren ket qua
--            da rank (WHERE ranking_in_department <= 5)
-- Y nghia  : Phuc vu uu tien trung bay va quang ba san pham theo
--            dung tung nhom hang rieng, thay vi ap dung chien
--            luoc chung cho ca platform.
-- ============================================================
SELECT *
FROM (
    SELECT
        d.department,
        p.product_name,
        COUNT(*) AS total_sales,
        RANK() OVER (
            PARTITION BY d.department
            ORDER BY COUNT(*) DESC
        ) AS ranking_in_department
    FROM order_products_prior opp
    JOIN products p
        ON opp.product_id = p.product_id
    JOIN departments d
        ON p.department_id = d.department_id
    GROUP BY d.department, p.product_name
) x
WHERE ranking_in_department <= 5
ORDER BY department, ranking_in_department;
GO


-- ################################################################
-- PHAN 2: CAC VIEW PHUC VU PYTHON VE BIEU DO EDA 
-- ----------------------------------------------------------------
-- Muc dich chung : Tao 6 VIEW de Python doc truc tiep qua
--                  pd.read_sql() thay vi xuat file CSV trung gian
--                  (tranh ton ~3.7 GB dung luong cho bang lam
--                  viec tong hop ~32 trieu dong).
-- ################################################################


-- ============================================================
-- VIEW 1: vw_basket_size
-- ------------------------------------------------------------
-- Muc dich : Tinh tong so san pham trong moi don hang.
-- Dau vao  : orders JOIN order_products_prior (theo order_id)
-- Dau ra   : ~3.2 trieu dong - order_id, user_id, basket_size
-- Dung cho : Bieu do B1 - Histogram + Boxplot kich thuoc gio hang
-- ============================================================
IF OBJECT_ID('dbo.vw_basket_size', 'V') IS NOT NULL
    DROP VIEW dbo.vw_basket_size;
GO
CREATE VIEW dbo.vw_basket_size AS
SELECT
    o.order_id,
    o.user_id,
    COUNT(opp.product_id) AS basket_size
FROM orders o
INNER JOIN order_products_prior opp ON o.order_id = opp.order_id
GROUP BY o.order_id, o.user_id;
GO


-- ============================================================
-- VIEW 2: vw_order_cycle
-- ------------------------------------------------------------
-- Muc dich : Lay so ngay giua hai don hang lien tiep, bo qua
--            cac don hang dau tien (khong co don truoc de tinh
--            khoang cach).
-- Dau vao  : orders, loc WHERE is_first_order = 0
-- Dau ra   : ~3.2 trieu dong - order_id, user_id,
--            days_since_prior_order
-- Dung cho : Bieu do B2 - Boxplot + Histogram chu ky dat hang
-- ============================================================
IF OBJECT_ID('dbo.vw_order_cycle', 'V') IS NOT NULL
    DROP VIEW dbo.vw_order_cycle;
GO
CREATE VIEW dbo.vw_order_cycle AS
SELECT
    order_id,
    user_id,
    days_since_prior_order
FROM orders
WHERE is_first_order = 0;
GO


-- ============================================================
-- VIEW 3: vw_order_heatmap
-- ------------------------------------------------------------
-- Muc dich : Dem so don hang theo tung to hop gio (0-23) va
--            ngay trong tuan (0-6).
-- Dau vao  : orders (GROUP BY order_dow, order_hour_of_day)
-- Dau ra   : 168 dong (7 ngay x 24 gio) - order_dow,
--            order_hour_of_day, order_count
-- Dung cho : Bieu do B3 - Ban do nhiet gio x ngay
-- ============================================================
IF OBJECT_ID('dbo.vw_order_heatmap', 'V') IS NOT NULL
    DROP VIEW dbo.vw_order_heatmap;
GO
CREATE VIEW dbo.vw_order_heatmap AS
SELECT
    order_dow,
    order_hour_of_day,
    COUNT(order_id) AS order_count
FROM orders
GROUP BY order_dow, order_hour_of_day;
GO

-- ============================================================
-- VIEW 4: vw_rfm
-- ------------------------------------------------------------
-- Muc dich : Tinh 3 chi so hanh vi RFM cho moi nguoi dung, lam
--            du lieu dau vao truc tiep cho thuat toan K-Means o
--            Python. Python doc VIEW nay qua cung
--            engine ket noi da dung cho cac VIEW EDA khac
--            (khong xuat ra file CSV trung gian).
--   Recency (Gan day)    - days_since_prior_order cua don hang
--                          co order_number lon nhat moi user
--   Frequency (Tan suat) - tong so don hang theo user_id
--   Monetary (Khoi luong, dung thay the vi dataset khong co gia
--             san pham) - tong so san pham da mua
-- Dau vao  : orders, order_products_prior
-- Dau ra   : ~206,000 dong - user_id, recency, frequency,
--            monetary
-- Dung cho : K-Means - Phan nhom khach hang theo RFM
--            , doc bang pd.read_sql("SELECT * FROM
--            vw_rfm", engine)
-- Ky thuat : CTE (3 CTE), Window Function
--            ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...),
--            LEFT JOIN, COALESCE (xu ly NULL)
-- ============================================================
IF OBJECT_ID('dbo.vw_rfm', 'V') IS NOT NULL
    DROP VIEW dbo.vw_rfm;
GO
CREATE VIEW dbo.vw_rfm AS
WITH recency_cte AS (
    SELECT user_id, days_since_prior_order AS recency
    FROM (
        SELECT
            user_id,
            days_since_prior_order,
            ROW_NUMBER() OVER (
                PARTITION BY user_id
                ORDER BY order_number DESC
            ) AS rn
        FROM orders
        WHERE is_first_order = 0
    ) t
    WHERE rn = 1
),
frequency_cte AS (
    SELECT user_id, COUNT(order_id) AS frequency
    FROM orders
    GROUP BY user_id
),
monetary_cte AS (
    SELECT o.user_id, COUNT(opp.product_id) AS monetary
    FROM orders o
    INNER JOIN order_products_prior opp ON o.order_id = opp.order_id
    GROUP BY o.user_id
)
SELECT
    f.user_id,
    COALESCE(r.recency,  0) AS recency,
    f.frequency,
    COALESCE(m.monetary, 0) AS monetary
FROM frequency_cte f
LEFT JOIN recency_cte  r ON f.user_id = r.user_id
LEFT JOIN monetary_cte m ON f.user_id = m.user_id;
GO
-- ============================================================
-- Kiem tra: phai hien thi dung 4 dong
-- ============================================================
SELECT
    name                                   AS view_name,
    CONVERT(VARCHAR(19), create_date, 120) AS created_at
FROM sys.views
WHERE name IN (
    'vw_basket_size', 'vw_order_cycle', 'vw_order_heatmap', 'vw_rfm'
)
ORDER BY name;
GO


-- ################################################################
-- PHAN 3: CAC QUERY XUAT DU LIEU CHO R, POWER BI VA MO HINH ML
-- ----------------------------------------------------------------
-- Muc dich chung : Cac SELECT duoi day duoc ghi file CSV.
-- ################################################################


-- ============================================================
-- Query xuat 1: Du lieu giao dich cho R (Phan tich Apriori)
-- ------------------------------------------------------------
-- Muc dich : Tao du lieu dau vao cho thuat toan Apriori trong R.
--            Lay mau ngau nhien 100,000 don hang (tu prior set)
--            de tranh tran bo nho khi R xu ly.
-- Dau vao  : orders (loc eval_set = 'prior', lay mau bang
--            TOP 100000 ... ORDER BY NEWID())
--            JOIN order_products_prior JOIN products
-- Dau ra   : ~100,000 dong - order_id, items (ten san pham noi
--            bang dau phay qua STRING_AGG)
-- File CSV : transactions.csv 
-- Ky thuat : Subquery (derived table) lay mau, Multi-table JOIN,
--            STRING_AGG (ham noi chuoi cua SQL Server)
-- ============================================================
SELECT
    opp.order_id,
    STRING_AGG(p.product_name, ',') AS items
FROM (
    SELECT TOP 100000 order_id
    FROM orders
    WHERE eval_set = 'prior'
    ORDER BY NEWID()
) sampled
INNER JOIN order_products_prior opp ON sampled.order_id = opp.order_id
INNER JOIN products p ON opp.product_id = p.product_id
GROUP BY opp.order_id;
GO


-- ============================================================
-- Query xuat 2: Chi so tong quan KPI cho Power BI
-- ------------------------------------------------------------
-- Muc dich : Cung cap 4 chi so KPI cho trang tong quan Power BI
--            (hien thi duoi dang the so - card visual).
-- Dau vao  : orders, order_products_prior
-- Dau ra   : 1 dong x 4 cot - tong_nguoi_dung, tong_don_hang,
--            chu_ky_tb_ngay, phan_tram_dat_lai
-- File CSV : summary_stats.csv
-- Ky thuat : Subquery doc lap (scalar subquery) trong SELECT,
--            CAST, ROUND, NULLIF
-- ============================================================
SELECT
    (SELECT COUNT(DISTINCT user_id)
     FROM orders) AS tong_nguoi_dung,

    (SELECT COUNT(DISTINCT order_id)
     FROM orders
     WHERE eval_set = 'prior') AS tong_don_hang,

    (SELECT ROUND(AVG(CAST(days_since_prior_order AS FLOAT)), 2)
     FROM orders
     WHERE is_first_order = 0) AS chu_ky_tb_ngay,

    (SELECT ROUND(
         100.0 * CAST(SUM(reordered) AS FLOAT) / NULLIF(COUNT(*), 0),
         2)
     FROM order_products_prior) AS phan_tram_dat_lai;
GO


-- ============================================================
-- Query xuat 3: Du lieu ban do nhiet cho Power BI
-- ------------------------------------------------------------
-- Muc dich : Cung cap so don hang theo gio x ngay cho trang
--            "Hanh vi mua sam" trong Power BI.
-- Dau vao  : orders
-- Dau ra   : 168 dong - order_dow, order_hour_of_day, so_don_hang
-- File CSV : order_heatmap.csv
--            (Luu y: order_dow = 0 la Chu nhat - Power BI can
--            them cot nhan ngay trong Power Query)
-- Ky thuat : GROUP BY, COUNT, ORDER BY
-- ============================================================
SELECT
    order_dow,
    order_hour_of_day,
    COUNT(order_id) AS so_don_hang
FROM orders
GROUP BY order_dow, order_hour_of_day
ORDER BY order_dow, order_hour_of_day;
GO


-- ============================================================
-- Query xuat 4: Top san pham ban chay cho Power BI
-- ------------------------------------------------------------
-- Muc dich : Cung cap danh sach 50 san pham ban chay nhat kem
--            thong tin danh muc.
-- Dau vao  : order_products_prior JOIN products JOIN aisles
--            JOIN departments (4 bang)
-- Dau ra   : 50 dong - product_name, aisle, department,
--            so_lan_mua, pct_dat_lai
-- File CSV : top_products.csv
-- Ky thuat : Multi-table JOIN (4 bang), GROUP BY, CAST, ROUND,
--            NULLIF, TOP
-- ============================================================
SELECT TOP 50
    p.product_name,
    a.aisle,
    d.department,
    COUNT(opp.product_id) AS so_lan_mua,
    ROUND(
        100.0 * CAST(SUM(opp.reordered) AS FLOAT) / NULLIF(COUNT(*), 0),
        2) AS pct_dat_lai
FROM order_products_prior opp
INNER JOIN products    p ON opp.product_id  = p.product_id
INNER JOIN aisles      a ON p.aisle_id      = a.aisle_id
INNER JOIN departments d ON p.department_id = d.department_id
GROUP BY p.product_id, p.product_name, a.aisle, d.department
ORDER BY so_lan_mua DESC;
GO


-- ============================================================
-- Query xuat 5a: Top danh muc (Aisle) cho Power BI
-- ------------------------------------------------------------
-- Muc dich : Cung cap thong ke 20 danh muc san pham ban chay
--            nhat cho bieu do danh muc trong Power BI.
-- Dau vao  : order_products_prior JOIN products JOIN aisles
--            JOIN departments
-- Dau ra   : 20 dong - aisle, department, so_lan_mua
-- File CSV : top_aisles.csv
-- Ky thuat : Multi-table JOIN, GROUP BY, COUNT, TOP
-- ============================================================
SELECT TOP 20
    a.aisle,
    d.department,
    COUNT(opp.product_id) AS so_lan_mua
FROM order_products_prior opp
INNER JOIN products    p ON opp.product_id  = p.product_id
INNER JOIN aisles      a ON p.aisle_id      = a.aisle_id
INNER JOIN departments d ON p.department_id = d.department_id
GROUP BY a.aisle_id, a.aisle, d.department
ORDER BY so_lan_mua DESC;
GO


-- ============================================================
-- Query xuat 5b: Top nhom hang (Department) cho Power BI
-- ------------------------------------------------------------
-- Muc dich : Cung cap thong ke toan bo 21 department kem ty le
--            dat lai cho bieu do danh muc trong Power BI.
-- Dau vao  : order_products_prior JOIN products JOIN departments
-- Dau ra   : 21 dong - department, so_lan_mua, pct_dat_lai
-- File CSV : top_departments.csv
-- Ky thuat : Multi-table JOIN, GROUP BY, CAST, ROUND, NULLIF
-- ============================================================
SELECT
    d.department,
    COUNT(opp.product_id) AS so_lan_mua,
    ROUND(
        100.0 * CAST(SUM(opp.reordered) AS FLOAT) / NULLIF(COUNT(*), 0),
        2) AS pct_dat_lai
FROM order_products_prior opp
INNER JOIN products    p ON opp.product_id  = p.product_id
INNER JOIN departments d ON p.department_id = d.department_id
GROUP BY d.department_id, d.department
ORDER BY so_lan_mua DESC;
GO

-- ============================================================
-- VIEW feature_table: Bang dac trung cho mo hinh hoc may
-- ------------------------------------------------------------
-- Muc dich : Tong hop tat ca dac trung hanh vi cua nguoi dung
--            va san pham thanh mot bang phang duy nhat, lam dau
--            vao truc tiep cho mo hinh XGBoost o Python.
--             Dung VIEW (khong xuat CSV) vi bang co
--            ~1.4 trieu dong x 10 cot - Python doc truc tiep
--            qua pd.read_sql('SELECT * FROM feature_table').
-- Dau vao  : order_products_train (bang chinh) JOIN orders,
--            order_products_prior thong qua 4 CTE
-- Dau ra   : VIEW feature_table - ~1.4 trieu dong x 10 cot
-- Canh bao : VIEW nay co 4 CTE nang voi JOIN tren bang 32 trieu
--            dong. Lan dau doc bang pd.read_sql() co the mat
--            5-15 phut tuy cau hinh may - day la binh thuong.
-- Ky thuat : CTE (4 CTE doc lap), LEFT JOIN nhieu bang,
--            CAST, ROUND, NULLIF, COALESCE
-- ============================================================
IF OBJECT_ID('dbo.feature_table', 'V') IS NOT NULL
    DROP VIEW dbo.feature_table;
GO
CREATE VIEW dbo.feature_table AS
WITH user_features AS (
    SELECT
        user_id,
        COUNT(order_id)                            AS user_total_orders,
        AVG(CAST(days_since_prior_order AS FLOAT)) AS user_avg_days_between_orders,
        MAX(order_number)                          AS user_max_order_number
    FROM orders
    GROUP BY user_id
),
user_reorder AS (
    SELECT
        o.user_id,
        ROUND(
            CAST(SUM(opp.reordered) AS FLOAT)
                / NULLIF(COUNT(opp.product_id), 0),
            4
        ) AS user_reorder_ratio
    FROM orders o
    INNER JOIN order_products_prior opp ON o.order_id = opp.order_id
    GROUP BY o.user_id
),
product_features AS (
    SELECT
        product_id,
        ROUND(
            CAST(SUM(reordered) AS FLOAT) / NULLIF(COUNT(*), 0),
            4
        )                                      AS product_reorder_rate,
        AVG(CAST(add_to_cart_order AS FLOAT))  AS avg_add_to_cart_position
    FROM order_products_prior
    GROUP BY product_id
),
user_product_features AS (
    SELECT
        o.user_id,
        opp.product_id,
        COUNT(*) AS user_product_times_bought
    FROM orders o
    INNER JOIN order_products_prior opp ON o.order_id = opp.order_id
    GROUP BY o.user_id, opp.product_id
)
SELECT
    t.order_id,
    o.user_id,
    t.product_id,
    t.reordered,
    COALESCE(uf.user_total_orders,            0) AS user_total_orders,
    COALESCE(uf.user_avg_days_between_orders, 0) AS user_avg_days_between_orders,
    COALESCE(ur.user_reorder_ratio,           0) AS user_reorder_ratio,
    COALESCE(pf.product_reorder_rate,         0) AS product_reorder_rate,
    COALESCE(pf.avg_add_to_cart_position,     0) AS avg_add_to_cart_position,
    COALESCE(upf.user_product_times_bought,   0) AS user_product_times_bought
FROM order_products_train       t
LEFT JOIN orders                o   ON t.order_id   = o.order_id
LEFT JOIN user_features         uf  ON o.user_id    = uf.user_id
LEFT JOIN user_reorder          ur  ON o.user_id    = ur.user_id
LEFT JOIN product_features      pf  ON t.product_id = pf.product_id
LEFT JOIN user_product_features upf ON o.user_id    = upf.user_id
                                    AND t.product_id = upf.product_id;
GO


-- ================================================================
-- KET THUC FILE
-- ================================================================
