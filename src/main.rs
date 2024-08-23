// #![recursion_limit = "256"]


#[macro_use] extern crate rocket;
#[macro_use] extern crate serde_json;

use rocket::{launch, routes, http::CookieJar};
use rocket::serde::json::Json;
use rocket::http::Cookie;
use rocket_dyn_templates::Template;
use uuid::Uuid;
use std::collections::HashMap;
use std::sync::Mutex;
use serde::{Deserialize};
use crate::models::StickyNote;
use crate::models::StickyLine;
use rocket::fs::NamedFile;
use std::path::{Path};
use rocket::response::status;
use rocket::http::Status;

mod db;
mod models;
mod schema;
mod state;

#[launch]
fn rocket() -> _ {

    rocket::build()
        // .attach(cors)
        .attach(db::DbConn::fairing())
        .mount("/", rocket::fs::FileServer::from("static"))
        .mount("/", routes![index, get_spaces, create_space, view_space, silent_auth, get_other_active_spaces])
        .mount("/notes", routes![create_sticky_note, get_sticky_notes, update_sticky_note, delete_sticky_note])
        .mount("/track", routes![start_time_tracking, get_all_time_tracking, delete_time_tracking, complete_time_tracking])
        .attach(Template::fairing())
        .manage(Spaces::default())
}

#[derive(Default)]
pub struct Spaces { // Make the struct public
    pub spaces: Mutex<HashMap<String, Vec<String>>>,
    pub active_connections: Mutex<HashMap<String, String>>, // Tracks user connections
}

impl Spaces {
    pub fn add_connection(&self, user_id: String, space_name: String) { // Make the method public
        let mut connections = self.active_connections.lock().unwrap();
        connections.insert(user_id, space_name);
    }

    pub fn remove_connection(&self, user_id: &String) { // Make the method public
        let mut connections = self.active_connections.lock().unwrap();
        connections.remove(user_id);
    }

    pub fn get_other_active_spaces(&self, current_user_id: &String) -> Vec<String> { // Make the method public
        let connections = self.active_connections.lock().unwrap();
        connections.iter()
        .filter(|(user_id, _)| *user_id != current_user_id)// Exclude the current user's spaces
            .map(|(_, space_name)| space_name.clone())
            .collect()
    }
}

fn get_user_id(jar: &CookieJar<'_>) -> String {
    jar.get("user_id").map_or_else(|| Uuid::new_v4().to_string(), |cookie| cookie.value().to_string())
}

// fn has_spaces(user_id: String) -> bool {
//     !user_id.is_empty()
// }

#[get("/")]
async fn index() -> Option<NamedFile> {
    NamedFile::open(Path::new("static/index.html")).await.ok()
}

#[post("/auth/silent")]
fn silent_auth(jar: &CookieJar<'_>) -> Json<String> {
    // Generate and set user_id if not present
    let user_id = jar.get("user_id").map_or_else(|| {
        let new_user_id = Uuid::new_v4().to_string();
        jar.add(Cookie::new("user_id", new_user_id.clone()));
        new_user_id
    }, |cookie| cookie.value().to_string());
    println!("auth: {}", user_id);
    Json(user_id)
}

#[get("/spaces")]
async fn get_spaces(jar: &CookieJar<'_>, conn: db::DbConn) -> Json<HashMap<String, Vec<String>>> {
    let user_id = get_user_id(jar);
    let user_spaces = db::get_user_spaces(&conn, &user_id).await;
    
    let mut result = HashMap::new();
    println!("getspaces: {}", user_id);
    println!("getspaceslist: {:?}", user_spaces);

    result.insert(user_id, user_spaces);
    // println("getresults: {}", Json(result))
    Json(result)
}

#[post("/spaces", data = "<space_name>")]
async fn create_space(space_name: Json<String>, jar: &CookieJar<'_>, conn: db::DbConn) -> status::Custom<Json<String>> {
    let user_id = get_user_id(jar);

    match db::create_space(&conn, user_id.clone(), space_name.into_inner()).await {
        Ok(_) => {
            println!("create-space: {}", user_id);
            status::Custom(Status::Ok, Json("Space created successfully".to_string()))
        },
        Err(e) => {
            eprintln!("Error creating space: {}", e);
            status::Custom(Status::InternalServerError, Json("Failed to create space".to_string()))
        }
    }
}


