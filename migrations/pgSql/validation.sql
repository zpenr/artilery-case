-- Валидация входных параметров и функции готовых отчётов.
DO $$
BEGIN

DROP FUNCTION IF EXISTS get_parameter_errors();
DROP FUNCTION IF EXISTS get_best_shooters();
DROP FUNCTION IF EXISTS validate_parameters(p_list parameter_list);
DROP TYPE IF EXISTS parameter_list CASCADE;
DROP TYPE IF EXISTS parameter_value CASCADE;
DROP TABLE IF EXISTS Errors CASCADE;

-- Справочник сообщений об ошибках входных параметров
CREATE TABLE Errors (
    code text PRIMARY KEY,
    message text NOT NULL
);

-- Сообщения, которые использует функция validate_parameters
INSERT INTO Errors (code, message) VALUES
    ('MISSING_PARAM', 'Отсутствует обязательный параметр'),
    ('FORBIDDEN_PARAM', 'Параметр недопустим для оборудования'),
    ('OUT_OF_RANGE', 'Значение вне диапазона');

-- Один параметр: код типа и числовое значение
CREATE TYPE parameter_value AS (
    param_id int,
    param_value numeric
);

-- Список параметров одной пачки с привязкой к типу оборудования
CREATE TYPE parameter_list AS (
    equipment_id int,
    params parameter_value[]
);

-- Проверяет обязательные, недопустимые параметры и диапазоны значений
-- возвращает строку с ошибками или NULL, если ошибок нет
CREATE OR REPLACE FUNCTION validate_parameters(p_list parameter_list)
RETURNS text
LANGUAGE plpgsql
STABLE
AS $func$
DECLARE
    -- Накопленный текст сообщений об ошибках
    v_errors text := '';
    -- Текущий проверяемый параметр из входного списка
    v_item parameter_value;
    -- Строка справочника Types_parameters для текущего параметра
    v_type Types_parameters%ROWTYPE;
    -- Обязательные параметры для выбранного типа оборудования
    v_required int[];
    -- Уже обработанные param_id
    v_seen int[] := ARRAY[]::int[];
    -- Очередной обязательный param_id при проверке отсутствующих
    v_id int;
BEGIN
    -- Набор обязательных параметров: ДМК и ВР
    v_required := CASE p_list.equipment_id
        WHEN 1 THEN ARRAY[1, 2, 3, 4, 5]
        WHEN 2 THEN ARRAY[1, 2, 3, 4, 6]
        ELSE NULL
    END;

    -- Проверяем каждый переданный параметр
    FOREACH v_item IN ARRAY p_list.params
    LOOP
        v_seen := v_seen || v_item.param_id;

        SELECT *
        INTO v_type
        FROM Types_parameters
        WHERE id = v_item.param_id;

        IF v_required IS NOT NULL AND NOT (v_item.param_id = ANY(v_required)) THEN
            v_errors := v_errors || format(
                '%s: %s;',
                (SELECT message FROM Errors WHERE code = 'FORBIDDEN_PARAM'),
                v_type.name
            );
        END IF;

        IF v_item.param_value IS NULL
           OR v_item.param_value < v_type.min_val
           OR v_item.param_value > v_type.max_val THEN
            v_errors := v_errors || format(
                '%s: %s = %s, допустимо %s..%s;',
                (SELECT message FROM Errors WHERE code = 'OUT_OF_RANGE'),
                v_type.name,
                COALESCE(v_item.param_value::text, 'NULL'),
                v_type.min_val,
                v_type.max_val
            );
        END IF;
    END LOOP;

    -- Проверяем, что все обязательные параметры переданы
    IF v_required IS NOT NULL THEN
        FOREACH v_id IN ARRAY v_required
        LOOP
            IF NOT (v_id = ANY(v_seen)) THEN
                v_errors := v_errors || format(
                    '%s: %s;',
                    (SELECT message FROM Errors WHERE code = 'MISSING_PARAM'),
                    (SELECT name FROM Types_parameters WHERE id = v_id)
                );
            END IF;
        END LOOP;
    END IF;

    IF length(v_errors) = 0 THEN
        RETURN NULL;
    END IF;

    RETURN v_errors;
END;
$func$;

