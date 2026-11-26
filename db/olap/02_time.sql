-- OLAP: ресурс время

DO $$
BEGIN
    CREATE SCHEMA IF NOT EXISTS olap;

    CREATE TABLE IF NOT EXISTS olap.dim_time (
        id bigint NOT NULL PRIMARY KEY,
        month_start date NOT NULL,
        month_end date NOT NULL,
        month_name text NOT NULL,
        year smallint NOT NULL,
        quarter_no smallint NOT NULL,
        quarter_name text NOT NULL
    );

    COMMENT ON TABLE olap.dim_time IS 'Время: месяцы и кварталы';
    COMMENT ON COLUMN olap.dim_time.id IS 'Код месяца в формате YYYYMM';
    COMMENT ON COLUMN olap.dim_time.month_start IS 'Дата начала месяца';
    COMMENT ON COLUMN olap.dim_time.month_end IS 'Дата окончания месяца';
    COMMENT ON COLUMN olap.dim_time.month_name IS 'Название месяца';
    COMMENT ON COLUMN olap.dim_time.year IS 'Год';
    COMMENT ON COLUMN olap.dim_time.quarter_no IS 'Номер квартала';
    COMMENT ON COLUMN olap.dim_time.quarter_name IS 'Название квартала';

    TRUNCATE TABLE olap.dim_time;

    INSERT INTO olap.dim_time (
        id,
        month_start,
        month_end,
        month_name,
        year,
        quarter_no,
        quarter_name
    )
    SELECT
        TO_CHAR(d, 'YYYYMM')::bigint,
        d::date,
        (d + INTERVAL '1 month - 1 day')::date,
        (ARRAY[
            'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
            'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
        ])[EXTRACT(MONTH FROM d)::integer],
        EXTRACT(YEAR FROM d)::smallint,
        EXTRACT(QUARTER FROM d)::smallint,
        CONCAT(EXTRACT(QUARTER FROM d)::integer, ' квартал')
    FROM generate_series(
        '2010-01-01'::date,
        '2025-12-01'::date,
        INTERVAL '1 month'
    ) AS d;
END $$;
