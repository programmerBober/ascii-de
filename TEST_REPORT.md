# ASCII-DE / Terminal-Plasma Verification & Test Report

**Date:** 2026-11-13  
**Scope:** End-to-end verification of the `ascii-de-compositor` (C++ / Qt6 Wayland + QML), `ascii-de-backend` (Rust), multi-monitor 3-output isolated KWin visual/stress suite, live `:14` Steam audit, and post-edit static/build/test sweep.

---

## 1. Implemented Desktop Environment Features

| Feature Area | Primary Files & Symbols | Verified Behaviour |
|---|---|---|
| **Native Qt6 Wayland Compositor & `wl_output` v4 Shim** | `compositor/main.cpp` (`wrappedOutputBind`, signal pipe, `--qml`, `--socket`, `--fullscreen`, `--all-monitors`, `aboutToQuit`), `ui/MainCompositor.qml` | Multi-output `WaylandCompositor` with `XdgShell`, `XdgOutputManagerV1`, `XdgDecorationManagerV1`, `WlShell`, and `wl_global_create` protocol shim upgrading `xdg_wm_base` to v2 and `wl_output` to v4 (clamping `qtVersion <= 4` and emitting `name`, `description`, `done`). Clean teardown via `aboutToQuit` window hiding + `engine.rootObjects()` deletion. |
| **XWayland / Steam Support** | `compositor/DesktopBridge.cpp` (`startXWayland`), `compositor/main.cpp` | Launches `xwayland-satellite` (with `Xwayland` fallback) against the compositor socket; receives accurate logical output metadata via `wl_output` v4 + `zxdg_output_manager_v1`. |
| **Multi-Monitor & Display Layout Editor** | `ui/AsciiDisplayEditor.qml`, `ui/MainCompositor.qml` (`preferredPrimaryOutput`, `primaryScreenIdx`, `onPrimaryScreenIdxChanged`), `backend/src/displays.rs` (`build_kscreen_args`, `KscreenModeMap`) | Visual drag-and-drop monitor arrangement, rotation (`rem_euclid(360)`), scale/mode switching, live primary handoff across connected screens, and `kscreen-doctor` emission using `output.<name>.priority.1`..`N` rather than deprecated `.primary`. |
| **Window Frame Chrome, Fullscreen Pin & SNAPTIC Data Lens** | `ui/AsciiWindowFrame.qml` (`onXChanged`, `onYChanged`, `enterFullscreen`, `exitFullscreen`, `restoreFloating`, `effMinW`/`effMaxW`, `inhibitsIdle`, `clientViewport`), `ui/MainCompositor.qml` (`triggerSpeedLines`) | Monospace box-drawing chrome, snap/maximize/minimize/restore, `[ ⛶ ]` fullscreen toggle with `#000000` backdrop, `(0, 0)` fullscreen coordinate pinning, `IdleInhibitManagerV1` surface support, `modDragOverlay` disabled while fullscreen, and SNAPTIC Data Lens + smear/impact animations. |
| **Desktop Shell, Popups & Modals** | `ui/AsciiDesktopShell.qml` (`[ SCR ]`, `[ NOTIF ]`, `[ CLIP ]`, `[ PWR ]`, `volBtn` + `audioPopup`, `clockBtn` + `clockPopup`, `onSecondaryScreenModeChanged`, `startMenuOpen`, `focusStartSearch`) | Top bar status/action pills, interactive PipeWire audio mixer popup, interactive calendar popup, start launcher with cross-monitor keyboard focus reset (`DesktopBridge::clearSeatKeyboardFocus`), and configurable secondary screen modes. |
| **Dynamic System App Theming & SNAPTIC Theme Studio** | `compositor/DesktopBridge.cpp` (`launchApp`), `ui/AsciiThemeApp.qml`, `ui/AsciiSettingsApp.qml`, `backend/src/theme.rs`, `backend/src/system.rs` | `launchApp` scopes `XDG_CONFIG_HOME=~/.config/ascii-de/xdg-config` (`XDG_CONFIG_DIRS=/etc/xdg`) and `kitty -o include` so apps follow active ASCII-DE/SNAPTIC palettes without mutating protected user configs (`~/.config/plasmarc` kept absent). |
| **Screenshot Capture Overlay** | `ui/AsciiScreenshotOverlay.qml`, `compositor/DesktopBridge.cpp` (`captureWindow`, `ScreenshotHelper`) | Interactive region/window capture (`saveToDisk`, `copyToClipboard`) triggered via `Print` / `Meta+Shift+S` or top-bar `[ SCR ]`. |
| **Notifications Daemon & Clipboard History** | `ui/AsciiNotificationsAndClip.qml`, `compositor/DesktopBridge.cpp` (`NotificationServer`, `ClipboardHistory`) | `org.freedesktop.Notifications` D-Bus daemon toast + drawer (`Meta+N` / `[ NOTIF ]`) and clipboard history modal (`Meta+V` / `[ CLIP ]`). |
| **Lock Screen & Power Menu** | `ui/AsciiPowerAndLock.qml` (`closePowerDialog`, `unlocked`), `compositor/DesktopBridge.cpp` (`verifyPasswordAsync`), `backend/src/power.rs` | PAM/system password verification (`'\0'`-guarded in `power.rs`), lock overlay (`Meta+L`), and power actions dialog (`Meta+Alt+Delete` / `[ PWR ]`). |
| **Responsive UI Clamping & Audio Validation** | `ui/AsciiDisplayEditor.qml`, `ui/AsciiThemeApp.qml`, `ui/AsciiSettingsApp.qml`, `ui/AsciiPowerAndLock.qml`, `ui/AsciiNotificationsAndClip.qml`, `backend/src/audio.rs` | Responsive `GridLayout` breakpoints (`< 720`, `< 660`), proportional sidebars, bounded `Flickable` interiors, `implicitWidth`-bounded footer buttons across portrait/scaled/landscape monitors, plus `run_wpctl()` error propagation and `format_wpctl_vol_arg()` validation. |

---

## 2. Advertised Wayland Protocols

Observed on isolated compositor via `wayland-info` (`#117` / Wave 2B verification):

- `wl_output` **v4** (via `wrappedOutputBind` shim in `compositor/main.cpp`, sending `name`, `description`, `done`)
- `xdg_wm_base` **v2** (via `wl_global_create` shim in `compositor/main.cpp`)
- `zxdg_output_manager_v1` **v3** (`XdgOutputManagerV1`)
- `zxdg_decoration_manager_v1` **v1** (`XdgDecorationManagerV1`)
- `wp_presentation` **v1** (`PresentationTime`)
- `zwp_text_input_manager_v3` **v1** (`TextInputManagerV3`)
- `zwp_text_input_manager_v2` **v1** (`TextInputManager`)
- `zwp_idle_inhibit_manager_v1` **v1** (`IdleInhibitManagerV1`)
- `wl_shell` (`WlShell`)

