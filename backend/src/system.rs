use crate::audio::{query_audio, sinks_to_json};
use crate::displays::has_onkyo_monitor_hint;
use crate::hardware::{has_nvidia_gpu, home_dir, user_name};
use crate::json::escape_str;
use std::collections::BTreeMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::thread;
use std::time::Duration;

fn read_cpu_totals() -> Option<(u64, u64)> {
    let raw = fs::read_to_string("/proc/stat").ok()?;
    let first = raw.lines().next()?;
    if !first.starts_with("cpu ") {
        return None;
    }
    let nums: Vec<u64> = first
        .split_whitespace()
        .skip(1)
        .filter_map(|s| s.parse::<u64>().ok())
        .collect();
    if nums.len() < 4 {
        return None;
    }
    let idle = nums[3] + nums.get(4).copied().unwrap_or(0);
    let total: u64 = nums.iter().sum();
    Some((idle, total))
}

fn cpu_sample_path() -> PathBuf {
    let base = env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/tmp".to_string());
    let uid = user_name();
    PathBuf::from(base).join(format!("ascii-de-cpu-{uid}.stat"))
}

fn compute_cpu_pct() -> u64 {
    let Some((idle_now, total_now)) = read_cpu_totals() else {
        return 0;
    };
    let cache_path = cpu_sample_path();
    let prev = fs::read_to_string(&cache_path).ok().and_then(|s| {
        let mut it = s.split_whitespace();
        let i = it.next()?.parse::<u64>().ok()?;
        let t = it.next()?.parse::<u64>().ok()?;
        Some((i, t))
    });

    let (idle_prev, total_prev, idle_cur, total_cur) = match prev {
        Some((ip, tp)) if total_now > tp => (ip, tp, idle_now, total_now),
        _ => {
            thread::sleep(Duration::from_millis(60));
            if let Some((i2, t2)) = read_cpu_totals() {
                (idle_now, total_now, i2, t2)
            } else {
                (idle_now, total_now, idle_now, total_now)
            }
        }
    };

    let _ = fs::write(&cache_path, format!("{idle_cur} {total_cur}"));
    let dt = total_cur.saturating_sub(total_prev);
    let di = idle_cur.saturating_sub(idle_prev);
    if dt == 0 {
        return 0;
    }
    let busy = dt.saturating_sub(di);
    ((busy * 100) + dt / 2) / dt
}

fn compute_ram_stats() -> (u64, String, String) {
    let Ok(raw) = fs::read_to_string("/proc/meminfo") else {
        return (0, "0.0".to_string(), "0.0".to_string());
    };
    let mut total_kb: u64 = 0;
    let mut avail_kb: u64 = 0;
    let mut free_kb: u64 = 0;
    for line in raw.lines() {
        if let Some(rest) = line.strip_prefix("MemTotal:") {
            total_kb = rest.split_whitespace().next().and_then(|s| s.parse().ok()).unwrap_or(0);
        } else if let Some(rest) = line.strip_prefix("MemAvailable:") {
            avail_kb = rest.split_whitespace().next().and_then(|s| s.parse().ok()).unwrap_or(0);
        } else if let Some(rest) = line.strip_prefix("MemFree:") {
            free_kb = rest.split_whitespace().next().and_then(|s| s.parse().ok()).unwrap_or(0);
        }
    }
    if avail_kb == 0 {
        avail_kb = free_kb;
    }
    if total_kb == 0 {
        return (0, "0.0".to_string(), "0.0".to_string());
    }
    let used_kb = total_kb.saturating_sub(avail_kb);
    let pct = ((used_kb * 100) + total_kb / 2) / total_kb;
    let used_gb = format!("{:.1}", used_kb as f64 / 1_048_576.0);
    let total_gb = format!("{:.1}", total_kb as f64 / 1_048_576.0);
    (pct, used_gb, total_gb)
}

static GPU_CACHE: std::sync::Mutex<Option<(std::time::Instant, u64, u64)>> = std::sync::Mutex::new(None);

