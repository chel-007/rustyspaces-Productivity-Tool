-- Your SQL goes here

ALTER TABLE sticky_notes
ADD COLUMN space_id INT4 DEFAULT 0 NOT NULL;