---

## 3. Global Hotkeys & Volume/Media Event Filter

Observed in `ui/MainCompositor.qml:1286-1448` plus `DesktopBridge` `QCoreApplication::installEventFilter` (`#122`):

| Shortcut / Key | Line (`MainCompositor.qml`) | Action |
|---|---|---|
| `Meta+Space` | `1286` | Toggle Start Menu / focus search (`F1` removed so games/apps receive `F1`) |
| `Alt+Tab` | `1292` | Cycle windows (`F2` removed so games/apps receive `F2`) |
| `Meta+Return` | `1298` | Launch terminal (`kitty`) |
| `Alt+F4`, `Meta+Shift+Q` | `1304` | Close active window |
| `Meta+M` | `1310` | Minimize active window |
| `Meta+Shift+Left` / `Meta+Shift+Right` | `1316` / `1322` | Move active window to previous/next monitor |
| `Meta+Left` / `Right` / `Up` / `Down` | `1328` / `1334` / `1340` / `1346` | Snap left/right, maximize, restore/float |
| `Meta+Shift+F` | `1352` | Toggle fullscreen on active window |
| `Meta+I` | `1358` | Display / Inspector shortcut |
| `Meta+P`, `Meta+D` | `1364` | Display / Monitor layout toggle |
| `Meta+S` | `1370` | Open Settings app |
| `Meta+T` | `1376` | Open Theme Overhaul Studio |
| `Print`, `Meta+Shift+S` | `1382` | Open Screenshot overlay |
| `Meta+V` | `1388` | Toggle Clipboard History modal |
| `Meta+N` | `1394` | Toggle Notifications drawer |
| `Meta+L` | `1400` | Lock screen |
| `Meta+Alt+Delete` | `1406` | Toggle Power dialog |
| `Volume Up` / `Volume Down` / `Volume Mute` (+ `Key_MicMute`, `Key_Media*`) | `1412` / `1418` / `1424` + `DesktopBridge` | Global `qApp` event filter intercepts volume/media keys across all monitors and focused `ShellSurfaceItem`s (`volumeActionRequested`) |
| `Meta+1` .. `Meta+4` | `1430`, `1436`, `1442`, `1448` | Switch virtual workspaces 1–4 |

---

## 4. Key Bugs Fixed & Root Causes

1. **Fullscreen Coordinate Jump / HDMI Bottom-Right Clipping (`#124`)**  
   - *Root cause:* `ShellSurfaceItem { moveItem: frameRoot }` combined with `WaylandOutput::position` displaced fullscreen frames to `2*x` on secondary outputs.  
   - *Fix:* Removed `moveItem` and added `onXChanged`/`onYChanged` fullscreen pins locking fullscreen frames to `(0, 0)` with `#000000` backdrop in `ui/AsciiWindowFrame.qml:298-307`.

2. **`QWaylandXdgOutputV1` Teardown SIGSEGV (`exit 139`, `#128`, `#131`)**  
   - *Root cause:* `DesktopBridge::registerXdgOutput` originally parented `QWaylandXdgOutputV1` to `output`, causing `~QWaylandXdgOutputV1()` to dereference an already-destroyed `QWaylandXdgOutputManagerV1` on compositor shutdown.  
   - *Fix:* In `compositor/DesktopBridge.cpp:485-490`, parented `QWaylandXdgOutputV1` to `manager` and connected `output` `&QObject::destroyed` via `QPointer<QWaylandXdgOutputV1>` cleanup; added clean window hiding in `compositor/main.cpp:215-230`. Re-verified clean quit (`COMP_EXIT=0`, `#131`, `#132`, `#134`).

3. **`AsciiPowerAndLock.qml` Imperative Binding Breaks (`#130`, `#133`, `#134`)**  
   - *Root cause:* Imperative assignments (`powerDialogOpen = false` on lines `155, 160, 196, 232` and `root.locked = false` on line `136`) overwrote QML property bindings (`powerDialogOpen: wmState.powerDialogOpen`, `locked: wmState.screenLocked`) from `MainCompositor.qml`, preventing the Power dialog from reopening after lock/unlock.  
   - *Fix:* Replaced all imperative assignments with `root.closePowerDialog()` and `root.unlocked()`. Re-verified clean render in isolated 3-monitor suite (`#134`: `05b_power_dialog.png`, `COMP_EXIT=0`).

4. **`topBar` Header Pill Overlap (`#124`, `#130`)**  
   - *Root cause:* Missing `implicitWidth`/`Layout.preferredWidth` constraints on `AsciiDesktopShell.qml` top bar items.  
   - *Fix:* Updated layout sizing in `ui/AsciiDesktopShell.qml`; confirmed crisp non-overlapping rendering in `01a_portrait_desktop.png` and `02a_landscape_start_and_clients.png` (`#130`).

5. **F1/F2 Game Input Capture & Multi-Monitor Volume Keys (`#119`, `#122`)**  
   - *Root cause:* `F1`/`F2` were bound to shell shortcuts and Qt6 `QKeySequence` required space-separated `"Volume Up"`/`"Volume Down"`/`"Volume Mute"` plus global event interception when a `ShellSurfaceItem` holds focus.  
   - *Fix:* Removed `F1`/`F2` shell shortcuts, corrected Qt6 `QKeySequence` strings in `ui/MainCompositor.qml:1412-1424`, and installed `DesktopBridge` app-wide event filter.

6. **`kscreen-doctor` `priority` Migration & Dynamic Primary Handoff (`#106`, `#109`, `#111`)**  
   - *Root cause:* `kscreen-doctor` expects `output.<name>.priority.1`..`N` instead of legacy `.primary`.  
   - *Fix:* Updated `build_kscreen_args` in `backend/src/displays.rs` and wired live primary switching in `MainCompositor.qml` / `AsciiDesktopShell.qml`.

7. **Responsive Dialog Clamping & Rust Clippy / Validation Sweep (`#126`, `#127`)**  
   - *Fix:* Bounded dialogs/sidebars/footers across `AsciiDisplayEditor.qml`, `AsciiThemeApp.qml`, `AsciiSettingsApp.qml`, `AsciiPowerAndLock.qml`, and `AsciiNotificationsAndClip.qml`; added `run_wpctl()` error checks + `format_wpctl_vol_arg()` validation in `backend/src/audio.rs`, `'\0'` password guard in `backend/src/power.rs`, and eliminated all 5 `cargo clippy` warnings.

---

## 5. Final Post-Edit Verification Results

All static, build, unit-test, and hash checks below were executed **after the final code edit** (`AsciiPowerAndLock.qml:136`):

