USE Front;
GO
SET NOCOUNT ON;
GO

SELECT
    ot.Description AS [Операция],
    COUNT(*) AS [Строк],
    CAST(SUM(s.[Count]) AS decimal(18,3)) AS [Количество],
    CAST(SUM(s.Amount) AS decimal(18,2)) AS [Сумма, руб.],
    CONVERT(varchar(10), MIN(s.DateAdd), 120) AS [С],
    CONVERT(varchar(10), MAX(s.DateAdd), 120) AS [По]
FROM dbo.bm_StorageOperations s
JOIN dbo.bm_StorageOperationsType ot ON ot.ID = s.OperationID
GROUP BY ot.Description
ORDER BY COUNT(*) DESC;
GO

SELECT TOP (10)
    p.description AS [Продукт],
    CAST(SUM(CASE WHEN s.OperationID = 1 THEN s.[Count] ELSE 0 END) AS decimal(18,3)) AS [Приход],
    CAST(SUM(CASE WHEN s.OperationID = 2 THEN s.[Count] ELSE 0 END) AS decimal(18,3)) AS [Расход],
    CAST(SUM(ABS(s.Amount)) AS decimal(18,2)) AS [Оборот, руб.]
FROM dbo.bm_StorageOperations s
JOIN dbo.product p ON p.id = s.ProductID
GROUP BY p.description
ORDER BY SUM(ABS(s.Amount)) DESC;
GO

SELECT TOP (10)
    p.description AS [Продукт],
    CAST(SUM(s.[Count]) AS decimal(18,3)) AS [Количество],
    CAST(SUM(s.Amount) AS decimal(18,2)) AS [Сумма, руб.],
    COUNT(*) AS [Строк]
FROM dbo.bm_StorageOperations s
JOIN dbo.product p ON p.id = s.ProductID
WHERE s.OperationID = 2
GROUP BY p.description
ORDER BY SUM(s.Amount) ASC;
GO

SELECT 'product.onhand (не NULL)' AS [Показатель],
       SUM(CASE WHEN onhand IS NOT NULL THEN 1 ELSE 0 END) AS [Значение]
FROM dbo.product
UNION ALL SELECT 'stock', COUNT(*) FROM dbo.stock
UNION ALL SELECT 'storagesonhand', COUNT(*) FROM dbo.storagesonhand
UNION ALL SELECT 'storages', COUNT(*) FROM dbo.storages;
GO

SELECT TOP (10)
    p.description AS [Продукт],
    CAST(SUM(CASE WHEN s.OperationID = 1 THEN s.[Count] ELSE 0 END) AS decimal(18,3)) AS [Приход],
    CAST(SUM(CASE WHEN s.OperationID = 2 THEN s.[Count] ELSE 0 END) AS decimal(18,3)) AS [Расход],
    CAST(SUM(s.[Count]) AS decimal(18,3)) AS [Баланс по движениям],
    CAST(SUM(s.Amount) AS decimal(18,2)) AS [Сумма, руб.]
FROM dbo.bm_StorageOperations s
JOIN dbo.product p ON p.id = s.ProductID
GROUP BY p.description
ORDER BY ABS(SUM(s.[Count])) DESC;
GO
