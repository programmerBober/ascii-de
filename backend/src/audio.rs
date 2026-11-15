use crate::hardware::{is_onkyo_sink, load_hardware_profile};
use crate::json::{self, escape_str};
use std::process::Command;

pub const BT_PREFIX: &str = "bluez_output.";

#[derive(Debug, Clone)]
pub struct SinkInfo {
    pub id: i64,
    pub wp_id: Option<String>,
    pub name: String,
    pub desc: String,
    pub vol: i64,
    pub muted: bool,
    pub is_default: bool,
}

#[derive(Debug, Clone)]
pub struct AudioSnapshot {
    pub audio_label: String,
    pub audio_vol: i64,
    pub audio_muted: bool,
    pub onkyo_active: bool,
    pub onkyo_detected: bool,
    pub sinks: Vec<SinkInfo>,
}

static AUDIO_CACHE: std::sync::Mutex<Option<(std::time::Instant, AudioSnapshot)>> = std::sync::Mutex::new(None);

pub fn invalidate_audio_cache() {
    if let Ok(mut guard) = AUDIO_CACHE.lock() {
        *guard = None;
    }
}

pub fn query_audio() -> AudioSnapshot {
    if let Ok(guard) = AUDIO_CACHE.lock() {
        if let Some((ts, ref snap)) = *guard {
            if ts.elapsed() < std::time::Duration::from_millis(2500) {
                return snap.clone();
            }
        }
    }
    let snap = query_audio_fresh();
    if let Ok(mut guard) = AUDIO_CACHE.lock() {
        *guard = Some((std::time::Instant::now(), snap.clone()));
    }
    snap
}

fn query_audio_fresh() -> AudioSnapshot {
    let default_name = Command::new("pactl")
        .args(["get-default-sink"])
        .output()
        .ok()
        .and_then(|o| {
            if o.status.success() {
                Some(String::from_utf8_lossy(&o.stdout).trim().to_string())
            } else {
                None
            }
        })
        .unwrap_or_default();

    let raw_json = Command::new("pactl")
        .args(["-f", "json", "list", "sinks"])
        .output()
        .ok()
        .and_then(|o| {
            if o.status.success() {
                Some(String::from_utf8_lossy(&o.stdout).to_string())
            } else {
                None
            }
        })
        .unwrap_or_else(|| "[]".to_string());

    let mut sinks = Vec::new();
    if let Ok(parsed) = json::parse(&raw_json) {
        if let Some(arr) = parsed.as_arr() {
            for item in arr {
                let id = item.get("index").and_then(|v| v.as_i64()).unwrap_or(0);
                let name = item
                    .get("name")
                    .and_then(|v| v.as_str())
                    .unwrap_or("")
                    .to_string();
                let props = item.get("properties");
                let wp_id = props
                    .and_then(|p| p.get("object.id"))
                    .and_then(|v| v.as_str())
                    .map(|s| s.to_string());
                let desc = item
                    .get("description")
                    .and_then(|v| v.as_str())
                    .or_else(|| props.and_then(|p| p.get("node.description")).and_then(|v| v.as_str()))
                    .unwrap_or(&name)
                    .to_string();
                let muted = item.get("mute").and_then(|v| v.as_bool()).unwrap_or(false);
                let vol = extract_vol_pct(item);
                let is_default = !default_name.is_empty() && name == default_name;
                sinks.push(SinkInfo {
                    id,
                    wp_id,
                    name,
                    desc,
                    vol,
                    muted,
                    is_default,
                });
            }
        }
    }

    let profile = load_hardware_profile();
    let onkyo_detected = sinks
        .iter()
        .any(|s| is_onkyo_sink(&s.name, &s.desc, &profile));

    let mut audio_label = "NO AUDIO SINK".to_string();
    let mut audio_vol = 0;
    let mut audio_muted = false;
    let mut onkyo_active = false;

    if let Some(def) = sinks.iter().find(|s| s.is_default) {
        audio_vol = def.vol;
        audio_muted = def.muted;
        if is_onkyo_sink(&def.name, &def.desc, &profile) {
            audio_label = "ONKYO 5.1".to_string();
            onkyo_active = true;
        } else if def.name.starts_with(BT_PREFIX) {
            audio_label = format!("BT:{}", def.desc);
        } else if def.name.contains("snd_aloop") {
            audio_label = "LOOPBACK".to_string();
        } else {
            audio_label = def.desc.clone();
        }
    }

    AudioSnapshot {
        audio_label,
        audio_vol,
        audio_muted,
        onkyo_active,
        onkyo_detected,
        sinks,
    }
}

