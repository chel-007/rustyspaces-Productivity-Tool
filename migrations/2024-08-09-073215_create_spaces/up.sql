-- Your SQL goes here
CREATE TABLE spaces (
    id SERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    space_name TEXT NOT NULL
);

-- CREATE TABLE sticky_notes (
--     id UUID PRIMARY KEY,
--     user_id TEXT NOT NULL,
--     color TEXT NOT NULL,
--     text_color TEXT NOT NULL,
--     created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
--     updated_at TIMESTAMP,
--     tags TEXT[],
--     lines TEXT[]
-- );


