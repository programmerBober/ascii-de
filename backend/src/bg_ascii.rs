use crate::json::{self, escape_str};
use crate::theme::{atomic_write, config_dir};
use std::collections::hash_map::DefaultHasher;
use std::fs;
use std::hash::{Hash, Hasher};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::UNIX_EPOCH;

fn cache_dir() -> PathBuf {
    config_dir().join("ascii-cache")
}

fn find_chafa() -> Option<&'static str> {
    ["/usr/bin/chafa", "/usr/local/bin/chafa", "chafa"]
        .into_iter()
        .find(|&candidate| Path::new(candidate).exists() || candidate == "chafa")
}

pub fn normalize_charset(raw: &str) -> String {
    match raw.trim().to_ascii_lowercase().as_str() {
        "blocks" | "block" => "blocks".to_string(),
        "braille" => "braille".to_string(),
        _ => "ascii".to_string(),
    }
}

pub fn normalize_color_mode(raw: &str) -> String {
    match raw.trim().to_ascii_lowercase().as_str() {
        "theme" | "mono" => "theme".to_string(),
        _ => "colored".to_string(),
    }
}

fn html_escape_char(out: &mut String, ch: char) {
    match ch {
        '&' => out.push_str("&amp;"),
        '<' => out.push_str("&lt;"),
        '>' => out.push_str("&gt;"),
        '"' => out.push_str("&quot;"),
        _ => out.push(ch),
    }
}

fn ansi_256_to_rgb(idx: u8) -> (u8, u8, u8) {
    const BASE16: [(u8, u8, u8); 16] = [
        (0, 0, 0),
        (170, 0, 0),
        (0, 170, 0),
        (170, 85, 0),
        (0, 0, 170),
        (170, 0, 170),
        (0, 170, 170),
        (170, 170, 170),
        (85, 85, 85),
        (255, 85, 85),
        (85, 255, 85),
        (255, 255, 85),
        (85, 85, 255),
        (255, 85, 255),
        (85, 255, 255),
        (255, 255, 255),
    ];
    if idx < 16 {
        return BASE16[idx as usize];
    }
    if idx < 232 {
        let i = idx - 16;
        let r = i / 36;
        let g = (i % 36) / 6;
        let b = i % 6;
        let lvl = |v: u8| if v == 0 { 0 } else { 55 + v * 40 };
        return (lvl(r), lvl(g), lvl(b));
    }
    let gray = 8 + (idx - 232) * 10;
    (gray, gray, gray)
}

/// Convert ANSI SGR text (from `chafa -f symbols`) into `(html_lines, plain_text)`.
pub fn ansi_to_html_and_plain(ansi: &str) -> (String, String) {
    let mut html = String::with_capacity(ansi.len() * 2 + 64);
    let mut plain = String::with_capacity(ansi.len());
    html.push_str("<pre style=\"margin:0;line-height:1.0;\">");

    let mut cur_fg: Option<String> = None;
    let mut span_open = false;
    let bytes = ansi.as_bytes();
    let mut i = 0usize;

    let close_span = |html: &mut String, span_open: &mut bool| {
        if *span_open {
            html.push_str("</span>");
            *span_open = false;
        }
    };

    while i < bytes.len() {
        if bytes[i] == 0x1b && i + 1 < bytes.len() && bytes[i + 1] == b'[' {
            // CSI sequence: find final byte in 0x40..=0x7E
            let mut j = i + 2;
            while j < bytes.len() && !(0x40..=0x7e).contains(&bytes[j]) {
                j += 1;
            }
            if j < bytes.len() {
                if bytes[j] == b'm' {
                    let params = std::str::from_utf8(&bytes[i + 2..j]).unwrap_or("");
                    let nums: Vec<u16> = params
                        .split(';')
                        .filter_map(|p| if p.is_empty() { Some(0) } else { p.parse::<u16>().ok() })
                        .collect();
                    let mut idx = 0usize;
                    if nums.is_empty() {
                        cur_fg = None;
                    }
                    while idx < nums.len() {
                        match nums[idx] {
                            0 | 39 => {
                                cur_fg = None;
                                idx += 1;
                            }
                            38 => {
                                if idx + 4 < nums.len() && nums[idx + 1] == 2 {
                                    cur_fg = Some(format!(
                                        "#{:02x}{:02x}{:02x}",
                                        nums[idx + 2].min(255),
                                        nums[idx + 3].min(255),
                                        nums[idx + 4].min(255)
                                    ));
                                    idx += 5;
                                } else if idx + 2 < nums.len() && nums[idx + 1] == 5 {
                                    let (r, g, b) = ansi_256_to_rgb(nums[idx + 2].min(255) as u8);
                                    cur_fg = Some(format!("#{r:02x}{g:02x}{b:02x}"));
                                    idx += 3;
                                } else {
                                    idx += 1;
                                }
                            }
                            c @ 30..=37 => {
                                let (r, g, b) = ansi_256_to_rgb((c - 30) as u8);
                                cur_fg = Some(format!("#{r:02x}{g:02x}{b:02x}"));
                                idx += 1;
                            }
                            c @ 90..=97 => {
                                let (r, g, b) = ansi_256_to_rgb((c - 90 + 8) as u8);
                                cur_fg = Some(format!("#{r:02x}{g:02x}{b:02x}"));
                                idx += 1;
                            }
                            _ => {
                                idx += 1;
                            }
                        }
                    }
                    close_span(&mut html, &mut span_open);
                }
                i = j + 1;
                continue;
            }
        } else if bytes[i] == 0x1b {
            i += 1;
            continue;
        }

        let rest = std::str::from_utf8(&bytes[i..]).unwrap_or("");
        let Some(ch) = rest.chars().next() else {
            break;
        };
        i += ch.len_utf8();

        if ch == '\r' {
            continue;
        }
        if ch == '\n' {
            close_span(&mut html, &mut span_open);
            html.push('\n');
            plain.push('\n');
            continue;
        }
        plain.push(ch);
        if let Some(ref hex) = cur_fg {
            if !span_open {
                html.push_str("<span style=\"color:");
                html.push_str(hex);
                html.push_str("\">");
                span_open = true;
            }
        } else {
            close_span(&mut html, &mut span_open);
        }
        html_escape_char(&mut html, ch);
    }
    close_span(&mut html, &mut span_open);
    html.push_str("</pre>");
    (html, plain)
}

