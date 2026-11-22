-- =============================================================================
-- 01_ddl_olap.sql
-- DDL OLAP-базы db2026 (PostgreSQL).
--
-- Создать базу один раз от суперпользователя:
--   CREATE DATABASE db2026;
-- Затем подключиться к db2026 и выполнить этот скрипт.
--
-- Структура:
--   * ресурсы-измерения dim_*: единица измерения, категория, поставщик,
--     товар, сотрудник, склад, способ оплаты, тип операции, тип события;
--   * отдельная метрика time_metrics (время);
--   * факты по четырём направлениям: закупки, продажи, персонал, остатки.
--
-- Стиль измерений — как в файле преподавателя:
--   id bigint primary key default nextval('public.seq_dim_...'),
--   external_id, name, ..., date_add timestamp default now().
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS stg;

-- =============================================================================
-- 1. РЕСУРСЫ-ИЗМЕРЕНИЯ
-- =============================================================================

-- 1.1. Единицы измерения (шаблон преподавателя) --------------------------------
CREATE SEQUENCE IF NOT EXISTS public.seq_dim_ranges;

CREATE TABLE IF NOT EXISTS public.dim_ranges (
    id          bigint PRIMARY KEY DEFAULT nextval('public.seq_dim_ranges'),
    external_id bigint UNIQUE,
    name        text,
    factor      double precision,
    date_add    timestamp DEFAULT now()
);

COMMENT ON TABLE  public.dim_ranges IS 'Единицы измерения (dbo.[size])';
COMMENT ON COLUMN public.dim_ranges.id          IS 'Внутренний код';
COMMENT ON COLUMN public.dim_ranges.external_id IS 'Код единицы измерения в Front';
COMMENT ON COLUMN public.dim_ranges.name        IS 'Название единицы измерения';
COMMENT ON COLUMN public.dim_ranges.factor      IS 'Коэффициент пересчёта';
COMMENT ON COLUMN public.dim_ranges.date_add    IS 'Дата добавления записи';

-- 1.2. Категории --------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.seq_dim_categories;

CREATE TABLE IF NOT EXISTS public.dim_categories (
    id          bigint PRIMARY KEY DEFAULT nextval('public.seq_dim_categories'),
    external_id bigint UNIQUE,
    name        text,
    parent_id   bigint,
    date_add    timestamp DEFAULT now()
);

COMMENT ON TABLE  public.dim_categories IS 'Категории товаров (dbo.category)';
COMMENT ON COLUMN public.dim_categories.id          IS 'Внутренний код';
COMMENT ON COLUMN public.dim_categories.external_id IS 'Код категории в Front';
COMMENT ON COLUMN public.dim_categories.name        IS 'Название категории';
COMMENT ON COLUMN public.dim_categories.parent_id   IS 'Код родительской категории в Front';
COMMENT ON COLUMN public.dim_categories.date_add    IS 'Дата добавления записи';

-- 1.3. Поставщики -------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.seq_dim_vendors;

CREATE TABLE IF NOT EXISTS public.dim_vendors (
    id          bigint PRIMARY KEY DEFAULT nextval('public.seq_dim_vendors'),
    external_id bigint UNIQUE,
    name        text,
    parent_id   bigint,
    parent_name text,
    date_add    timestamp DEFAULT now()
);

COMMENT ON TABLE  public.dim_vendors IS 'Поставщики (dbo.vendors + dbo.vendorgroup)';
COMMENT ON COLUMN public.dim_vendors.id          IS 'Внутренний код';
COMMENT ON COLUMN public.dim_vendors.external_id IS 'Код поставщика в Front';
COMMENT ON COLUMN public.dim_vendors.name        IS 'Название поставщика (vendors.clientid)';
COMMENT ON COLUMN public.dim_vendors.parent_id   IS 'Код группы поставщиков';
COMMENT ON COLUMN public.dim_vendors.parent_name IS 'Название группы поставщиков';
COMMENT ON COLUMN public.dim_vendors.date_add    IS 'Дата добавления записи';

-- 1.4. Сотрудники -------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.seq_dim_personnel;

