use diesel::{Queryable, Insertable, Selectable};
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use super::schema::sticky_notes;
use super::schema::time_tracking_sessions;


#[derive(Queryable, Serialize, Deserialize)]
pub struct Space {
    pub id: i32,
    pub user_id: String,
    pub space_name: String,
}

#[derive(Insertable)]
#[diesel(table_name = crate::schema::spaces)]

// In your models.rs
pub struct NewSpace {
    pub user_id: String,
    pub space_name: String,
}

#[derive(Debug, Clone)]
pub struct StickyLine {
    pub text: String,
    pub color: String,
    pub is_checked: bool,
}

impl StickyLine {
    pub fn from_string(s: &str) -> Self {
        let parts: Vec<&str> = s.split('|').collect();
        StickyLine {
            text: parts.get(0).unwrap_or(&"").to_string(),
            color: parts.get(1).unwrap_or(&"").to_string(),
            is_checked: parts.get(2).unwrap_or(&"false").parse().unwrap_or(false),
        }
    }

    pub fn to_string(&self) -> String {
        format!("{}|{}|{}", self.text, self.color, self.is_checked)
    }
}

#[derive(Queryable, Selectable, Insertable, Serialize, Deserialize)]
#[diesel(table_name = sticky_notes)]
pub struct StickyNote {
    pub id: Uuid,
    pub space_id: i32,
    pub user_id: String,
    pub title: String,
    pub color: String,
    pub text_color: String,
    pub created_at: chrono::NaiveDateTime,
    pub updated_at: Option<chrono::NaiveDateTime>,
    pub tags: Option<Vec<String>>, // Option to handle Nullable in the database
    pub lines: Option<Vec<String>>, // Option to handle Nullable in the database
}

#[derive(Insertable, Serialize, Deserialize)]
#[diesel(table_name = sticky_notes)]
pub struct UpdateNote {
    pub id: Uuid,
    pub color: String,
    pub text_color: String,
    pub tags: Option<Vec<String>>,
    pub lines: Option<Vec<String>>,
}

#[derive(Insertable, Serialize, Deserialize)]
#[diesel(table_name = sticky_notes)]
pub struct UpdateHeader {
    pub id: Uuid,
    pub title: String,
}


#[derive(Insertable, Serialize, Deserialize)]
#[diesel(table_name = sticky_notes)]
pub struct NewStickyNote {
    pub title: String,
    pub color: String,
    pub text_color: String,
    pub tags: Option<Vec<String>>,
    pub lines: Option<Vec<String>>, // Array of strings for lines
}


// time tracking

#[derive(Queryable, Insertable, Serialize, Deserialize)]
#[diesel(table_name = time_tracking_sessions)]
pub struct TimeTrackingSession {
    pub id: Uuid,
    pub user_id: String,
    pub space_id: i32,
    pub activity_name: String,
    pub start_time: chrono::NaiveDateTime,
    pub end_time: Option<chrono::NaiveDateTime>,
    pub duration: Option<i64>,
}

#[derive(Queryable, Insertable, Serialize, Deserialize)]
#[diesel(table_name = time_tracking_sessions)]
pub struct NewTimeTrackingSession {
    pub activity_name: String,
    pub start_time: chrono::NaiveDateTime,
}