fn query_nvidia_smi() -> (u64, u64) {
    let Ok(out) = Command::new("nvidia-smi")
        .args([
            "--query-gpu=utilization.gpu,temperature.gpu",
            "--format=csv,noheader,nounits",
        ])
        .output()
    else {
        return (0, 0);
    };
    if !out.status.success() {
        return (0, 0);
    }
    let text = String::from_utf8_lossy(&out.stdout);
    let Some(first) = text.lines().next() else {
        return (0, 0);
    };
    let mut parts = first.split(',').map(|s| s.trim().parse::<u64>().unwrap_or(0));
    let util = parts.next().unwrap_or(0);
    let temp = parts.next().unwrap_or(0);
    (util, temp)
}

fn compute_gpu_stats() -> (u64, u64) {
    if let Ok(guard) = GPU_CACHE.lock() {
        if let Some((ts, util, temp)) = *guard {
            if ts.elapsed() < Duration::from_secs(5) {
                return (util, temp);
            }
        }
    }
    let stats = query_nvidia_smi();
    if let Ok(mut guard) = GPU_CACHE.lock() {
        *guard = Some((std::time::Instant::now(), stats.0, stats.1));
    }
    stats
}

pub fn handle_status_cmd() -> String {
    let cpu_pct = compute_cpu_pct();
    let (ram_pct, ram_used_gb, ram_total_gb) = compute_ram_stats();
    let (gpu_pct, gpu_temp) = compute_gpu_stats();
    let audio = query_audio();
    let has_onkyo = audio.onkyo_active || audio.onkyo_detected || has_onkyo_monitor_hint();
    let has_nvidia = has_nvidia_gpu();

    format!(
        "{{\"cpu_pct\":{},\"ram_pct\":{},\"ram_used_gb\":{},\"ram_total_gb\":{},\"gpu_pct\":{},\"gpu_temp\":{},\"audio_label\":{},\"audio_vol\":{},\"audio_muted\":{},\"onkyo_active\":{},\"onkyo_detected\":{},\"has_onkyo\":{},\"has_nvidia\":{},\"sinks\":{}}}",
        cpu_pct,
        ram_pct,
        escape_str(&ram_used_gb),
        escape_str(&ram_total_gb),
        gpu_pct,
        gpu_temp,
        escape_str(&audio.audio_label),
        audio.audio_vol,
        audio.audio_muted,
        audio.onkyo_active,
        has_onkyo,
        has_onkyo,
        has_nvidia,
        sinks_to_json(&audio.sinks)
    )
}

#[derive(Debug, Clone)]
pub struct AppEntry {
    pub name: String,
    pub exec: String,
    pub category: String,
    pub glyph: String,
}

fn strip_exec_codes(raw: &str) -> String {
    let mut tokens = Vec::new();
    for tok in raw.split_whitespace() {
        if matches!(
            tok,
            "%f" | "%F" | "%u" | "%U" | "%d" | "%D" | "%n" | "%N" | "%i" | "%c" | "%k" | "%v" | "%m"
        ) {
            continue;
        }
        tokens.push(tok);
    }
    while matches!(tokens.last().copied(), Some("--" | "--url")) {
        tokens.pop();
    }
    tokens.join(" ")
}

fn normalize_category(cats: &str) -> String {
    let list: Vec<&str> = cats.split(';').filter(|s| !s.is_empty()).collect();
    for pref in [
        "Network",
        "Game",
        "AudioVideo",
        "Audio",
        "Video",
        "Development",
        "Graphics",
        "Office",
        "System",
        "Utility",
        "Settings",
    ] {
        if list.iter().any(|c| c.eq_ignore_ascii_case(pref)) {
            return pref.to_string();
        }
    }
    list.first().copied().unwrap_or("Utility").to_string()
}

