use crate::json::{self, escape_str, JsonVal};
use crate::settings;
use std::collections::BTreeMap;
use std::fs;
use std::os::unix::fs::symlink;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, PartialEq)]
pub struct Theme {
    pub name: String,
    pub label: String,
    pub bg: String,
    pub bg_secondary: String,
    pub panel_bg: String,
    pub grid_dot: String,
    pub snap_line: String,
    pub fg: String,
    pub accent: String,
    pub secondary: String,
    pub muted: String,
    pub danger: String,
    pub close_btn_bg: String,
    pub font_family: String,
    pub font_size: u32,
    pub chrome_style: String,
    pub background_style: String,
    pub monitor_backgrounds: BTreeMap<String, String>,
    pub bg_terminal_cmd: String,
    pub custom_bg_text: String,
    pub xmas_monitor: String,
    pub grid_char: String,
    pub corner_radius: u32,
    pub border_width: u32,
    pub smear_drag: bool,
    pub impact_flash: bool,
    pub speed_lines: bool,
    pub origin_smear: bool,
}

struct ThemePresetSpec {
    name: &'static str,
    label: &'static str,
    bg: &'static str,
    bg_secondary: &'static str,
    panel_bg: &'static str,
    grid_dot: &'static str,
    snap_line: &'static str,
    fg: &'static str,
    accent: &'static str,
    secondary: &'static str,
    muted: &'static str,
    danger: &'static str,
    close_btn_bg: &'static str,
    font_family: &'static str,
    font_size: u32,
    chrome_style: &'static str,
    background_style: &'static str,
    grid_char: &'static str,
    corner_radius: u32,
    border_width: u32,
    smear_drag: bool,
    impact_flash: bool,
    speed_lines: bool,
    origin_smear: bool,
}

impl From<&ThemePresetSpec> for Theme {
    fn from(p: &ThemePresetSpec) -> Self {
        Self {
            name: p.name.to_string(),
            label: p.label.to_string(),
            bg: p.bg.to_string(),
            bg_secondary: p.bg_secondary.to_string(),
            panel_bg: p.panel_bg.to_string(),
            grid_dot: p.grid_dot.to_string(),
            snap_line: p.snap_line.to_string(),
            fg: p.fg.to_string(),
            accent: p.accent.to_string(),
            secondary: p.secondary.to_string(),
            muted: p.muted.to_string(),
            danger: p.danger.to_string(),
            close_btn_bg: p.close_btn_bg.to_string(),
            font_family: p.font_family.to_string(),
            font_size: p.font_size,
            chrome_style: p.chrome_style.to_string(),
            background_style: p.background_style.to_string(),
            monitor_backgrounds: BTreeMap::new(),
            bg_terminal_cmd: "asciiquarium".to_string(),
            custom_bg_text: String::new(),
            xmas_monitor: "tallest".to_string(),
            grid_char: p.grid_char.to_string(),
            corner_radius: p.corner_radius,
            border_width: p.border_width,
            smear_drag: p.smear_drag,
            impact_flash: p.impact_flash,
            speed_lines: p.speed_lines,
            origin_smear: p.origin_smear,
        }
    }
}

