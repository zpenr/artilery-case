DO $$
BEGIN
	DROP TABLE IF EXISTS Calc_cells CASCADE;
	DROP TABLE IF EXISTS Calc_columns CASCADE;
	DROP TABLE IF EXISTS Calc_rows CASCADE;
	DROP TABLE IF EXISTS Calc_tables CASCADE;
	
	DROP SEQUENCE IF EXISTS cells_id CASCADE;
	DROP SEQUENCE IF EXISTS rows_id CASCADE;
	DROP SEQUENCE IF EXISTS cols_id CASCADE;
	DROP SEQUENCE IF EXISTS tables_id CASCADE;
	
	CREATE TABLE Calc_tables ( id integer PRIMARY KEY, name varchar(150) NOT NULL, equipment_id integer REFERENCES Equipments(id),
	    value_param_id integer REFERENCES Types_parameters(id), value_unit_id integer REFERENCES Units_measurement(id));
	
	CREATE TABLE Calc_columns ( id integer PRIMARY KEY,table_id integer NOT NULL REFERENCES Calc_tables(id),
		param_id integer REFERENCES Types_parameters(id),
		unit_id integer REFERENCES Units_measurement(id), min_val numeric(7,2), max_val numeric(7,2));
	
	CREATE TABLE Calc_rows (id integer PRIMARY KEY, table_id integer NOT NULL REFERENCES Calc_tables(id),
	    param_id integer REFERENCES Types_parameters(id), unit_id integer REFERENCES Units_measurement(id),
	    row_value numeric(7,2));
	
	CREATE TABLE Calc_cells ( id integer PRIMARY KEY, col_id integer NOT NULL REFERENCES Calc_columns(id),
	    row_id integer NOT NULL REFERENCES Calc_rows(id), val text NOT NULL);
	
	INSERT INTO Types_parameters (id, name, min_val, max_val)
	VALUES
	    (8, 'Скорость среднего ветра', 0, 50),
	    (9, 'Приращение направления', 0, 59)
	ON CONFLICT (id) DO NOTHING;
	
	INSERT INTO Units_measurement (id, name)
	VALUES (6, 'Большие деления угломера')
	ON CONFLICT (id) DO NOTHING;

	
	INSERT INTO Calc_tables (id, name, equipment_id, value_param_id, value_unit_id)
	VALUES
	    (1, 'Таблица 2. Среднее отклонение температуры', NULL, 2, 3),
	    (2, 'Таблица 3. ДМК. Скорость среднего ветра', 1, 8, 5),
	    (3, 'Таблица 3. ДМК. α', 1, 9, 6);
	
	INSERT INTO Calc_columns (id, table_id, param_id, unit_id, min_val, max_val)
	VALUES
	    (1,  1, 2, 3,  1,  1),
	    (2,  1, 2, 3,  2,  2),
	    (3,  1, 2, 3,  3,  3),
	    (4,  1, 2, 3,  4,  4),
	    (5,  1, 2, 3,  5,  5),
	    (6,  1, 2, 3,  6,  6),
	    (7,  1, 2, 3,  7,  7),
	    (8,  1, 2, 3,  8,  8),
	    (9,  1, 2, 3,  9,  9),
	    (10, 1, 2, 3, 10, 10),
	    (11, 1, 2, 3, 20, 20),
	    (12, 1, 2, 3, 30, 30),
	    (13, 1, 2, 3, 40, 40),
	    (14, 1, 2, 3, 50, 50);
	
	INSERT INTO Calc_columns (id, table_id, param_id, unit_id, min_val, max_val)
	VALUES
	    (15, 2, 5, 5,  3,  3),
	    (16, 2, 5, 5,  4,  4),
	    (17, 2, 5, 5,  5,  5),
	    (18, 2, 5, 5,  6,  6),
	    (19, 2, 5, 5,  7,  7),
	    (20, 2, 5, 5,  8,  8),
	    (21, 2, 5, 5,  9,  9),
	    (22, 2, 5, 5, 10, 10),
	    (23, 2, 5, 5, 11, 11),
	    (24, 2, 5, 5, 12, 12),
	    (25, 2, 5, 5, 13, 13),
	    (26, 2, 5, 5, 14, 14),
	    (27, 2, 5, 5, 15, 15);
	
	INSERT INTO Calc_columns (id, table_id, param_id, unit_id, min_val, max_val)
	VALUES (28, 3, 9, 6, NULL, NULL);
	
	INSERT INTO Calc_rows (id, table_id, param_id, unit_id, row_value)
	VALUES
	    (1, 1, 1, 1, 200),
	    (2, 2, 1, 1, 200),
	    (3, 3, 1, 1, 200);
	
	INSERT INTO Calc_cells (id, col_id, row_id, val)
	VALUES
	    (1,  1,  1, '-1/1'),
	    (2,  2,  1, '-2/2'),
	    (3,  3,  1, '-3/3'),
	    (4,  4,  1, '-4/4'),
	    (5,  5,  1, '-5/5'),
	    (6,  6,  1, '-6/6'),
	    (7,  7,  1, '-7/7'),
	    (8,  8,  1, '-8/8'),
	    (9,  9,  1, '-8/9'),
	    (10, 10, 1, '-9/10'),
	    (11, 11, 1, '-20/20'),
	    (12, 12, 1, '-29/30'),
	    (13, 13, 1, '-39/-'),
	    (14, 14, 1, '-49/-');

	INSERT INTO Calc_cells (id, col_id, row_id, val)
	VALUES
	    (15, 15, 2, '4'),
	    (16, 16, 2, '6'),
	    (17, 17, 2, '8'),
	    (18, 18, 2, '9'),
	    (19, 19, 2, '10'),
	    (20, 20, 2, '12'),
	    (21, 21, 2, '14'),
	    (22, 22, 2, '15'),
	    (23, 23, 2, '16'),
	    (24, 24, 2, '18'),
	    (25, 25, 2, '20'),
	    (26, 26, 2, '21'),
	    (27, 27, 2, '22');
	
	INSERT INTO Calc_cells (id, col_id, row_id, val)
	VALUES (28, 28, 3, '1.00');

END $$;

SELECT
    c.min_val AS delta_t,
    cell.val AS value_negative_positive
FROM Calc_tables AS t
JOIN Calc_columns AS c ON c.table_id = t.id
JOIN Calc_rows AS r ON r.table_id = t.id
JOIN Calc_cells AS cell ON cell.col_id = c.id AND cell.row_id = r.id
WHERE t.id = 1
  AND r.row_value = 200
ORDER BY c.min_val;

SELECT
    c.min_val AS v0,
    cell.val AS avg_wind_speed,
    dir.val AS delta_alpha
FROM Calc_tables AS t
JOIN Calc_columns AS c ON c.table_id = t.id
JOIN Calc_rows AS r ON r.table_id = t.id
JOIN Calc_cells AS cell ON cell.col_id = c.id AND cell.row_id = r.id
LEFT JOIN Calc_cells AS dir ON dir.row_id = 3
WHERE t.id = 2
  AND r.row_value = 200
ORDER BY c.min_val;