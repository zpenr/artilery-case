-- функции для расчета Метео приближенный
DO $$
    BEGIN

    DROP FUNCTION IF EXISTS get_constant_num(varchar);
    DROP FUNCTION IF EXISTS get_constant_text(varchar);
    DROP TABLE IF EXISTS Constants CASCADE;

    -- Таблица именованных числовых констант
    CREATE TABLE Constants (
        code text PRIMARY KEY,
        value numeric NOT NULL
    );

    INSERT INTO Constants (code, value) VALUES
        ('PRESSURE', 750),
        ('TEMPERATURE', 15.9),
        ('PRESSURE_NEG', 500),
        ('TEMPERATURE_NEG', 50),
        ('HEIGHT_NEG', 5000);

    -- Возвращает числовое значение константы по её коду
    CREATE OR REPLACE FUNCTION get_constant(p_code text)
    RETURNS numeric
    LANGUAGE sql
    AS $func$
        SELECT value
        FROM Constants
        WHERE code = p_code;
    $func$;

    COMMIT;

    DROP FUNCTION IF EXISTS calc_meteo_header(int, timestamp);
    DROP FUNCTION IF EXISTS calc_virtual_temperature(numeric);
    DROP FUNCTION IF EXISTS calc_tt(numeric);
    DROP FUNCTION IF EXISTS calc_ddchhm(timestamp);
    DROP FUNCTION IF EXISTS calc_vvvv(int);
    DROP FUNCTION IF EXISTS calc_bbbtt(numeric, numeric);

    -- ДДЧЧМ: день, часы и десятки минут
    CREATE OR REPLACE FUNCTION calc_ddchhm(p_time timestamp DEFAULT current_timestamp)
    RETURNS text
    LANGUAGE sql
    AS $func$
        SELECT to_char(p_time, 'DDHH24')
            || floor(extract(minute FROM p_time) / 10)::int::text;
    $func$;

    -- ВВВВ: высота метеопоста в четырёх разрядах
    CREATE OR REPLACE FUNCTION calc_vvvv(p_height int)
    RETURNS text
    LANGUAGE sql
    AS $func$
        SELECT lpad(
            (CASE
                WHEN p_height < 0 THEN get_constant('HEIGHT_NEG') + abs(p_height)
                ELSE p_height
            END)::int::text,
            4,
            '0'
        );
    $func$;

    -- БББТТ: отклонение давления и виртуальной температуры
    CREATE OR REPLACE FUNCTION calc_bbbtt(p_pressure numeric, p_temperature numeric)
    RETURNS text
    LANGUAGE sql
    AS $func$
        WITH c AS (
            SELECT
                get_constant('PRESSURE') AS p0,
                get_constant('TEMPERATURE') AS t0,
                get_constant('PRESSURE_NEG') AS pn,
                get_constant('TEMPERATURE_NEG') AS tn
        ),
        v AS (
            SELECT
                p_pressure - c.p0 AS dp,
                round(
                    p_temperature
                    + COALESCE(interpolation(
                        p_temperature,
                        find_value(1, p_temperature)
                    ), 0)
                    - c.t0
                ) AS dt,
                c.pn,
                c.tn
            FROM c
        )
        SELECT lpad(
                (CASE WHEN dp < 0 THEN pn + abs(dp) ELSE dp END)::int::text,
                3,
                '0'
            )
            || lpad(
                (CASE WHEN dt < 0 THEN tn + abs(dt) ELSE dt END)::int::text,
                2,
                '0'
            )
        FROM v;
    $func$;

END $$;

-- Проверка функций расчёта приближённого метеобюллетеня.

-- 1. Проверка ДДЧЧМ на фиксированной дате и времени
SELECT
    calc_ddchhm(TIMESTAMP '2026-10-24 09:34') AS "Получено",
    '24093' AS "Ожидается",
    calc_ddchhm(TIMESTAMP '2026-10-24 09:34') = '24093' AS "Проверка пройдена";

-- 2. Проверка ВВВВ для положительной и отрицательной высоты
SELECT
    calc_vvvv(60) AS "Получено +60",
    '0060' AS "Ожидается +60",
    calc_vvvv(60) = '0060' AS "Проверка +60",
    calc_vvvv(-60) AS "Получено -60",
    '5060' AS "Ожидается -60",
    calc_vvvv(-60) = '5060' AS "Проверка -60";

-- 3. Проверка БББТТ для положительного и отрицательного отклонения давления
SELECT
    calc_bbbtt(765, 25) AS "Получено 765/25",
    '01511' AS "Ожидается 765/25",
    calc_bbbtt(765, 25) = '01511' AS "Проверка 765/25",
    calc_bbbtt(743, 15) AS "Получено 743/15",
    '50700' AS "Ожидается 743/15",
    calc_bbbtt(743, 15) = '50700' AS "Проверка 743/15";
