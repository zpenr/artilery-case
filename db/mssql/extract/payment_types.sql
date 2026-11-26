-- Виды оплаты
SET NOCOUNT ON;

SELECT 'insert into olap.dim_payment_types (external_id, name) values ('
    + CAST(paymenttypeid AS varchar(20)) + ', '''
    + REPLACE(ISNULL(description, ''), '''', '''''') + ''');' AS [sql]
FROM [Front].[dbo].[paymenttype]
ORDER BY paymenttypeid;