CREATE TABLE IF NOT EXISTS public.dim_personnel (
    id           bigint PRIMARY KEY DEFAULT nextval('public.seq_dim_personnel'),
    external_id  bigint UNIQUE,
    name         text,
    access_level smallint,
    date_add     timestamp DEFAULT now()
);

COMMENT ON TABLE  public.dim_personnel IS 'Сотрудники (dbo.personnel)';
COMMENT ON COLUMN public.dim_personnel.id           IS 'Внутренний код';
COMMENT ON COLUMN public.dim_personnel.external_id  IS 'Код сотрудника в Front';
COMMENT ON COLUMN public.dim_personnel.name         IS 'ФИО';
COMMENT ON COLUMN public.dim_personnel.access_level IS 'Уровень доступа';
COMMENT ON COLUMN public.dim_personnel.date_add     IS 'Дата добавления записи';

-- 1.5. Способы оплаты ---------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.seq_dim_payment_types;

CREATE TABLE IF NOT EXISTS public.dim_payment_types (
    id          bigint PRIMARY KEY DEFAULT nextval('public.seq_dim_payment_types'),
    external_id bigint UNIQUE,
    name        text,
    date_add    timestamp DEFAULT now()
);

COMMENT ON TABLE  public.dim_payment_types IS 'Способы оплаты (transtype.transgroupid = 2)';
COMMENT ON COLUMN public.dim_payment_types.id          IS 'Внутренний код';
COMMENT ON COLUMN public.dim_payment_types.external_id IS 'Код способа оплаты в Front';
COMMENT ON COLUMN public.dim_payment_types.name        IS 'Название способа оплаты';
COMMENT ON COLUMN public.dim_payment_types.date_add    IS 'Дата добавления записи';

-- 1.6. Типы складских операций ------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.seq_dim_operation_types;

CREATE TABLE IF NOT EXISTS public.dim_operation_types (
    id          bigint PRIMARY KEY DEFAULT nextval('public.seq_dim_operation_types'),
    external_id bigint UNIQUE,
    name        text,
    factor      smallint CHECK (factor IN (-1, 1)),
    date_add    timestamp DEFAULT now()
);

COMMENT ON TABLE  public.dim_operation_types IS 'Типы складских операций';
COMMENT ON COLUMN public.dim_operation_types.id          IS 'Внутренний код';
COMMENT ON COLUMN public.dim_operation_types.external_id IS 'Код типа операции в Front';
COMMENT ON COLUMN public.dim_operation_types.name        IS 'Название типа операции';
COMMENT ON COLUMN public.dim_operation_types.factor      IS 'Знак операции: +1 приход, -1 расход';
COMMENT ON COLUMN public.dim_operation_types.date_add    IS 'Дата добавления записи';

-- 1.7. Типы событий журнала сессий --------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.seq_dim_event_types;

CREATE TABLE IF NOT EXISTS public.dim_event_types (
    id          bigint PRIMARY KEY DEFAULT nextval('public.seq_dim_event_types'),
    external_id bigint,
    name        text UNIQUE,
    date_add    timestamp DEFAULT now()
);

COMMENT ON TABLE  public.dim_event_types IS 'Типы событий (bm_JournalSessions.Type)';
COMMENT ON COLUMN public.dim_event_types.id          IS 'Внутренний код';
COMMENT ON COLUMN public.dim_event_types.external_id IS 'Служебный код (0 — бонусы)';
COMMENT ON COLUMN public.dim_event_types.name        IS 'Название типа события';
COMMENT ON COLUMN public.dim_event_types.date_add    IS 'Дата добавления записи';

-- 1.8. Товары ----------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.seq_dim_products;

CREATE TABLE IF NOT EXISTS public.dim_products (
    id          bigint PRIMARY KEY DEFAULT nextval('public.seq_dim_products'),
    external_id bigint UNIQUE,
    name        text,
    category_id bigint NOT NULL REFERENCES public.dim_categories (id),
    range_id    bigint NOT NULL REFERENCES public.dim_ranges (id),
    date_add    timestamp DEFAULT now()
);