fn pick_ascii_glyph(name: &str, category: &str, exec: &str) -> &'static str {
    let ln = name.to_ascii_lowercase();
    let le = exec.to_ascii_lowercase();
    if ln.contains("terminal") || ln.contains("kitty") || ln.contains("alacritty") || ln.contains("konsole") || le.contains("kitty") {
        return ">_";
    }
    if ln.contains("discord") || ln.contains("vesktop") || ln.contains("telegram") || ln.contains("signal") || ln.contains("chat") {
        return "##";
    }
    if ln.contains("file") || ln.contains("dolphin") || ln.contains("thunar") || ln.contains("nautilus") {
        return "[]";
    }
    if ln.contains("mixer") || ln.contains("pavucontrol") || ln.contains("audio") || ln.contains("spotify") || ln.contains("vlc") || ln.contains("mpv") {
        return "dB";
    }
    if ln.contains("steam") || ln.contains("lutris") || ln.contains("prism") || ln.contains("minecraft") {
        return "++";
    }
    match category {
        "Network" => "WW",
        "Game" => "++",
        "AudioVideo" | "Audio" | "Video" => "dB",
        "Development" => "<>",
        "Graphics" | "Office" => "::",
        "Settings" => "**",
        "System" => ">_",
        _ => "::",
    }
}

fn parse_desktop_file(path: &Path) -> Option<AppEntry> {
    let raw = fs::read_to_string(path).ok()?;
    let mut in_main = false;
    let mut app_type = String::new();
    let mut name = String::new();
    let mut exec = String::new();
    let mut categories = String::new();
    let mut no_display = false;
    let mut hidden = false;

    for line in raw.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') {
            continue;
        }
        if trimmed.starts_with('[') && trimmed.ends_with(']') {
            in_main = trimmed == "[Desktop Entry]";
            continue;
        }
        if !in_main {
            continue;
        }
        let Some((k, v)) = trimmed.split_once('=') else {
            continue;
        };
        let key = k.trim();
        let val = v.trim();
        match key {
            "Type" => app_type = val.to_string(),
            "Name" if name.is_empty() => name = val.to_string(),
            "Exec" if exec.is_empty() => exec = strip_exec_codes(val),
            "Categories" if categories.is_empty() => categories = val.to_string(),
            "NoDisplay" => no_display = val.eq_ignore_ascii_case("true"),
            "Hidden" => hidden = val.eq_ignore_ascii_case("true"),
            _ => {}
        }
    }

    if app_type != "Application" || no_display || hidden || name.is_empty() || exec.is_empty() {
        return None;
    }
    let category = normalize_category(&categories);
    let glyph = pick_ascii_glyph(&name, &category, &exec).to_string();
    Some(AppEntry { name, exec, category, glyph })
}

pub fn handle_apps_cmd() -> String {
    let home = home_dir();
    let dirs = [
        PathBuf::from("/usr/share/applications"),
        home.join(".local/share/applications"),
    ];

    let mut by_file: BTreeMap<String, AppEntry> = BTreeMap::new();
    for dir in &dirs {
        let Ok(rd) = fs::read_dir(dir) else {
            continue;
        };
        for entry in rd.flatten() {
            let path = entry.path();
            if path.extension().and_then(|s| s.to_str()) != Some("desktop") {
                continue;
            }
            if let Some(fname) = path.file_name().and_then(|s| s.to_str()) {
                if let Some(app) = parse_desktop_file(&path) {
                    by_file.insert(fname.to_string(), app);
                } else {
                    by_file.remove(fname);
                }
            }
        }
    }

    let mut apps: Vec<AppEntry> = by_file.into_values().collect();
    apps.sort_by_key(|a| a.name.to_ascii_lowercase());

    let mut out = String::from("[");
    for (i, a) in apps.iter().enumerate() {
        if i > 0 {
            out.push(',');
        }
        out.push_str(&format!(
            "{{\"name\":{},\"exec\":{},\"category\":{},\"glyph\":{}}}",
            escape_str(&a.name),
            escape_str(&a.exec),
            escape_str(&a.category),
            escape_str(&a.glyph)
        ));
    }
    out.push(']');
    out
}
