use crate::hardware::home_dir;
use crate::json::{self, escape_str};
use crate::theme::{atomic_write, config_dir};
use std::collections::HashSet;
use std::env;
use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone)]
pub struct DesktopIcon {
    pub id: String,
    pub label: String,
    pub cmd: String,
    pub glyph: String,
    pub col: i64,
    pub row: i64,
}

fn icons_path() -> PathBuf {
    config_dir().join("desktop-icons.json")
}

fn is_executable_file(path: &Path) -> bool {
    let Ok(meta) = fs::metadata(path) else {
        return false;
    };
    if !meta.is_file() {
        return false;
    }
    meta.permissions().mode() & 0o111 != 0
}

fn has_command_in(name: &str, path_dirs: &[PathBuf]) -> bool {
    path_dirs
        .iter()
        .any(|dir| is_executable_file(&dir.join(name)))
}

fn has_desktop_in(desktop_names: &[&str], app_dirs: &[PathBuf]) -> bool {
    for dir in app_dirs {
        for fname in desktop_names {
            if dir.join(fname).is_file() {
                return true;
            }
        }
    }
    false
}

fn is_app_available(bins: &[&str], desktops: &[&str], path_dirs: &[PathBuf], app_dirs: &[PathBuf]) -> Option<String> {
    for bin in bins {
        if has_command_in(bin, path_dirs) {
            return Some((*bin).to_string());
        }
    }
    if has_desktop_in(desktops, app_dirs) {
        return bins.first().map(|s| (*s).to_string());
    }
    None
}

pub fn default_icons_with_env(path_dirs: &[PathBuf], app_dirs: &[PathBuf]) -> Vec<DesktopIcon> {
    let mut icons = Vec::new();
    let mut row = 0i64;

    let term_cmd = is_app_available(
        &["ascii-de-terminal", "kitty", "foot", "konsole", "alacritty", "xterm"],
        &["kitty.desktop", "foot.desktop", "org.kde.konsole.desktop", "Alacritty.desktop"],
        path_dirs,
        app_dirs,
    )
    .unwrap_or_else(|| "ascii-de-terminal".to_string());
    icons.push(DesktopIcon {
        id: "term".to_string(),
        label: "Terminal".to_string(),
        cmd: term_cmd,
        glyph: ">_".to_string(),
        col: 0,
        row,
    });
    row += 1;

    let browsers: [(&str, &str, &str); 6] = [
        ("firefox", "Firefox", "firefox.desktop"),
        ("chromium", "Chromium", "chromium.desktop"),
        ("google-chrome-stable", "Chrome", "google-chrome.desktop"),
        ("brave", "Brave", "brave-browser.desktop"),
        ("librewolf", "LibreWolf", "librewolf.desktop"),
        ("vivaldi-stable", "Vivaldi", "vivaldi-stable.desktop"),
    ];
    for (bin, label, desktop) in browsers {
        if is_app_available(&[bin], &[desktop], path_dirs, app_dirs).is_some() {
            icons.push(DesktopIcon {
                id: "web".to_string(),
                label: label.to_string(),
                cmd: bin.to_string(),
                glyph: "WW".to_string(),
                col: 0,
                row,
            });
            row += 1;
            break;
        }
    }

    let file_managers: [(&str, &str); 5] = [
        ("dolphin", "org.kde.dolphin.desktop"),
        ("thunar", "thunar.desktop"),
        ("pcmanfm", "pcmanfm.desktop"),
        ("nautilus", "org.gnome.Nautilus.desktop"),
        ("nemo", "nemo.desktop"),
    ];
    for (bin, desktop) in file_managers {
        if is_app_available(&[bin], &[desktop], path_dirs, app_dirs).is_some() {
            icons.push(DesktopIcon {
                id: "files".to_string(),
                label: "Files".to_string(),
                cmd: bin.to_string(),
                glyph: "[]".to_string(),
                col: 0,
                row,
            });
            row += 1;
            break;
        }
    }

    if let Some(cmd) = is_app_available(
        &["discord", "vesktop"],
        &["discord.desktop", "vesktop.desktop"],
        path_dirs,
        app_dirs,
    ) {
        icons.push(DesktopIcon {
            id: "discord".to_string(),
            label: "Discord".to_string(),
            cmd,
            glyph: "##".to_string(),
            col: 0,
            row,
        });
        row += 1;
    }

    if let Some(cmd) = is_app_available(&["steam"], &["steam.desktop"], path_dirs, app_dirs) {
        icons.push(DesktopIcon {
            id: "steam".to_string(),
            label: "Steam".to_string(),
            cmd,
            glyph: "++".to_string(),
            col: 0,
            row,
        });
        row += 1;
    }

    icons.push(DesktopIcon {
        id: "settings".to_string(),
        label: "Settings".to_string(),
        cmd: "ascii-de-settings".to_string(),
        glyph: "[*".to_string(),
        col: 0,
        row,
    });
    row += 1;

    icons.push(DesktopIcon {
        id: "mixer".to_string(),
        label: "Audio".to_string(),
        cmd: "ascii-de-settings --tab 3".to_string(),
        glyph: "dB".to_string(),
        col: 0,
        row,
    });

    icons
}

