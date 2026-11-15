use crate::hardware::{
    is_onkyo_monitor as hw_is_onkyo_monitor, load_hardware_profile,
    terminal_plasma_outputs_conf_path, HardwareProfile, LEGACY_ONKYO_SINK_FALLBACK,
    LEGACY_ONKYO_SINK_NAME,
};
use crate::json::{self, escape_str};
use crate::theme::{atomic_write, config_dir};
use std::collections::{BTreeMap, HashMap};
use std::env;
use std::fs;
use std::path::PathBuf;
use std::process::Command;

#[derive(Debug, Clone)]
pub struct MonitorConfig {
    pub name: String,
    pub description: String,
    pub width: i64,
    pub height: i64,
    pub refresh: f64,
    pub x: i64,
    pub y: i64,
    pub rotation: i64,
    pub scale: f64,
    pub primary: bool,
    pub enabled: bool,
    pub available_modes: Vec<String>,
    pub onkyo_avr: bool,
}

fn monitors_json_path() -> PathBuf {
    config_dir().join("monitors.json")
}

fn outputs_conf_path() -> PathBuf {
    terminal_plasma_outputs_conf_path()
}

fn friendly_desc_for(name: &str) -> Option<&'static str> {
    if !outputs_conf_path().exists() {
        return None;
    }
    match name {
        "DP-2" => Some("AOC 24P1W1"),
        "DP-3" => Some("Hewlett Packard LA1905"),
        "HDMI-A-1" => Some("ONKYO Corporation HT-R758 (AVR)"),
        "DVI-I-1" => Some("Ancor Communications Inc MB169B+"),
        _ => None,
    }
}

fn is_onkyo_monitor(name: &str, desc: &str, profile: &HardwareProfile) -> bool {
    hw_is_onkyo_monitor(name, desc, profile)
}

pub fn has_onkyo_monitor_hint() -> bool {
    let profile = load_hardware_profile();
    if profile.onkyo_output.is_some() {
        return true;
    }
    if let Ok(raw) = fs::read_to_string(monitors_json_path()) {
        if let Ok(mons) = parse_monitors_json(&raw) {
            if mons.iter().any(|m| {
                m.onkyo_avr
                    && (m.description.to_ascii_uppercase().contains("ONKYO")
                        || m.description.to_ascii_uppercase().contains("HT-R758")
                        || crate::hardware::outputs_conf_has_onkyo())
            }) {
                return true;
            }
        }
    }
    false
}

fn default_modes_for(name: &str, w: i64, h: i64, hz: f64) -> Vec<String> {
    let base: Vec<&str> = if outputs_conf_path().exists() {
        match name {
            "DP-2" => vec![
                "1920x1080@60.00",
                "1920x1080@59.94",
                "1920x1080@50.00",
                "1680x1050@59.95",
                "1280x1024@75.03",
                "1280x1024@60.02",
                "1440x900@59.89",
                "1280x720@60.00",
            ],
            "DP-3" => vec![
                "1440x900@59.89",
                "1280x1024@60.02",
                "1280x960@60.00",
                "1024x768@60.00",
                "800x600@60.32",
                "640x480@59.94",
            ],
            "HDMI-A-1" => vec![
                "1920x1080@60.00",
                "1920x1080@74.97",
                "1920x1080@59.94",
                "1920x1080@50.00",
                "1680x1050@59.95",
                "1600x900@60.00",
                "1280x720@60.00",
            ],
            "DVI-I-1" => vec![
                "1920x1080@60.01",
                "1280x1024@75.03",
                "1280x1024@60.02",
                "1366x768@60.00",
                "1024x768@75.03",
                "1024x768@60.00",
            ],
            _ => vec![],
        }
    } else {
        vec![]
    };
    let mut out: Vec<String> = base.into_iter().map(|s| s.to_string()).collect();
    let cur = format!("{w}x{h}@{hz:.2}");
    if !out.contains(&cur) {
        out.insert(0, cur);
    }
    out
}