#[get("/spaces/<space_name>")]
async fn view_space(space_name: String, jar: &CookieJar<'_>, conn: db::DbConn, spaces: &rocket::State<Spaces>) -> Template {
    let user_id = get_user_id(jar);
    let user_spaces = db::get_user_spaces(&conn, &user_id).await;
    
    if user_spaces.contains(&space_name) {
        spaces.add_connection(user_id.clone(), space_name.clone());

        let context = json!({
            "space_name": space_name,
            "spaces": user_spaces,
        });
        Template::render("space", &context)
    } else {
        Template::render("404", &json!({ "error": "Space not found" }))
    }
}


#[get("/others")]
async fn get_other_active_spaces(jar: &CookieJar<'_>, spaces: &rocket::State<Spaces>) -> Json<Vec<String>> {
    let user_id = get_user_id(jar);
    let other_spaces = spaces.get_other_active_spaces(&user_id);
    Json(other_spaces)
}




#[derive(Debug, Deserialize)]
pub struct RequestQuery {
    pub space_name: String,
}


#[post("/create?<space_name>", data = "<note_data>")]
async fn create_sticky_note(
    note_data: Json<models::NewStickyNote>,
    jar: &CookieJar<'_>,
    conn: db::DbConn,
    space_name: Option<String>,
) -> Result<Json<models::StickyNote>, status::Custom<Json<String>>> {
    let user_id = get_user_id(jar);

    // Ensure space_name is provided
    let space_name = match space_name {
        Some(name) => name,
        None => return Err(status::Custom(Status::BadRequest, Json("Missing space_name".to_string()))),
    };

    let space_id = match db::get_space_id(&conn, user_id.clone(), space_name).await {
        Ok(id) => id,
        Err(_) => {
            return Err(status::Custom(Status::NotFound, Json("Space not found".to_string())));
        }
    };

    let sticky_lines: Option<Vec<StickyLine>> = note_data.lines.as_ref().map(|lines| {
        lines.iter().map(|line| StickyLine::from_string(line)).collect()
    });

    let new_note = db::create_sticky_note(
        &conn,
        &user_id,
        space_id,
        &note_data.color,
        &note_data.text_color,
        note_data.tags.clone(),
        sticky_lines,
    )
    .await
    .map_err(|_| status::Custom(Status::InternalServerError, Json("Failed to create sticky note".to_string())))?;

    Ok(Json(new_note))
}



#[get("/notes?<space_name>")]
async fn get_sticky_notes(
    jar: &CookieJar<'_>,
    conn: db::DbConn,
    space_name: Option<String>,
) -> Json<Vec<StickyNote>> {
    let user_id = get_user_id(jar);

    let space_name = match space_name {
        Some(name) => name,
        None => return Json(Vec::new()), // Return an empty list if space_name is missing
    };

    let space_id = match db::get_space_id(&conn, user_id.clone(), space_name).await {
        Ok(id) => id,
        Err(_) => {
            return Json(Vec::new());
        }
    };

    let notes = match db::get_sticky_notes(&conn, user_id, space_id).await {
        Ok(notes) => notes,
        Err(_) => {
            Vec::new()
        }
    };

    Json(notes)
}

#[put("/update?<space_name>", data = "<note>")]
async fn update_sticky_note(
    jar: &CookieJar<'_>,
    conn: db::DbConn,
    note: Json<models::UpdateNote>,
    space_name: Option<String>,
) -> Result<Json<StickyNote>, status::Custom<Json<String>>> {
    let user_id = get_user_id(jar);

        // Ensure space_name is provided
        let space_name = match space_name {
            Some(name) => name,
            
            None => return Err(status::Custom(Status::BadRequest, Json("Missing space_name".to_string()))),
        };
    
        println!("i got to check space-name: {}", space_name);
        let space_id = match db::get_space_id(&conn, user_id.clone(), space_name).await {
            Ok(id) => id,
            Err(_) => {
                return Err(status::Custom(Status::NotFound, Json("Space not found".to_string())));
            }
        };
        println!("i got to check space-id: {}", space_id);

    // Convert lines from Vec<String> to Vec<StickyLine>
    let sticky_lines: Option<Vec<StickyLine>> = note.lines.as_ref().map(|lines| {
        lines.iter().map(|line| StickyLine::from_string(line)).collect()
    });
    
    match db::update_sticky_note(
        &conn,
        user_id,
        space_id,
        note.id,
        Some(note.color.clone()),
        Some(note.text_color.clone()),
        note.tags.clone(),
        sticky_lines,
    ).await {
        Ok(updated_note) => Ok(Json(updated_note)),
        Err(e) => {
            // Create an error message JSON response
            let error_message = Json(format!("Error updating sticky note: {:?}", e));
            // Wrap the JSON response in a Custom response with the appropriate HTTP status
            Err(status::Custom(Status::InternalServerError, error_message))
        }
    }
}


