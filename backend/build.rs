use std::fs;
use std::path::Path;

fn main() {
    let version_path = Path::new("../VERSION");
    println!("cargo:rerun-if-changed=../VERSION");
    let ver = fs::read_to_string(version_path)
        .ok()
        .and_then(|s| s.lines().next().map(|l| l.trim().to_string()))
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| env!("CARGO_PKG_VERSION").to_string());
    println!("cargo:rustc-env=ASCII_DE_VERSION={ver}");
}
