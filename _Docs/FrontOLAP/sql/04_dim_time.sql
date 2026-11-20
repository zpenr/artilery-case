-- =============================================================================
-- 04_dim_time.sql
-- Отдельный скрипт формирования ресурса (метрики) "Время".
--
-- Таблица public.dim_time содержит обязательные поля:
--   Код                     -> external_id (YYYYMM) + суррогатный id;
--   Дата начала месяца      -> month_start_date;
--   Дата окончания месяца   -> month_end_date;
--   Название месяца         -> month_name;
--   Год                     -> year;
--   Номер квартала          -> quarter_number;
--   Название квартала       -> quarter_name.
--
-- Скрипт можно запускать независимо от остальных: он сам создаёт
-- последовательность, таблицу и функцию заполнения.
--
-- По умолчанию заполняется диапазон 2010-01-01 .. 2030-12-01.
-- =============================================================================

CREATE SEQUENCE IF NOT EXISTS public.seq_dim_time;

CREATE TABLE IF NOT EXISTS public.dim_time (
    id               bigint PRIMARY KEY DEFAULT nextval('public.seq_dim_time'),
    external_id      bigint NOT NULL UNIQUE,
    month_start_date date NOT NULL,
    month_end_date   date NOT NULL,
    month_name       text NOT NULL,
    year             integer NOT NULL,
    quarter_number   integer NOT NULL,
    quarter_name     text NOT NULL,
    date_add         timestamp DEFAULT now(),
    CONSTRAINT chk_dim_time_period CHECK (month_start_date <= month_end_date),
    CONSTRAINT chk_dim_time_quarter CHECK (quarter_number BETWEEN 1 AND 4),
    CONSTRAINT uq_dim_time_month UNIQUE (year, month_start_date)
);

COMMENT ON TABLE  public.dim_time IS 'Измерение Время (месяц). external_id = YYYYMM';
COMMENT ON COLUMN public.dim_time.id               IS 'Внутренний суррогатный код';
COMMENT ON COLUMN public.dim_time.external_id      IS 'Код месяца в формате YYYYMM';
COMMENT ON COLUMN public.dim_time.month_start_date IS 'Дата начала месяца';
COMMENT ON COLUMN public.dim_time.month_end_date   IS 'Дата окончания месяца';
COMMENT ON COLUMN public.dim_time.month_name       IS 'Название месяца (Январь ... Декабрь)';
COMMENT ON COLUMN public.dim_time.year             IS 'Год';
COMMENT ON COLUMN public.dim_time.quarter_number   IS 'Номер квартала (1..4)';
COMMENT ON COLUMN public.dim_time.quarter_name     IS 'Название квартала (I квартал ... IV квартал)';
COMMENT ON COLUMN public.dim_time.date_add         IS 'Дата добавления записи';

CREATE OR REPLACE FUNCTION public.fill_time_dimension(
    p_from date DEFAULT DATE '2010-01-01',
    p_to   date DEFAULT DATE '2030-12-01'
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_month        date;
    v_count        integer := 0;
    v_external_id  integer;
    v_month_name   text;
    v_quarter_no   integer;
    v_quarter_name text;
BEGIN
    IF p_from IS NULL OR p_to IS NULL THEN
        RAISE EXCEPTION 'Границы формирования времени не заданы';
    END IF;

    IF p_from > p_to THEN
        RAISE EXCEPTION 'Дата начала (%) больше даты окончания (%)', p_from, p_to;
    END IF;

    v_month := date_trunc('month', p_from)::date;

    WHILE v_month <= date_trunc('month', p_to)::date LOOP
        v_external_id := EXTRACT(YEAR FROM v_month)::integer * 100
                       + EXTRACT(MONTH FROM v_month)::integer;

        v_month_name := CASE EXTRACT(MONTH FROM v_month)::integer
            WHEN 1  THEN 'Январь'
            WHEN 2  THEN 'Февраль'
            WHEN 3  THEN 'Март'
            WHEN 4  THEN 'Апрель'
            WHEN 5  THEN 'Май'
            WHEN 6  THEN 'Июнь'
            WHEN 7  THEN 'Июль'
            WHEN 8  THEN 'Август'
            WHEN 9  THEN 'Сентябрь'
            WHEN 10 THEN 'Октябрь'
            WHEN 11 THEN 'Ноябрь'
            WHEN 12 THEN 'Декабрь'
        END;

        v_quarter_no := EXTRACT(QUARTER FROM v_month)::integer;

        v_quarter_name := CASE v_quarter_no
            WHEN 1 THEN 'I квартал'
            WHEN 2 THEN 'II квартал'
            WHEN 3 THEN 'III квартал'
            WHEN 4 THEN 'IV квартал'
        END;

        INSERT INTO public.dim_time (
            external_id,
            month_start_date,
            month_end_date,
            month_name,
            year,
            quarter_number,
            quarter_name
        )
        VALUES (
            v_external_id,
            v_month,
            (v_month + INTERVAL '1 month - 1 day')::date,
            v_month_name,
            EXTRACT(YEAR FROM v_month)::integer,
            v_quarter_no,
            v_quarter_name
        )
        ON CONFLICT (external_id) DO UPDATE
        SET month_start_date = EXCLUDED.month_start_date,
            month_end_date   = EXCLUDED.month_end_date,
            month_name       = EXCLUDED.month_name,
            year             = EXCLUDED.year,
            quarter_number   = EXCLUDED.quarter_number,
            quarter_name     = EXCLUDED.quarter_name;

        v_count := v_count + 1;
        v_month := (v_month + INTERVAL '1 month')::date;
    END LOOP;

    RETURN v_count;
END;
$$;

COMMENT ON FUNCTION public.fill_time_dimension(date, date)
    IS 'Формирует/обновляет измерение Время за указанный диапазон месяцев';

-- -----------------------------------------------------------------------------
-- Заполнение. При необходимости измените диапазон.
-- -----------------------------------------------------------------------------
SELECT public.fill_time_dimension(DATE '2010-01-01', DATE '2030-12-01') AS months_filled;

-- Контроль: 21 год * 12 = 252 месяца.
SELECT count(*) AS total_months,
       min(external_id) AS first_code,
       max(external_id) AS last_code
FROM public.dim_time;

SELECT external_id AS code,
       month_start_date,
       month_end_date,
       month_name,
       year,
       quarter_number,
       quarter_name
FROM public.dim_time
ORDER BY external_id
LIMIT 12;
