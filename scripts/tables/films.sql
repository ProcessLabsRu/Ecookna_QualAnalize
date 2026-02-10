-- entechai.public.films определение

-- Drop table

-- DROP TABLE entechai.public.films;

CREATE TABLE entechai.public.films (
	id serial DEFAULT nextval('films_id_seq'::regclass) NOT NULL,
	user_created uuid,
	date_created timestamptz,
	user_updated uuid,
	date_updated timestamptz,
	films_article varchar(255),
	films_type varchar(255),
	type_of_film varchar(255),
	CONSTRAINT films_pkey PRIMARY KEY (id)
);


-- entechai.public.films внешние включи

ALTER TABLE entechai.public.films ADD CONSTRAINT films_user_created_foreign FOREIGN KEY (user_created) REFERENCES entechai.public.directus_users(id);
ALTER TABLE entechai.public.films ADD CONSTRAINT films_user_updated_foreign FOREIGN KEY (user_updated) REFERENCES entechai.public.directus_users(id);