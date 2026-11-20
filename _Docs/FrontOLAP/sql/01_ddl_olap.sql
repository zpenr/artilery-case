-- =============================================================================
-- 01_ddl_olap.sql
-- DDL OLAP-базы db2026 (PostgreSQL 14+).
--
-- Структура следует шаблону преподавателя:
--   * суррогатный ключ id bigint DEFAULT nextval('seq_dim_...');
--   * внешний код источника external_id;
--   * человекочитаемое имя name;
--   * дата загрузки date_add timestamp DEFAULT now().
--
-- Схемы:
--   public - измерения и факты OLAP;
--   stg    - слой загрузки (CSV из MSSQL).
--
-- Направления анализа:
--   1. закупки продукции          -> public.fact_purchases;
--   2. продажи товара             -> public.fact_sales + public.fact_payments;
--   3. работа персонала           -> public.fact_personnel;
--   4. остатки / движение товара  -> public.fact_stock + public.v_stock_balance.
--
-- Порядок запуска:
--   1. 00_create_database.sql;
--   2. этот файл, подключившись к db2026;
--   3. 04_dim_time.sql;
--   4. выгрузка MSSQL -> CSV -> stg.*;
--   5. 03_load_olap.sql.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS stg;

-- =============================================================================
-- 1. ИЗМЕРЕНИЯ
-- =============================================================================

-- 1.1. Единицы измерения / диапазоны (шаблон преподавателя) -------------------
CREATE SEQUENCE IF NOT EXISTS public.seq_dim_ranges;

CREATE TABLE IF NOT EXISTS public.dim_ranges (
    id          bigint PRIMARY KEY DEFAULT nextval('public.seq_dim_ranges'),
    external_id bigint UNIQUE,
    name        text,
    factor      double precision,
    date_add    timestamp DEFAULT now()
);

COMMENT ON TABLE  public.dim_ranges IS 'Единицы измерения / диапазоны (источник: dbo.[size])';
COMMENT ON COLUMN public.dim_ranges.id          IS 'Внутренний суррогатный код';
COMMENT ON COLUMN public.dim_ranges.external_id IS 'Код единицы измерения в Front (size.ID)';
COMMENT ON COLUMN public.dim_ranges.name        IS 'Название единицы измерения (size.sizeid)';
COMMENT ON COLUMN public.dim_ranges.factor      IS 'Коэффициент пересчёта (size.portionrate)';
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

COMMENT ON TABLE  public.dim_categories IS 'Категории товаров (источник: dbo.category)';
COMMENT ON COLUMN public.dim_categories.id          IS 'Внутренний суррогатный код';
COMMENT ON COLUMN public.dim_categories.external_id IS 'Код категории в Front (category.id)';
COMMENT ON COLUMN public.dim_categories.name        IS 'Название категории';
COMMENT ON COLUMN public.dim_categories.parent_id   IS 'Код родительской категории в Front (category.ParentID)';
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

COMMENT ON TABLE  public.dim_vendors IS 'Поставщики (источник: dbo.vendors + dbo.vendorgroup)';
COMMENT ON COLUMN public.dim_vendors.id          IS 'Внутренний суррогатный код';
COMMENT ON COLUMN public.dim_vendors.external_id IS 'Код поставщика в Front (vendors.id)';
COMMENT ON COLUMN public.dim_vendors.name        IS 'Название поставщика (vendors.clientid)';
COMMENT ON COLUMN public.dim_vendors.parent_id   IS 'Код группы поставщиков (vendors.clientgroup)';
COMMENT ON COLUMN public.dim_vendors.parent_name IS 'Название группы поставщиков';
COMMENT ON COLUMN public.dim_vendors.date_add    IS 'Дата добавления записи';

-- 1.4. Сотрудники -------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.seq_dim_personnel;

CREATE TABLE IF NOT EXISTS public.dim_personnel (
    id             bigint PRIMARY KEY DEFAULT nextval('public.seq_dim_personnel'),
    external_id    bigint UNIQUE,
    name           text,
    last_name      text,
    first_name     text,
    middle_name    text,
    access_level   smallint,
    has_pos_access boolean NOT NULL DEFAULT false,
    is_deleted     boolean NOT NULL DEFAULT false,
    date_add       timestamp DEFAULT now()
);