COMMENT ON TABLE  public.dim_products IS 'Товары / ингредиенты (dbo.product)';
COMMENT ON COLUMN public.dim_products.id          IS 'Внутренний код';
COMMENT ON COLUMN public.dim_products.external_id IS 'Код товара в Front';
COMMENT ON COLUMN public.dim_products.name        IS 'Наименование товара';
COMMENT ON COLUMN public.dim_products.category_id IS 'Ссылка на dim_categories.id';
COMMENT ON COLUMN public.dim_products.range_id    IS 'Ссылка на dim_ranges.id';
COMMENT ON COLUMN public.dim_products.date_add    IS 'Дата добавления записи';

-- 1.9. Склады ----------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.seq_dim_storages;

CREATE TABLE IF NOT EXISTS public.dim_storages (
    id          bigint PRIMARY KEY DEFAULT nextval('public.seq_dim_storages'),
    external_id bigint UNIQUE,
    name        text,
    date_add    timestamp DEFAULT now()
);

COMMENT ON TABLE  public.dim_storages IS 'Склады (dbo.storages)';
COMMENT ON COLUMN public.dim_storages.id          IS 'Внутренний код';
COMMENT ON COLUMN public.dim_storages.external_id IS 'Код склада в Front';
COMMENT ON COLUMN public.dim_storages.name        IS 'Название склада';
COMMENT ON COLUMN public.dim_storages.date_add    IS 'Дата добавления записи';

-- =============================================================================
-- 2. МЕТРИКА ВРЕМЯ
-- =============================================================================
CREATE SEQUENCE IF NOT EXISTS public.seq_time_metrics;

CREATE TABLE IF NOT EXISTS public.time_metrics (
    id               bigint PRIMARY KEY DEFAULT nextval('public.seq_time_metrics'),
    external_id      bigint NOT NULL UNIQUE,
    month_start_date date NOT NULL,
    month_end_date   date NOT NULL,
    month_name       text NOT NULL,
    year             integer NOT NULL,
    quarter_number   integer NOT NULL,
    quarter_name     text NOT NULL,
    date_add         timestamp DEFAULT now(),
    CONSTRAINT chk_time_metrics_period CHECK (month_start_date <= month_end_date),
    CONSTRAINT chk_time_metrics_quarter CHECK (quarter_number BETWEEN 1 AND 4)
);

COMMENT ON TABLE  public.time_metrics IS 'Метрика Время (месяц). external_id = YYYYMM';
COMMENT ON COLUMN public.time_metrics.id               IS 'Внутренний код';
COMMENT ON COLUMN public.time_metrics.external_id      IS 'Код месяца YYYYMM';
COMMENT ON COLUMN public.time_metrics.month_start_date IS 'Дата начала месяца';
COMMENT ON COLUMN public.time_metrics.month_end_date   IS 'Дата окончания месяца';
COMMENT ON COLUMN public.time_metrics.month_name       IS 'Название месяца';
COMMENT ON COLUMN public.time_metrics.year             IS 'Год';
COMMENT ON COLUMN public.time_metrics.quarter_number   IS 'Номер квартала';
COMMENT ON COLUMN public.time_metrics.quarter_name     IS 'Название квартала';
COMMENT ON COLUMN public.time_metrics.date_add         IS 'Дата добавления записи';

-- =============================================================================
-- 3. ФАКТЫ
-- =============================================================================

-- 3.1. Закупки продукции ------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.seq_fact_purchases;

CREATE TABLE IF NOT EXISTS public.fact_purchases (
    id          bigint PRIMARY KEY DEFAULT nextval('public.seq_fact_purchases'),
    time_id     bigint NOT NULL REFERENCES public.time_metrics (id),
    product_id  bigint NOT NULL REFERENCES public.dim_products (id),
    vendor_id   bigint NOT NULL REFERENCES public.dim_vendors (id),
    storage_id  bigint NOT NULL REFERENCES public.dim_storages (id),
    range_id    bigint NOT NULL REFERENCES public.dim_ranges (id),
    lines_count bigint NOT NULL CHECK (lines_count >= 0),
    quantity    numeric(18,4) NOT NULL,
    amount      numeric(18,2) NOT NULL,
    date_add    timestamp DEFAULT now(),
    CONSTRAINT ux_fact_purchases_grain
        UNIQUE (time_id, product_id, vendor_id, storage_id, range_id)
);