struct CacheKeyParams<'a> {
    path: &'a str,
    mtime_secs: u64,
    cols: i64,
    rows: i64,
    charset: &'a str,
    color_mode: &'a str,
    invert: bool,
    bg_hex: &'a str,
}

fn compute_cache_key(p: &CacheKeyParams<'_>) -> String {
    let mut h = DefaultHasher::new();
    p.path.hash(&mut h);
    p.mtime_secs.hash(&mut h);
    p.cols.hash(&mut h);
    p.rows.hash(&mut h);
    p.charset.hash(&mut h);
    p.color_mode.hash(&mut h);
    p.invert.hash(&mut h);
    p.bg_hex.hash(&mut h);
    format!("{:016x}", h.finish())
}

pub fn handle_bg_ascii_cmd(args: &[String]) -> Result<String, String> {
    let sub = args.first().map(|s| s.as_str()).unwrap_or("convert");
    if sub != "convert" {
        return Err(format!("unknown bg-ascii subcommand: {sub}"));
    }
    let payload = args
        .get(1)
        .ok_or_else(|| "bg-ascii convert requires <json>".to_string())?;
    let val = json::parse(payload)?;
    let image_path = val
        .get("imagePath")
        .and_then(|x| x.as_str())
        .map(str::trim)
        .unwrap_or("");
    if image_path.is_empty() {
        return Err("imagePath cannot be empty".to_string());
    }
    let expanded_path = if let Some(rest) = image_path.strip_prefix("~/") {
        crate::hardware::home_dir().join(rest).to_string_lossy().into_owned()
    } else {
        image_path.to_string()
    };
    let path_obj = Path::new(&expanded_path);
    if !path_obj.exists() || !path_obj.is_file() {
        return Err(format!("image file not found: {expanded_path}"));
    }

    let cols = val.get("cols").and_then(|x| x.as_i64()).unwrap_or(100).clamp(16, 360);
    let rows = val.get("rows").and_then(|x| x.as_i64()).unwrap_or(40).clamp(8, 180);
    let charset = normalize_charset(val.get("charset").and_then(|x| x.as_str()).unwrap_or("ascii"));
    let color_mode = normalize_color_mode(val.get("colorMode").and_then(|x| x.as_str()).unwrap_or("colored"));
    let invert = val.get("invert").and_then(|x| x.as_bool()).unwrap_or(false);
    let bg_hex = val
        .get("bg")
        .and_then(|x| x.as_str())
        .map(str::trim)
        .filter(|s| s.starts_with('#') && s.len() == 7)
        .unwrap_or("#0d0f10");

    let meta = fs::metadata(path_obj).map_err(|e| format!("stat failed: {e}"))?;
    let mtime_secs = meta
        .modified()
        .ok()
        .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let canonical = fs::canonicalize(path_obj)
        .map(|p| p.to_string_lossy().into_owned())
        .unwrap_or_else(|_| expanded_path.clone());

    let key = compute_cache_key(&CacheKeyParams {
        path: &canonical,
        mtime_secs,
        cols,
        rows,
        charset: &charset,
        color_mode: &color_mode,
        invert,
        bg_hex,
    });
    let cache_file = cache_dir().join(format!("{key}.json"));
    if cache_file.exists() {
        if let Ok(cached) = fs::read_to_string(&cache_file) {
            if !cached.trim().is_empty() {
                return Ok(cached.trim().to_string());
            }
        }
    }

    let chafa = find_chafa().ok_or_else(|| "chafa binary not found".to_string())?;
    let symbols_arg = match charset.as_str() {
        "blocks" => "block+half",
        "braille" => "braille",
        _ => "ascii",
    };

    let mut cmd = Command::new(chafa);
    cmd.arg("--format=symbols")
        .arg(format!("--size={cols}x{rows}"))
        .arg(format!("--symbols={symbols_arg}"))
        .arg("--bg")
        .arg(bg_hex);
    if color_mode == "theme" {
        cmd.arg("--colors=none");
    } else {
        cmd.arg("--color-space=rgb").arg("--colors=full");
    }
    if invert {
        cmd.arg("--invert");
    }
    cmd.arg(&canonical);

    let out = cmd
        .output()
        .map_err(|e| format!("failed to run chafa: {e}"))?;
    if !out.status.success() {
        let stderr = String::from_utf8_lossy(&out.stderr);
        return Err(format!("chafa failed: {}", stderr.trim()));
    }

    let raw_ansi = String::from_utf8_lossy(&out.stdout);
    let (html, plain) = ansi_to_html_and_plain(&raw_ansi);
    let response = format!(
        "{{\"ok\":true,\"key\":{},\"cols\":{cols},\"rows\":{rows},\"charset\":{},\"colorMode\":{},\"html\":{},\"plain\":{}}}",
        escape_str(&key),
        escape_str(&charset),
        escape_str(&color_mode),
        escape_str(&html),
        escape_str(&plain)
    );
    let _ = atomic_write(&cache_file, &(response.clone() + "\n"));
    Ok(response)
}
