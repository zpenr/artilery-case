-- =============================================================================
-- 03_load_olap.sql
-- PL/pgSQL-скрипт загрузки данных из staging (stg.*) в OLAP-витрину (public.*).
--
-- Предусловия:
--   1. Выполнен 01_ddl_olap.sql (база db2026).
--   2. Выполнен 04_dim_time.sql.
--   3. Таблицы stg.* заполнены результатами 02_extract_front_mssql.sql.
--
-- Использование:
--   CALL public.load_all(false); -- инкрементально по месяцам из staging
--   CALL public.load_all(true);  -- полная перезагрузка фактов
--
-- Процедуры не делают COMMIT. Для атомарной загрузки:
--   BEGIN;
--   CALL public.load_all(false);
--   COMMIT;
-- =============================================================================

-- =============================================================================
-- 1. ЗАГРУЗКА ИЗМЕРЕНИЙ
-- =============================================================================
CREATE OR REPLACE PROCEDURE public.load_dimensions()
LANGUAGE plpgsql
AS $$
BEGIN
    -- Неуказанные элементы получают суррогатный id = 0 и external_id = 0.
    -- Это позволяет фактам ссылаться на «неизвестное» значение без NULL.
    INSERT INTO public.dim_ranges (id, external_id, name, factor)
    VALUES (0, 0, 'Не указан', 1)
    ON CONFLICT DO NOTHING;

    INSERT INTO public.dim_categories (id, external_id, name, parent_id)
    VALUES (0, 0, 'Не указана', NULL)
    ON CONFLICT DO NOTHING;

    INSERT INTO public.dim_vendors (id, external_id, name, parent_id, parent_name)
    VALUES (0, 0, 'Не указан', NULL, NULL)
    ON CONFLICT DO NOTHING;

    INSERT INTO public.dim_personnel (
        id, external_id, name, last_name, first_name, middle_name,
        access_level, has_pos_access, is_deleted
    )
    VALUES (0, 0, 'Не указан', NULL, NULL, NULL, NULL, false, false)
    ON CONFLICT DO NOTHING;

    INSERT INTO public.dim_payment_types (id, external_id, name)
    VALUES (0, 0, 'Не указан')
    ON CONFLICT DO NOTHING;

    INSERT INTO public.dim_operation_types (id, external_id, name, factor)
    VALUES (0, 0, 'Не указан', 1)
    ON CONFLICT DO NOTHING;

    INSERT INTO public.dim_products (
        id, external_id, external_code, name, category_id, range_id, cost, is_active
    )
    VALUES (0, 0, NULL, 'Не указан', 0, 0, NULL, true)
    ON CONFLICT DO NOTHING;

    INSERT INTO public.dim_storages (
        id, external_id, name, company_external_id, company_name, responsible_person_id
    )
    VALUES (0, 0, 'Не указан', NULL, NULL, 0)
    ON CONFLICT DO NOTHING;

    -- Специальный тип события для бонусных начислений.
    INSERT INTO public.dim_event_types (id, external_id, name)
    VALUES (0, 0, 'Бонусные начисления')
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

    -- 2. Категории (parent_id хранит внешний код родителя).
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

    -- 4. Сотрудники (до складов: склад ссылается на ответственного).
    INSERT INTO public.dim_personnel (
        external_id, name, last_name, first_name, middle_name,
        access_level, has_pos_access, is_deleted
    )
    SELECT
        s.external_id,
        COALESCE(NULLIF(s.name, ''), 'Сотрудник ' || s.external_id),
        s.last_name,
        s.first_name,
        s.middle_name,
        s.access_level,
        COALESCE(s.has_pos_access, false),
        COALESCE(s.is_deleted, false)
    FROM stg.personnel AS s
    ON CONFLICT (external_id) DO UPDATE
    SET name           = EXCLUDED.name,
        last_name      = EXCLUDED.last_name,
        first_name     = EXCLUDED.first_name,
        middle_name    = EXCLUDED.middle_name,
        access_level   = EXCLUDED.access_level,
        has_pos_access = EXCLUDED.has_pos_access,
        is_deleted     = EXCLUDED.is_deleted;

    -- 5. Товары (категория и единица измерения разрешаются в суррогатные id).
    INSERT INTO public.dim_products (
        external_id, external_code, name, category_id, range_id, cost, is_active
    )
    SELECT
        s.external_id,
        s.external_code,
        COALESCE(NULLIF(s.name, ''), 'Товар ' || s.external_id),
        COALESCE(c.id, 0),
        COALESCE(r.id, 0),
        s.cost,
        COALESCE(s.is_active, true)
    FROM stg.products AS s
    LEFT JOIN public.dim_categories AS c
           ON c.external_id = s.category_external_id
    LEFT JOIN public.dim_ranges AS r
           ON r.external_id = s.range_external_id
    ON CONFLICT (external_id) DO UPDATE
    SET external_code = EXCLUDED.external_code,
        name          = EXCLUDED.name,
        category_id   = EXCLUDED.category_id,
        range_id      = EXCLUDED.range_id,
        cost          = EXCLUDED.cost,
        is_active     = EXCLUDED.is_active;

    -- 6. Склады.
    INSERT INTO public.dim_storages (
        external_id, name, company_external_id, company_name, responsible_person_id
    )
    SELECT
        s.external_id,
        COALESCE(NULLIF(s.name, ''), 'Склад ' || s.external_id),
        s.company_external_id,
        s.company_name,
        COALESCE(p.id, 0)
    FROM stg.storages AS s
    LEFT JOIN public.dim_personnel AS p
           ON p.external_id = s.responsible_person_external_id
    ON CONFLICT (external_id) DO UPDATE
    SET name                  = EXCLUDED.name,
        company_external_id   = EXCLUDED.company_external_id,
        company_name          = EXCLUDED.company_name,
        responsible_person_id = EXCLUDED.responsible_person_id;

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

    -- 9. Типы событий (натуральный ключ — name).
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

    -- 10. Страховка: в источнике могут встречаться внешние коды, которых нет
    -- в справочнике (например, RangeID = 163, 111, 796 отсутствуют в [size]).
    -- Создаём для них отдельные строки, чтобы не «схлопывать» разные значения
    -- в один id = 0 и не нарушать уникальность гранулярности фактов.
    INSERT INTO public.dim_categories (external_id, name, parent_id)
    SELECT DISTINCT s.category_external_id,
           'Категория ' || s.category_external_id,
           NULL::bigint
    FROM (
        SELECT category_external_id FROM stg.products
        UNION
        SELECT category_external_id FROM stg.purchases
        UNION
        SELECT category_external_id FROM stg.sales
    ) AS s
    LEFT JOIN public.dim_categories AS d
           ON d.external_id = s.category_external_id
    WHERE d.id IS NULL
      AND s.category_external_id IS NOT NULL
    ON CONFLICT (external_id) DO NOTHING;

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
    LEFT JOIN public.dim_ranges AS d
           ON d.external_id = s.range_external_id
    WHERE d.id IS NULL
      AND s.range_external_id IS NOT NULL
    ON CONFLICT (external_id) DO NOTHING;

    INSERT INTO public.dim_products (
        external_id, external_code, name, category_id, range_id, cost, is_active
    )
    SELECT DISTINCT s.product_external_id,
           NULL::text,
           'Товар ' || s.product_external_id,
           0,
           0,
           NULL::numeric,
           true
    FROM (
        SELECT product_external_id FROM stg.purchases
        UNION
        SELECT product_external_id FROM stg.sales
        UNION
        SELECT product_external_id FROM stg.stock
    ) AS s
    LEFT JOIN public.dim_products AS d
           ON d.external_id = s.product_external_id
    WHERE d.id IS NULL
      AND s.product_external_id IS NOT NULL
    ON CONFLICT (external_id) DO NOTHING;

    INSERT INTO public.dim_vendors (external_id, name, parent_id, parent_name)
    SELECT DISTINCT s.vendor_external_id,
           'Поставщик ' || s.vendor_external_id,
           NULL::bigint,
           NULL::text
    FROM stg.purchases AS s
    LEFT JOIN public.dim_vendors AS d
           ON d.external_id = s.vendor_external_id
    WHERE d.id IS NULL
      AND s.vendor_external_id IS NOT NULL
    ON CONFLICT (external_id) DO NOTHING;

    INSERT INTO public.dim_personnel (external_id, name)
    SELECT DISTINCT s.person_external_id,
           'Сотрудник ' || s.person_external_id
    FROM (
        SELECT person_external_id FROM stg.personnel_sessions
        UNION
        SELECT person_external_id FROM stg.personnel_bonus
    ) AS s
    LEFT JOIN public.dim_personnel AS d
           ON d.external_id = s.person_external_id
    WHERE d.id IS NULL
      AND s.person_external_id IS NOT NULL
    ON CONFLICT (external_id) DO NOTHING;

    INSERT INTO public.dim_storages (external_id, name, responsible_person_id)
    SELECT DISTINCT s.storage_external_id,
           'Склад ' || s.storage_external_id,
           0
    FROM (
        SELECT storage_external_id FROM stg.purchases
        UNION
        SELECT storage_external_id FROM stg.stock
    ) AS s
    LEFT JOIN public.dim_storages AS d
           ON d.external_id = s.storage_external_id
    WHERE d.id IS NULL
      AND s.storage_external_id IS NOT NULL
    ON CONFLICT (external_id) DO NOTHING;

    INSERT INTO public.dim_payment_types (external_id, name)
    SELECT DISTINCT s.payment_type_external_id,
           'Способ оплаты ' || s.payment_type_external_id
    FROM stg.payments AS s
    LEFT JOIN public.dim_payment_types AS d
           ON d.external_id = s.payment_type_external_id
    WHERE d.id IS NULL
      AND s.payment_type_external_id IS NOT NULL
    ON CONFLICT (external_id) DO NOTHING;

    INSERT INTO public.dim_operation_types (external_id, name, factor)
    SELECT DISTINCT s.operation_type_external_id,
           'Операция ' || s.operation_type_external_id,
           1
    FROM stg.stock AS s
    LEFT JOIN public.dim_operation_types AS d
           ON d.external_id = s.operation_type_external_id
    WHERE d.id IS NULL
      AND s.operation_type_external_id IS NOT NULL
    ON CONFLICT (external_id) DO NOTHING;

    -- После создания недостающих категорий/единиц уточняем ссылки товаров.
    UPDATE public.dim_products AS p
    SET category_id = COALESCE(c.id, 0),
        range_id    = COALESCE(r.id, 0)
    FROM stg.products AS s
    LEFT JOIN public.dim_categories AS c
           ON c.external_id = s.category_external_id
    LEFT JOIN public.dim_ranges AS r
           ON r.external_id = s.range_external_id
    WHERE p.external_id = s.external_id;

    RAISE NOTICE 'Измерения загружены: ranges=%, categories=%, vendors=%, products=%, personnel=%, storages=%',
        (SELECT count(*) FROM public.dim_ranges),
        (SELECT count(*) FROM public.dim_categories),
        (SELECT count(*) FROM public.dim_vendors),
        (SELECT count(*) FROM public.dim_products),
        (SELECT count(*) FROM public.dim_personnel),
        (SELECT count(*) FROM public.dim_storages);
