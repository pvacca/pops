CREATE EXTENSION IF NOT EXISTS "uuid-ossp"
;
CREATE EXTENSION IF NOT EXISTS "pg_trgm"
;

CREATE TABLE IF NOT EXISTS series (
    series_id serial NOT NULL PRIMARY KEY
, series text NOT NULL UNIQUE
)
;
ALTER TABLE series OWNER TO pops
;

CREATE TABLE IF NOT EXISTS variations (
    variant_id serial NOT NULL PRIMARY KEY
, variant text NOT NULL UNIQUE
)
;
ALTER TABLE variations OWNER TO pops
;

CREATE TABLE IF NOT EXISTS exclusives (
    exclusive_id serial NOT NULL PRIMARY KEY
, exclusive text NOT NULL UNIQUE
)
;
ALTER TABLE exclusives OWNER TO pops
;

CREATE TABLE IF NOT EXISTS pops (
    pop_id uuid NOT NULL PRIMARY KEY DEFAULT uuid_generate_v1mc()
, series_id integer NOT NULL
, marquee text NOT NULL
, "number" text NOT NULL
, name text NOT NULL
, variant_id integer NOT NULL CONSTRAINT "fk_pops->variations" REFERENCES variations
, exclusive_id integer NOT NULL CONSTRAINT "fk_pops->exclusives" REFERENCES exclusives
, release_year char(7)
, edition_count integer
, notes text
, thumbnail_url text
, cover_photo_url text
, photo_bucket_url text
, tags jsonb

, CONSTRAINT uq_pops UNIQUE (marquee, "number", name, variant_id)
, name_glob text NOT NULL
)
;
ALTER TABLE pops OWNER TO pops
;

CREATE INDEX IF NOT EXISTS "ix_gist_pops_name_glob" on pops USING gist (name_glob gist_trgm_ops)
;

CREATE OR REPLACE FUNCTION pops_name_glob()
  RETURNS trigger AS $$
BEGIN
  NEW.name_glob := (SELECT series from series WHERE series_id = NEW.series_id)
    || ' ' || NEW.marquee || ' ' || NEW."number" || ' ' || NEW.name
    || ' ' || (SELECT variant from variations WHERE variant_id = NEW.variant_id)
    || ' ' || (SELECT exclusive from exclusives WHERE exclusive_id = NEW.exclusive_id)
  ;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql
;

CREATE TRIGGER "trig_pops_after_UPDATE.name_glob" 
  AFTER UPDATE on pops
  FOR EACH ROW
  WHEN (OLD.* IS DISTINCT FROM NEW.*)
  EXECUTE PROCEDURE pops_name_glob()
;

CREATE TRIGGER "trig_pops_after_INSERT.name_glob" 
  AFTER INSERT on pops
  FOR EACH ROW 
  EXECUTE PROCEDURE pops_name_glob()
;

CREATE TABLE IF NOT EXISTS pops_data (
    pop_id uuid NOT NULL CONSTRAINT "fk_pops_data->pops" REFERENCES pops
, desireability 
-- , ppg_retrieved timestamptz NOT NULL
, ppg_have integer
, ppg_want integer
, date_recorded date NOT NULL DEFAULT CURRENT_TIMESTAMP::date
)
;
ALTER TABLE pops_data OWNER TO pops
;

DROP SCHEMA IF EXISTS template CASCADE
;
CREATE SCHEMA IF NOT EXISTS template
;

CREATE TABLE IF NOT EXISTS template.vendors (
    vendor_id uuid NOT NULL PRIMARY KEY DEFAULT uuid_generate_v1mc()
, vendor text NOT NULL
, tags jsonb NOT NULL DEFAULT '{ "location": "Unknown" }'
, insert_tz timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
, is_active boolean NOT NULL DEFAULT true
)
;

CREATE TABLE IF NOT EXISTS template.inventory (
    inventory_id serial NOT NULL PRIMARY KEY
, pop_id uuid NOT NULL CONSTRAINT "fk_template.inventory->pops" REFERENCES pops
, grade NUMERIC (3, 1)
, notes text
, purchase_date date NOT NULL
, vendor_id uuid NOT NULL CONSTRAINT "fk_template.inventory->vendors" REFERENCES template.vendors
, seller text
, receive_date date
, item_price money NOT NULL
, shipping_price money NOT NULL DEFAULT 0.0
, tax money NOT NULL DEFAULT 0.0
, total_price money NOT NULL CONSTRAINT 
  "ck_template.inventory_price" CHECK (total_price = item_price + shipping_price + tax)
)
;

CREATE TABLE IF NOT EXISTS template.close_reasons (
    close_reason_id serial NOT NULL PRIMARY KEY
, close_reason text NOT NULL UNIQUE
)
;

CREATE TABLE IF NOT EXISTS template.closed_inventory (
    closed_inventory_id serial NOT NULL PRIMARY KEY
, pop_id uuid NOT NULL CONSTRAINT 
  "fk_template.closed_inventory->pops" REFERENCES pops
, grade NUMERIC (3, 1)
, notes text
, purchase_date date NOT NULL
, vendor_id uuid NOT NULL CONSTRAINT 
  "fk_template.closed_inventory->vendors" REFERENCES template.vendors
, seller text
, receive_date date
, item_price money NOT NULL
, shipping_price money NOT NULL DEFAULT 0.0
, tax money NOT NULL DEFAULT 0.0
, total_price money NOT NULL CONSTRAINT 
  "ck_template.closed_inventory_price" CHECK (total_price = item_price + shipping_price + tax)
, close_reason_id integer NOT NULL CONSTRAINT
  "fk_template.closed_inventory->close_reasons" REFERENCES template.close_reasons
, close_notes text
)
;

CREATE TABLE IF NOT EXISTS template.sales (
  sale_id serial NOT NULL PRIMARY KEY
, closed_inventory_id integer NOT NULL CONSTRAINT
  "fk_template.sales->closed_inventory" REFERENCES template.closed_inventory
, pop_id uuid NOT NULL CONSTRAINT 
  "fk_template.sales->pops" REFERENCES pops
, sale_price money NOT NULL
, sales_tax_collected money NOT NULL DEFAULT 0.0
, total_fees money NOT NULL DEFAULT 0.0
, sale_date date NOT NULL DEFAULT CURRENT_TIMESTAMP::date
, listing_tz timestamptz
, platform text
, buyer jsonb NOT NULL DEFAULT '{"name": "Unkown"}'
, notes text
, sale_tags jsonb NOT NULL DEFAULT '{}'
)
;