fn extract_vol_pct(item: &json::JsonVal) -> i64 {
    let Some(vol_obj) = item.get("volume").and_then(|v| v.as_obj()) else {
        return 0;
    };
    let mut sum = 0i64;
    let mut count = 0i64;
    for ch in vol_obj.values() {
        if let Some(vp) = ch.get("value_percent").and_then(|v| v.as_str()) {
            let trimmed = vp.trim().trim_end_matches('%');
            if let Ok(n) = trimmed.parse::<i64>() {
                sum += n;
                count += 1;
            }
        }
    }
    if count == 0 {
        0
    } else {
        (sum + count / 2) / count
    }
}

pub fn sinks_to_json(sinks: &[SinkInfo]) -> String {
    let mut out = String::from("[");
    for (i, s) in sinks.iter().enumerate() {
        if i > 0 {
            out.push(',');
        }
        out.push_str(&format!(
            "{{\"id\":{},\"name\":{},\"desc\":{},\"vol\":{},\"muted\":{},\"default\":{}}}",
            s.id,
            escape_str(&s.name),
            escape_str(&s.desc),
            s.vol,
            s.muted,
            s.is_default
        ));
    }
    out.push(']');
    out
}

fn switch_to_sink(sink: &SinkInfo) {
    if let Some(wp_id) = &sink.wp_id {
        let _ = Command::new("wpctl").args(["set-default", wp_id]).status();
    }
    let _ = Command::new("pactl")
        .args(["set-default-sink", &sink.name])
        .status();
    let _ = Command::new("pactl")
        .args(["set-sink-mute", &sink.name, "0"])
        .status();

    let meta_json = format!("{{\"name\":{}}}", escape_str(&sink.name));
    for key in ["default.audio.sink", "default.configured.audio.sink"] {
        let _ = Command::new("pw-metadata")
            .args(["-n", "default", "0", key, &meta_json, "Spa:String:JSON"])
            .status();
    }

    if let Ok(out) = Command::new("pactl")
        .args(["list", "sink-inputs", "short"])
        .output()
    {
        if out.status.success() {
            let text = String::from_utf8_lossy(&out.stdout);
            for line in text.lines() {
                if let Some(stream_id) = line.split_whitespace().next() {
                    let _ = Command::new("pactl")
                        .args(["move-sink-input", stream_id, &sink.name])
                        .status();
                }
            }
        }
    }
}

fn run_wpctl(args: &[&str]) -> Result<(), String> {
    let out = Command::new("wpctl")
        .args(args)
        .output()
        .map_err(|e| format!("failed to run wpctl: {e}"))?;
    if !out.status.success() {
        let err = String::from_utf8_lossy(&out.stderr).trim().to_string();
        return Err(if err.is_empty() {
            format!("wpctl exited with status {}", out.status.code().unwrap_or(-1))
        } else {
            format!("wpctl failed: {err}")
        });
    }
    Ok(())
}

pub fn format_wpctl_vol_arg(val: &str) -> Result<String, String> {
    let trimmed = val.trim();
    if trimmed.is_empty() {
        return Err("audio vol requires <+5%|-5%|80%>".to_string());
    }
    if let Some(rest) = trimmed.strip_prefix('+') {
        if rest.is_empty() {
            return Err("invalid volume delta: +".to_string());
        }
        Ok(format!("{rest}+"))
    } else if let Some(rest) = trimmed.strip_prefix('-') {
        if rest.is_empty() {
            return Err("invalid volume delta: -".to_string());
        }
        Ok(format!("{rest}-"))
    } else {
        Ok(trimmed.to_string())
    }
}

