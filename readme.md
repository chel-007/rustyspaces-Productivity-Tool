Project Documentation: Overview and Features
High-Level Overview of the App
App Name: RustySpaces
RustySpaces is a web application that allows users to create, manage, and interact with personal and shared digital spaces. The app includes features such as creating spaces, storing space data in a database, and providing a responsive and visually appealing frontend.


#5432 

Features Installed and Implemented
1. Frontend
index.html.tera

Purpose: Displays the main page of the app with options to create a new space or view existing spaces.
Key Components:
Tooltip: Displays a message prompting users to create their first space.
Plus Button: Allows users to add new spaces.
Space List: Shows existing spaces if any are available.
Styling: Utilizes Tailwind CSS for styling and Font Awesome for icons.
script.js

Purpose: Handles frontend interactions, such as displaying existing spaces, updating the UI, and managing space creation.
Key Features:
Event Listeners: Attached to buttons for creating new spaces.
Local Storage: Manages space data temporarily on the client side.
2. Backend
models.rs

Purpose: Defines the data models for the app.
Key Components:
Space Model: Represents a space with fields for id, user_id, and space_name.
NewSpace Struct: Used for creating new space entries in the database.
db.rs

Purpose: Handles database interactions.
Key Components:
Database Connection: Configured to use SQLite (with a focus on switching to PostgreSQL).
CRUD Operations:
get_user_spaces: Fetches spaces for a given user.
create_space: Inserts a new space into the database.
Database Setup:

Migration Files:
Create Spaces Table:
SQL: CREATE TABLE spaces (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id TEXT NOT NULL, space_name TEXT NOT NULL);
Purpose: Defines the schema for storing space data.
3. Database Management
Managed Database Solution:

Current Solution: SQLite for local development and testing.
Planned Solution: PostgreSQL using Supabase for production.
Configuration:

Database URL: Set in the environment variables or configuration file.
Migration Commands:
diesel migration generate create_spaces - Generates a new migration.
diesel migration run - Applies migrations to the database.
Note: Ensure that the PostgreSQL feature is enabled in Diesel for compatibility with the managed database solution.