-- Your SQL goes here

CREATE TABLE time_tracking_sessions (
    id UUID PRIMARY KEY,                       -- Unique identifier for the session
    user_id TEXT NOT NULL,                     -- Reference to the user who started the session
    space_id INT4 DEFAULT 0 NOT NULL,                    -- Reference to the space where the session was started
    activity_name TEXT NOT NULL,               -- Name of the activity being tracked
    start_time TIMESTAMP NOT NULL,             -- When the session started
    end_time TIMESTAMP,                        -- When the session ended (NULL if still ongoing)
    duration BIGINT,                       -- Duration of the session (calculated on completion)
    limit_notification_sent BOOLEAN NOT NULL   -- Flag to indicate if a limit notification has been sent
);