COMMENT ON TABLE  public.dim_personnel IS 'Сотрудники (источник: dbo.personnel)';
COMMENT ON COLUMN public.dim_personnel.id             IS 'Внутренний суррогатный код';
COMMENT ON COLUMN public.dim_personnel.external_id    IS 'Код сотрудника в Front (personnel.personid)';
COMMENT ON COLUMN public.dim_personnel.name           IS 'ФИО одной строкой';
COMMENT ON COLUMN public.dim_personnel.last_name      IS 'Фамилия';
COMMENT ON COLUMN public.dim_personnel.first_name     IS 'Имя';
COMMENT ON COLUMN public.dim_personnel.middle_name    IS 'Отчество';
COMMENT ON COLUMN public.dim_personnel.access_level   IS 'Уровень доступа';
COMMENT ON COLUMN public.dim_personnel.has_pos_access IS 'Доступ к POS';
COMMENT ON COLUMN public.dim_personnel.is_deleted     IS 'Признак удаления карточки';
COMMENT ON COLUMN public.dim_personnel.date_add       IS 'Дата добавления записи';

-- 1.5. Способы оплаты ---------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.seq_dim_payment_types;

CREATE TABLE IF NOT EXISTS public.dim_payment_types (
    id          bigint PRIMARY KEY DEFAULT nextval('public.seq_dim_payment_types'),
    external_id bigint UNIQUE,
    name        text,
    date_add    timestamp DEFAULT now()
);

COMMENT ON TABLE  public.dim_payment_types IS 'Способы оплаты (transtype с transgroupid = 2)';
COMMENT ON COLUMN public.dim_payment_types.id          IS 'Внутренний суррогатный код';
COMMENT ON COLUMN public.dim_payment_types.external_id IS 'Код способа оплаты в Front (transtype.transtypeid)';
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

COMMENT ON TABLE  public.dim_operation_types IS 'Типы складских операций (bm_StorageOperationsType)';
COMMENT ON COLUMN public.dim_operation_types.id          IS 'Внутренний суррогатный код';
COMMENT ON COLUMN public.dim_operation_types.external_id IS 'Код типа операции в Front';
COMMENT ON COLUMN public.dim_operation_types.name        IS 'Название типа операции';
COMMENT ON COLUMN public.dim_operation_types.factor      IS 'Знак операции: +1 приход, -1 расход';
COMMENT ON COLUMN public.dim_operation_types.date_add    IS 'Дата добавления записи';

-- 1.7. Типы событий журнала сессий --------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.seq_dim_event_types;

CREATE TABLE IF NOT EXISTS public.dim_event_types (
    id          bigint PRIMARY KEY DEFAULT nextval('public.seq_dim_event_types'),
    external_id bigint UNIQUE,
    name        text UNIQUE,
    date_add    timestamp DEFAULT now()
);

COMMENT ON TABLE  public.dim_event_types IS 'Типы событий (bm_JournalSessions.Type)';
COMMENT ON COLUMN public.dim_event_types.id          IS 'Внутренний суррогатный код';
COMMENT ON COLUMN public.dim_event_types.external_id IS 'Служебный код (0 — бонусные начисления)';
COMMENT ON COLUMN public.dim_event_types.name        IS 'Название типа события';
COMMENT ON COLUMN public.dim_event_types.date_add    IS 'Дата добавления записи';

-- 1.8. Время ------------------------------------------------------------------
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

-- 1.9. Товары ----------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.seq_dim_products;

CREATE TABLE IF NOT EXISTS public.dim_products (
    id              bigint PRIMARY KEY DEFAULT nextval('public.seq_dim_products'),
    external_id     bigint UNIQUE,
    external_code   text,
    name            text,
    category_id     bigint NOT NULL REFERENCES public.dim_categories (id),
    range_id        bigint NOT NULL REFERENCES public.dim_ranges (id),
    cost            numeric(18,2),
    is_active       boolean NOT NULL DEFAULT true,
    date_add        timestamp DEFAULT now()
);

COMMENT ON TABLE  public.dim_products IS 'Товары / ингредиенты (источник: dbo.product)';
COMMENT ON COLUMN public.dim_products.id            IS 'Внутренний суррогатный код';
COMMENT ON COLUMN public.dim_products.external_id   IS 'Код товара в Front (product.id)';
COMMENT ON COLUMN public.dim_products.external_code IS 'Внешний код / штрихкод (product.productid)';
COMMENT ON COLUMN public.dim_products.name          IS 'Наименование товара';
COMMENT ON COLUMN public.dim_products.category_id   IS 'Ссылка на dim_categories.id';
COMMENT ON COLUMN public.dim_products.range_id      IS 'Ссылка на dim_ranges.id';
COMMENT ON COLUMN public.dim_products.cost          IS 'Себестоимость';
COMMENT ON COLUMN public.dim_products.is_active     IS 'Признак использования';
COMMENT ON COLUMN public.dim_products.date_add      IS 'Дата добавления записи';