const PRESETS: &[ThemePresetSpec] = &[
    ThemePresetSpec {
        name: "amber",
        label: "Warm Amber CRT",
        bg: "#0d0f10",
        bg_secondary: "#14171a",
        panel_bg: "#14171a",
        grid_dot: "#252a30",
        snap_line: "#8b949e",
        fg: "#e6dcc8",
        accent: "#ffb000",
        secondary: "#50fa7b",
        muted: "#6e7681",
        danger: "#ff5555",
        close_btn_bg: "#ff5555",
        font_family: "JetBrains Mono",
        font_size: 13,
        chrome_style: "ascii",
        background_style: "ascii_grid",
        grid_char: "·",
        corner_radius: 0,
        border_width: 1,
        smear_drag: false,
        impact_flash: false,
        speed_lines: false,
        origin_smear: false,
    },
    ThemePresetSpec {
        name: "green",
        label: "Cyber Green Matrix",
        bg: "#090f0b",
        bg_secondary: "#101913",
        panel_bg: "#101913",
        grid_dot: "#1e3024",
        snap_line: "#8b949e",
        fg: "#d6f5df",
        accent: "#50fa7b",
        secondary: "#ffb000",
        muted: "#5f7a68",
        danger: "#ff5555",
        close_btn_bg: "#ff5555",
        font_family: "JetBrains Mono",
        font_size: 13,
        chrome_style: "ascii",
        background_style: "ascii_grid",
        grid_char: "·",
        corner_radius: 0,
        border_width: 1,
        smear_drag: false,
        impact_flash: false,
        speed_lines: false,
        origin_smear: false,
    },
    ThemePresetSpec {
        name: "cyan",
        label: "Ice Cyan Terminal",
        bg: "#090e12",
        bg_secondary: "#11181f",
        panel_bg: "#11181f",
        grid_dot: "#1e2c38",
        snap_line: "#8b949e",
        fg: "#d8ecf7",
        accent: "#38bdf8",
        secondary: "#50fa7b",
        muted: "#64748b",
        danger: "#ff5555",
        close_btn_bg: "#ff5555",
        font_family: "JetBrains Mono",
        font_size: 13,
        chrome_style: "ascii",
        background_style: "ascii_grid",
        grid_char: "·",
        corner_radius: 0,
        border_width: 1,
        smear_drag: false,
        impact_flash: false,
        speed_lines: false,
        origin_smear: false,
    },
    ThemePresetSpec {
        name: "mono",
        label: "Monochrome Slate",
        bg: "#0b0b0b",
        bg_secondary: "#151515",
        panel_bg: "#151515",
        grid_dot: "#2a2a2a",
        snap_line: "#8b949e",
        fg: "#e5e5e5",
        accent: "#ffffff",
        secondary: "#a3a3a3",
        muted: "#666666",
        danger: "#ff5555",
        close_btn_bg: "#ff5555",
        font_family: "JetBrains Mono",
        font_size: 13,
        chrome_style: "ascii",
        background_style: "ascii_grid",
        grid_char: "·",
        corner_radius: 0,
        border_width: 1,
        smear_drag: false,
        impact_flash: false,
        speed_lines: false,
        origin_smear: false,
    },
    ThemePresetSpec {
        name: "snaptic",
        label: "SNAPTIC :: Data Lens Overhaul",
        bg: "#E8ECFC",
        bg_secondary: "#C5CEF7",
        panel_bg: "#D8DDF4",
        grid_dot: "#A0A8D8",
        snap_line: "#45C2FF",
        fg: "#3E4670",
        accent: "#7B84BF",
        secondary: "#45C2FF",
        muted: "#7D86B5",
        danger: "#FF3366",
        close_btn_bg: "#FF5C5C",
        font_family: "JetBrains Mono",
        font_size: 13,
        chrome_style: "snaptic_datalens",
        background_style: "snaptic_void",
        grid_char: "∘",
        corner_radius: 10,
        border_width: 2,
        smear_drag: true,
        impact_flash: true,
        speed_lines: true,
        origin_smear: true,
    },
    ThemePresetSpec {
        name: "xmas",
        label: "Christmas Tree (dwcminh)",
        bg: "#090a10",
        bg_secondary: "#0e1518",
        panel_bg: "#10161c",
        grid_dot: "#1f3028",
        snap_line: "#44cc66",
        fg: "#e6f2e8",
        accent: "#ff474d",
        secondary: "#ffe647",
        muted: "#7a9e87",
        danger: "#ff474d",
        close_btn_bg: "#ff474d",
        font_family: "JetBrains Mono",
        font_size: 13,
        chrome_style: "ascii",
        background_style: "christmas_tree",
        grid_char: "*",
        corner_radius: 0,
        border_width: 1,
        smear_drag: false,
        impact_flash: false,
        speed_lines: false,
        origin_smear: false,
    },
];

pub fn config_dir() -> PathBuf {
    crate::hardware::ascii_config_dir()
}

fn theme_path() -> PathBuf {
    config_dir().join("theme.json")
}

fn find_preset(name: &str) -> Option<&'static ThemePresetSpec> {
    let lower = name.trim().to_ascii_lowercase();
    PRESETS.iter().find(|p| p.name == lower)
}

fn is_valid_hex_color(s: &str) -> bool {
    let t = s.trim();
    if !t.starts_with('#') {
        return false;
    }
    let hex = &t[1..];
    (hex.len() == 6 || hex.len() == 8) && hex.bytes().all(|b| b.is_ascii_hexdigit())
}

