use crate::hardware;
use crate::json::escape_str;
use crate::maintain;
use std::env;
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

const GITHUB_NEW_ISSUE_BASE: &str = "https://github.com/programmerBober/ascii-de/issues/new";

fn xdg_data_home() -> PathBuf {
    env::var_os("XDG_DATA_HOME")
        .filter(|v| !v.is_empty())
        .map(PathBuf::from)
        .unwrap_or_else(|| hardware::home_dir().join(".local").join("share"))
}

fn bug_reports_dir() -> PathBuf {
    xdg_data_home().join("ascii-de").join("bug-reports")
}

fn find_in_path(bin: &str) -> Option<String> {
    let path_os = env::var_os("PATH")?;
    for dir in env::split_paths(&path_os) {
        let cand = dir.join(bin);
        if cand.is_file() {
            return Some(cand.to_string_lossy().into_owned());
        }
    }
    None
}

fn run_cmd_text(prog: &str, args: &[&str], max_lines: usize) -> String {
    let output = if find_in_path("timeout").is_some() {
        let mut cmd = Command::new("timeout");
        cmd.arg("3").arg(prog).args(args);
        cmd.output()
    } else {
        Command::new(prog).args(args).output()
    };

    match output {
        Ok(out) => {
            let mut combined = String::from_utf8_lossy(&out.stdout).into_owned();
            let err = String::from_utf8_lossy(&out.stderr);
            if !err.trim().is_empty() {
                if !combined.is_empty() && !combined.ends_with('\n') {
                    combined.push('\n');
                }
                combined.push_str(err.trim_end());
            }
            let lines: Vec<&str> = combined.lines().collect();
            if lines.is_empty() {
                format!("(exit {}, empty)", out.status.code().unwrap_or(-1))
            } else if lines.len() > max_lines {
                lines[lines.len() - max_lines..].join("\n")
            } else {
                lines.join("\n")
            }
        }
        Err(e) => format!("(unavailable: {e})"),
    }
}

fn read_os_pretty_name() -> String {
    let Ok(raw) = fs::read_to_string("/etc/os-release") else {
        return "Linux".to_string();
    };
    for line in raw.lines() {
        if let Some(rest) = line.strip_prefix("PRETTY_NAME=") {
            return rest.trim().trim_matches('"').to_string();
        }
    }
    "Linux".to_string()
}

pub fn sanitize_text(input: &str) -> String {
    let home = hardware::home_dir().to_string_lossy().into_owned();
    let user = hardware::user_name();
    let mut out = input.to_string();
    if !home.is_empty() && home != "/" {
        out = out.replace(&home, "~");
    }
    if !user.is_empty() && user != "user" && user != "root" {
        out = out.replace(&format!("/home/{user}"), "/home/<user>");
        out = out.replace(&format!("user {user}"), "user <user>");
    }

    let mut cleaned_lines = Vec::with_capacity(out.lines().count().max(1));
    for line in out.lines() {
        cleaned_lines.push(redact_line_secrets(line));
    }
    let mut joined = cleaned_lines.join("\n");
    if input.ends_with('\n') {
        joined.push('\n');
    }
    joined
}

fn redact_line_secrets(line: &str) -> String {
    let mut s = line.to_string();
    for prefix in ["ghp_", "github_pat_", "gho_", "glpat-"] {
        while let Some(idx) = s.find(prefix) {
            let tail = &s[idx + prefix.len()..];
            let token_len = tail
                .find(|c: char| !(c.is_ascii_alphanumeric() || c == '_'))
                .unwrap_or(tail.len());
            s.replace_range(idx..idx + prefix.len() + token_len, "<REDACTED_TOKEN>");
        }
    }
    let lower = s.to_ascii_lowercase();
    for key in ["authorization:", "password=", "passwd=", "api_key=", "token="] {
        if let Some(idx) = lower.find(key) {
            s.truncate(idx + key.len());
            s.push_str(" <REDACTED>");
            return s;
        }
    }
    s
}

fn tail_file(path: &Path, max_lines: usize) -> String {
    let Ok(raw) = fs::read_to_string(path) else {
        return String::new();
    };
    let lines: Vec<&str> = raw.lines().collect();
    if lines.len() > max_lines {
        lines[lines.len() - max_lines..].join("\n")
    } else {
        lines.join("\n")
    }
}