COMMENT ON TABLE public.fact_purchases IS 'Закупки: месяц x товар x поставщик x склад x единица';

-- 3.2. Продажи товара ---------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.seq_fact_sales;

CREATE TABLE IF NOT EXISTS public.fact_sales (
    id            bigint PRIMARY KEY DEFAULT nextval('public.seq_fact_sales'),
    time_id       bigint NOT NULL REFERENCES public.time_metrics (id),
    product_id    bigint NOT NULL REFERENCES public.dim_products (id),
    lines_count   bigint NOT NULL CHECK (lines_count >= 0),
    quantity      numeric(18,3) NOT NULL,
    revenue       numeric(18,2) NOT NULL,
    refund_amount numeric(18,2) NOT NULL,
    net_revenue   numeric(18,2) NOT NULL,
    date_add      timestamp DEFAULT now(),
    CONSTRAINT ux_fact_sales_grain UNIQUE (time_id, product_id)
);

COMMENT ON TABLE public.fact_sales IS 'Продажи: месяц x товар';

-- 3.3. Оплаты (часть анализа продаж) ------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.seq_fact_payments;

CREATE TABLE IF NOT EXISTS public.fact_payments (
    id               bigint PRIMARY KEY DEFAULT nextval('public.seq_fact_payments'),
    time_id          bigint NOT NULL REFERENCES public.time_metrics (id),
    payment_type_id  bigint NOT NULL REFERENCES public.dim_payment_types (id),
    receipts_count   bigint NOT NULL CHECK (receipts_count >= 0),
    operations_count bigint NOT NULL CHECK (operations_count >= 0),
    amount           numeric(18,2) NOT NULL,
    date_add         timestamp DEFAULT now(),
    CONSTRAINT ux_fact_payments_grain UNIQUE (time_id, payment_type_id)
);

COMMENT ON TABLE public.fact_payments IS 'Оплаты: месяц x способ оплаты';

-- 3.4. Работа персонала: сессии ----------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.seq_fact_personnel_sessions;

CREATE TABLE IF NOT EXISTS public.fact_personnel_sessions (
    id             bigint PRIMARY KEY DEFAULT nextval('public.seq_fact_personnel_sessions'),
    time_id        bigint NOT NULL REFERENCES public.time_metrics (id),
    person_id      bigint NOT NULL REFERENCES public.dim_personnel (id),
    event_type_id  bigint NOT NULL REFERENCES public.dim_event_types (id),
    sessions_count bigint NOT NULL CHECK (sessions_count >= 0),
    errors_count   bigint NOT NULL CHECK (errors_count >= 0),
    date_add       timestamp DEFAULT now(),
    CONSTRAINT ux_fact_personnel_sessions_grain
        UNIQUE (time_id, person_id, event_type_id)
);

COMMENT ON TABLE public.fact_personnel_sessions IS 'Персонал: месяц x сотрудник x тип события';

-- 3.5. Работа персонала: бонусы -----------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.seq_fact_personnel_bonus;

CREATE TABLE IF NOT EXISTS public.fact_personnel_bonus (
    id                  bigint PRIMARY KEY DEFAULT nextval('public.seq_fact_personnel_bonus'),
    time_id             bigint NOT NULL REFERENCES public.time_metrics (id),
    person_id           bigint NOT NULL REFERENCES public.dim_personnel (id),
    bonus_records_count bigint NOT NULL CHECK (bonus_records_count >= 0),
    bonus_value         numeric(18,2) NOT NULL DEFAULT 0,
    date_add            timestamp DEFAULT now(),
    CONSTRAINT ux_fact_personnel_bonus_grain UNIQUE (time_id, person_id)
);

COMMENT ON TABLE public.fact_personnel_bonus IS 'Бонусы персонала: месяц x сотрудник';

-- 3.6. Остатки / движение товара ---------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.seq_fact_stock;

