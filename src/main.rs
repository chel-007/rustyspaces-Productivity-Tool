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
use std::path::{Path, PathBuf};
use rocket::response::status;
use rocket::http::Status;
use rocket::http::ContentType;
use rocket::tokio::fs::{File};
use rocket::tokio::io::BufReader;
use rocket::response::stream::ByteStream;
use tokio_util::io::ReaderStream;
use rand::seq::SliceRandom;
use tokio_stream::wrappers::ReadDirStream;
use tokio_stream::StreamExt;
use rocket::tokio::sync::RwLock;
use std::sync::Arc;
use rocket::State;

mod db;
mod models;
mod schema;

#[launch]
fn rocket() -> _ {
    std::env::set_var("DISABLE_PREPARED_STATEMENTS", "true");

    rocket::build()
        // .attach(cors)
        .attach(db::DbConn::fairing())
        .mount("/", rocket::fs::FileServer::from("static"))
        .mount("/", routes![index, get_spaces, create_space, view_space, silent_auth, get_other_active_spaces])
        .mount("/notes", routes![create_sticky_note, get_sticky_notes, update_sticky_note, update_header, delete_sticky_note])
        .mount("/track", routes![start_time_tracking, get_all_time_tracking, delete_time_tracking, complete_time_tracking])
        .mount("/music", routes![stream_random_music, next_song, play_test, get_metadata])
        .attach(Template::fairing())
        .manage(Spaces::default())
        .manage(MusicState::default())
        .manage(CurrentFileName(Arc::new(RwLock::new(None))))
}

#[derive(Default)]
pub struct Spaces { // Make the struct public
    pub spaces: Mutex<HashMap<String, Vec<String>>>,
    pub active_connections: Mutex<HashMap<String, String>>,
}

impl Spaces {
    pub fn add_connection(&self, user_id: String, space_name: String) {
        let mut connections = self.active_connections.lock().unwrap();
        connections.insert(user_id, space_name);
    }

    pub fn remove_connection(&self, user_id: &String) {
        let mut connections = self.active_connections.lock().unwrap();
        connections.remove(user_id);
    }