### 5.1 QML Lint (`qmllint`)
Ran `qmllint` across all 10 files in `ui/`:
- `AsciiDesktopShell.qml`
- `AsciiDisplayEditor.qml`
- `AsciiGridCanvas.qml`
- `AsciiNotificationsAndClip.qml`
- `AsciiPowerAndLock.qml`
- `AsciiScreenshotOverlay.qml`
- `AsciiSettingsApp.qml`
- `AsciiThemeApp.qml`
- `AsciiWindowFrame.qml`
- `MainCompositor.qml`

Result: **`QMLLINT_FINAL_EXIT=0`** (0 warnings, 0 errors).

### 5.2 Rust Backend (`cargo clippy` & `cargo test`)
In `backend/`:
- `cargo clippy --all-targets -- -D warnings`: **exit `0`** (0 warnings)
- `cargo test`: **`8 passed; 0 failed`**:
  1. `audio::tests::volume_arg_formatting_and_validation`
  2. `power::tests::power_helpers_and_empty_password`
  3. `tests::displays_roundtrip_and_serialize`
  4. `tests::kscreen_args_uses_priority_without_legacy_primary`
  5. `tests::parse_roundtrip_json`
  6. `tests::settings_validation_and_clamping`
  7. `tests::theme_overhaul_snaptic_and_custom`
  8. `tests::kdeglobals_and_gtk_generation_snaptic_and_amber`

### 5.3 C++ Compositor Build & Installed Binary SHA256 Sync
- `cmake --build compositor/build -j8`: **exit `0`** (`ninja: no work to do`)
- `backend/target/release/ascii-de-backend` == `~/bin/ascii-de-backend`:  
  `a2f54711991cf89b0e381322d0c67c29798d78f1f9d1673df343be85c7322a17`
- `compositor/build/ascii-de-compositor` == `~/bin/ascii-de-compositor`:  
  `b43f1d90779c1fec68b597585a7c2b454e5be3350925f2b5c16a8d368f674378`

### 5.4 Isolated 3-Monitor Visual & Teardown Suite (`@screenshot`, `#130`, `#132`, `#134`)
Executed in an isolated virtual KWin session (`Virtual-0` `1080x1920`, `Virtual-1` `1440x810` scale `1.3333`, `Virtual-2` `1920x1080`), **`COMP_EXIT=0`**, producing all 15 verified PNG snapshots in `/tmp/ascii-snaps/`:
- `01a_portrait_desktop.png`, `01b_portrait_display_editor.png`
- `02a_landscape_start_and_clients.png`, `02b_landscape_client_fullscreen.png`, `02c_landscape_client_restored.png`
- `03a_audio_popup.png`, `03b_clock_calendar.png`, `03c_settings_app.png`, `03d_theme_app.png`
- `04a_toasts.png`, `04b_notif_drawer.png`, `04c_clipboard_modal.png`
- `05a_lock_screen.png`, `05b_power_dialog.png` (re-verified post-fix in `#134`)
- `06_all_3_monitors.png`

### 5.5 Live `:14` Steam Audit & Host Safety Check (`@session` `#129` + Final Isolation Check)
- **Live `:14` Steam Launch (`#129`):** Steam launched cleanly inside live `DISPLAY=:14` (`0x1c00039`, `628x576+0+398`, `WM_NAME="Sign in to Steam"`), pausing cleanly at the two-account picker (`<account-1>`, `<account-2>`) for interactive sign-in prior to `Balatro` (`2379780`). GPU `29°C`, VRAM `2554 MiB / 8192 MiB`, PipeWire default sink `124` (`alsa_output.pci-0000_01_00.1.playback.3.0`, Onkyo 5.1, `65%`, unmuted, `onkyo_active:true`), `org.freedesktop.Notifications` owned by live compositor `PID 3931`, `F1`–`F12` and `XF86Audio*` keycodes mapped in `:14`.
- **Host Isolation Check (post-edit):**
  - Live socket `/run/user/1000/wayland-ascii-0` untouched and active.
  - `~/.config/hypr` and `~/.config/wireplumber` unmodified.
  - `~/.config/plasmarc` absent (`plasmarc_absent=OK`).

---

## 6. Wave C/D Updates: Discord, WM, Visuals, Audio & Clipboard Verifications

### 6.1 Discord Wayland/XWayland Surface Routing & Sizing (`#147`)
- **Surface Routing Leak (`DesktopBridge.cpp`)**: Set `forceX11` for Discord with explicit `WAYLAND_DISPLAY=""` to prevent fallback to host `wayland-0`, and inserted `--ozone-platform=x11 --ignore-gpu-blocklist` before any ` -- ` delimiter so Electron reliably parses arguments.
- **Window Sizing & Splash Clamping (`AsciiWindowFrame.qml`)**: Decoupled one-shot splash dimensions; dynamic size sync with `lastSurfaceW`/`lastSurfaceH` tracking and `workArea` bounds.
- **CSD Borders & Shadows**: Decoupled CSD offsets when un-anchored; unconstrained floating configure with `(0, 0)`.
- **Click-to-Focus**: Replaced press-intercepting overlay `MouseArea` with passive `TapHandler` (`gesturePolicy: DragThreshold`), preventing dropped clicks.
- **Vencord Update Loop**: Added `"SKIP_HOST_UPDATE": true` in `~/.config/discord/settings.json` to prevent updater crashes.

### 6.2 Draggable Modals & ASCII Keybind Help Menu (`#143`)
- **Draggable Modals**: `AsciiSettingsApp.qml`, `AsciiThemeApp.qml`, and `AsciiDisplayEditor.qml` converted from locked static center modals to freely draggable windows with edge clamping, double-click titlebar re-centering, keyboard focus cycling, and dynamic z-stack raising (`raiseModal`).
- **Interactive Keybind Reference**: Created `AsciiKeybindHelp.qml` with interactive category filtering, live text search, `Esc` dismissal, draggable header, and `Meta+?` global hotkey.

### 6.3 Window Management: Fullscreen Transparency, Dragging & Secondary Monitors (`#144`)
- **Terminal Fullscreen Transparency**: Added `clientBackdrop` under `ShellSurfaceItem` in `AsciiWindowFrame.qml` (black or theme bg) when maximized/fullscreen.
- **Cross-Monitor Dragging**: Added smooth multi-monitor window dragging with customizable setting `crossMonitorDragging` in `AsciiSettingsApp.qml` and seamless ghost preview tracking.
- **Secondary Monitor Utility**: Enabled `topHeader` bar across secondary monitors with display identity badge (`[ DISPLAY: <screenName> ]`), interactive workspace indicator (`[ *1 2 3 4 ]`), and real-time secondary clock.

