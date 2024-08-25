-- Your SQL goes here
CREATE TABLE time_tracking_sessions (
    id UUID PRIMARY KEY,                       
    user_id TEXT NOT NULL,                     
    space_id INT4 DEFAULT 0 NOT NULL,
    activity_name TEXT NOT NULL,              
    start_time TIMESTAMP NOT NULL,             
    end_time TIMESTAMP,                        
    duration BIGINT
);