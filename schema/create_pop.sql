CREATE EXTENSION "uuid-ossp"
;

CREATE TABLE series (
    series_id serial NOT NULL PRIMARY KEY
, series text NOT NULL UNIQUE
)
;

CREATE TABLE variations (
    variant_id serial NOT NULL PRIMARY KEY
, variant text NOT NULL UNIQUE
)
;

CREATE TYPE exclusives (
    exclusive_id serial NOT NULL PRIMARY KEY
, exclusive text NOT NULL UNIQUE
)
;

CREATE TABLE pops (
    pop_id uuid NOT NULL PRIMARY KEY DEFAULT uuid_generate_v1mc()
, series_id integer NOT NULL
, marquee text NOT NULL
, "number" text NOT NULL
, name text NOT NULL
, variant_id integer NOT NULL FOREIGN KEY REFERENCES variations
, exclusive_id integer NOT NULL FOREIGN KEY REFERENCES exclusives
, release_year char(7)
, edition_count integer
, notes text
, tags jsonb

, CONSTRAINT uq_pops UNIQUE (marquee, "number", name, variant_id)
)
;

CREATE TABLE pops_data (
    pop_id uuid NOT NULL FOREIGN KEY REFERENCES pops
-- , ppg_retrieved timestamptz NOT NULL
, ppg_have integer
, ppg_want integer
)
;

CREATE SCHEMA template ;

CREATE TABLE template.vendors (
    vendor_id uuid NOT NULL PRIMARY KEY DEFAULT uuid_generate_v1mc()
, vendor text NOT NULL
, location_tags jsonb NOT NULL DEFAULT '{ "location": "Unknown" }'
, insert_tz timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
)
;

CREATE TABLE template.inventory (
    seq_id serial NOT NULL PRIMARY KEY
, pop_id uuid NOT NULL
, purchase_date date NOT NULL
, receive_date date
, item_price money NOT NULL
, shipping_price money NOT NULL DEFAULT 0.0
, tax money NOT NULL DEFAULT 0.0
, total_price money NOT NULL
)
;