-- 1.10. Склады ----------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.seq_dim_storages;

CREATE TABLE IF NOT EXISTS public.dim_storages (
    id                      bigint PRIMARY KEY DEFAULT nextval('public.seq_dim_storages'),
    external_id             bigint UNIQUE,
    name                    text,
    company_external_id     bigint,
    company_name            text,
    responsible_person_id   bigint NOT NULL REFERENCES public.dim_personnel (id),
    date_add                timestamp DEFAULT now()
);

COMMENT ON TABLE  public.dim_storages IS 'Склады и организации (источник: dbo.storages + dbo.bm_Companies)';
COMMENT ON COLUMN public.dim_storages.id                    IS 'Внутренний суррогатный код';
COMMENT ON COLUMN public.dim_storages.external_id           IS 'Код склада в Front (storages.id)';
COMMENT ON COLUMN public.dim_storages.name                  IS 'Название склада';
COMMENT ON COLUMN public.dim_storages.company_external_id   IS 'Код организации в Front';
COMMENT ON COLUMN public.dim_storages.company_name          IS 'Название организации';
COMMENT ON COLUMN public.dim_storages.responsible_person_id IS 'Ссылка на dim_personnel.id';
COMMENT ON COLUMN public.dim_storages.date_add              IS 'Дата добавления записи';

-- =============================================================================
-- 2. ФАКТЫ
-- =============================================================================

-- 2.1. Закупки продукции ------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.seq_fact_purchases;

CREATE TABLE IF NOT EXISTS public.fact_purchases (
    id           bigint PRIMARY KEY DEFAULT nextval('public.seq_fact_purchases'),
    time_id      bigint NOT NULL REFERENCES public.dim_time (id),
    product_id   bigint NOT NULL REFERENCES public.dim_products (id),
    vendor_id    bigint NOT NULL REFERENCES public.dim_vendors (id),
    category_id  bigint NOT NULL REFERENCES public.dim_categories (id),
    storage_id   bigint NOT NULL REFERENCES public.dim_storages (id),
    range_id     bigint NOT NULL REFERENCES public.dim_ranges (id),
    lines_count  bigint NOT NULL CHECK (lines_count >= 0),
    quantity     numeric(18,4) NOT NULL,
    amount       numeric(18,2) NOT NULL,
    avg_price    numeric(18,2),
    date_add     timestamp DEFAULT now(),
    CONSTRAINT ux_fact_purchases_grain
        UNIQUE (time_id, product_id, vendor_id, storage_id, range_id)
);

COMMENT ON TABLE public.fact_purchases IS 'Закупки: месяц x товар x поставщик x склад x единица измерения';
COMMENT ON COLUMN public.fact_purchases.lines_count IS 'Количество строк закупки';
COMMENT ON COLUMN public.fact_purchases.quantity    IS 'Количество';
COMMENT ON COLUMN public.fact_purchases.amount      IS 'Сумма закупки, руб.';
COMMENT ON COLUMN public.fact_purchases.avg_price   IS 'Средняя цена закупки, руб.';

CREATE INDEX IF NOT EXISTS idx_fact_purchases_time ON public.fact_purchases (time_id);

-- 2.2. Продажи товара ---------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.seq_fact_sales;

CREATE TABLE IF NOT EXISTS public.fact_sales (
    id             bigint PRIMARY KEY DEFAULT nextval('public.seq_fact_sales'),
    time_id        bigint NOT NULL REFERENCES public.dim_time (id),
    product_id     bigint NOT NULL REFERENCES public.dim_products (id),
    category_id    bigint NOT NULL REFERENCES public.dim_categories (id),
    receipts_count bigint NOT NULL CHECK (receipts_count >= 0),
    lines_count    bigint NOT NULL CHECK (lines_count >= 0),
    quantity       numeric(18,3) NOT NULL,
    revenue        numeric(18,2) NOT NULL,
    refund_amount  numeric(18,2) NOT NULL,
    net_revenue    numeric(18,2) NOT NULL,
    date_add       timestamp DEFAULT now(),
    CONSTRAINT ux_fact_sales_grain UNIQUE (time_id, product_id)
);

