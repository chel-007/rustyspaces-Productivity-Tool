-- Your SQL goes here

CREATE TABLE spaces (
    id SERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    space_name TEXT NOT NULL
);
