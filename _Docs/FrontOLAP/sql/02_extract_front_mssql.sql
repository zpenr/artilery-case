-- =============================================================================
-- 02_extract_front_mssql.sql
-- SQL-запросы выборки ресурсов из исходной базы Front (MSSQL 2017+).
--
-- Каждый запрос возвращает результат для загрузки в таблицу stg.*.
-- Формат выгрузки:
--   * bcp: разделитель |, без заголовка, UTF-8;
--   * либо GUI (SSMS / Azure Data Studio): CSV с заголовком.
--
-- Порядок столбцов соответствует 01_ddl_olap.sql (раздел STAGING).
-- =============================================================================

USE Front;
GO
SET NOCOUNT ON;
GO

-- =============================================================================
-- 1. ИЗМЕРЕНИЯ
-- =============================================================================

-- 1.1. stg.ranges -> public.dim_ranges
-- Источник: dbo.[size]. external_id = size.ID, name = size.sizeid,
-- factor = size.portionrate. Это соответствует списку из файла преподавателя.
SELECT
    s.ID AS external_id,
    ISNULL(NULLIF(LTRIM(RTRIM(s.sizeid)), ''), 'Единица ' + CONVERT(varchar(20), s.ID)) AS name,
    s.portionrate AS factor
FROM dbo.[size] AS s;
GO

-- 1.2. stg.categories -> public.dim_categories
-- parent_id = category.ParentID (0 заменяется на NULL), как в примере преподавателя.
SELECT
    c.id AS external_id,
    ISNULL(NULLIF(LTRIM(RTRIM(c.description)), ''), 'Без названия') AS name,
    CASE WHEN COALESCE(c.ParentID, 0) = 0 THEN NULL ELSE c.ParentID END AS parent_id
FROM dbo.category AS c;
GO

-- 1.3. stg.vendors -> public.dim_vendors
-- name = vendors.clientid, parent_id = clientgroup, parent_name = vendorgroup.description.
SELECT
    v.id AS external_id,
    ISNULL(NULLIF(LTRIM(RTRIM(v.clientid)), ''), 'Поставщик ' + CONVERT(varchar(20), v.id)) AS name,
    v.clientgroup AS parent_id,
    vg.description AS parent_name
FROM dbo.vendors AS v
INNER JOIN dbo.vendorgroup AS vg
        ON vg.vendorgroupid = v.clientgroup;
GO

-- 1.4. stg.personnel -> public.dim_personnel
SELECT
    p.personid AS external_id,
    LTRIM(RTRIM(
        ISNULL(NULLIF(REPLACE(p.lastname, CHAR(0), ''), ''), '') + ' ' +
        ISNULL(NULLIF(REPLACE(p.firstname, CHAR(0), ''), ''), '') + ' ' +
        ISNULL(NULLIF(REPLACE(p.middlename, CHAR(0), ''), ''), '')
    )) AS name,
    NULLIF(REPLACE(p.lastname, CHAR(0), ''), '') AS last_name,
    NULLIF(REPLACE(p.firstname, CHAR(0), ''), '') AS first_name,
    NULLIF(REPLACE(p.middlename, CHAR(0), ''), '') AS middle_name,
    p.securityaccess AS access_level,
    CAST(CASE WHEN ISNULL(p.flagpos, 0) = 1 THEN 1 ELSE 0 END AS bit) AS has_pos_access,
    CAST(CASE WHEN ISNULL(p.deleteflag, 0) = 1 THEN 1 ELSE 0 END AS bit) AS is_deleted
FROM dbo.personnel AS p;
GO

-- 1.5. stg.payment_types -> public.dim_payment_types
SELECT
    t.transtypeid AS external_id,
    ISNULL(NULLIF(LTRIM(RTRIM(t.description)), ''), 'Способ оплаты ' + CONVERT(varchar(20), t.transtypeid)) AS name
FROM dbo.transtype AS t
WHERE t.transgroupid = 2;
GO

-- 1.6. stg.operation_types -> public.dim_operation_types
SELECT
    ot.ID AS external_id,
    ISNULL(NULLIF(LTRIM(RTRIM(ot.Description)), ''), 'Операция ' + CONVERT(varchar(20), ot.ID)) AS name,
    CAST(CASE WHEN ISNULL(ot.Factor, 1) = -1 THEN -1 ELSE 1 END AS smallint) AS factor
FROM dbo.bm_StorageOperationsType AS ot;
GO

-- 1.7. stg.event_types -> public.dim_event_types
SELECT DISTINCT
    ISNULL(NULLIF(LTRIM(RTRIM(s.Type)), ''), '(не указан)') AS name
FROM dbo.bm_JournalSessions AS s;
GO

