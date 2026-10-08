SELECT * FROM (
	SELECT table_name AS name,
		CASE table_type
			WHEN 'BASE TABLE' THEN 'Таблица'
			WHEN 'VIEW' THEN 'Представление'
			ELSE table_type
		END AS type
	FROM information_schema.tables
	WHERE table_schema = 'public'

	UNION ALL

	SELECT sequence_name, 'Последовательность'
	FROM information_schema.sequences
	WHERE sequence_schema = 'public'
);