fn generic_fallback_monitors() -> Vec<MonitorConfig> {
    vec![MonitorConfig {
        name: "Wayland-1".to_string(),
        description: "ASCII-DE Virtual Display".to_string(),
        width: 1920,
        height: 1080,
        refresh: 60.0,
        x: 0,
        y: 0,
        rotation: 0,
        scale: 1.0,
        primary: true,
        enabled: true,
        available_modes: vec![
            "1920x1080@60.00".to_string(),
            "1600x900@60.00".to_string(),
            "1280x720@60.00".to_string(),
        ],
        onkyo_avr: false,
    }]
}

fn parse_rotation_str(rot: &str) -> i64 {
    match rot.trim().to_ascii_lowercase().as_str() {
        "left" | "90" => 90,
        "inverted" | "180" => 180,
        "right" | "270" => 270,
        _ => 0,
    }
}

fn kscreen_rot_word(deg: i64) -> &'static str {
    match normalize_rotation(deg) {
        90 => "left",
        180 => "inverted",
        270 => "right",
        _ => "none",
    }
}

fn normalize_rotation(deg: i64) -> i64 {
    match deg.rem_euclid(360) {
        90 => 90,
        180 => 180,
        270 => 270,
        _ => 0,
    }
}

fn read_outputs_conf() -> Option<Vec<MonitorConfig>> {
    let profile = load_hardware_profile();
    let raw = fs::read_to_string(outputs_conf_path()).ok()?;
    let mut primary_name = String::new();
    let mut specs = Vec::new();
    let mut in_specs = false;

    for line in raw.lines() {
        let t = line.trim();
        if t.starts_with("PRIMARY_OUTPUT=") {
            primary_name = t
                .trim_start_matches("PRIMARY_OUTPUT=")
                .trim()
                .trim_matches('"')
                .to_string();
        } else if t.starts_with("OUTPUT_SPECS=(") {
            in_specs = true;
        } else if in_specs {
            if t == ")" {
                in_specs = false;
                continue;
            }
            if t.starts_with('#') || t.is_empty() {
                continue;
            }
            let entry = t.trim_matches('"');
            let parts: Vec<&str> = entry.splitn(9, '|').collect();
            if parts.len() == 9 {
                let name = parts[0].to_string();
                let width = parts[1].parse::<i64>().unwrap_or(1920);
                let height = parts[2].parse::<i64>().unwrap_or(1080);
                let refresh = parts[3].parse::<f64>().unwrap_or(60.0);
                let mut xy = parts[4].split(',');
                let x = xy.next().and_then(|s| s.parse::<i64>().ok()).unwrap_or(0);
                let y = xy.next().and_then(|s| s.parse::<i64>().ok()).unwrap_or(0);
                let rotation = parse_rotation_str(parts[5]);
                let scale = parts[6].parse::<f64>().unwrap_or(1.0);
                let prio = parts[7].parse::<i64>().unwrap_or(99);
                let desc = parts[8].to_string();
                let onkyo_avr = is_onkyo_monitor(&name, &desc, &profile);
                let primary = (!primary_name.is_empty() && name == primary_name) || prio == 1;
                specs.push(MonitorConfig {
                    available_modes: default_modes_for(&name, width, height, refresh),
                    name,
                    description: desc,
                    width,
                    height,
                    refresh,
                    x,
                    y,
                    rotation,
                    scale,
                    primary,
                    enabled: true,
                    onkyo_avr,
                });
            }
        }
    }

    if specs.is_empty() {
        None
    } else {
        Some(specs)
    }
}

fn is_kscreen_active() -> bool {
    Command::new("kscreen-doctor")
        .arg("-o")
        .output()
        .ok()
        .map(|o| o.status.success() && String::from_utf8_lossy(&o.stdout).contains("Output:"))
        .unwrap_or(false)
}

type KscreenModeMap = HashMap<String, Vec<(String, i64, i64, f64)>>;