fn normalize_chrome(raw: &str) -> Option<String> {
    match raw.trim().to_ascii_lowercase().as_str() {
        "ascii" | "snaptic_datalens" | "minimal" => Some(raw.trim().to_ascii_lowercase()),
        _ => None,
    }
}

fn normalize_bg_style(raw: &str) -> Option<String> {
    match raw.trim().to_ascii_lowercase().as_str() {
        "ascii_grid"
        | "solid"
        | "gradient"
        | "snaptic_void"
        | "custom_text"
        | "christmas_tree"
        | "newsboard"
        | "visualizer"
        | "visualizer_stripes"
        | "visualizer_dots"
        | "terminal"
        | "ascii_image" => Some(raw.trim().to_ascii_lowercase()),
        _ => None,
    }
}

impl Theme {
    pub fn to_json(&self) -> String {
        let mut mb_entries = Vec::new();
        for (k, v) in &self.monitor_backgrounds {
            mb_entries.push(format!("{}:{}", escape_str(k), escape_str(v)));
        }
        let mb_json = format!("{{{}}}", mb_entries.join(","));

        format!(
            "{{\"name\":{},\"label\":{},\"bg\":{},\"bgSecondary\":{},\"panelBg\":{},\"gridDot\":{},\"snapLine\":{},\"fg\":{},\"accent\":{},\"secondary\":{},\"muted\":{},\"danger\":{},\"closeBtnBg\":{},\"fontFamily\":{},\"fontSize\":{},\"chromeStyle\":{},\"backgroundStyle\":{},\"monitorBackgrounds\":{},\"bgTerminalCmd\":{},\"customBgText\":{},\"xmasMonitor\":{},\"gridChar\":{},\"cornerRadius\":{},\"borderWidth\":{},\"smearDrag\":{},\"impactFlash\":{},\"speedLines\":{},\"originSmear\":{}}}",
            escape_str(&self.name),
            escape_str(&self.label),
            escape_str(&self.bg),
            escape_str(&self.bg_secondary),
            escape_str(&self.panel_bg),
            escape_str(&self.grid_dot),
            escape_str(&self.snap_line),
            escape_str(&self.fg),
            escape_str(&self.accent),
            escape_str(&self.secondary),
            escape_str(&self.muted),
            escape_str(&self.danger),
            escape_str(&self.close_btn_bg),
            escape_str(&self.font_family),
            self.font_size,
            escape_str(&self.chrome_style),
            escape_str(&self.background_style),
            mb_json,
            escape_str(&self.bg_terminal_cmd),
            escape_str(&self.custom_bg_text),
            escape_str(&self.xmas_monitor),
            escape_str(&self.grid_char),
            self.corner_radius,
            self.border_width,
            self.smear_drag,
            self.impact_flash,
            self.speed_lines,
            self.origin_smear
        )
    }