### 6.4 Visuals: Dynamic Christmas Tree, Live Newsboard & Audio Visualizer (`#146`)
- **Christmas Tree Buildup**: Procedural 45-frame startup buildup (`xmas_tree_intro.webp`) from snow to glowing decorated tree, transitioning seamlessly into continuous 360° rotation (`xmas_tree.webp`) with phosphor aura and topper star bloom.
- **Live Newsboard Wallpaper**: Monospace broadsheet wallpaper with live system telemetry, wire ticker dispatches, and key directory.
- **Audio Visualizer**: Procedural and PipeWire-reactive ASCII visualizer with 28-column equalizer stripes mode and 48-node dancing wave matrix dots mode.

### 6.5 Audio Notification Debounce & Clipboard Paste Reliability (`#148`)
- **Onkyo Spam Debounce**: Added 30s debounce and 2-consecutive-check offline filter in `onkyo-watchdog`, plus in-place active toast updates in `NotificationServer.cpp`.
- **Clipboard History Multi-MIME**: Removed restrictive `--type` override in `ClipboardHistory.cpp`; `wl-copy` now advertises all 5 standard MIME types (`text/plain`, `text/plain;charset=utf-8`, `TEXT`, `STRING`, `UTF8_STRING`) with direct argv payload passing and `retainedSelection: true` persistence.

### 6.6 HDMI Fullscreen & Maximized Discord Frame Fit (`#149`, `#152`, `#153`)
- **Dynamic `workArea` Binding**: `AsciiWindowFrame.qml` binds `workArea` dynamically to `outputContainer ? outputContainer.workArea : ...`, updated on `transferFrameToOutput` and `enterFullscreen`.
- **CSD Margin Decoupling**: `csdOffsetX` and `csdOffsetY` forced to 0 on maximized/fullscreen so client shadows do not offset surfaces outside the frame.
- **Exact Output Sizing**: `sendClientConfigure` calculates exact output work area dimensions on maximize/fullscreen and bypasses floating frame clamping.
- **Visual Desktop Check**: Verified live via `spectacle` screenshot (`/tmp/live_spectacle.png`) across all 4 displays (DP-3, DP-2, HDMI-A-1, DVI-I-1) confirming crisp multi-output layout, active framed windows, secondary screen badges, and stable compositor operation.

---

## 7. Multi-Tile Background Terminal & Visual Layout Architecture Verification

### 7.1 Shared Data Contract & Rust Backend (`backend/src/{theme.rs, settings.rs, bg_ascii.rs, main.rs}`)
- **Contract Compatibility**: Verified exact JSON keys between Rust models and QML (`monitorBackgrounds`, `backgroundStyle`, `bgTerminalCmd`, `bgLayoutTiles`, `monitorAsciiImages`, `bgTerminalFontSize`, `bgTerminalOpacity`, `bgTerminalMatchGrid`).
- **Legacy Fallback**: If `bgLayoutTiles` is omitted and `bgTerminalEnabled` is true, automatically seeds `tile-1` on the primary display.
- **Image-to-ASCII Pipeline (`bg_ascii.rs`)**: High-performance ANSI TrueColor (`38;2;r;g;b`) and 256-color palette to HTML `<span>` and plaintext converter with SHA cache keys, custom Chafa charsets (`ascii`, `blocks`, `braille`), and color modes (`colored`, `theme`).
- **Backend Tests & Clippy**:
  - `cargo test --manifest-path backend/Cargo.toml`: **11 passed; 0 failed; 0 warnings**.
  - `cargo clippy --manifest-path backend/Cargo.toml -- -D warnings`: **0 warnings, exit 0**.
  - Smoke test: `ascii-de-backend bg-ascii convert` generated 40x20 HTML + plain text with instant caching.
  - Installed binary SHA256: `f4aef9a124982eee28215d8ea9e9b3ff581ad825a138202cbfddecea14f9a921`.

### 7.2 Native Wayland Multi-Tile Daemon (`DesktopBridge.h/.cpp`)
- **Native Wayland Alacritty Engine (`launchBgTile`)**: Prefers `/usr/bin/alacritty` on native `WAYLAND_DISPLAY = m_waylandSocket` (unsetting `DISPLAY`) with `--class ascii-de-bg-tile-<tileId>`, `-T ascii-de-bg-tile-<tileId>`, borderless decorations, ARGB background opacity, JetBrains Mono font sizing, and theme colors. Live Wayland smoke test verified with exit code 0 and zero EGL errors.
- **Safe X11 Fallback for Kitty**: If Alacritty is missing, routes Kitty strictly to X11 (`DISPLAY = m_x11Display`, removing `WAYLAND_DISPLAY`), passing `-o include=ascii-de-kitty.conf` first so per-tile font and palette overrides cleanly take precedence.
- **Lifecycle & PID Management**: `stopBgTile(tileId)` and `stopAllBgTiles()` cleanly track PIDs in `m_bgTilePids`.
- **Compositor Build**: `cmake --build compositor/build` passed cleanly with exit 0; installed binary SHA256: `32d03275ba31f2dca3f07db92c7948680b283e92d0bd89b85fea02a3c3ba52df`.

### 7.3 Maximize `[ □ ]` Surface Downward Shift Bug Fix (`ui/AsciiWindowFrame.qml`)
- **Root Cause & Fix**:
  - `csdOffsetX` and `csdOffsetY` now consistently track `clientWinGeom.x/y` without artificial zero-clamping during maximize.
  - `surfaceItem` positions at `x: -csdOffsetX, y: -csdOffsetY`, aligning the client content buffer exactly to `(0, 0)` within `clientViewport`.
  - `clientViewport.clip` enabled on maximized and fullscreen states (`frameRoot.clientFullscreen || frameRoot.maximized || frameRoot.snapMode === "maximize"`), preventing any surface overflow below the window frame.
  - `sendClientConfigure` calculates exact `effWa.width - railW * 2` and `effWa.height - topH - botH` dimensions for maximized states.
  - `clampFrameWidth` and `clampFrameHeight` bypass floating limits during maximize/fullscreen.

### 7.4 2D Visual Background & Tile Layout Editor (`ui/AsciiBackgroundEditor.qml`)
- **Draggable Modal Architecture**: Styled after `AsciiDisplayEditor.qml` with draggable header, double-click centering, output tabs (`[DP-3]`, `[HDMI-A-1]`, `[DP-2]`), and live tile counts.
- **2D Canvas & Snapping**: Real-time interactive scaled monitor viewport with dotted matrix, top panel offset marker, 4-corner resizing, edge/sibling snapping, and pixel/cell readouts.
- **Quick Presets & Inspector**: One-click presets (`[ + Term Tile ]`, `[ + Img->ASCII ]`, `[ Split L|R ]`, `[ 2x2 Grid ]`, `[ Main+Stack ]`, `[ Full ]`), per-monitor background style selector, and per-tile command/font/opacity/charset inspector.
- **Binding Loop Fix**: Eliminated `ScrollView` `availableWidth` binding loop on line 944.
- **Offscreen Visual Verification**: Rendered and saved `/tmp/verify_bg_editor_sized.png` with 0 warnings.

