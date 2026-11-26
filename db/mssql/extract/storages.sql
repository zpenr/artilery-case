-- Склады
SET NOCOUNT ON;

SELECT 'insert into olap.dim_storages (external_id, name) values ('
    + CAST(id AS varchar(20)) + ', '''
    + REPLACE(ISNULL(description, ''), '''', '''''') + ''');' AS [sql]
FROM [Front].[dbo].[storages]
ORDER BY id;