fn query_kscreen_live() -> Option<(Vec<MonitorConfig>, KscreenModeMap)> {
    if !is_kscreen_active() {
        return None;
    }
    let out = Command::new("kscreen-doctor").arg("-j").output().ok()?;
    if !out.status.success() {
        return None;
    }
    let text = String::from_utf8_lossy(&out.stdout);
    let parsed = json::parse(&text).ok()?;
    let outputs = parsed.get("outputs")?.as_arr()?;
    if outputs.is_empty() {
        return None;
    }

    let profile = load_hardware_profile();
    let mut monitors = Vec::new();
    let mut mode_ids: HashMap<String, Vec<(String, i64, i64, f64)>> = HashMap::new();

    for item in outputs {
        let connected = item.get("connected").and_then(|v| v.as_bool()).unwrap_or(true);
        if !connected {
            continue;
        }
        let name = item.get("name").and_then(|v| v.as_str()).unwrap_or("").to_string();
        if name.is_empty() {
            continue;
        }
        let desc = item
            .get("model")
            .and_then(|v| v.as_str())
            .filter(|s| !s.is_empty())
            .or_else(|| friendly_desc_for(&name))
            .unwrap_or(&name)
            .to_string();
        let enabled = item.get("enabled").and_then(|v| v.as_bool()).unwrap_or(true);
        let scale = item.get("scale").and_then(|v| v.as_f64()).unwrap_or(1.0);
        let prio = item.get("priority").and_then(|v| v.as_i64()).unwrap_or(99);
        let rot_raw = item.get("rotation").and_then(|v| v.as_i64()).unwrap_or(1);
        let rotation = match rot_raw {
            2 => 90,
            4 => 180,
            8 => 270,
            _ => 0,
        };
        let pos = item.get("pos");
        let x = pos.and_then(|p| p.get("x")).and_then(|v| v.as_i64()).unwrap_or(0);
        let y = pos.and_then(|p| p.get("y")).and_then(|v| v.as_i64()).unwrap_or(0);
        let cur_mode_id = item
            .get("currentModeId")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();

        let mut width = 1920i64;
        let mut height = 1080i64;
        let mut refresh = 60.0f64;
        let mut avail = Vec::new();
        let mut raw_modes = Vec::new();

        if let Some(modes) = item.get("modes").and_then(|v| v.as_arr()) {
            for m in modes {
                let mid = m.get("id").and_then(|v| v.as_str()).unwrap_or("").to_string();
                let sz = m.get("size");
                let mw = sz.and_then(|s| s.get("width")).and_then(|v| v.as_i64()).unwrap_or(0);
                let mh = sz.and_then(|s| s.get("height")).and_then(|v| v.as_i64()).unwrap_or(0);
                let mut mhz = m.get("refreshRate").and_then(|v| v.as_f64()).unwrap_or(60.0);
                if mhz > 1000.0 {
                    mhz /= 1000.0;
                }
                if mw > 0 && mh > 0 {
                    let label = format!("{mw}x{mh}@{mhz:.2}");
                    if !avail.contains(&label) {
                        avail.push(label);
                    }
                    if !mid.is_empty() {
                        raw_modes.push((mid.clone(), mw, mh, mhz));
                    }
                    if mid == cur_mode_id {
                        width = mw;
                        height = mh;
                        refresh = mhz;
                    }
                }
            }
        }
        if avail.is_empty() {
            avail = default_modes_for(&name, width, height, refresh);
        }
        mode_ids.insert(name.clone(), raw_modes);
        let onkyo_avr = is_onkyo_monitor(&name, &desc, &profile);
        monitors.push(MonitorConfig {
            name,
            description: desc,
            width,
            height,
            refresh,
            x,
            y,
            rotation,
            scale,
            primary: prio == 1,
            enabled,
            available_modes: avail,
            onkyo_avr,
        });
    }

    if monitors.is_empty() {
        None
    } else {
        Some((monitors, mode_ids))
    }
}

