-- Единицы измерения
SET NOCOUNT ON;

SELECT 'insert into olap.dim_ranges (external_id, group_external_id, short_name, name) values ('
    + CAST(ID AS varchar(20)) + ', '
    + ISNULL(CAST(GroupID AS varchar(20)), 'null') + ', '
    + ISNULL('''' + REPLACE(ShortName, '''', '''''') + '''', 'null') + ', '
    + '''' + REPLACE(ISNULL(Description, ''), '''', '''''') + ''');' AS [sql]
FROM [Front].[dbo].[bm_classifierSizes]
ORDER BY GroupID, ID;
