mod audio;
mod bg_ascii;
mod bugreport;
mod displays;
mod hardware;
mod icons;
mod json;
mod maintain;
mod power;
mod settings;
mod system;
mod theme;

use std::env;
use std::process::ExitCode;

fn print_usage() {
    eprintln!(
        "Usage: ascii-de-backend <COMMAND> [ARGS]\n\n\
         Commands:\n\
         \x20 status\n\
         \x20 apps\n\
         \x20 displays <list|save|apply|reset> ...\n\
         \x20 icons <list|add|remove|move|edit> ...\n\
         \x20 audio <vol|mute|onkyo|bt|toggle|set-sink> ...\n\
         \x20 settings <get|set|reset> ...\n\
         \x20 power <verify|suspend|reboot|poweroff>\n\
         \x20 theme [presets|get|set <amber|green|cyan|mono|snaptic>|custom <json>|sync-apps]\n\
         \x20 bg-ascii convert <json>\n\
         \x20 version [--json]\n\
         \x20 migrate\n\
         \x20 update-check\n\
         \x20 bug-report [--note <text>] [--upload]"
    );
}

fn main() -> ExitCode {
    let args: Vec<String> = env::args().skip(1).collect();
    let Some(cmd) = args.first() else {
        print_usage();
        return ExitCode::from(2);
    };

    let res = match cmd.as_str() {
        "status" => Ok(system::handle_status_cmd()),
        "apps" => Ok(system::handle_apps_cmd()),
        "displays" => displays::handle_displays_cmd(&args[1..]),
        "icons" => icons::handle_icons_cmd(&args[1..]),
        "audio" => audio::handle_audio_cmd(&args[1..]),
        "settings" => settings::handle_settings_cmd(&args[1..]),
        "power" => power::handle_power_cmd(&args[1..]),
        "theme" => theme::handle_theme_cmd(&args[1..]),
        "bg-ascii" => bg_ascii::handle_bg_ascii_cmd(&args[1..]),
        "version" | "--version" | "-V" => Ok(maintain::handle_version_cmd(&args[1..])),
        "migrate" => maintain::handle_migrate_cmd(),
        "update-check" => Ok(maintain::handle_update_check_cmd(&args[1..])),
        "bug-report" => bugreport::handle_bug_report_cmd(&args[1..]),
        "-h" | "--help" | "help" => {
            print_usage();
            return ExitCode::SUCCESS;
        }
        other => Err(format!("unknown command: {other}")),
    };

    match res {
        Ok(json_out) => {
            println!("{json_out}");
            ExitCode::SUCCESS
        }
        Err(err) => {
            eprintln!("{{\"error\":{}}}", json::escape_str(&err));
            ExitCode::from(1)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::json;

    #[test]
    fn parse_roundtrip_json() {
        let sample = r#"[{"index":124,"name":"alsa_output.test","mute":false,"volume":{"fl":{"value_percent":"100%"}}}]"#;
        let v = json::parse(sample).expect("valid json");
        let arr = v.as_arr().expect("array");
        assert_eq!(arr[0].get("index").and_then(|x| x.as_i64()), Some(124));
        assert_eq!(arr[0].get("mute").and_then(|x| x.as_bool()), Some(false));
    }

    #[test]
    fn displays_roundtrip_and_serialize() {
        let sample = r#"[{"name":"DP-2","description":"AOC 24P1W1","width":1920,"height":1080,"refresh":59.94,"x":840,"y":1079,"rotation":90,"scale":1,"primary":true,"enabled":true,"available_modes":["1920x1080@59.94"],"onkyo_avr":false},{"name":"HDMI-A-1","description":"ONKYO HT-R758","width":1920,"height":1080,"refresh":60.0,"x":1920,"y":1581,"rotation":0,"scale":1,"primary":false,"enabled":true,"onkyo_avr":true}]"#;
        let parsed = json::parse(sample).expect("valid monitor json");
        let arr = parsed.as_arr().expect("array");
        assert_eq!(arr.len(), 2);
        assert_eq!(arr[0].get("refresh").and_then(|v| v.as_f64()), Some(59.94));
        assert_eq!(arr[1].get("onkyo_avr").and_then(|v| v.as_bool()), Some(true));
    }

    #[test]
    fn settings_validation_and_clamping() {
        let mut s = super::settings::AppSettings::default();
        let val = json::parse(
            r#"{"theme":"CYAN","fontSize":99,"snapThresholdPx":4,"gridDensity":"dense","startMenuDefaultMode":"folders","clockShowSeconds":false}"#,
        )
        .expect("valid settings json");
        s.apply_json(&val).expect("apply");
        assert_eq!(s.theme, "cyan");
        assert_eq!(s.font_size, 16);
        assert_eq!(s.snap_threshold_px, 12);
        assert_eq!(s.grid_density, "dense");
        assert_eq!(s.start_menu_default_mode, "folders");
        assert!(!s.clock_show_seconds);
    }

    #[test]
    fn theme_overhaul_snaptic_and_custom() {
        let presets = super::theme::presets_json();
        let arr_val = json::parse(&presets).expect("presets json");
        let arr = arr_val.as_arr().expect("array");
        assert_eq!(arr.len(), 6);
        let xmas = arr
            .iter()
            .find(|x| x.get("name").and_then(|v| v.as_str()) == Some("xmas"))
            .expect("xmas preset");
        assert_eq!(xmas.get("backgroundStyle").and_then(|v| v.as_str()), Some("christmas_tree"));
        assert_eq!(xmas.get("xmasMonitor").and_then(|v| v.as_str()), Some("tallest"));
        let snap = arr
            .iter()
            .find(|x| x.get("name").and_then(|v| v.as_str()) == Some("snaptic"))
            .expect("snaptic preset");
        assert_eq!(snap.get("chromeStyle").and_then(|v| v.as_str()), Some("snaptic_datalens"));
        assert_eq!(snap.get("backgroundStyle").and_then(|v| v.as_str()), Some("snaptic_void"));
        assert_eq!(snap.get("cornerRadius").and_then(|v| v.as_i64()), Some(10));
        assert_eq!(snap.get("smearDrag").and_then(|v| v.as_bool()), Some(true));

        let mut custom = super::theme::load_theme();
        let patch = json::parse(r##"{"bg":"#112233","fontSize":20,"chromeStyle":"minimal","backgroundStyle":"custom_text","customBgText":"  /\\_/\\\n ( o.o )","smearDrag":true}"##).expect("patch");
        custom.apply_json(&patch).expect("apply patch");
        assert_eq!(custom.bg, "#112233");
        assert_eq!(custom.font_size, 16);
        assert_eq!(custom.chrome_style, "minimal");
        assert_eq!(custom.background_style, "custom_text");
        assert_eq!(custom.custom_bg_text, "  /\\_/\\\n ( o.o )");
        assert!(custom.smear_drag);

        let mut cfg = super::settings::AppSettings::default();
        let s_patch = json::parse(r##"{"bgTerminalEnabled":true,"bgTerminalCmd":"htop","bgTerminalInteractive":false,"bgTerminalWidth":9999,"bgTerminalHeight":50}"##).expect("s_patch");
        cfg.apply_json(&s_patch).expect("apply settings");
        assert!(cfg.bg_terminal_enabled);
        assert_eq!(cfg.bg_terminal_cmd, "htop");
        assert!(!cfg.bg_terminal_interactive);
        assert_eq!(cfg.bg_terminal_width, 3840);
        assert_eq!(cfg.bg_terminal_height, 160);
    }

    #[test]
    fn kdeglobals_and_gtk_generation_snaptic_and_amber() {
        let presets_val = json::parse(&super::theme::presets_json()).expect("presets");
        let presets = presets_val.as_arr().expect("array");

        let mut snaptic = super::theme::load_theme();
        let snap_obj = presets
            .iter()
            .find(|x| x.get("name").and_then(|v| v.as_str()) == Some("snaptic"))
            .expect("snaptic");
        snaptic.apply_json(snap_obj).expect("apply snaptic");

        let snap_kde = super::theme::render_kdeglobals(&snaptic);
        assert!(snap_kde.contains("BackgroundNormal=232,236,252"));
        assert!(snap_kde.contains("Theme=breeze\n"));
        let snap_gtk = super::theme::render_gtk_css(&snaptic);
        assert!(snap_gtk.contains("@define-color theme_bg_color #E8ECFC;"));
        let snap_ini = super::theme::render_gtk_settings_ini(&snaptic);
        assert!(snap_ini.contains("gtk-application-prefer-dark-theme=0"));

        let mut amber = super::theme::load_theme();
        let amber_obj = presets
            .iter()
            .find(|x| x.get("name").and_then(|v| v.as_str()) == Some("amber"))
            .expect("amber");
        amber.apply_json(amber_obj).expect("apply amber");

        let amb_kde = super::theme::render_kdeglobals(&amber);
        assert!(amb_kde.contains("BackgroundNormal=13,15,16"));
        assert!(amb_kde.contains("Theme=breeze-dark\n"));
        let amb_gtk = super::theme::render_gtk_css(&amber);
        assert!(amb_gtk.contains("@define-color theme_bg_color #0d0f10;"));
        let amb_ini = super::theme::render_gtk_settings_ini(&amber);
        assert!(amb_ini.contains("gtk-application-prefer-dark-theme=1"));
    }

    #[test]
    fn kscreen_args_uses_priority_without_legacy_primary() {
        use std::collections::HashMap;
        let mons = vec![
            super::displays::MonitorConfig {
                name: "DP-2".into(),
                description: "AOC".into(),
                width: 1920,
                height: 1080,
                refresh: 60.0,
                x: 0,
                y: 0,
                rotation: 90,
                scale: 1.0,
                primary: false,
                enabled: true,
                available_modes: vec![],
                onkyo_avr: false,
            },
            super::displays::MonitorConfig {
                name: "HDMI-A-1".into(),
                description: "ONKYO".into(),
                width: 1920,
                height: 1080,
                refresh: 60.0,
                x: 1080,
                y: 0,
                rotation: 0,
                scale: 1.0,
                primary: true,
                enabled: true,
                available_modes: vec![],
                onkyo_avr: true,
            },
        ];
        let mut mode_ids = HashMap::new();
        mode_ids.insert("HDMI-A-1".into(), vec![("1".into(), 1920, 1080, 60.0)]);
        let args = super::displays::build_kscreen_args(&mons, &["DP-2", "HDMI-A-1"], &mode_ids);
        assert!(args.contains(&"output.HDMI-A-1.priority.1".to_string()));
        assert!(args.contains(&"output.DP-2.priority.2".to_string()));
        assert!(!args.iter().any(|a| a.ends_with(".primary")));
    }

    #[test]
    fn bg_ascii_helpers_and_ansi_html() {
        use super::bg_ascii;
        assert_eq!(bg_ascii::normalize_charset("BLOCKS"), "blocks");
        assert_eq!(bg_ascii::normalize_charset("braille"), "braille");
        assert_eq!(bg_ascii::normalize_charset("unknown"), "ascii");

        assert_eq!(bg_ascii::normalize_color_mode("THEME"), "theme");
        assert_eq!(bg_ascii::normalize_color_mode("mono"), "theme");
        assert_eq!(bg_ascii::normalize_color_mode("colored"), "colored");

        let raw = "\x1b[38;2;255;85;0mOrange\x1b[0m Text\n";
        let (html, plain) = bg_ascii::ansi_to_html_and_plain(raw);
        assert!(html.contains("<span style=\"color:#ff5500\">Orange</span> Text"));
        assert_eq!(plain, "Orange Text\n");
    }

    #[test]
    fn theme_monitor_backgrounds_and_terminal_cmd() {
        let mut t = super::theme::load_theme();
        let patch = json::parse(
            r#"{"backgroundStyle":"terminal","monitorBackgrounds":{"HDMI-A-1":"ascii_image","DP-2":"newsboard"},"bgTerminalCmd":"cmatrix"}"#,
        )
        .expect("patch json");
        t.apply_json(&patch).expect("apply patch");
        assert_eq!(t.background_style, "terminal");
        assert_eq!(t.bg_terminal_cmd, "cmatrix");
        assert_eq!(t.monitor_backgrounds.get("HDMI-A-1").map(String::as_str), Some("ascii_image"));
        assert_eq!(t.monitor_backgrounds.get("DP-2").map(String::as_str), Some("newsboard"));

        let out = t.to_json();
        let parsed = json::parse(&out).expect("roundtrip json");
        assert_eq!(parsed.get("backgroundStyle").and_then(|x| x.as_str()), Some("terminal"));
        assert_eq!(parsed.get("bgTerminalCmd").and_then(|x| x.as_str()), Some("cmatrix"));
        let mb = parsed.get("monitorBackgrounds").and_then(|x| x.as_obj()).expect("mb obj");
        assert_eq!(mb.get("HDMI-A-1").and_then(|x| x.as_str()), Some("ascii_image"));
    }

    #[test]
    fn settings_layout_tiles_and_monitor_ascii_images() {
        let mut s = super::settings::AppSettings::default();
        let patch = json::parse(
            r#"{
                "bgTerminalFontSize": 14,
                "bgTerminalOpacity": 0.25,
                "bgTerminalMatchGrid": false,
                "bgLayoutTiles": [
                    {
                        "id": "tile-term-1",
                        "kind": "terminal",
                        "monitor": "DP-2",
                        "x": 100,
                        "y": 120,
                        "width": 800,
                        "height": 400,
                        "enabled": true,
                        "cmd": "htop",
                        "interactive": true,
                        "fontSize": 12,
                        "opacity": 0.1,
                        "matchGrid": true,
                        "imagePath": "",
                        "charset": "ascii",
                        "colorMode": "colored",
                        "fitMode": "fit",
                        "invert": false
                    },
                    {
                        "id": "tile-img-1",
                        "kind": "ascii_image",
                        "monitor": "HDMI-A-1",
                        "x": 200,
                        "y": 200,
                        "width": 640,
                        "height": 480,
                        "enabled": false,
                        "cmd": "",
                        "interactive": false,
                        "fontSize": 0,
                        "opacity": 0.0,
                        "matchGrid": true,
                        "imagePath": "/tmp/test.png",
                        "charset": "blocks",
                        "colorMode": "theme",
                        "fitMode": "cover",
                        "invert": true
                    }
                ],
                "monitorAsciiImages": {
                    "DP-2": {
                        "imagePath": "/tmp/wallpaper.jpg",
                        "charset": "braille",
                        "colorMode": "colored",
                        "fitMode": "cover",
                        "invert": false,
                        "opacity": 0.3
                    }
                }
            }"#,
        )
        .expect("patch json");
        s.apply_json(&patch).expect("apply patch");
        assert_eq!(s.bg_terminal_font_size, 14);
        assert!((s.bg_terminal_opacity - 0.25).abs() < 1e-4);
        assert!(!s.bg_terminal_match_grid);
        assert_eq!(s.bg_layout_tiles.len(), 2);
        assert_eq!(s.bg_layout_tiles[0].id, "tile-term-1");
        assert_eq!(s.bg_layout_tiles[0].kind, "terminal");
        assert_eq!(s.bg_layout_tiles[1].id, "tile-img-1");
        assert_eq!(s.bg_layout_tiles[1].kind, "ascii_image");
        assert_eq!(s.bg_layout_tiles[1].charset, "blocks");
        assert_eq!(s.bg_layout_tiles[1].color_mode, "theme");

        let dp2_img = s.monitor_ascii_images.get("DP-2").expect("DP-2 image");
        assert_eq!(dp2_img.image_path, "/tmp/wallpaper.jpg");
        assert_eq!(dp2_img.charset, "braille");
        assert_eq!(dp2_img.fit_mode, "cover");

        // Test backward compat: when bgTerminalEnabled is true and bgLayoutTiles is omitted, tile-1 is seeded
        let mut s2 = super::settings::AppSettings::default();
        let legacy_patch = json::parse(r#"{"bgTerminalEnabled":true,"bgTerminalCmd":"asciiquarium","bgTerminalWidth":950}"#).expect("legacy json");
        s2.apply_json(&legacy_patch).expect("apply legacy");
        assert_eq!(s2.bg_layout_tiles.len(), 1);
        assert_eq!(s2.bg_layout_tiles[0].id, "tile-1");
        assert_eq!(s2.bg_layout_tiles[0].cmd, "asciiquarium");
        assert_eq!(s2.bg_layout_tiles[0].width, 950);
    }

    #[test]
    fn version_and_hardware_gating_tests() {
        let txt = super::maintain::handle_version_cmd(&[]);
        assert!(txt.starts_with("ascii-de-backend "));
        let j = super::maintain::handle_version_cmd(&["--json".to_string()]);
        let parsed = json::parse(&j).expect("version json");
        assert_eq!(parsed.get("name").and_then(|x| x.as_str()), Some("ascii-de-backend"));
        assert!(!parsed.get("version").and_then(|x| x.as_str()).unwrap_or("").is_empty());

        let prof = super::hardware::HardwareProfile::default();
        assert!(super::hardware::is_onkyo_sink("alsa_output.test", "Onkyo HT-R758 HDMI", &prof));
        assert!(!super::hardware::is_onkyo_sink("alsa_output.pci-0000_00_1f.3.analog-stereo", "Built-in Audio", &prof));
        assert!(super::hardware::is_onkyo_monitor("HDMI-A-2", "ONKYO Corporation HT-R758", &prof));
        assert!(!super::hardware::is_onkyo_monitor("Virtual-1", "QEMU Monitor", &prof));
    }

    #[test]
    fn migrate_preserves_user_settings_and_creates_backup() {
        let tmp = std::env::temp_dir().join(format!("ascii-de-migrate-test-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&tmp);
        std::fs::create_dir_all(&tmp).expect("mkdir tmp");
        std::fs::write(tmp.join("settings.json"), r#"{"theme":"cyan","fontSize":15}"#).expect("write settings");
        std::fs::write(tmp.join("theme.json"), r##"{"name":"custom","accent":"#123456"}"##).expect("write theme");

        let out = super::maintain::migrate_dir(&tmp).expect("migrate_dir");
        let res = json::parse(&out).expect("migrate json");
        assert_eq!(res.get("ok").and_then(|x| x.as_bool()), Some(true));
        let backup_dir = res.get("backup_dir").and_then(|x| x.as_str()).expect("backup_dir");
        assert!(std::path::Path::new(backup_dir).join("settings.json").is_file());
        assert!(std::path::Path::new(backup_dir).join("theme.json").is_file());

        let new_settings = json::parse(&std::fs::read_to_string(tmp.join("settings.json")).unwrap()).unwrap();
        assert_eq!(new_settings.get("theme").and_then(|x| x.as_str()), Some("cyan"));
        assert_eq!(new_settings.get("fontSize").and_then(|x| x.as_i64()), Some(15));
        assert!(new_settings.get("gridDensity").is_some());

        let new_theme = json::parse(&std::fs::read_to_string(tmp.join("theme.json")).unwrap()).unwrap();
        assert_eq!(new_theme.get("accent").and_then(|x| x.as_str()), Some("#123456"));
        assert!(new_theme.get("bg").is_some());

        let _ = std::fs::remove_dir_all(&tmp);
    }
}
