-- entechai.public.art_rules определение

-- Drop table

-- DROP TABLE entechai.public.art_rules;

CREATE TABLE entechai.public.art_rules (
	id serial DEFAULT nextval('art_rules_id_seq'::regclass) NOT NULL,
	user_created uuid,
	date_created timestamptz,
	user_updated uuid,
	date_updated timestamptz,
	glass_article varchar(255),
	glass_type varchar(255),
	type_of_glass varchar(255),
	type_of_processing varchar(255),
	surface varchar(255),
	note text,
	analog_list int4,
	CONSTRAINT art_rules_pkey PRIMARY KEY (id)
);


-- entechai.public.art_rules внешние включи

ALTER TABLE entechai.public.art_rules ADD CONSTRAINT art_rules_analog_list_foreign FOREIGN KEY (analog_list) REFERENCES entechai.public.art_rules(id);
ALTER TABLE entechai.public.art_rules ADD CONSTRAINT art_rules_user_created_foreign FOREIGN KEY (user_created) REFERENCES entechai.public.directus_users(id);
ALTER TABLE entechai.public.art_rules ADD CONSTRAINT art_rules_user_updated_foreign FOREIGN KEY (user_updated) REFERENCES entechai.public.directus_users(id);