### 7.5 Integration & Final Static Analysis
- **Shell & Menu Integration**:
  - Wired into `AsciiThemeApp.qml` (`[ Live Terminal ]` & `[ Image -> ASCII ]` pills + layout editor launcher button).
  - Wired into `AsciiSettingsApp.qml` Section 6 with live tile count badge and editor button.
  - Wired into `AsciiDesktopShell.qml` modal stack, Start Menu, and desktop right-click menu (`[ ⛶ Desktop Backgrounds & Tiles ]`).
  - Wired per-monitor background overrides, `monitorAsciiImage`, and `imageTiles` into `MainCompositor.qml` and `AsciiGridCanvas.qml`.

### 7.6 Multi-Monitor Subsurface Offset, Qt6 `moveItem` Hijack & Fullscreen Blackout Bug Fix (`#173`, `#174`, `#177`, `#178`)
- **Qt6 `moveItem` C++ Coordinate Hijack (Disassembly Root Cause)**:
  - In `libQt6WaylandCompositor.so`, `QWaylandXdgToplevelIntegration::handleMaximizedChanged()` and `handleFullscreenChanged()` call `QQuickItem::setPosition(output->availableGeometry().topLeft())` / `output->geometry().topLeft()` on `moveItem ? moveItem : clientSurfaceItem`.
  - When `clientSurfaceItem` lacked an explicit `moveItem`, Qt in C++ called `setPosition(QPointF(1080, 900))` (matching `output.globalX/globalY`) directly on `clientSurfaceItem`, overwriting QML `x: 0, y: 0` bindings and shifting maximized content down-right by `+1080, +900` and fullscreen content completely off-screen behind the black backdrop!
  - **Fix in `AsciiWindowFrame.qml`**: Added hidden sink `Item { id: qtMoveSink; visible: false }` inside `clientViewport` and assigned `moveItem: qtMoveSink` on `clientSurfaceItem`. Qt now safely writes its internal global offsets to the sink item while `clientSurfaceItem` remains cleanly pinned to `(0, 0)`!
- **`DesktopBridge::syncSurfaceOutput` Protocol Cleanup**:
  - Removed manual `surfaceLeave`/`surfaceEnter` loops that triggered `Ignoring unexpected wl_surface.leave` log warnings. Now cleanly delegates to `qitem->setOutput(targetOut)` and `childItem->setOutput(targetOut)` so QtWayland natively dispatches protocol events without race conditions.
  - Removed aggressive `> 100` subsurface coordinate clamping from `normalizeClientSubsurfaces` and `attachSubsurfaceFixer`, keeping methods as safe no-ops so legitimate subsurfaces (video, WebGL, custom controls) are never squashed.
- **Environment Isolation**: Protected `DesktopBridge::launchApp` Wayland environment variables with `if (!forceX11)` so X11 apps (Kitty/Discord) are never contaminated with Wayland overrides.
- **`AsciiWindowFrame.qml` & `MainCompositor.qml`**:
  - Pinned `clientSurfaceItem` position and dimensions when fullscreen/maximized (`x: 0, y: 0, width: clientViewport.width, height: clientViewport.height`).
  - Wired `syncSurfaceOutput` on frame creation, output migration, maximize, and fullscreen transitions.
- **Suite Results**:
  - `qmllint -I ui ui/*.qml`: **13/13 files passed with 0 errors and 0 warnings**.
  - `cargo test`: **11/11 tests passed**.
  - `cargo clippy`: **clean, 0 warnings**.
  - `cmake --build`: **clean, exit 0**; installed binary SHA256: `1fdcd320ec3f872fdbbc5896fd90bfa27cf594288585722ac08e590f16fff31d`.
  - Offscreen smoke boot: `QT_QPA_PLATFORM=offscreen timeout 2 ascii-de-compositor` executed cleanly with 0 QML warnings and 0 binding loops.
  - Live desktop safety check: Verified live session PID 100886 untouched and active.

---

## 8. System CPU/RAM Optimization & Antigravity Telemetry Suite (`#182`, `#183`, `#184`, `#186`, `#187`, `#188`)

### 8.1 Hardware, Kernel & System Scaling Audit (`#183`)
- **Intel Alder Lake HWP CPU**: i5-12400F running `intel_pstate` active governor with `energy_performance_preference: performance` dynamically scaling between 800 MHz and 4.4 GHz.
- **DisplayLink USB Monitor (`DVI-I-1`)**: ASUS MB169B+ EVDI software frame compression CPU load identified as directly proportional to compositor frame damage/repaint rate.
- **Memory & Swap**: 31 GiB RAM (~75% free), 8.0 GiB swapfile, zswap with `zstd` compression active and `vm.swappiness = 10`.

### 8.2 User Daemon & Background Process Optimization (`#184`)
- **local TTS daemon (XTTS-v2)**: Capped CPU thread pool from unbounded (34 threads) down to 2 via `torch.set_num_threads(2)` and `torch.set_num_interop_threads(2)`; added explicit post-synthesis `torch.cuda.empty_cache()` and `gc.collect()`; configured `OMP_NUM_THREADS=2`, `TORCH_NUM_THREADS=2`, `MKL_NUM_THREADS=2` in its systemd user service.
- **`onkyo-watchdog`**: Throttled passive polling loops from 5s to 20s/30s, relying primarily on event-driven `pactl subscribe` and `udevadm monitor`.
- **`freellmapi`**: Constrained Node.js V8 heap with `--max-old-space-size=128`.
- **`ollama`**: Configured idle model eviction with `OLLAMA_KEEP_ALIVE=5m` and `OLLAMA_NUM_PARALLEL=1`.

### 8.3 Compositor & Shell CPU/RAM Optimization (`#186`)
- **Status Polling Throttled by 87.5%**: Restricted telemetry timer in `AsciiDesktopShell.qml` to primary screen only and extended interval from 2.5s to 5.0s, reducing backend child invocations from 96/min to 12/min.
- **Process Coalescing**: Added `m_activeStatusProcess` guard in `DesktopBridge` to coalesce overlapping status checks under CPU load.
- **Hardware Telemetry Caching**: Added 5-second `GPU_CACHE` in `backend/src/system.rs` (avoiding redundant `nvidia-smi` kernel queries) and 2.5-second `AUDIO_CACHE` in `backend/src/audio.rs` with instant mutator invalidation.
- **DisplayLink Render Loop Throttling**: Guarded Christmas tree animation clock and window drag smear interpolators (`enabled: Boolean(theme.smearDrag)`).
- **Installed Binaries**:
  - `ascii-de-backend`: SHA256 `376ff47654a5fc691e7e67f950f9167777c46c999e44d2d7a2f3d22eb50313a0`.
  - `ascii-de-compositor`: SHA256 `a15f117728608c05ec5f8cde85ef0a7209520a165d81c376eecd897eb256043f`.

