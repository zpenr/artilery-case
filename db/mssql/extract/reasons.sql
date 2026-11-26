-- Причины списания
SET NOCOUNT ON;

SELECT 'insert into olap.dim_reasons (external_id, name, parent_id) values ('
    + CAST(ID AS varchar(20)) + ', '''
    + REPLACE(ISNULL(Description, ''), '''', '''''') + ''', '
    + CASE
        WHEN ISNULL(ParentID, 0) = 0 THEN 'null'
        ELSE CAST(ParentID AS varchar(20))
      END
    + ');' AS [sql]
FROM [Front].[dbo].[bm_ReasonDebit]
ORDER BY ID;
