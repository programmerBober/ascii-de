#!/usr/bin/env bash
set -euo pipefail

install -Dm755 /dev/stdin /usr/local/bin/ascii-de-session <<'EOF'
#!/usr/bin/env bash
exec "$(command -v ascii-de || echo /usr/bin/ascii-de)" --session "$@"
EOF

install -Dm644 /dev/stdin /usr/share/wayland-sessions/ascii-de.desktop <<'EOF'
[Desktop Entry]
Name=ASCII-DE (Wayland)
Comment=Native Compiled ASCII Desktop Environment (Qt6 Wayland Compositor)
Exec=/usr/local/bin/ascii-de-session
TryExec=/usr/local/bin/ascii-de-session
Type=Application
DesktopNames=ASCII-DE
EOF

echo "OK: /usr/local/bin/ascii-de-session + /usr/share/wayland-sessions/ascii-de.desktop installed."