-- Отчёт «Список параметров с ошибками»
CREATE OR REPLACE FUNCTION get_parameter_errors()
RETURNS TABLE (
    "№" int,
    "Тип оборудования" text,
    "Высота метеопоста" numeric,
    "Температура" numeric,
    "Давление" numeric,
    "Направление ветра" numeric,
    "Скорость ветра" numeric,
    "Дальность сноса пуль" numeric,
    "Флаг: Есть ошибка" boolean,
    "Описание ошибки" text
)
LANGUAGE sql
STABLE
AS $func$
    WITH batches AS (
        SELECT
            l.id,
            e.name AS equipment_name,
            max(p.param_value) FILTER (WHERE p.param_id = 1) AS station_high,
            max(p.param_value) FILTER (WHERE p.param_id = 2) AS temperature,
            max(p.param_value) FILTER (WHERE p.param_id = 3) AS pressure,
            max(p.param_value) FILTER (WHERE p.param_id = 4) AS wind_direction,
            max(p.param_value) FILTER (WHERE p.param_id = 5) AS wind_speed,
            max(p.param_value) FILTER (WHERE p.param_id = 6) AS bullet_drift,
            validate_parameters(
                ROW(
                    l.equipment_id,
                    COALESCE(
                        array_agg(
                            ROW(p.param_id, p.param_value)::parameter_value
                            ORDER BY p.id
                        ),
                        ARRAY[]::parameter_value[]
                    )
                )::parameter_list
            ) AS error_text
        FROM Logs l
        JOIN Equipments e ON e.id = l.equipment_id
        LEFT JOIN Parameters p ON p.log_id = l.id
        GROUP BY l.id, l.equipment_id, e.name
    )
    SELECT
        b.id,
        b.equipment_name,
        b.station_high,
        b.temperature,
        b.pressure,
        b.wind_direction,
        b.wind_speed,
        b.bullet_drift,
        (b.error_text IS NOT NULL),
        b.error_text
    FROM batches b
    ORDER BY b.id;
$func$;

-- Отчёт «Лучший стрелок»
CREATE OR REPLACE FUNCTION get_best_shooters()
RETURNS TABLE (
    "Пользователь" text,
    "Количество ошибок" int,
    "Ошибочных пачек" int,
    "Всего пачек" int,
    "Место" int,
    "Лучший стрелок" bool
)
LANGUAGE sql
STABLE
AS $func$
    WITH batches AS (
        SELECT
            l.id,
            l.user_id,
            validate_parameters(
                ROW(
                    l.equipment_id,
                    COALESCE(
                        array_agg(
                            ROW(p.param_id, p.param_value)::parameter_value
                            ORDER BY p.id
                        ),
                        ARRAY[]::parameter_value[]
                    )
                )::parameter_list
            ) AS error_text
        FROM Logs l
        LEFT JOIN Parameters p ON p.log_id = l.id
        GROUP BY l.id, l.user_id, l.equipment_id
    ),
    stats AS (
        SELECT
            u.id AS user_id,
            u.name AS user_name,
            count(b.id) AS logs_count,
            count(*) FILTER (WHERE b.error_text IS NOT NULL) AS bad_batches,
            COALESCE(sum(regexp_count(b.error_text, ';')), 0)::int AS error_count
        FROM Users u
        LEFT JOIN batches b ON b.user_id = u.id
        GROUP BY u.id, u.name
    ),
    ranked AS (
        SELECT
            s.*,
            CASE
                WHEN s.logs_count > 0 THEN
                    rank() OVER (
                        PARTITION BY (s.logs_count > 0)
                        ORDER BY s.error_count, s.bad_batches
                    )
            END AS place,
            CASE
                WHEN s.logs_count > 0 THEN
                    min(s.error_count) OVER (PARTITION BY (s.logs_count > 0))
            END AS best_error_count
        FROM stats s
    )
    SELECT
        r.user_name,
        r.error_count,
        r.bad_batches,
        r.logs_count,
        r.place,
        (r.logs_count > 0 AND r.error_count = r.best_error_count)
    FROM ranked r
    ORDER BY r.place, r.logs_count DESC;
$func$;

END$$;

SELECT * FROM get_parameter_errors();

SELECT * FROM get_best_shooters();