fn default_icons() -> Vec<DesktopIcon> {
    let path_dirs: Vec<PathBuf> = env::var_os("PATH")
        .map(|v| env::split_paths(&v).collect())
        .unwrap_or_default();
    let app_dirs = vec![
        PathBuf::from("/usr/share/applications"),
        home_dir().join(".local/share/applications"),
    ];
    default_icons_with_env(&path_dirs, &app_dirs)
}

fn serialize_icons(icons: &[DesktopIcon]) -> String {
    let mut out = String::from("[\n");
    for (i, ic) in icons.iter().enumerate() {
        out.push_str(&format!(
            "  {{\"id\":{},\"label\":{},\"cmd\":{},\"glyph\":{},\"col\":{},\"row\":{}}}",
            escape_str(&ic.id),
            escape_str(&ic.label),
            escape_str(&ic.cmd),
            escape_str(&ic.glyph),
            ic.col,
            ic.row
        ));
        if i + 1 < icons.len() {
            out.push(',');
        }
        out.push('\n');
    }
    out.push(']');
    out
}

fn load_or_seed_icons() -> Result<Vec<DesktopIcon>, String> {
    let path = icons_path();
    if !path.exists() {
        let seeded = default_icons();
        atomic_write(&path, &(serialize_icons(&seeded) + "\n"))?;
        return Ok(seeded);
    }
    let raw = fs::read_to_string(&path).map_err(|e| format!("read {}: {e}", path.display()))?;
    let val = json::parse(&raw)?;
    let arr = val.as_arr().ok_or_else(|| "desktop-icons.json must be a JSON array".to_string())?;
    let mut icons = Vec::with_capacity(arr.len());
    for item in arr {
        let id = item.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string();
        let label = item.get("label").and_then(|v| v.as_str()).unwrap_or("").to_string();
        let cmd = item.get("cmd").and_then(|v| v.as_str()).unwrap_or("").to_string();
        let glyph = item.get("glyph").and_then(|v| v.as_str()).unwrap_or(">_").to_string();
        let col = item.get("col").and_then(|v| v.as_i64()).unwrap_or(0).max(0);
        let row = item.get("row").and_then(|v| v.as_i64()).unwrap_or(0).max(0);
        if !id.is_empty() {
            icons.push(DesktopIcon { id, label, cmd, glyph, col, row });
        }
    }
    Ok(icons)
}

fn save_icons(icons: &[DesktopIcon]) -> Result<String, String> {
    let body = serialize_icons(icons);
    atomic_write(&icons_path(), &(body.clone() + "\n"))?;
    Ok(body)
}

fn make_unique_id(label: &str, existing: &[DesktopIcon]) -> String {
    let mut slug = String::new();
    let mut prev_dash = false;
    for ch in label.chars() {
        let lc = ch.to_ascii_lowercase();
        if lc.is_ascii_alphanumeric() {
            slug.push(lc);
            prev_dash = false;
        } else if !prev_dash && !slug.is_empty() {
            slug.push('-');
            prev_dash = true;
        }
    }
    while slug.ends_with('-') {
        slug.pop();
    }
    if slug.is_empty() {
        slug = "icon".to_string();
    }

    let used: HashSet<&str> = existing.iter().map(|i| i.id.as_str()).collect();
    if !used.contains(slug.as_str()) {
        return slug;
    }
    let mut n = 2usize;
    loop {
        let cand = format!("{slug}-{n}");
        if !used.contains(cand.as_str()) {
            return cand;
        }
        n += 1;
    }
}

fn find_free_slot(existing: &[DesktopIcon]) -> (i64, i64) {
    let occupied: HashSet<(i64, i64)> = existing.iter().map(|i| (i.col, i.row)).collect();
    for col in 0..20 {
        for row in 0..8 {
            if !occupied.contains(&(col, row)) {
                return (col, row);
            }
        }
    }
    (0, existing.len() as i64)
}

fn normalize_glyph(raw: &str) -> String {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return ">_".to_string();
    }
    trimmed.chars().take(2).collect()
}