COMMENT ON TABLE public.fact_sales IS 'Продажи: месяц x товар';
COMMENT ON COLUMN public.fact_sales.receipts_count IS 'Количество чеков с товаром (не аддитивно по товарам)';
COMMENT ON COLUMN public.fact_sales.lines_count    IS 'Количество строк продаж';
COMMENT ON COLUMN public.fact_sales.quantity       IS 'Количество (без возвратов)';
COMMENT ON COLUMN public.fact_sales.revenue        IS 'Выручка без возвратов, руб.';
COMMENT ON COLUMN public.fact_sales.refund_amount  IS 'Сумма возвратов, руб.';
COMMENT ON COLUMN public.fact_sales.net_revenue    IS 'Чистая выручка, руб.';

CREATE INDEX IF NOT EXISTS idx_fact_sales_time ON public.fact_sales (time_id);

-- 2.3. Оплаты -----------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.seq_fact_payments;

CREATE TABLE IF NOT EXISTS public.fact_payments (
    id                bigint PRIMARY KEY DEFAULT nextval('public.seq_fact_payments'),
    time_id           bigint NOT NULL REFERENCES public.dim_time (id),
    payment_type_id   bigint NOT NULL REFERENCES public.dim_payment_types (id),
    operations_count  bigint NOT NULL CHECK (operations_count >= 0),
    amount            numeric(18,2) NOT NULL,
    date_add          timestamp DEFAULT now(),
    CONSTRAINT ux_fact_payments_grain UNIQUE (time_id, payment_type_id)
);

COMMENT ON TABLE public.fact_payments IS 'Оплаты: месяц x способ оплаты';
COMMENT ON COLUMN public.fact_payments.operations_count IS 'Количество операций оплаты';
COMMENT ON COLUMN public.fact_payments.amount           IS 'Сумма оплат, руб.';

CREATE INDEX IF NOT EXISTS idx_fact_payments_time ON public.fact_payments (time_id);

-- 2.4. Работа персонала -------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.seq_fact_personnel;

CREATE TABLE IF NOT EXISTS public.fact_personnel (
    id                  bigint PRIMARY KEY DEFAULT nextval('public.seq_fact_personnel'),
    time_id             bigint NOT NULL REFERENCES public.dim_time (id),
    person_id           bigint NOT NULL REFERENCES public.dim_personnel (id),
    event_type_id       bigint NOT NULL REFERENCES public.dim_event_types (id),
    sessions_count      bigint NOT NULL DEFAULT 0 CHECK (sessions_count >= 0),
    errors_count        bigint NOT NULL DEFAULT 0 CHECK (errors_count >= 0),
    bonus_records_count bigint NOT NULL DEFAULT 0 CHECK (bonus_records_count >= 0),
    bonus_value         numeric(18,2) NOT NULL DEFAULT 0,
    date_add            timestamp DEFAULT now(),
    CONSTRAINT ux_fact_personnel_grain UNIQUE (time_id, person_id, event_type_id)
);

COMMENT ON TABLE public.fact_personnel IS 'Активность персонала: месяц x сотрудник x тип события';
COMMENT ON COLUMN public.fact_personnel.sessions_count      IS 'Количество событий/сессий';
COMMENT ON COLUMN public.fact_personnel.errors_count        IS 'Количество ошибок';
COMMENT ON COLUMN public.fact_personnel.bonus_records_count IS 'Количество бонусных записей';
COMMENT ON COLUMN public.fact_personnel.bonus_value         IS 'Суммарное значение бонусов';

CREATE INDEX IF NOT EXISTS idx_fact_personnel_time ON public.fact_personnel (time_id);
CREATE INDEX IF NOT EXISTS idx_fact_personnel_person ON public.fact_personnel (person_id);

-- 2.5. Движение товара / остатки ---------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.seq_fact_stock;