#[delete("/<note_id>")]
async fn delete_sticky_note(note_id: String, conn: db::DbConn) -> Json<String> {
    let note_uuid = Uuid::parse_str(&note_id).expect("Invalid UUID");
    let deleted_rows = db::delete_sticky_note(&conn, note_uuid)
        .await
        .expect("Failed to delete sticky note");

    if deleted_rows > 0 {
        Json("Sticky note deleted successfully".to_string())
    } else {
        Json("Sticky note not found".to_string())
    }
}


// time tracking

#[derive(Debug, Deserialize)]
pub struct RequestQueryTwo {
    pub session_id: String,
}

#[post("/start?<space_name>", data = "<new_session>")]
async fn start_time_tracking(
    jar: &CookieJar<'_>,
    conn: db::DbConn,
    new_session: Json<models::NewTimeTrackingSession>,
    space_name: Option<String>,
) -> Result<Json<models::TimeTrackingSession>, status::Custom<Json<String>>> {

    let user_id = get_user_id(jar);

    // Ensure space_name is provided
    let space_name = match space_name {
        Some(name) => name,
        
        None => return Err(status::Custom(Status::BadRequest, Json("Missing space_name".to_string()))),
    };

    println!("i got to check space-name: {}", space_name);
    let space_id = match db::get_space_id(&conn, user_id.clone(), space_name).await {
        Ok(id) => id,
        Err(_) => {
            return Err(status::Custom(Status::NotFound, Json("Space not found".to_string())));
        }
    };
    println!("i got to check space-id: {}", space_id);

    let session = db::create_time_tracking_session(
        &conn,
        user_id,
        space_id,
        new_session.activity_name.clone(),
        new_session.start_time,
    ).await.expect("Failed to create time tracking session");

    Ok(Json(session))
}

#[post("/complete?<session_id>&<end_time>")]
async fn complete_time_tracking(
    // jar: &CookieJar<'_>,
    conn: db::DbConn,
    session_id: String,
    end_time: i64,
) -> Result<Json<models::TimeTrackingSession>, Status> {

    let session_id = Uuid::parse_str(&session_id).map_err(|_| Status::BadRequest)?;

    let session = db::complete_time_tracking_session(
        &conn,
        session_id,
        end_time,
    ).await.map_err(|e| {
        error!("Failed to complete time tracking session: {:?}", e);
        Status::InternalServerError
    })?;

    Ok(Json(session))
}

#[get("/time_tracking?<space_name>")]
async fn get_all_time_tracking(
    jar: &CookieJar<'_>,
    conn: db::DbConn,
    space_name: Option<String>,
) -> Json<Vec<models::TimeTrackingSession>> {
    let user_id = get_user_id(jar);

    let space_name = match space_name {
        Some(name) => name,
        None => return Json(Vec::new()), // Return an empty list if space_name is missing
    };

    let space_id = match db::get_space_id(&conn, user_id.clone(), space_name).await {
        Ok(id) => id,
        Err(_) => {
            return Json(Vec::new());
        }
    };

    let sessions = match db::get_all_time_tracking_sessions(&conn, user_id, space_id).await {
        Ok(sessions) => sessions,
        Err(_) => {
            Vec::new()
        }
    };

    Json(sessions)
}




#[delete("/delete?<session_id>")]
async fn delete_time_tracking(
    // jar: &CookieJar<'_>,
    conn: db::DbConn,
    session_id: String,
) -> Result<Status, Status> {
    // Parse the session_id from a String to a Uuid
    let session_id = match Uuid::parse_str(&session_id) {
        Ok(uuid) => uuid,
        Err(_) => return Err(Status::BadRequest),
    };
    
    match db::delete_time_tracking_session(&conn, session_id).await {
        Ok(_) => Ok(Status::Ok),
        Err(_) => Err(Status::InternalServerError),
    }
}