fn collect_cache_logs(cache_dir: &Path) -> String {
    let Ok(entries) = fs::read_dir(cache_dir) else {
        return "(no ~/.cache/ascii-de directory)".to_string();
    };
    let mut logs: Vec<PathBuf> = entries
        .filter_map(|e| e.ok().map(|x| x.path()))
        .filter(|p| p.is_file() && p.extension().and_then(|e| e.to_str()) == Some("log"))
        .collect();
    logs.sort();
    if logs.is_empty() {
        return "(no *.log files in ~/.cache/ascii-de)".to_string();
    }
    let mut out = String::new();
    for log_path in logs.into_iter().take(6) {
        let name = log_path
            .file_name()
            .map(|n| n.to_string_lossy().into_owned())
            .unwrap_or_default();
        let body = tail_file(&log_path, 45);
        out.push_str(&format!("--- {name} (tail) ---\n{}\n\n", body.trim_end()));
    }
    out.trim_end().to_string()
}

fn collect_tools_probe() -> String {
    let tools = [
        "ascii-de",
        "ascii-de-compositor",
        "ascii-de-backend",
        "ascii-de-terminal",
        "ascii-de-settings",
        "ascii-de-update",
        "bt-menu",
        "kitty",
        "foot",
        "alacritty",
        "konsole",
        "rofi",
        "bluetui",
        "bluetoothctl",
        "wpctl",
        "wiremix",
        "pulsemixer",
        "alsamixer",
        "kscreen-doctor",
        "wl-copy",
        "xdg-open",
        "curl",
        "jq",
    ];
    tools
        .iter()
        .map(|t| match find_in_path(t) {
            Some(p) => format!("{t:<20} : {p}"),
            None => format!("{t:<20} : MISSING"),
        })
        .collect::<Vec<_>>()
        .join("\n")
}

fn collect_journal_excerpt() -> String {
    let raw = run_cmd_text("journalctl", &["--user", "-n", "140", "--no-pager"], 140);
    let keywords = [
        "ascii-de",
        "compositor",
        "bt-menu",
        "bluetooth",
        "bluetui",
        "kitty",
        "foot",
        "rofi",
        "kwin",
        "pipewire",
        "wireplumber",
        "qml",
        "glfw",
        "egl",
        "wayland",
    ];
    let matched: Vec<&str> = raw
        .lines()
        .filter(|l| {
            let low = l.to_ascii_lowercase();
            keywords.iter().any(|k| low.contains(k))
        })
        .collect();
    if matched.is_empty() {
        raw.lines().rev().take(45).collect::<Vec<_>>().into_iter().rev().collect::<Vec<_>>().join("\n")
    } else if matched.len() > 70 {
        matched[matched.len() - 70..].join("\n")
    } else {
        matched.join("\n")
    }
}

