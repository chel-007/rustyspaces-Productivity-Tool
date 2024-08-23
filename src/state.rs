// use std::collections::HashMap;
// use std::sync::Mutex;

// #[derive(Default)]
// pub struct Spaces {
//     pub spaces: Mutex<HashMap<String, Vec<String>>>,
//     pub active_connections: Mutex<HashMap<String, String>>, // Tracks user connections
// }

// impl Spaces {
//     pub fn add_connection(&self, user_id: String, space_name: String) {
//         let mut connections = self.active_connections.lock().unwrap();
//         connections.insert(user_id, space_name);
//     }

//     pub fn remove_connection(&self, user_id: &String) {
//         let mut connections = self.active_connections.lock().unwrap();
//         connections.remove(user_id);
//     }

//     pub fn get_other_active_spaces(&self, current_user_id: &String) -> Vec<String> {
//         let connections = self.active_connections.lock().unwrap();
//         connections.iter()
//             .filter(|(user_id, _)| user_id != current_user_id) // Exclude the current user's spaces
//             .map(|(_, space_name)| space_name.clone())
//             .collect()
//     }
// }
