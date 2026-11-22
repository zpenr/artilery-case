-- =============================================================================
-- 03_load_olap.sql
-- PL/pgSQL-скрипт вставки данных из staging в OLAP.
--
-- Предусловия:
--   1. Выполнен 01_ddl_olap.sql.
--   2. Выполнен 04_time_metrics.sql.
--   3. Таблицы stg.* заполнены результатами 02_extract_front_mssql.sql.
--
-- Использование:
--   CALL public.load_all(false); -- перезаписать месяцы, которые есть в staging
--   CALL public.load_all(true);  -- полная перезагрузка фактов
-- =============================================================================

-- =============================================================================
-- 1. РЕСУРСЫ-ИЗМЕРЕНИЯ
-- =============================================================================
CREATE OR REPLACE PROCEDURE public.load_dimensions()
LANGUAGE plpgsql
AS $$
BEGIN
    -- Неуказанные значения (id = 0) для ссылочной целостности.
    INSERT INTO public.dim_ranges (id, external_id, name, factor)
    VALUES (0, 0, 'Не указан', 1)
    ON CONFLICT DO NOTHING;

    INSERT INTO public.dim_categories (id, external_id, name, parent_id)
    VALUES (0, 0, 'Не указана', NULL)
    ON CONFLICT DO NOTHING;

    INSERT INTO public.dim_vendors (id, external_id, name, parent_id, parent_name)
    VALUES (0, 0, 'Не указан', NULL, NULL)
    ON CONFLICT DO NOTHING;

    INSERT INTO public.dim_personnel (id, external_id, name, access_level)
    VALUES (0, 0, 'Не указан', NULL)
    ON CONFLICT DO NOTHING;

    INSERT INTO public.dim_payment_types (id, external_id, name)
    VALUES (0, 0, 'Не указан')
    ON CONFLICT DO NOTHING;

    INSERT INTO public.dim_operation_types (id, external_id, name, factor)
    VALUES (0, 0, 'Не указан', 1)
    ON CONFLICT DO NOTHING;

    INSERT INTO public.dim_event_types (id, external_id, name)
    VALUES (0, 0, 'Не указан')
    ON CONFLICT DO NOTHING;

    INSERT INTO public.dim_products (
        id, external_id, name, category_id, range_id
    )
    VALUES (0, 0, 'Не указан', 0, 0)
    ON CONFLICT DO NOTHING;

    INSERT INTO public.dim_storages (id, external_id, name)
    VALUES (0, 0, 'Не указан')
    ON CONFLICT DO NOTHING;

    -- 1. Единицы измерения.
    INSERT INTO public.dim_ranges (external_id, name, factor)
    SELECT
        s.external_id,
        COALESCE(NULLIF(s.name, ''), 'Единица ' || s.external_id),
        COALESCE(s.factor, 1)
    FROM stg.ranges AS s
    ON CONFLICT (external_id) DO UPDATE
    SET name   = EXCLUDED.name,
        factor = EXCLUDED.factor;

    -- 1.1. Единицы, которые встречаются в фактах, но отсутствуют в [size].
    INSERT INTO public.dim_ranges (external_id, name, factor)
    SELECT DISTINCT s.range_external_id,
           'Единица ' || s.range_external_id,
           1
    FROM (
        SELECT range_external_id FROM stg.products
        UNION
        SELECT range_external_id FROM stg.purchases
        UNION
        SELECT range_external_id FROM stg.stock
    ) AS s
    LEFT JOIN public.dim_ranges AS r
           ON r.external_id = s.range_external_id
    WHERE r.id IS NULL
      AND s.range_external_id IS NOT NULL
    ON CONFLICT (external_id) DO NOTHING;

    -- 2. Категории.
    INSERT INTO public.dim_categories (external_id, name, parent_id)
    SELECT
        s.external_id,
        COALESCE(NULLIF(s.name, ''), 'Категория ' || s.external_id),
        s.parent_id
    FROM stg.categories AS s
    ON CONFLICT (external_id) DO UPDATE
    SET name      = EXCLUDED.name,
        parent_id = EXCLUDED.parent_id;

    -- 3. Поставщики.
    INSERT INTO public.dim_vendors (external_id, name, parent_id, parent_name)
    SELECT
        s.external_id,
        COALESCE(NULLIF(s.name, ''), 'Поставщик ' || s.external_id),
        s.parent_id,
        s.parent_name
    FROM stg.vendors AS s
    ON CONFLICT (external_id) DO UPDATE
    SET name        = EXCLUDED.name,
        parent_id   = EXCLUDED.parent_id,
        parent_name = EXCLUDED.parent_name;

    -- 4. Сотрудники.
    INSERT INTO public.dim_personnel (external_id, name, access_level)
    SELECT
        s.external_id,
        COALESCE(NULLIF(s.name, ''), 'Сотрудник ' || s.external_id),
        s.access_level
    FROM stg.personnel AS s
    ON CONFLICT (external_id) DO UPDATE
    SET name         = EXCLUDED.name,
        access_level = EXCLUDED.access_level;

    -- 5. Товары.
    INSERT INTO public.dim_products (
        external_id, name, category_id, range_id
    )
    SELECT
        s.external_id,
        COALESCE(NULLIF(s.name, ''), 'Товар ' || s.external_id),
        COALESCE(c.id, 0),
        COALESCE(r.id, 0)
    FROM stg.products AS s
    LEFT JOIN public.dim_categories AS c
           ON c.external_id = s.category_external_id
    LEFT JOIN public.dim_ranges AS r
           ON r.external_id = s.range_external_id
    ON CONFLICT (external_id) DO UPDATE
    SET name        = EXCLUDED.name,
        category_id = EXCLUDED.category_id,
        range_id    = EXCLUDED.range_id;

    -- 6. Склады.
    INSERT INTO public.dim_storages (external_id, name)
    SELECT
        s.external_id,
        COALESCE(NULLIF(s.name, ''), 'Склад ' || s.external_id)
    FROM stg.storages AS s
    ON CONFLICT (external_id) DO UPDATE
    SET name = EXCLUDED.name;

    -- 7. Способы оплаты.
    INSERT INTO public.dim_payment_types (external_id, name)
    SELECT
        s.external_id,
        COALESCE(NULLIF(s.name, ''), 'Способ оплаты ' || s.external_id)
    FROM stg.payment_types AS s
    ON CONFLICT (external_id) DO UPDATE
    SET name = EXCLUDED.name;

    -- 8. Типы складских операций.
    INSERT INTO public.dim_operation_types (external_id, name, factor)
    SELECT
        s.external_id,
        COALESCE(NULLIF(s.name, ''), 'Операция ' || s.external_id),
        CASE WHEN s.factor = -1 THEN -1 ELSE 1 END
    FROM stg.operation_types AS s
    ON CONFLICT (external_id) DO UPDATE
    SET name   = EXCLUDED.name,
        factor = EXCLUDED.factor;

    -- 9. Типы событий.
    INSERT INTO public.dim_event_types (name)
    SELECT s.name
    FROM stg.event_types AS s
    WHERE s.name IS NOT NULL
    ON CONFLICT (name) DO NOTHING;

    INSERT INTO public.dim_event_types (name)
    SELECT DISTINCT s.event_type_name
    FROM stg.personnel_sessions AS s
    WHERE s.event_type_name IS NOT NULL
    ON CONFLICT (name) DO NOTHING;

    RAISE NOTICE 'Ресурсы загружены: ranges=%, categories=%, vendors=%, products=%, personnel=%, storages=%',
        (SELECT count(*) FROM public.dim_ranges),
        (SELECT count(*) FROM public.dim_categories),
        (SELECT count(*) FROM public.dim_vendors),
        (SELECT count(*) FROM public.dim_products),
        (SELECT count(*) FROM public.dim_personnel),
        (SELECT count(*) FROM public.dim_storages);