fn find_hypr_signature() -> Option<String> {
    if let Ok(sig) = env::var("HYPRLAND_INSTANCE_SIGNATURE") {
        if !sig.is_empty() {
            return Some(sig);
        }
    }
    let runtime = env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/run/user/1000".to_string());
    let hypr_dir = PathBuf::from(runtime).join("hypr");
    let rd = fs::read_dir(hypr_dir).ok()?;
    for entry in rd.flatten() {
        let sock = entry.path().join(".socket.sock");
        if sock.exists() {
            if let Some(name) = entry.file_name().to_str() {
                return Some(name.to_string());
            }
        }
    }
    None
}

fn query_hyprctl_live() -> Option<Vec<MonitorConfig>> {
    let mut cmd = Command::new("hyprctl");
    cmd.args(["monitors", "-j"]);
    if let Some(sig) = find_hypr_signature() {
        cmd.env("HYPRLAND_INSTANCE_SIGNATURE", sig);
    }
    let out = cmd.output().ok()?;
    if !out.status.success() {
        return None;
    }
    let text = String::from_utf8_lossy(&out.stdout);
    let parsed = json::parse(&text).ok()?;
    let arr = parsed.as_arr()?;
    if arr.is_empty() {
        return None;
    }

    let profile = load_hardware_profile();
    let mut monitors = Vec::new();
    for item in arr {
        let name = item.get("name").and_then(|v| v.as_str()).unwrap_or("").to_string();
        if name.is_empty() {
            continue;
        }
        let desc = item
            .get("description")
            .and_then(|v| v.as_str())
            .unwrap_or(&name)
            .to_string();
        let width = item.get("width").and_then(|v| v.as_i64()).unwrap_or(1920);
        let height = item.get("height").and_then(|v| v.as_i64()).unwrap_or(1080);
        let refresh = item.get("refreshRate").and_then(|v| v.as_f64()).unwrap_or(60.0);
        let x = item.get("x").and_then(|v| v.as_i64()).unwrap_or(0);
        let y = item.get("y").and_then(|v| v.as_i64()).unwrap_or(0);
        let scale = item.get("scale").and_then(|v| v.as_f64()).unwrap_or(1.0);
        let transform = item.get("transform").and_then(|v| v.as_i64()).unwrap_or(0);
        let rotation = match transform % 4 {
            1 => 90,
            2 => 180,
            3 => 270,
            _ => 0,
        };
        let disabled = item.get("disabled").and_then(|v| v.as_bool()).unwrap_or(false);

        let mut avail = Vec::new();
        if let Some(modes) = item.get("availableModes").and_then(|v| v.as_arr()) {
            for m in modes {
                if let Some(s) = m.as_str() {
                    let clean = s.trim().trim_end_matches("Hz").to_string();
                    if !clean.is_empty() && !avail.contains(&clean) {
                        avail.push(clean);
                    }
                }
            }
        }
        if avail.is_empty() {
            avail = default_modes_for(&name, width, height, refresh);
        }

        let onkyo_avr = is_onkyo_monitor(&name, &desc, &profile);
        let primary = profile
            .preferred_primary
            .as_deref()
            .map(|p| p == name)
            .unwrap_or(false);
        monitors.push(MonitorConfig {
            name,
            description: desc,
            width,
            height,
            refresh,
            x,
            y,
            rotation,
            scale,
            primary,
            enabled: !disabled,
            available_modes: avail,
            onkyo_avr,
        });
    }

    if monitors.is_empty() {
        None
    } else {
        Some(monitors)
    }
}

