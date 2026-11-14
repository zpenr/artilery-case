USE Front;
GO
SET NOCOUNT ON;
GO

SELECT
    ISNULL(vg.description, 'Без группы') AS [Группа],
    COUNT(*) AS [Всего],
    SUM(CASE WHEN v.IsUse = 1 THEN 1 ELSE 0 END) AS [Активных]
FROM dbo.vendors v
LEFT JOIN dbo.vendorgroup vg ON vg.vendorgroupid = v.clientgroup
GROUP BY vg.description
ORDER BY COUNT(*) DESC;
GO

SELECT TOP (10)
    s.VendorID AS [Код],
    ISNULL(NULLIF(v.firstname, ''), v.lastname) AS [Поставщик],
    COUNT(DISTINCT s.ProductID) AS [Позиций],
    COUNT(*) AS [Строк],
    CAST(SUM(s.Amount) AS decimal(18,2)) AS [Сумма, руб.],
    CAST(100.0 * SUM(s.Amount) /
         (SELECT SUM(Amount) FROM dbo.bm_StorageOperations WHERE OperationID = 1)
         AS decimal(5,1)) AS [Доля, %]
FROM dbo.bm_StorageOperations s
LEFT JOIN dbo.vendors v ON v.id = s.VendorID
WHERE s.OperationID = 1
GROUP BY s.VendorID, ISNULL(NULLIF(v.firstname, ''), v.lastname)
ORDER BY SUM(s.Amount) DESC;
GO

SELECT
    COUNT(*) AS [Всего],
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(INN)), '') IS NOT NULL THEN 1 ELSE 0 END) AS [ИНН],
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(teln)), '') IS NOT NULL THEN 1 ELSE 0 END) AS [Телефон],
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(emaliaddress)), '') IS NOT NULL THEN 1 ELSE 0 END) AS [Email],
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(contactperson)), '') IS NOT NULL THEN 1 ELSE 0 END) AS [Контактное лицо],
    SUM(CASE WHEN IsUse = 1 THEN 1 ELSE 0 END) AS [Активных]
FROM dbo.vendors;
GO

SELECT 'product.vendorid' AS [Связь],
       COUNT(*) AS [Всего строк],
       SUM(CASE WHEN v.id IS NOT NULL THEN 1 ELSE 0 END) AS [Заполнено]
FROM dbo.product p
LEFT JOIN dbo.vendors v ON v.id = p.vendorid
UNION ALL
SELECT 'bm_StorageOperations.VendorID', COUNT(*), SUM(CASE WHEN v.id IS NOT NULL THEN 1 ELSE 0 END)
FROM dbo.bm_StorageOperations s
LEFT JOIN dbo.vendors v ON v.id = s.VendorID
WHERE s.OperationID = 1
UNION ALL
SELECT 'bm_Contracts.VendorID', COUNT(*), ISNULL(SUM(CASE WHEN v.id IS NOT NULL THEN 1 ELSE 0 END), 0)
FROM dbo.bm_Contracts c
LEFT JOIN dbo.vendors v ON v.id = c.VendorID;
GO

SELECT 'bm_Contracts' AS [Объект], COUNT(*) AS [Строк] FROM dbo.bm_Contracts
UNION ALL SELECT 'bm_Companies', COUNT(*) FROM dbo.bm_Companies
UNION ALL SELECT 'complaince', COUNT(*) FROM dbo.complaince;
GO