END;
$$;

-- =============================================================================
-- 2. ЗАГРУЗКА ФАКТОВ
-- =============================================================================
CREATE OR REPLACE PROCEDURE public.load_facts(p_full_refresh boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
DECLARE
    v_missing_times bigint;
BEGIN
    -- Проверяем, что измерение Время покрывает все месяцы из staging.
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
      LEFT JOIN public.dim_time AS t ON t.external_id = a.time_code
     WHERE t.id IS NULL;

    IF v_missing_times > 0 THEN
        RAISE EXCEPTION
            'В public.dim_time отсутствует % месяц(ев) из staging. Выполните 04_dim_time.sql',
            v_missing_times;
    END IF;

    IF p_full_refresh THEN
        TRUNCATE TABLE
            public.fact_purchases,
            public.fact_sales,
            public.fact_payments,
            public.fact_personnel,
            public.fact_stock
        RESTART IDENTITY;
    ELSE
        DELETE FROM public.fact_purchases
        WHERE time_id IN (
            SELECT t.id
            FROM public.dim_time AS t
            JOIN (SELECT DISTINCT time_code FROM stg.purchases) AS s
              ON s.time_code = t.external_id
        );

        DELETE FROM public.fact_sales
        WHERE time_id IN (
            SELECT t.id
            FROM public.dim_time AS t
            JOIN (SELECT DISTINCT time_code FROM stg.sales) AS s
              ON s.time_code = t.external_id
        );

        DELETE FROM public.fact_payments
        WHERE time_id IN (
            SELECT t.id
            FROM public.dim_time AS t
            JOIN (SELECT DISTINCT time_code FROM stg.payments) AS s
              ON s.time_code = t.external_id
        );

        DELETE FROM public.fact_personnel
        WHERE time_id IN (
            SELECT t.id
            FROM public.dim_time AS t
            JOIN (
                SELECT time_code FROM stg.personnel_sessions
                UNION
                SELECT time_code FROM stg.personnel_bonus
            ) AS s
              ON s.time_code = t.external_id
        );

        DELETE FROM public.fact_stock
        WHERE time_id IN (
            SELECT t.id
            FROM public.dim_time AS t
            JOIN (SELECT DISTINCT time_code FROM stg.stock) AS s
              ON s.time_code = t.external_id
        );
    END IF;

    -- 2.1. Закупки.
    INSERT INTO public.fact_purchases (
        time_id, product_id, vendor_id, category_id, storage_id, range_id,
        lines_count, quantity, amount, avg_price
    )
    SELECT
        t.id,
        COALESCE(p.id, 0),
        COALESCE(v.id, 0),
        COALESCE(c.id, 0),
        COALESCE(st.id, 0),
        COALESCE(r.id, 0),
        s.lines_count,
        s.quantity,
        s.amount,
        s.avg_price
    FROM stg.purchases AS s
    JOIN public.dim_time AS t
      ON t.external_id = s.time_code
    LEFT JOIN public.dim_products AS p
           ON p.external_id = s.product_external_id
    LEFT JOIN public.dim_vendors AS v
           ON v.external_id = s.vendor_external_id
    LEFT JOIN public.dim_categories AS c
           ON c.external_id = s.category_external_id
    LEFT JOIN public.dim_storages AS st
           ON st.external_id = s.storage_external_id
    LEFT JOIN public.dim_ranges AS r
           ON r.external_id = s.range_external_id
    ON CONFLICT (time_id, product_id, vendor_id, storage_id, range_id) DO UPDATE
    SET category_id = EXCLUDED.category_id,
        lines_count = EXCLUDED.lines_count,
        quantity    = EXCLUDED.quantity,
        amount      = EXCLUDED.amount,
        avg_price   = EXCLUDED.avg_price;

    -- 2.2. Продажи.
    INSERT INTO public.fact_sales (
        time_id, product_id, category_id, receipts_count, lines_count,
        quantity, revenue, refund_amount, net_revenue
    )
    SELECT
        t.id,
        COALESCE(p.id, 0),
        COALESCE(c.id, 0),
        s.receipts_count,
        s.lines_count,
        s.quantity,
        s.revenue,
        s.refund_amount,
        s.net_revenue
    FROM stg.sales AS s
    JOIN public.dim_time AS t
      ON t.external_id = s.time_code
    LEFT JOIN public.dim_products AS p
           ON p.external_id = s.product_external_id
    LEFT JOIN public.dim_categories AS c
           ON c.external_id = s.category_external_id
    ON CONFLICT (time_id, product_id) DO UPDATE
    SET category_id    = EXCLUDED.category_id,
        receipts_count = EXCLUDED.receipts_count,
        lines_count    = EXCLUDED.lines_count,
        quantity       = EXCLUDED.quantity,
        revenue        = EXCLUDED.revenue,
        refund_amount  = EXCLUDED.refund_amount,
        net_revenue    = EXCLUDED.net_revenue;

    -- 2.3. Оплаты.
    INSERT INTO public.fact_payments (
        time_id, payment_type_id, operations_count, amount
    )
    SELECT
        t.id,
        COALESCE(pt.id, 0),
        s.operations_count,
        s.amount
    FROM stg.payments AS s
    JOIN public.dim_time AS t
      ON t.external_id = s.time_code
    LEFT JOIN public.dim_payment_types AS pt
           ON pt.external_id = s.payment_type_external_id
    ON CONFLICT (time_id, payment_type_id) DO UPDATE
    SET operations_count = EXCLUDED.operations_count,
        amount           = EXCLUDED.amount;

    -- 2.4. Персонал: события.
    INSERT INTO public.fact_personnel (
        time_id, person_id, event_type_id,
        sessions_count, errors_count, bonus_records_count, bonus_value
    )
    SELECT
        t.id,
        COALESCE(p.id, 0),
        e.id,
        s.sessions_count,
        s.errors_count,
        0,
        0
    FROM stg.personnel_sessions AS s
    JOIN public.dim_time AS t
      ON t.external_id = s.time_code
    LEFT JOIN public.dim_personnel AS p
           ON p.external_id = s.person_external_id
    JOIN public.dim_event_types AS e
      ON e.name = s.event_type_name
    ON CONFLICT (time_id, person_id, event_type_id) DO UPDATE
    SET sessions_count = EXCLUDED.sessions_count,
        errors_count   = EXCLUDED.errors_count;

    -- 2.5. Персонал: бонусы.
    INSERT INTO public.fact_personnel (
        time_id, person_id, event_type_id,
        sessions_count, errors_count, bonus_records_count, bonus_value
    )
    SELECT
        t.id,
        COALESCE(p.id, 0),
        e.id,
        0,
        0,
        s.bonus_records_count,
        s.bonus_value
    FROM stg.personnel_bonus AS s
    JOIN public.dim_time AS t
      ON t.external_id = s.time_code
    LEFT JOIN public.dim_personnel AS p
           ON p.external_id = s.person_external_id
    JOIN public.dim_event_types AS e
      ON e.name = 'Бонусные начисления'
    ON CONFLICT (time_id, person_id, event_type_id) DO UPDATE
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
    JOIN public.dim_time AS t
      ON t.external_id = s.time_code
    LEFT JOIN public.dim_products AS p
           ON p.external_id = s.product_external_id
    LEFT JOIN public.dim_storages AS st
           ON st.external_id = s.storage_external_id
    LEFT JOIN public.dim_operation_types AS o
           ON o.external_id = s.operation_type_external_id
    LEFT JOIN public.dim_ranges AS r
           ON r.external_id = s.range_external_id
    ON CONFLICT (time_id, product_id, storage_id, operation_type_id, range_id) DO UPDATE
    SET lines_count     = EXCLUDED.lines_count,
        quantity        = EXCLUDED.quantity,
        amount          = EXCLUDED.amount,
        turnover_amount = EXCLUDED.turnover_amount;

    RAISE NOTICE 'Факты загружены: закупки=%, продажи=%, оплаты=%, персонал=%, движение=%',
        (SELECT count(*) FROM public.fact_purchases),
        (SELECT count(*) FROM public.fact_sales),
        (SELECT count(*) FROM public.fact_payments),
        (SELECT count(*) FROM public.fact_personnel),
        (SELECT count(*) FROM public.fact_stock);
END;
$$;

-- =============================================================================
-- 3. ОБЁРТКА
-- =============================================================================
CREATE OR REPLACE PROCEDURE public.load_all(p_full_refresh boolean DEFAULT false)
LANGUAGE plpgsql
AS $$
BEGIN
    CALL public.load_dimensions();
    CALL public.load_facts(p_full_refresh);
END;
$$;

-- =============================================================================
-- 4. ЗАПУСК
-- =============================================================================
BEGIN;
CALL public.load_all(false);
COMMIT;