CREATE TABLE IF NOT EXISTS public.fact_stock (
    id                bigint PRIMARY KEY DEFAULT nextval('public.seq_fact_stock'),
    time_id           bigint NOT NULL REFERENCES public.time_metrics (id),
    product_id        bigint NOT NULL REFERENCES public.dim_products (id),
    storage_id        bigint NOT NULL REFERENCES public.dim_storages (id),
    operation_type_id bigint NOT NULL REFERENCES public.dim_operation_types (id),
    range_id          bigint NOT NULL REFERENCES public.dim_ranges (id),
    lines_count       bigint NOT NULL CHECK (lines_count >= 0),
    quantity          numeric(18,4) NOT NULL,
    amount            numeric(18,2) NOT NULL,
    turnover_amount   numeric(18,2) NOT NULL,
    date_add          timestamp DEFAULT now(),
    CONSTRAINT ux_fact_stock_grain
        UNIQUE (time_id, product_id, storage_id, operation_type_id, range_id)
);

COMMENT ON TABLE public.fact_stock IS 'Движение товара: месяц x товар x склад x тип операции x единица';

-- Индексы по времени и основным разрезам фактов.
CREATE INDEX IF NOT EXISTS idx_fact_purchases_time    ON public.fact_purchases (time_id);
CREATE INDEX IF NOT EXISTS idx_fact_purchases_product ON public.fact_purchases (product_id);
CREATE INDEX IF NOT EXISTS idx_fact_sales_time        ON public.fact_sales (time_id);
CREATE INDEX IF NOT EXISTS idx_fact_sales_product     ON public.fact_sales (product_id);
CREATE INDEX IF NOT EXISTS idx_fact_payments_time     ON public.fact_payments (time_id);
CREATE INDEX IF NOT EXISTS idx_fact_personnel_sessions_time   ON public.fact_personnel_sessions (time_id);
CREATE INDEX IF NOT EXISTS idx_fact_personnel_sessions_person ON public.fact_personnel_sessions (person_id);
CREATE INDEX IF NOT EXISTS idx_fact_personnel_bonus_time      ON public.fact_personnel_bonus (time_id);
CREATE INDEX IF NOT EXISTS idx_fact_personnel_bonus_person    ON public.fact_personnel_bonus (person_id);
CREATE INDEX IF NOT EXISTS idx_fact_stock_time        ON public.fact_stock (time_id);
CREATE INDEX IF NOT EXISTS idx_fact_stock_product     ON public.fact_stock (product_id);

-- Баланс по движениям: приход, расход и сальдо.
-- Во Front нет входящих остатков, поэтому это баланс только по движениям.
CREATE OR REPLACE VIEW public.v_stock_balance AS
SELECT
    f.time_id,
    f.product_id,
    f.storage_id,
    f.range_id,
    SUM(CASE WHEN o.factor = 1  THEN  f.quantity ELSE 0 END) AS incoming_quantity,
    SUM(CASE WHEN o.factor = -1 THEN -f.quantity ELSE 0 END) AS outgoing_quantity,
    SUM(f.quantity)                                          AS balance_quantity,
    SUM(CASE WHEN o.factor = 1  THEN  f.amount ELSE 0 END)   AS incoming_amount,
    SUM(CASE WHEN o.factor = -1 THEN -f.amount ELSE 0 END)   AS outgoing_amount,
    SUM(f.amount)                                            AS balance_amount
FROM public.fact_stock f
JOIN public.dim_operation_types o ON o.id = f.operation_type_id
GROUP BY f.time_id, f.product_id, f.storage_id, f.range_id;

COMMENT ON VIEW public.v_stock_balance IS
    'Баланс движения товара по месяцам (без входящих остатков источника)';

-- =============================================================================
-- 4. STAGING ДЛЯ ЗАГРУЗКИ
-- =============================================================================

CREATE TABLE IF NOT EXISTS stg.ranges (
    external_id bigint PRIMARY KEY,
    name        text,
    factor      double precision
);

CREATE TABLE IF NOT EXISTS stg.categories (
    external_id bigint PRIMARY KEY,
    name        text,
    parent_id   bigint
);