fn normalize_primary(mut list: Vec<MonitorConfig>, profile: &HardwareProfile) -> Vec<MonitorConfig> {
    // Never default Onkyo AVR as primary when non-Onkyo outputs are enabled
    let has_non_onkyo = list.iter().any(|m| m.enabled && !m.onkyo_avr);
    if has_non_onkyo && list.iter().any(|m| m.primary && m.onkyo_avr) {
        for m in &mut list {
            m.primary = false;
        }
    }
    if !list.iter().any(|m| m.primary && m.enabled) {
        if let Some(pref) = profile.preferred_primary.as_deref() {
            if let Some(m) = list.iter_mut().find(|m| m.name == pref && m.enabled) {
                m.primary = true;
                return list;
            }
        }
        if let Some(first) = list.iter_mut().find(|m| m.enabled && !m.onkyo_avr) {
            first.primary = true;
        } else if let Some(first) = list.iter_mut().find(|m| m.enabled) {
            first.primary = true;
        }
    }
    list
}

fn query_live_monitors() -> Option<Vec<MonitorConfig>> {
    if let Some((live, _)) = query_kscreen_live() {
        return Some(live);
    }
    query_hyprctl_live()
}

fn discover_live_or_conf() -> Vec<MonitorConfig> {
    let profile = load_hardware_profile();
    if let Some(mut live) = query_live_monitors() {
        if profile.keep_offline_monitors {
            if let Some(conf) = read_outputs_conf() {
                let shares_host = live.iter().any(|m| conf.iter().any(|c| c.name == m.name));
                if shares_host {
                    for fb in conf {
                        if !live.iter().any(|m| m.name == fb.name) {
                            live.push(fb);
                        }
                    }
                }
            }
        }
        return normalize_primary(live, &profile);
    }
    if let Some(conf) = read_outputs_conf() {
        return normalize_primary(conf, &profile);
    }
    generic_fallback_monitors()
}

fn parse_monitors_json(raw: &str) -> Result<Vec<MonitorConfig>, String> {
    let profile = load_hardware_profile();
    let val = json::parse(raw)?;
    let arr = val
        .as_arr()
        .ok_or_else(|| "monitors payload must be a JSON array".to_string())?;
    let mut out = Vec::with_capacity(arr.len());
    for item in arr {
        let name = item
            .get("name")
            .and_then(|v| v.as_str())
            .ok_or_else(|| "monitor missing name".to_string())?
            .to_string();
        if name.is_empty() {
            return Err("monitor name cannot be empty".to_string());
        }
        let desc = item
            .get("description")
            .and_then(|v| v.as_str())
            .unwrap_or(&name)
            .to_string();
        let width = item.get("width").and_then(|v| v.as_i64()).unwrap_or(1920).max(320);
        let height = item.get("height").and_then(|v| v.as_i64()).unwrap_or(1080).max(240);
        let refresh = item.get("refresh").and_then(|v| v.as_f64()).unwrap_or(60.0);
        let x = item.get("x").and_then(|v| v.as_i64()).unwrap_or(0);
        let y = item.get("y").and_then(|v| v.as_i64()).unwrap_or(0);
        let rotation = normalize_rotation(item.get("rotation").and_then(|v| v.as_i64()).unwrap_or(0));
        let scale = item
            .get("scale")
            .and_then(|v| v.as_f64())
            .unwrap_or(1.0)
            .clamp(0.5, 4.0);
        let primary = item.get("primary").and_then(|v| v.as_bool()).unwrap_or(false);
        let enabled = item.get("enabled").and_then(|v| v.as_bool()).unwrap_or(true);

        let mut available_modes = Vec::new();
        if let Some(modes) = item.get("available_modes").and_then(|v| v.as_arr()) {
            for m in modes {
                if let Some(s) = m.as_str() {
                    available_modes.push(s.to_string());
                }
            }
        }
        if available_modes.is_empty() {
            available_modes = default_modes_for(&name, width, height, refresh);
        }
        let onkyo_avr = item
            .get("onkyo_avr")
            .and_then(|v| v.as_bool())
            .unwrap_or_else(|| is_onkyo_monitor(&name, &desc, &profile));

        out.push(MonitorConfig {
            name,
            description: desc,
            width,
            height,
            refresh,
            x,
            y,
            rotation,
            scale,
            primary,
            enabled,
            available_modes,
            onkyo_avr,
        });
    }

    if out.is_empty() {
        return Err("monitor array cannot be empty".to_string());
    }

    // Ensure exactly one enabled monitor is primary
    let mut seen_primary = false;
    for m in &mut out {
        if m.primary && m.enabled && !seen_primary {
            seen_primary = true;
        } else {
            m.primary = false;
        }
    }
    if !seen_primary {
        if let Some(pref) = profile.preferred_primary.as_deref() {
            if let Some(m) = out.iter_mut().find(|m| m.name == pref && m.enabled) {
                m.primary = true;
                return Ok(out);
            }
        }
        if let Some(first) = out.iter_mut().find(|m| m.enabled && !m.onkyo_avr) {
            first.primary = true;
        } else if let Some(first) = out.iter_mut().find(|m| m.enabled) {
            first.primary = true;
        }
    }

    Ok(out)
}

