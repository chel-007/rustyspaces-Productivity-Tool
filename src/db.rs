use diesel::prelude::*;
use rocket_sync_db_pools::database;
use uuid::Uuid;
use chrono::NaiveDateTime;
use crate::models::StickyLine;
use crate::models::{StickyNote, TimeTrackingSession};




#[database("postgres_database")]
pub struct DbConn(diesel::PgConnection);

pub async fn get_user_spaces(conn: &DbConn, user_id_param: &str) -> Result<Vec<String>, diesel::result::Error> {
    use crate::schema::spaces::dsl::*;

    let user_id_param = user_id_param.to_string(); // Clone the string for the async block

    conn.run(move |c| {
        let results = spaces
            .filter(user_id.eq(user_id_param))
            .load::<crate::models::Space>(c)
            .map_err(|e| {
                // Log or handle the error as needed
                e
            })?;

        Ok(results.into_iter().map(|s| s.space_name).collect())
    })
    .await
}

pub async fn create_space(conn: &DbConn, user_id: String, space_name: String) -> Result<(), diesel::result::Error> {
    use crate::schema::spaces;

    conn.run(move |c| {
        diesel::insert_into(spaces::table)
            .values((
                spaces::user_id.eq(user_id),
                spaces::space_name.eq(space_name),
            ))
            .execute(c)
            .map(|_| ()) // Return Ok(()) if insertion succeeds
    }).await
}



// pub async fn create_space(conn: &DbConn, user_id: &str, space_name: &str) {
//     use crate::schema::spaces;

//     let new_space = crate::models::NewSpace {
//         user_id: user_id.to_string(),
//         space_name: space_name.to_string(),
//     };

//     conn.run(move |c| {
//         diesel::insert_into(spaces::table)
//             .values(&new_space)
//             .execute(c)
//             .expect("Error creating new space");
//     })
//     .await
// }

// src/db.rs

 // Import from the shared module

// src/db.rs

// Convert Vec<StickyLine> to Vec<String> for storage
fn format_lines_for_storage(lines: Option<Vec<StickyLine>>) -> Option<Vec<String>> {
    lines.map(|lines| 
        lines.into_iter()
             .map(|line| line.to_string()) // Convert each StickyLine to String
             .collect()
    )
}

//Convert Vec<String> from storage to Vec<StickyLine>
// fn parse_lines_from_storage(lines: Option<Vec<String>>) -> Option<Vec<StickyLine>> {
//     lines.map(|lines| 
//         lines.into_iter()
//              .map(|line| StickyLine::from_string(&line)) // Convert each String to StickyLine
//              .collect()
//     )
// }


pub async fn create_sticky_note(
    conn: &DbConn,
    user_id: &str,
    titile: &str,
    space_id: i32,
    color: &str,
    text_color: &str,
    tags: Option<Vec<String>>,
    lines: Option<Vec<StickyLine>>, // Incoming as Vec<StickyLine>
) -> Result<StickyNote, diesel::result::Error> {
    use crate::schema::sticky_notes;

    let new_note = StickyNote {
        id: Uuid::new_v4(),
        user_id: user_id.to_string(),
        title: titile.to_string(),
        space_id: space_id,
        color: color.to_string(),
        text_color: text_color.to_string(),
        created_at: chrono::Utc::now().naive_utc(),
        updated_at: Some(chrono::Utc::now().naive_utc()),
        tags: tags,
        lines: format_lines_for_storage(lines), // Convert StickyLine to Vec<String> for storage
    };

    conn.run(move |c| {
        diesel::insert_into(sticky_notes::table)
            .values(&new_note)
            .get_result(c)
    })
    .await
    .map_err(|e| {
        eprintln!("Error creating sticky note: {:?}", e);
        e
    })
}

pub async fn get_space_id(
    conn: &DbConn,
    user_id_param: String,
    space_name_param: String,
) -> Result<i32, diesel::result::Error> {
    use crate::schema::spaces::dsl::*;

    conn.run(move |c| {
        spaces
            .filter(user_id.eq(user_id_param))
            .filter(space_name.eq(space_name_param))
            .select(id)
            .first::<i32>(c)
    })
    .await
    .map_err(|e| {
        eprintln!("Error getting space ID: {:?}", e);
        e
    })
}


pub async fn get_sticky_notes(
    conn: &DbConn,
    user_id_param: String,
    space_id_param: i32,
) -> Result<Vec<StickyNote>, diesel::result::Error> {
    use crate::schema::sticky_notes::dsl::*;

    conn.run(move |c| {
        sticky_notes
            .filter(user_id.eq(user_id_param)) 
            .filter(space_id.eq(space_id_param))
            .load::<StickyNote>(c)
    })
    .await
}

pub async fn update_sticky_header(
    conn: &DbConn,
    user_id: String,
    space_id: i32,
    note_id: Uuid,
    new_title: String,
) -> Result<StickyNote, diesel::result::Error> {
    use crate::schema::sticky_notes::dsl::*;
    
    conn.run(move |c| {
        diesel::update(sticky_notes.find(note_id))
            .set((
                title.eq(new_title), // Update only the title
                updated_at.eq(Some(chrono::Utc::now().naive_utc())), // Update the timestamp
            ))
            .get_result(c)
    })
    .await
}


