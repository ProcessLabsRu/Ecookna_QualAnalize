-- entechai.public.size_control определение

-- Drop table

-- DROP TABLE entechai.public.size_control;

CREATE TABLE entechai.public.size_control (
	id serial DEFAULT nextval('size_control_id_seq'::regclass) NOT NULL,
	date_created timestamptz,
	dim1 int8,
	dim2 int8 NOT NULL,
	marking varchar(255),
	formula_1 text,
	formula_2 text,
	formula_1_1k text,
	formula_1_2k text,
	formula_2_1k text,
	formula_2_2k text,
	formula_1_3k varchar(255),
	formula_2_3k varchar(255),
	CONSTRAINT size_control_pkey PRIMARY KEY (id)
);
CREATE INDEX idx_size_control_dim_pair ON entechai.public.size_control ();