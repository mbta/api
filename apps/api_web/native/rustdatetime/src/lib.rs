use chrono::{Local, TimeZone};

#[rustler::nif]
fn add(a: i64, b: i64) -> i64 {
    a + b
}

#[rustler::nif]
fn unix_to_local(unix: i64) -> String {
    let time = Local.timestamp_millis_opt(unix * 1_000);
    match time {
        chrono::LocalResult::None => "none".into(),
        chrono::LocalResult::Single(time) => time.to_rfc3339(),
        chrono::LocalResult::Ambiguous(_, _) => "ambiguous".into(),
    }
}

rustler::init!("Elixir.RustDateTime", [add, unix_to_local]);
