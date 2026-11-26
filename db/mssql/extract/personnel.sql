-- Сотрудники
SET NOCOUNT ON;

SELECT 'insert into olap.dim_personnel (external_id, full_name) values ('
    + CAST(personid AS varchar(20)) + ', '''
    + REPLACE(
        ISNULL(CONCAT_WS(' ', NULLIF(lastname, ''), NULLIF(firstname, ''), NULLIF(middlename, '')), ''),
        '''',
        ''''''
      ) + ''');' AS [sql]
FROM [Front].[dbo].[personnel]
ORDER BY personid;