fn format_scale(s: f64) -> String {
    if (s - s.round()).abs() < 0.001 {
        format!("{}", s.round() as i64)
    } else {
        let formatted = format!("{s:.2}");
        formatted.trim_end_matches('0').trim_end_matches('.').to_string()
    }
}

pub fn serialize_monitors(monitors: &[MonitorConfig]) -> String {
    let mut out = String::from("[\n");
    for (i, m) in monitors.iter().enumerate() {
        let mut modes_json = String::from("[");
        for (mi, mode) in m.available_modes.iter().enumerate() {
            if mi > 0 {
                modes_json.push(',');
            }
            modes_json.push_str(&escape_str(mode));
        }
        modes_json.push(']');

        out.push_str(&format!(
            "  {{\"name\":{},\"description\":{},\"width\":{},\"height\":{},\"refresh\":{:.2},\"x\":{},\"y\":{},\"rotation\":{},\"scale\":{},\"primary\":{},\"enabled\":{},\"available_modes\":{},\"onkyo_avr\":{}}}",
            escape_str(&m.name),
            escape_str(&m.description),
            m.width,
            m.height,
            m.refresh,
            m.x,
            m.y,
            m.rotation,
            format_scale(m.scale),
            m.primary,
            m.enabled,
            modes_json,
            m.onkyo_avr
        ));
        if i + 1 < monitors.len() {
            out.push(',');
        }
        out.push('\n');
    }
    out.push(']');
    out
}