pub fn build_report_text(note: &str) -> String {
    let ver = maintain::version_str();
    let os = read_os_pretty_name();
    let kernel = run_cmd_text("uname", &["-rm"], 4);
    let ts = maintain::utc_timestamp_compact();
    let desktop = env::var("XDG_CURRENT_DESKTOP").unwrap_or_default();
    let sess = env::var("XDG_SESSION_TYPE").unwrap_or_default();
    let wayland = env::var("WAYLAND_DISPLAY").unwrap_or_default();
    let display = env::var("DISPLAY").unwrap_or_default();
    let qpa = env::var("QT_QPA_PLATFORM").unwrap_or_default();

    let cfg_dir = hardware::ascii_config_dir();
    let cache_dir = hardware::xdg_cache_home().join("ascii-de");

    let gpus = run_cmd_text(
        "sh",
        &["-c", "lspci 2>/dev/null | grep -iE 'vga|3d|display|bluetooth|audio' || true"],
        15,
    );
    let dri = run_cmd_text("sh", &["-c", "ls -la /dev/dri 2>/dev/null || true"], 10);
    let bt_svc = run_cmd_text("systemctl", &["is-active", "bluetooth"], 3);
    let bt_ctl = run_cmd_text("bluetoothctl", &["show"], 20);
    let wp_status = run_cmd_text("wpctl", &["status"], 45);
    let displays = run_cmd_text("kscreen-doctor", &["-o"], 35);
    let scroll_svc = run_cmd_text(
        "systemctl",
        &["--user", "is-active", "ascii-de-x11-scroll-bridge.service"],
        3,
    );
    let settings_json = tail_file(&cfg_dir.join("settings.json"), 60);
    let cache_logs = collect_cache_logs(&cache_dir);
    let journal = collect_journal_excerpt();
    let tools = collect_tools_probe();

    let note_block = if note.trim().is_empty() {
        "(none provided)".to_string()
    } else {
        note.trim().to_string()
    };

    let raw = format!(
        "=== ASCII-DE DIAGNOSTIC BUG REPORT ===\n\
         Timestamp (UTC)      : {ts}\n\
         ASCII-DE Version     : {ver}\n\
         OS                   : {os}\n\
         Kernel               : {kernel}\n\
         Desktop / Session    : {desktop} / {sess}\n\
         WAYLAND_DISPLAY      : {wayland}\n\
         DISPLAY              : {display}\n\
         QT_QPA_PLATFORM      : {qpa}\n\
         Scroll Bridge Svc    : {scroll_svc}\n\n\
         --- USER DESCRIPTION ---\n\
         {note_block}\n\n\
         --- INSTALLED BINARIES ---\n\
         {tools}\n\n\
         --- HARDWARE (PCI / DRI) ---\n\
         {gpus}\n\
         {dri}\n\n\
         --- BLUETOOTH ---\n\
         bluetooth.service    : {bt_svc}\n\
         {bt_ctl}\n\n\
         --- AUDIO (wpctl status) ---\n\
         {wp_status}\n\n\
         --- DISPLAYS (kscreen-doctor -o) ---\n\
         {displays}\n\n\
         --- SETTINGS.JSON ---\n\
         {settings_json}\n\n\
         --- CACHE LOGS (~/.cache/ascii-de/*.log) ---\n\
         {cache_logs}\n\n\
         --- USER JOURNAL EXCERPT ---\n\
         {journal}\n"
    );
    sanitize_text(&raw)
}

fn copy_to_clipboard(text: &str) -> bool {
    let candidates: &[(&str, &[&str])] = &[
        ("wl-copy", &[]),
        ("xclip", &["-selection", "clipboard"]),
        ("xsel", &["--clipboard", "--input"]),
    ];
    for (bin, args) in candidates {
        if find_in_path(bin).is_none() {
            continue;
        }
        let Ok(mut child) = Command::new(bin)
            .args(*args)
            .stdin(Stdio::piped())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
        else {
            continue;
        };
        if let Some(mut stdin) = child.stdin.take() {
            let _ = stdin.write_all(text.as_bytes());
        }
        if let Ok(status) = child.wait() {
            if status.success() {
                return true;
            }
        }
    }
    false
}

fn upload_report(report_path: &Path) -> Result<String, String> {
    if find_in_path("curl").is_none() {
        return Err("curl is not installed".to_string());
    }
    let out = Command::new("curl")
        .args([
            "-fsS",
            "--max-time",
            "8",
            "--data-binary",
            &format!("@{}", report_path.display()),
            "https://paste.rs/",
        ])
        .output()
        .map_err(|e| format!("failed to run curl: {e}"))?;
    if !out.status.success() {
        let err = String::from_utf8_lossy(&out.stderr).trim().to_string();
        return Err(if err.is_empty() {
            format!("upload exited with {}", out.status)
        } else {
            err
        });
    }
    let url = String::from_utf8_lossy(&out.stdout).trim().to_string();
    if !url.starts_with("https://") {
        return Err(format!("unexpected upload response: {url}"));
    }
    Ok(url)
}

pub fn url_encode(input: &str) -> String {
    let mut out = String::with_capacity(input.len());
    for b in input.as_bytes() {
        match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                out.push(*b as char);
            }
            b' ' => out.push('+'),
            _ => out.push_str(&format!("%{b:02X}")),
        }
    }
    out
}

