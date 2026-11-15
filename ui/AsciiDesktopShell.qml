pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

Item {
    id: root

    // --- Public interface contract with MainCompositor.qml ---
    property var windowList: []
    property int currentWorkspace: 1
    property var theme: ({
        name: "amber",
        bg: "#0d0f10",
        panelBg: "#14171a",
        gridDot: "#252a30",
        snapLine: "#8b949e",
        fg: "#e6dcc8",
        accent: "#ffb000",
        secondary: "#50fa7b",
        muted: "#6e7681",
        danger: "#ff5555"
    })

    property bool startMenuOpen: false
    property bool iconManagerOpen: false
    property bool displayEditorOpen: false
    property bool backgroundEditorOpen: false
    property bool settingsOpen: false
    property bool themeAppOpen: false
    property bool keybindHelpOpen: false
    property bool altTabOpen: false
    property int altTabIndex: 0
    property bool secondaryScreenMode: false
    property string screenName: ""
    property var appSettings: ({
        theme: "amber",
        fontFamily: "JetBrains Mono",
        fontSize: 13,
        gridDensity: "normal",
        showGridDots: true,
        snapEnabled: true,
        snapThresholdPx: 24,
        showSplitDivider: true,
        startMenuDefaultMode: "search",
        clockShowSeconds: true,
        clock24h: true,
        onkyoAudioGuard: true
    })

    // Internal popup flags
    property bool contextMenuOpen: false
    property real contextMenuX: 40
    property real contextMenuY: 40
    property bool iconContextMenuOpen: false
    property real iconContextMenuX: 40
    property real iconContextMenuY: 40
    property var selectedIcon: null
    property bool audioPopupOpen: false
    property bool clockPopupOpen: false
    property int monitorCount: 0
    property var availableMonitors: []
    property int unreadNotifCount: 0
    property int clipboardCount: 0
    property bool notificationsOpen: false
    property bool clipboardOpen: false

    readonly property bool hasOpenPopup: !secondaryScreenMode && (startMenuOpen
                                      || contextMenuOpen
                                      || iconContextMenuOpen
                                      || audioPopupOpen
                                      || clockPopupOpen
                                      || iconManagerOpen
                                      || displayEditorOpen
                                      || backgroundEditorOpen
                                      || settingsOpen
                                      || themeAppOpen
                                      || keybindHelpOpen
                                      || altTabOpen)

    signal switchWorkspace(int ws)
    signal requestSpawnApp(string cmd)
    signal requestCascadeWindows()
    signal requestTileSideBySide()
    signal requestScreenshot()
    signal requestToggleNotifications()
    signal requestToggleClipboard()
    signal requestPowerDialog()
    signal requestLockScreen()
    signal themeUpdated(var newTheme)
    signal settingsUpdated(var newSettings)
    signal displaysUpdated(var monitors)

    // --- Internal reactive state ---
    readonly property string monoFamily: (theme && theme.fontFamily)
                                         ? theme.fontFamily
                                         : ((appSettings && appSettings.fontFamily) ? appSettings.fontFamily : "JetBrains Mono")
    readonly property int themeRadius: (theme && theme.cornerRadius !== undefined) ? Number(theme.cornerRadius) : 0
    readonly property int themeBorderWidth: (theme && theme.borderWidth !== undefined) ? Math.max(1, Number(theme.borderWidth)) : 1
    readonly property color closeBg: (theme && theme.closeBtnBg) ? theme.closeBtnBg : root.theme.danger
    readonly property bool isDataLens: (theme && theme.chromeStyle === "snaptic_datalens")
    readonly property bool snapticKinetic: Boolean(theme && (theme.originSmear || theme.chromeStyle === "snaptic_datalens"))
    readonly property int barFontSize: (theme && theme.fontSize !== undefined)
                                       ? Math.max(10, Math.min(13, Number(theme.fontSize) - 2))
                                       : 11
    readonly property bool compactTopBar: root.width < 1260
    readonly property bool mediumTopBar: root.width < 960
    readonly property bool narrowTopBar: root.width < 760
    readonly property bool ultraNarrowTopBar: root.width < 600

    // Shared SNAPTIC origin-smear & rim-impact animation state
    property real smearOriginX: 40
    property real smearOriginY: 40
    property real smearTargetX: 0
    property real smearTargetY: 0
    property real smearTargetW: 100
    property real smearTargetH: 100
    property real smearProgress: 0.0
    property Item kineticTarget: null
    property Item rimTarget: null
    property var desktopIcons: []
    property var installedApps: []
    property var telemetry: ({
        cpu_pct: 0,
        ram_pct: 0,
        ram_used_gb: "0.0",
        ram_total_gb: "16.0",
        gpu_pct: 0,
        audio_label: "AUDIO",
        audio_vol: 100,
        audio_muted: false,
        onkyo_active: false,
        onkyo_detected: false,
        has_onkyo: false,
        has_nvidia: false,
        sinks: []
    })
    property var updateInfo: ({
        current: "",
        latest: "",
        updateAvailable: false,
        releaseUrl: "",
        checkedAt: ""
    })
    readonly property bool updateAvailable: Boolean(updateInfo && updateInfo.updateAvailable)
    readonly property bool hasOnkyo: {
        if (Boolean(telemetry.has_onkyo || telemetry.onkyo_detected || telemetry.onkyo_active)) {
            return true;
        }
        if (Array.isArray(availableMonitors)) {
            for (var i = 0; i < availableMonitors.length; i++) {
                if (availableMonitors[i] && availableMonitors[i].onkyo_avr) {
                    return true;
                }
            }
        }
        return false;
    }

    property string editingIconId: ""
    property string formLabel: ""
    property string formCmd: ""
    property string formGlyph: ">_"
    property string appSearchQuery: ""
    property string startSearchQuery: ""
    property string startMenuMode: "search"
    property int startSelectedIndex: 0
    property var expandedFolders: ({})
    property date currentTime: new Date()

    onSecondaryScreenModeChanged: {
        if (secondaryScreenMode) {
            closeAllModals();
        } else {
            currentTime = new Date();
            callBackend(["icons", "list"], "icons");
            callBackend(["apps"], "apps");
            callBackend(["status"], "status");
            callBackend(["displays", "list"], "displays_shell");
            callBackend(["settings", "get"], "settings_shell");
            callBackend(["update-check"], "update_check");
        }
    }

    onIconManagerOpenChanged: {
        if (iconManagerOpen) {
            callBackend(["icons", "list"], "icons");
            if (installedApps.length === 0) callBackend(["apps"], "apps");
        }
    }

    property int topModalZ: 20
    function raiseModal(item) {
        if (!item) return;
        topModalZ = Math.max(topModalZ + 1, item.z + 1);
        item.z = topModalZ;
        item.forceActiveFocus();
    }

    onDisplayEditorOpenChanged: {
        if (displayEditorOpen) {
            if (secondaryScreenMode) {
                displayEditorOpen = false;
                return;
            }
            closeAllPopups();
            raiseModal(displayEditor);
        } else if (root.parent) {
            root.parent.forceActiveFocus();
        }
    }

    onBackgroundEditorOpenChanged: {
        if (backgroundEditorOpen) {
            if (secondaryScreenMode) {
                backgroundEditorOpen = false;
                return;
            }
            closeAllPopups();
            raiseModal(backgroundEditor);
        } else if (root.parent) {
            root.parent.forceActiveFocus();
        }
    }

    onSettingsOpenChanged: {
        if (settingsOpen) {
            if (secondaryScreenMode) {
                settingsOpen = false;
                return;
            }
            closeAllPopups();
            raiseModal(settingsApp);
        } else if (root.parent) {
            root.parent.forceActiveFocus();
        }
    }

    onThemeAppOpenChanged: {
        if (themeAppOpen) {
            if (secondaryScreenMode) {
                themeAppOpen = false;
                return;
            }
            closeAllPopups();
            raiseModal(themeApp);
        } else if (root.parent) {
            root.parent.forceActiveFocus();
        }
    }

    onKeybindHelpOpenChanged: {
        if (keybindHelpOpen) {
            if (secondaryScreenMode) {
                keybindHelpOpen = false;
                return;
            }
            closeAllPopups();
            raiseModal(keybindHelp);
        } else if (root.parent) {
            root.parent.forceActiveFocus();
        }
    }

    function focusSettings() {
        if (settingsApp && settingsOpen) raiseModal(settingsApp);
    }
    function focusThemeApp() {
        if (themeApp && themeAppOpen) raiseModal(themeApp);
    }
    function focusDisplayEditor() {
        if (displayEditor && displayEditorOpen) raiseModal(displayEditor);
    }
    function focusBackgroundEditor() {
        if (backgroundEditor && backgroundEditorOpen) raiseModal(backgroundEditor);
    }
    function focusKeybindHelp() {
        if (keybindHelp && keybindHelpOpen) raiseModal(keybindHelp);
    }

    function focusStartSearch() {
        if (!root.startMenuOpen) {
            return;
        }
        startSearchInput.forceActiveFocus();
        startSearchInput.selectAll();
    }

    onStartMenuOpenChanged: {
        if (startMenuOpen) {
            startMenuMode = (appSettings && appSettings.startMenuDefaultMode) ? appSettings.startMenuDefaultMode : "search";
            startSearchQuery = "";
            startSelectedIndex = 0;
            if (installedApps.length === 0) callBackend(["apps"], "apps");
            focusStartSearch();
            Qt.callLater(focusStartSearch);
        } else if (root.parent && !root.hasOpenPopup) {
            root.parent.forceActiveFocus();
        }
    }

    function folderDisplayName(rawCat) {
        var c = String(rawCat || "").trim();
        if (c === "Network") return "Internet";
        if (c === "Game") return "Games";
        if (c === "AudioVideo") return "Audio & Video";
        if (c === "Utility") return "Utilities";
        if (c.length === 0) return "Other";
        return c;
    }

    function toggleStartFolder(folderKey) {
        var next = {};
        var cur = expandedFolders || {};
        for (var k in cur) {
            if (Object.prototype.hasOwnProperty.call(cur, k)) {
                next[k] = cur[k];
            }
        }
        next[folderKey] = !Boolean(next[folderKey]);
        expandedFolders = next;
    }

    function startDisplayRows() {
        var q = (startSearchQuery || "").trim().toLowerCase();
        var builtin = [
            {
                name: "Display Layout Editor",
                exec: "__builtin:displays",
                glyph: "[MON]",
                category: "Settings",
                keywords: "display monitor screen layout resolution rotation scale primary",
                actionId: "displays"
            },
            {
                name: "Background & Tile Layout Editor",
                exec: "__builtin:backgrounds",
                glyph: "[BGD]",
                category: "Settings",
                keywords: "background wallpaper terminal ascii image tiles layout multi-monitor",
                actionId: "backgrounds"
            },
            {
                name: "System Settings",
                exec: "__builtin:settings",
                glyph: "[SET]",
                category: "Settings",
                keywords: "settings config theme font grid snap audio clock shortcuts",
                actionId: "settings"
            },
            {
                name: "Theme Overhaul Studio",
                exec: "__builtin:theme",
                glyph: "[THM]",
                category: "Settings",
                keywords: "theme snaptic amber green cyan mono overhaul colors datalens",
                actionId: "theme"
            },
            {
                name: "Screenshot Capture",
                exec: "__builtin:screenshot",
                glyph: "[SCR]",
                category: "Utility",
                keywords: "screenshot capture region screen print clip",
                actionId: "screenshot"
            }
        ];
        var apps = builtin.concat(installedApps || []);
        if (startMenuMode === "search" || q.length > 0) {
            var flat = [];
            for (var i = 0; i < apps.length; i++) {
                var a = apps[i];
                if (!a) continue;
                if (q.length > 0) {
                    var hay = ((a.name || "") + " " + (a.exec || "") + " " + (a.category || "") + " " + (a.keywords || "")).toLowerCase();
                    if (hay.indexOf(q) === -1) continue;
                }
                flat.push({
                    rowType: a.actionId ? "action" : "app",
                    actionId: a.actionId || "",
                    name: a.name || "App",
                    exec: a.exec || "",
                    glyph: a.glyph || "[APP]",
                    category: folderDisplayName(a.category),
                    indent: ""
                });
            }
            return flat;
        }

        // FOLDERS mode: group all installed apps into expandable ASCII category folders
        var groups = {};
        for (var j = 0; j < apps.length; j++) {
            var item = apps[j];
            if (!item) continue;
            var fk = folderDisplayName(item.category);
            if (!groups[fk]) groups[fk] = [];
            groups[fk].push(item);
        }
        var keys = Object.keys(groups).sort();
        var rows = [];
        for (var k = 0; k < keys.length; k++) {
            var key = keys[k];
            var list = groups[key];
            var isExp = Boolean(expandedFolders && expandedFolders[key]);
            rows.push({
                rowType: "folder",
                folderKey: key,
                label: key,
                count: list.length,
                expanded: isExp
            });
            if (isExp) {
                for (var m = 0; m < list.length; m++) {
                    var sub = list[m];
                    var isLast = (m === list.length - 1);
                    rows.push({
                        rowType: sub.actionId ? "action" : "app",
                        actionId: sub.actionId || "",
                        name: sub.name || "App",
                        exec: sub.exec || "",
                        glyph: sub.glyph || "[APP]",
                        category: key,
                        indent: isLast ? "└─ " : "├─ "
                    });
                }
            }
        }
        return rows;
    }

    function activateStartRow(rowIdx) {
        var rows = startDisplayRows();
        if (rows.length === 0) return;
        var idx = (rowIdx >= 0 && rowIdx < rows.length) ? rowIdx : 0;
        var row = rows[idx];
        if (!row) return;
        if (row.rowType === "folder") {
            toggleStartFolder(row.folderKey);
            startSearchInput.forceActiveFocus();
        } else if (row.rowType === "action" && row.actionId === "displays") {
            openDisplayEditor();
        } else if (row.rowType === "action" && row.actionId === "backgrounds") {
            openBackgroundEditor();
        } else if (row.rowType === "action" && row.actionId === "settings") {
            openSettings();
        } else if (row.rowType === "action" && row.actionId === "theme") {
            openThemeApp();
        } else if (row.rowType === "action" && row.actionId === "screenshot") {
            closeAllPopups();
            requestScreenshot();
        } else {
            closeAllPopups();
            requestSpawnApp(row.exec || "");
        }
    }

    function currentWorkspaceWindows() {
        var out = [];
        if (!windowList) return out;
        for (var i = 0; i < windowList.length; i++) {
            var w = windowList[i];
            if (!w) continue;
            if (w.workspace === undefined || w.workspace === currentWorkspace) {
                out.push(w);
            }
        }
        return out;
    }

    function getBackend() {
        // qmllint disable unqualified
        return (typeof Backend !== "undefined") ? Backend : null;
        // qmllint enable unqualified
    }

    function callBackend(args, tag) {
        var b = getBackend();
        if (b && b.runBackendAsync) {
            b.runBackendAsync(args, tag);
        }
    }

    function closeAllPopups() {
        startMenuOpen = false;
        contextMenuOpen = false;
        iconContextMenuOpen = false;
        audioPopupOpen = false;
        clockPopupOpen = false;
        altTabOpen = false;
    }

    function closeAllModals() {
        closeAllPopups();
        iconManagerOpen = false;
        displayEditorOpen = false;
        backgroundEditorOpen = false;
        settingsOpen = false;
        themeAppOpen = false;
        keybindHelpOpen = false;
    }

    function openDisplayEditor() {
        if (secondaryScreenMode) return;
        closeAllPopups();
        displayEditorOpen = !displayEditorOpen;
        if (displayEditorOpen) raiseModal(displayEditor);
    }

    function openBackgroundEditor() {
        if (secondaryScreenMode) return;
        closeAllPopups();
        backgroundEditorOpen = !backgroundEditorOpen;
        if (backgroundEditorOpen) raiseModal(backgroundEditor);
    }

    function openAudioMixer() {
        root.requestSpawnApp("sh -lc 'T=\"$(command -v ascii-de-terminal || command -v kitty || command -v foot || command -v konsole)\"; exec \"$T\" -e sh -lc '\''for c in terminal-plasma-mixer wiremix pulsemixer alsamixer; do command -v \"$c\" >/dev/null 2>&1 && exec \"$c\"; done; wpctl status; printf \"\\nPress Enter...\"; read -r _'\'''");
    }

    function openSettings() {
        if (secondaryScreenMode) return;
        closeAllPopups();
        settingsOpen = !settingsOpen;
        if (settingsOpen) raiseModal(settingsApp);
    }

    function openSettingsAtTab(tabIdx) {
        if (secondaryScreenMode) return;
        closeAllPopups();
        settingsApp.activeTab = tabIdx;
        settingsOpen = true;
        raiseModal(settingsApp);
    }

    function openThemeApp() {
        if (secondaryScreenMode) return;
        closeAllPopups();
        themeAppOpen = !themeAppOpen;
        if (themeAppOpen) raiseModal(themeApp);
    }

    function openKeybindHelp() {
        if (secondaryScreenMode) return;
        closeAllPopups();
        keybindHelpOpen = !keybindHelpOpen;
        if (keybindHelpOpen) raiseModal(keybindHelp);
    }

    function applySettings(cfg) {
        if (!cfg || typeof cfg !== "object") return;
        appSettings = cfg;
        if (!startMenuOpen && cfg.startMenuDefaultMode) {
            startMenuMode = cfg.startMenuDefaultMode;
        }
        settingsUpdated(cfg);
    }

    function openContextMenuAt(mx, my) {
        closeAllPopups();
        smearOriginX = mx;
        smearOriginY = my;
        var menuW = Math.min(308, Math.max(220, root.width - 16));
        var maxMenuH = Math.max(200, root.height - 72);
        var estMenuH = Math.min(376, maxMenuH);
        contextMenuX = Math.max(8, Math.min(mx, root.width - menuW - 8));
        contextMenuY = Math.max(30, Math.min(my, root.height - 38 - estMenuH));
        contextMenuOpen = true;
    }

    function openIconContextMenuFor(iconData, mx, my) {
        closeAllPopups();
        if (!iconData) return;
        smearOriginX = mx;
        smearOriginY = my;
        selectedIcon = iconData;
        iconContextMenuX = Math.max(8, Math.min(mx, root.width - 240));
        iconContextMenuY = Math.max(30, Math.min(my, root.height - 150));
        iconContextMenuOpen = true;
    }

    function triggerKineticPopup(targetItem, originItem, optX, optY) {
        if (!targetItem || secondaryScreenMode) return;
        var doSmear = Boolean(theme && theme.originSmear);
        var doFlash = Boolean(theme && (theme.originSmear || theme.impactFlash));
        if (!doSmear && !doFlash) {
            targetItem.scale = 1.0;
            return;
        }
        var ox = (optX !== undefined) ? optX : 40;
        var oy = (optY !== undefined) ? optY : (root.height - 20);
        if (originItem) {
            var pt = originItem.mapToItem(root, originItem.width * 0.5, originItem.height * 0.5);
            ox = pt.x;
            oy = pt.y;
        }
        smearOriginX = ox;
        smearOriginY = oy;
        kineticTarget = targetItem;
        rimTarget = targetItem;
        Qt.callLater(function() {
            if (!targetItem || !targetItem.visible) return;
            var pos = targetItem.mapToItem(root, 0, 0);
            root.smearTargetX = pos.x;
            root.smearTargetY = pos.y;
            root.smearTargetW = targetItem.width;
            root.smearTargetH = targetItem.height;
            if (doSmear) {
                sharedSmearAnim.restart();
            }
            sharedPopAnim.restart();
            sharedRimAnim.restart();
        });
    }

    function openIconManager(editIcon) {
        closeAllPopups();
        if (editIcon) {
            editingIconId = editIcon.id || "";
            formLabel = editIcon.label || "";
            formCmd = editIcon.cmd || "";
            formGlyph = editIcon.glyph || ">_";
        } else {
            editingIconId = "";
            formLabel = "";
            formCmd = "";
            formGlyph = ">_";
        }
        iconManagerOpen = true;
        callBackend(["icons", "list"], "icons");
        if (installedApps.length === 0) {
            callBackend(["apps"], "apps");
        }
    }

    function cycleTheme() {
        var order = ["amber", "green", "cyan", "mono"];
        var cur = (theme && theme.name) ? String(theme.name).toLowerCase() : "amber";
        var idx = order.indexOf(cur);
        var next = order[(idx + 1) % order.length];
        callBackend(["theme", "set", next], "theme");
    }

    function asciiBar(pct, slots) {
        var clamped = Math.max(0, Math.min(100, Number(pct) || 0));
        var filled = Math.round((clamped / 100.0) * slots);
        var s = "";
        for (var i = 0; i < slots; i++) {
            s += (i < filled) ? "|" : "·";
        }
        return s;
    }

    function padNum(n) {
        return (n < 10 ? "0" : "") + n;
    }

    function formatClock(d) {
        var use24 = !appSettings || appSettings.clock24h !== false;
        var showSec = !appSettings || appSettings.clockShowSeconds !== false;
        var h = d.getHours();
        var suffix = "";
        if (!use24) {
            suffix = (h >= 12) ? " PM" : " AM";
            h = h % 12;
            if (h === 0) h = 12;
        }
        var base = padNum(h) + ":" + padNum(d.getMinutes());
        if (showSec) base += ":" + padNum(d.getSeconds());
        return base + suffix;
    }

    function formatIsoDate(d) {
        return d.getFullYear() + "-" + padNum(d.getMonth() + 1) + "-" + padNum(d.getDate());
    }

    function pointHitsVisibleWindow(px, py) {
        if (!windowList) return false;
        for (var i = 0; i < windowList.length; i++) {
            var w = windowList[i];
            if (!w || w.minimized) continue;
            if (w.workspace !== undefined && w.workspace !== currentWorkspace) continue;
            if (px >= w.x && px <= (w.x + w.width) && py >= w.y && py <= (w.y + w.height)) {
                return true;
            }
        }
        return false;
    }

    function rectHitsVisibleWindow(rx, ry, rw, rh) {
        if (!windowList) return false;
        for (var i = 0; i < windowList.length; i++) {
            var w = windowList[i];
            if (!w || w.minimized) continue;
            if (w.workspace !== undefined && w.workspace !== currentWorkspace) continue;
            var overlapX = (rx < (w.x + w.width)) && ((rx + rw) > w.x);
            var overlapY = (ry < (w.y + w.height)) && ((ry + rh) > w.y);
            if (overlapX && overlapY) return true;
        }
        return false;
    }

    function filteredApps(query, cat) {
        if (!installedApps) return [];
        var q = (query || "").trim().toLowerCase();
        var c = cat || "All";
        var out = [];
        for (var i = 0; i < installedApps.length; i++) {
            var a = installedApps[i];
            if (!a) continue;
            var aCat = (a.category || "").toLowerCase();
            if (c !== "All") {
                if (c === "Dev" && aCat.indexOf("develop") === -1 && aCat.indexOf("ide") === -1) continue;
                else if (c === "Media" && aCat.indexOf("audio") === -1 && aCat.indexOf("video") === -1 && aCat.indexOf("music") === -1) continue;
                else if (c !== "Dev" && c !== "Media" && aCat.indexOf(c.toLowerCase()) === -1) continue;
            }
            if (q.length > 0) {
                var hay = ((a.name || "") + " " + (a.exec || "") + " " + (a.category || "")).toLowerCase();
                if (hay.indexOf(q) === -1) continue;
            }
            out.push(a);
        }
        return out;
    }

    function safeJsonParse(raw, fallback) {
        if (!raw || typeof raw !== "string") return fallback;
        var trimmed = raw.trim();
        if (trimmed.length === 0) return fallback;
        try {
            return JSON.parse(trimmed);
        } catch (e) {
            return fallback;
        }
    }

    Component.onCompleted: {
        callBackend(["theme", "get"], "theme");
        if (!secondaryScreenMode) {
            callBackend(["icons", "list"], "icons");
            callBackend(["apps"], "apps");
            callBackend(["status"], "status");
            callBackend(["displays", "list"], "displays_shell");
            callBackend(["settings", "get"], "settings_shell");
            callBackend(["update-check"], "update_check");
        }
    }

    Connections {
        target: root.getBackend()
        ignoreUnknownSignals: true

        function onBackendResult(tag, jsonOutput) {
            if (tag === "theme") {
                var th = root.safeJsonParse(jsonOutput, null);
                if (th && typeof th === "object" && th.bg) {
                    root.theme = th;
                    root.themeUpdated(th);
                }
                return;
            }
            if (tag === "status") {
                var st = root.safeJsonParse(jsonOutput, null);
                if (st && typeof st === "object") {
                    root.telemetry = st;
                }
                return;
            }
            if (root.secondaryScreenMode) return; else if (tag === "icons") {
                var ic = root.safeJsonParse(jsonOutput, null);
                if (Array.isArray(ic)) {
                    root.desktopIcons = ic;
                }
            } else if (tag === "apps") {
                var ap = root.safeJsonParse(jsonOutput, null);
                if (Array.isArray(ap)) {
                    root.installedApps = ap;
                }
            } else if (tag === "displays_shell") {
                var mons = root.safeJsonParse(jsonOutput, null);
                if (Array.isArray(mons)) {
                    root.monitorCount = mons.length;
                }
            } else if (tag === "settings_shell") {
                var cfg = root.safeJsonParse(jsonOutput, null);
                if (cfg && typeof cfg === "object" && !cfg.error) {
                    root.applySettings(cfg);
                }
            } else if (tag === "audio") {
                root.callBackend(["status"], "status");
            } else if (tag === "update_check") {
                var upd = root.safeJsonParse(jsonOutput, null);
                if (upd && typeof upd === "object" && !upd.error) {
                    root.updateInfo = upd;
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: !root.secondaryScreenMode
        repeat: true
        onTriggered: root.callBackend(["status"], "status")
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.currentTime = new Date()
    }

    // --- 0. Secondary Screen Minimal Display Badge ---
    Rectangle {
        visible: false // Integrated into responsive topHeader bar
        anchors {
            top: parent.top
            left: parent.left
            margins: 10
        }
        width: secBadgeTxt.implicitWidth + 16
        height: 22
        z: 5
        color: root.theme.panelBg
        border.color: root.theme.muted
        border.width: 1

        Text {
            id: secBadgeTxt
            anchors.centerIn: parent
            font.family: root.monoFamily
            font.pixelSize: 11
            color: root.theme.secondary
            text: "[ DISPLAY: " + (root.screenName.length > 0 ? root.screenName : "EXT") + " ]"
        }
    }

    // --- 1. Background Empty-Space Mouse Catcher (z: 0, passes through over windows) ---
    MouseArea {
        id: desktopBgCatcher
        visible: !root.secondaryScreenMode
        anchors {
            top: topHeader.bottom
            bottom: bottomTaskbar.top
            left: parent.left
            right: parent.right
        }
        z: 0
        hoverEnabled: false
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: (mouse) => {
            var rootPos = mapToItem(root, mouse.x, mouse.y);
            if (root.pointHitsVisibleWindow(rootPos.x, rootPos.y)) {
                mouse.accepted = false;
                return;
            }
            if (mouse.button === Qt.RightButton) {
                root.openContextMenuAt(rootPos.x, rootPos.y);
            } else {
                root.closeAllPopups();
            }
        }
    }

    // --- 2. Clickable & Draggable ASCII Desktop Icons (z: 2) ---
    Item {
        id: desktopIconLayer
        visible: !root.secondaryScreenMode
        anchors {
            top: topHeader.bottom
            bottom: bottomTaskbar.top
            left: parent.left
            right: parent.right
        }
        z: 2

        Repeater {
            model: root.desktopIcons

            delegate: Item {
                id: iconCard
                required property var modelData
                required property int index

                readonly property int gridCol: Number(modelData.col !== undefined ? modelData.col : 0)
                readonly property int gridRow: Number(modelData.row !== undefined ? modelData.row : index)
                readonly property real snappedX: gridCol * 116 + 18
                readonly property real snappedY: gridRow * 86 + 16
                readonly property bool isDragging: iconDragMouse.drag.active

                width: 104
                height: 76
                x: snappedX
                y: snappedY
                visible: isDragging || !root.rectHitsVisibleWindow(x, y + 26, width, height)

                Rectangle {
                    anchors.fill: parent
                    color: iconDragMouse.containsMouse ? root.theme.bg : Qt.alpha(root.theme.panelBg, 0.90)
                    radius: Number(root.theme.cornerRadius || 0) > 0 ? Math.min(8, Number(root.theme.cornerRadius)) : 0
                    border.color: (iconDragMouse.containsMouse || iconDragMouse.pressed) ? root.theme.secondary : root.theme.accent
                    border.width: (iconDragMouse.containsMouse || iconDragMouse.pressed) ? 2 : 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 3
                        width: parent.width - 8

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            font.family: root.monoFamily
                            font.pixelSize: 10
                            color: root.theme.muted
                            text: "┌────────┐"
                        }
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            font.family: root.monoFamily
                            font.pixelSize: 13
                            font.bold: true
                            color: root.theme.accent
                            text: "[ " + (iconCard.modelData.glyph || ">_") + " ]"
                        }
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            font.family: root.monoFamily
                            font.pixelSize: 11
                            color: root.theme.fg
                            text: iconCard.modelData.label || "App"
                        }
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            font.family: root.monoFamily
                            font.pixelSize: 10
                            color: root.theme.muted
                            text: "└────────┘"
                        }
                    }
                }

                MouseArea {
                    id: iconDragMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    drag.target: iconCard
                    drag.minimumX: 4
                    drag.maximumX: Math.max(4, desktopIconLayer.width - iconCard.width - 4)
                    drag.minimumY: 4
                    drag.maximumY: Math.max(4, desktopIconLayer.height - iconCard.height - 4)

                    property real startX: 0
                    property real startY: 0
                    property bool wasDragged: false
                    property double lastLaunchMs: 0

                    onPressed: (mouse) => {
                        var rootPos = mapToItem(root, mouse.x, mouse.y);
                        if (root.pointHitsVisibleWindow(rootPos.x, rootPos.y)) {
                            mouse.accepted = false;
                            return;
                        }
                        startX = iconCard.x;
                        startY = iconCard.y;
                        wasDragged = false;
                    }

                    onPositionChanged: {
                        if (drag.active && Math.abs(iconCard.x - startX) + Math.abs(iconCard.y - startY) > 6) {
                            wasDragged = true;
                        }
                    }

                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            var rPos = mapToItem(root, mouse.x, mouse.y);
                            root.openIconContextMenuFor(iconCard.modelData, rPos.x, rPos.y);
                        } else if (mouse.button === Qt.LeftButton) {
                            var dist = Math.abs(iconCard.x - startX) + Math.abs(iconCard.y - startY);
                            if (!wasDragged && dist <= 6) {
                                var now = Date.now();
                                if (now - lastLaunchMs > 350) {
                                    lastLaunchMs = now;
                                    root.closeAllPopups();
                                    root.requestSpawnApp(iconCard.modelData.cmd || "");
                                }
                            }
                        }
                    }

                    onReleased: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            var dist = Math.abs(iconCard.x - startX) + Math.abs(iconCard.y - startY);
                            if (dist > 8) {
                                var newCol = Math.max(0, Math.round((iconCard.x - 18) / 116));
                                var newRow = Math.max(0, Math.round((iconCard.y - 16) / 86));
                                iconCard.x = newCol * 116 + 18;
                                iconCard.y = newRow * 86 + 16;
                                root.callBackend(["icons", "move", String(iconCard.modelData.id), String(newCol), String(newRow)], "icons");
                            }
                        }
                    }
                }
            }
        }
    }

    // --- 3. Top ASCII System Header Bar (26px tall, z: 5) ---
    Rectangle {
        id: topHeader
        visible: true
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: 26
        z: 5
        color: root.theme.panelBg

        Rectangle {
            anchors {
                bottom: parent.bottom
                left: parent.left
                right: parent.right
            }
            height: root.themeBorderWidth
            color: root.theme.accent
        }

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 8
                rightMargin: 8
            }
            spacing: 0

            Text {
                font.family: root.monoFamily
                font.pixelSize: root.barFontSize
                font.bold: true
                color: root.theme.accent
                text: {
                    if (root.secondaryScreenMode) {
                        var dName = (root.screenName && root.screenName.length > 0) ? root.screenName : "EXT";
                        return root.isDataLens
                            ? (root.compactTopBar ? ("[ 👁 " + dName + " ]─[WS:") : ("[ 👁 " + dName + " ]─┬─[ WS:"))
                            : (root.compactTopBar ? ("┌─[" + dName + "]─[WS:") : ("┌─[ DISPLAY: " + dName + " ]─┬─[ WS:"));
                    }
                    return root.isDataLens
                          ? (root.compactTopBar ? "[ 👁 SNAPTIC ]─[WS:" : "[ 👁 ASCII-DE :: SNAPTIC LENS ]─┬─[ WS:")
                          : (root.compactTopBar ? "┌─[ ASCII ]─[WS:" : "┌─[ ASCII-DE :: WAYLAND ]─┬─[ WS:");
                }
            }

            Row {
                spacing: 2

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (event) => {
                        if (event.angleDelta.y === 0) return;
                        var delta = event.angleDelta.y > 0 ? -1 : 1;
                        var nextWs = Math.max(1, Math.min(4, root.currentWorkspace + delta));
                        if (nextWs !== root.currentWorkspace) {
                            root.switchWorkspace(nextWs);
                        }
                    }
                }

                Repeater {
                    model: [1, 2, 3, 4]
                    delegate: Rectangle {
                        id: wsDel
                        required property int modelData
                        readonly property bool isCur: modelData === root.currentWorkspace
                        width: wsTxt.implicitWidth + 6
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter
                        color: isCur ? root.theme.accent : (wsMa.containsMouse ? root.theme.gridDot : "transparent")

                        Text {
                            id: wsTxt
                            anchors.centerIn: parent
                            font.family: root.monoFamily
                            font.pixelSize: 11
                            font.bold: wsDel.isCur
                            color: wsDel.isCur ? root.theme.bg : root.theme.fg
                            text: (wsDel.isCur ? "*" : " ") + wsDel.modelData
                        }

                        MouseArea {
                            id: wsMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.switchWorkspace(wsDel.modelData)
                        }
                    }
                }
            }

            Text {
                font.family: root.monoFamily
                font.pixelSize: 11
                color: root.theme.muted
                text: " ]─┬─"
            }

            Text {
                font.family: root.monoFamily
                font.pixelSize: 11
                color: (Number(root.telemetry.cpu_pct) > 85) ? root.theme.danger : root.theme.secondary
                text: root.compactTopBar
                      ? ("[CPU " + (root.telemetry.cpu_pct || 0) + "%]")
                      : ("[ CPU " + root.asciiBar(root.telemetry.cpu_pct, 8) + " " + (root.telemetry.cpu_pct || 0) + "% ]")
            }

            Text {
                visible: !root.narrowTopBar
                font.family: root.monoFamily
                font.pixelSize: 11
                color: root.theme.muted
                text: "─"
            }

            Text {
                visible: !root.narrowTopBar
                font.family: root.monoFamily
                font.pixelSize: 11
                color: (Number(root.telemetry.ram_pct) > 85) ? root.theme.danger : root.theme.fg
                text: root.compactTopBar
                      ? ("[RAM " + (root.telemetry.ram_used_gb || "0.0") + "G]")
                      : ("[ RAM " + root.asciiBar(root.telemetry.ram_pct, 8) + " " + (root.telemetry.ram_used_gb || "0.0") + "G ]")
            }

            Text {
                visible: !root.mediumTopBar
                font.family: root.monoFamily
                font.pixelSize: 11
                color: root.theme.muted
                text: "─"
            }

            Text {
                visible: !root.mediumTopBar
                font.family: root.monoFamily
                font.pixelSize: 11
                color: root.theme.accent
                text: root.compactTopBar
                      ? ("[GPU " + (root.telemetry.gpu_pct || 0) + "%]")
                      : ("[ GPU " + (root.telemetry.gpu_pct || 0) + "% ]")
            }

            Item { Layout.fillWidth: true }

            Text {
                font.family: root.monoFamily
                font.pixelSize: 11
                color: root.theme.muted
                text: "─┬─"
            }

            Rectangle {
                id: notifHdrBtn
                visible: !root.ultraNarrowTopBar
                implicitWidth: notifHdrTxt.implicitWidth + 8
                implicitHeight: 20
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: 20
                radius: Math.min(4, root.themeRadius)
                color: (root.notificationsOpen || notifHdrMa.containsMouse) ? root.theme.accent : "transparent"

                Text {
                    id: notifHdrTxt
                    anchors.centerIn: parent
                    font.family: root.monoFamily
                    font.pixelSize: root.barFontSize
                    font.bold: true
                    color: (root.notificationsOpen || notifHdrMa.containsMouse)
                        ? root.theme.bg
                        : (root.unreadNotifCount > 0 ? root.theme.accent : root.theme.secondary)
                    text: root.compactTopBar
                          ? (root.unreadNotifCount > 0 ? ("[NTF:" + root.unreadNotifCount + "]") : "[NTF]")
                          : (root.unreadNotifCount > 0 ? ("[ NOTIF:" + root.unreadNotifCount + " ]") : "[ NOTIF ]")
                }

                MouseArea {
                    id: notifHdrMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.closeAllPopups();
                        root.requestToggleNotifications();
                    }
                }
            }

            Text {
                visible: !root.narrowTopBar
                font.family: root.monoFamily
                font.pixelSize: 11
                color: root.theme.muted
                text: "─"
            }

            Rectangle {
                id: clipHdrBtn
                visible: !root.narrowTopBar
                implicitWidth: clipHdrTxt.implicitWidth + 8
                implicitHeight: 20
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: 20
                radius: Math.min(4, root.themeRadius)
                color: (root.clipboardOpen || clipHdrMa.containsMouse) ? root.theme.accent : "transparent"

                Text {
                    id: clipHdrTxt
                    anchors.centerIn: parent
                    font.family: root.monoFamily
                    font.pixelSize: root.barFontSize
                    font.bold: true
                    color: (root.clipboardOpen || clipHdrMa.containsMouse) ? root.theme.bg : root.theme.secondary
                    text: root.compactTopBar ? "[CLP]" : "[ CLIP ]"
                }

                MouseArea {
                    id: clipHdrMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.closeAllPopups();
                        root.requestToggleClipboard();
                    }
                }
            }

            Text {
                visible: !root.narrowTopBar
                font.family: root.monoFamily
                font.pixelSize: 11
                color: root.theme.muted
                text: "─"
            }

            Rectangle {
                id: scrHdrBtn
                visible: !root.narrowTopBar
                implicitWidth: scrHdrTxt.implicitWidth + 8
                implicitHeight: 20
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: 20
                radius: Math.min(4, root.themeRadius)
                color: scrHdrMa.containsMouse ? root.theme.accent : "transparent"

                Text {
                    id: scrHdrTxt
                    anchors.centerIn: parent
                    font.family: root.monoFamily
                    font.pixelSize: root.barFontSize
                    font.bold: true
                    color: scrHdrMa.containsMouse ? root.theme.bg : root.theme.secondary
                    text: root.compactTopBar ? "[SCR]" : "[ SCR ]"
                }

                MouseArea {
                    id: scrHdrMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.closeAllPopups();
                        root.requestScreenshot();
                    }
                }
            }

            Text {
                visible: !root.secondaryScreenMode && !root.mediumTopBar
                font.family: root.monoFamily
                font.pixelSize: 11
                color: root.theme.muted
                text: "─"
            }

            Rectangle {
                id: monHdrBtn
                visible: !root.secondaryScreenMode && !root.mediumTopBar
                implicitWidth: monHdrTxt.implicitWidth + 8
                implicitHeight: 20
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: 20
                color: (root.displayEditorOpen || monHdrMa.containsMouse) ? root.theme.accent : "transparent"

                Text {
                    id: monHdrTxt
                    anchors.centerIn: parent
                    font.family: root.monoFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: (root.displayEditorOpen || monHdrMa.containsMouse) ? root.theme.bg : root.theme.accent
                    text: root.compactTopBar
                          ? ("[M:" + (displayEditor.monitors.length > 0 ? displayEditor.monitors.length : (root.monitorCount > 0 ? root.monitorCount : "-")) + "]")
                          : ("[ MON: " + (displayEditor.monitors.length > 0 ? displayEditor.monitors.length : (root.monitorCount > 0 ? root.monitorCount : "-")) + " ]")
                }

                MouseArea {
                    id: monHdrMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openDisplayEditor()
                }
            }

            Text {
                visible: !root.secondaryScreenMode && !root.mediumTopBar
                font.family: root.monoFamily
                font.pixelSize: 11
                color: root.theme.muted
                text: "─"
            }

            Rectangle {
                id: setHdrBtn
                visible: !root.secondaryScreenMode && !root.mediumTopBar
                implicitWidth: setHdrTxt.implicitWidth + 8
                implicitHeight: 20
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: 20
                color: (root.settingsOpen || setHdrMa.containsMouse) ? root.theme.accent : "transparent"

                Text {
                    id: setHdrTxt
                    anchors.centerIn: parent
                    font.family: root.monoFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: (root.settingsOpen || setHdrMa.containsMouse) ? root.theme.bg : root.theme.secondary
                    text: root.compactTopBar ? "[SET]" : "[ ⚙ SET ]"
                }

                MouseArea {
                    id: setHdrMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openSettings()
                }
            }

            Text {
                visible: !root.secondaryScreenMode && !root.compactTopBar
                font.family: root.monoFamily
                font.pixelSize: 11
                color: root.theme.muted
                text: "─"
            }

            Rectangle {
                id: addIconHdrBtn
                visible: !root.secondaryScreenMode && !root.compactTopBar
                implicitWidth: addIconHdrTxt.implicitWidth + 8
                implicitHeight: 20
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: 20
                color: addIconHdrMa.containsMouse ? root.theme.accent : "transparent"

                Text {
                    id: addIconHdrTxt
                    anchors.centerIn: parent
                    font.family: root.monoFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: addIconHdrMa.containsMouse ? root.theme.bg : root.theme.secondary
                    text: root.compactTopBar ? "[+ICN]" : "[ + ICON ]"
                }

                MouseArea {
                    id: addIconHdrMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openIconManager(null)
                }
            }

            Text {
                visible: !root.secondaryScreenMode && !root.mediumTopBar
                font.family: root.monoFamily
                font.pixelSize: 11
                color: root.theme.muted
                text: "─"
            }

            Rectangle {
                id: themeHdrBtn
                visible: !root.secondaryScreenMode && !root.mediumTopBar
                implicitWidth: themeHdrTxt.implicitWidth + 8
                implicitHeight: 20
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: 20
                radius: Math.min(4, root.themeRadius)
                color: (root.themeAppOpen || themeHdrMa.containsMouse) ? root.theme.accent : "transparent"

                Text {
                    id: themeHdrTxt
                    anchors.centerIn: parent
                    font.family: root.monoFamily
                    font.pixelSize: root.barFontSize
                    font.bold: true
                    color: (root.themeAppOpen || themeHdrMa.containsMouse) ? root.theme.bg : root.theme.accent
                    text: root.compactTopBar
                          ? "[THM]"
                          : ("[ THEME: " + ((root.theme && root.theme.name) ? String(root.theme.name).toUpperCase() : "AMBER") + " ]")
                }

                MouseArea {
                    id: themeHdrMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openThemeApp()
                }
            }

            Text {
                visible: !root.secondaryScreenMode && !root.mediumTopBar
                font.family: root.monoFamily
                font.pixelSize: 11
                color: root.theme.muted
                text: "─"
            }

            Rectangle {
                id: helpHdrBtn
                visible: !root.secondaryScreenMode && !root.mediumTopBar
                implicitWidth: helpHdrTxt.implicitWidth + 8
                implicitHeight: 20
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: 20
                radius: Math.min(4, root.themeRadius)
                color: (root.keybindHelpOpen || helpHdrMa.containsMouse) ? root.theme.accent : "transparent"

                Text {
                    id: helpHdrTxt
                    anchors.centerIn: parent
                    font.family: root.monoFamily
                    font.pixelSize: root.barFontSize
                    font.bold: true
                    color: (root.keybindHelpOpen || helpHdrMa.containsMouse) ? root.theme.bg : root.theme.secondary
                    text: root.compactTopBar ? "[?]" : "[ ? HELP ]"
                }

                MouseArea {
                    id: helpHdrMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openKeybindHelp()
                }
            }

            Text {
                visible: !root.secondaryScreenMode && root.updateAvailable
                font.family: root.monoFamily
                font.pixelSize: 11
                color: root.theme.muted
                text: "─"
            }

            Rectangle {
                id: updHdrBtn
                visible: !root.secondaryScreenMode && root.updateAvailable
                implicitWidth: updHdrTxt.implicitWidth + 8
                implicitHeight: 20
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: 20
                radius: Math.min(4, root.themeRadius)
                color: updHdrMa.containsMouse ? root.theme.accent : "transparent"

                Text {
                    id: updHdrTxt
                    anchors.centerIn: parent
                    font.family: root.monoFamily
                    font.pixelSize: root.barFontSize
                    font.bold: true
                    color: updHdrMa.containsMouse ? root.theme.bg : root.theme.accent
                    text: "[UPD]"
                }

                MouseArea {
                    id: updHdrMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openSettingsAtTab(6)
                }
            }

            Text {
                visible: root.secondaryScreenMode
                font.family: root.monoFamily
                font.pixelSize: 11
                color: root.theme.muted
                text: "─"
            }

            // Dedicated Secondary Monitor Clock
            Rectangle {
                id: secHdrClockBtn
                visible: root.secondaryScreenMode
                implicitWidth: secHdrClockTxt.implicitWidth + 8
                implicitHeight: 20
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: 20
                radius: Math.min(4, root.themeRadius)
                color: secHdrClockMa.containsMouse ? root.theme.accent : root.theme.bg
                border.color: root.theme.muted
                border.width: 1

                Text {
                    id: secHdrClockTxt
                    anchors.centerIn: parent
                    font.family: root.monoFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: secHdrClockMa.containsMouse ? root.theme.bg : root.theme.accent
                    text: "[ " + root.formatClock(root.currentTime) + " ]"
                }

                MouseArea {
                    id: secHdrClockMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.currentTime = new Date();
                    }
                }
            }

            Text {
                font.family: root.monoFamily
                font.pixelSize: 11
                color: root.theme.muted
                text: "─"
            }

            Rectangle {
                id: pwrHdrBtn
                implicitWidth: pwrHdrTxt.implicitWidth + 8
                implicitHeight: 20
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: 20
                radius: Math.min(4, root.themeRadius)
                color: pwrHdrMa.containsMouse ? root.theme.danger : "transparent"

                Text {
                    id: pwrHdrTxt
                    anchors.centerIn: parent
                    font.family: root.monoFamily
                    font.pixelSize: root.barFontSize
                    font.bold: true
                    color: pwrHdrMa.containsMouse ? root.theme.bg : root.theme.danger
                    text: root.compactTopBar ? "[PWR]" : "[ PWR ]"
                }

                MouseArea {
                    id: pwrHdrMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.closeAllPopups();
                        root.requestPowerDialog();
                    }
                }
            }

            Text {
                font.family: root.monoFamily
                font.pixelSize: root.barFontSize
                color: root.theme.accent
                text: root.isDataLens ? " ]" : "─┐"
            }
        }
    }

    // --- 4. Bottom ASCII Taskbar (28px tall, z: 5) ---
    Rectangle {
        id: bottomTaskbar
        visible: !root.secondaryScreenMode
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
        height: 28
        z: 5
        color: root.theme.panelBg

        Rectangle {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: root.themeBorderWidth
            color: root.theme.accent
        }

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 6
                rightMargin: 6
            }
            spacing: 6

            // [ >_ START ]
            Rectangle {
                id: startBtn
                Layout.preferredWidth: startBtnTxt.implicitWidth + 14
                Layout.preferredHeight: 22
                radius: Math.min(6, root.themeRadius)
                color: (root.startMenuOpen || startBtnMa.containsMouse) ? root.theme.accent : root.theme.bg
                border.color: root.theme.accent
                border.width: 1

                Text {
                    id: startBtnTxt
                    anchors.centerIn: parent
                    font.family: root.monoFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: (root.startMenuOpen || startBtnMa.containsMouse) ? root.theme.bg : root.theme.accent
                    text: "[ >_ START ]"
                }

                MouseArea {
                    id: startBtnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var was = root.startMenuOpen;
                        root.closeAllPopups();
                        root.startMenuOpen = !was;
                        if (root.startMenuOpen && root.installedApps.length === 0) {
                            root.callBackend(["apps"], "apps");
                        }
                    }
                }
            }

            Text {
                font.family: root.monoFamily
                font.pixelSize: 11
                color: root.theme.muted
                text: "│"
            }

            // Running window tabs
            QQC2.ScrollView {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                clip: true
                QQC2.ScrollBar.vertical.policy: QQC2.ScrollBar.AlwaysOff

                Row {
                    spacing: 4
                    height: 24

                    Repeater {
                        model: root.windowList
                        delegate: Rectangle {
                            id: tabDel
                            required property var modelData
                            required property int index

                            readonly property bool visibleOnWs: (modelData.workspace === undefined || modelData.workspace === root.currentWorkspace)
                            visible: visibleOnWs
                            width: visibleOnWs ? Math.min(230, tabTxt.implicitWidth + closeTabBtn.width + 18) : 0
                            height: 22
                            radius: Math.min(6, root.themeRadius)
                            scale: (root.snapticKinetic && tabMa.containsMouse) ? 1.04 : 1.0
                            color: modelData.active ? root.theme.accent : (tabMa.containsMouse ? root.theme.gridDot : root.theme.bg)
                            border.color: (root.snapticKinetic && (tabMa.containsMouse || modelData.active))
                                          ? "#45C2FF"
                                          : (modelData.active ? root.theme.accent : (modelData.minimized ? root.theme.gridDot : root.theme.muted))
                            border.width: (root.snapticKinetic && tabMa.containsMouse) ? 2 : 1

                            Behavior on scale {
                                NumberAnimation { duration: 120; easing.type: Easing.OutBack }
                            }

                            transform: Translate {
                                y: (root.snapticKinetic && tabMa.containsMouse) ? -2 : 0
                                Behavior on y {
                                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                                }
                            }

                            Row {
                                anchors {
                                    fill: parent
                                    leftMargin: 6
                                    rightMargin: 4
                                }
                                spacing: 4

                                Text {
                                    id: tabTxt
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(180, implicitWidth)
                                    elide: Text.ElideRight
                                    font.family: root.monoFamily
                                    font.pixelSize: 11
                                    font.bold: Boolean(tabDel.modelData.active)
                                    color: tabDel.modelData.active ? root.theme.bg : (tabDel.modelData.minimized ? root.theme.muted : root.theme.fg)
                                    text: (tabDel.modelData.active ? "*" : (tabDel.modelData.minimized ? "-" : " ")) + root.padNum(tabDel.index + 1) + ": " + (tabDel.modelData.title || tabDel.modelData.appId || "window")
                                }

                                Text {
                                    id: closeTabBtn
                                    anchors.verticalCenter: parent.verticalCenter
                                    font.family: root.monoFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: closeTabMa.containsMouse ? root.closeBg : (tabDel.modelData.active ? root.theme.bg : root.theme.muted)
                                    text: "[x]"

                                    MouseArea {
                                        id: closeTabMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (tabDel.modelData.closeFn) tabDel.modelData.closeFn();
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: tabMa
                                anchors {
                                    top: parent.top
                                    bottom: parent.bottom
                                    left: parent.left
                                    right: parent.right
                                    rightMargin: 24
                                }
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (tabDel.modelData.active && tabDel.modelData.toggleMinFn) {
                                        tabDel.modelData.toggleMinFn();
                                    } else if (tabDel.modelData.focusFn) {
                                        tabDel.modelData.focusFn();
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: !root.windowList || root.windowList.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: root.monoFamily
                        font.pixelSize: 11
                        color: root.theme.muted
                        text: "[ no active windows — right-click desktop or press Super ]"
                    }
                }
            }

            Text {
                font.family: root.monoFamily
                font.pixelSize: 11
                color: root.theme.muted
                text: "│"
            }

            // [ VOL: 91% ]
            Rectangle {
                id: volBtn
                Layout.preferredWidth: volBtnTxt.implicitWidth + 12
                Layout.preferredHeight: 22
                color: (root.audioPopupOpen || volBtnMa.containsMouse) ? root.theme.accent : root.theme.bg
                border.color: root.telemetry.onkyo_active ? root.theme.secondary : root.theme.muted
                border.width: 1

                Text {
                    id: volBtnTxt
                    anchors.centerIn: parent
                    font.family: root.monoFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: (root.audioPopupOpen || volBtnMa.containsMouse)
                           ? root.theme.bg
                           : (root.telemetry.audio_muted ? root.theme.danger : (root.telemetry.onkyo_active ? root.theme.secondary : root.theme.fg))
                    text: "[ VOL: " + (root.telemetry.audio_muted ? "MUTE" : ((root.telemetry.audio_vol !== undefined ? root.telemetry.audio_vol : 100) + "%")) + " ]"
                }

                MouseArea {
                    id: volBtnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton || mouse.button === Qt.MiddleButton) {
                            root.callBackend(["audio", "mute"], "audio");
                            return;
                        }
                        var was = root.audioPopupOpen;
                        root.closeAllPopups();
                        root.audioPopupOpen = !was;
                        if (root.audioPopupOpen) root.callBackend(["status"], "status");
                    }
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (event) => {
                        if (event.angleDelta.y === 0) return;
                        root.callBackend(["audio", "vol", event.angleDelta.y > 0 ? "+5%" : "-5%"], "audio");
                    }
                }
            }

            // [ HH:MM:SS ]
            Rectangle {
                id: clockBtn
                Layout.preferredWidth: clockBtnTxt.implicitWidth + 12
                Layout.preferredHeight: 22
                color: (root.clockPopupOpen || clockBtnMa.containsMouse) ? root.theme.accent : root.theme.bg
                border.color: root.theme.muted
                border.width: 1

                Text {
                    id: clockBtnTxt
                    anchors.centerIn: parent
                    font.family: root.monoFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: (root.clockPopupOpen || clockBtnMa.containsMouse) ? root.theme.bg : root.theme.accent
                    text: "[ " + root.formatClock(root.currentTime) + " ]"
                }

                MouseArea {
                    id: clockBtnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var was = root.clockPopupOpen;
                        root.closeAllPopups();
                        root.clockPopupOpen = !was;
                    }
                }
            }
        }
    }

    // --- 5. Popup Dismiss Backdrop (z: 15) ---
    MouseArea {
        anchors.fill: parent
        z: 15
        visible: root.hasOpenPopup
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: (mouse) => {
            if (mouse.button === Qt.RightButton
                    && !root.secondaryScreenMode
                    && !root.pointHitsVisibleWindow(mouse.x, mouse.y)
                    && mouse.y >= topHeader.height
                    && mouse.y <= root.height - bottomTaskbar.height) {
                var dPos = mapToItem(desktopIconLayer, mouse.x, mouse.y);
                var hitIcon = desktopIconLayer.childAt(dPos.x, dPos.y);
                if (hitIcon && hitIcon.modelData) {
                    root.openIconContextMenuFor(hitIcon.modelData, mouse.x, mouse.y);
                } else {
                    root.openContextMenuAt(mouse.x, mouse.y);
                }
                return;
            }
            root.closeAllPopups();
        }
    }

    // --- 6. Desktop Right-Click ASCII Context Menu (z: 20) ---
    Rectangle {
        id: desktopContextMenu
        visible: !root.secondaryScreenMode && root.contextMenuOpen
        x: root.contextMenuX
        y: root.contextMenuY
        width: Math.min(308, Math.max(220, root.width - 16))
        height: Math.min(ctxCol.implicitHeight + 16, Math.max(200, root.height - 72))
        z: 20
        clip: true
        color: root.theme.panelBg
        border.color: root.theme.accent
        border.width: root.themeBorderWidth
        radius: root.themeRadius
        transformOrigin: Item.TopLeft

        onVisibleChanged: {
            if (visible) {
                root.triggerKineticPopup(desktopContextMenu, null, root.smearOriginX, root.smearOriginY);
            } else {
                scale = 1.0;
            }
        }

        MouseArea { anchors.fill: parent } // absorb clicks inside popup

        Flickable {
            anchors {
                fill: parent
                margins: 8
            }
            contentWidth: width
            contentHeight: ctxCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: ctxCol
                width: parent.width
                spacing: 1

                Text {
                    font.family: root.monoFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: root.theme.accent
                    text: "┌─[ ASCII-DE DESKTOP MENU ]──────┐"
                }

                Repeater {
                    model: [
                        { label: "[ 📸 Take Screenshot (Print)     ]", act: "screenshot" },
                        { label: "[ 🔔 Notifications (Meta+N)      ]", act: "notif" },
                        { label: "[ 📋 Clipboard History (Meta+V)  ]", act: "clip" },
                        { label: "[ 🖥 Display Settings            ]", act: "displays" },
                        { label: "[ ⛶ Desktop Backgrounds & Tiles ]", act: "backgrounds" },
                        { label: "[ ⚙ System Settings              ]", act: "settings" },
                        { label: "[ 🎨 Theme Overhaul Studio...    ]", act: "theme" },
                        { label: "[ >_ Open Terminal               ]", act: "terminal" },
                        { label: "[ 🌐 Launch Web Browser          ]", act: "browser" },
                        { label: "[ 🎛 Open Audio Mixer TUI        ]", act: "mixer" },
                        { label: "[ 🔊 Switch Audio: Onkyo <-> BT  ]", act: "audio" },
                        { label: "[ ⊞ Tile Windows Side-by-Side    ]", act: "tile" },
                        { label: "[ ❐ Cascade Windows              ]", act: "cascade" },
                        { label: "[ + Add / Manage Desktop Icons   ]", act: "iconmgr" },
                        { label: "[ 🔒 Lock Screen (Meta+L)        ]", act: "lock" },
                        { label: "[ ⏻ Power Menu                   ]", act: "power" }
                    ]
                    delegate: Rectangle {
                        id: ctxDel
                        required property var modelData
                        width: ctxCol.width
                        height: 22
                        color: ctxItemMa.containsMouse ? root.theme.accent : "transparent"

                        Text {
                            anchors {
                                verticalCenter: parent.verticalCenter
                                left: parent.left
                                right: parent.right
                                leftMargin: 6
                                rightMargin: 6
                            }
                            elide: Text.ElideRight
                            font.family: root.monoFamily
                            font.pixelSize: 11
                            color: ctxItemMa.containsMouse ? root.theme.bg : root.theme.fg
                            text: (ctxDel.modelData.act === "audio" && !root.hasOnkyo)
                                  ? "[ 🔊 Switch / Cycle Audio Sink   ]"
                                  : ctxDel.modelData.label
                        }

                        MouseArea {
                            id: ctxItemMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var act = ctxDel.modelData.act;
                                root.closeAllPopups();
                                if (act === "iconmgr") root.openIconManager(null);
                                else if (act === "screenshot") root.requestScreenshot();
                                else if (act === "displays") root.openDisplayEditor();
                                else if (act === "backgrounds") root.openBackgroundEditor();
                                else if (act === "settings") root.openSettings();
                                else if (act === "terminal") root.requestSpawnApp("sh -lc 'command -v ascii-de-terminal >/dev/null 2>&1 && exec ascii-de-terminal; exec kitty'");
                                else if (act === "browser") root.requestSpawnApp("sh -lc 'for b in firefox chromium google-chrome-stable brave; do command -v \"$b\" >/dev/null 2>&1 && exec \"$b\"; done'");
                                else if (act === "mixer") root.openAudioMixer();
                                else if (act === "tile") root.requestTileSideBySide();
                                else if (act === "cascade") root.requestCascadeWindows();
                                else if (act === "audio") root.callBackend(["audio", "toggle"], "audio");
                                else if (act === "notif") root.requestToggleNotifications();
                                else if (act === "clip") root.requestToggleClipboard();
                                else if (act === "lock") root.requestLockScreen();
                                else if (act === "power") root.requestPowerDialog();
                                else if (act === "theme") root.openThemeApp();
                            }
                        }
                    }
                }
            }
        }
    }

    // --- 7. Icon Right-Click Action Menu (z: 20) ---
    Rectangle {
        id: iconActionMenu
        visible: !root.secondaryScreenMode && root.iconContextMenuOpen && root.selectedIcon !== null
        x: root.iconContextMenuX
        y: root.iconContextMenuY
        width: 232
        height: iconCtxCol.implicitHeight + 16
        z: 20
        color: root.theme.panelBg
        border.color: root.theme.accent
        border.width: root.themeBorderWidth
        radius: root.themeRadius

        MouseArea { anchors.fill: parent }

        Column {
            id: iconCtxCol
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 8
            }
            spacing: 2

            Text {
                font.family: root.monoFamily
                font.pixelSize: 11
                font.bold: true
                color: root.theme.accent
                elide: Text.ElideRight
                width: parent.width
                text: "┌─[ " + (root.selectedIcon ? (root.selectedIcon.label || "Icon") : "Icon") + " ]"
            }

            Repeater {
                model: [
                    { label: "[ ▶ Open App         ]", act: "open", danger: false },
                    { label: "[ ✎ Edit Icon...     ]", act: "edit", danger: false },
                    { label: "[ + Add New Icon...  ]", act: "add", danger: false },
                    { label: "[ ✕ Remove Icon      ]", act: "remove", danger: true }
                ]
                delegate: Rectangle {
                    id: icCtxDel
                    required property var modelData
                    width: parent.width
                    height: 24
                    color: icItemMa.containsMouse ? (modelData.danger ? root.theme.danger : root.theme.accent) : "transparent"

                    Text {
                        anchors {
                            verticalCenter: parent.verticalCenter
                            left: parent.left
                            leftMargin: 6
                        }
                        font.family: root.monoFamily
                        font.pixelSize: 11
                        color: icItemMa.containsMouse ? root.theme.bg : (icCtxDel.modelData.danger ? root.theme.danger : root.theme.fg)
                        text: icCtxDel.modelData.label
                    }

                    MouseArea {
                        id: icItemMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var targetIcon = root.selectedIcon;
                            var act = icCtxDel.modelData.act;
                            root.closeAllPopups();
                            if (!targetIcon) return;
                            if (act === "open") root.requestSpawnApp(targetIcon.cmd || "");
                            else if (act === "edit") root.openIconManager(targetIcon);
                            else if (act === "add") root.openIconManager(null);
                            else if (act === "remove") root.callBackend(["icons", "remove", String(targetIcon.id)], "icons");
                        }
                    }
                }
            }
        }
    }

    // --- 8. Quick ASCII Desktop Icon Manager Modal (z: 20) ---
    Rectangle {
        id: iconManagerModal
        visible: !root.secondaryScreenMode && root.iconManagerOpen
        width: Math.min(780, root.width - 40)
        height: Math.min(520, root.height - 80)
        anchors.centerIn: parent
        z: 20
        color: root.theme.panelBg
        border.color: root.theme.accent
        border.width: root.themeBorderWidth
        radius: root.themeRadius

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors {
                fill: parent
                margins: 10
            }
            spacing: 8

            // Title bar
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    font.family: root.monoFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: root.theme.accent
                    elide: Text.ElideRight
                    text: "┌─[ ASCII DESKTOP ICON MANAGER — ADD / REMOVE ICONS ]─────────────────────────"
                }
                Rectangle {
                    width: 44
                    height: 22
                    radius: Math.min(6, root.themeRadius)
                    color: closeMgrMa.containsMouse ? root.theme.fg : root.closeBg
                    border.color: root.closeBg
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        font.family: root.monoFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: closeMgrMa.containsMouse ? root.theme.bg : "#ffffff"
                        text: "[ ✕ ]"
                    }
                    MouseArea {
                        id: closeMgrMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.iconManagerOpen = false
                    }
                }
            }

            // Two-column body
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                // Left Column: Current Desktop Icons
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    color: root.theme.bg
                    border.color: root.theme.muted
                    border.width: 1

                    ColumnLayout {
                        anchors { fill: parent; margins: 8 }
                        spacing: 6

                        Text {
                            font.family: root.monoFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: root.theme.secondary
                            text: "CURRENT DESKTOP ICONS (" + root.desktopIcons.length + ")"
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 4
                            model: root.desktopIcons

                            delegate: Rectangle {
                                id: curIconDel
                                required property var modelData
                                width: ListView.view.width
                                height: 32
                                color: root.theme.panelBg
                                border.color: (root.editingIconId === modelData.id) ? root.theme.accent : root.theme.gridDot
                                border.width: 1

                                RowLayout {
                                    anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                                    spacing: 6

                                    Text {
                                        font.family: root.monoFamily
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: root.theme.accent
                                        text: "[" + (curIconDel.modelData.glyph || ">_") + "]"
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        font.family: root.monoFamily
                                        font.pixelSize: 11
                                        color: root.theme.fg
                                        text: (curIconDel.modelData.label || "") + " (" + curIconDel.modelData.col + "," + curIconDel.modelData.row + ")"
                                    }
                                    Rectangle {
                                        width: 58
                                        height: 22
                                        color: editRowMa.containsMouse ? root.theme.accent : root.theme.bg
                                        border.color: root.theme.accent
                                        border.width: 1
                                        Text {
                                            anchors.centerIn: parent
                                            font.family: root.monoFamily
                                            font.pixelSize: 10
                                            color: editRowMa.containsMouse ? root.theme.bg : root.theme.accent
                                            text: "[✎ Edit]"
                                        }
                                        MouseArea {
                                            id: editRowMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.editingIconId = String(curIconDel.modelData.id);
                                                root.formLabel = String(curIconDel.modelData.label || "");
                                                root.formCmd = String(curIconDel.modelData.cmd || "");
                                                root.formGlyph = String(curIconDel.modelData.glyph || ">_");
                                            }
                                        }
                                    }
                                    Rectangle {
                                        width: 68
                                        height: 22
                                        color: rmRowMa.containsMouse ? root.theme.danger : root.theme.bg
                                        border.color: root.theme.danger
                                        border.width: 1
                                        Text {
                                            anchors.centerIn: parent
                                            font.family: root.monoFamily
                                            font.pixelSize: 10
                                            color: rmRowMa.containsMouse ? root.theme.bg : root.theme.danger
                                            text: "[✕ Remove]"
                                        }
                                        MouseArea {
                                            id: rmRowMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.callBackend(["icons", "remove", String(curIconDel.modelData.id)], "icons")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Right Column: Quick Add from Installed Apps + Custom Form
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1.15
                    color: root.theme.bg
                    border.color: root.theme.muted
                    border.width: 1

                    ColumnLayout {
                        anchors { fill: parent; margins: 8 }
                        spacing: 6

                        Text {
                            font.family: root.monoFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: root.theme.accent
                            text: "QUICK ADD FROM INSTALLED APPS"
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 26
                            color: root.theme.panelBg
                            border.color: root.theme.muted
                            border.width: 1
                            TextInput {
                                anchors { fill: parent; margins: 5 }
                                font.family: root.monoFamily
                                font.pixelSize: 11
                                color: root.theme.fg
                                text: root.appSearchQuery
                                onTextChanged: root.appSearchQuery = text
                                clip: true
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: parent.text.length === 0
                                    font.family: root.monoFamily
                                    font.pixelSize: 11
                                    color: root.theme.muted
                                    text: "Search installed apps..."
                                }
                            }
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 3
                            model: root.filteredApps(root.appSearchQuery, "All")

                            delegate: Rectangle {
                                id: addAppDel
                                required property var modelData
                                width: ListView.view.width
                                height: 28
                                color: root.theme.panelBg
                                border.color: root.theme.gridDot
                                border.width: 1

                                RowLayout {
                                    anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                                    spacing: 6

                                    Text {
                                        font.family: root.monoFamily
                                        font.pixelSize: 10
                                        color: root.theme.accent
                                        text: addAppDel.modelData.glyph || "[APP]"
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        font.family: root.monoFamily
                                        font.pixelSize: 11
                                        color: root.theme.fg
                                        text: addAppDel.modelData.name || "App"
                                    }
                                    Rectangle {
                                        width: 118
                                        height: 20
                                        color: addAppMa.containsMouse ? root.theme.secondary : root.theme.bg
                                        border.color: root.theme.secondary
                                        border.width: 1
                                        Text {
                                            anchors.centerIn: parent
                                            font.family: root.monoFamily
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: addAppMa.containsMouse ? root.theme.bg : root.theme.secondary
                                            text: "[+ Add to Desktop]"
                                        }
                                        MouseArea {
                                            id: addAppMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var g = String(addAppDel.modelData.glyph || ">_").replace("[", "").replace("]", "").slice(0, 2);
                                                if (g.length === 0) g = ">_";
                                                root.callBackend(["icons", "add", String(addAppDel.modelData.name || "App"), String(addAppDel.modelData.exec || ""), g], "icons");
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Custom / Edit Icon Form
                        Rectangle {
                            Layout.fillWidth: true
                            height: 122
                            color: root.theme.panelBg
                            border.color: root.theme.accent
                            border.width: 1

                            ColumnLayout {
                                anchors { fill: parent; margins: 8 }
                                spacing: 5

                                Text {
                                    font.family: root.monoFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: root.theme.accent
                                    text: (root.editingIconId !== "") ? ("EDIT ICON: " + root.editingIconId) : "CUSTOM ICON FORM"
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 24
                                        color: root.theme.bg
                                        border.color: root.theme.muted
                                        border.width: 1
                                        TextInput {
                                            anchors { fill: parent; margins: 4 }
                                            font.family: root.monoFamily
                                            font.pixelSize: 11
                                            color: root.theme.fg
                                            text: root.formLabel
                                            onTextChanged: root.formLabel = text
                                            clip: true
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: parent.text.length === 0
                                                font.family: root.monoFamily
                                                font.pixelSize: 10
                                                color: root.theme.muted
                                                text: "Label (e.g. Neovim)"
                                            }
                                        }
                                    }
                                    Rectangle {
                                        width: 68
                                        height: 24
                                        color: root.theme.bg
                                        border.color: root.theme.muted
                                        border.width: 1
                                        TextInput {
                                            anchors { fill: parent; margins: 4 }
                                            font.family: root.monoFamily
                                            font.pixelSize: 11
                                            color: root.theme.accent
                                            text: root.formGlyph
                                            onTextChanged: root.formGlyph = text
                                            maximumLength: 2
                                            clip: true
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 24
                                    color: root.theme.bg
                                    border.color: root.theme.muted
                                    border.width: 1
                                    TextInput {
                                        anchors { fill: parent; margins: 4 }
                                        font.family: root.monoFamily
                                        font.pixelSize: 11
                                        color: root.theme.fg
                                        text: root.formCmd
                                        onTextChanged: root.formCmd = text
                                        clip: true
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: parent.text.length === 0
                                            font.family: root.monoFamily
                                            font.pixelSize: 10
                                            color: root.theme.muted
                                            text: "Command (e.g. kitty -e nvim)"
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 24
                                        color: submitCustomMa.containsMouse ? root.theme.secondary : root.theme.bg
                                        border.color: root.theme.secondary
                                        border.width: 1
                                        Text {
                                            anchors.centerIn: parent
                                            font.family: root.monoFamily
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: submitCustomMa.containsMouse ? root.theme.bg : root.theme.secondary
                                            text: (root.editingIconId !== "") ? "[ ✓ Save Icon Changes ]" : "[ + Create Custom Icon ]"
                                        }
                                        MouseArea {
                                            id: submitCustomMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var lbl = root.formLabel.trim();
                                                var cmd = root.formCmd.trim();
                                                var gl = root.formGlyph.trim() || ">_";
                                                if (lbl.length === 0 || cmd.length === 0) return;
                                                if (root.editingIconId !== "") {
                                                    root.callBackend(["icons", "edit", root.editingIconId, lbl, cmd, gl], "icons");
                                                    root.editingIconId = "";
                                                } else {
                                                    root.callBackend(["icons", "add", lbl, cmd, gl], "icons");
                                                }
                                                root.formLabel = "";
                                                root.formCmd = "";
                                                root.formGlyph = ">_";
                                            }
                                        }
                                    }
                                    Rectangle {
                                        visible: root.editingIconId !== ""
                                        width: 72
                                        height: 24
                                        color: cancelEditMa.containsMouse ? root.theme.muted : root.theme.bg
                                        border.color: root.theme.muted
                                        border.width: 1
                                        Text {
                                            anchors.centerIn: parent
                                            font.family: root.monoFamily
                                            font.pixelSize: 10
                                            color: cancelEditMa.containsMouse ? root.theme.bg : root.theme.fg
                                            text: "[Cancel]"
                                        }
                                        MouseArea {
                                            id: cancelEditMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.editingIconId = "";
                                                root.formLabel = "";
                                                root.formCmd = "";
                                                root.formGlyph = ">_";
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // --- 9. Start Menu Popup (z: 20) ---
    Rectangle {
        id: startMenuPopup
        visible: !root.secondaryScreenMode && root.startMenuOpen
        anchors {
            left: parent.left
            bottom: bottomTaskbar.top
            leftMargin: 6
            bottomMargin: 4
        }
        width: 490
        height: Math.min(500, root.height - 70)
        z: 20
        color: root.theme.panelBg
        border.color: root.theme.accent
        border.width: root.themeBorderWidth
        radius: root.themeRadius
        transformOrigin: Item.BottomLeft

        onVisibleChanged: {
            if (visible) {
                root.triggerKineticPopup(startMenuPopup, startBtn);
            } else {
                scale = 1.0;
            }
        }

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors { fill: parent; margins: 10 }
            spacing: 6

            // Header with [ MODE: SEARCH | FOLDERS ] toggle
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.family: root.monoFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: root.theme.accent
                    text: "┌─[ START :: LAUNCHER ]─"
                }

                Text {
                    font.family: root.monoFamily
                    font.pixelSize: 10
                    color: root.theme.muted
                    text: "[ MODE:"
                }

                Rectangle {
                    width: searchModeTxt.implicitWidth + 8
                    height: 20
                    color: (root.startMenuMode === "search") ? root.theme.accent : (searchModeMa.containsMouse ? root.theme.gridDot : root.theme.bg)
                    border.color: (root.startMenuMode === "search") ? root.theme.accent : root.theme.muted
                    border.width: 1
                    Text {
                        id: searchModeTxt
                        anchors.centerIn: parent
                        font.family: root.monoFamily
                        font.pixelSize: 10
                        font.bold: root.startMenuMode === "search"
                        color: (root.startMenuMode === "search") ? root.theme.bg : root.theme.fg
                        text: "SEARCH"
                    }
                    MouseArea {
                        id: searchModeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.startMenuMode = "search";
                            root.startSelectedIndex = 0;
                            startSearchInput.forceActiveFocus();
                        }
                    }
                }

                Text {
                    font.family: root.monoFamily
                    font.pixelSize: 10
                    color: root.theme.muted
                    text: "|"
                }

                Rectangle {
                    width: folderModeTxt.implicitWidth + 8
                    height: 20
                    color: (root.startMenuMode === "folders") ? root.theme.accent : (folderModeMa.containsMouse ? root.theme.gridDot : root.theme.bg)
                    border.color: (root.startMenuMode === "folders") ? root.theme.accent : root.theme.muted
                    border.width: 1
                    Text {
                        id: folderModeTxt
                        anchors.centerIn: parent
                        font.family: root.monoFamily
                        font.pixelSize: 10
                        font.bold: root.startMenuMode === "folders"
                        color: (root.startMenuMode === "folders") ? root.theme.bg : root.theme.fg
                        text: "FOLDERS"
                    }
                    MouseArea {
                        id: folderModeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.startMenuMode = "folders";
                            root.startSelectedIndex = 0;
                            startSearchInput.forceActiveFocus();
                        }
                    }
                }

                Text {
                    font.family: root.monoFamily
                    font.pixelSize: 10
                    color: root.theme.accent
                    text: "]─┐"
                }
            }

            // Auto-focused search input + keyboard navigation
            Rectangle {
                Layout.fillWidth: true
                height: 26
                color: root.theme.bg
                border.color: root.theme.accent
                border.width: 1

                TextInput {
                    id: startSearchInput
                    anchors { fill: parent; margins: 5 }
                    font.family: root.monoFamily
                    font.pixelSize: 11
                    color: root.theme.fg
                    text: root.startSearchQuery
                    clip: true
                    onTextChanged: {
                        root.startSearchQuery = text;
                        root.startSelectedIndex = 0;
                    }
                    MouseArea {
                        anchors.fill: parent
                        propagateComposedEvents: true
                        onPressed: (mouse) => {
                            startSearchInput.forceActiveFocus();
                            mouse.accepted = false;
                        }
                    }
                    Keys.onPressed: (event) => {
                        var rows = root.startDisplayRows();
                        if (event.key === Qt.Key_Down) {
                            if (rows.length > 0) {
                                root.startSelectedIndex = Math.min(rows.length - 1, root.startSelectedIndex + 1);
                                startMenuList.positionViewAtIndex(root.startSelectedIndex, ListView.Contain);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            if (rows.length > 0) {
                                root.startSelectedIndex = Math.max(0, root.startSelectedIndex - 1);
                                startMenuList.positionViewAtIndex(root.startSelectedIndex, ListView.Contain);
                            }
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Tab) {
                            root.startMenuMode = (root.startMenuMode === "search") ? "folders" : "search";
                            root.startSelectedIndex = 0;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.activateStartRow(root.startSelectedIndex);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            root.closeAllPopups();
                            event.accepted = true;
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: startSearchInput.text.length === 0
                        font.family: root.monoFamily
                        font.pixelSize: 11
                        color: root.theme.muted
                        text: (root.startMenuMode === "folders")
                              ? "$ filter apps or browse folders... (Tab: mode, ↑↓/Enter)"
                              : "$ type to search apps... (Tab: folders, ↑↓/Enter)"
                    }
                }
            }

            ListView {
                id: startMenuList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: root.startDisplayRows()

                delegate: Rectangle {
                    id: startRowDel
                    required property var modelData
                    required property int index

                    readonly property bool isFolder: modelData.rowType === "folder"
                    readonly property bool isSelected: index === root.startSelectedIndex
                    readonly property bool isActiveRow: appItemMa.containsMouse || isSelected

                    width: ListView.view.width
                    height: 26
                    radius: Math.min(6, root.themeRadius)
                    scale: (root.snapticKinetic && isActiveRow) ? 1.03 : 1.0
                    color: isActiveRow
                           ? (isFolder ? root.theme.secondary : root.theme.accent)
                           : (isFolder ? root.theme.panelBg : root.theme.bg)
                    border.color: (root.snapticKinetic && isActiveRow)
                                  ? "#45C2FF"
                                  : (isFolder
                                     ? (isActiveRow ? root.theme.secondary : root.theme.muted)
                                     : (isActiveRow ? root.theme.accent : root.theme.gridDot))
                    border.width: (root.snapticKinetic && isActiveRow) ? 2 : 1

                    Behavior on scale {
                        NumberAnimation { duration: 120; easing.type: Easing.OutBack }
                    }

                    transform: Translate {
                        x: (root.snapticKinetic && startRowDel.isActiveRow) ? 4 : 0
                        Behavior on x {
                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        spacing: 6

                        // Folder row content
                        Text {
                            visible: startRowDel.isFolder
                            font.family: root.monoFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: startRowDel.isActiveRow ? root.theme.bg : root.theme.accent
                            text: startRowDel.modelData.expanded ? "[─]" : "[+]"
                        }
                        Text {
                            visible: startRowDel.isFolder
                            font.family: root.monoFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: startRowDel.isActiveRow ? root.theme.bg : root.theme.secondary
                            text: "[DIR]"
                        }
                        Text {
                            visible: startRowDel.isFolder
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            font.family: root.monoFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: startRowDel.isActiveRow ? root.theme.bg : root.theme.fg
                            text: (startRowDel.modelData.label || "Folder") + " (" + (startRowDel.modelData.count || 0) + ")"
                        }

                        // App row content
                        Text {
                            visible: !startRowDel.isFolder && String(startRowDel.modelData.indent || "").length > 0
                            font.family: root.monoFamily
                            font.pixelSize: 11
                            color: startRowDel.isActiveRow ? root.theme.bg : root.theme.muted
                            text: startRowDel.modelData.indent || ""
                        }
                        Text {
                            visible: !startRowDel.isFolder
                            font.family: root.monoFamily
                            font.pixelSize: 10
                            color: startRowDel.isActiveRow ? root.theme.bg : root.theme.accent
                            text: startRowDel.modelData.glyph || "[APP]"
                        }
                        Text {
                            visible: !startRowDel.isFolder
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            font.family: root.monoFamily
                            font.pixelSize: 11
                            font.bold: startRowDel.isSelected
                            color: startRowDel.isActiveRow ? root.theme.bg : root.theme.fg
                            text: startRowDel.modelData.name || "App"
                        }
                        Text {
                            visible: !startRowDel.isFolder
                            font.family: root.monoFamily
                            font.pixelSize: 10
                            color: startRowDel.isActiveRow ? root.theme.bg : root.theme.muted
                            text: startRowDel.modelData.category || ""
                        }
                    }

                    MouseArea {
                        id: appItemMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.startSelectedIndex = startRowDel.index
                        onClicked: root.activateStartRow(startRowDel.index)
                    }
                }
            }

            // Bottom system buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: [
                        { label: "[Reload Icons]", act: "reload", col: "fg" },
                        { label: "[Icon Manager]", act: "mgr", col: "secondary" },
                        { label: "[Audio Switch]", act: "audio", col: "accent" },
                        { label: "[Exit Session]", act: "exit", col: "danger" }
                    ]
                    delegate: Rectangle {
                        id: sysBtnDel
                        required property var modelData
                        Layout.fillWidth: true
                        height: 24
                        color: sysBtnMa.containsMouse ? root.theme.accent : root.theme.bg
                        border.color: root.theme[modelData.col]
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            font.family: root.monoFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: sysBtnMa.containsMouse ? root.theme.bg : root.theme[sysBtnDel.modelData.col]
                            text: sysBtnDel.modelData.label
                        }
                        MouseArea {
                            id: sysBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var act = sysBtnDel.modelData.act;
                                root.closeAllPopups();
                                if (act === "reload") root.callBackend(["icons", "list"], "icons");
                                else if (act === "mgr") root.openIconManager(null);
                                else if (act === "audio") root.callBackend(["audio", "toggle"], "audio");
                                else if (act === "exit") {
                                    var b = root.getBackend();
                                    if (b && b.quitCompositor) b.quitCompositor();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // --- 10. Audio Popup (z: 20) ---
    Rectangle {
        id: audioPopup
        visible: !root.secondaryScreenMode && root.audioPopupOpen
        anchors {
            right: parent.right
            bottom: bottomTaskbar.top
            rightMargin: Math.min(90, Math.max(6, root.width - width - 6))
            bottomMargin: 4
        }
        width: Math.min(370, Math.max(260, root.width - 16))
        height: Math.min(324, Math.max(220, root.height - 76))
        z: 20
        color: root.theme.panelBg
        border.color: root.theme.accent
        border.width: root.themeBorderWidth
        radius: root.themeRadius
        transformOrigin: Item.BottomRight

        onVisibleChanged: {
            if (visible) {
                root.triggerKineticPopup(audioPopup, volBtn);
            } else {
                scale = 1.0;
            }
        }

        MouseArea { anchors.fill: parent }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                if (event.angleDelta.y === 0) return;
                root.callBackend(["audio", "vol", event.angleDelta.y > 0 ? "+5%" : "-5%"], "audio");
            }
        }

        ColumnLayout {
            anchors { fill: parent; margins: 10 }
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    font.family: root.monoFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: root.theme.accent
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    text: "┌─[ AUDIO: " + (root.telemetry.audio_label || "PipeWire") + " ]"
                }
                Rectangle {
                    width: 24; height: 20
                    color: audioRefreshMa.containsMouse ? root.theme.accent : root.theme.bg
                    border.color: root.theme.muted; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        font.family: root.monoFamily
                        font.pixelSize: 10
                        color: audioRefreshMa.containsMouse ? root.theme.bg : root.theme.fg
                        text: "↻"
                    }
                    MouseArea {
                        id: audioRefreshMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.callBackend(["status"], "status")
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    width: 48; height: 24
                    color: vDownMa.containsMouse ? root.theme.accent : root.theme.bg
                    border.color: root.theme.muted; border.width: 1
                    Text { anchors.centerIn: parent; font.family: root.monoFamily; font.pixelSize: 11; color: vDownMa.containsMouse ? root.theme.bg : root.theme.fg; text: "[-5%]" }
                    MouseArea { id: vDownMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.callBackend(["audio", "vol", "-5%"], "audio") }
                }
                Rectangle {
                    id: volBarRect
                    Layout.fillWidth: true
                    height: 24
                    color: root.theme.bg
                    border.color: volBarMa.containsMouse ? root.theme.accent : root.theme.gridDot
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        font.family: root.monoFamily
                        font.pixelSize: 11
                        color: root.telemetry.audio_muted ? root.theme.danger : root.theme.secondary
                        text: "[ " + root.asciiBar(root.telemetry.audio_vol || 0, 12) + " ] " + (root.telemetry.audio_vol || 0) + "%"
                    }

                    MouseArea {
                        id: volBarMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: (mouse) => {
                            var pct = Math.max(0, Math.min(100, Math.round((mouse.x / Math.max(1, volBarRect.width)) * 20) * 5));
                            root.callBackend(["audio", "vol", pct + "%"], "audio");
                        }
                    }
                }
                Rectangle {
                    width: 48; height: 24
                    color: vUpMa.containsMouse ? root.theme.accent : root.theme.bg
                    border.color: root.theme.muted; border.width: 1
                    Text { anchors.centerIn: parent; font.family: root.monoFamily; font.pixelSize: 11; color: vUpMa.containsMouse ? root.theme.bg : root.theme.fg; text: "[+5%]" }
                    MouseArea { id: vUpMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.callBackend(["audio", "vol", "+5%"], "audio") }
                }
                Rectangle {
                    width: 56; height: 24
                    color: root.telemetry.audio_muted ? root.theme.danger : root.theme.bg
                    border.color: root.theme.danger; border.width: 1
                    Text { anchors.centerIn: parent; font.family: root.monoFamily; font.pixelSize: 10; font.bold: true; color: root.telemetry.audio_muted ? root.theme.bg : root.theme.danger; text: "[MUTE]" }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.callBackend(["audio", "mute"], "audio") }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Rectangle {
                    visible: root.hasOnkyo
                    Layout.fillWidth: true; height: 24
                    color: onkMa.containsMouse ? root.theme.secondary : root.theme.bg
                    border.color: root.theme.secondary; border.width: 1
                    Text { anchors.centerIn: parent; font.family: root.monoFamily; font.pixelSize: 10; font.bold: true; color: onkMa.containsMouse ? root.theme.bg : root.theme.secondary; text: "[ Onkyo 5.1 ]" }
                    MouseArea { id: onkMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.callBackend(["audio", "onkyo"], "audio") }
                }
                Rectangle {
                    Layout.fillWidth: true; height: 24
                    color: btMa.containsMouse ? root.theme.accent : root.theme.bg
                    border.color: root.theme.accent; border.width: 1
                    Text { anchors.centerIn: parent; font.family: root.monoFamily; font.pixelSize: 10; font.bold: true; color: btMa.containsMouse ? root.theme.bg : root.theme.accent; text: "[ Use BT ]" }
                    MouseArea { id: btMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.callBackend(["audio", "bt"], "audio") }
                }
                Rectangle {
                    Layout.fillWidth: true; height: 24
                    color: btMenuMa.containsMouse ? root.theme.accent : root.theme.bg
                    border.color: root.theme.accent; border.width: 1
                    Text { anchors.centerIn: parent; font.family: root.monoFamily; font.pixelSize: 10; font.bold: true; color: btMenuMa.containsMouse ? root.theme.bg : root.theme.accent; text: "[ BT Menu ]" }
                    MouseArea { id: btMenuMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.closeAllPopups(); Backend.launchApp("bt-menu"); } }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    font.family: root.monoFamily
                    font.pixelSize: 10
                    color: root.theme.muted
                    text: "AVAILABLE SINKS (scroll to adjust vol):"
                }
                Rectangle {
                    width: tuiMixTxt.implicitWidth + 10; height: 18
                    color: tuiMixMa.containsMouse ? root.theme.accent : root.theme.bg
                    border.color: root.theme.muted; border.width: 1
                    Text { id: tuiMixTxt; anchors.centerIn: parent; font.family: root.monoFamily; font.pixelSize: 9; color: tuiMixMa.containsMouse ? root.theme.bg : root.theme.fg; text: "[Mixer]" }
                    MouseArea {
                        id: tuiMixMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.closeAllPopups();
                            root.openAudioMixer();
                        }
                    }
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 3
                model: root.telemetry.sinks || []

                delegate: Rectangle {
                    id: sinkDel
                    required property var modelData
                    width: ListView.view.width
                    height: 26
                    color: modelData["default"] ? root.theme.accent : (sinkMa.containsMouse ? root.theme.gridDot : root.theme.bg)
                    border.color: modelData["default"] ? root.theme.accent : root.theme.gridDot
                    border.width: 1

                    Text {
                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: parent.right; leftMargin: 6; rightMargin: 6 }
                        elide: Text.ElideRight
                        font.family: root.monoFamily
                        font.pixelSize: 10
                        font.bold: Boolean(sinkDel.modelData["default"])
                        color: sinkDel.modelData["default"] ? root.theme.bg : root.theme.fg
                        text: (sinkDel.modelData["default"] ? "* " : "  ") + "[" + sinkDel.modelData.id + "] " + (sinkDel.modelData.desc || sinkDel.modelData.name || "sink") + " (" + sinkDel.modelData.vol + "%)"
                    }

                    MouseArea {
                        id: sinkMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.callBackend(["audio", "set-sink", String(sinkDel.modelData.id)], "audio")
                    }
                }
            }
        }
    }

    // --- 11. Clock & Interactive ASCII Calendar Popup (z: 20) ---
    Rectangle {
        id: clockPopup
        visible: !root.secondaryScreenMode && root.clockPopupOpen
        anchors {
            right: parent.right
            bottom: bottomTaskbar.top
            rightMargin: 6
            bottomMargin: 4
        }
        width: Math.min(298, Math.max(240, root.width - 16))
        height: Math.min(clockCol.implicitHeight + 20, Math.max(220, root.height - 76))
        z: 20
        clip: true
        color: root.theme.panelBg
        border.color: root.theme.accent
        border.width: root.themeBorderWidth
        radius: root.themeRadius
        transformOrigin: Item.BottomRight

        property int viewYear: (new Date()).getFullYear()
        property int viewMonth: (new Date()).getMonth()
        readonly property var monthNames: ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"]
        readonly property var weekdayNames: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

        function shiftMonth(delta) {
            var m = viewMonth + delta;
            var y = viewYear;
            while (m < 0) { m += 12; y -= 1; }
            while (m > 11) { m -= 12; y += 1; }
            viewMonth = m;
            viewYear = y;
        }

        function resetToToday() {
            var now = root.currentTime || new Date();
            viewYear = now.getFullYear();
            viewMonth = now.getMonth();
        }

        function calendarCells(y, m, nowDate) {
            var now = nowDate || new Date();
            var todayY = now.getFullYear();
            var todayM = now.getMonth();
            var todayD = now.getDate();

            var firstDay = new Date(y, m, 1).getDay(); // 0=Sun..6=Sat
            var daysInMonth = new Date(y, m + 1, 0).getDate();
            var prevMonthDays = new Date(y, m, 0).getDate();
            var cells = [];

            for (var i = firstDay - 1; i >= 0; i--) {
                cells.push({ day: prevMonthDays - i, inMonth: false, isToday: false });
            }
            for (var d = 1; d <= daysInMonth; d++) {
                cells.push({
                    day: d,
                    inMonth: true,
                    isToday: (y === todayY && m === todayM && d === todayD)
                });
            }
            var nextDay = 1;
            while (cells.length < 42) {
                cells.push({ day: nextDay++, inMonth: false, isToday: false });
            }
            return cells;
        }

        onVisibleChanged: {
            if (visible) {
                resetToToday();
                root.triggerKineticPopup(clockPopup, clockBtn);
            } else {
                scale = 1.0;
            }
        }

        MouseArea { anchors.fill: parent }

        Column {
            id: clockCol
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 10
            }
            spacing: 6

            Text {
                width: parent.width
                font.family: root.monoFamily
                font.pixelSize: 11
                font.bold: true
                color: root.theme.accent
                elide: Text.ElideRight
                text: "┌─[ CLOCK & CALENDAR ]───────┐"
            }

            RowLayout {
                width: parent.width
                spacing: 8
                Text {
                    font.family: root.monoFamily
                    font.pixelSize: 18
                    font.bold: true
                    color: root.theme.fg
                    text: root.formatClock(root.currentTime)
                }
                Column {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignRight
                        font.family: root.monoFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: root.theme.secondary
                        text: root.formatIsoDate(root.currentTime)
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignRight
                        font.family: root.monoFamily
                        font.pixelSize: 10
                        color: root.theme.muted
                        text: clockPopup.weekdayNames[root.currentTime.getDay()]
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: root.theme.gridDot
            }

            // Month navigation bar
            RowLayout {
                width: parent.width
                spacing: 4

                Rectangle {
                    width: 28; height: 22
                    color: prevMoMa.containsMouse ? root.theme.accent : root.theme.bg
                    border.color: root.theme.muted; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        font.family: root.monoFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: prevMoMa.containsMouse ? root.theme.bg : root.theme.fg
                        text: "<"
                    }
                    MouseArea {
                        id: prevMoMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clockPopup.shiftMonth(-1)
                    }
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    font.family: root.monoFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: root.theme.accent
                    text: clockPopup.monthNames[clockPopup.viewMonth] + " " + clockPopup.viewYear
                }

                Rectangle {
                    width: 46; height: 22
                    color: todayMoMa.containsMouse ? root.theme.secondary : root.theme.bg
                    border.color: root.theme.secondary; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        font.family: root.monoFamily
                        font.pixelSize: 10
                        font.bold: true
                        color: todayMoMa.containsMouse ? root.theme.bg : root.theme.secondary
                        text: "TODAY"
                    }
                    MouseArea {
                        id: todayMoMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clockPopup.resetToToday()
                    }
                }

                Rectangle {
                    width: 28; height: 22
                    color: nextMoMa.containsMouse ? root.theme.accent : root.theme.bg
                    border.color: root.theme.muted; border.width: 1
                    Text {
                        anchors.centerIn: parent
                        font.family: root.monoFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: nextMoMa.containsMouse ? root.theme.bg : root.theme.fg
                        text: ">"
                    }
                    MouseArea {
                        id: nextMoMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clockPopup.shiftMonth(1)
                    }
                }
            }

            // Weekday header
            Grid {
                width: parent.width
                columns: 7
                columnSpacing: 2

                Repeater {
                    model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                    delegate: Item {
                        id: calDowDel
                        required property string modelData
                        width: Math.floor((clockCol.width - 12) / 7)
                        height: 18
                        Text {
                            anchors.centerIn: parent
                            font.family: root.monoFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: (calDowDel.modelData === "Su" || calDowDel.modelData === "Sa")
                                   ? root.theme.accent
                                   : root.theme.muted
                            text: calDowDel.modelData
                        }
                    }
                }
            }

            // 6x7 Calendar grid
            Grid {
                width: parent.width
                columns: 7
                columnSpacing: 2
                rowSpacing: 2

                Repeater {
                    model: clockPopup.calendarCells(clockPopup.viewYear, clockPopup.viewMonth, root.currentTime)
                    delegate: Rectangle {
                        id: calDayCell
                        required property var modelData
                        width: Math.floor((clockCol.width - 12) / 7)
                        height: 20
                        color: calDayCell.modelData.isToday
                               ? root.theme.accent
                               : (calDayMa.containsMouse ? root.theme.gridDot : "transparent")
                        border.color: calDayCell.modelData.isToday ? root.theme.accent : "transparent"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            font.family: root.monoFamily
                            font.pixelSize: 10
                            font.bold: calDayCell.modelData.isToday
                            color: calDayCell.modelData.isToday
                                   ? root.theme.bg
                                   : (calDayCell.modelData.inMonth ? root.theme.fg : root.theme.muted)
                            opacity: calDayCell.modelData.inMonth ? 1.0 : 0.45
                            text: String(calDayCell.modelData.day)
                        }

                        MouseArea {
                            id: calDayMa
                            anchors.fill: parent
                            hoverEnabled: true
                        }
                    }
                }
            }

            Text {
                width: parent.width
                font.family: root.monoFamily
                font.pixelSize: 10
                color: root.theme.muted
                elide: Text.ElideRight
                text: "SESSION: ASCII-DE (Wayland Compositor)"
            }
        }
    }

    // --- 12. Alt-Tab Window Switcher Overlay (z: 25) ---
    Rectangle {
        id: altTabOverlay
        visible: !root.secondaryScreenMode && root.altTabOpen
        width: 440
        height: Math.min(360, Math.max(120, altTabCol.implicitHeight + 20))
        anchors.centerIn: parent
        z: 25
        color: root.theme.panelBg
        border.color: root.theme.accent
        border.width: root.themeBorderWidth
        radius: root.themeRadius

        MouseArea { anchors.fill: parent }

        Column {
            id: altTabCol
            anchors { fill: parent; margins: 10 }
            spacing: 4

            Text {
                font.family: root.monoFamily
                font.pixelSize: 11
                font.bold: true
                color: root.theme.accent
                text: "┌─[ SWITCH WINDOW (Alt+Tab / F2) ]───────────┐"
            }

            Repeater {
                model: root.currentWorkspaceWindows()
                delegate: Rectangle {
                    id: altTabDel
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === root.altTabIndex
                    width: parent.width
                    height: 26
                    color: sel ? root.theme.accent : root.theme.bg
                    border.color: sel ? root.theme.accent : root.theme.gridDot
                    border.width: 1

                    Text {
                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: parent.right; leftMargin: 8; rightMargin: 8 }
                        elide: Text.ElideRight
                        font.family: root.monoFamily
                        font.pixelSize: 11
                        font.bold: altTabDel.sel
                        color: altTabDel.sel ? root.theme.bg : root.theme.fg
                        text: (altTabDel.sel ? "▸ " : "  ") + "[" + root.padNum(altTabDel.index + 1) + "] " + (altTabDel.modelData.title || altTabDel.modelData.appId || "window")
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.altTabOpen = false;
                            if (altTabDel.modelData.focusFn) altTabDel.modelData.focusFn();
                        }
                    }
                }
            }

            Text {
                visible: root.currentWorkspaceWindows().length === 0
                font.family: root.monoFamily
                font.pixelSize: 11
                color: root.theme.muted
                text: "  (no open windows)"
            }
        }
    }

    // --- 13. ASCII Display Layout Editor Modal (z: 20) ---
    AsciiDisplayEditor {
        id: displayEditor
        visible: !root.secondaryScreenMode && root.displayEditorOpen
        width: Math.min(900, root.width - 40)
        height: Math.min(600, root.height - 80)
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        z: 20
        theme: root.theme
        monoFamily: root.monoFamily
        onCloseRequested: root.displayEditorOpen = false
        onDisplaysUpdated: (mons) => root.displaysUpdated(mons)
        onVisibleChanged: {
            if (visible) {
                root.raiseModal(displayEditor);
                if (x < 0 || x > root.width - 80 || y < 28 || y > root.height - 60) {
                    x = Math.round((root.width - width) / 2);
                    y = Math.round((root.height - height) / 2);
                }
            }
        }
    }

    // --- 14. ASCII-DE System Settings Modal (z: 20) ---
    AsciiSettingsApp {
        id: settingsApp
        visible: !root.secondaryScreenMode && root.settingsOpen
        width: Math.min(960, root.width - 40)
        height: Math.min(660, root.height - 60)
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        z: 20
        theme: root.theme
        monoFamily: root.monoFamily
        telemetry: root.telemetry
        settings: root.appSettings
        monitors: root.availableMonitors
        updateInfo: root.updateInfo
        onUpdateInfoUpdated: (info) => { root.updateInfo = info; }
        onCloseRequested: root.settingsOpen = false
        onSettingsUpdated: (newCfg) => root.applySettings(newCfg)
        onThemeUpdated: (newTh) => {
            root.theme = newTh;
            root.themeUpdated(newTh);
        }
        onOpenDisplayEditorRequested: root.openDisplayEditor()
        onOpenBackgroundEditorRequested: root.openBackgroundEditor()
        onOpenThemeAppRequested: root.openThemeApp()
        onOpenIconManagerRequested: root.openIconManager(null)
        onRequestSpawnApp: (cmd) => root.requestSpawnApp(cmd)
        onRefreshStatusRequested: root.callBackend(["status"], "status")
        onVisibleChanged: {
            if (visible) {
                root.raiseModal(settingsApp);
                root.triggerKineticPopup(settingsApp, setHdrBtn);
                if (x < 0 || x > root.width - 80 || y < 28 || y > root.height - 60) {
                    x = Math.round((root.width - width) / 2);
                    y = Math.round((root.height - height) / 2);
                }
            } else {
                scale = 1.0;
            }
        }
    }

    // --- 15. ASCII-DE Theme Overhaul Studio Modal (z: 20) ---
    AsciiThemeApp {
        id: themeApp
        visible: !root.secondaryScreenMode && root.themeAppOpen
        width: Math.min(940, root.width - 40)
        height: Math.min(640, root.height - 60)
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        z: 20
        theme: root.theme
        monoFamily: root.monoFamily
        availableMonitors: root.availableMonitors
        onCloseRequested: root.themeAppOpen = false
        onOpenBackgroundEditorRequested: root.openBackgroundEditor()
        onThemeUpdated: (newTh) => {
            root.theme = newTh;
            root.themeUpdated(newTh);
        }
        onVisibleChanged: {
            if (visible) {
                root.raiseModal(themeApp);
                root.triggerKineticPopup(themeApp, themeHdrBtn);
                if (x < 0 || x > root.width - 80 || y < 28 || y > root.height - 60) {
                    x = Math.round((root.width - width) / 2);
                    y = Math.round((root.height - height) / 2);
                }
            } else {
                scale = 1.0;
            }
        }
    }

    // --- 15.5. ASCII-DE Background & Tile Layout Editor Modal (z: 20) ---
    AsciiBackgroundEditor {
        id: backgroundEditor
        visible: !root.secondaryScreenMode && root.backgroundEditorOpen
        width: Math.min(1000, root.width - 40)
        height: Math.min(660, root.height - 60)
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        z: 20
        theme: root.theme
        monoFamily: root.monoFamily
        availableMonitors: root.availableMonitors
        settings: root.appSettings
        onCloseRequested: root.backgroundEditorOpen = false
        onSettingsUpdated: (newCfg) => root.applySettings(newCfg)
        onThemeUpdated: (newTh) => {
            root.theme = newTh;
            root.themeUpdated(newTh);
        }
        onVisibleChanged: {
            if (visible) {
                root.raiseModal(backgroundEditor);
                if (x < 0 || x > root.width - 80 || y < 28 || y > root.height - 60) {
                    x = Math.round((root.width - width) / 2);
                    y = Math.round((root.height - height) / 2);
                }
            }
        }
    }

    // --- 16. ASCII-DE Shortcut & Keybind Reference Modal (z: 20) ---
    AsciiKeybindHelp {
        id: keybindHelp
        visible: !root.secondaryScreenMode && root.keybindHelpOpen
        width: Math.min(780, root.width - 40)
        height: Math.min(540, root.height - 80)
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        z: 20
        theme: root.theme
        monoFamily: root.monoFamily
        onCloseRequested: root.keybindHelpOpen = false
        onVisibleChanged: {
            if (visible) {
                root.raiseModal(keybindHelp);
                root.triggerKineticPopup(keybindHelp, helpHdrBtn);
                if (x < 0 || x > root.width - 80 || y < 28 || y > root.height - 60) {
                    x = Math.round((root.width - width) / 2);
                    y = Math.round((root.height - height) / 2);
                }
            } else {
                scale = 1.0;
            }
        }
    }

    // --- 16. Shared SNAPTIC Origin Smear Wedge & Rim Impact Overlay ---
    Canvas {
        id: originSmearCanvas
        anchors.fill: parent
        z: 19
        visible: !root.secondaryScreenMode && root.smearProgress > 0.0 && root.smearProgress < 1.0

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            var p = root.smearProgress;
            if (p <= 0.0 || p >= 1.0) return;

            var alpha = (1.0 - p) * 0.85;
            var ox = root.smearOriginX;
            var oy = root.smearOriginY;
            var tx = root.smearTargetX;
            var ty = root.smearTargetY;
            var tw = root.smearTargetW;
            var th = root.smearTargetH;
            var cx = tx + tw * 0.5;
            var cy = ty + th * 0.5;

            var dx = cx - ox;
            var dy = cy - oy;
            var dist = Math.sqrt(dx * dx + dy * dy);
            if (dist < 4) return;

            // Pick silhouette edge endpoints orthogonal to direction (ox,oy)->(cx,cy)
            var c1x = tx;
            var c1y = ty;
            var c2x = tx + tw;
            var c2y = ty + th;
            if ((dx * dy) >= 0) {
                c1x = tx + tw;
                c1y = ty;
                c2x = tx;
                c2y = ty + th;
            }

            // Animate origin tip chasing toward popup center as it completes
            var tailT = Math.min(0.65, p * 0.65);
            var tipX = ox + (cx - ox) * tailT;
            var tipY = oy + (cy - oy) * tailT;

            ctx.save();
            var grad = ctx.createLinearGradient(tipX, tipY, cx, cy);
            grad.addColorStop(0.0, "rgba(69, 194, 255, " + (alpha * 0.15) + ")");
            grad.addColorStop(0.55, "rgba(123, 132, 191, " + (alpha * 0.42) + ")");
            grad.addColorStop(1.0, "rgba(69, 194, 255, " + (alpha * 0.55) + ")");
            ctx.fillStyle = grad;
            ctx.beginPath();
            ctx.moveTo(tipX, tipY);
            ctx.lineTo(c1x, c1y);
            ctx.lineTo(c2x, c2y);
            ctx.closePath();
            ctx.fill();

            // 3 trailing spear speed lines shooting from origin to popup
            var ux = dx / dist;
            var uy = dy / dist;
            var px = -uy;
            var py = ux;
            var offsets = [-0.28, 0.0, 0.28];
            for (var i = 0; i < offsets.length; i++) {
                var lat = offsets[i] * Math.min(tw, th) * 0.65;
                var sx0 = tipX + px * (lat * 0.25);
                var sy0 = tipY + py * (lat * 0.25);
                var sx1 = cx + px * lat;
                var sy1 = cy + py * lat;
                ctx.strokeStyle = (i === 1)
                                  ? ("rgba(255, 255, 255, " + alpha + ")")
                                  : ("rgba(69, 194, 255, " + (alpha * 0.9) + ")");
                ctx.lineWidth = (i === 1) ? 2.5 : 1.8;
                ctx.beginPath();
                ctx.moveTo(sx0, sy0);
                ctx.lineTo(sx1, sy1);
                ctx.stroke();
            }
            ctx.restore();
        }
    }

    Rectangle {
        id: sharedRimFlash
        visible: !root.secondaryScreenMode && opacity > 0.0 && root.rimTarget !== null
        x: root.smearTargetX
        y: root.smearTargetY
        width: root.smearTargetW
        height: root.smearTargetH
        radius: root.themeRadius
        z: 21
        color: "transparent"
        border.color: "#45C2FF"
        border.width: 3
        opacity: 0.0
    }

    NumberAnimation {
        id: sharedSmearAnim
        target: root
        property: "smearProgress"
        from: 0.01
        to: 1.0
        duration: 180
        easing.type: Easing.OutCubic
        onRunningChanged: {
            if (!running) root.smearProgress = 0.0;
        }
    }

    onSmearProgressChanged: {
        if (originSmearCanvas.visible) {
            originSmearCanvas.requestPaint();
        }
    }

    SequentialAnimation {
        id: sharedPopAnim
        PropertyAction { target: root.kineticTarget; property: "scale"; value: 0.82 }
        NumberAnimation { target: root.kineticTarget; property: "scale"; to: 1.06; duration: 135; easing.type: Easing.OutBack }
        NumberAnimation { target: root.kineticTarget; property: "scale"; to: 1.0; duration: 75; easing.type: Easing.OutQuad }
    }

    SequentialAnimation {
        id: sharedRimAnim
        PauseAnimation { duration: 120 }
        PropertyAction { target: sharedRimFlash; property: "opacity"; value: 0.95 }
        NumberAnimation { target: sharedRimFlash; property: "opacity"; to: 0.0; duration: 65; easing.type: Easing.OutQuad }
    }
}
