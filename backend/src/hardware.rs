use crate::json;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};

pub const LEGACY_ONKYO_SINK_NAME: &str = "alsa_output.pci-0000_01_00.1.playback.3.0";
pub const LEGACY_ONKYO_SINK_FALLBACK: &str = "alsa_output.pci-0000_01_00.1.hdmi-surround";

#[derive(Debug, Clone, Default)]
pub struct HardwareProfile {
    pub onkyo_sink: Option<String>,
    pub onkyo_sink_fallback: Option<String>,
    pub onkyo_output: Option<String>,
    pub preferred_primary: Option<String>,
    pub sync_terminal_plasma_outputs: bool,
    pub keep_offline_monitors: bool,
}

pub fn home_dir() -> PathBuf {
    env::var_os("HOME")
        .filter(|v| !v.is_empty())
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/tmp"))
}

pub fn user_name() -> String {
    env::var("USER")
        .ok()
        .filter(|v| !v.trim().is_empty())
        .or_else(|| env::var("LOGNAME").ok().filter(|v| !v.trim().is_empty()))
        .unwrap_or_else(|| "user".to_string())
}

pub fn xdg_cache_home() -> PathBuf {
    env::var_os("XDG_CACHE_HOME")
        .filter(|v| !v.is_empty())
        .map(PathBuf::from)
        .unwrap_or_else(|| home_dir().join(".cache"))
}

pub fn ascii_config_dir() -> PathBuf {
    home_dir().join(".config").join("ascii-de")
}

pub fn hardware_profile_path() -> PathBuf {
    ascii_config_dir().join("hardware-profile.json")
}

pub fn terminal_plasma_outputs_conf_path() -> PathBuf {
    home_dir()
        .join(".config")
        .join("terminal-plasma")
        .join("kscreen")
        .join("outputs.conf")
}

pub fn outputs_conf_has_onkyo() -> bool {
    let path = terminal_plasma_outputs_conf_path();
    let Ok(raw) = fs::read_to_string(path) else {
        return false;
    };
    let upper = raw.to_ascii_uppercase();
    upper.contains("ONKYO") || upper.contains("HT-R758")
}

pub fn load_hardware_profile() -> HardwareProfile {
    let mut profile = HardwareProfile {
        sync_terminal_plasma_outputs: terminal_plasma_outputs_conf_path()
            .parent()
            .map(|p| p.exists())
            .unwrap_or(false),
        keep_offline_monitors: terminal_plasma_outputs_conf_path().exists(),
        ..HardwareProfile::default()
    };

    let path = hardware_profile_path();
    let Ok(raw) = fs::read_to_string(path) else {
        return profile;
    };
    let Ok(val) = json::parse(&raw) else {
        return profile;
    };

    if let Some(s) = val.get("onkyo_sink").and_then(|v| v.as_str()).map(str::trim) {
        if !s.is_empty() {
            profile.onkyo_sink = Some(s.to_string());
        }
    }
    if let Some(s) = val
        .get("onkyo_sink_fallback")
        .and_then(|v| v.as_str())
        .map(str::trim)
    {
        if !s.is_empty() {
            profile.onkyo_sink_fallback = Some(s.to_string());
        }
    }
    if let Some(s) = val.get("onkyo_output").and_then(|v| v.as_str()).map(str::trim) {
        if !s.is_empty() {
            profile.onkyo_output = Some(s.to_string());
        }
    }
    if let Some(s) = val
        .get("preferred_primary")
        .and_then(|v| v.as_str())
        .map(str::trim)
    {
        if !s.is_empty() {
            profile.preferred_primary = Some(s.to_string());
        }
    }
    if let Some(b) = val
        .get("sync_terminal_plasma_outputs")
        .and_then(|v| v.as_bool())
    {
        profile.sync_terminal_plasma_outputs = b;
    }
    if let Some(b) = val.get("keep_offline_monitors").and_then(|v| v.as_bool()) {
        profile.keep_offline_monitors = b;
    }

    profile
}

pub fn is_onkyo_sink(name: &str, desc: &str, profile: &HardwareProfile) -> bool {
    if profile.onkyo_sink.as_deref() == Some(name)
        || profile.onkyo_sink_fallback.as_deref() == Some(name)
    {
        return true;
    }
    let desc_up = desc.to_ascii_uppercase();
    if desc_up.contains("ONKYO") || desc_up.contains("HT-R758") {
        return true;
    }
    name == LEGACY_ONKYO_SINK_NAME || name == LEGACY_ONKYO_SINK_FALLBACK
}

pub fn is_onkyo_monitor(name: &str, desc: &str, profile: &HardwareProfile) -> bool {
    let desc_up = desc.to_ascii_uppercase();
    if desc_up.contains("ONKYO") || desc_up.contains("HT-R758") {
        return true;
    }
    if profile.onkyo_output.as_deref() == Some(name) {
        return true;
    }
    name == "HDMI-A-1" && outputs_conf_has_onkyo()
}

pub fn has_nvidia_gpu() -> bool {
    Path::new("/dev/nvidia0").exists() || Path::new("/sys/module/nvidia_drm").exists()
}
