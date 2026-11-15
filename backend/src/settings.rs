use crate::json::{self, escape_str, JsonVal};
use crate::theme::{self, atomic_write, config_dir};
use std::collections::BTreeMap;
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Clone, PartialEq)]
pub struct BgLayoutTile {
    pub id: String,
    pub kind: String, // "terminal" | "ascii_image"
    pub monitor: String,
    pub x: i64,
    pub y: i64,
    pub width: i64,
    pub height: i64,
    pub enabled: bool,
    pub cmd: String,
    pub interactive: bool,
    pub font_size: i64, // 0 = inherit
    pub opacity: f64,   // 0.0..1.0
    pub match_grid: bool,
    pub image_path: String,
    pub charset: String,    // "ascii" | "blocks" | "braille"
    pub color_mode: String, // "colored" | "theme"
    pub fit_mode: String,   // "fit" | "cover"
    pub invert: bool,
}

impl BgLayoutTile {
    pub fn to_json(&self) -> String {
        format!(
            "{{\"id\":{},\"kind\":{},\"monitor\":{},\"x\":{},\"y\":{},\"width\":{},\"height\":{},\"enabled\":{},\"cmd\":{},\"interactive\":{},\"fontSize\":{},\"opacity\":{:.2},\"matchGrid\":{},\"imagePath\":{},\"charset\":{},\"colorMode\":{},\"fitMode\":{},\"invert\":{}}}",
            escape_str(&self.id),
            escape_str(&self.kind),
            escape_str(&self.monitor),
            self.x,
            self.y,
            self.width,
            self.height,
            self.enabled,
            escape_str(&self.cmd),
            self.interactive,
            self.font_size,
            self.opacity,
            self.match_grid,
            escape_str(&self.image_path),
            escape_str(&self.charset),
            escape_str(&self.color_mode),
            escape_str(&self.fit_mode),
            self.invert
        )
    }