CREATE TABLE IF NOT EXISTS public.fact_stock (
    id                  bigint PRIMARY KEY DEFAULT nextval('public.seq_fact_stock'),
    time_id             bigint NOT NULL REFERENCES public.dim_time (id),
    product_id          bigint NOT NULL REFERENCES public.dim_products (id),
    storage_id          bigint NOT NULL REFERENCES public.dim_storages (id),
    operation_type_id   bigint NOT NULL REFERENCES public.dim_operation_types (id),
    range_id            bigint NOT NULL REFERENCES public.dim_ranges (id),
    lines_count         bigint NOT NULL CHECK (lines_count >= 0),
    quantity            numeric(18,4) NOT NULL,
    amount              numeric(18,2) NOT NULL,
    turnover_amount     numeric(18,2) NOT NULL,
    date_add            timestamp DEFAULT now(),
    CONSTRAINT ux_fact_stock_grain
        UNIQUE (time_id, product_id, storage_id, operation_type_id, range_id)
);

COMMENT ON TABLE public.fact_stock IS 'Движение товара: месяц x товар x склад x тип операции x единица';
COMMENT ON COLUMN public.fact_stock.lines_count     IS 'Количество строк операций';
COMMENT ON COLUMN public.fact_stock.quantity        IS 'Количество со знаком источника (приход +, расход -)';
COMMENT ON COLUMN public.fact_stock.amount          IS 'Сумма со знаком источника';
COMMENT ON COLUMN public.fact_stock.turnover_amount IS 'Оборот по модулю суммы, руб.';

CREATE INDEX IF NOT EXISTS idx_fact_stock_time ON public.fact_stock (time_id);

-- =============================================================================
-- 3. ПРЕДСТАВЛЕНИЕ БАЛАНСА
-- =============================================================================
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
-- 4. STAGING (ЗАГРУЗКА CSV ИЗ MSSQL)
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
    external_id    bigint PRIMARY KEY,
    name           text,
    last_name      text,
    first_name     text,
    middle_name    text,
    access_level   smallint,
    has_pos_access boolean,
    is_deleted     boolean
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
    external_code        text,
    name                 text,
    category_external_id bigint,
    range_external_id    bigint,
    cost                 numeric(18,2),
    is_active            boolean
);

CREATE TABLE IF NOT EXISTS stg.storages (
    external_id                    bigint PRIMARY KEY,
    name                           text,
    company_external_id            bigint,
    company_name                   text,
    responsible_person_external_id bigint
);

CREATE TABLE IF NOT EXISTS stg.purchases (
    time_code           integer NOT NULL,
    product_external_id bigint  NOT NULL,
    vendor_external_id  bigint  NOT NULL,
    category_external_id bigint NOT NULL,
    storage_external_id bigint  NOT NULL,
    range_external_id   bigint  NOT NULL,
    lines_count         bigint  NOT NULL,
    quantity            numeric(18,4) NOT NULL,
    amount              numeric(18,2) NOT NULL,
    avg_price           numeric(18,2),
    PRIMARY KEY (time_code, product_external_id, vendor_external_id,
                 storage_external_id, range_external_id)
);

CREATE TABLE IF NOT EXISTS stg.sales (
    time_code           integer NOT NULL,
    product_external_id bigint  NOT NULL,
    category_external_id bigint NOT NULL,
    receipts_count      bigint  NOT NULL,
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
    operations_count         bigint  NOT NULL,
    amount                   numeric(18,2) NOT NULL,
    PRIMARY KEY (time_code, payment_type_external_id)
);

CREATE TABLE IF NOT EXISTS stg.personnel_sessions (
    time_code           integer NOT NULL,
    person_external_id  bigint  NOT NULL,
    event_type_name     text    NOT NULL,
    sessions_count      bigint  NOT NULL,
    errors_count        bigint  NOT NULL,
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
    time_code                   integer NOT NULL,
    product_external_id         bigint  NOT NULL,
    storage_external_id         bigint  NOT NULL,
    operation_type_external_id  bigint  NOT NULL,
    range_external_id           bigint  NOT NULL,
    lines_count                 bigint  NOT NULL,
    quantity                    numeric(18,4) NOT NULL,
    amount                      numeric(18,2) NOT NULL,
    turnover_amount             numeric(18,2) NOT NULL,
    PRIMARY KEY (time_code, product_external_id, storage_external_id,
                 operation_type_external_id, range_external_id)
);

COMMENT ON SCHEMA stg IS 'Слой загрузки: результаты MSSQL-запросов в CSV';

-- =============================================================================
-- 5. ПРОВЕРКА СТРУКТУРЫ
-- =============================================================================
SELECT table_schema, table_name, table_type
FROM information_schema.tables
WHERE table_schema IN ('public', 'stg')
ORDER BY table_schema, table_name;