pub fn handle_audio_cmd(args: &[String]) -> Result<String, String> {
    if args.is_empty() {
        return Err("usage: ascii-de-backend audio <vol|mute|onkyo|bt|toggle|set-sink> ...".to_string());
    }
    match args[0].as_str() {
        "vol" => {
            let val = args.get(1).ok_or_else(|| "audio vol requires <+5%|-5%|80%>".to_string())?;
            let wp_arg = format_wpctl_vol_arg(val)?;
            if val.trim().starts_with('-') {
                run_wpctl(&["set-volume", "@DEFAULT_AUDIO_SINK@", &wp_arg])?;
            } else {
                run_wpctl(&["set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", &wp_arg])?;
            }
        }
        "mute" => {
            run_wpctl(&["set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])?;
        }
        "onkyo" => {
            let profile = load_hardware_profile();
            let snap = query_audio();
            let target = snap
                .sinks
                .iter()
                .find(|s| is_onkyo_sink(&s.name, &s.desc, &profile))
                .ok_or_else(|| "Onkyo HT-R758 sink not found".to_string())?;
            switch_to_sink(target);
        }
        "bt" | "headphones" => {
            let snap = query_audio();
            let target = snap
                .sinks
                .iter()
                .find(|s| s.name.starts_with(BT_PREFIX))
                .ok_or_else(|| "Bluetooth audio sink not found".to_string())?;
            switch_to_sink(target);
        }
        "toggle" => {
            let profile = load_hardware_profile();
            let snap = query_audio();
            let current_is_bt = snap
                .sinks
                .iter()
                .find(|s| s.is_default)
                .map(|s| s.name.starts_with(BT_PREFIX))
                .unwrap_or(false);
            if current_is_bt {
                if let Some(target) = snap
                    .sinks
                    .iter()
                    .find(|s| is_onkyo_sink(&s.name, &s.desc, &profile))
                {
                    switch_to_sink(target);
                } else if let Some(target) = snap
                    .sinks
                    .iter()
                    .find(|s| !s.name.starts_with(BT_PREFIX) && !s.name.contains("snd_aloop"))
                {
                    switch_to_sink(target);
                } else {
                    return Err("No speaker/wired sink available".to_string());
                }
            } else if let Some(target) = snap.sinks.iter().find(|s| s.name.starts_with(BT_PREFIX)) {
                switch_to_sink(target);
            } else if let Some(target) = snap
                .sinks
                .iter()
                .find(|s| is_onkyo_sink(&s.name, &s.desc, &profile))
            {
                switch_to_sink(target);
            } else if let Some(target) = snap.sinks.iter().find(|s| !s.is_default) {
                switch_to_sink(target);
            } else {
                return Err("No alternative audio sink available".to_string());
            }
        }
        "set-sink" => {
            let query = args.get(1).ok_or_else(|| "audio set-sink requires <name_or_id>".to_string())?;
            let snap = query_audio();
            let target = snap
                .sinks
                .iter()
                .find(|s| {
                    s.name == *query
                        || s.id.to_string() == *query
                        || s.wp_id.as_deref() == Some(query.as_str())
                })
                .ok_or_else(|| format!("sink not found: {query}"))?;
            switch_to_sink(target);
        }
        other => return Err(format!("unknown audio subcommand: {other}")),
    }

    invalidate_audio_cache();
    let updated = query_audio();
    Ok(format!(
        "{{\"ok\":true,\"audio_label\":{},\"audio_vol\":{},\"audio_muted\":{},\"onkyo_active\":{},\"onkyo_detected\":{},\"has_onkyo\":{},\"sinks\":{}}}",
        escape_str(&updated.audio_label),
        updated.audio_vol,
        updated.audio_muted,
        updated.onkyo_active,
        updated.onkyo_detected,
        updated.onkyo_detected,
        sinks_to_json(&updated.sinks)
    ))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn volume_arg_formatting_and_validation() {
        assert_eq!(format_wpctl_vol_arg("+5%").unwrap(), "5%+");
        assert_eq!(format_wpctl_vol_arg("-5%").unwrap(), "5%-");
        assert_eq!(format_wpctl_vol_arg(" 75% ").unwrap(), "75%");
        assert!(format_wpctl_vol_arg("").is_err());
        assert!(format_wpctl_vol_arg("+").is_err());
        assert!(format_wpctl_vol_arg("-").is_err());
    }
}
