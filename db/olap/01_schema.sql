-- OLAP: структура ресурсов

DO $$
BEGIN
    CREATE SCHEMA IF NOT EXISTS olap;

    -- единицы измерения
    CREATE SEQUENCE IF NOT EXISTS olap.seq_dim_ranges;
    CREATE TABLE IF NOT EXISTS olap.dim_ranges (
        id bigint NOT NULL DEFAULT nextval('olap.seq_dim_ranges') PRIMARY KEY,
        external_id bigint NOT NULL UNIQUE,
        group_external_id bigint,
        short_name text,
        name text NOT NULL,
        date_add timestamp NOT NULL DEFAULT now()
    );
    ALTER SEQUENCE olap.seq_dim_ranges OWNED BY olap.dim_ranges.id;

    COMMENT ON TABLE olap.dim_ranges IS 'Единицы измерения';
    COMMENT ON COLUMN olap.dim_ranges.id IS 'Внутренний код';
    COMMENT ON COLUMN olap.dim_ranges.external_id IS 'Код единицы в исходной базе Front';
    COMMENT ON COLUMN olap.dim_ranges.group_external_id IS 'Код группы единиц в исходной базе';
    COMMENT ON COLUMN olap.dim_ranges.short_name IS 'Краткое обозначение';
    COMMENT ON COLUMN olap.dim_ranges.name IS 'Наименование единицы измерения';
    COMMENT ON COLUMN olap.dim_ranges.date_add IS 'Дата добавления записи';

    -- категории товаров
    CREATE SEQUENCE IF NOT EXISTS olap.seq_dim_categories;
    CREATE TABLE IF NOT EXISTS olap.dim_categories (
        id bigint NOT NULL DEFAULT nextval('olap.seq_dim_categories') PRIMARY KEY,
        external_id bigint NOT NULL UNIQUE,
        name text NOT NULL,
        parent_id bigint,
        date_add timestamp NOT NULL DEFAULT now()
    );
    ALTER SEQUENCE olap.seq_dim_categories OWNED BY olap.dim_categories.id;

    COMMENT ON TABLE olap.dim_categories IS 'Категории товаров';
    COMMENT ON COLUMN olap.dim_categories.id IS 'Внутренний код';
    COMMENT ON COLUMN olap.dim_categories.external_id IS 'Код категории в исходной базе Front';
    COMMENT ON COLUMN olap.dim_categories.name IS 'Наименование категории';
    COMMENT ON COLUMN olap.dim_categories.parent_id IS 'Внутренний код родительской категории';
    COMMENT ON COLUMN olap.dim_categories.date_add IS 'Дата добавления записи';

    -- товары
    CREATE SEQUENCE IF NOT EXISTS olap.seq_dim_products;
    CREATE TABLE IF NOT EXISTS olap.dim_products (
        id bigint NOT NULL DEFAULT nextval('olap.seq_dim_products') PRIMARY KEY,
        external_id bigint NOT NULL UNIQUE,
        code text,
        name text NOT NULL,
        date_add timestamp NOT NULL DEFAULT now()
    );
    ALTER SEQUENCE olap.seq_dim_products OWNED BY olap.dim_products.id;

    COMMENT ON TABLE olap.dim_products IS 'Товары';
    COMMENT ON COLUMN olap.dim_products.id IS 'Внутренний код';
    COMMENT ON COLUMN olap.dim_products.external_id IS 'Код товара в исходной базе Front';
    COMMENT ON COLUMN olap.dim_products.code IS 'Внешний код товара (productid)';
    COMMENT ON COLUMN olap.dim_products.name IS 'Наименование товара';
    COMMENT ON COLUMN olap.dim_products.date_add IS 'Дата добавления записи';

    -- поставщики
    CREATE SEQUENCE IF NOT EXISTS olap.seq_dim_vendors;
    CREATE TABLE IF NOT EXISTS olap.dim_vendors (
        id bigint NOT NULL DEFAULT nextval('olap.seq_dim_vendors') PRIMARY KEY,
        external_id bigint NOT NULL UNIQUE,
        name text NOT NULL,
        group_external_id bigint,
        group_name text,
        date_add timestamp NOT NULL DEFAULT now()
    );
    ALTER SEQUENCE olap.seq_dim_vendors OWNED BY olap.dim_vendors.id;

    COMMENT ON TABLE olap.dim_vendors IS 'Поставщики';
    COMMENT ON COLUMN olap.dim_vendors.id IS 'Внутренний код';
    COMMENT ON COLUMN olap.dim_vendors.external_id IS 'Код поставщика в исходной базе Front';
    COMMENT ON COLUMN olap.dim_vendors.name IS 'Наименование поставщика';
    COMMENT ON COLUMN olap.dim_vendors.group_external_id IS 'Код группы поставщиков в исходной базе';
    COMMENT ON COLUMN olap.dim_vendors.group_name IS 'Наименование группы поставщиков';
    COMMENT ON COLUMN olap.dim_vendors.date_add IS 'Дата добавления записи';

    -- виды оплаты
    CREATE SEQUENCE IF NOT EXISTS olap.seq_dim_payment_types;
    CREATE TABLE IF NOT EXISTS olap.dim_payment_types (
        id bigint NOT NULL DEFAULT nextval('olap.seq_dim_payment_types') PRIMARY KEY,
        external_id bigint NOT NULL UNIQUE,
        name text NOT NULL,
        date_add timestamp NOT NULL DEFAULT now()
    );
    ALTER SEQUENCE olap.seq_dim_payment_types OWNED BY olap.dim_payment_types.id;

    COMMENT ON TABLE olap.dim_payment_types IS 'Виды оплаты';
    COMMENT ON COLUMN olap.dim_payment_types.id IS 'Внутренний код';
    COMMENT ON COLUMN olap.dim_payment_types.external_id IS 'Код вида оплаты в исходной базе Front';
    COMMENT ON COLUMN olap.dim_payment_types.name IS 'Наименование вида оплаты';
    COMMENT ON COLUMN olap.dim_payment_types.date_add IS 'Дата добавления записи';

    -- сотрудники
    CREATE SEQUENCE IF NOT EXISTS olap.seq_dim_personnel;
    CREATE TABLE IF NOT EXISTS olap.dim_personnel (
        id bigint NOT NULL DEFAULT nextval('olap.seq_dim_personnel') PRIMARY KEY,
        external_id bigint NOT NULL UNIQUE,
        full_name text NOT NULL,
        date_add timestamp NOT NULL DEFAULT now()
    );
    ALTER SEQUENCE olap.seq_dim_personnel OWNED BY olap.dim_personnel.id;

    COMMENT ON TABLE olap.dim_personnel IS 'Сотрудники';
    COMMENT ON COLUMN olap.dim_personnel.id IS 'Внутренний код';
    COMMENT ON COLUMN olap.dim_personnel.external_id IS 'Код сотрудника в исходной базе Front';
    COMMENT ON COLUMN olap.dim_personnel.full_name IS 'Фамилия, имя и отчество сотрудника';
    COMMENT ON COLUMN olap.dim_personnel.date_add IS 'Дата добавления записи';

    -- склады
    CREATE SEQUENCE IF NOT EXISTS olap.seq_dim_storages;
    CREATE TABLE IF NOT EXISTS olap.dim_storages (
        id bigint NOT NULL DEFAULT nextval('olap.seq_dim_storages') PRIMARY KEY,
        external_id bigint NOT NULL UNIQUE,
        name text NOT NULL,
        date_add timestamp NOT NULL DEFAULT now()
    );
    ALTER SEQUENCE olap.seq_dim_storages OWNED BY olap.dim_storages.id;

    COMMENT ON TABLE olap.dim_storages IS 'Склады';
    COMMENT ON COLUMN olap.dim_storages.id IS 'Внутренний код';
    COMMENT ON COLUMN olap.dim_storages.external_id IS 'Код склада в исходной базе Front';
    COMMENT ON COLUMN olap.dim_storages.name IS 'Наименование склада';
    COMMENT ON COLUMN olap.dim_storages.date_add IS 'Дата добавления записи';

    -- причины списания
    CREATE SEQUENCE IF NOT EXISTS olap.seq_dim_reasons;
    CREATE TABLE IF NOT EXISTS olap.dim_reasons (
        id bigint NOT NULL DEFAULT nextval('olap.seq_dim_reasons') PRIMARY KEY,
        external_id bigint NOT NULL UNIQUE,
        name text NOT NULL,
        parent_id bigint,
        parent_name text,
        date_add timestamp NOT NULL DEFAULT now()
    );
    ALTER SEQUENCE olap.seq_dim_reasons OWNED BY olap.dim_reasons.id;

    COMMENT ON TABLE olap.dim_reasons IS 'Причины списания';
    COMMENT ON COLUMN olap.dim_reasons.id IS 'Внутренний код';
    COMMENT ON COLUMN olap.dim_reasons.external_id IS 'Код причины в исходной базе Front';
    COMMENT ON COLUMN olap.dim_reasons.name IS 'Наименование причины';
    COMMENT ON COLUMN olap.dim_reasons.parent_id IS 'Внутренний код родительской причины';
    COMMENT ON COLUMN olap.dim_reasons.parent_name IS 'Название родительской группы';
    COMMENT ON COLUMN olap.dim_reasons.date_add IS 'Дата добавления записи';
END $$;
