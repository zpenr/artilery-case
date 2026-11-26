-- Единицы измерения
SET NOCOUNT ON;

SELECT 'insert into olap.dim_ranges (external_id, group_external_id, short_name, name) values ('
    + CAST(ID AS varchar(20)) + ', null, '
    + ISNULL('''' + REPLACE(sizeid, '''', '''''') + '''', 'null') + ', '
    + '''' + REPLACE(ISNULL(description, ''), '''', '''''') + ''');' AS [sql]
FROM [Front].[dbo].[size]
ORDER BY ID;
