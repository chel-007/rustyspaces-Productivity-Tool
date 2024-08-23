// @generated automatically by Diesel CLI.

diesel::table! {
    spaces (id) {
        id -> Int4,
        user_id -> Text,
        space_name -> Text,
    }
}

diesel::table! {
    sticky_notes (id) {
        id -> Uuid,
        space_id -> Int4,
        user_id -> Text,
        color -> Text,
        text_color -> Text,
        created_at -> Timestamp,
        updated_at -> Nullable<Timestamp>,
        tags -> Nullable<Array<Text>>,
        lines -> Nullable<Array<Text>>, 
    }
}

diesel::table! {
    time_tracking_sessions (id) {
        id -> Uuid,
        user_id -> Text,
        space_id -> Int4,
        activity_name -> Text,
        start_time -> Timestamp,
        end_time -> Nullable<Timestamp>,
        duration -> Nullable<Int8>,
        limit_notification_sent -> Bool,
    }
}



diesel::allow_tables_to_appear_in_same_query!(
    spaces,
    sticky_notes,
    time_tracking_sessions,
);