CREATE TABLE IF NOT EXISTS stg.vendors (
    external_id bigint PRIMARY KEY,
    name        text,
    parent_id   bigint,
    parent_name text
);

CREATE TABLE IF NOT EXISTS stg.personnel (
    external_id  bigint PRIMARY KEY,
    name         text,
    access_level smallint
);

CREATE TABLE IF NOT EXISTS stg.payment_types (
    external_id bigint PRIMARY KEY,
    name        text
);

CREATE TABLE IF NOT EXISTS stg.operation_types (
    external_id bigint PRIMARY KEY,
    name        text,
    factor      smallint
);

CREATE TABLE IF NOT EXISTS stg.event_types (
    name text PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS stg.products (
    external_id          bigint PRIMARY KEY,
    name                 text,
    category_external_id bigint,
    range_external_id    bigint
);

CREATE TABLE IF NOT EXISTS stg.storages (
    external_id bigint PRIMARY KEY,
    name        text
);

CREATE TABLE IF NOT EXISTS stg.purchases (
    time_code           integer NOT NULL,
    product_external_id bigint  NOT NULL,
    vendor_external_id  bigint  NOT NULL,
    storage_external_id bigint  NOT NULL,
    range_external_id   bigint  NOT NULL,
    lines_count         bigint  NOT NULL,
    quantity            numeric(18,4) NOT NULL,
    amount              numeric(18,2) NOT NULL,
    PRIMARY KEY (time_code, product_external_id, vendor_external_id,
                 storage_external_id, range_external_id)
);

CREATE TABLE IF NOT EXISTS stg.sales (
    time_code           integer NOT NULL,
    product_external_id bigint  NOT NULL,
    lines_count         bigint  NOT NULL,
    quantity            numeric(18,3) NOT NULL,
    revenue             numeric(18,2) NOT NULL,
    refund_amount       numeric(18,2) NOT NULL,
    net_revenue         numeric(18,2) NOT NULL,
    PRIMARY KEY (time_code, product_external_id)
);

CREATE TABLE IF NOT EXISTS stg.payments (
    time_code                integer NOT NULL,
    payment_type_external_id bigint  NOT NULL,
    receipts_count           bigint  NOT NULL,
    operations_count         bigint  NOT NULL,
    amount                   numeric(18,2) NOT NULL,
    PRIMARY KEY (time_code, payment_type_external_id)
);

CREATE TABLE IF NOT EXISTS stg.personnel_sessions (
    time_code          integer NOT NULL,
    person_external_id bigint  NOT NULL,
    event_type_name    text    NOT NULL,
    sessions_count     bigint  NOT NULL,
    errors_count       bigint  NOT NULL,
    PRIMARY KEY (time_code, person_external_id, event_type_name)
);

CREATE TABLE IF NOT EXISTS stg.personnel_bonus (
    time_code           integer NOT NULL,
    person_external_id  bigint  NOT NULL,
    bonus_records_count bigint  NOT NULL,
    bonus_value         numeric(18,2) NOT NULL,
    PRIMARY KEY (time_code, person_external_id)
);

CREATE TABLE IF NOT EXISTS stg.stock (
    time_code                  integer NOT NULL,
    product_external_id        bigint  NOT NULL,
    storage_external_id        bigint  NOT NULL,
    operation_type_external_id bigint  NOT NULL,
    range_external_id          bigint  NOT NULL,
    lines_count                bigint  NOT NULL,
    quantity                   numeric(18,4) NOT NULL,
    amount                     numeric(18,2) NOT NULL,
    turnover_amount            numeric(18,2) NOT NULL,
    PRIMARY KEY (time_code, product_external_id, storage_external_id,
                 operation_type_external_id, range_external_id)
);

COMMENT ON SCHEMA stg IS 'Слой загрузки CSV из MSSQL';

-- =============================================================================
-- 5. ПРОВЕРКА СТРУКТУРЫ
-- =============================================================================
SELECT table_schema, table_name, table_type
FROM information_schema.tables
WHERE table_schema IN ('public', 'stg')
ORDER BY table_schema, table_name;
