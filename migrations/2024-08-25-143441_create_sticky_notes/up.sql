-- Your SQL goes here
CREATE TABLE sticky_notes (
    id UUID PRIMARY KEY,
    space_id INT NOT NULL,
    user_id TEXT NOT NULL,
    title TEXT NOT NULL,
    color TEXT NOT NULL,
    text_color TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP,
    tags TEXT[],
    lines TEXT[]
);
