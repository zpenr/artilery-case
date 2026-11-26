-- Товары
SET NOCOUNT ON;

SELECT 'insert into olap.dim_products (external_id, code, name) values ('
    + CAST(id AS varchar(20)) + ', '
    + ISNULL('''' + REPLACE(productid, '''', '''''') + '''', 'null') + ', '''
    + REPLACE(ISNULL(description, ''), '''', '''''') + ''');' AS [sql]
FROM [Front].[dbo].[product]
ORDER BY id;
