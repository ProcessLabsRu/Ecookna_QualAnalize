-- entechai.public.qual_analize_pos_issues определение

-- Drop table

-- DROP TABLE entechai.public.qual_analize_pos_issues;

CREATE TABLE entechai.public.qual_analize_pos_issues (
	id bigserial DEFAULT nextval('qual_analize_pos_issues_id_seq'::regclass) NOT NULL,
	pos_id int8 NOT NULL,
	issue_code text NOT NULL,
	severity text DEFAULT 'error'::text NOT NULL,
	message text NOT NULL,
	context jsonb,
	created_at timestamptz DEFAULT now() NOT NULL,
	CONSTRAINT qual_analize_pos_issues_pkey PRIMARY KEY (id)
);
CREATE INDEX idx_qual_issues_pos_id ON entechai.public.qual_analize_pos_issues (pos_id);


-- entechai.public.qual_analize_pos_issues внешние включи

ALTER TABLE entechai.public.qual_analize_pos_issues ADD CONSTRAINT qual_analize_pos_issues_pos_id_fkey FOREIGN KEY (pos_id) REFERENCES entechai.public.qual_analize_pos(id) ON DELETE CASCADE;