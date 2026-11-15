use crate::hardware;
use crate::json::{self, escape_str};
use crate::settings;
use crate::theme;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::{SystemTime, UNIX_EPOCH};

pub fn version_str() -> &'static str {
    env!("ASCII_DE_VERSION")
}

pub fn handle_version_cmd(args: &[String]) -> String {
    let as_json = args.iter().any(|a| a == "--json" || a == "-j");
    let ver = version_str();
    if as_json {
        format!(
            "{{\"name\":\"ascii-de-backend\",\"version\":{}}}",
            escape_str(ver)
        )
    } else {
        format!("ascii-de-backend {ver}")
    }
}

fn utc_timestamp_compact() -> String {
    let secs = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0);
    let days = secs.div_euclid(86_400);
    let rem = secs.rem_euclid(86_400);
    let hour = rem / 3_600;
    let min = (rem % 3_600) / 60;
    let sec = rem % 60;

    // Howard Hinnant's civil-from-days algorithm
    let z = days + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = mp + if mp < 10 { 3 } else { -9 };
    let y = y + if m <= 2 { 1 } else { 0 };
    format!("{y:04}{m:02}{d:02}_{hour:02}{min:02}{sec:02}")
}

fn unique_backup_dir(cfg_dir: &Path) -> Result<PathBuf, String> {
    let base = cfg_dir.join("backups");
    fs::create_dir_all(&base).map_err(|e| format!("mkdir {}: {e}", base.display()))?;
    let stamp = utc_timestamp_compact();
    let first = base.join(&stamp);
    if !first.exists() {
        return Ok(first);
    }
    for i in 1..=999 {
        let cand = base.join(format!("{stamp}_{i}"));
        if !cand.exists() {
            return Ok(cand);
        }
    }
    Err("unable to allocate unique backup directory".to_string())
}

pub fn migrate_dir(cfg_dir: &Path) -> Result<String, String> {
    fs::create_dir_all(cfg_dir).map_err(|e| format!("mkdir {}: {e}", cfg_dir.display()))?;

    let backup_dir = unique_backup_dir(cfg_dir)?;
    let files = [
        "settings.json",
        "theme.json",
        "monitors.json",
        "desktop-icons.json",
    ];
    let mut backed_up: Vec<String> = Vec::new();
    let mut backup_created = false;

    for fname in files {
        let src = cfg_dir.join(fname);
        if src.is_file() {
            if !backup_created {
                fs::create_dir_all(&backup_dir)
                    .map_err(|e| format!("mkdir {}: {e}", backup_dir.display()))?;
                backup_created = true;
            }
            let dst = backup_dir.join(fname);
            fs::copy(&src, &dst)
                .map_err(|e| format!("backup {} -> {}: {e}", src.display(), dst.display()))?;
            backed_up.push(fname.to_string());
        }
    }

    let mut migrated: Vec<String> = Vec::new();
    if settings::migrate_settings_file(&cfg_dir.join("settings.json"))? {
        migrated.push("settings.json".to_string());
    }
    if theme::migrate_theme_file(&cfg_dir.join("theme.json"))? {
        migrated.push("theme.json".to_string());
    }

    let backup_list = format!(
        "[{}]",
        backed_up
            .iter()
            .map(|s| escape_str(s))
            .collect::<Vec<_>>()
            .join(",")
    );
    let migrated_list = format!(
        "[{}]",
        migrated
            .iter()
            .map(|s| escape_str(s))
            .collect::<Vec<_>>()
            .join(",")
    );
    let backup_path_str = if backup_created {
        backup_dir.to_string_lossy().into_owned()
    } else {
        String::new()
    };

    Ok(format!(
        "{{\"ok\":true,\"version\":{},\"backup_dir\":{},\"backed_up\":{},\"migrated\":{}}}",
        escape_str(version_str()),
        escape_str(&backup_path_str),
        backup_list,
        migrated_list
    ))
}

pub fn handle_migrate_cmd() -> Result<String, String> {
    migrate_dir(&hardware::ascii_config_dir())
}

fn find_update_bin() -> Option<PathBuf> {
    if let Ok(exe) = env::current_exe() {
        if let Some(dir) = exe.parent() {
            let sibling = dir.join("ascii-de-update");
            if sibling.is_file() {
                return Some(sibling);
            }
        }
    }
    if let Some(path_os) = env::var_os("PATH") {
        for dir in env::split_paths(&path_os) {
            let cand = dir.join("ascii-de-update");
            if cand.is_file() {
                return Some(cand);
            }
        }
    }
    None
}

pub fn handle_update_check_cmd() -> String {
    if let Some(bin) = find_update_bin() {
        if let Ok(out) = Command::new(&bin).args(["--check", "--json"]).output() {
            if out.status.success() {
                let text = String::from_utf8_lossy(&out.stdout).trim().to_string();
                if !text.is_empty() && json::parse(&text).is_ok() {
                    return text;
                }
            }
        }
    }

    let cache_path = hardware::xdg_cache_home()
        .join("ascii-de")
        .join("update-check.json");
    if let Ok(raw) = fs::read_to_string(&cache_path) {
        let trimmed = raw.trim().to_string();
        if !trimmed.is_empty() && json::parse(&trimmed).is_ok() {
            return trimmed;
        }
    }

    format!(
        "{{\"current\":{},\"latest\":\"\",\"updateAvailable\":false,\"available\":false,\"releaseUrl\":\"\",\"checkedAt\":\"\"}}",
        escape_str(version_str())
    )
}