fn sync_outputs_conf(monitors: &[MonitorConfig]) -> Result<(), String> {
    let profile = load_hardware_profile();
    if !profile.sync_terminal_plasma_outputs {
        return Ok(());
    }
    let path = outputs_conf_path();
    let existing = fs::read_to_string(&path).unwrap_or_default();

    // Preserve audio guard tail section (everything from `# PipeWire / WirePlumber` onward)
    let audio_tail = existing
        .find("# PipeWire / WirePlumber")
        .map(|idx| existing[idx..].to_string())
        .unwrap_or_else(|| {
            format!(
                "# PipeWire / WirePlumber runtime targets (never modifies ~/.config/wireplumber/)\n\
                 ONKYO_SINK_NAME=\"{LEGACY_ONKYO_SINK_NAME}\"\n\
                 ONKYO_SINK_FALLBACK=\"{LEGACY_ONKYO_SINK_FALLBACK}\"\n\
                 ONKYO_SINK_DESC=\"Onkyo HT-R758 Surround 5.1 (HDMI)\"\n\n\
                 BT_HEADPHONE_PREFIX=\"bluez_output.\"\n"
            )
        });

    let primary_name = monitors
        .iter()
        .find(|m| m.primary && m.enabled)
        .or_else(|| monitors.iter().find(|m| m.enabled))
        .map(|m| m.name.as_str())
        .unwrap_or("");

    let mut ordered: Vec<&MonitorConfig> = monitors.iter().filter(|m| m.enabled).collect();
    ordered.sort_by_key(|m| if m.name == primary_name { 0 } else { 1 });

    let mut body = String::from(
        "# Terminal Plasma — Declarative Multi-Monitor & Audio Guard Profile\n\
         # Synced by ascii-de-backend displays save\n\n",
    );
    body.push_str(&format!("PRIMARY_OUTPUT=\"{primary_name}\"\n\n"));
    body.push_str("# Output specs: \"NAME|WIDTH|HEIGHT|REFRESH|POS_X,POS_Y|ROTATION|SCALE|PRIORITY|DESC\"\n");
    body.push_str("# Rotation values for kscreen-doctor: none, left, right, inverted\n");
    body.push_str("OUTPUT_SPECS=(\n");
    for (idx, m) in ordered.iter().enumerate() {
        let prio = idx + 1;
        let rot_word = kscreen_rot_word(m.rotation);
        let scale_str = format_scale(m.scale);
        let clean_desc = m.description.replace('"', "'").replace('|', "/");
        body.push_str(&format!(
            "  \"{}|{}|{}|{:.2}|{},{}|{}|{}|{}|{}\"\n",
            m.name, m.width, m.height, m.refresh, m.x, m.y, rot_word, scale_str, prio, clean_desc
        ));
    }
    body.push_str(")\n\n");
    body.push_str(&audio_tail);

    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|e| format!("mkdir {}: {e}", parent.display()))?;
    }
    let tmp = path.with_extension("conf.tmp");
    fs::write(&tmp, body).map_err(|e| format!("write {}: {e}", tmp.display()))?;
    fs::rename(&tmp, &path).map_err(|e| format!("rename {}: {e}", path.display()))?;
    Ok(())
}

fn load_or_seed_monitors() -> Result<Vec<MonitorConfig>, String> {
    let path = monitors_json_path();
    let profile = load_hardware_profile();
    let live_hw = query_live_monitors();
    let live = discover_live_or_conf();

    if path.exists() {
        if let Ok(raw) = fs::read_to_string(&path) {
            if let Ok(mut saved) = parse_monitors_json(&raw) {
                if let Some(ref hw) = live_hw {
                    let has_overlap = saved.iter().any(|s| hw.iter().any(|l| l.name == s.name));
                    if !has_overlap {
                        let serialized = serialize_monitors(&live);
                        atomic_write(&path, &(serialized + "\n"))?;
                        return Ok(live);
                    }
                    if !profile.keep_offline_monitors {
                        saved.retain(|s| hw.iter().any(|l| l.name == s.name));
                    }
                }
                let live_map: BTreeMap<String, &MonitorConfig> =
                    live.iter().map(|m| (m.name.clone(), m)).collect();
                for m in &mut saved {
                    if let Some(lm) = live_map.get(&m.name) {
                        if !lm.available_modes.is_empty() {
                            m.available_modes = lm.available_modes.clone();
                        }
                        if m.description == m.name {
                            m.description = lm.description.clone();
                        }
                    }
                }
                for lm in &live {
                    if !saved.iter().any(|m| m.name == lm.name) {
                        saved.push(lm.clone());
                    }
                }
                return Ok(normalize_primary(saved, &profile));
            }
        }
    }

    let serialized = serialize_monitors(&live);
    atomic_write(&path, &(serialized + "\n"))?;
    Ok(live)
}

