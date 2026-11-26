SET NOCOUNT ON;

SELECT 'insert into olap.fact_buys (external_id, product_external_id, range_external_id, category_external_id, vendor_external_id, quantity, amount, period_id) values ('
    + CAST(s.ID AS varchar(20)) + ', '
    + CAST(s.ProductID AS varchar(20)) + ', '
    + CAST(s.RangeID AS varchar(20)) + ', '
    + ISNULL(CAST(p.CategoryID AS varchar(20)), 'null') + ', '
    + ISNULL(CAST(NULLIF(s.VendorID, 0) AS varchar(20)), 'null') + ', '
    + CAST(s.[Count] AS varchar(40)) + ', '
    + CAST(s.Amount AS varchar(40)) + ', '
    + CAST(YEAR(s.DateAdd) * 100 + MONTH(s.DateAdd) AS varchar(6))
    + ');' AS [sql]
FROM [dbo].[bm_StorageOperations] AS s
JOIN [dbo].[product] AS p ON p.id = s.ProductID
WHERE s.OperationID = 1
ORDER BY s.ID;