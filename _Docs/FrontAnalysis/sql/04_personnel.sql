USE Front;
GO
SET NOCOUNT ON;
GO

SELECT
    securityaccess AS [Уровень доступа],
    COUNT(*) AS [Сотрудников],
    SUM(CASE WHEN flagpos = 1 THEN 1 ELSE 0 END) AS [Доступ к POS],
    SUM(CASE WHEN flagsales = 1 THEN 1 ELSE 0 END) AS [Продажи],
    SUM(CASE WHEN flagreports = 1 THEN 1 ELSE 0 END) AS [Отчёты]
FROM dbo.personnel
GROUP BY securityaccess
ORDER BY COUNT(*) DESC;
GO

SELECT
    p.personid AS [Код],
    LTRIM(RTRIM(ISNULL(p.lastname, '') + ' ' + ISNULL(p.firstname, ''))) AS [Сотрудник],
    (SELECT COUNT(*) FROM dbo.bm_JournalSessions s WHERE s.PersonID = p.personid) AS [Сессий],
    ISNULL((SELECT SUM(CASE WHEN s.IsError = 1 THEN 1 ELSE 0 END)
       FROM dbo.bm_JournalSessions s WHERE s.PersonID = p.personid), 0) AS [Ошибок],
    (SELECT COUNT(*) FROM dbo.bm_BonusHistory b WHERE b.PersonID = p.personid) AS [Бонусных записей]
FROM dbo.personnel p
WHERE EXISTS (SELECT 1 FROM dbo.bm_JournalSessions s WHERE s.PersonID = p.personid)
   OR EXISTS (SELECT 1 FROM dbo.bm_BonusHistory b WHERE b.PersonID = p.personid)
ORDER BY [Сессий] DESC;
GO

SELECT TOP (15)
    CASE WHEN ISNULL(s.Type, '') = '' THEN '(не указан)' ELSE s.Type END AS [Тип события],
    COUNT(*) AS [Событий],
    SUM(CASE WHEN s.IsError = 1 THEN 1 ELSE 0 END) AS [Ошибок],
    COUNT(DISTINCT s.PersonID) AS [Сотрудников]
FROM dbo.bm_JournalSessions s
GROUP BY s.Type
ORDER BY COUNT(*) DESC;
GO

SELECT TOP (10)
    b.PersonID AS [Код],
    LTRIM(RTRIM(ISNULL(p.lastname, '') + ' ' + ISNULL(p.firstname, ''))) AS [Сотрудник],
    COUNT(*) AS [Записей],
    CONVERT(varchar(19), MIN(b.Period), 120) AS [Первый],
    CONVERT(varchar(19), MAX(b.Period), 120) AS [Последний]
FROM dbo.bm_BonusHistory b
LEFT JOIN dbo.personnel p ON p.personid = b.PersonID
GROUP BY b.PersonID, p.lastname, p.firstname
ORDER BY COUNT(*) DESC;
GO

SELECT 'personnel' AS [Таблица], COUNT(*) AS [Строк] FROM dbo.personnel
UNION ALL SELECT 'bm_JournalSessions', COUNT(*) FROM dbo.bm_JournalSessions
UNION ALL SELECT 'bm_BonusHistory', COUNT(*) FROM dbo.bm_BonusHistory
UNION ALL SELECT 'bm_ShiftsOperations', COUNT(*) FROM dbo.bm_ShiftsOperations
UNION ALL SELECT 'bm_ShiftsOperations_Values', COUNT(*) FROM dbo.bm_ShiftsOperations_Values
UNION ALL SELECT 'bm_WorkHours', COUNT(*) FROM dbo.bm_WorkHours
UNION ALL SELECT 'personnelmessages', COUNT(*) FROM dbo.personnelmessages
UNION ALL SELECT 'bm_CashOperations', COUNT(*) FROM dbo.bm_CashOperations
UNION ALL SELECT 'bm_CashOperationsType', COUNT(*) FROM dbo.bm_CashOperationsType;
GO