    pub fn from_json(val: &JsonVal) -> Option<Self> {
        let obj = val.as_obj()?;
        let id = obj.get("id").and_then(|x| x.as_str()).map(str::trim).filter(|s| !s.is_empty())?.to_string();
        let kind = match obj.get("kind").and_then(|x| x.as_str()).map(str::trim).map(str::to_ascii_lowercase).as_deref() {
            Some("ascii_image" | "image") => "ascii_image".to_string(),
            _ => "terminal".to_string(),
        };
        let monitor = obj.get("monitor").and_then(|x| x.as_str()).map(str::trim).filter(|s| !s.is_empty()).unwrap_or("primary").to_string();
        let x = obj.get("x").and_then(|x| x.as_i64()).unwrap_or(80).clamp(-4096, 8192);
        let y = obj.get("y").and_then(|x| x.as_i64()).unwrap_or(60).clamp(-4096, 8192);
        let width = obj.get("width").and_then(|x| x.as_i64()).unwrap_or(900).clamp(160, 3840);
        let height = obj.get("height").and_then(|x| x.as_i64()).unwrap_or(520).clamp(120, 2160);
        let enabled = obj.get("enabled").and_then(|x| x.as_bool()).unwrap_or(true);
        let cmd = obj.get("cmd").and_then(|x| x.as_str()).map(str::trim).filter(|s| !s.is_empty()).unwrap_or("asciiquarium").chars().take(512).collect();
        let interactive = obj.get("interactive").and_then(|x| x.as_bool()).unwrap_or(false);
        let font_size = obj.get("fontSize").and_then(|x| x.as_i64()).unwrap_or(0).clamp(0, 18);
        let opacity = obj.get("opacity").and_then(|x| x.as_f64()).unwrap_or(0.0).clamp(0.0, 1.0);
        let match_grid = obj.get("matchGrid").and_then(|x| x.as_bool()).unwrap_or(true);
        let image_path = obj.get("imagePath").and_then(|x| x.as_str()).map(str::trim).unwrap_or("").chars().take(1024).collect();
        let charset = match obj.get("charset").and_then(|x| x.as_str()).map(str::trim).map(str::to_ascii_lowercase).as_deref() {
            Some("blocks" | "block") => "blocks".to_string(),
            Some("braille") => "braille".to_string(),
            _ => "ascii".to_string(),
        };
        let color_mode = match obj.get("colorMode").and_then(|x| x.as_str()).map(str::trim).map(str::to_ascii_lowercase).as_deref() {
            Some("theme" | "mono") => "theme".to_string(),
            _ => "colored".to_string(),
        };
        let fit_mode = match obj.get("fitMode").and_then(|x| x.as_str()).map(str::trim).map(str::to_ascii_lowercase).as_deref() {
            Some("cover") => "cover".to_string(),
            _ => "fit".to_string(),
        };
        let invert = obj.get("invert").and_then(|x| x.as_bool()).unwrap_or(false);

        Some(Self {
            id,
            kind,
            monitor,
            x,
            y,
            width,
            height,
            enabled,
            cmd,
            interactive,
            font_size,
            opacity,
            match_grid,
            image_path,
            charset,
            color_mode,
            fit_mode,
            invert,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct MonitorAsciiImage {
    pub image_path: String,
    pub charset: String,    // "ascii" | "blocks" | "braille"
    pub color_mode: String, // "colored" | "theme"
    pub fit_mode: String,   // "fit" | "cover"
    pub invert: bool,
    pub opacity: f64,
}

impl MonitorAsciiImage {
    pub fn to_json(&self) -> String {
        format!(
            "{{\"imagePath\":{},\"charset\":{},\"colorMode\":{},\"fitMode\":{},\"invert\":{},\"opacity\":{:.2}}}",
            escape_str(&self.image_path),
            escape_str(&self.charset),
            escape_str(&self.color_mode),
            escape_str(&self.fit_mode),
            self.invert,
            self.opacity
        )
    }

    pub fn from_json(val: &JsonVal) -> Option<Self> {
        let obj = val.as_obj()?;
        let image_path = obj.get("imagePath").and_then(|x| x.as_str()).map(str::trim).unwrap_or("").chars().take(1024).collect();
        let charset = match obj.get("charset").and_then(|x| x.as_str()).map(str::trim).map(str::to_ascii_lowercase).as_deref() {
            Some("blocks" | "block") => "blocks".to_string(),
            Some("braille") => "braille".to_string(),
            _ => "ascii".to_string(),
        };
        let color_mode = match obj.get("colorMode").and_then(|x| x.as_str()).map(str::trim).map(str::to_ascii_lowercase).as_deref() {
            Some("theme" | "mono") => "theme".to_string(),
            _ => "colored".to_string(),
        };
        let fit_mode = match obj.get("fitMode").and_then(|x| x.as_str()).map(str::trim).map(str::to_ascii_lowercase).as_deref() {
            Some("cover") => "cover".to_string(),
            _ => "fit".to_string(),
        };
        let invert = obj.get("invert").and_then(|x| x.as_bool()).unwrap_or(false);
        let opacity = obj.get("opacity").and_then(|x| x.as_f64()).unwrap_or(0.0).clamp(0.0, 1.0);

        Some(Self {
            image_path,
            charset,
            color_mode,
            fit_mode,
            invert,
            opacity,
        })
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct AppSettings {
    pub theme: String,
    pub font_family: String,
    pub font_size: i64,
    pub grid_density: String,
    pub show_grid_dots: bool,
    pub snap_enabled: bool,
    pub snap_threshold_px: i64,
    pub show_split_divider: bool,
    pub start_menu_default_mode: String,
    pub clock_show_seconds: bool,
    pub clock_24h: bool,
    pub onkyo_audio_guard: bool,
    pub bg_terminal_enabled: bool,
    pub bg_terminal_cmd: String,
    pub bg_terminal_interactive: bool,
    pub bg_terminal_x: i64,
    pub bg_terminal_y: i64,
    pub bg_terminal_width: i64,
    pub bg_terminal_height: i64,
    pub bg_terminal_font_size: i64,
    pub bg_terminal_opacity: f64,
    pub bg_terminal_match_grid: bool,
    pub bg_layout_tiles: Vec<BgLayoutTile>,
    pub monitor_ascii_images: BTreeMap<String, MonitorAsciiImage>,
}

impl Default for AppSettings {
    fn default() -> Self {
        Self {
            theme: "amber".to_string(),
            font_family: "JetBrains Mono".to_string(),
            font_size: 13,
            grid_density: "normal".to_string(),
            show_grid_dots: true,
            snap_enabled: true,
            snap_threshold_px: 24,
            show_split_divider: true,
            start_menu_default_mode: "search".to_string(),
            clock_show_seconds: true,
            clock_24h: true,
            onkyo_audio_guard: true,
            bg_terminal_enabled: false,
            bg_terminal_cmd: "asciiquarium".to_string(),
            bg_terminal_interactive: false,
            bg_terminal_x: 80,
            bg_terminal_y: 60,
            bg_terminal_width: 900,
            bg_terminal_height: 520,
            bg_terminal_font_size: 11,
            bg_terminal_opacity: 0.0,
            bg_terminal_match_grid: true,
            bg_layout_tiles: Vec::new(),
            monitor_ascii_images: BTreeMap::new(),
        }
    }
}

fn settings_path() -> PathBuf {
    config_dir().join("settings.json")
}

fn normalize_theme(raw: &str) -> String {
    match raw.trim().to_ascii_lowercase().as_str() {
        "amber" | "green" | "cyan" | "mono" | "snaptic" | "xmas" | "custom" => {
            raw.trim().to_ascii_lowercase()
        }
        _ => "amber".to_string(),
    }
}

fn normalize_grid_density(raw: &str) -> String {
    match raw.trim().to_ascii_lowercase().as_str() {
        "sparse" | "normal" | "dense" => raw.trim().to_ascii_lowercase(),
        _ => "normal".to_string(),
    }
}

fn normalize_start_mode(raw: &str) -> String {
    match raw.trim().to_ascii_lowercase().as_str() {
        "search" | "folders" => raw.trim().to_ascii_lowercase(),
        _ => "search".to_string(),
    }
}

impl AppSettings {
    pub fn apply_json(&mut self, val: &JsonVal) -> Result<(), String> {
        if val.as_obj().is_none() {
            return Err("settings payload must be a JSON object".to_string());
        }
        if let Some(v) = val.get("theme").and_then(|x| x.as_str()) {
            self.theme = normalize_theme(v);
        }
        if let Some(v) = val.get("fontFamily").and_then(|x| x.as_str()) {
            let trimmed = v.trim();
            if !trimmed.is_empty() {
                self.font_family = trimmed.to_string();
            }
        }
        if let Some(v) = val.get("fontSize").and_then(|x| x.as_i64()) {
            self.font_size = v.clamp(11, 16);
        }
        if let Some(v) = val.get("gridDensity").and_then(|x| x.as_str()) {
            self.grid_density = normalize_grid_density(v);
        }
        if let Some(v) = val.get("showGridDots").and_then(|x| x.as_bool()) {
            self.show_grid_dots = v;
        }
        if let Some(v) = val.get("snapEnabled").and_then(|x| x.as_bool()) {
            self.snap_enabled = v;
        }
        if let Some(v) = val.get("snapThresholdPx").and_then(|x| x.as_i64()) {
            self.snap_threshold_px = v.clamp(12, 48);
        }
        if let Some(v) = val.get("showSplitDivider").and_then(|x| x.as_bool()) {
            self.show_split_divider = v;
        }
        if let Some(v) = val.get("startMenuDefaultMode").and_then(|x| x.as_str()) {
            self.start_menu_default_mode = normalize_start_mode(v);
        }
        if let Some(v) = val.get("clockShowSeconds").and_then(|x| x.as_bool()) {
            self.clock_show_seconds = v;
        }
        if let Some(v) = val.get("clock24h").and_then(|x| x.as_bool()) {
            self.clock_24h = v;
        }
        if let Some(v) = val.get("onkyoAudioGuard").and_then(|x| x.as_bool()) {
            self.onkyo_audio_guard = v;
        }
        if let Some(v) = val.get("bgTerminalEnabled").and_then(|x| x.as_bool()) {
            self.bg_terminal_enabled = v;
        }
        if let Some(v) = val.get("bgTerminalCmd").and_then(|x| x.as_str()) {
            let trimmed = v.trim();
            if !trimmed.is_empty() {
                self.bg_terminal_cmd = trimmed.chars().take(512).collect();
            }
        }
        if let Some(v) = val.get("bgTerminalInteractive").and_then(|x| x.as_bool()) {
            self.bg_terminal_interactive = v;
        }
        if let Some(v) = val.get("bgTerminalX").and_then(|x| x.as_i64()) {
            self.bg_terminal_x = v.clamp(-4096, 8192);
        }
        if let Some(v) = val.get("bgTerminalY").and_then(|x| x.as_i64()) {
            self.bg_terminal_y = v.clamp(-4096, 8192);
        }
        if let Some(v) = val.get("bgTerminalWidth").and_then(|x| x.as_i64()) {
            self.bg_terminal_width = v.clamp(240, 3840);
        }
        if let Some(v) = val.get("bgTerminalHeight").and_then(|x| x.as_i64()) {
            self.bg_terminal_height = v.clamp(160, 2160);
        }
        if let Some(v) = val.get("bgTerminalFontSize").and_then(|x| x.as_i64()) {
            self.bg_terminal_font_size = v.clamp(8, 18);
        }
        if let Some(v) = val.get("bgTerminalOpacity").and_then(|x| x.as_f64()) {
            self.bg_terminal_opacity = v.clamp(0.0, 1.0);
        }
        if let Some(v) = val.get("bgTerminalMatchGrid").and_then(|x| x.as_bool()) {
            self.bg_terminal_match_grid = v;
        }
        if let Some(arr) = val.get("bgLayoutTiles").and_then(|x| x.as_arr()) {
            let mut tiles = Vec::new();
            for item in arr {
                if let Some(tile) = BgLayoutTile::from_json(item) {
                    tiles.push(tile);
                }
            }
            self.bg_layout_tiles = tiles;
        } else if self.bg_terminal_enabled && self.bg_layout_tiles.is_empty() {
            // Seed legacy tile-1 on primary output if bgLayoutTiles was not in JSON
            self.bg_layout_tiles.push(BgLayoutTile {
                id: "tile-1".to_string(),
                kind: "terminal".to_string(),
                monitor: "primary".to_string(),
                x: self.bg_terminal_x,
                y: self.bg_terminal_y,
                width: self.bg_terminal_width,
                height: self.bg_terminal_height,
                enabled: true,
                cmd: self.bg_terminal_cmd.clone(),
                interactive: self.bg_terminal_interactive,
                font_size: self.bg_terminal_font_size,
                opacity: self.bg_terminal_opacity,
                match_grid: self.bg_terminal_match_grid,
                image_path: String::new(),
                charset: "ascii".to_string(),
                color_mode: "colored".to_string(),
                fit_mode: "fit".to_string(),
                invert: false,
            });
        }
        if let Some(obj) = val.get("monitorAsciiImages").and_then(|x| x.as_obj()) {
            let mut map = BTreeMap::new();
            for (k, v) in obj {
                if let Some(img) = MonitorAsciiImage::from_json(v) {
                    map.insert(k.clone(), img);
                }
            }
            self.monitor_ascii_images = map;
        }
        Ok(())
    }

    pub fn to_json(&self) -> String {
        let tiles_json = format!(
            "[{}]",
            self.bg_layout_tiles
                .iter()
                .map(BgLayoutTile::to_json)
                .collect::<Vec<_>>()
                .join(",")
        );
        let mut mai_entries = Vec::new();
        for (k, v) in &self.monitor_ascii_images {
            mai_entries.push(format!("{}:{}", escape_str(k), v.to_json()));
        }
        let mai_json = format!("{{{}}}", mai_entries.join(","));

        format!(
            "{{\"theme\":{},\"fontFamily\":{},\"fontSize\":{},\"gridDensity\":{},\"showGridDots\":{},\"snapEnabled\":{},\"snapThresholdPx\":{},\"showSplitDivider\":{},\"startMenuDefaultMode\":{},\"clockShowSeconds\":{},\"clock24h\":{},\"onkyoAudioGuard\":{},\"bgTerminalEnabled\":{},\"bgTerminalCmd\":{},\"bgTerminalInteractive\":{},\"bgTerminalX\":{},\"bgTerminalY\":{},\"bgTerminalWidth\":{},\"bgTerminalHeight\":{},\"bgTerminalFontSize\":{},\"bgTerminalOpacity\":{:.2},\"bgTerminalMatchGrid\":{},\"bgLayoutTiles\":{},\"monitorAsciiImages\":{}}}",
            escape_str(&self.theme),
            escape_str(&self.font_family),
            self.font_size,
            escape_str(&self.grid_density),
            self.show_grid_dots,
            self.snap_enabled,
            self.snap_threshold_px,
            self.show_split_divider,
            escape_str(&self.start_menu_default_mode),
            self.clock_show_seconds,
            self.clock_24h,
            self.onkyo_audio_guard,
            self.bg_terminal_enabled,
            escape_str(&self.bg_terminal_cmd),
            self.bg_terminal_interactive,
            self.bg_terminal_x,
            self.bg_terminal_y,
            self.bg_terminal_width,
            self.bg_terminal_height,
            self.bg_terminal_font_size,
            self.bg_terminal_opacity,
            self.bg_terminal_match_grid,
            tiles_json,
            mai_json
        )
    }
}

fn load_or_seed() -> Result<AppSettings, String> {
    let path = settings_path();
    let mut cfg = AppSettings::default();
    if path.exists() {
        if let Ok(raw) = fs::read_to_string(&path) {
            if let Ok(val) = json::parse(&raw) {
                if cfg.apply_json(&val).is_ok() {
                    return Ok(cfg);
                }
            }
        }
    }
    let out = cfg.to_json();
    atomic_write(&path, &(out + "\n"))?;
    Ok(cfg)
}

pub fn migrate_settings_file(path: &std::path::Path) -> Result<bool, String> {
    if !path.exists() {
        return Ok(false);
    }
    let raw = fs::read_to_string(path).map_err(|e| format!("read {}: {e}", path.display()))?;
    let val = json::parse(&raw)?;
    if val.as_obj().is_none() {
        return Err(format!("{} is not a JSON object", path.display()));
    }
    let mut cfg = AppSettings::default();
    cfg.apply_json(&val)?;
    atomic_write(path, &(cfg.to_json() + "\n"))?;
    Ok(true)
}

pub fn sync_from_theme(theme_name: &str, font_family: &str, font_size: i64) -> Result<(), String> {
    let mut cfg = load_or_seed()?;
    cfg.theme = normalize_theme(theme_name);
    let trimmed_font = font_family.trim();
    if !trimmed_font.is_empty() {
        cfg.font_family = trimmed_font.to_string();
    }
    cfg.font_size = font_size.clamp(11, 16);
    let out = cfg.to_json();
    atomic_write(&settings_path(), &(out + "\n"))
}

pub fn handle_settings_cmd(args: &[String]) -> Result<String, String> {
    let sub = args.first().map(|s| s.as_str()).unwrap_or("get");
    match sub {
        "get" => {
            let cfg = load_or_seed()?;
            Ok(cfg.to_json())
        }
        "set" => {
            let payload = args
                .get(1)
                .ok_or_else(|| "settings set requires <json>".to_string())?;
            let val = json::parse(payload)?;
            let mut cfg = load_or_seed()?;
            let prev_theme = cfg.theme.clone();
            cfg.apply_json(&val)?;
            let out = cfg.to_json();
            atomic_write(&settings_path(), &(out.clone() + "\n"))?;
            if (cfg.theme != prev_theme || !config_dir().join("theme.json").exists())
                && cfg.theme != "custom"
            {
                if let Ok(t) = theme::set_theme_only(&cfg.theme) {
                    let _ = theme::sync_apps_for_theme(&t);
                }
            } else {
                let mut t = theme::load_theme();
                t.font_family = cfg.font_family.clone();
                t.font_size = cfg.font_size as u32;
                let _ = theme::sync_apps_for_theme(&t);
            }
            Ok(out)
        }
        "reset" => {
            let cfg = AppSettings::default();
            let out = cfg.to_json();
            atomic_write(&settings_path(), &(out.clone() + "\n"))?;
            if let Ok(t) = theme::set_theme_only(&cfg.theme) {
                let _ = theme::sync_apps_for_theme(&t);
            }
            Ok(out)
        }
        other => Err(format!("unknown settings subcommand: {other}")),
    }
}