-- 1.8. stg.products -> public.dim_products
SELECT
    p.id AS external_id,
    NULLIF(REPLACE(p.productid, CHAR(0), ''), '') AS external_code,
    ISNULL(NULLIF(LTRIM(RTRIM(p.description)), ''), 'Товар ' + CONVERT(varchar(20), p.id)) AS name,
    ISNULL(p.CategoryID, 0) AS category_external_id,
    ISNULL(p.SizeID, 0) AS range_external_id,
    ISNULL(p.cost, 0) AS cost,
    CAST(CASE WHEN ISNULL(p.IsUse, 0) = 1 THEN 1 ELSE 0 END AS bit) AS is_active
FROM dbo.product AS p;
GO

-- 1.9. stg.storages -> public.dim_storages
SELECT
    s.id AS external_id,
    ISNULL(NULLIF(LTRIM(RTRIM(s.description)), ''), 'Склад ' + CONVERT(varchar(20), s.id)) AS name,
    s.CompanyID AS company_external_id,
    comp.CompanyName AS company_name,
    ISNULL(s.ResponsibleID, 0) AS responsible_person_external_id
FROM dbo.storages AS s
LEFT JOIN dbo.bm_Companies AS comp
       ON comp.ID = s.CompanyID;
GO

-- =============================================================================
-- 2. ФАКТЫ
-- =============================================================================

-- 2.1. Закупки -> stg.purchases -> public.fact_purchases
SELECT
    YEAR(s.DateAdd) * 100 + MONTH(s.DateAdd) AS time_code,
    s.ProductID AS product_external_id,
    ISNULL(s.VendorID, 0) AS vendor_external_id,
    ISNULL(p.CategoryID, 0) AS category_external_id,
    s.StorageID AS storage_external_id,
    ISNULL(s.RangeID, 0) AS range_external_id,
    COUNT(*) AS lines_count,
    CAST(SUM(ISNULL(s.[Count], 0)) AS decimal(18,4)) AS quantity,
    CAST(SUM(ISNULL(s.Amount, 0)) AS decimal(18,2)) AS amount,
    CAST(SUM(ISNULL(s.Amount, 0)) /
         NULLIF(SUM(ISNULL(s.[Count], 0)), 0) AS decimal(18,2)) AS avg_price
FROM dbo.bm_StorageOperations AS s
JOIN dbo.product AS p
  ON p.id = s.ProductID
WHERE s.OperationID = 1
GROUP BY
    YEAR(s.DateAdd) * 100 + MONTH(s.DateAdd),
    s.ProductID,
    ISNULL(s.VendorID, 0),
    ISNULL(p.CategoryID, 0),
    s.StorageID,
    ISNULL(s.RangeID, 0);
GO

-- 2.2. Продажи -> stg.sales -> public.fact_sales
SELECT
    YEAR(j.dater) * 100 + MONTH(j.dater) AS time_code,
    ISNULL(p.id, 0) AS product_external_id,
    ISNULL(p.CategoryID, 0) AS category_external_id,
    COUNT(DISTINCT j.receiptn) AS receipts_count,
    COUNT(*) AS lines_count,
    CAST(SUM(CASE WHEN ISNULL(j.flagrefund, 0) = 0
                  THEN ISNULL(j.quantity, 0) ELSE 0 END) AS decimal(18,3)) AS quantity,
    CAST(SUM(CASE WHEN ISNULL(j.flagrefund, 0) = 0
                  THEN ISNULL(j.amount, 0) ELSE 0 END) AS decimal(18,2)) AS revenue,
    CAST(SUM(CASE WHEN ISNULL(j.flagrefund, 0) = 1
                  THEN ISNULL(j.amount, 0) ELSE 0 END) AS decimal(18,2)) AS refund_amount,
    CAST(SUM(ISNULL(j.amount, 0)) AS decimal(18,2)) AS net_revenue
FROM dbo.journal AS j
LEFT JOIN dbo.product AS p
       ON p.productid = j.id
WHERE j.transtype = 101
GROUP BY
    YEAR(j.dater) * 100 + MONTH(j.dater),
    ISNULL(p.id, 0),
    ISNULL(p.CategoryID, 0);
GO

-- 2.3. Оплаты -> stg.payments -> public.fact_payments
SELECT
    YEAR(j.dater) * 100 + MONTH(j.dater) AS time_code,
    j.transtype AS payment_type_external_id,
    COUNT(*) AS operations_count,
    CAST(SUM(ISNULL(j.amount, 0)) AS decimal(18,2)) AS amount
FROM dbo.journal AS j
JOIN dbo.transtype AS t
  ON t.transtypeid = j.transtype
