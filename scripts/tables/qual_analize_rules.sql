-- entechai.public.qual_analize_rules определение

-- Drop table

-- DROP TABLE entechai.public.qual_analize_rules;

CREATE TABLE entechai.public.qual_analize_rules (
	id serial DEFAULT nextval('analize_rules_id_seq'::regclass) NOT NULL,
	created_at timestamp,
	updated_at timestamp,
	created_by varchar,
	updated_by varchar,
	nc_order numeric,
	rules text NOT NULL,
	is_active bool DEFAULT true NOT NULL,
	CONSTRAINT analize_rules_pkey PRIMARY KEY (id)
);
CREATE INDEX analize_rules_order_idx ON entechai.public.qual_analize_rules (nc_order);