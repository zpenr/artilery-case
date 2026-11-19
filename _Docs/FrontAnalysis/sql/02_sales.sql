USE Front;
GO
SET NOCOUNT ON;
GO

SELECT
    YEAR(j.dater) AS [Год],
    COUNT(DISTINCT j.receiptn) AS [Чеков],
    COUNT(*) AS [Строк],
    CAST(SUM(CASE WHEN ISNULL(j.flagrefund,0) = 0 THEN j.amount ELSE 0 END) AS decimal(18,2)) AS [Продажи, руб.],
    CAST(SUM(CASE WHEN ISNULL(j.flagrefund,0) = 1 THEN j.amount ELSE 0 END) AS decimal(18,2)) AS [Возвраты, руб.],
    CAST(SUM(j.amount) AS decimal(18,2)) AS [Чистая выручка, руб.],
    CAST(SUM(j.amount) / NULLIF(COUNT(DISTINCT j.receiptn),0) AS decimal(18,2)) AS [Средний чек, руб.]
FROM dbo.journal j
WHERE j.transtype = 101
GROUP BY YEAR(j.dater)
ORDER BY YEAR(j.dater);
GO

SELECT TOP (10)
    j.description AS [Товар],
    CAST(SUM(j.quantity) AS decimal(18,3)) AS [Количество],
    CAST(SUM(j.amount) AS decimal(18,2)) AS [Выручка, руб.],
    COUNT(*) AS [Строк]
FROM dbo.journal j
WHERE j.transtype = 101
GROUP BY j.description
ORDER BY SUM(j.amount) DESC;
GO

SELECT
    t.description AS [Способ оплаты],
    COUNT(*) AS [Операций],
    CAST(SUM(j.amount) AS decimal(18,2)) AS [Сумма, руб.]
FROM dbo.journal j
JOIN dbo.transtype t ON t.transtypeid = j.transtype
WHERE t.transgroupid = 2
GROUP BY t.description
ORDER BY SUM(j.amount) DESC;
GO

SELECT TOP (15)
    ISNULL(c.description, 'Без категории') AS [Категория],
    COUNT(*) AS [Строк],
    CAST(SUM(j.quantity) AS decimal(18,3)) AS [Количество],
    CAST(SUM(j.amount) AS decimal(18,2)) AS [Выручка, руб.]
FROM dbo.journal j
JOIN dbo.product p ON p.productid = j.id
LEFT JOIN dbo.category c ON c.id = p.CategoryID
WHERE j.transtype = 101
GROUP BY c.description
ORDER BY SUM(j.amount) DESC;
GO
