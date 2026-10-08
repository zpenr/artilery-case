
DO $$
	BEGIN
    
		-- Создаём счётчики
		CREATE SEQUENCE IF NOT EXISTS rank_id;
		CREATE SEQUENCE IF NOT EXISTS users_id;
		CREATE SEQUENCE IF NOT EXISTS logs_id;
		CREATE SEQUENCE IF NOT EXISTS parameters_id;
		CREATE SEQUENCE IF NOT EXISTS types_parameters_id;
		CREATE SEQUENCE IF NOT EXISTS units_measurement_id;
		CREATE SEQUENCE IF NOT EXISTS equipments_id;
		CREATE SEQUENCE IF NOT EXISTS tables_id;
		CREATE SEQUENCE IF NOT EXISTS rows_id;
		CREATE SEQUENCE IF NOT EXISTS cols_id;
		CREATE SEQUENCE IF NOT EXISTS cells_id;

		-- Создание таблиц
		CREATE TABLE IF NOT EXISTS Users(id int DEFAULT nextval('users_id') PRIMARY KEY, name text, rank_id int NOT NULL);

		CREATE TABLE IF NOT EXISTS Ranks(id int DEFAULT nextval('rank_id') PRIMARY KEY, name text UNIQUE);

		CREATE TABLE IF NOT EXISTS Equipments(id int DEFAULT nextval('equipments_id') PRIMARY KEY, name text UNIQUE);

		CREATE TABLE IF NOT EXISTS Types_parameters ( id integer DEFAULT nextval('types_parameters_id') PRIMARY KEY, name text, min_val int, max_val int);

		CREATE TABLE IF NOT EXISTS Units_measurement (id integer DEFAULT nextval('units_measurement_id') PRIMARY KEY, name text);

		CREATE TABLE IF NOT EXISTS Logs(id int DEFAULT nextval('logs_id') PRIMARY KEY,
			user_id int NOT NULL, equipment_id int NOT NULL, date timestamp DEFAULT CURRENT_TIMESTAMP);

		CREATE TABLE IF NOT EXISTS Parameters (id int DEFAULT nextval('parameters_id') PRIMARY KEY,
			log_id int NOT NULL, param_id int NOT NULL, units_id int NOT NULL, param_value Decimal(7,2));

		CREATE TABLE IF NOT EXISTS public.Tables(id int DEFAULT nextval('tables_id') PRIMARY KEY, name text UNIQUE);

		CREATE TABLE IF NOT EXISTS public.Columns(id int DEFAULT nextval('cols_id') PRIMARY KEY,
			table_id int NOT NULL, param_id int,  unit_id int, min_val decimal(7,2), max_val decimal(7,2));

		CREATE TABLE IF NOT EXISTS public.Rows(id int DEFAULT nextval('rows_id') PRIMARY KEY,
			table_id int NOT NULL, param_id int, unit_id int);

		CREATE TABLE IF NOT EXISTS public.Cells(id int DEFAULT nextval('cells_id') PRIMARY KEY,
			col_id int NOT NULL, row_id int NOT NULL, val decimal(7,2));


	COMMIT;

        -- 1. Звания
        INSERT INTO Ranks (name) VALUES
            ('Рядовой'),
            ('Ефрейтор'),
            ('Младший сержант'),
            ('Сержант'),
            ('Старший сержант'),
            ('Старшина'),
            ('Прапорщик'),
            ('Старший прапорщик');
            
        -- 2. Единицы измерения
        INSERT INTO Units_measurement (name) VALUES
            ('Метры'),
            ('мм. рт. ст.'),
            ('Цельсий'),
            ('Градусы'),
            ('м/с');

        -- 3. Типы параметров и их диапазоны
        INSERT INTO Types_parameters (name, min_val, max_val) VALUES
            ('Высота метеопоста',      -500, 1000),
            ('Температура',             -58,   58),
            ('Давление',                500,  900),
            ('Направление ветра',         0,   59),
            ('Скорость ветра',            0,   15),
            ('Дальность сноса пуль',      0,  150),
            ('Виртуальная поправка', 	-58,   58);

        -- 4. Оборудование
        INSERT INTO Equipments (name) VALUES
            ('ДМК'),
            ('ВР');
        -- 5. Пользователи (12)
        INSERT INTO Users (name, rank_id) VALUES
            ('Волков Дмитрий Андреевич',   1),
            ('Кузнецова Елена Игоревна',   3),
            ('Смирнов Максим Витальевич',  2),
            ('Морозова Анна Дмитриевна',   6),
            ('Петров Роман Сергеевич',     5),
            ('Иванова Ольга Петровна',     4),
            ('Соколов Игорь Валерьевич',   7),
            ('Новикова Мария Андреевна',   1),
            ('Кузьмин Павел Олегович',     4),
            ('Белова Екатерина Юрьевна',   3),
            ('Тарасов Николай Ильич',      6),
            ('Гущина Светлана Борисовна',  2);

        -- 6. Пачки измерений (24): у каждого пользователя ДМК и ВР
        INSERT INTO Logs (user_id, equipment_id, date) VALUES
            (1,  1, TIMESTAMP '2026-10-01 08:00:00'),
            (1,  2, TIMESTAMP '2026-10-01 14:00:00'),
            (2,  1, TIMESTAMP '2026-10-02 08:00:00'),
            (2,  2, TIMESTAMP '2026-10-02 14:00:00'),
            (3,  1, TIMESTAMP '2026-10-03 08:00:00'),
            (3,  2, TIMESTAMP '2026-10-03 14:00:00'),
            (4,  1, TIMESTAMP '2026-10-04 08:00:00'),
            (4,  2, TIMESTAMP '2026-10-04 14:00:00'),
            (5,  1, TIMESTAMP '2026-10-05 08:00:00'),
            (5,  2, TIMESTAMP '2026-10-05 14:00:00'),
            (6,  1, TIMESTAMP '2026-10-06 08:00:00'),
            (6,  2, TIMESTAMP '2026-10-06 14:00:00'),
            (7,  1, TIMESTAMP '2026-10-07 08:00:00'),
            (7,  2, TIMESTAMP '2026-10-07 14:00:00'),
            (8,  1, TIMESTAMP '2026-10-08 08:00:00'),
            (8,  2, TIMESTAMP '2026-10-08 14:00:00'),
            (9,  1, TIMESTAMP '2026-10-09 08:00:00'),
            (9,  2, TIMESTAMP '2026-10-09 14:00:00'),
            (10, 1, TIMESTAMP '2026-10-10 08:00:00'),
            (10, 2, TIMESTAMP '2026-10-10 14:00:00'),
            (11, 1, TIMESTAMP '2026-10-11 08:00:00'),
            (11, 2, TIMESTAMP '2026-10-11 14:00:00'),
            (12, 1, TIMESTAMP '2026-10-12 08:00:00'),
            (12, 2, TIMESTAMP '2026-10-12 14:00:00');

        -- 7. Измерения (120 = 24 пачки × 5)
        INSERT INTO Parameters (log_id, param_id, units_id, param_value) VALUES
            -- пачка 1, Волков, ДМК
            (1, 1, 1, 120),     (1, 2, 3, 11.5),  (1, 3, 2, 705),
            (1, 4, 4, 5),       (1, 5, 5, 3),
            -- пачка 2, Волков, ВР
            (2, 1, 1, 175),     (2, 2, 3, -2.5),  (2, 3, 2, 670),
            (2, 4, 4, 7),       (2, 6, 1, 13),
            -- пачка 3, Кузнецова, ДМК
            (3, 1, 1, 140),     (3, 2, 3, 13.0),  (3, 3, 2, 710),
            (3, 4, 4, 10),      (3, 5, 5, 6),
            -- пачка 4, Кузнецова, ВР
            (4, 1, 1, 200),     (4, 2, 3, 0.0),   (4, 3, 2, 680),
            (4, 4, 4, 14),      (4, 6, 1, 26),
            -- пачка 5, Смирнов, ДМК
            (5, 1, 1, 160),     (5, 2, 3, 14.5),  (5, 3, 2, 715),
            (5, 4, 4, 15),      (5, 5, 5, 9),
            -- пачка 6, Смирнов, ВР
            (6, 1, 1, 225),     (6, 2, 3, 2.5),   (6, 3, 2, 690),
            (6, 4, 4, 21),      (6, 6, 1, 39),
            -- пачка 7, Морозова, ДМК
            (7, 1, 1, 180),     (7, 2, 3, 16.0),  (7, 3, 2, 720),
            (7, 4, 4, 20),      (7, 5, 5, 12),
            -- пачка 8, Морозова, ВР
            (8, 1, 1, 250),     (8, 2, 3, 5.0),   (8, 3, 2, 700),
            (8, 4, 4, 28),      (8, 6, 1, 52),
            -- пачка 9, Петров, ДМК
            (9, 1, 1, 200),     (9, 2, 3, 17.5),  (9, 3, 2, 725),
            (9, 4, 4, 25),      (9, 5, 5, 15),
            -- пачка 10, Петров, ВР
            (10, 1, 1, 275),    (10, 2, 3, 7.5),  (10, 3, 2, 710),
            (10, 4, 4, 35),     (10, 6, 1, 65),
            -- пачка 11, Иванова, ДМК
            (11, 1, 1, 220),    (11, 2, 3, 19.0), (11, 3, 2, 730),
            (11, 4, 4, 30),     (11, 5, 5, 2),
            -- пачка 12, Иванова, ВР
            (12, 1, 1, 300),    (12, 2, 3, 10.0), (12, 3, 2, 720),
            (12, 4, 4, 42),     (12, 6, 1, 78),
            -- пачка 13, Соколов, ДМК
            (13, 1, 1, 240),    (13, 2, 3, 20.5), (13, 3, 2, 735),
            (13, 4, 4, 35),     (13, 5, 5, 5),
            -- пачка 14, Соколов, ВР
            (14, 1, 1, 325),    (14, 2, 3, 12.5), (14, 3, 2, 730),
            (14, 4, 4, 49),     (14, 6, 1, 91),
            -- пачка 15, Новикова, ДМК
            (15, 1, 1, 260),    (15, 2, 3, 22.0), (15, 3, 2, 740),
            (15, 4, 4, 40),     (15, 5, 5, 8),
            -- пачка 16, Новикова, ВР
            (16, 1, 1, 350),    (16, 2, 3, 15.0), (16, 3, 2, 740),
            (16, 4, 4, 56),     (16, 6, 1, 104),
            -- пачка 17, Кузьмин, ДМК
            (17, 1, 1, 280),    (17, 2, 3, 23.5), (17, 3, 2, 745),
            (17, 4, 4, 45),     (17, 5, 5, 11),
            -- пачка 18, Кузьмин, ВР
            (18, 1, 1, 375),    (18, 2, 3, 17.5), (18, 3, 2, 750),
            (18, 4, 4, 3),      (18, 6, 1, 117),
            -- пачка 19, Белова, ДМК
            (19, 1, 1, 300),    (19, 2, 3, 25.0), (19, 3, 2, 750),
            (19, 4, 4, 50),     (19, 5, 5, 14),
            -- пачка 20, Белова, ВР
            (20, 1, 1, 400),    (20, 2, 3, 20.0), (20, 3, 2, 760),
            (20, 4, 4, 10),     (20, 6, 1, 130),
            -- пачка 21, Тарасов, ДМК
            (21, 1, 1, 320),    (21, 2, 3, 26.5), (21, 3, 2, 755),
            (21, 4, 4, 55),     (21, 5, 5, 1),
            -- пачка 22, Тарасов, ВР
            (22, 1, 1, 425),    (22, 2, 3, 22.5), (22, 3, 2, 770),
            (22, 4, 4, 17),     (22, 6, 1, 143),
            -- пачка 23, Гущина, ДМК
            (23, 1, 1, 340),    (23, 2, 3, 28.0), (23, 3, 2, 760),
            (23, 4, 4, 0),      (23, 5, 5, 4),
            -- пачка 24, Гущина, ВР
            (24, 1, 1, 450),    (24, 2, 3, 25.0), (24, 3, 2, 780),
            (24, 4, 4, 24),     (24, 6, 1, 5);
            
        INSERT INTO public.Tables(name) VALUES ('Расчет температуры');
        INSERT INTO public.Columns(table_id, param_id, unit_id, min_val, max_val) VALUES
            (1, 2,3, -100, 0), (1, 2 ,3, 0, 5), (1, 2 ,3, 10, 15), (1, 2 ,3, NULL, 20),
            (1, 2 ,3, NULL, 25), (1, 2 ,3, NULL, 30), (1, 2 ,3, NULL, 40);
        INSERT INTO public.Rows(table_id, param_id, unit_id) VALUES (1, 7, 2);

        INSERT INTO public.Cells(col_id, row_id, val) VALUES (1,1,0),
            (2,1,0.5), (3,1,1),(4,1,1.5),
            (5,1,2),(6,1,3.5),(7,1,4.5);
		
	COMMIT;

        ALTER TABLE Users
        ADD CONSTRAINT fk_users_ranks
        FOREIGN KEY (rank_id) REFERENCES Ranks(id);


        ALTER TABLE Logs
        ADD CONSTRAINT fk_logs_users
        FOREIGN KEY (user_id) REFERENCES Users(id);
    
        ALTER TABLE Logs
        ADD CONSTRAINT fk_logs_equipments
        FOREIGN KEY (equipment_id) REFERENCES Equipments(id);
    
        ALTER TABLE Parameters
        ADD CONSTRAINT fk_parameters_logs
        FOREIGN KEY (log_id) REFERENCES Logs(id);
    
        ALTER TABLE Parameters
        ADD CONSTRAINT fk_parameters_tparams
        FOREIGN KEY (param_id) REFERENCES Types_parameters(id);
    
        ALTER TABLE Parameters
        ADD CONSTRAINT fk_parameters_units
        FOREIGN KEY (units_id) REFERENCES Units_measurement(id);
    
        ALTER TABLE public.Columns
        ADD CONSTRAINT fk_columns_tables
        FOREIGN KEY (table_id) REFERENCES public.Tables(id);
    
        ALTER TABLE public.Columns
        ADD CONSTRAINT fk_columns_tparams
        FOREIGN KEY (param_id) REFERENCES public.Types_parameters(id);
    
        ALTER TABLE public.Columns
        ADD CONSTRAINT fk_columns_units
        FOREIGN KEY (unit_id) REFERENCES public.Units_measurement(id);
    
        ALTER TABLE public.Rows
        ADD CONSTRAINT fk_rows_tables
        FOREIGN KEY (table_id) REFERENCES public.Tables(id);
    
        ALTER TABLE public.Rows
        ADD CONSTRAINT fk_rows_tparams
        FOREIGN KEY (param_id) REFERENCES public.Types_parameters(id);
    
        ALTER TABLE public.Rows
        ADD CONSTRAINT fk_rows_units
        FOREIGN KEY (unit_id) REFERENCES public.Units_measurement(id);
    
        ALTER TABLE public.Cells
        ADD CONSTRAINT fk_cells_columns
        FOREIGN KEY (col_id) REFERENCES public.Columns(id);
    
        ALTER TABLE public.Cells
        ADD CONSTRAINT fk_cells_rows
        FOREIGN KEY (row_id) REFERENCES public.Rows(id);
    
        ALTER TABLE Types_parameters
        ADD CONSTRAINT chk_types_parameters_range
        CHECK (min_val <= max_val);
    
        ALTER TABLE public.Columns
        ADD CONSTRAINT chk_columns_range
        CHECK (min_val IS NULL OR max_val IS NULL OR min_val <= max_val);
		
		ALTER TABLE Logs ALTER COLUMN date SET NOT NULL;
		ALTER TABLE Parameters ALTER COLUMN param_value SET NOT NULL;
		ALTER TABLE public.Cells ALTER COLUMN val SET NOT NULL;

	COMMIT;

END $$;