    pub fn apply_json(&mut self, val: &JsonVal) -> Result<(), String> {
        if val.as_obj().is_none() {
            return Err("theme payload must be a JSON object".to_string());
        }
        if let Some(v) = val.get("name").and_then(|x| x.as_str()) {
            let trimmed = v.trim();
            if !trimmed.is_empty() {
                self.name = trimmed.to_string();
            }
        }
        if let Some(v) = val.get("label").and_then(|x| x.as_str()) {
            let trimmed = v.trim();
            if !trimmed.is_empty() {
                self.label = trimmed.to_string();
            }
        }
        for (key, target) in [
            ("bg", &mut self.bg),
            ("bgSecondary", &mut self.bg_secondary),
            ("panelBg", &mut self.panel_bg),
            ("gridDot", &mut self.grid_dot),
            ("snapLine", &mut self.snap_line),
            ("fg", &mut self.fg),
            ("accent", &mut self.accent),
            ("secondary", &mut self.secondary),
            ("muted", &mut self.muted),
            ("danger", &mut self.danger),
            ("closeBtnBg", &mut self.close_btn_bg),
        ] {
            if let Some(v) = val.get(key).and_then(|x| x.as_str()) {
                if is_valid_hex_color(v) {
                    *target = v.trim().to_string();
                }
            }
        }
        if let Some(v) = val.get("fontFamily").and_then(|x| x.as_str()) {
            let trimmed = v.trim();
            if !trimmed.is_empty() {
                self.font_family = trimmed.to_string();
            }
        }
        if let Some(v) = val.get("fontSize").and_then(|x| x.as_i64()) {
            self.font_size = v.clamp(11, 16) as u32;
        }
        if let Some(v) = val.get("chromeStyle").and_then(|x| x.as_str()) {
            if let Some(norm) = normalize_chrome(v) {
                self.chrome_style = norm;
            }
        }
        if let Some(v) = val.get("backgroundStyle").and_then(|x| x.as_str()) {
            if let Some(norm) = normalize_bg_style(v) {
                self.background_style = norm;
            }
        }
        if let Some(obj) = val.get("monitorBackgrounds").and_then(|x| x.as_obj()) {
            let mut map = BTreeMap::new();
            for (k, v) in obj {
                if let Some(s) = v.as_str() {
                    if let Some(norm) = normalize_bg_style(s) {
                        map.insert(k.clone(), norm);
                    }
                }
            }
            self.monitor_backgrounds = map;
        }
        if let Some(v) = val.get("bgTerminalCmd").and_then(|x| x.as_str()) {
            let trimmed = v.trim();
            if !trimmed.is_empty() {
                self.bg_terminal_cmd = trimmed.chars().take(512).collect();
            }
        }
        if let Some(v) = val.get("customBgText").and_then(|x| x.as_str()) {
            self.custom_bg_text = v.chars().take(16384).collect();
        }
        if let Some(v) = val.get("xmasMonitor").and_then(|x| x.as_str()) {
            let trimmed = v.trim();
            self.xmas_monitor = if trimmed.is_empty() {
                "tallest".to_string()
            } else {
                trimmed.chars().take(64).collect()
            };
        }
        if let Some(v) = val.get("gridChar").and_then(|x| x.as_str()) {
            let trimmed = v.trim();
            if let Some(ch) = trimmed.chars().next() {
                self.grid_char = ch.to_string();
            }
        }
        if let Some(v) = val.get("cornerRadius").and_then(|x| x.as_i64()) {
            self.corner_radius = v.clamp(0, 24) as u32;
        }
        if let Some(v) = val.get("borderWidth").and_then(|x| x.as_i64()) {
            self.border_width = v.clamp(1, 6) as u32;
        }
        if let Some(v) = val.get("smearDrag").and_then(|x| x.as_bool()) {
            self.smear_drag = v;
        }
        if let Some(v) = val.get("impactFlash").and_then(|x| x.as_bool()) {
            self.impact_flash = v;
        }
        if let Some(v) = val.get("speedLines").and_then(|x| x.as_bool()) {
            self.speed_lines = v;
        }
        if let Some(v) = val.get("originSmear").and_then(|x| x.as_bool()) {
            self.origin_smear = v;
        }
        Ok(())
    }
}

pub fn atomic_write(path: &Path, content: &str) -> Result<(), String> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|e| format!("mkdir {}: {e}", parent.display()))?;
    }
    let tmp = path.with_extension("json.tmp");
    fs::write(&tmp, content).map_err(|e| format!("write {}: {e}", tmp.display()))?;
    fs::rename(&tmp, path).map_err(|e| format!("rename {}: {e}", path.display()))?;
    Ok(())
}

pub fn load_theme() -> Theme {
    let path = theme_path();
    if let Ok(raw) = fs::read_to_string(&path) {
        if let Ok(val) = json::parse(&raw) {
            let base_name = val.get("name").and_then(|v| v.as_str()).unwrap_or("amber");
            let mut theme = find_preset(base_name)
                .map(Theme::from)
                .unwrap_or_else(|| Theme::from(&PRESETS[0]));
            if theme.apply_json(&val).is_ok() {
                return theme;
            }
        }
    }
    let def = Theme::from(&PRESETS[0]);
    let _ = atomic_write(&path, &(def.to_json() + "\n"));
    def
}

pub fn migrate_theme_file(path: &Path) -> Result<bool, String> {
    if !path.exists() {
        return Ok(false);
    }
    let raw = fs::read_to_string(path).map_err(|e| format!("read {}: {e}", path.display()))?;
    let val = json::parse(&raw)?;
    if val.as_obj().is_none() {
        return Err(format!("{} is not a JSON object", path.display()));
    }
    let mut theme = Theme::from(&PRESETS[0]);
    theme.apply_json(&val)?;
    atomic_write(path, &(theme.to_json() + "\n"))?;
    Ok(true)
}

pub fn set_theme_only(name: &str) -> Result<Theme, String> {
    let preset = find_preset(name)
        .ok_or_else(|| format!("unknown theme '{name}' (expected: amber, green, cyan, mono, snaptic)"))?;
    let theme = Theme::from(preset);
    atomic_write(&theme_path(), &(theme.to_json() + "\n"))?;
    Ok(theme)
}