END;
$$;

-- =============================================================================
-- 2. ФАКТЫ
-- =============================================================================
CREATE OR REPLACE PROCEDURE public.load_facts(p_full_refresh boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    v_missing_times bigint;
BEGIN
    WITH all_times AS (
        SELECT time_code FROM stg.purchases
        UNION
        SELECT time_code FROM stg.sales
        UNION
        SELECT time_code FROM stg.payments
        UNION
        SELECT time_code FROM stg.personnel_sessions
        UNION
        SELECT time_code FROM stg.personnel_bonus
        UNION
        SELECT time_code FROM stg.stock
    )
    SELECT count(*)
      INTO v_missing_times
      FROM all_times AS a
      LEFT JOIN public.time_metrics AS t ON t.external_id = a.time_code
     WHERE t.id IS NULL;

    IF v_missing_times > 0 THEN
        RAISE EXCEPTION
            'В public.time_metrics отсутствует % месяц(ев) из staging. Выполните 04_time_metrics.sql',
            v_missing_times;
    END IF;

    IF p_full_refresh THEN
        TRUNCATE TABLE
            public.fact_purchases,
            public.fact_sales,
            public.fact_payments,
            public.fact_personnel_sessions,
            public.fact_personnel_bonus,
            public.fact_stock
        RESTART IDENTITY;
    ELSE
        DELETE FROM public.fact_purchases
        WHERE time_id IN (
            SELECT t.id FROM public.time_metrics AS t
            JOIN (SELECT DISTINCT time_code FROM stg.purchases) AS s
              ON s.time_code = t.external_id
        );

        DELETE FROM public.fact_sales
        WHERE time_id IN (
            SELECT t.id FROM public.time_metrics AS t
            JOIN (SELECT DISTINCT time_code FROM stg.sales) AS s
              ON s.time_code = t.external_id
        );

        DELETE FROM public.fact_payments
        WHERE time_id IN (
            SELECT t.id FROM public.time_metrics AS t
            JOIN (SELECT DISTINCT time_code FROM stg.payments) AS s
              ON s.time_code = t.external_id
        );

        DELETE FROM public.fact_personnel_sessions
        WHERE time_id IN (
            SELECT t.id FROM public.time_metrics AS t
            JOIN (SELECT DISTINCT time_code FROM stg.personnel_sessions) AS s
              ON s.time_code = t.external_id
        );

        DELETE FROM public.fact_personnel_bonus
        WHERE time_id IN (
            SELECT t.id FROM public.time_metrics AS t
            JOIN (SELECT DISTINCT time_code FROM stg.personnel_bonus) AS s
              ON s.time_code = t.external_id
        );

        DELETE FROM public.fact_stock
        WHERE time_id IN (
            SELECT t.id FROM public.time_metrics AS t
            JOIN (SELECT DISTINCT time_code FROM stg.stock) AS s
              ON s.time_code = t.external_id
        );
    END IF;

    -- 2.1. Закупки.
    INSERT INTO public.fact_purchases (
        time_id, product_id, vendor_id, storage_id, range_id,
        lines_count, quantity, amount
    )
    SELECT
        t.id,
        COALESCE(p.id, 0),
        COALESCE(v.id, 0),
        COALESCE(st.id, 0),
        COALESCE(r.id, 0),
        s.lines_count,
        s.quantity,
        s.amount
    FROM stg.purchases AS s
    JOIN public.time_metrics AS t ON t.external_id = s.time_code
    LEFT JOIN public.dim_products AS p ON p.external_id = s.product_external_id
    LEFT JOIN public.dim_vendors AS v ON v.external_id = s.vendor_external_id
    LEFT JOIN public.dim_storages AS st ON st.external_id = s.storage_external_id
    LEFT JOIN public.dim_ranges AS r ON r.external_id = s.range_external_id
    ON CONFLICT (time_id, product_id, vendor_id, storage_id, range_id) DO UPDATE
    SET lines_count = EXCLUDED.lines_count,
        quantity    = EXCLUDED.quantity,
        amount      = EXCLUDED.amount;

    -- 2.2. Продажи.
    INSERT INTO public.fact_sales (
        time_id, product_id, lines_count, quantity,
        revenue, refund_amount, net_revenue
    )
    SELECT
        t.id,
        COALESCE(p.id, 0),
        s.lines_count,
        s.quantity,
        s.revenue,
        s.refund_amount,
        s.net_revenue
    FROM stg.sales AS s
    JOIN public.time_metrics AS t ON t.external_id = s.time_code
    LEFT JOIN public.dim_products AS p ON p.external_id = s.product_external_id
    ON CONFLICT (time_id, product_id) DO UPDATE
    SET lines_count   = EXCLUDED.lines_count,
        quantity      = EXCLUDED.quantity,
        revenue       = EXCLUDED.revenue,
        refund_amount = EXCLUDED.refund_amount,
        net_revenue   = EXCLUDED.net_revenue;

    -- 2.3. Оплаты.
    INSERT INTO public.fact_payments (
        time_id, payment_type_id, receipts_count, operations_count, amount
    )
    SELECT
        t.id,
        COALESCE(pt.id, 0),
        s.receipts_count,
        s.operations_count,
        s.amount
    FROM stg.payments AS s
    JOIN public.time_metrics AS t ON t.external_id = s.time_code
    LEFT JOIN public.dim_payment_types AS pt
           ON pt.external_id = s.payment_type_external_id
    ON CONFLICT (time_id, payment_type_id) DO UPDATE
    SET receipts_count   = EXCLUDED.receipts_count,
        operations_count = EXCLUDED.operations_count,
        amount           = EXCLUDED.amount;

    -- 2.4. Персонал: события.
    INSERT INTO public.fact_personnel_sessions (
        time_id, person_id, event_type_id, sessions_count, errors_count
    )
    SELECT
        t.id,
        COALESCE(p.id, 0),
        COALESCE(e.id, 0),
        s.sessions_count,
        s.errors_count
    FROM stg.personnel_sessions AS s
    JOIN public.time_metrics AS t ON t.external_id = s.time_code
    LEFT JOIN public.dim_personnel AS p ON p.external_id = s.person_external_id
    LEFT JOIN public.dim_event_types AS e ON e.name = s.event_type_name
    ON CONFLICT (time_id, person_id, event_type_id) DO UPDATE
    SET sessions_count = EXCLUDED.sessions_count,
        errors_count   = EXCLUDED.errors_count;

    -- 2.5. Персонал: бонусы.
    INSERT INTO public.fact_personnel_bonus (
        time_id, person_id, bonus_records_count, bonus_value
    )
    SELECT
        t.id,
        COALESCE(p.id, 0),
        s.bonus_records_count,
        s.bonus_value
    FROM stg.personnel_bonus AS s
    JOIN public.time_metrics AS t ON t.external_id = s.time_code
    LEFT JOIN public.dim_personnel AS p ON p.external_id = s.person_external_id
    ON CONFLICT (time_id, person_id) DO UPDATE
    SET bonus_records_count = EXCLUDED.bonus_records_count,
        bonus_value         = EXCLUDED.bonus_value;

    -- 2.6. Движение товара.
    INSERT INTO public.fact_stock (
        time_id, product_id, storage_id, operation_type_id, range_id,
        lines_count, quantity, amount, turnover_amount
    )
    SELECT
        t.id,
        COALESCE(p.id, 0),
        COALESCE(st.id, 0),
        COALESCE(o.id, 0),
        COALESCE(r.id, 0),
        s.lines_count,
        s.quantity,
        s.amount,
        s.turnover_amount
    FROM stg.stock AS s
    JOIN public.time_metrics AS t ON t.external_id = s.time_code
    LEFT JOIN public.dim_products AS p ON p.external_id = s.product_external_id
    LEFT JOIN public.dim_storages AS st ON st.external_id = s.storage_external_id
    LEFT JOIN public.dim_operation_types AS o ON o.external_id = s.operation_type_external_id
    LEFT JOIN public.dim_ranges AS r ON r.external_id = s.range_external_id
    ON CONFLICT (time_id, product_id, storage_id, operation_type_id, range_id) DO UPDATE
    SET lines_count     = EXCLUDED.lines_count,
        quantity        = EXCLUDED.quantity,
        amount          = EXCLUDED.amount,
        turnover_amount = EXCLUDED.turnover_amount;

    RAISE NOTICE 'Факты загружены: закупки=%, продажи=%, оплаты=%, сессии=%, бонусы=%, движение=%',
        (SELECT count(*) FROM public.fact_purchases),
        (SELECT count(*) FROM public.fact_sales),
        (SELECT count(*) FROM public.fact_payments),
        (SELECT count(*) FROM public.fact_personnel_sessions),
        (SELECT count(*) FROM public.fact_personnel_bonus),
        (SELECT count(*) FROM public.fact_stock);
END;
$$;

-- =============================================================================
-- 3. ОБЁРТКА И ЗАПУСК
-- =============================================================================
CREATE OR REPLACE PROCEDURE public.load_all(p_full_refresh boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
BEGIN
    CALL public.load_dimensions();
    CALL public.load_facts(p_full_refresh);
END;
$$;

BEGIN;
CALL public.load_all(false);
COMMIT;
