# ASCII-DE

A native compiled ASCII-styled Wayland Desktop Environment for Linux (Arch / EndeavourOS), combining a **Qt6 Wayland Compositor** (`ascii-de-compositor`), a **QML shell & window chrome** (`ui/`), and a **zero-dependency pure-std Rust backend** (`ascii-de-backend`).

Repository: <https://github.com/programmerBober/ascii-de>

---

## Architecture

- **`compositor/`** — C++20 / Qt6 `WaylandCompositor` (`XdgShell`, `XdgOutputManagerV1`, `XdgDecorationManagerV1`, `IdleInhibitManagerV1`, `WlShell`, `xwayland-satellite` / `Xwayland` bridge, D-Bus notifications, clipboard history, screenshot capture).
- **`backend/`** — Pure-`std` Rust CLI (`ascii-de-backend`) handling PipeWire/wpctl audio, `kscreen-doctor` multi-monitor layouts, desktop entries, themes/GTK/Qt/kitty sync, PAM password check, ASCII art conversion, and safe config migrations.
- **`ui/`** — QML compositor shell, monospace box-drawing window frames, Aero-snap/split-divider physics, launcher, settings, theme studio, display editor, notification drawer, clipboard modal, and lock/power overlays.
- **`bin/`** — Launcher (`ascii-de`), smart terminal wrapper (`ascii-de-terminal`), PyQt6 standalone settings host (`ascii-de-settings`), update manager (`ascii-de-update`), X11 wheel bridge (`ascii-de-x11-scroll-bridge`), Bluetooth menu (`bt-menu`), autostart helper (`ascii-de-autostart`), and Wayland `xclip`/`xsel` shims.
- **`packaging/arch/`** — Arch / EndeavourOS `PKGBUILD` installing standard `/usr` FHS paths and a Wayland session entry for SDDM/GDM/LightDM.

---

## Requirements (Arch / EndeavourOS `extra`)

All runtime dependencies live in the official Arch `extra` repository (no AUR dependencies required). Option 1 (`pacman`) and Option 2 (`makepkg -si`) pull these automatically, or you can install them explicitly:

```bash
sudo pacman -S --needed \
  qt6-base qt6-declarative qt6-imageformats qt6-wayland wayland kwin libkscreen \
  xwayland-satellite xorg-xwayland wl-clipboard pam dbus chafa \
  libpulse wireplumber kitty foot ttf-jetbrains-mono breeze-icons \
  playerctl brightnessctl bluez-utils rofi bluetui \
  python python-pyqt6 python-evdev python-xlib jq curl
```

Build dependencies: `cmake`, `ninja`, `rust`, `gcc`.

---

## Installation

### Option 1: Latest GitHub Release (`pacman`)

Downloads the latest signed-checksum `.pkg.tar.zst` from GitHub Releases, verifies `SHA256SUMS`, and installs with `pacman -U`:

```bash
curl -fsSL https://raw.githubusercontent.com/programmerBober/ascii-de/main/install.sh | bash
```

For unattended (`--noconfirm`) installation:

```bash
curl -fsSL https://raw.githubusercontent.com/programmerBober/ascii-de/main/install.sh | bash -s -- --yes
```

### Option 2: Build & Install from Local Clone (`makepkg`)

```bash
git clone https://github.com/programmerBober/ascii-de.git
cd ascii-de
./install.sh --local
```

Or directly with `makepkg`:

```bash
cd packaging/arch
makepkg -si
```

### Option 3: Developer / User-Local Mode

Keep an existing local development checkout intact without overwriting system packages:

```bash
./install.sh --dev
```

---

## Usage

```bash
# Nested Wayland/X11 window (default 1600x960)
ascii-de --nested

# Standalone multi-monitor DRM session (also available in SDDM/GDM as "ASCII-DE (Wayland)")
ascii-de --session

# Hot-restart supervised compositor without logging out
ascii-de restart

# Check or apply updates (preserves ~/.config/ascii-de/*)
ascii-de update --check
ascii-de update --apply
```

### Core Keybindings

| Shortcut | Action |
|---|---|
| `Meta + Space` / `Meta` | Start Menu / App Launcher |
| `Meta + Return` | Open Terminal (`ascii-de-terminal`) |
| `Meta + Arrow` | Aero Snap (Left / Right / Maximize / Minimize) |
| `Meta + Q` | Close focused window |
| `Meta + F` | Toggle fullscreen |
| `Meta + 1..4` | Switch virtual workspace |
| `Meta + S` | System Settings |
| `Meta + V` | Clipboard History |
| `Meta + N` | Notifications Drawer |
| `Meta + L` | Lock Screen |
| `Print` / `Meta + Shift + S` | Screenshot Overlay |
| `Meta + Alt + Delete` | Power Menu |

---

## Updating Safely

`ascii-de update` checks GitHub Releases (with a 24h cache in `~/.cache/ascii-de/update-check.json`), verifies `SHA256SUMS`, installs the new `.pkg.tar.zst` (or pulls & rebuilds in source mode), runs `ascii-de-backend migrate` (creating a timestamped backup under `~/.config/ascii-de/backups/` before adding any new default keys), and never overwrites `~/.config/ascii-de/{settings,theme,monitors,desktop-icons}.json` or interrupts an active Wayland session.

---

## License

MIT — see [LICENSE](LICENSE).
