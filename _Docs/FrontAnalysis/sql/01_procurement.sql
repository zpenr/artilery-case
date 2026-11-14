USE Front;
GO
SET NOCOUNT ON;
GO

SELECT
    YEAR(DateAdd) AS [Год],
    COUNT(*) AS [Строк],
    CAST(SUM([Count]) AS decimal(18,3)) AS [Количество],
    CAST(SUM(Amount) AS decimal(18,2)) AS [Сумма, руб.],
    CAST(SUM(Amount) / NULLIF(SUM([Count]),0) AS decimal(18,2)) AS [Средняя цена, руб.]
FROM dbo.bm_StorageOperations
WHERE OperationID = 1
GROUP BY YEAR(DateAdd)
ORDER BY YEAR(DateAdd);
GO

SELECT TOP (10)
    p.description AS [Продукт],
    CAST(SUM(s.[Count]) AS decimal(18,3)) AS [Количество],
    CAST(SUM(s.Amount) AS decimal(18,2)) AS [Сумма, руб.],
    COUNT(*) AS [Строк]
FROM dbo.bm_StorageOperations s
JOIN dbo.product p ON p.id = s.ProductID
WHERE s.OperationID = 1
GROUP BY p.description
ORDER BY SUM(s.Amount) DESC;
GO

SELECT TOP (10)
    s.VendorID AS [Код поставщика],
    ISNULL(NULLIF(v.firstname, ''), v.lastname) AS [Поставщик],
    COUNT(*) AS [Строк],
    CAST(SUM(s.Amount) AS decimal(18,2)) AS [Сумма, руб.]
FROM dbo.bm_StorageOperations s
LEFT JOIN dbo.vendors v ON v.id = s.VendorID
WHERE s.OperationID = 1
GROUP BY s.VendorID, ISNULL(NULLIF(v.firstname, ''), v.lastname)
ORDER BY SUM(s.Amount) DESC;
GO

SELECT TOP (15)
    ISNULL(c.description, 'Без категории') AS [Категория],
    COUNT(*) AS [Строк],
    CAST(SUM(s.[Count]) AS decimal(18,3)) AS [Количество],
    CAST(SUM(s.Amount) AS decimal(18,2)) AS [Сумма, руб.]
FROM dbo.bm_StorageOperations s
JOIN dbo.product p ON p.id = s.ProductID
LEFT JOIN dbo.category c ON c.id = p.CategoryID
WHERE s.OperationID = 1
GROUP BY c.description
ORDER BY SUM(s.Amount) DESC;
GO