WHERE t.transgroupid = 2
GROUP BY
    YEAR(j.dater) * 100 + MONTH(j.dater),
    j.transtype;
GO

-- 2.4. Работа персонала: события -> stg.personnel_sessions
SELECT
    YEAR(s.DateAdd) * 100 + MONTH(s.DateAdd) AS time_code,
    ISNULL(s.PersonID, 0) AS person_external_id,
    ISNULL(NULLIF(LTRIM(RTRIM(s.Type)), ''), '(не указан)') AS event_type_name,
    COUNT(*) AS sessions_count,
    SUM(CASE WHEN ISNULL(s.IsError, 0) = 1 THEN 1 ELSE 0 END) AS errors_count
FROM dbo.bm_JournalSessions AS s
WHERE s.DateAdd IS NOT NULL
GROUP BY
    YEAR(s.DateAdd) * 100 + MONTH(s.DateAdd),
    ISNULL(s.PersonID, 0),
    ISNULL(NULLIF(LTRIM(RTRIM(s.Type)), ''), '(не указан)');
GO

-- 2.5. Работа персонала: бонусы -> stg.personnel_bonus
SELECT
    YEAR(b.Period) * 100 + MONTH(b.Period) AS time_code,
    ISNULL(b.PersonID, 0) AS person_external_id,
    COUNT(*) AS bonus_records_count,
    CAST(SUM(ISNULL(b.BonusValue, 0)) AS decimal(18,2)) AS bonus_value
FROM dbo.bm_BonusHistory AS b
WHERE b.Period IS NOT NULL
GROUP BY
    YEAR(b.Period) * 100 + MONTH(b.Period),
    ISNULL(b.PersonID, 0);
GO

-- 2.6. Движение товара -> stg.stock -> public.fact_stock
SELECT
    YEAR(s.DateAdd) * 100 + MONTH(s.DateAdd) AS time_code,
    s.ProductID AS product_external_id,
    ISNULL(s.StorageID, 0) AS storage_external_id,
    s.OperationID AS operation_type_external_id,
    ISNULL(s.RangeID, 0) AS range_external_id,
    COUNT(*) AS lines_count,
    CAST(SUM(ISNULL(s.[Count], 0)) AS decimal(18,4)) AS quantity,
    CAST(SUM(ISNULL(s.Amount, 0)) AS decimal(18,2)) AS amount,
    CAST(SUM(ABS(ISNULL(s.Amount, 0))) AS decimal(18,2)) AS turnover_amount
FROM dbo.bm_StorageOperations AS s
WHERE s.DateAdd IS NOT NULL
GROUP BY
    YEAR(s.DateAdd) * 100 + MONTH(s.DateAdd),
    s.ProductID,
    ISNULL(s.StorageID, 0),
    s.OperationID,
    ISNULL(s.RangeID, 0);
GO

-- =============================================================================
-- 3. КОНТРОЛЬНЫЕ ЗАПРОСЫ
-- =============================================================================

SELECT 'units' AS dimension, COUNT(*) AS rows_count FROM dbo.[size]
UNION ALL SELECT 'categories', COUNT(*) FROM dbo.category
UNION ALL SELECT 'vendors', COUNT(*) FROM dbo.vendors v
    INNER JOIN dbo.vendorgroup vg ON vg.vendorgroupid = v.clientgroup
UNION ALL SELECT 'products', COUNT(*) FROM dbo.product
UNION ALL SELECT 'personnel', COUNT(*) FROM dbo.personnel
UNION ALL SELECT 'payment_types', COUNT(*) FROM dbo.transtype WHERE transgroupid = 2
UNION ALL SELECT 'operation_types', COUNT(*) FROM dbo.bm_StorageOperationsType;
GO

SELECT 'Закупки' AS direction, MIN(s.DateAdd) AS period_from, MAX(s.DateAdd) AS period_to, COUNT(*) AS rows_count
FROM dbo.bm_StorageOperations AS s WHERE s.OperationID = 1
UNION ALL
SELECT 'Продажи', MIN(j.dater), MAX(j.dater), COUNT(*)
FROM dbo.journal AS j WHERE j.transtype = 101
UNION ALL
SELECT 'Сессии', MIN(s.DateAdd), MAX(s.DateAdd), COUNT(*)
FROM dbo.bm_JournalSessions AS s
UNION ALL
SELECT 'Бонусы', MIN(b.Period), MAX(b.Period), COUNT(*)
FROM dbo.bm_BonusHistory AS b
UNION ALL
SELECT 'Движение товара', MIN(s.DateAdd), MAX(s.DateAdd), COUNT(*)
FROM dbo.bm_StorageOperations AS s;
GO