pub fn handle_icons_cmd(args: &[String]) -> Result<String, String> {
    let sub = args.first().map(|s| s.as_str()).unwrap_or("list");
    let mut icons = load_or_seed_icons()?;

    match sub {
        "list" => Ok(serialize_icons(&icons)),
        "add" => {
            let label = args.get(1).ok_or_else(|| "icons add requires <label> <cmd> <glyph> [col] [row]".to_string())?.clone();
            let cmd = args.get(2).ok_or_else(|| "icons add requires <cmd>".to_string())?.clone();
            let glyph = normalize_glyph(args.get(3).map(|s| s.as_str()).unwrap_or(">_"));
            let (def_col, def_row) = find_free_slot(&icons);
            let col = args.get(4).and_then(|s| s.parse::<i64>().ok()).unwrap_or(def_col).max(0);
            let row = args.get(5).and_then(|s| s.parse::<i64>().ok()).unwrap_or(def_row).max(0);
            let id = make_unique_id(&label, &icons);
            icons.push(DesktopIcon { id, label, cmd, glyph, col, row });
            save_icons(&icons)
        }
        "remove" => {
            let id = args.get(1).ok_or_else(|| "icons remove requires <id>".to_string())?;
            icons.retain(|ic| ic.id != *id);
            save_icons(&icons)
        }
        "move" => {
            let id = args.get(1).ok_or_else(|| "icons move requires <id> <col> <row>".to_string())?;
            let col = args.get(2).and_then(|s| s.parse::<i64>().ok()).ok_or_else(|| "invalid col".to_string())?.max(0);
            let row = args.get(3).and_then(|s| s.parse::<i64>().ok()).ok_or_else(|| "invalid row".to_string())?.max(0);
            if let Some(ic) = icons.iter_mut().find(|i| i.id == *id) {
                ic.col = col;
                ic.row = row;
                save_icons(&icons)
            } else {
                Err(format!("icon not found: {id}"))
            }
        }
        "edit" => {
            let id = args.get(1).ok_or_else(|| "icons edit requires <id> <label> <cmd> <glyph>".to_string())?;
            let label = args.get(2).ok_or_else(|| "icons edit requires <label>".to_string())?.clone();
            let cmd = args.get(3).ok_or_else(|| "icons edit requires <cmd>".to_string())?.clone();
            let glyph = normalize_glyph(args.get(4).ok_or_else(|| "icons edit requires <glyph>".to_string())?);
            if let Some(ic) = icons.iter_mut().find(|i| i.id == *id) {
                ic.label = label;
                ic.cmd = cmd;
                ic.glyph = glyph;
                save_icons(&icons)
            } else {
                Err(format!("icon not found: {id}"))
            }
        }
        other => Err(format!("unknown icons subcommand: {other}")),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn touch_exec(dir: &Path, name: &str) {
        let p = dir.join(name);
        fs::write(&p, "#!/bin/sh\n").expect("write mock bin");
        let mut perms = fs::metadata(&p).expect("meta").permissions();
        perms.set_mode(0o755);
        fs::set_permissions(&p, perms).expect("chmod");
    }

    #[test]
    fn dynamic_default_icons_omit_missing_apps() {
        let tmp = std::env::temp_dir().join(format!("ascii-de-icons-empty-{}", std::process::id()));
        let _ = fs::remove_dir_all(&tmp);
        fs::create_dir_all(&tmp).expect("mkdir");

        let icons = default_icons_with_env(std::slice::from_ref(&tmp), std::slice::from_ref(&tmp));
        let ids: Vec<&str> = icons.iter().map(|i| i.id.as_str()).collect();
        assert_eq!(ids, vec!["term", "settings", "mixer"]);
        assert_eq!(icons[0].cmd, "ascii-de-terminal");
        assert_eq!(icons[0].row, 0);
        assert_eq!(icons[1].row, 1);
        assert_eq!(icons[2].row, 2);

        let _ = fs::remove_dir_all(&tmp);
    }

    #[test]
    fn dynamic_default_icons_detect_installed_apps_in_order() {
        let tmp = std::env::temp_dir().join(format!("ascii-de-icons-full-{}", std::process::id()));
        let _ = fs::remove_dir_all(&tmp);
        let bin_dir = tmp.join("bin");
        let app_dir = tmp.join("apps");
        fs::create_dir_all(&bin_dir).expect("mkdir bin");
        fs::create_dir_all(&app_dir).expect("mkdir apps");

        touch_exec(&bin_dir, "foot");
        touch_exec(&bin_dir, "chromium");
        touch_exec(&bin_dir, "thunar");

        let icons = default_icons_with_env(&[bin_dir], &[app_dir]);
        let ids: Vec<&str> = icons.iter().map(|i| i.id.as_str()).collect();
        assert_eq!(ids, vec!["term", "web", "files", "settings", "mixer"]);
        assert_eq!(icons[0].cmd, "foot");
        assert_eq!(icons[1].cmd, "chromium");
        assert_eq!(icons[2].cmd, "thunar");
        assert!(!ids.contains(&"discord"));
        assert!(!ids.contains(&"steam"));
        for (idx, ic) in icons.iter().enumerate() {
            assert_eq!(ic.row, idx as i64);
        }

        let _ = fs::remove_dir_all(&tmp);
    }
}