pub async fn update_sticky_note(
    conn: &DbConn,
    user_id: String,
    space_id: i32,
    note_id: Uuid,
    color: Option<String>,
    text_color: Option<String>,
    tags: Option<Vec<String>>,
    newlines: Option<Vec<StickyLine>>,
) -> Result<StickyNote, diesel::result::Error> {
    use crate::schema::sticky_notes::dsl::*;
    
    conn.run(move |c| {
        diesel::update(sticky_notes.find(note_id))
            .set((
                space_id.eq(space_id),
                color.eq(color),
                text_color.eq(text_color),
                tags.eq(tags),
                lines.eq(format_lines_for_storage(newlines)),
                updated_at.eq(Some(chrono::Utc::now().naive_utc())),
            ))
            .get_result(c)
    })
    .await
}







pub async fn delete_sticky_note(
    conn: &DbConn,
    note_id: Uuid,
) -> Result<usize, diesel::result::Error> {
    use crate::schema::sticky_notes::dsl::*;

    conn.run(move |c| {
        diesel::delete(sticky_notes.filter(id.eq(note_id)))
            .execute(c)
    })
    .await
}



// time tracking

pub async fn create_time_tracking_session(
    conn: &DbConn,
    user_id: String,
    space_id: i32,
    activity_name: String,
    start_time: NaiveDateTime,
) -> Result<TimeTrackingSession, diesel::result::Error> {
    use crate::schema::time_tracking_sessions;

    let new_session = TimeTrackingSession {
        id: Uuid::new_v4(),
        user_id,
        space_id,
        activity_name,
        start_time,
        end_time: None,
        duration: None,
    };

    conn.run(move |c| {
        diesel::insert_into(time_tracking_sessions::table)
            .values(&new_session)
            .get_result(c)
    })
    .await
    .map_err(|e| {
        eprintln!("Error creating new Time Track session: {:?}", e);
        e
    })
}


// Assuming `end_time` is passed as a UNIX timestamp (seconds since epoch) from the frontend
pub async fn complete_time_tracking_session(
    conn: &DbConn,
    session_id: Uuid,
    end_time_timestamp: i64, // UNIX timestamp
) -> Result<TimeTrackingSession, diesel::result::Error> {
    use crate::schema::time_tracking_sessions::dsl::*;

    // Convert UNIX timestamp to NaiveDateTime
    let end_time_pending = NaiveDateTime::from_timestamp_opt(end_time_timestamp, 0)
        .ok_or_else(|| diesel::result::Error::NotFound)?; // Handle conversion error

    // Fetch the session
    let session = conn.run(move |c| {
        time_tracking_sessions
            .filter(id.eq(session_id))
            .first::<TimeTrackingSession>(c)
    }).await?;

    // Calculate the duration
    let start_time_pending = session.start_time;
    let duration_pending = end_time_pending.signed_duration_since(start_time_pending).num_seconds();

    // println!("Backend start time: {:?}", start_time_pending);
    // println!("Backend end time: {:?}", end_time_pending);
    // println!("Duration in seconds: {}", duration_pending);


    // Update the session with the new end_time and duration
    conn.run(move |c| {
        diesel::update(time_tracking_sessions.filter(id.eq(session_id)))
            .set((
                end_time.eq(Some(end_time_pending)),
                duration.eq(Some(duration_pending)),
            ))
            .get_result(c)
    })
    .await
}


pub async fn get_all_time_tracking_sessions(
    conn: &DbConn,
    user_id_param: String,
    space_id_param: i32,
) -> Result<Vec<TimeTrackingSession>, diesel::result::Error> {
    use crate::schema::time_tracking_sessions::dsl::*;

    conn.run(move |c| {
        time_tracking_sessions
            .filter(user_id.eq(user_id_param)) 
            .filter(space_id.eq(space_id_param))
            .load::<TimeTrackingSession>(c)
    })
    .await
}

// pub async fn get_a_tracking_session(
//     conn: &DbConn,
//     session_id: Uuid,
// ) -> Result<TimeTrackingSession, diesel::result::Error> {
//     use crate::schema::time_tracking_sessions::dsl::*;

//     conn.run(move |c| {
//         time_tracking_sessions
//             .filter(id.eq(session_id))
//             .first::<TimeTrackingSession>(c)
//     })
//     .await
// }


pub async fn delete_time_tracking_session(
    conn: &DbConn,
    session_id: Uuid,
) -> Result<usize, diesel::result::Error> {
    use crate::schema::time_tracking_sessions::dsl::*;

    conn.run(move |c| {
        diesel::delete(time_tracking_sessions.filter(id.eq(session_id)))
            .execute(c)
    })
    .await
}


// pub async fn check_and_send_notification(
//     conn: &DbConn,
//     session_id: Uuid,
//     time_limit: Duration,
// ) -> Result<(), diesel::result::Error> {
//     use crate::schema::time_tracking_sessions::dsl::{
//         time_tracking_sessions, limit_notification_sent, id
//     };

//     let session = get_a_tracking_session(conn, session_id).await?;

//     if let Some(end_time) = session.end_time {
//         let session_duration = end_time.signed_duration_since(session.start_time);

//         if session_duration > time_limit && !session.limit_notification_sent {
//             // Send notification here (logic depends on your notification system)

//             // Update the session to indicate that the notification has been sent
//             conn.run(move |c| {
//                 diesel::update(time_tracking_sessions.find(session_id))
//                     .set(limit_notification_sent.eq(true))
//                     .execute(c)
//             })
//             .await?;
//         }
//     }

//     Ok(())
// }