### 8.4 Antigravity Usage & Hive Telemetry TUI (`~/bin/agy-usage`, `#187`)
- **Zero-Bloat Architecture**: Pure Python 3 standard library (`/proc` PID, RSS, CPU% direct inspection), incremental transcript `(path, mtime, size)` caching, and incremental log file-seek reading.
- **Benchmark & Performance**: Verified startup and execution in **0.053s** (53ms), <0.1% CPU.
- **Presets & Symlink**: Symlinked to `~/.local/bin/agy-usage`; added `agy-usage` command pill to `AsciiBackgroundEditor.qml`, `AsciiSettingsApp.qml`, and `AsciiThemeApp.qml`.

### 8.5 Verification Suite
- `qmllint -I ui ui/*.qml`: **13/13 files 100% clean, 0 errors, 0 warnings**.
- `cargo test --manifest-path backend/Cargo.toml`: **11 passed; 0 failed**.
- `cargo clippy --manifest-path backend/Cargo.toml -- -D warnings`: **clean, 0 warnings**.
- `cmake --build compositor/build`: **clean, exit 0**.
- Live desktop safety check: Verified live compositor PID 100886 untouched and active.

---

## 9. Browser Sizing, CSD/SSD Negotiation, Tiled Protocol States & Scroll Bridge Guard (`#192`, `#193`, `#194`)

### 9.1 Chromium & Browser Wayland SSD Negotiation (`DesktopBridge::launchApp`)
- **Native Wayland Execution**: Verified Chromium-based browsers (`google-chrome`, `chromium`, `brave`, `microsoft-edge`) remain on native Wayland (`--ozone-platform=wayland`) for zero-scaling-loss, GPU-accelerated rendering.
- **Server-Side Decoration Flag**: Injected `--ozone-platform=wayland --enable-features=WaylandWindowDecorations` before any `--` delimiter, cleanly negotiating SSD with `zxdg_decoration_manager_v1` and dropping CSD shadow borders.
- **Chrome Flags Integration**: Symlinked `~/.config/ascii-de/xdg-config/chrome-flags.conf` from user `~/.config/chrome-flags.conf` to preserve custom user arguments.

### 9.2 X11 Wheel Double-Scroll Daemon Guard (`DesktopBridge::forwardX11Wheel`)
- **Scroll Bridge Detection**: Added a 2-second cached check for `ascii-de-x11-scroll-bridge` daemon (`pgrep -f ascii-de-x11-scroll-bridge`). When active, immediately skips duplicate XTest wheel injection, eliminating double-scrolling on X11 clients.

### 9.3 Active Compositor SSD Protocol (`MainCompositor.qml`)
- **`XdgDecorationManagerV1`**: Moved into `extensions: [...]` container with `preferredMode: XdgToplevel.ServerSideDecoration`, properly advertising SSD negotiation to all connecting Wayland clients (Firefox, Chrome, Electron).

### 9.4 Window Frame CSD Anchoring, Sizing & Tiled States (`AsciiWindowFrame.qml`)
- **Anchoring**: `clientSurfaceItem` consistently anchored to `(-csdOffsetX, -csdOffsetY)` so window content aligns exactly to viewport origin without shifting or bleeding.
- **1:1 Buffer Sizing**: `clientSurfaceItem` dimensions preserve natural buffer scale (`width: (csdOffsetX > 0 || implicitWidth > 0) ? implicitWidth : clientViewport.width`), preventing squashed/stretched client rendering.
- **Tiled Protocol States**: `sendClientConfigure` emits `XdgToplevel.TiledLeftState`, `TiledRightState`, `TiledTopState`, `TiledBottomState` alongside `MaximizedState` on maximize and snapped states (`snapMode !== ""`), signaling browsers to drop client-side rounded corners and shadow buffers.
- **Interior Geometry Sizing**: Snapped configure passes exact interior dimensions (`width - railW * 2`, `height - topH - botH`).
- **Resize Feedback Guard**: Guarded `syncInitialSizeFromSurface` with `!initialSized`, preventing floating browsers from having their window coordinates overwritten on subsequent surface commits.

### 9.5 Verification Suite
- `qmllint -I ui ui/*.qml`: **13/13 files 100% clean, 0 errors, 0 warnings**.
- `cargo test --manifest-path backend/Cargo.toml`: **11 passed; 0 failed**.
- `cmake --build compositor/build`: **clean, exit 0**; installed binary SHA256: `af20c60864a1d447a91f3438765749e57f5cbb08938993b3c57a5368412d3a85`.
- Live desktop safety check: Verified live compositor PID 100886 untouched and active.


---

## 10. Foundational Multi-Monitor Scale, Protocol & Living Architecture Verification (`#196`, `#197`, `#198`, `#199`)

### 10.1 Chromium Linux Wayland Vulkan Incompatibility Guard (`DesktopBridge.cpp`)
- **Flag Injected**: Added `--disable-features=Vulkan` alongside `--ozone-platform=wayland --enable-features=WaylandWindowDecorations` in `DesktopBridge::launchApp`.
- **Root Cause & Fix**: Ozone Wayland platform initialization logs `ERROR:ui/ozone/platform/wayland/gpu/wayland_surface_factory.cc:248] '--ozone-platform=wayland' is not compatible with Vulkan` when Vulkan is probed on Linux. Disabling the Vulkan feature resolves GPU surface allocation errors while keeping native Wayland and hardware GL acceleration active.

### 10.2 `zxdg_output_v1` Immutable Name & Description Protocol Compliance (`DesktopBridge.cpp`)
- **Protocol Adherence**: Wayland `zxdg_output_v1` specification defines output `name` and `description` as immutable properties set once upon initial object announcement.
- **Implementation**: `xdgOut->setName(name)` and `xdgOut->setDescription(...)` are now scoped strictly inside `if (!xdgOut)` initial creation. Dynamic repositioning updates only `setLogicalPosition` and `setLogicalSize`, preventing redundant protocol property sync spam.

### 10.3 Icon Theme User-Space Spec Override (`~/.local/share/icons/breeze-plus-dark/index.theme`)
- **Specification Fix**: Added missing `[status/32]` (Size=32), `[status/48]` (Size=48), and `[status/64]` (Size=64) sections in user-space `index.theme` to match the theme's `Directories=` header.
- **Verification**: Eliminates GTK/Firefox `Theme directory status/{32,48,64} of theme breeze-plus-dark has no size field` warnings in `session.log`.