fn build_issue_url(note: &str, paste_url: Option<&str>, os: &str, kernel: &str) -> String {
    let ver = maintain::version_str();
    let clean_note = if note.trim().is_empty() {
        "Describe what happened here..."
    } else {
        note.trim()
    };
    let short_title = if note.trim().is_empty() {
        format!("[Bug] Issue on {os} (v{ver})")
    } else {
        let first_line = note.trim().lines().next().unwrap_or("Bug report");
        let clipped: String = first_line.chars().take(60).collect();
        format!("[Bug] {clipped}")
    };
    let logs_section = match paste_url {
        Some(url) => format!("Diagnostics URL: {url}\n"),
        None => "Full sanitized diagnostics were copied to clipboard — press Ctrl+V below or attach the saved `.txt` report.\n".to_string(),
    };
    let body = format!(
        "### Description\n{clean_note}\n\n\
         ### Environment\n\
         - ASCII-DE: `{ver}`\n\
         - OS: `{os}`\n\
         - Kernel: `{kernel}`\n\n\
         ### Logs\n{logs_section}"
    );
    format!(
        "{GITHUB_NEW_ISSUE_BASE}?title={}&body={}",
        url_encode(&short_title),
        url_encode(&body)
    )
}

pub fn handle_bug_report_cmd(args: &[String]) -> Result<String, String> {
    let mut upload = false;
    let mut note_parts: Vec<String> = Vec::new();
    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--upload" => upload = true,
            "--note" => {
                if let Some(val) = args.get(i + 1) {
                    note_parts.push(val.clone());
                    i += 1;
                }
            }
            other if !other.starts_with('-') => note_parts.push(other.to_string()),
            _ => {}
        }
        i += 1;
    }
    let note = note_parts.join(" ");

    let dir = bug_reports_dir();
    fs::create_dir_all(&dir).map_err(|e| format!("mkdir {}: {e}", dir.display()))?;
    let ts = maintain::utc_timestamp_compact();
    let file_path = dir.join(format!("ascii-de-bugreport-{ts}.txt"));

    let report_text = build_report_text(&note);
    fs::write(&file_path, &report_text)
        .map_err(|e| format!("write {}: {e}", file_path.display()))?;

    let mut paste_url = String::new();
    let mut upload_err = String::new();
    if upload {
        match upload_report(&file_path) {
            Ok(url) => paste_url = url,
            Err(err) => upload_err = err,
        }
    }

    let copied = if !paste_url.is_empty() {
        copy_to_clipboard(&paste_url)
    } else {
        copy_to_clipboard(&report_text)
    };

    let os = read_os_pretty_name();
    let kernel = run_cmd_text("uname", &["-rm"], 2);
    let issue_url = build_issue_url(
        &note,
        if paste_url.is_empty() { None } else { Some(&paste_url) },
        &os,
        &kernel,
    );

    let preview: String = report_text.lines().take(12).collect::<Vec<_>>().join("\n");
    Ok(format!(
        "{{\"ok\":true,\"path\":{},\"bytes\":{},\"copied\":{},\"pasteUrl\":{},\"uploadError\":{},\"issueUrl\":{},\"preview\":{}}}",
        escape_str(&file_path.to_string_lossy()),
        report_text.len(),
        copied,
        escape_str(&paste_url),
        escape_str(&upload_err),
        escape_str(&issue_url),
        escape_str(&preview)
    ))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sanitize_redacts_home_and_tokens() {
        let home = hardware::home_dir().to_string_lossy().into_owned();
        let sample = format!(
            "dir={home}/.config/ascii-de\nAuthorization: Bearer secret123\ntoken=ghp_abc123XYZ000\n"
        );
        let clean = sanitize_text(&sample);
        if home != "/" {
            assert!(!clean.contains(&home), "home path leaked: {clean}");
        }
        assert!(!clean.contains("secret123"));
        assert!(!clean.contains("ghp_abc123XYZ000"));
        assert!(clean.contains("<REDACTED"));
    }

    #[test]
    fn url_encode_handles_special_chars() {
        assert_eq!(url_encode("a b&c=d\ne"), "a+b%26c%3Dd%0Ae");
    }
}
