
do $$
begin
CREATE TABLE IF NOT EXISTS olap.fact_buys (
    external_id bigint PRIMARY KEY,   
    product_external_id bigint,      
    range_external_id bigint,      
    category_external_id bigint,               
    vendor_external_id bigint,               
    quantity numeric(18,4),
    amount numeric(18,2),
    period_id bigint,
    date_add timestamp NOT NULL DEFAULT now());

ALTER TABLE olap.fact_buys ADD CONSTRAINT fk_fact_buys_product
    FOREIGN KEY (product_external_id) REFERENCES olap.dim_products (external_id);

ALTER TABLE olap.fact_buys ADD CONSTRAINT fk_fact_buys_range
    FOREIGN KEY (range_external_id) REFERENCES olap.dim_ranges (external_id);

ALTER TABLE olap.fact_buys ADD CONSTRAINT fk_fact_buys_category
    FOREIGN KEY (category_external_id) REFERENCES olap.dim_categories (external_id);

ALTER TABLE olap.fact_buys ADD CONSTRAINT fk_fact_buys_vendor
    FOREIGN KEY (vendor_external_id) REFERENCES olap.dim_vendors (external_id);

ALTER TABLE olap.fact_buys ADD CONSTRAINT fk_fact_buys_period
    FOREIGN KEY (period_id) REFERENCES olap.dim_time (id);
end $$;