pub fn set_theme(name: &str) -> Result<String, String> {
    let theme = set_theme_only(name)?;
    let _ = settings::sync_from_theme(&theme.name, &theme.font_family, theme.font_size as i64);
    sync_apps_for_theme(&theme)?;
    Ok(theme.to_json())
}

pub fn set_custom_theme(raw_json: &str) -> Result<String, String> {
    let val = json::parse(raw_json)?;
    if val.as_obj().is_none() {
        return Err("theme custom requires a JSON object".to_string());
    }
    let mut base = if let Some(req_name) = val.get("name").and_then(|v| v.as_str()) {
        if let Some(p) = find_preset(req_name) {
            Theme::from(p)
        } else {
            load_theme()
        }
    } else {
        load_theme()
    };

    base.name = "custom".to_string();
    base.apply_json(&val)?;
    if base.name.trim().is_empty() {
        base.name = "custom".to_string();
    }
    if val.get("label").is_none() && base.name == "custom" {
        base.label = "Custom Overhaul".to_string();
    }

    let out = base.to_json();
    atomic_write(&theme_path(), &(out.clone() + "\n"))?;
    let _ = settings::sync_from_theme(&base.name, &base.font_family, base.font_size as i64);
    sync_apps_for_theme(&base)?;
    Ok(out)
}

pub fn xdg_config_dir() -> PathBuf {
    config_dir().join("xdg-config")
}

pub fn parse_hex_rgb(hex: &str) -> (u8, u8, u8) {
    let t = hex.trim().trim_start_matches('#');
    if t.len() >= 6 {
        if let (Ok(r), Ok(g), Ok(b)) = (
            u8::from_str_radix(&t[0..2], 16),
            u8::from_str_radix(&t[2..4], 16),
            u8::from_str_radix(&t[4..6], 16),
        ) {
            return (r, g, b);
        }
    }
    (13, 15, 16)
}

pub fn rgb_csv(hex: &str) -> String {
    let (r, g, b) = parse_hex_rgb(hex);
    format!("{r},{g},{b}")
}

pub fn luminance(hex: &str) -> f64 {
    let (r, g, b) = parse_hex_rgb(hex);
    (0.2126 * (r as f64) + 0.7152 * (g as f64) + 0.0722 * (b as f64)) / 255.0
}

fn mix_hex(a: &str, b: &str, t: f64) -> String {
    let (ar, ag, ab) = parse_hex_rgb(a);
    let (br, bg, bb) = parse_hex_rgb(b);
    let clamp_t = t.clamp(0.0, 1.0);
    let lerp = |x: u8, y: u8| -> u8 {
        ((x as f64) * (1.0 - clamp_t) + (y as f64) * clamp_t)
            .round()
            .clamp(0.0, 255.0) as u8
    };
    format!("#{:02X}{:02X}{:02X}", lerp(ar, br), lerp(ag, bg), lerp(ab, bb))
}

fn write_text_atomic(path: &Path, content: &str) -> Result<(), String> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|e| format!("mkdir {}: {e}", parent.display()))?;
    }
    let tmp = path.with_extension("tmp");
    fs::write(&tmp, content).map_err(|e| format!("write {}: {e}", tmp.display()))?;
    fs::rename(&tmp, path).map_err(|e| format!("rename {}: {e}", path.display()))?;
    Ok(())
}

fn ensure_app_symlinks(xdg_dir: &Path) {
    let host_cfg = crate::hardware::home_dir().join(".config");
    let safe_entries = [
        "dolphinrc",
        "katerc",
        "kwriterc",
        "konsolerc",
        "kitty",
        "fontconfig",
        "dconf",
        "pulse",
        "discord",
        "Vencord",
        "Equicord",
        "vesktop",
        "BetterDiscord",
        "Code",
    ];

    for entry in safe_entries {
        let src = host_cfg.join(entry);
        let dst = xdg_dir.join(entry);
        if !src.exists() {
            continue;
        }
        if let Ok(meta) = fs::symlink_metadata(&dst) {
            if meta.file_type().is_symlink() && !dst.exists() {
                let _ = fs::remove_file(&dst);
            } else {
                continue;
            }
        }
        let _ = symlink(&src, &dst);
    }
}