### 10.4 DisplayLink Multi-Monitor Scale Normalization (`MainCompositor.qml`)
- **Scale Factor Normalization**: Replaced `scaleFactor: Math.max(1, Math.round(waylandOut.modelData ? waylandOut.modelData.devicePixelRatio : 1))` with `scaleFactor: 1` on `WaylandOutput`.
- **Root Cause & Fix**: Host `kwin_wayland` already scales the 1080p portable ASUS MB169B+ DisplayLink monitor (`DVI-I-1`) at 1.5x (1280x720 logical resolution). Rounding `1.5 -> 2` previously caused `ascii-de-compositor` to advertise `DVI-I-1` as `2560x1440` (`scale: 2`), leading to oversized Firefox surfaces overflowing frames, `xwayland-satellite` mixed output scale warnings, and cross-monitor pointer desyncs. Setting `scaleFactor: 1` directly matches KWin logical coordinates.

### 10.5 Presentation Feedback Error Elimination (`MainCompositor.qml`)
- **Protocol Cleanup**: Removed `import QtWayland.Compositor.PresentationTime` and `PresentationTime { id: presentationTime }`.
- **Root Cause & Fix**: QtWayland's `PresentationTime` extension requires QtQuick scene graph integration not present in nested custom compositors, logging `QWaylandPresentationTime only works with QtQuick compositors` and causing Chrome Wayland (`wayland_frame_manager.cc:707`) to stall frame presentation queues. Removing the extension completely stabilizes Chrome and offscreen boot logs.

### 10.6 WorkArea Binding Preservation & XWayland Lifecycle (`MainCompositor.qml`)
- **Binding Preservation**: In `transferFrameToOutput`, removed static assignment `frame.workArea = targetOut.workArea;`, allowing the dynamic `Qt.binding` established during frame instantiation to update reactively across monitors.
- **Lifecycle Ordering**: In `onCreatedChanged`, wrapped `Backend.startXWayland()` inside `Qt.callLater` to guarantee that all `WaylandOutput` instances are initialized and registered before `xwayland-satellite` connects.

### 10.7 Floating Window Tiled States, Viewport Clipping & Instant Focus (`AsciiWindowFrame.qml`)
- **Universal Tiled States**: In `sendClientConfigure`, `stateTiledLeft`, `stateTiledRight`, `stateTiledTop`, and `stateTiledBottom` are now emitted for all non-fullscreen windows (`!frameRoot.clientFullscreen`), signaling browsers to eliminate client-side rounded corners and drop shadows even when floating.
- **Unconditional Clipping**: `clientViewport.clip: true` set unconditionally to prevent any subsurface rendering artifacts or client buffer bleed outside the frame border.
- **Minimum Surface Size Expansion**: In `syncInitialSizeFromSurface`, added expansion logic: when floating and `contentW > expectedW + 4 || contentH > expectedH + 4`, `frameRoot` expands its width and height (clamped to `workArea`) to fit `contentW + railW * 2` and `contentH + topH + botH`.
- **Instant Click-to-Focus**: Added `onPressedChanged: { if (pressed) { frameRoot.requestFocus(frameRoot.winId); } }` inside `TapHandler` to immediately focus Wayland surfaces on pointer down.

### 10.8 Living Architecture Map & Obsidian Documentation
- **Architecture Blueprint**: Created `~/ObsidianVault/System/ASCII-DE Architecture Map.md` featuring a 4-layer Mermaid architecture flowchart (`flowchart TD`), component responsibility matrix, multi-monitor topology, and diagnostics guide.
- **Vault Index Integration**: Linked in `~/ObsidianVault/00 - Index.md` under System Architecture, and logged master change entry in `~/ObsidianVault/System/System Changes.md`.

### 10.9 Verification Suite & Offscreen Smoke Test
- `qmllint -I ui ui/*.qml`: **13/13 files 100% clean, 0 errors, 0 warnings**.
- `cargo test --manifest-path backend/Cargo.toml`: **11 passed; 0 failed** in 0.00s.
- `cmake --build compositor/build` & `cmake --install compositor/build`: **clean, exit 0**.
- Binary Hash: `~/bin/ascii-de-compositor` SHA256: `c9864cbd5b5e5832de7b6a04e1cef82f241cc73b4e3d5c6114fafb81b78e3d53`.
- Offscreen Smoke Boot: `QT_QPA_PLATFORM=offscreen timeout 2 ~/bin/ascii-de-compositor --socket wayland-test-verify`: clean boot, 0 QML errors, 0 PresentationTime errors.
- Live desktop safety check: Verified live compositor PID 3731 active, healthy, and untouched.


---

## 11. Portable EndeavourOS Packaging, KVM/UEFI VM Verification & Zero-Downtime Self-Update (`#202`–`#225`)

### 11.1 Arch Packaging Architecture (`packaging/arch/PKGBUILD`)
- **FHS Compliance**: Standards-compliant `/usr` prefix layout package. Binaries placed in `/usr/bin/ascii-de{,-autostart,-backend,-compositor,-settings,-update,-x11-scroll-bridge}` and `/usr/bin/bt-menu`.
- **Zero Conflict Isolation**: `xclip` and `xsel` Wayland compatibility shims are installed under isolated `/usr/lib/ascii-de/bin/{xclip,xsel}`, prepended to PATH dynamically by session scripts and leaving host package managers free of file conflicts.
- **Service & Session Integration**: Includes `/usr/lib/systemd/user/ascii-de-x11-scroll-bridge.service` and `/usr/share/wayland-sessions/ascii-de.desktop`.
- **Namcap Package Audit**: Verified 0 errors on both `PKGBUILD` and built package `ascii-de-0.1.0-1-x86_64.pkg.tar.zst`.

### 11.2 EndeavourOS Titan-Nova KVM/UEFI VM Provisioning (`tools/vm/`)
- **Automated Infrastructure**: Reusable provisioning suite (`vm-setup-base.sh`, `vm-snapshot.sh`, `vm-run.sh`, `vm-screendump.py`) using official EndeavourOS Titan-Nova ISO (`sha512sum` verified).
- **Virtual Machine Specification**: 6 vCPUs, 6144 MiB RAM, UEFI OVMF (`OVMF_CODE.4m.fd` / `OVMF_VARS.4m.fd`), VirtIO networking with user-mode SSH port forwarding (`127.0.0.1:2222`), QMP UNIX socket screendump, and VNC display.
- **Disposable CoW Architecture**: Instantaneous snapshot reset (`eos-test.qcow2` backed by immutable `eos-base.qcow2`) in <2 seconds.