pub fn build_kscreen_args(
    monitors: &[MonitorConfig],
    live_names: &[&str],
    mode_ids: &HashMap<String, Vec<(String, i64, i64, f64)>>,
) -> Vec<String> {
    let mut args: Vec<String> = Vec::new();
    let mut prio = 1usize;
    let mut assigned_primary = false;

    for m in monitors {
        if !live_names.contains(&m.name.as_str()) {
            continue;
        }
        // Protect Onkyo AVR HDMI-A-1 audio handshake
        let effective_enabled = if m.onkyo_avr { true } else { m.enabled };
        if !effective_enabled {
            args.push(format!("output.{}.disable", m.name));
            continue;
        }
        args.push(format!("output.{}.enable", m.name));

        let mut best_id: Option<String> = None;
        let mut best_diff = 9999.0f64;
        if let Some(modes) = mode_ids.get(&m.name) {
            for (mid, mw, mh, mhz) in modes {
                if *mw == m.width && *mh == m.height {
                    let diff = (*mhz - m.refresh).abs();
                    if diff < best_diff {
                        best_diff = diff;
                        best_id = Some(mid.clone());
                    }
                }
            }
        }
        if let Some(mid) = best_id {
            args.push(format!("output.{}.mode.{mid}", m.name));
        } else {
            args.push(format!(
                "output.{}.mode.{}x{}@{}",
                m.name,
                m.width,
                m.height,
                m.refresh.round() as i64
            ));
        }
        args.push(format!("output.{}.position.{},{}", m.name, m.x, m.y));
        args.push(format!("output.{}.rotation.{}", m.name, kscreen_rot_word(m.rotation)));
        args.push(format!("output.{}.scale.{}", m.name, format_scale(m.scale)));
        // Plasma 6 / libkscreen 6.8+ uses output.<name>.priority.1; passing `.primary` can demote priority
        if m.primary && !assigned_primary {
            assigned_primary = true;
            args.push(format!("output.{}.priority.1", m.name));
        } else {
            prio += 1;
            args.push(format!("output.{}.priority.{prio}", m.name));
        }
    }

    args
}

fn apply_kscreen(monitors: &[MonitorConfig]) -> Result<bool, String> {
    if env::var("ASCII_DE_NESTED").ok().as_deref() == Some("1") {
        return Ok(false);
    }
    let Some((live, mode_ids)) = query_kscreen_live() else {
        return Ok(false);
    };
    let live_names: Vec<&str> = live.iter().map(|m| m.name.as_str()).collect();
    let args = build_kscreen_args(monitors, &live_names, &mode_ids);

    if args.is_empty() {
        return Ok(false);
    }

    let out = Command::new("kscreen-doctor")
        .args(&args)
        .output()
        .map_err(|e| format!("kscreen-doctor failed: {e}"))?;
    if !out.status.success() {
        let stderr = String::from_utf8_lossy(&out.stderr);
        return Err(format!("kscreen-doctor failed: {}", stderr.trim()));
    }
    Ok(true)
}

pub fn handle_displays_cmd(args: &[String]) -> Result<String, String> {
    let sub = args.first().map(|s| s.as_str()).unwrap_or("list");
    match sub {
        "list" => {
            let monitors = load_or_seed_monitors()?;
            Ok(serialize_monitors(&monitors))
        }
        "save" => {
            let payload = args
                .get(1)
                .ok_or_else(|| "displays save requires <json_array>".to_string())?;
            let monitors = parse_monitors_json(payload)?;
            let serialized = serialize_monitors(&monitors);
            atomic_write(&monitors_json_path(), &(serialized.clone() + "\n"))?;
            sync_outputs_conf(&monitors)?;
            Ok(serialized)
        }
        "apply" => {
            let monitors = load_or_seed_monitors()?;
            let applied_kwin = apply_kscreen(&monitors)?;
            let mon_json = serialize_monitors(&monitors);
            if applied_kwin {
                Ok(format!(
                    "{{\"status\":\"applied\",\"mode\":\"kwin\",\"monitors\":{mon_json}}}"
                ))
            } else {
                Ok(format!(
                    "{{\"status\":\"saved\",\"mode\":\"nested-preview\",\"monitors\":{mon_json}}}"
                ))
            }
        }
        "reset" => {
            let monitors = discover_live_or_conf();
            let serialized = serialize_monitors(&monitors);
            atomic_write(&monitors_json_path(), &(serialized.clone() + "\n"))?;
            Ok(serialized)
        }
        other => Err(format!("unknown displays subcommand: {other}")),
    }
}