pub fn render_kdeglobals(theme: &Theme) -> String {
    let is_light = luminance(&theme.bg) >= 0.5;
    let icon_theme = if is_light { "breeze" } else { "breeze-dark" };
    let bg_rgb = rgb_csv(&theme.bg);
    let bg2_rgb = rgb_csv(&theme.bg_secondary);
    let panel_rgb = rgb_csv(&theme.panel_bg);
    let fg_rgb = rgb_csv(&theme.fg);
    let accent_rgb = rgb_csv(&theme.accent);
    let sec_rgb = rgb_csv(&theme.secondary);
    let muted_rgb = rgb_csv(&theme.muted);
    let danger_rgb = rgb_csv(&theme.danger);
    let btn_alt_rgb = rgb_csv(&mix_hex(&theme.panel_bg, &theme.bg_secondary, 0.5));
    let sel_fg_hex = if luminance(&theme.accent) >= 0.55 { "#14171a" } else { "#ffffff" };
    let sel_fg_rgb = rgb_csv(sel_fg_hex);
    let small_pt = theme.font_size.saturating_sub(2).max(8);
    let pt = theme.font_size;
    let font_spec = format!("{},{pt},-1,5,400,0,0,0,0,0,0,0,0,0,0,1", theme.font_family);
    let bold_font_spec = format!("{},{pt},-1,5,600,0,0,0,0,0,0,0,0,0,0,1", theme.font_family);
    let small_font_spec = format!("{},{small_pt},-1,5,400,0,0,0,0,0,0,0,0,0,0,1", theme.font_family);

    let mut out = String::new();
    out.push_str(&format!(
        "[ColorEffects:Disabled]\n\
         Color={bg_rgb}\n\
         ColorAmount=0.25\n\
         ColorEffect=3\n\
         ContrastAmount=0.55\n\
         ContrastEffect=1\n\
         IntensityAmount=0.1\n\
         IntensityEffect=2\n\n\
         [ColorEffects:Inactive]\n\
         ChangeSelectionColor=true\n\
         Color={muted_rgb}\n\
         ColorAmount=0.05\n\
         ColorEffect=2\n\
         ContrastAmount=0.15\n\
         ContrastEffect=2\n\
         Enable=false\n\
         IntensityAmount=0\n\
         IntensityEffect=0\n\n"
    ));

    for (section, norm_bg, alt_bg, norm_fg) in [
        ("Colors:Window", &panel_rgb, &bg_rgb, &fg_rgb),
        ("Colors:View", &bg_rgb, &bg2_rgb, &fg_rgb),
        ("Colors:Button", &panel_rgb, &btn_alt_rgb, &fg_rgb),
        ("Colors:Selection", &accent_rgb, &sec_rgb, &sel_fg_rgb),
        ("Colors:Tooltip", &panel_rgb, &bg2_rgb, &fg_rgb),
        ("Colors:Complementary", &panel_rgb, &bg_rgb, &fg_rgb),
        ("Colors:Header", &panel_rgb, &bg2_rgb, &fg_rgb),
        ("Colors:Header][Inactive", &bg2_rgb, &panel_rgb, &muted_rgb),
    ] {
        let fg_active = if section == "Colors:Selection" { &sel_fg_rgb } else { &accent_rgb };
        let fg_link = if section == "Colors:Selection" { &sel_fg_rgb } else { &sec_rgb };
        out.push_str(&format!(
            "[{section}]\n\
             BackgroundAlternate={alt_bg}\n\
             BackgroundNormal={norm_bg}\n\
             DecorationFocus={accent_rgb}\n\
             DecorationHover={sec_rgb}\n\
             ForegroundActive={fg_active}\n\
             ForegroundInactive={muted_rgb}\n\
             ForegroundLink={fg_link}\n\
             ForegroundNegative={danger_rgb}\n\
             ForegroundNeutral={accent_rgb}\n\
             ForegroundNormal={norm_fg}\n\
             ForegroundPositive={sec_rgb}\n\
             ForegroundVisited={muted_rgb}\n\n"
        ));
    }

    out.push_str(&format!(
        "[General]\n\
         AccentColor={accent_rgb}\n\
         ColorScheme=AsciiDeActive\n\
         LastUsedCustomAccentColor={accent_rgb}\n\
         TerminalApplication=kitty -1\n\
         XftHintStyle=hintslight\n\
         XftSubPixel=none\n\
         fixed={font_spec}\n\
         font={font_spec}\n\
         menuFont={font_spec}\n\
         shadeSortColumn=true\n\
         smallestReadableFont={small_font_spec}\n\
         toolBarFont={font_spec}\n\n\
         [Icons]\n\
         Theme={icon_theme}\n\n\
         [KDE]\n\
         contrast=4\n\
         frameContrast=0.25\n\
         widgetStyle=Breeze\n\n\
         [WM]\n\
         activeBackground={panel_rgb}\n\
         activeBlend={accent_rgb}\n\
         activeFont={bold_font_spec}\n\
         activeForeground={fg_rgb}\n"
    ));
    out
}