### 11.3 Clean Pacman Install & Hardware Abstraction (`0.1.0`)
- **Repository Dependency Resolution**: All 38 runtime dependencies (`qt6-wayland`, `kwin`, `libkscreen`, `xwayland-satellite`, `xorg-xwayland`, `wl-clipboard`, `rofi`, `bluetui`, `chafa`, `pipewire`, `wireplumber`, `kitty`, etc.) cleanly installed from official EndeavourOS/Arch repos without missing packages or AUR requirements.
- **Hardware Abstraction**: Verified `ascii-de-backend status` safely detects virtualized hardware without crash: `has_onkyo: false`, `onkyo_detected: false`, `has_nvidia: false`, returning clean JSON telemetry.
- **Offline / Safe Update Check**: `ascii-de update --check --json` handles unpushed/offline upstream safely, emitting structured JSON without crashing.

### 11.4 Full SDDM -> Standalone Wayland Session Launch
- **Display Manager Handshake**: SDDM configured with `autologin.conf` (`Session=ascii-de.desktop`) seamlessly hands off DRM master to `kwin_wayland` (`--drm --no-lockscreen --no-global-shortcuts --exit-with-session /usr/bin/ascii-de`).
- **Complete Subsystem Orchestration**: Verified running processes inside vanilla EndeavourOS VM:
  - `kwin_wayland` (DRM hardware host)
  - `ascii-de-compositor` (Qt6 nested compositor on `wayland-ascii-0`)
  - `xwayland-satellite :14` + `Xwayland :14` (rootless X11 bridge)
  - `ascii-de-x11-scroll-bridge` (evdev wheel input filter)
- **GUI Application Rendering**: Launched `ascii-de-settings` under `wayland-ascii-0`; captured full visual screen verification via `vm-screendump.py --ocr` confirming authentic ASCII box frame title bar `[ 63: ASCII-DE Settings ——————————— [_][=][x]`, tabs, and theme typography controls.
- **Wayland Clipboard Protocol**: Verified native clipboard exchange via `wl-copy` and `wl-paste` on `wayland-ascii-0`.

### 11.5 In-Place Zero-Downtime Package Upgrade (`0.1.0 -> 0.1.1`)
- **Updater Command**: Verified `ascii-de update --apply --local-pkg ~/ascii-de-0.1.1-1-x86_64.pkg.tar.zst --yes`.
- **Config & Setting Preservation**: Pre-update custom marker in `~/.config/ascii-de/settings.json` was safely backed up to `~/.config/ascii-de/backups/<timestamp>/` and preserved by `ascii-de-backend migrate`.
- **Non-Destructive Session**: Verified running `ascii-de-compositor` PID 4094 was **NOT** killed or interrupted during package installation; visual UI and active settings modal remained rendered and responsive throughout the upgrade.
- **Version Bump**: Verified `ascii-de --version`, `ascii-de-backend version --json`, and `/usr/share/ascii-de/install-meta.json` updated to `0.1.1`.

### 11.6 Live Host Session Integrity
- **Host Safety**: Verified live compositor PID 3805 active, healthy, and untouched.


---

## 12. Regression, Fractional Scale, Dynamic Icon Detection, Smart Terminal & Scroll Bridge Verification (`#228`–`#236`)

### 12.1 `DVI-I-1` Fractional Scale Protocol Alignment (`compositor/DesktopBridge.cpp` & `ui/MainCompositor.qml`)
- **Protocol Desync Fixed**: Previously, `WaylandOutput` defaulted to `sizeFollowsWindow: true` which rounded 1.5x up to 2, advertising a `2560x1440` `wl_output.mode` while `xdg_output` advertised `1280x720`, shrinking XWayland Discord to a 2/3 corner viewport.
- **Resolution**: Set `sizeFollowsWindow: false` and `scaleFactor: 1` on `WaylandOutput`. In `DesktopBridge::registerXdgOutput`, synchronized output modes with `QWaylandOutputMode(QSize(w, h), refreshMhz)` using `addMode` and `setCurrentMode`, perfectly aligning Wayland and XWayland geometry.

### 12.2 Hardened X11 Scroll Wheel Bridge (`bin/ascii-de-x11-scroll-bridge` & `compositor/DesktopBridge.cpp`)
- **Resource Management**: Tracked devices by `(dev.path, dev.fd)` and explicitly closed removed devices on hotplug/DPMS events to eliminate leaked file descriptors.
- **Protocol & Heartbeat**: Emits timestamp updates to `${XDG_RUNTIME_DIR}/ascii-de-scroll-bridge.alive`. Compositor `forwardX11Wheel` validates daemon PID and ensures heartbeat is <10s fresh before suppressing fallback injection. Re-establishes X11 connections and retries notches on transient XErrors.
- **Host Verification**: Service restarted and verified `active (running)` with 0 leaked fds; heartbeat confirmed active on host.

### 12.3 Smart Terminal Fallback Launcher (`bin/ascii-de-terminal`)
- **Automated Fallback**: Primary launcher launches `kitty` with custom configuration when GPU hardware acceleration is available. If `kitty` fails within 3 seconds (e.g. software `llvmpipe` in virtual machines lacking OpenGL 3.1), it immediately cascades to `alacritty`, `foot`, `konsole`, or `xterm`.
- **Packaging**: Installed to `/usr/bin/ascii-de-terminal` in Arch package and symlinked to `~/bin/ascii-de-terminal` in developer mode.

### 12.4 Dynamic Installed Application Detection (`backend/src/icons.rs`)
- **Probing Engine**: `default_icons_with_env` probes `$PATH` and `.desktop` files in `/usr/share/applications` and `~/.local/share/applications`.
- **Zero Phantom Icons**: Omit uninstalled applications (`Discord`, `Steam`, `Firefox`) on clean installations, seeding only installed software (`Terminal`, `Settings`, `Audio`).
- **Unit Test Coverage**: Verified by 2 new automated tests (`dynamic_default_icons_detect_installed_apps_in_order` and `dynamic_default_icons_omit_missing_apps`, 15/15 passed).

### 12.5 Clean Vanilla EndeavourOS VM Re-Test
- **Package Installation**: Rebuilt `ascii-de-0.1.0-1-x86_64.pkg.tar.zst` installed into fresh VM with cleared user configuration.
- **Clean Desktop Dock**: Verified `~/.config/ascii-de/desktop-icons.json` generated with only `Terminal`, `Settings`, and `Audio`.
- **Zero Runtime Errors**: `session.log` verified with **0 QML errors** and **0 WebP decoder errors** (`qt6-imageformats` installed).
- **Interactive Verification**: Executed `ascii-de-terminal` inside the VM; `alacritty` launched seamlessly into an authentic ASCII box frame window (`[ 02: tester@eos-ascii-vm ~ ]`).
- **Screen Dump**: Captured OCR-verified screenshot `~/VMs/ascii-de-test/run/ascii-de-vm-clean-terminal.png`.
- **VNC Attachment**: Confirmed `ascii-de-vm-viewer.service` (`vncviewer 127.0.0.1:5900`, PID 51739) active and connected to VM PID 51668.

### 12.6 Live Host Compositor Safety
- Live host compositor PID 3805 active, untouched, and unharmed.
