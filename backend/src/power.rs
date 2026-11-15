use crate::json;
use std::env;
use std::io::{self, BufRead, Write};
use std::process::{Command, Stdio};

fn resolve_username() -> String {
    if let Ok(u) = env::var("USER") {
        let trimmed = u.trim();
        if !trimmed.is_empty() {
            return trimmed.to_string();
        }
    }
    if let Ok(u) = env::var("LOGNAME") {
        let trimmed = u.trim();
        if !trimmed.is_empty() {
            return trimmed.to_string();
        }
    }
    if let Ok(out) = Command::new("id").arg("-un").output() {
        if out.status.success() {
            let s = String::from_utf8_lossy(&out.stdout).trim().to_string();
            if !s.is_empty() {
                return s;
            }
        }
    }
    String::new()
}

pub fn trim_password_line(raw: &str) -> &str {
    raw.trim_end_matches(&['\r', '\n'][..])
}

pub fn verify_password_with_unix_chkpwd(password: &str) -> Result<bool, String> {
    if password.is_empty() || password.contains('\0') {
        return Ok(false);
    }

    let user = resolve_username();
    if user.is_empty() {
        return Err("unable to determine current user".to_string());
    }

    let mut child = Command::new("/usr/bin/unix_chkpwd")
        .arg(&user)
        .arg("nullok")
        .stdin(Stdio::piped())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|e| format!("failed to spawn /usr/bin/unix_chkpwd: {e}"))?;

    if let Some(mut stdin) = child.stdin.take() {
        let mut payload = Vec::with_capacity(password.len() + 1);
        payload.extend_from_slice(password.as_bytes());
        payload.push(0);
        stdin
            .write_all(&payload)
            .map_err(|e| format!("failed to write password to unix_chkpwd: {e}"))?;
        let _ = stdin.flush();
    }

    let status = child
        .wait()
        .map_err(|e| format!("failed waiting for unix_chkpwd: {e}"))?;
    Ok(status.success())
}

pub fn map_systemctl_action(subcmd: &str) -> Option<&'static str> {
    match subcmd {
        "suspend" => Some("suspend"),
        "reboot" => Some("reboot"),
        "poweroff" => Some("poweroff"),
        _ => None,
    }
}

pub fn handle_power_cmd(args: &[String]) -> Result<String, String> {
    let sub = args.first().map(String::as_str).unwrap_or("");
    match sub {
        "verify" => {
            let mut line = String::new();
            let stdin = io::stdin();
            let mut locked = stdin.lock();
            locked
                .read_line(&mut line)
                .map_err(|e| format!("failed to read password from stdin: {e}"))?;
            let pw = trim_password_line(&line);
            let ok = verify_password_with_unix_chkpwd(pw)?;
            Ok(format!("{{\"ok\":{ok}}}"))
        }
        "suspend" | "reboot" | "poweroff" => {
            let action = map_systemctl_action(sub).expect("validated action");
            let status = Command::new("systemctl")
                .arg(action)
                .status()
                .map_err(|e| format!("failed to run systemctl {action}: {e}"))?;
            if status.success() {
                Ok(format!(
                    "{{\"ok\":true,\"action\":{}}}",
                    json::escape_str(action)
                ))
            } else {
                Err(format!(
                    "systemctl {action} exited with status {}",
                    status.code().unwrap_or(-1)
                ))
            }
        }
        "" => Err("missing power subcommand (expected: verify|suspend|reboot|poweroff)".to_string()),
        other => Err(format!("unknown power subcommand: {other}")),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn power_helpers_and_empty_password() {
        assert_eq!(trim_password_line("secret\r\n"), "secret");
        assert_eq!(trim_password_line("secret\n"), "secret");
        assert_eq!(trim_password_line("secret"), "secret");

        assert_eq!(map_systemctl_action("suspend"), Some("suspend"));
        assert_eq!(map_systemctl_action("reboot"), Some("reboot"));
        assert_eq!(map_systemctl_action("poweroff"), Some("poweroff"));
        assert_eq!(map_systemctl_action("halt"), None);

        assert!(!verify_password_with_unix_chkpwd("").unwrap());
        assert!(!verify_password_with_unix_chkpwd("abc\0def").unwrap());
    }
}