pub fn render_gtk_colors_css(theme: &Theme) -> String {
    let sel_fg = if luminance(&theme.accent) >= 0.55 { "#14171a" } else { "#ffffff" };
    let border_col = mix_hex(&theme.grid_dot, &theme.muted, 0.5);
    format!(
        "/* Generated by ascii-de-backend theme sync-apps ({name}) */\n\
         @define-color theme_bg_color {bg};\n\
         @define-color theme_base_color {bg};\n\
         @define-color theme_fg_color {fg};\n\
         @define-color theme_text_color {fg};\n\
         @define-color theme_selected_bg_color {accent};\n\
         @define-color theme_selected_fg_color {sel_fg};\n\
         @define-color accent_bg_color {accent};\n\
         @define-color accent_fg_color {sel_fg};\n\
         @define-color accent_color {accent};\n\
         @define-color window_bg_color {bg};\n\
         @define-color window_fg_color {fg};\n\
         @define-color view_bg_color {bg2};\n\
         @define-color view_fg_color {fg};\n\
         @define-color headerbar_bg_color {panel};\n\
         @define-color headerbar_fg_color {fg};\n\
         @define-color card_bg_color {panel};\n\
         @define-color card_fg_color {fg};\n\
         @define-color popover_bg_color {panel};\n\
         @define-color popover_fg_color {fg};\n\
         @define-color borders {border_col};\n\
         @define-color destructive_color {danger};\n\
         @define-color success_color {sec};\n",
        name = theme.name,
        bg = theme.bg,
        bg2 = theme.bg_secondary,
        panel = theme.panel_bg,
        fg = theme.fg,
        accent = theme.accent,
        sec = theme.secondary,
        danger = theme.danger,
    )
}

pub fn render_gtk_css(theme: &Theme) -> String {
    let mut css = render_gtk_colors_css(theme);
    css.push_str(
        "\nwindow, dialog, .background {\n\
           background-color: @window_bg_color;\n\
           color: @window_fg_color;\n\
         }\n\
         headerbar {\n\
           background-color: @headerbar_bg_color;\n\
           color: @headerbar_fg_color;\n\
         }\n",
    );
    css
}

pub fn render_gtk_settings_ini(theme: &Theme) -> String {
    let is_light = luminance(&theme.bg) >= 0.5;
    let prefer_dark = if is_light { 0 } else { 1 };
    let icon_theme = if is_light { "breeze" } else { "breeze-dark" };
    format!(
        "[Settings]\n\
         gtk-theme-name=Breeze\n\
         gtk-icon-theme-name={icon_theme}\n\
         gtk-font-name={font} {size}\n\
         gtk-application-prefer-dark-theme={prefer_dark}\n",
        font = theme.font_family,
        size = theme.font_size,
    )
}

fn render_kitty_conf(theme: &Theme) -> String {
    let sel_fg = if luminance(&theme.accent) >= 0.55 { "#14171a" } else { "#ffffff" };
    format!(
        "# Generated by ascii-de-backend theme sync-apps ({name})\n\
         font_family {font}\n\
         font_size {size}.0\n\
         background {bg}\n\
         foreground {fg}\n\
         cursor {accent}\n\
         selection_background {accent}\n\
         selection_foreground {sel_fg}\n\
         active_border_color {accent}\n\
         inactive_border_color {muted}\n",
        name = theme.name,
        font = theme.font_family,
        size = theme.font_size,
        bg = theme.bg,
        fg = theme.fg,
        accent = theme.accent,
        muted = theme.muted,
    )
}

