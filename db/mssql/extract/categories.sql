-- Категории товаров
SET NOCOUNT ON;

SELECT 'insert into olap.dim_categories (external_id, name, parent_id) values ('
    + CAST(id AS varchar(20)) + ', '''
    + REPLACE(ISNULL(description, ''), '''', '''''') + ''', '
    + CASE
        WHEN ISNULL(ParentID, 0) = 0 THEN 'null'
        ELSE CAST(ParentID AS varchar(20))
      END
    + ');' AS [sql]
FROM [Front].[dbo].[category]
ORDER BY id;
