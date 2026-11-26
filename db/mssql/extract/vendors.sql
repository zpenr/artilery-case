-- Поставщики вместе с группой
SET NOCOUNT ON;

SELECT 'insert into olap.dim_vendors (external_id, name, group_external_id, group_name) values ('
    + CAST(v.id AS varchar(20)) + ', '''
    + REPLACE(ISNULL(v.clientid, ''), '''', '''''') + ''', '
    + ISNULL(CAST(v.clientgroup AS varchar(20)), 'null') + ', '
    + ISNULL('''' + REPLACE(g.description, '''', '''''') + '''', 'null') + ');' AS [sql]
FROM [Front].[dbo].[vendors] v
LEFT JOIN [Front].[dbo].[vendorgroup] g ON g.vendorgroupid = v.clientgroup
ORDER BY v.id;