    pub fn get_other_active_spaces(&self, current_user_id: &String) -> Vec<String> {
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
    let user_spaces_result = db::get_user_spaces(&conn, &user_id).await;

    let mut result = HashMap::new();
    
    match user_spaces_result {
        Ok(user_spaces) => {
            result.insert(user_id, user_spaces);
        }
        Err(e) => {
            // Handle the error
            println!("Error fetching user spaces: {:?}", e);
            result.insert(user_id, Vec::new());
        }
    }

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
    let user_spaces_result = db::get_user_spaces(&conn, &user_id).await;

    let user_spaces = match user_spaces_result {
        Ok(s) => s,
        Err(e) => {
            // Handle the error
            println!("Error fetching user spaces: {:?}", e);
            Vec::new()
        }
    };

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
        &note_data.title,
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

#[post("/header?<space_name>", data = "<note>")]
async fn update_header(
    jar: &CookieJar<'_>,
    conn: db::DbConn,
    note: Json<models::UpdateHeader>,
    space_name: Option<String>,
) -> Result<Json<StickyNote>, status::Custom<Json<String>>> {
    let user_id = get_user_id(jar);

    let space_name = match space_name {
        Some(name) => name,
        None => return Err(status::Custom(Status::BadRequest, Json("Space name is missing".to_string()))),
    };

    let space_id = match db::get_space_id(&conn, user_id.clone(), space_name).await {
        Ok(id) => id,
        Err(_) => return Err(status::Custom(Status::NotFound, Json("Space not found".to_string()))),
    };

    match db::update_sticky_header(
        &conn,
        user_id,
        space_id,
        note.id,
        note.title.clone(),
    ).await {
        Ok(updated_note) => Ok(Json(updated_note)),
        Err(e) => Err(status::Custom(Status::InternalServerError, Json(format!("Error updating sticky note header: {:?}", e)))),
    }
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

#[derive(Default)]
struct MusicState {
    playlist: Mutex<Vec<String>>, // Store file names or paths
    current_song: Mutex<Option<String>>, // Current song being played
}

struct CurrentFileName(Arc<RwLock<Option<String>>>);

#[get("/play")]
async fn stream_random_music(state: &State<CurrentFileName>) -> Result<(ContentType, ByteStream<impl futures::Stream<Item = Vec<u8>>>), Status> {
    // List all files in the 'music' directory
    let music_dir = Path::new("music/");
    println!("Checking if music directory exists: {:?}", music_dir.display());

    let read_dir = match rocket::tokio::fs::read_dir(music_dir).await {
        Ok(read_dir) => {
            println!("Successfully read the music directory.");
            read_dir
        },
        Err(e) => {
            println!("Error reading music directory: {:?}", e);
            return Err(Status::InternalServerError);
        },
    };

    // Convert ReadDir to a stream and collect entries
    // Convert ReadDir to a stream and collect entries
    let entries = ReadDirStream::new(read_dir)
        .filter_map(|entry| match entry {
            Ok(entry) => {
                println!("Found entry: {:?}", entry.path().display());
                Some(entry)
            },
            Err(e) => {
                println!("Error reading directory entry: {:?}", e);
                None
            },
        })
        .collect::<Vec<_>>()
        .await;

    // Filter entries to get file paths
    let files: Vec<PathBuf> = entries
        .iter()
        .filter_map(|entry| {
            let path = entry.path();
            let is_file = rocket::tokio::task::block_in_place(|| {
                let metadata = std::fs::metadata(&path);
                match metadata {
                    Ok(metadata) => metadata.is_file(),
                    Err(e) => {
                        println!("Error getting metadata for file {}: {:?}", path.display(), e);
                        false
                    },
                }
            });
            if is_file {
                println!("File found: {:?}", path.display());
                Some(path)
            } else {
                None
            }
        })
        .collect();

    if files.is_empty() {
        println!("No files found in the music directory.");
        return Err(Status::NotFound);
    }

    // Randomly select a file
    let random_file_path = match files.choose(&mut rand::thread_rng()) {
        Some(path) => path,
        None => {
            println!("Failed to select a random file.");
            return Err(Status::InternalServerError);
        },
    };

    println!("Selected file: {:?}", random_file_path.display());
    

    // Open the selected file
    let file = match File::open(&random_file_path).await {
        Ok(f) => f,
        Err(e) => {
            println!("Error opening file {}: {:?}", random_file_path.display(), e);
            return Err(Status::InternalServerError);
        },
    };

        // Process the metadata and store the filename
    let file_name = process_metadata(&random_file_path);

    let mut file_name_lock = state.0.write().await;
    *file_name_lock = Some(file_name.clone());

    println!("processed file: {:?}", file_name);
    println!("processed file stored: {:?}", file_name_lock);

    // Create a buffered reader and stream its contents as Vec<u8>
    let reader = BufReader::new(file);
    let stream = ReaderStream::new(reader).map(|result| {
        match result {
            Ok(bytes) => bytes.to_vec(),
            Err(e) => {
                println!("Error reading from file stream: {:?}", e);
                Vec::new() // Handle the error by yielding an empty Vec<u8>
            },
        }
    });

    // Return the stream as a ByteStream
    Ok((ContentType::Binary, ByteStream::from(stream)))
}

// Define the process_metadata function
fn process_metadata(file_path: &PathBuf) -> String {
    let file_name_without_extension = file_path
        .file_stem()
        .and_then(|os_str| os_str.to_str())
        .unwrap_or("unknown");

    file_name_without_extension.to_string()
}

#[get("/metadata")]
async fn get_metadata(state: &State<CurrentFileName>) -> Result<String, rocket::http::Status> {
    let file_name_lock = state.0.read().await;

    match &*file_name_lock {
        Some(name) => Ok(name.clone()),
        None => Err(rocket::http::Status::NotFound),
    }
}


#[get("/test")]
async fn play_test() -> Result<(ContentType, ByteStream<impl futures::Stream<Item = Vec<u8>>>), Status> {
    let path = Path::new("music/comet.mp3"); // Ensure you have a file named test.mp3
    let file = match File::open(&path).await {
        Ok(f) => f,
        Err(_) => return Err(Status::InternalServerError),
    };

    let reader = BufReader::new(file);
    let stream = ReaderStream::new(reader).map(|result| {
        match result {
            Ok(bytes) => bytes.to_vec(),
            Err(e) => {
                println!("Error reading from file stream: {:?}", e);
                Vec::new() // Handle the error by yielding an empty Vec<u8>
            },
        }
    });

    Ok((ContentType::new("audio", "mpeg"), ByteStream::from(stream)))
}


#[post("/next")]
async fn next_song(state: &State<MusicState>) -> Result<Json<String>, Status> {
    let mut playlist = state.playlist.lock().unwrap();
    let mut current_song = state.current_song.lock().unwrap();

    if playlist.is_empty() {
        return Err(Status::NotFound);
    }

    let next_song = playlist.pop().unwrap();
    *current_song = Some(next_song.clone());

    Ok(Json(next_song))
}

