-- entechai.public.qual_analize_prompts определение

-- Drop table

-- DROP TABLE entechai.public.qual_analize_prompts;

CREATE TABLE entechai.public.qual_analize_prompts (
	id serial DEFAULT nextval('qual_analize_prompts_id_seq'::regclass) NOT NULL,
	created_at timestamp,
	updated_at timestamp,
	created_by varchar,
	updated_by varchar,
	nc_order numeric,
	prompts text,
	promt_key text,
	prompt_name varchar(255),
	CONSTRAINT qual_analize_prompts_pkey PRIMARY KEY (id)
);
CREATE INDEX qual_analize_prompts_order_idx ON entechai.public.qual_analize_prompts (nc_order);