fn render_konsole_colorscheme(theme: &Theme) -> String {
    let bg = rgb_csv(&theme.bg);
    let bg2 = rgb_csv(&theme.bg_secondary);
    let panel = rgb_csv(&theme.panel_bg);
    let fg = rgb_csv(&theme.fg);
    let accent = rgb_csv(&theme.accent);
    let sec = rgb_csv(&theme.secondary);
    let muted = rgb_csv(&theme.muted);
    let danger = rgb_csv(&theme.danger);
    format!(
        "[Background]\nColor={bg}\n\n\
         [BackgroundIntense]\nColor={panel}\n\n\
         [BackgroundFaint]\nColor={bg2}\n\n\
         [Foreground]\nColor={fg}\n\n\
         [ForegroundIntense]\nColor={accent}\n\n\
         [ForegroundFaint]\nColor={muted}\n\n\
         [Color0]\nColor={bg}\n\n\
         [Color0Intense]\nColor={muted}\n\n\
         [Color1]\nColor={danger}\n\n\
         [Color1Intense]\nColor={danger}\n\n\
         [Color2]\nColor={sec}\n\n\
         [Color2Intense]\nColor={sec}\n\n\
         [Color3]\nColor={accent}\n\n\
         [Color3Intense]\nColor={accent}\n\n\
         [Color4]\nColor={sec}\n\n\
         [Color4Intense]\nColor={accent}\n\n\
         [Color5]\nColor={accent}\n\n\
         [Color5Intense]\nColor={sec}\n\n\
         [Color6]\nColor={sec}\n\n\
         [Color6Intense]\nColor={sec}\n\n\
         [Color7]\nColor={fg}\n\n\
         [Color7Intense]\nColor={fg}\n\n\
         [General]\nDescription=ASCII-DE Active ({name})\nOpacity=1\n",
        name = theme.name
    )
}

pub fn sync_apps_for_theme(theme: &Theme) -> Result<(), String> {
    let xdg_dir = xdg_config_dir();
    fs::create_dir_all(&xdg_dir).map_err(|e| format!("mkdir {}: {e}", xdg_dir.display()))?;
    ensure_app_symlinks(&xdg_dir);

    write_text_atomic(&xdg_dir.join("kdeglobals"), &render_kdeglobals(theme))?;

    let colors_css = render_gtk_colors_css(theme);
    let gtk_css = render_gtk_css(theme);
    let gtk_ini = render_gtk_settings_ini(theme);
    for gtk_ver in ["gtk-3.0", "gtk-4.0"] {
        let gdir = xdg_dir.join(gtk_ver);
        write_text_atomic(&gdir.join("colors.css"), &colors_css)?;
        write_text_atomic(&gdir.join("gtk.css"), &gtk_css)?;
        write_text_atomic(&gdir.join("settings.ini"), &gtk_ini)?;
    }

    write_text_atomic(&xdg_dir.join("ascii-de-kitty.conf"), &render_kitty_conf(theme))?;
    write_text_atomic(
        &xdg_dir.join("konsole-colors.colorscheme"),
        &render_konsole_colorscheme(theme),
    )?;
    Ok(())
}

pub fn presets_json() -> String {
    let mut out = String::from("[\n");
    for (i, p) in PRESETS.iter().enumerate() {
        let t = Theme::from(p);
        out.push_str("  ");
        out.push_str(&t.to_json());
        if i + 1 < PRESETS.len() {
            out.push(',');
        }
        out.push('\n');
    }
    out.push(']');
    out
}

pub fn handle_theme_cmd(args: &[String]) -> Result<String, String> {
    let sub = args.first().map(|s| s.as_str()).unwrap_or("get");
    match sub {
        "presets" => Ok(presets_json()),
        "get" => Ok(load_theme().to_json()),
        "set" => {
            let name = args
                .get(1)
                .ok_or_else(|| "theme set requires <amber|green|cyan|mono|snaptic>".to_string())?;
            set_theme(name)
        }
        "custom" => {
            let payload = args
                .get(1)
                .ok_or_else(|| "theme custom requires <json>".to_string())?;
            set_custom_theme(payload)
        }
        "sync-apps" => {
            let theme = load_theme();
            sync_apps_for_theme(&theme)?;
            let is_light = luminance(&theme.bg) >= 0.5;
            Ok(format!(
                "{{\"ok\":true,\"theme\":{},\"light\":{},\"xdg_config_home\":{}}}",
                escape_str(&theme.name),
                is_light,
                escape_str(&xdg_config_dir().display().to_string())
            ))
        }
        other => Err(format!("unknown theme subcommand: {other}")),
    }
}
