pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

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
        danger: "#ff5555",
        impactFlash: false,
        originSmear: false
    })
    property string monoFamily: "JetBrains Mono"
    property var telemetry: ({
        audio_label: "PipeWire",
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
    property bool checkingUpdates: false
    property bool bugReportLoading: false
    property bool bugReportOpenIssueAfter: false
    property var bugReportInfo: ({
        path: "",
        pasteUrl: "",
        issueUrl: "",
        uploadError: "",
        copied: false,
        bytes: 0,
        preview: ""
    })
    readonly property bool hasOnkyo: {
        if (Boolean(root.telemetry.has_onkyo || root.telemetry.onkyo_detected || root.telemetry.onkyo_active)) {
            return true;
        }
        if (Array.isArray(root.monitors)) {
            for (var i = 0; i < root.monitors.length; i++) {
                if (root.monitors[i] && root.monitors[i].onkyo_avr) {
                    return true;
                }
            }
        }
        return false;
    }
    property var settings: defaultSettings()
    property int activeTab: 0
    property var monitors: []
    property string statusMessage: "Settings synced."
    property bool statusError: false
    property bool maximizedModal: false
    property rect savedModalRect: Qt.rect(80, 50, 960, 660)

    implicitWidth: 960
    implicitHeight: 660

    readonly property bool kineticImpact: Boolean(root.theme && root.theme.impactFlash)
    readonly property bool kineticSmear: Boolean(root.theme && root.theme.originSmear)
    property real tabSpearSlide: 0.0
    property real tabFlashAlpha: 0.0
    property real saveFlashAlpha: 0.0
    property real saveBtnScale: 1.0
    property real contentFlashAlpha: 0.0

    signal closeRequested()
    signal settingsUpdated(var newSettings)
    signal themeUpdated(var newTheme)
    signal openDisplayEditorRequested()
    signal openBackgroundEditorRequested()
    signal openThemeAppRequested()
    signal openIconManagerRequested()
    signal requestSpawnApp(string cmd)
    signal refreshStatusRequested()
    signal updateInfoUpdated(var info)

    color: root.theme.panelBg
    border.color: root.theme.accent
    border.width: 2
    focus: true

    function toggleMaximizeModal() {
        if (!root.parent) return;
        if (!maximizedModal) {
            savedModalRect = Qt.rect(root.x, root.y, root.width, root.height);
            root.x = 12;
            root.y = 34;
            root.width = Math.max(740, root.parent.width - 24);
            root.height = Math.max(500, root.parent.height - 56);
            maximizedModal = true;
        } else {
            root.width = Math.min(savedModalRect.width || 960, root.parent.width - 40);
            root.height = Math.min(savedModalRect.height || 660, root.parent.height - 80);
            root.x = Math.round((root.parent.width - root.width) / 2);
            root.y = Math.round((root.parent.height - root.height) / 2);
            maximizedModal = false;
        }
    }

    Keys.onEscapePressed: (event) => {
        root.closeRequested();
        event.accepted = true;
    }
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            root.closeRequested();
            event.accepted = true;
        } else if (event.key === Qt.Key_Left && event.modifiers === Qt.NoModifier) {
            root.activeTab = (root.activeTab + 6) % 7;
            root.triggerTabImpact();
            event.accepted = true;
        } else if (event.key === Qt.Key_Right && event.modifiers === Qt.NoModifier) {
            root.activeTab = (root.activeTab + 1) % 7;
            root.triggerTabImpact();
            event.accepted = true;
        }
    }

    TapHandler {
        onTapped: root.forceActiveFocus()
    }

    function defaultSettings() {
        return {
            theme: "amber",
            fontFamily: "JetBrains Mono",
            fontSize: 13,
            gridDensity: "normal",
            showGridDots: true,
            crossMonitorDragging: true,
            snapEnabled: true,
            snapThresholdPx: 24,
            showSplitDivider: true,
            startMenuDefaultMode: "search",
            clockShowSeconds: true,
            clock24h: true,
            onkyoAudioGuard: true,
            bgTerminalEnabled: false,
            bgTerminalCmd: "asciiquarium",
            bgTerminalInteractive: false,
            bgTerminalX: 80,
            bgTerminalY: 60,
            bgTerminalWidth: 900,
            bgTerminalHeight: 520,
            bgTerminalFontSize: 11,
            bgTerminalOpacity: 0.0,
            bgTerminalMatchGrid: true,
            bgLayoutTiles: [],
            monitorAsciiImages: ({})
        };
    }

    function cloneSettings(src) {
        var base = defaultSettings();
        var cur = src || {};
        var out = {};
        for (var k in base) {
            if (Object.prototype.hasOwnProperty.call(base, k)) {
                if (cur[k] !== undefined && cur[k] !== null) {
                    if (Array.isArray(cur[k])) {
                        out[k] = cur[k].slice();
                    } else if (typeof cur[k] === "object") {
                        out[k] = Object.assign({}, cur[k]);
                    } else {
                        out[k] = cur[k];
                    }
                } else {
                    out[k] = base[k];
                }
            }
        }
        for (var ek in cur) {
            if (Object.prototype.hasOwnProperty.call(cur, ek) && out[ek] === undefined && cur[ek] !== null) {
                out[ek] = cur[ek];
            }
        }
        return out;
    }

    function activeMonitorInfo() {
        if (root.monitors && root.monitors.length > 0) {
            for (var i = 0; i < root.monitors.length; i++) {
                if (root.monitors[i] && root.monitors[i].primary) {
                    return root.monitors[i];
                }
            }
            return root.monitors[0];
        }
        return { name: "", width: 1920, height: 1080 };
    }

    function commitSettings(next, msg) {
        settings = next;
        statusError = false;
        statusMessage = msg || "Saved & applying...";
        settingsUpdated(next);
        triggerSaveImpact();
        runBackend(["settings", "set", JSON.stringify(next)], "settings_set");
    }

    function syncBgTerminalToggle(enable) {
        var next = cloneSettings(settings);
        next.bgTerminalEnabled = Boolean(enable);
        var tiles = Array.isArray(next.bgLayoutTiles) ? next.bgLayoutTiles.slice() : [];
        var primName = String(activeMonitorInfo().name || "");
        var cmd = String(next.bgTerminalCmd || "asciiquarium").trim() || "asciiquarium";
        var termCount = 0;
        for (var i = 0; i < tiles.length; i++) {
            var t = tiles[i];
            if (t && (t.kind === "terminal" || !t.kind)) {
                var copy = Object.assign({}, t, { enabled: Boolean(enable) });
                tiles[i] = copy;
                termCount++;
            }
        }
        if (enable && termCount === 0) {
            tiles.push({
                id: "tile-" + Date.now(),
                kind: "terminal",
                monitor: primName,
                x: Number(next.bgTerminalX) || 80,
                y: Number(next.bgTerminalY) || 60,
                width: Math.max(240, Number(next.bgTerminalWidth) || 900),
                height: Math.max(160, Number(next.bgTerminalHeight) || 520),
                enabled: true,
                cmd: cmd,
                interactive: Boolean(next.bgTerminalInteractive),
                fontSize: Number(next.bgTerminalFontSize) || 11,
                opacity: next.bgTerminalOpacity !== undefined ? Number(next.bgTerminalOpacity) : 0.0,
                matchGrid: next.bgTerminalMatchGrid !== false
            });
        }
        next.bgLayoutTiles = tiles;
        commitSettings(next, enable ? "Live terminal wallpaper enabled." : "Live terminal wallpaper turned off.");
    }

    function patchTerminalProp(propKey, propVal) {
        var next = cloneSettings(settings);
        next[propKey] = propVal;
        var tiles = Array.isArray(next.bgLayoutTiles) ? next.bgLayoutTiles.slice() : [];
        var tileKey = "";
        if (propKey === "bgTerminalCmd") tileKey = "cmd";
        else if (propKey === "bgTerminalFontSize") tileKey = "fontSize";
        else if (propKey === "bgTerminalOpacity") tileKey = "opacity";
        else if (propKey === "bgTerminalInteractive") tileKey = "interactive";
        else if (propKey === "bgTerminalMatchGrid") tileKey = "matchGrid";

        if (tileKey) {
            for (var i = 0; i < tiles.length; i++) {
                var t = tiles[i];
                if (t && (t.kind === "terminal" || !t.kind)) {
                    var copy = Object.assign({}, t);
                    if (tileKey !== "cmd" || i === 0) {
                        copy[tileKey] = propVal;
                    }
                    tiles[i] = copy;
                }
            }
        }
        next.bgLayoutTiles = tiles;
        commitSettings(next, "Updated " + propKey + ".");
    }

    function applyTerminalLayoutPreset(presetName) {
        var next = cloneSettings(settings);
        var mon = activeMonitorInfo();
        var monName = String(mon.name || "");
        var mw = Math.max(640, Number(mon.width) || 1920);
        var mh = Math.max(480, Number(mon.height) || 1080);
        var topOff = 26;
        var usableH = Math.max(200, mh - topOff);
        var baseCmd = String(next.bgTerminalCmd || "asciiquarium").trim() || "asciiquarium";
        var fs = Number(next.bgTerminalFontSize) || 11;
        var op = next.bgTerminalOpacity !== undefined ? Number(next.bgTerminalOpacity) : 0.0;
        var inter = Boolean(next.bgTerminalInteractive);
        var blend = next.bgTerminalMatchGrid !== false;

        var kept = [];
        var oldTiles = Array.isArray(next.bgLayoutTiles) ? next.bgLayoutTiles : [];
        for (var i = 0; i < oldTiles.length; i++) {
            var ot = oldTiles[i];
            if (!ot) continue;
            var tMon = String(ot.monitor || "");
            if (tMon !== "" && tMon !== monName && ot.kind === "terminal") {
                kept.push(ot);
            } else if (ot.kind === "ascii_image") {
                kept.push(ot);
            }
        }

        var ts = Date.now();
        function mkTile(suffix, x, y, w, h, cmdOverride, fontOverride) {
            return {
                id: "tile-" + ts + "-" + suffix,
                kind: "terminal",
                monitor: monName,
                x: Math.round(x),
                y: Math.round(y),
                width: Math.round(w),
                height: Math.round(h),
                enabled: true,
                cmd: cmdOverride || baseCmd,
                interactive: inter,
                fontSize: fontOverride || fs,
                opacity: op,
                matchGrid: blend
            };
        }

        if (presetName === "off") {
            next.bgTerminalEnabled = false;
            next.bgLayoutTiles = kept;
            commitSettings(next, "Live terminal wallpaper turned off.");
            return;
        } else if (presetName === "floating") {
            var fw = Math.min(900, Math.round(mw * 0.72));
            var fh = Math.min(520, Math.round(usableH * 0.68));
            kept.push(mkTile("1", Math.max(0, (mw - fw) / 2), topOff + Math.max(0, (usableH - fh) / 2), fw, fh, baseCmd, fs));
            next.bgTerminalWidth = fw;
            next.bgTerminalHeight = fh;
        } else if (presetName === "fullscreen") {
            kept.push(mkTile("full", 0, topOff, mw, usableH, baseCmd, fs));
            next.bgTerminalWidth = mw;
            next.bgTerminalHeight = usableH;
        } else if (presetName === "split_lr") {
            var hw = Math.round(mw / 2);
            kept.push(mkTile("l", 0, topOff, hw, usableH, baseCmd, fs));
            kept.push(mkTile("r", hw, topOff, mw - hw, usableH, "htop", fs));
        } else if (presetName === "main_stack") {
            var lw = Math.round(mw * 0.62);
            var rw = mw - lw;
            var hh = Math.round(usableH / 2);
            kept.push(mkTile("m", 0, topOff, lw, usableH, baseCmd, fs));
            kept.push(mkTile("t", lw, topOff, rw, hh, "htop", Math.max(9, fs - 1)));
            kept.push(mkTile("b", lw, topOff + hh, rw, usableH - hh, "cava", Math.max(9, fs - 1)));
        } else if (presetName === "grid2x2") {
            var ghw = Math.round(mw / 2);
            var ghh = Math.round(usableH / 2);
            var gcmds = [baseCmd, "cmatrix", "htop", "cava"];
            for (var r = 0; r < 2; r++) {
                for (var c = 0; c < 2; c++) {
                    var idx = r * 2 + c;
                    kept.push(mkTile(String(idx + 1), c * ghw, topOff + r * ghh, c === 0 ? ghw : mw - ghw, r === 0 ? ghh : usableH - ghh, gcmds[idx], Math.max(9, fs - 1)));
                }
            }
        }

        next.bgTerminalEnabled = true;
        next.bgLayoutTiles = kept;
        commitSettings(next, "Applied terminal layout: " + presetName);
    }

    function patchThemeProp(key, val) {
        var nextTh = Object.assign({}, root.theme || {}, {});
        nextTh[key] = val;
        if (key === "chromeStyle") {
            if (val === "snaptic_datalens") {
                nextTh.cornerRadius = 10;
                nextTh.borderWidth = 2;
            } else {
                nextTh.cornerRadius = 0;
                nextTh.borderWidth = 1;
            }
        }
        statusError = false;
        statusMessage = "Applying " + key + ": " + val;
        themeUpdated(nextTh);
        triggerSaveImpact();
        runBackend(["theme", "custom", JSON.stringify(nextTh)], "settings_theme");
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

    function getBackend() {
        // qmllint disable unqualified
        return (typeof Backend !== "undefined") ? Backend : null;
        // qmllint enable unqualified
    }

    function safeJsonParse(raw, fallback) {
        try {
            if (!raw || typeof raw !== "string") return fallback;
            return JSON.parse(raw);
        } catch (e) {
            return fallback;
        }
    }

    function runBackend(args, tag) {
        var b = getBackend();
        if (b && b.runBackendAsync) {
            b.runBackendAsync(args, tag);
        }
    }

    function shellQuote(s) {
        return "'" + String(s || "").replace(/'/g, "'\"'\"'") + "'";
    }

    function terminalCmd(shellBody) {
        return "sh -lc 'T=\"$(command -v ascii-de-terminal || command -v kitty || command -v foot || command -v konsole || command -v xterm)\"; exec \"$T\" -e sh -lc " + shellQuote(shellBody) + "'";
    }

    function loadSettings() {
        statusError = false;
        statusMessage = "Loading settings...";
        root.runBackend(["settings", "get"], "settings_get");
    }

    function loadMonitors() {
        root.runBackend(["displays", "list"], "settings_displays");
    }

    function triggerTabImpact() {
        if (!kineticImpact && !kineticSmear) {
            tabSpearSlide = 0.0;
            tabFlashAlpha = 0.0;
            contentFlashAlpha = 0.0;
            return;
        }
        tabImpactAnim.restart();
    }

    function triggerSaveImpact() {
        if (!kineticImpact) {
            saveFlashAlpha = 0.0;
            saveBtnScale = 1.0;
            return;
        }
        saveImpactAnim.restart();
    }

    function patchSetting(key, value) {
        var next = cloneSettings(settings);
        next[key] = value;
        settings = next;
        statusError = false;
        statusMessage = "Saving " + key + "...";
        settingsUpdated(next);
        triggerSaveImpact();
        root.runBackend(["settings", "set", JSON.stringify(next)], "settings_set");
        if (key === "theme") {
            root.runBackend(["theme", "set", String(value)], "settings_theme");
        }
    }

    function saveSettingsNow() {
        var next = cloneSettings(settings);
        settings = next;
        statusError = false;
        statusMessage = "Saved & applied.";
        settingsUpdated(next);
        triggerSaveImpact();
        root.runBackend(["settings", "set", JSON.stringify(next)], "settings_set");
    }

    function resetDefaults() {
        var defs = defaultSettings();
        settings = defs;
        statusError = false;
        statusMessage = "Resetting defaults...";
        settingsUpdated(defs);
        triggerSaveImpact();
        root.runBackend(["settings", "reset"], "settings_reset");
        root.runBackend(["theme", "set", defs.theme], "settings_theme");
    }

    onActiveTabChanged: triggerTabImpact()

    onVisibleChanged: {
        if (visible) {
            loadSettings();
            loadMonitors();
            refreshStatusRequested();
            if (!root.updateInfo || !root.updateInfo.current) {
                root.runBackend(["update-check"], "settings_update_check");
            }
        }
    }

    MouseArea {
        anchors.fill: parent
    }

    ParallelAnimation {
        id: tabImpactAnim
        SequentialAnimation {
            NumberAnimation {
                target: root
                property: "tabFlashAlpha"
                from: 0.92
                to: 0.0
                duration: 160
                easing.type: Easing.OutCubic
            }
        }
        SequentialAnimation {
            NumberAnimation {
                target: root
                property: "contentFlashAlpha"
                from: 0.55
                to: 0.0
                duration: 160
                easing.type: Easing.OutCubic
            }
        }
        NumberAnimation {
            target: root
            property: "tabSpearSlide"
            from: -14.0
            to: 0.0
            duration: 160
            easing.type: Easing.OutBack
            easing.overshoot: 1.5
        }
    }

    ParallelAnimation {
        id: saveImpactAnim
        NumberAnimation {
            target: root
            property: "saveFlashAlpha"
            from: 0.95
            to: 0.0
            duration: 180
            easing.type: Easing.OutCubic
        }
        SequentialAnimation {
            NumberAnimation {
                target: root
                property: "saveBtnScale"
                from: 0.94
                to: 1.05
                duration: 85
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: root
                property: "saveBtnScale"
                from: 1.05
                to: 1.0
                duration: 115
                easing.type: Easing.OutBack
            }
        }
    }

    // SNAPTIC cyan impact flash ring on toggle / Save & Apply
    Rectangle {
        anchors.fill: parent
        z: 100
        color: "transparent"
        border.color: "#45C2FF"
        border.width: 3
        opacity: root.saveFlashAlpha
        visible: opacity > 0.01
    }

    component KineticToggleButton : Rectangle {
        id: ktBtn
        property bool checked: false
        property string label: ""
        property bool kinetic: root.kineticImpact
        property color activeColor: root.theme.secondary
        property color inactiveColor: root.theme.panelBg
        property color activeTextColor: root.theme.bg
        property color inactiveTextColor: root.theme.fg
        property color inactiveBorderColor: root.theme.muted
        property real popScale: 1.0
        property real flashAlpha: 0.0
        signal toggled()

        Layout.fillWidth: true
        height: 28
        scale: popScale
        transformOrigin: Item.Center
        color: checked ? activeColor : (ktMa.containsMouse ? root.theme.gridDot : inactiveColor)
        border.color: checked ? activeColor : inactiveBorderColor
        border.width: 1

        ParallelAnimation {
            id: ktAnim
            NumberAnimation {
                target: ktBtn
                property: "flashAlpha"
                from: 0.92
                to: 0.0
                duration: 160
                easing.type: Easing.OutCubic
            }
            SequentialAnimation {
                NumberAnimation {
                    target: ktBtn
                    property: "popScale"
                    from: 0.96
                    to: 1.03
                    duration: 75
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: ktBtn
                    property: "popScale"
                    from: 1.03
                    to: 1.0
                    duration: 95
                    easing.type: Easing.OutBack
                }
            }
        }

        Text {
            anchors.centerIn: parent
            font.family: root.monoFamily
            font.pixelSize: 11
            font.bold: true
            color: ktBtn.checked ? ktBtn.activeTextColor : ktBtn.inactiveTextColor
            text: ktBtn.label
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: "#45C2FF"
            border.width: 2
            opacity: ktBtn.flashAlpha
            visible: opacity > 0.01
        }

        MouseArea {
            id: ktMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (ktBtn.kinetic) {
                    ktAnim.restart();
                }
                ktBtn.toggled();
            }
        }
    }

    Connections {
        target: root.getBackend()
        ignoreUnknownSignals: true

        function onBackendResult(tag, jsonOutput) {
            if (tag === "settings_get" || tag === "settings_set" || tag === "settings_reset") {
                var parsed = root.safeJsonParse(jsonOutput, null);
                if (parsed && typeof parsed === "object" && !parsed.error) {
                    var merged = root.cloneSettings(parsed);
                    root.settings = merged;
                    root.settingsUpdated(merged);
                    root.statusError = false;
                    root.statusMessage = (tag === "settings_reset")
                                         ? "Reset to defaults."
                                         : (tag === "settings_set" ? "Saved & applied." : "Settings loaded.");
                } else {
                    root.statusError = false;
                    root.statusMessage = "Using local settings preview.";
                }
            } else if (tag === "settings_theme") {
                var th = root.safeJsonParse(jsonOutput, null);
                if (th && typeof th === "object" && th.bg) {
                    root.themeUpdated(th);
                }
            } else if (tag === "settings_displays") {
                var mons = root.safeJsonParse(jsonOutput, null);
                if (Array.isArray(mons)) {
                    root.monitors = mons;
                }
            } else if (tag === "settings_audio") {
                var ares = root.safeJsonParse(jsonOutput, null);
                if (ares && ares.error) {
                    root.statusError = true;
                    root.statusMessage = String(ares.error);
                } else {
                    root.statusError = false;
                }
                root.refreshStatusRequested();
            } else if (tag === "settings_bug_report" || tag === "settings_bug_report_upload") {
                root.bugReportLoading = false;
                var openAfter = root.bugReportOpenIssueAfter;
                root.bugReportOpenIssueAfter = false;
                var br = root.safeJsonParse(jsonOutput, null);
                if (br && typeof br === "object" && br.ok) {
                    root.bugReportInfo = br;
                    if (br.uploadError && String(br.uploadError).length > 0) {
                        root.statusError = true;
                        root.statusMessage = "Saved " + (br.path || "report") + " (upload failed: " + br.uploadError + ")";
                    } else if (br.pasteUrl && String(br.pasteUrl).length > 0) {
                        root.statusError = false;
                        root.statusMessage = "Uploaded & copied URL: " + br.pasteUrl;
                    } else {
                        root.statusError = false;
                        root.statusMessage = br.copied
                            ? ("Report copied to clipboard (" + (br.path || "") + ")")
                            : ("Report saved: " + (br.path || ""));
                    }
                    if (openAfter && br.issueUrl) {
                        root.requestSpawnApp("xdg-open " + root.shellQuote(String(br.issueUrl)));
                    }
                } else {
                    root.statusError = true;
                    root.statusMessage = (br && br.error) ? String(br.error) : "Failed to collect bug report.";
                }
            } else if (tag === "settings_update_check") {
                root.checkingUpdates = false;
                var upd = root.safeJsonParse(jsonOutput, null);
                if (upd && typeof upd === "object" && !upd.error) {
                    root.updateInfo = upd;
                    root.updateInfoUpdated(upd);
                    root.statusError = false;
                    root.statusMessage = upd.updateAvailable
                        ? ("Update available: " + (upd.latest || "new release"))
                        : "Update status refreshed.";
                } else {
                    root.statusError = false;
                    root.statusMessage = "Updater not configured or offline.";
                }
            }
        }
    }

    ColumnLayout {
        anchors { fill: parent; margins: 10 }
        spacing: 8

        // Draggable Title bar container
        Item {
            Layout.fillWidth: true
            implicitHeight: 24

            MouseArea {
                id: titleDragArea
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.SizeAllCursor
                drag.target: root
                drag.minimumX: -root.width + 120
                drag.maximumX: (root.parent ? root.parent.width : 1920) - 120
                drag.minimumY: 28
                drag.maximumY: (root.parent ? root.parent.height : 1080) - 40
                onPressed: root.forceActiveFocus()
                onDoubleClicked: {
                    if (root.parent) {
                        root.x = Math.round((root.parent.width - root.width) / 2);
                        root.y = Math.round((root.parent.height - root.height) / 2);
                    }
                }
            }

            RowLayout {
                anchors.fill: parent
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.family: root.monoFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: root.theme.accent
                    text: "┌─[ ASCII-DE SYSTEM SETTINGS ]──────────────────────────────────────┐"
                }

                Rectangle {
                    z: 2
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 22
                    color: maxSetMa.containsMouse ? root.theme.accent : root.theme.bg
                    border.color: root.theme.accent
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        font.family: root.monoFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: maxSetMa.containsMouse ? root.theme.bg : root.theme.accent
                        text: root.maximizedModal ? "[❐]" : "[□]"
                    }

                    MouseArea {
                        id: maxSetMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleMaximizeModal()
                    }
                }

                Rectangle {
                    z: 2
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 22
                    color: closeMa.containsMouse ? root.theme.danger : root.theme.bg
                    border.color: root.theme.danger
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        font.family: root.monoFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: closeMa.containsMouse ? root.theme.bg : root.theme.danger
                        text: "[✕]"
                    }

                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeRequested()
                    }
                }
            }
        }

        // Main Split: Left ASCII Sidebar Tabs + Right Content Pane
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            // Left ASCII Sidebar
            Rectangle {
                Layout.preferredWidth: Math.min(224, Math.max(178, Math.round(root.width * 0.24)))
                Layout.fillHeight: true
                color: root.theme.bg
                border.color: root.theme.muted
                border.width: 1

                ColumnLayout {
                    anchors { fill: parent; margins: 6 }
                    spacing: 4

                    Text {
                        font.family: root.monoFamily
                        font.pixelSize: 10
                        font.bold: true
                        color: root.theme.muted
                        text: "SECTIONS:"
                    }

                    Repeater {
                        model: [
                            { idx: 0, label: "[ 1. Appearance        ]" },
                            { idx: 1, label: "[ 2. Wallpaper & Term  ]" },
                            { idx: 2, label: "[ 3. Displays          ]" },
                            { idx: 3, label: root.hasOnkyo ? "[ 4. Audio & Onkyo     ]" : "[ 4. Audio & Devices   ]" },
                            { idx: 4, label: "[ 5. Windows & Snap    ]" },
                            { idx: 5, label: "[ 6. Panel & Shortcuts ]" },
                            { idx: 6, label: (root.updateInfo && root.updateInfo.updateAvailable) ? "[ 7. Updates & Bugs [U]]" : "[ 7. Updates & Bugs    ]" }
                        ]
                        delegate: Rectangle {
                            id: tabDel
                            required property var modelData
                            readonly property bool isCur: root.activeTab === modelData.idx
                            property real popScale: 1.0
                            property real localFlash: 0.0
                            Layout.fillWidth: true
                            height: 28
                            scale: popScale
                            transformOrigin: Item.Center
                            color: isCur ? root.theme.accent : (tabMa.containsMouse ? root.theme.gridDot : root.theme.panelBg)
                            border.color: isCur ? root.theme.accent : root.theme.gridDot
                            border.width: 1

                            onIsCurChanged: {
                                if (isCur && (root.kineticImpact || root.kineticSmear)) {
                                    tabBounceAnim.restart();
                                } else {
                                    popScale = 1.0;
                                    localFlash = 0.0;
                                }
                            }

                            ParallelAnimation {
                                id: tabBounceAnim
                                SequentialAnimation {
                                    NumberAnimation {
                                        target: tabDel
                                        property: "popScale"
                                        from: 0.94
                                        to: 1.03
                                        duration: 75
                                        easing.type: Easing.OutQuad
                                    }
                                    NumberAnimation {
                                        target: tabDel
                                        property: "popScale"
                                        from: 1.03
                                        to: 1.0
                                        duration: 85
                                        easing.type: Easing.OutBack
                                    }
                                }
                                NumberAnimation {
                                    target: tabDel
                                    property: "localFlash"
                                    from: 0.95
                                    to: 0.0
                                    duration: 160
                                    easing.type: Easing.OutCubic
                                }
                            }

                            // Sliding spear accent line (▸) when active
                            Text {
                                id: spearIndicator
                                visible: tabDel.isCur
                                anchors.verticalCenter: parent.verticalCenter
                                x: 4 + (root.kineticImpact || root.kineticSmear ? root.tabSpearSlide : 0)
                                font.family: root.monoFamily
                                font.pixelSize: 11
                                font.bold: true
                                color: (root.kineticImpact && root.tabFlashAlpha > 0.15) ? "#45C2FF" : root.theme.bg
                                text: "▸"
                            }

                            Text {
                                anchors {
                                    verticalCenter: parent.verticalCenter
                                    left: parent.left
                                    right: parent.right
                                    leftMargin: tabDel.isCur ? 16 : 6
                                    rightMargin: 6
                                }
                                Behavior on anchors.leftMargin {
                                    enabled: root.kineticImpact || root.kineticSmear
                                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                                }
                                elide: Text.ElideRight
                                font.family: root.monoFamily
                                font.pixelSize: 11
                                font.bold: tabDel.isCur
                                color: tabDel.isCur ? root.theme.bg : root.theme.fg
                                text: tabDel.modelData.label
                            }

                            // 160ms #45C2FF cyan impact flash border + tint
                            Rectangle {
                                anchors.fill: parent
                                color: "#45C2FF"
                                opacity: tabDel.localFlash * 0.30
                                visible: opacity > 0.01
                            }
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: "#45C2FF"
                                border.width: 2
                                opacity: tabDel.localFlash
                                visible: opacity > 0.01
                            }

                            MouseArea {
                                id: tabMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activeTab = tabDel.modelData.idx
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.family: root.monoFamily
                        font.pixelSize: 10
                        color: root.theme.muted
                        text: "CONFIG:\n~/.config/ascii-de/\nsettings.json"
                    }
                }
            }

            // Right Content Pane
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: root.theme.bg
                border.color: root.theme.muted
                border.width: 1

                Rectangle {
                    anchors.fill: parent
                    z: 20
                    color: "transparent"
                    border.color: "#45C2FF"
                    border.width: 2
                    opacity: Math.max(root.contentFlashAlpha, root.saveFlashAlpha * 0.65)
                    visible: opacity > 0.01
                }

                Flickable {
                    anchors { fill: parent; margins: 10 }
                    contentWidth: width
                    contentHeight: contentCol.implicitHeight
                    clip: true

                    ColumnLayout {
                        id: contentCol
                        width: parent.width
                        spacing: 10

                        // --- TAB 0: Appearance ---
                        ColumnLayout {
                            visible: root.activeTab === 0
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                font.family: root.monoFamily
                                font.pixelSize: 12
                                font.bold: true
                                color: root.theme.accent
                                text: "═══ 1. THEME, COLORS & TYPOGRAPHY ═══"
                            }

                            Text {
                                font.family: root.monoFamily
                                font.pixelSize: 10
                                color: root.theme.muted
                                text: "COLOR PRESETS (instant apply):"
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 3
                                columnSpacing: 6
                                rowSpacing: 6
                                Repeater {
                                    model: [
                                        { id: "amber",   label: "[ Amber CRT ]" },
                                        { id: "green",   label: "[ Cyber Green ]" },
                                        { id: "cyan",    label: "[ Ice Cyan ]" },
                                        { id: "mono",    label: "[ Monochrome ]" },
                                        { id: "snaptic", label: "[ SNAPTIC Lens ]" },
                                        { id: "xmas",    label: "[ Xmas Tree ]" }
                                    ]
                                    delegate: Rectangle {
                                        id: thDel
                                        required property var modelData
                                        readonly property bool active: (root.settings.theme || "amber") === modelData.id
                                        Layout.fillWidth: true
                                        height: 28
                                        color: active ? root.theme.accent : (thMa.containsMouse ? root.theme.gridDot : root.theme.panelBg)
                                        border.color: active ? root.theme.accent : root.theme.muted
                                        border.width: 1
                                        Text {
                                            anchors.centerIn: parent
                                            font.family: root.monoFamily
                                            font.pixelSize: 11
                                            font.bold: thDel.active
                                            color: thDel.active ? root.theme.bg : root.theme.fg
                                            text: thDel.modelData.label
                                        }
                                        MouseArea {
                                            id: thMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.patchSetting("theme", thDel.modelData.id)
                                        }
                                    }
                                }
                            }

                            Text {
                                font.family: root.monoFamily
                                font.pixelSize: 10
                                color: root.theme.muted
                                text: "WINDOW FRAME CHROME:"
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Repeater {
                                    model: [
                                        { id: "ascii",            label: "[ ASCII Box ┌─┐ ]" },
                                        { id: "snaptic_datalens", label: "[ SNAPTIC Data Lens ]" },
                                        { id: "minimal",          label: "[ Minimal ]" }
                                    ]
                                    delegate: Rectangle {
                                        id: chrDel
                                        required property var modelData
                                        readonly property bool active: (root.theme && root.theme.chromeStyle ? root.theme.chromeStyle : "ascii") === modelData.id
                                        Layout.fillWidth: true
                                        height: 26
                                        color: active ? root.theme.secondary : (chrMa.containsMouse ? root.theme.gridDot : root.theme.panelBg)
                                        border.color: active ? root.theme.secondary : root.theme.muted
                                        border.width: 1
                                        Text {
                                            anchors.centerIn: parent
                                            font.family: root.monoFamily
                                            font.pixelSize: 10
                                            font.bold: chrDel.active
                                            color: chrDel.active ? root.theme.bg : root.theme.fg
                                            text: chrDel.modelData.label
                                        }
                                        MouseArea {
                                            id: chrMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.patchThemeProp("chromeStyle", chrDel.modelData.id)
                                        }
                                    }
                                }
                            }

                            Text {
                                font.family: root.monoFamily
                                font.pixelSize: 10
                                color: root.theme.muted
                                text: "MONOSPACE FONT FAMILY:"
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                columnSpacing: 6
                                rowSpacing: 4
                                Repeater {
                                    model: [
                                        "JetBrains Mono",
                                        "CaskaydiaCove Nerd Font Mono",
                                        "Hack",
                                        "DejaVu Sans Mono"
                                    ]
                                    delegate: Rectangle {
                                        id: fontDel
                                        required property string modelData
                                        readonly property bool active: (root.settings.fontFamily || "JetBrains Mono") === modelData
                                        Layout.fillWidth: true
                                        height: 26
                                        color: active ? root.theme.accent : (fontMa.containsMouse ? root.theme.gridDot : root.theme.panelBg)
                                        border.color: active ? root.theme.accent : root.theme.gridDot
                                        border.width: 1
                                        Text {
                                            anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: parent.right; leftMargin: 8; rightMargin: 8 }
                                            elide: Text.ElideRight
                                            font.family: root.monoFamily
                                            font.pixelSize: 11
                                            font.bold: fontDel.active
                                            color: fontDel.active ? root.theme.bg : root.theme.fg
                                            text: (fontDel.active ? "[●] " : "[ ] ") + fontDel.modelData
                                        }
                                        MouseArea {
                                            id: fontMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.patchSetting("fontFamily", fontDel.modelData)
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Text {
                                    font.family: root.monoFamily
                                    font.pixelSize: 10
                                    color: root.theme.muted
                                    text: "UI FONT SIZE:"
                                }
                                Repeater {
                                    model: [11, 12, 13, 14, 15, 16]
                                    delegate: Rectangle {
                                        id: fsDel
                                        required property int modelData
                                        readonly property bool active: Number(root.settings.fontSize || 13) === modelData
                                        Layout.fillWidth: true
                                        height: 24
                                        color: active ? root.theme.accent : (fsMa.containsMouse ? root.theme.gridDot : root.theme.panelBg)
                                        border.color: active ? root.theme.accent : root.theme.muted
                                        border.width: 1
                                        Text {
                                            anchors.centerIn: parent
                                            font.family: root.monoFamily
                                            font.pixelSize: 11
                                            font.bold: fsDel.active
                                            color: fsDel.active ? root.theme.bg : root.theme.fg
                                            text: fsDel.modelData + "px"
                                        }
                                        MouseArea {
                                            id: fsMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.patchSetting("fontSize", fsDel.modelData)
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                KineticToggleButton {
                                    Layout.fillWidth: false
                                    Layout.preferredWidth: 210
                                    checked: Boolean(root.settings.showGridDots)
                                    label: "[ ASCII Dot Grid: " + (root.settings.showGridDots ? "ON" : "OFF") + " ]"
                                    onToggled: root.patchSetting("showGridDots", !Boolean(root.settings.showGridDots))
                                }

                                Repeater {
                                    model: ["sparse", "normal", "dense"]
                                    delegate: Rectangle {
                                        id: gdDel
                                        required property string modelData
                                        readonly property bool active: (root.settings.gridDensity || "normal") === modelData
                                        Layout.fillWidth: true
                                        height: 28
                                        color: active ? root.theme.accent : (gdMa.containsMouse ? root.theme.gridDot : root.theme.panelBg)
                                        border.color: active ? root.theme.accent : root.theme.muted
                                        border.width: 1
                                        Text {
                                            anchors.centerIn: parent
                                            font.family: root.monoFamily
                                            font.pixelSize: 11
                                            font.bold: gdDel.active
                                            color: gdDel.active ? root.theme.bg : root.theme.fg
                                            text: "[ " + gdDel.modelData + " ]"
                                        }
                                        MouseArea {
                                            id: gdMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.patchSetting("gridDensity", gdDel.modelData)
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 30
                                color: openThemeStudioMa.containsMouse ? root.theme.accent : root.theme.panelBg
                                border.color: root.theme.accent
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    font.family: root.monoFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: openThemeStudioMa.containsMouse ? root.theme.bg : root.theme.accent
                                    text: "[ ◐ Open Custom Color & Animation Theme Studio... ]"
                                }
                                MouseArea {
                                    id: openThemeStudioMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openThemeAppRequested()
                                }
                            }
                        }

                        // --- TAB 1: Wallpaper & Live Terminal ---
                        ColumnLayout {
                            id: wallpaperTabCol
                            visible: root.activeTab === 1
                            Layout.fillWidth: true
                            spacing: 10

                            readonly property int configuredTileCount: (root.settings && Array.isArray(root.settings.bgLayoutTiles))
                                ? root.settings.bgLayoutTiles.filter(function(t) { return t && t.enabled !== false; }).length
                                : (root.settings.bgTerminalEnabled ? 1 : 0)

                            Text {
                                font.family: root.monoFamily
                                font.pixelSize: 12
                                font.bold: true
                                color: root.theme.accent
                                text: "═══ 2. DESKTOP WALLPAPER & LIVE TERMINAL ═══"
                            }

                            // Section A: Live Terminal Wallpaper Card
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: termWallpaperCol.implicitHeight + 16
                                color: root.theme.panelBg
                                border.color: root.settings.bgTerminalEnabled ? root.theme.secondary : root.theme.muted
                                border.width: 1

                                ColumnLayout {
                                    id: termWallpaperCol
                                    anchors { fill: parent; margins: 8 }
                                    spacing: 8

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Text {
                                            Layout.fillWidth: true
                                            font.family: root.monoFamily
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: root.settings.bgTerminalEnabled ? root.theme.secondary : root.theme.fg
                                            text: "LIVE TERMINAL WALLPAPER (" + (root.settings.bgTerminalEnabled ? ("ACTIVE · " + wallpaperTabCol.configuredTileCount + " tile(s)") : "OFF") + ")"
                                        }

                                        Text {
                                            font.family: root.monoFamily
                                            font.pixelSize: 10
                                            color: root.theme.muted
                                            text: "Shows live TUI (asciiquarium, htop, cava...) behind windows"
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        KineticToggleButton {
                                            checked: Boolean(root.settings.bgTerminalEnabled)
                                            label: "[ Live Terminal Wallpaper: " + (root.settings.bgTerminalEnabled ? "ON" : "OFF") + " ]"
                                            onToggled: root.syncBgTerminalToggle(!Boolean(root.settings.bgTerminalEnabled))
                                        }

                                        KineticToggleButton {
                                            checked: Boolean(root.settings.bgTerminalInteractive)
                                            inactiveBorderColor: root.theme.secondary
                                            label: "[ Click/Type Inside: " + (root.settings.bgTerminalInteractive ? "ON" : "OFF") + " ]"
                                            onToggled: root.patchTerminalProp("bgTerminalInteractive", !Boolean(root.settings.bgTerminalInteractive))
                                        }
                                    }

                                    Text {
                                        font.family: root.monoFamily
                                        font.pixelSize: 10
                                        color: root.theme.muted
                                        text: "QUICK 1-CLICK LAYOUT ON PRIMARY MONITOR:"
                                    }

                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 3
                                        columnSpacing: 6
                                        rowSpacing: 6

                                        Repeater {
                                            model: [
                                                { id: "floating",   label: "[ 1x Center Box ]" },
                                                { id: "fullscreen", label: "[ 1x Fullscreen ]" },
                                                { id: "split_lr",   label: "[ 2x Split Left|Right ]" },
                                                { id: "main_stack", label: "[ 3x Main + Stack ]" },
                                                { id: "grid2x2",    label: "[ 4x 2x2 Grid ]" },
                                                { id: "off",        label: "[ Turn Off Terminal ]" }
                                            ]
                                            delegate: Rectangle {
                                                id: termPreDel
                                                required property var modelData
                                                Layout.fillWidth: true
                                                height: 26
                                                color: termPreMa.containsMouse
                                                       ? (modelData.id === "off" ? root.theme.danger : root.theme.secondary)
                                                       : root.theme.bg
                                                border.color: modelData.id === "off" ? root.theme.danger : root.theme.muted
                                                border.width: 1
                                                Text {
                                                    anchors.centerIn: parent
                                                    font.family: root.monoFamily
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                    color: termPreMa.containsMouse
                                                           ? root.theme.bg
                                                           : (termPreDel.modelData.id === "off" ? root.theme.danger : root.theme.fg)
                                                    text: termPreDel.modelData.label
                                                }
                                                MouseArea {
                                                    id: termPreMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.applyTerminalLayoutPreset(termPreDel.modelData.id)
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        font.family: root.monoFamily
                                        font.pixelSize: 10
                                        color: root.theme.muted
                                        text: "COMMAND TO RUN (primary tile):"
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 28
                                            color: root.theme.bg
                                            border.color: bgTermCmdInput.activeFocus ? root.theme.accent : root.theme.muted
                                            border.width: 1

                                            TextInput {
                                                id: bgTermCmdInput
                                                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                                verticalAlignment: TextInput.AlignVCenter
                                                font.family: root.monoFamily
                                                font.pixelSize: 11
                                                color: root.theme.fg
                                                clip: true
                                                text: String(root.settings.bgTerminalCmd || "asciiquarium")
                                                onAccepted: root.patchTerminalProp("bgTerminalCmd", text.trim() || "asciiquarium")
                                            }
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 112
                                            height: 28
                                            color: bgTermApplyMa.containsMouse ? root.theme.accent : root.theme.bg
                                            border.color: root.theme.accent
                                            border.width: 1
                                            Text {
                                                anchors.centerIn: parent
                                                font.family: root.monoFamily
                                                font.pixelSize: 11
                                                font.bold: true
                                                color: bgTermApplyMa.containsMouse ? root.theme.bg : root.theme.accent
                                                text: "[ Apply Cmd ]"
                                            }
                                            MouseArea {
                                                id: bgTermApplyMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.patchTerminalProp("bgTerminalCmd", bgTermCmdInput.text.trim() || "asciiquarium")
                                            }
                                        }
                                    }

                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Repeater {
                                            model: ["asciiquarium", "cmatrix", "agy-usage", "btop", "htop", "cava", "cbonsai -li", "fastfetch"]
                                            delegate: Rectangle {
                                                id: bgPresetDel
                                                required property string modelData
                                                readonly property bool active: String(root.settings.bgTerminalCmd || "asciiquarium") === modelData
                                                implicitWidth: cmdPresetTxt.implicitWidth + 12
                                                height: 24
                                                color: active ? root.theme.secondary : (bgPreMa.containsMouse ? root.theme.gridDot : root.theme.bg)
                                                border.color: active ? root.theme.secondary : root.theme.muted
                                                border.width: 1
                                                Text {
                                                    id: cmdPresetTxt
                                                    anchors.centerIn: parent
                                                    font.family: root.monoFamily
                                                    font.pixelSize: 10
                                                    font.bold: bgPresetDel.active
                                                    color: bgPresetDel.active ? root.theme.bg : root.theme.fg
                                                    text: bgPresetDel.modelData
                                                }
                                                MouseArea {
                                                    id: bgPreMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        bgTermCmdInput.text = bgPresetDel.modelData;
                                                        root.patchTerminalProp("bgTerminalCmd", bgPresetDel.modelData);
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Text {
                                            font.family: root.monoFamily
                                            font.pixelSize: 10
                                            color: root.theme.muted
                                            text: "FONT:"
                                        }

                                        Repeater {
                                            model: [9, 10, 11, 12, 14]
                                            delegate: Rectangle {
                                                id: termFsDel
                                                required property int modelData
                                                readonly property bool active: Number(root.settings.bgTerminalFontSize || 11) === modelData
                                                implicitWidth: 42
                                                height: 24
                                                color: active ? root.theme.accent : (termFsMa.containsMouse ? root.theme.gridDot : root.theme.bg)
                                                border.color: active ? root.theme.accent : root.theme.muted
                                                border.width: 1
                                                Text {
                                                    anchors.centerIn: parent
                                                    font.family: root.monoFamily
                                                    font.pixelSize: 10
                                                    color: termFsDel.active ? root.theme.bg : root.theme.fg
                                                    text: termFsDel.modelData + "px"
                                                }
                                                MouseArea {
                                                    id: termFsMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.patchTerminalProp("bgTerminalFontSize", termFsDel.modelData)
                                                }
                                            }
                                        }

                                        Text {
                                            font.family: root.monoFamily
                                            font.pixelSize: 10
                                            color: root.theme.muted
                                            text: "BG:"
                                        }

                                        Repeater {
                                            model: [
                                                { val: 0.0,  label: "0% Dots" },
                                                { val: 0.35, label: "35% Tint" },
                                                { val: 0.75, label: "75% Dark" },
                                                { val: 1.0,  label: "100% Solid" }
                                            ]
                                            delegate: Rectangle {
                                                id: termOpDel
                                                required property var modelData
                                                readonly property bool active: Math.abs(Number(root.settings.bgTerminalOpacity || 0.0) - modelData.val) < 0.05
                                                Layout.fillWidth: true
                                                height: 24
                                                color: active ? root.theme.accent : (termOpMa.containsMouse ? root.theme.gridDot : root.theme.bg)
                                                border.color: active ? root.theme.accent : root.theme.muted
                                                border.width: 1
                                                Text {
                                                    anchors.centerIn: parent
                                                    font.family: root.monoFamily
                                                    font.pixelSize: 10
                                                    color: termOpDel.active ? root.theme.bg : root.theme.fg
                                                    text: termOpDel.modelData.label
                                                }
                                                MouseArea {
                                                    id: termOpMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.patchTerminalProp("bgTerminalOpacity", termOpDel.modelData.val)
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 30
                                        color: openBgEdMa.containsMouse ? root.theme.accent : root.theme.bg
                                        border.color: root.theme.accent
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            font.family: root.monoFamily
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: openBgEdMa.containsMouse ? root.theme.bg : root.theme.accent
                                            text: "[ ⛶ Open Visual 2D Multi-Monitor & Image->ASCII Studio... ]"
                                        }

                                        MouseArea {
                                            id: openBgEdMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.openBackgroundEditorRequested()
                                        }
                                    }
                                }
                            }

                            // Section B: Global Desktop Scene / Wallpaper Mode
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: sceneBgCol.implicitHeight + 16
                                color: root.theme.panelBg
                                border.color: root.theme.muted
                                border.width: 1

                                ColumnLayout {
                                    id: sceneBgCol
                                    anchors { fill: parent; margins: 8 }
                                    spacing: 6

                                    Text {
                                        font.family: root.monoFamily
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: root.theme.accent
                                        text: "DESKTOP WALLPAPER SCENE (CURRENT: " + ((root.theme && root.theme.backgroundStyle) ? String(root.theme.backgroundStyle).toUpperCase() : "ASCII_GRID") + ")"
                                    }

                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 4
                                        columnSpacing: 6
                                        rowSpacing: 6

                                        Repeater {
                                            model: [
                                                { id: "ascii_grid",     label: "[ ASCII Grid ]" },
                                                { id: "christmas_tree", label: "[ Xmas Tree ]" },
                                                { id: "newsboard",      label: "[ Newsboard ]" },
                                                { id: "visualizer",     label: "[ Visualizer ]" },
                                                { id: "snaptic_void",   label: "[ SNAPTIC Void ]" },
                                                { id: "solid",          label: "[ Solid Color ]" },
                                                { id: "gradient",       label: "[ Gradient ]" },
                                                { id: "ascii_image",    label: "[ Image -> ASCII ]" }
                                            ]
                                            delegate: Rectangle {
                                                id: scBgDel
                                                required property var modelData
                                                readonly property bool active: (root.theme && root.theme.backgroundStyle ? root.theme.backgroundStyle : "ascii_grid") === modelData.id
                                                Layout.fillWidth: true
                                                height: 26
                                                color: active ? root.theme.accent : (scBgMa.containsMouse ? root.theme.gridDot : root.theme.bg)
                                                border.color: active ? root.theme.accent : root.theme.muted
                                                border.width: 1
                                                Text {
                                                    anchors.centerIn: parent
                                                    font.family: root.monoFamily
                                                    font.pixelSize: 10
                                                    font.bold: scBgDel.active
                                                    color: scBgDel.active ? root.theme.bg : root.theme.fg
                                                    text: scBgDel.modelData.label
                                                }
                                                MouseArea {
                                                    id: scBgMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        root.patchThemeProp("backgroundStyle", scBgDel.modelData.id);
                                                        if (scBgDel.modelData.id === "ascii_image") {
                                                            root.openBackgroundEditorRequested();
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // --- TAB 2: Displays ---
                        ColumnLayout {
                            visible: root.activeTab === 2
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                font.family: root.monoFamily
                                font.pixelSize: 12
                                font.bold: true
                                color: root.theme.accent
                                text: "═══ 3. DISPLAYS & MULTI-MONITOR ═══"
                            }

                            Text {
                                visible: root.monitors.length === 0
                                font.family: root.monoFamily
                                font.pixelSize: 11
                                color: root.theme.muted
                                text: "(No monitor metadata cached — open Layout Editor or Refresh)"
                            }

                            Repeater {
                                model: root.monitors
                                delegate: Rectangle {
                                    id: monSumDel
                                    required property var modelData
                                    Layout.fillWidth: true
                                    height: 40
                                    color: root.theme.panelBg
                                    border.color: modelData.primary ? root.theme.accent : (modelData.onkyo_avr ? root.theme.secondary : root.theme.gridDot)
                                    border.width: 1

                                    Column {
                                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: parent.right; margins: 6 }
                                        spacing: 2
                                        Text {
                                            width: parent.width
                                            elide: Text.ElideRight
                                            font.family: root.monoFamily
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: monSumDel.modelData.primary ? root.theme.accent : root.theme.fg
                                            text: (monSumDel.modelData.primary ? "★ " : "  ")
                                                  + (monSumDel.modelData.name || "OUTPUT")
                                                  + (monSumDel.modelData.onkyo_avr ? " [ONKYO AVR]" : "")
                                                  + (!monSumDel.modelData.enabled ? " [OFF]" : "")
                                        }
                                        Text {
                                            width: parent.width
                                            elide: Text.ElideRight
                                            font.family: root.monoFamily
                                            font.pixelSize: 10
                                            color: root.theme.muted
                                            text: "  " + (monSumDel.modelData.width || 0) + "x" + (monSumDel.modelData.height || 0)
                                                  + "@" + Math.round(Number(monSumDel.modelData.refresh || 60)) + "Hz"
                                                  + "  pos:(" + (monSumDel.modelData.x || 0) + "," + (monSumDel.modelData.y || 0) + ")"
                                                  + "  rot:" + (monSumDel.modelData.rotation || 0) + "°"
                                                  + "  scale:" + Number(monSumDel.modelData.scale || 1).toFixed(2) + "x"
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 30
                                    color: openDispMa.containsMouse ? root.theme.accent : root.theme.panelBg
                                    border.color: root.theme.accent
                                    border.width: 1
                                    Text {
                                        anchors.centerIn: parent
                                        font.family: root.monoFamily
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: openDispMa.containsMouse ? root.theme.bg : root.theme.accent
                                        text: "[ ⊞ Open Display Layout Editor ]"
                                    }
                                    MouseArea {
                                        id: openDispMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.openDisplayEditorRequested()
                                    }
                                }

                                Rectangle {
                                    width: 110
                                    height: 30
                                    color: refDispMa.containsMouse ? root.theme.gridDot : root.theme.panelBg
                                    border.color: root.theme.muted
                                    border.width: 1
                                    Text {
                                        anchors.centerIn: parent
                                        font.family: root.monoFamily
                                        font.pixelSize: 11
                                        color: root.theme.fg
                                        text: "[ ↻ Refresh ]"
                                    }
                                    MouseArea {
                                        id: refDispMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.loadMonitors()
                                    }
                                }
                            }
                        }

                        // --- TAB 3: Audio ---
                        ColumnLayout {
                            visible: root.activeTab === 3
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                font.family: root.monoFamily
                                font.pixelSize: 12
                                font.bold: true
                                color: root.theme.accent
                                text: root.hasOnkyo ? "═══ 4. AUDIO & ONKYO RECEIVER ═══" : "═══ 4. AUDIO & DEVICES ═══"
                            }

                            Text {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                font.family: root.monoFamily
                                font.pixelSize: 11
                                color: root.theme.secondary
                                text: "ACTIVE SINK: " + (root.telemetry.audio_label || "PipeWire")
                                      + (root.telemetry.audio_muted ? " [MUTED]" : "")
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Rectangle {
                                    width: 56; height: 26
                                    color: sVDownMa.containsMouse ? root.theme.accent : root.theme.panelBg
                                    border.color: root.theme.muted; border.width: 1
                                    Text { anchors.centerIn: parent; font.family: root.monoFamily; font.pixelSize: 11; color: sVDownMa.containsMouse ? root.theme.bg : root.theme.fg; text: "[-5%]" }
                                    MouseArea { id: sVDownMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.runBackend(["audio", "vol", "-5%"], "settings_audio") }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    font.family: root.monoFamily
                                    font.pixelSize: 11
                                    color: root.telemetry.audio_muted ? root.theme.danger : root.theme.secondary
                                    text: "[ " + root.asciiBar(root.telemetry.audio_vol || 0, 12) + " ] " + (root.telemetry.audio_vol || 0) + "%"
                                }
                                Rectangle {
                                    width: 56; height: 26
                                    color: sVUpMa.containsMouse ? root.theme.accent : root.theme.panelBg
                                    border.color: root.theme.muted; border.width: 1
                                    Text { anchors.centerIn: parent; font.family: root.monoFamily; font.pixelSize: 11; color: sVUpMa.containsMouse ? root.theme.bg : root.theme.fg; text: "[+5%]" }
                                    MouseArea { id: sVUpMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.runBackend(["audio", "vol", "+5%"], "settings_audio") }
                                }
                                Rectangle {
                                    width: 68; height: 26
                                    color: root.telemetry.audio_muted ? root.theme.danger : root.theme.panelBg
                                    border.color: root.theme.danger; border.width: 1
                                    Text { anchors.centerIn: parent; font.family: root.monoFamily; font.pixelSize: 11; font.bold: true; color: root.telemetry.audio_muted ? root.theme.bg : root.theme.danger; text: "[Mute]" }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.runBackend(["audio", "mute"], "settings_audio") }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Rectangle {
                                    visible: root.hasOnkyo
                                    Layout.fillWidth: true; height: 28
                                    color: sOnkMa.containsMouse ? root.theme.secondary : root.theme.panelBg
                                    border.color: root.theme.secondary; border.width: 1
                                    Text { anchors.centerIn: parent; font.family: root.monoFamily; font.pixelSize: 11; font.bold: true; color: sOnkMa.containsMouse ? root.theme.bg : root.theme.secondary; text: "[ Onkyo 5.1 ]" }
                                    MouseArea { id: sOnkMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.runBackend(["audio", "onkyo"], "settings_audio") }
                                }

                                Rectangle {
                                    Layout.fillWidth: true; height: 28
                                    color: sBtMa.containsMouse ? root.theme.accent : root.theme.panelBg
                                    border.color: root.theme.accent; border.width: 1
                                    Text { anchors.centerIn: parent; font.family: root.monoFamily; font.pixelSize: 11; font.bold: true; color: sBtMa.containsMouse ? root.theme.bg : root.theme.accent; text: "[ BT Audio Sink ]" }
                                    MouseArea { id: sBtMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.runBackend(["audio", "bt"], "settings_audio") }
                                }

                                Rectangle {
                                    Layout.fillWidth: true; height: 28
                                    color: sBtMenuMa.containsMouse ? root.theme.accent : root.theme.panelBg
                                    border.color: root.theme.accent; border.width: 1
                                    Text { anchors.centerIn: parent; font.family: root.monoFamily; font.pixelSize: 11; font.bold: true; color: sBtMenuMa.containsMouse ? root.theme.bg : root.theme.accent; text: "[ Bluetooth Manager ]" }
                                    MouseArea {
                                        id: sBtMenuMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.requestSpawnApp("bt-menu")
                                    }
                                }
                            }

                            KineticToggleButton {
                                visible: root.hasOnkyo
                                checked: Boolean(root.settings.onkyoAudioGuard)
                                label: "[ Onkyo HDMI Keep-Alive Guard: " + (root.settings.onkyoAudioGuard ? "ON" : "OFF") + " ]"
                                onToggled: root.patchSetting("onkyoAudioGuard", !Boolean(root.settings.onkyoAudioGuard))
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 28
                                color: mixBtnMa.containsMouse ? root.theme.accent : root.theme.panelBg
                                border.color: root.theme.accent
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    font.family: root.monoFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: mixBtnMa.containsMouse ? root.theme.bg : root.theme.accent
                                    text: "[ Launch TUI Mixer ]"
                                }
                                MouseArea {
                                    id: mixBtnMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.closeRequested();
                                        root.requestSpawnApp(root.terminalCmd("for c in terminal-plasma-mixer wiremix pulsemixer alsamixer; do command -v \"$c\" >/dev/null 2>&1 && exec \"$c\"; done; wpctl status; printf \"\\nPress Enter...\"; read -r _"));
                                    }
                                }
                            }
                        }

                        // --- TAB 4: Windows & Snap ---
                        ColumnLayout {
                            visible: root.activeTab === 4
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                font.family: root.monoFamily
                                font.pixelSize: 12
                                font.bold: true
                                color: root.theme.accent
                                text: "═══ 5. WINDOWS & AERO SNAP ═══"
                            }

                            KineticToggleButton {
                                height: 30
                                checked: Boolean(root.settings.snapEnabled)
                                label: "[ Aero Snap Dot-to-Gray-Line Preview: " + (root.settings.snapEnabled ? "ON" : "OFF") + " ]"
                                onToggled: root.patchSetting("snapEnabled", !Boolean(root.settings.snapEnabled))
                            }

                            Text {
                                font.family: root.monoFamily
                                font.pixelSize: 10
                                color: root.theme.muted
                                text: "EDGE SNAP MAGNETIC THRESHOLD:"
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Repeater {
                                    model: [16, 24, 36]
                                    delegate: Rectangle {
                                        id: stDel
                                        required property int modelData
                                        readonly property bool active: Number(root.settings.snapThresholdPx || 24) === modelData
                                        Layout.fillWidth: true
                                        height: 26
                                        color: active ? root.theme.accent : (stMa.containsMouse ? root.theme.gridDot : root.theme.panelBg)
                                        border.color: active ? root.theme.accent : root.theme.muted
                                        border.width: 1
                                        Text {
                                            anchors.centerIn: parent
                                            font.family: root.monoFamily
                                            font.pixelSize: 11
                                            font.bold: stDel.active
                                            color: stDel.active ? root.theme.bg : root.theme.fg
                                            text: "[ " + stDel.modelData + " px ]"
                                        }
                                        MouseArea {
                                            id: stMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.patchSetting("snapThresholdPx", stDel.modelData)
                                        }
                                    }
                                }
                            }

                            KineticToggleButton {
                                height: 30
                                checked: Boolean(root.settings.showSplitDivider)
                                label: "[ Windows 11 Split-Divider (║): " + (root.settings.showSplitDivider ? "ON" : "OFF") + " ]"
                                onToggled: root.patchSetting("showSplitDivider", !Boolean(root.settings.showSplitDivider))
                            }

                            KineticToggleButton {
                                height: 30
                                checked: root.settings.crossMonitorDragging !== false
                                label: "[ Multi-Monitor Cross-Screen Drag: " + (root.settings.crossMonitorDragging !== false ? "SMOOTH" : "CONFINED") + " ]"
                                onToggled: root.patchSetting("crossMonitorDragging", !(root.settings.crossMonitorDragging !== false))
                            }
                        }

                        // --- TAB 5: Panel, Desktop Icons & Shortcuts ---
                        ColumnLayout {
                            visible: root.activeTab === 5
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                font.family: root.monoFamily
                                font.pixelSize: 12
                                font.bold: true
                                color: root.theme.accent
                                text: "═══ 6. PANEL, START MENU & SHORTCUTS ═══"
                            }

                            Text {
                                font.family: root.monoFamily
                                font.pixelSize: 10
                                color: root.theme.muted
                                text: "DEFAULT START MENU MODE:"
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Repeater {
                                    model: [
                                        { id: "search",  label: "[ SEARCH ]" },
                                        { id: "folders", label: "[ FOLDERS ]" }
                                    ]
                                    delegate: Rectangle {
                                        id: smDel
                                        required property var modelData
                                        readonly property bool active: (root.settings.startMenuDefaultMode || "search") === modelData.id
                                        Layout.fillWidth: true
                                        height: 28
                                        color: active ? root.theme.accent : (smMa.containsMouse ? root.theme.gridDot : root.theme.panelBg)
                                        border.color: active ? root.theme.accent : root.theme.muted
                                        border.width: 1
                                        Text {
                                            anchors.centerIn: parent
                                            font.family: root.monoFamily
                                            font.pixelSize: 11
                                            font.bold: smDel.active
                                            color: smDel.active ? root.theme.bg : root.theme.fg
                                            text: smDel.modelData.label
                                        }
                                        MouseArea {
                                            id: smMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.patchSetting("startMenuDefaultMode", smDel.modelData.id)
                                        }
                                    }
                                }
                            }

                            Text {
                                font.family: root.monoFamily
                                font.pixelSize: 10
                                color: root.theme.muted
                                text: "TASKBAR CLOCK FORMAT:"
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                KineticToggleButton {
                                    checked: Boolean(root.settings.clock24h)
                                    inactiveBorderColor: root.theme.secondary
                                    label: "[ Clock: " + (root.settings.clock24h ? "24h" : "12h") + " ]"
                                    onToggled: root.patchSetting("clock24h", !Boolean(root.settings.clock24h))
                                }

                                KineticToggleButton {
                                    checked: Boolean(root.settings.clockShowSeconds)
                                    inactiveBorderColor: root.theme.secondary
                                    label: "[ Seconds: " + (root.settings.clockShowSeconds ? "ON" : "OFF") + " ]"
                                    onToggled: root.patchSetting("clockShowSeconds", !Boolean(root.settings.clockShowSeconds))
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 30
                                color: iconMgrBtnMa.containsMouse ? root.theme.accent : root.theme.panelBg
                                border.color: root.theme.accent
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    font.family: root.monoFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: iconMgrBtnMa.containsMouse ? root.theme.bg : root.theme.accent
                                    text: "[ ✎ Open Desktop Icon Manager ]"
                                }
                                MouseArea {
                                    id: iconMgrBtnMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openIconManagerRequested()
                                }
                            }

                            Text {
                                font.family: root.monoFamily
                                font.pixelSize: 11
                                font.bold: true
                                color: root.theme.accent
                                text: "KEYBOARD SHORTCUTS:"
                            }

                            Text {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                font.family: root.monoFamily
                                font.pixelSize: 11
                                color: root.theme.fg
                                text: "  Meta / Super       : Toggle Start Menu\n"
                                      + "  Meta + Enter       : Launch Terminal (ascii-de-terminal)\n"
                                      + "  Meta + S           : System Settings\n"
                                      + "  Meta + P / Meta+D  : Display Layout Editor\n"
                                      + "  Meta + I           : Desktop Icon Manager\n"
                                      + "  Meta + Alt + 1..4  : Switch Workspace\n"
                                      + "  Meta + Arrow Keys  : Aero Snap / Quarter Tile\n"
                                      + "  Alt  + Tab         : Window Switcher\n"
                                      + "  Meta + Q           : Close Active Window\n"
                                      + "  Right-Click Desk   : ASCII Desktop Menu"
                            }
                        }

                        // --- TAB 6: Updates ---
                        ColumnLayout {
                            visible: root.activeTab === 6
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                font.family: root.monoFamily
                                font.pixelSize: 12
                                font.bold: true
                                color: root.theme.accent
                                text: "═══ 7. SYSTEM UPDATES ═══"
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: updCol.implicitHeight + 16
                                color: root.theme.panelBg
                                border.color: (root.updateInfo && root.updateInfo.updateAvailable) ? root.theme.accent : root.theme.muted
                                border.width: 1

                                ColumnLayout {
                                    id: updCol
                                    anchors { fill: parent; margins: 8 }
                                    spacing: 4

                                    Text {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        font.family: root.monoFamily
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: (root.updateInfo && root.updateInfo.updateAvailable) ? root.theme.accent : root.theme.secondary
                                        text: "STATUS          : " + (root.checkingUpdates
                                            ? "CHECKING..."
                                            : ((root.updateInfo && root.updateInfo.updateAvailable)
                                                ? ("UPDATE AVAILABLE (" + (root.updateInfo.latest || "new") + ")")
                                                : ((root.updateInfo && root.updateInfo.current) ? "UP TO DATE" : "UPDATER NOT CONFIGURED")))
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        font.family: root.monoFamily
                                        font.pixelSize: 11
                                        color: root.theme.fg
                                        text: "CURRENT VERSION : " + ((root.updateInfo && root.updateInfo.current) ? root.updateInfo.current : "unknown")
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        font.family: root.monoFamily
                                        font.pixelSize: 11
                                        color: root.theme.fg
                                        text: "LATEST RELEASE  : " + ((root.updateInfo && root.updateInfo.latest) ? root.updateInfo.latest : "unavailable")
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        font.family: root.monoFamily
                                        font.pixelSize: 10
                                        color: root.theme.muted
                                        text: "LAST CHECKED    : " + ((root.updateInfo && root.updateInfo.checkedAt) ? root.updateInfo.checkedAt : "never")
                                    }
                                    Text {
                                        visible: Boolean(root.updateInfo && root.updateInfo.releaseUrl)
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        font.family: root.monoFamily
                                        font.pixelSize: 10
                                        color: root.theme.muted
                                        text: "RELEASE URL     : " + ((root.updateInfo && root.updateInfo.releaseUrl) ? root.updateInfo.releaseUrl : "")
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 30
                                    color: chkUpdMa.containsMouse ? root.theme.accent : root.theme.panelBg
                                    border.color: root.theme.accent
                                    border.width: 1
                                    Text {
                                        anchors.centerIn: parent
                                        font.family: root.monoFamily
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: chkUpdMa.containsMouse ? root.theme.bg : root.theme.accent
                                        text: root.checkingUpdates ? "[ Checking... ]" : "[ ↻ Check for Updates ]"
                                    }
                                    MouseArea {
                                        id: chkUpdMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.checkingUpdates = true;
                                            root.statusError = false;
                                            root.statusMessage = "Checking for ASCII-DE updates...";
                                            root.runBackend(["update-check", "--force"], "settings_update_check");
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 30
                                    color: applyUpdMa.containsMouse ? root.theme.secondary : root.theme.panelBg
                                    border.color: root.theme.secondary
                                    border.width: 1
                                    Text {
                                        anchors.centerIn: parent
                                        font.family: root.monoFamily
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: applyUpdMa.containsMouse ? root.theme.bg : root.theme.secondary
                                        text: "[ >_ Update in Terminal ]"
                                    }
                                    MouseArea {
                                        id: applyUpdMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.closeRequested();
                                        root.requestSpawnApp(root.terminalCmd("if command -v ascii-de >/dev/null 2>&1 && (command -v ascii-de-update >/dev/null 2>&1 || [ -x /usr/bin/ascii-de-update ]); then ascii-de update --apply; elif command -v ascii-de-update >/dev/null 2>&1; then ascii-de-update --apply; else echo \"ascii-de-update is not installed on PATH.\"; fi; printf \"\\nPress Enter to close...\"; read -r _"));
                                    }
                                }
                            }
                        }

                        Text {
                            font.family: root.monoFamily
                            font.pixelSize: 12
                            font.bold: true
                            color: root.theme.accent
                            text: "═══ BUG REPORT & LOGS ═══"
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: bugCol.implicitHeight + 16
                            color: root.theme.panelBg
                            border.color: root.theme.muted
                            border.width: 1

                            ColumnLayout {
                                id: bugCol
                                anchors { fill: parent; margins: 8 }
                                spacing: 6

                                Text {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    font.family: root.monoFamily
                                    font.pixelSize: 10
                                    color: root.theme.secondary
                                    text: "Collects sanitized system, audio, bluetooth, display & session logs to share safely."
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 28
                                    color: root.theme.bg
                                    border.color: bugNoteInput.activeFocus ? root.theme.accent : root.theme.muted
                                    border.width: 1

                                    TextInput {
                                        id: bugNoteInput
                                        anchors { fill: parent; margins: 6 }
                                        verticalAlignment: TextInput.AlignVCenter
                                        clip: true
                                        font.family: root.monoFamily
                                        font.pixelSize: 11
                                        color: root.theme.fg
                                        selectionColor: root.theme.accent
                                        selectedTextColor: root.theme.bg
                                    }

                                    Text {
                                        anchors { fill: parent; margins: 6 }
                                        verticalAlignment: Text.AlignVCenter
                                        font.family: root.monoFamily
                                        font.pixelSize: 11
                                        color: root.theme.muted
                                        visible: bugNoteInput.text.length === 0 && !bugNoteInput.activeFocus
                                        text: "Describe issue (optional)..."
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 28
                                        color: collectBugMa.containsMouse ? root.theme.accent : root.theme.bg
                                        border.color: root.theme.accent
                                        border.width: 1
                                        Text {
                                            anchors.centerIn: parent
                                            font.family: root.monoFamily
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: collectBugMa.containsMouse ? root.theme.bg : root.theme.accent
                                            text: root.bugReportLoading ? "[ Working... ]" : "[ Collect & Copy Logs ]"
                                        }
                                        MouseArea {
                                            id: collectBugMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (root.bugReportLoading) return;
                                                root.bugReportLoading = true;
                                                root.bugReportOpenIssueAfter = false;
                                                root.statusError = false;
                                                root.statusMessage = "Collecting sanitized diagnostics...";
                                                root.runBackend(["bug-report", "--note", bugNoteInput.text], "settings_bug_report");
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 28
                                        color: uploadBugMa.containsMouse ? root.theme.secondary : root.theme.bg
                                        border.color: root.theme.secondary
                                        border.width: 1
                                        Text {
                                            anchors.centerIn: parent
                                            font.family: root.monoFamily
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: uploadBugMa.containsMouse ? root.theme.bg : root.theme.secondary
                                            text: "[ Upload Logs (paste.rs) ]"
                                        }
                                        MouseArea {
                                            id: uploadBugMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (root.bugReportLoading) return;
                                                root.bugReportLoading = true;
                                                root.bugReportOpenIssueAfter = false;
                                                root.statusError = false;
                                                root.statusMessage = "Collecting & uploading sanitized logs...";
                                                root.runBackend(["bug-report", "--upload", "--note", bugNoteInput.text], "settings_bug_report_upload");
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 28
                                        color: issueBugMa.containsMouse ? root.theme.accent : root.theme.bg
                                        border.color: root.theme.accent
                                        border.width: 1
                                        Text {
                                            anchors.centerIn: parent
                                            font.family: root.monoFamily
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: issueBugMa.containsMouse ? root.theme.bg : root.theme.accent
                                            text: "[ Open GitHub Issue ]"
                                        }
                                        MouseArea {
                                            id: issueBugMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (root.bugReportInfo && root.bugReportInfo.issueUrl) {
                                                    root.requestSpawnApp("xdg-open " + root.shellQuote(String(root.bugReportInfo.issueUrl)));
                                                    return;
                                                }
                                                if (root.bugReportLoading) return;
                                                root.bugReportLoading = true;
                                                root.bugReportOpenIssueAfter = true;
                                                root.statusError = false;
                                                root.statusMessage = "Preparing diagnostics for GitHub Issue...";
                                                root.runBackend(["bug-report", "--note", bugNoteInput.text], "settings_bug_report");
                                            }
                                        }
                                    }
                                }

                                Text {
                                    visible: Boolean(root.bugReportInfo && root.bugReportInfo.path)
                                    Layout.fillWidth: true
                                    elide: Text.ElideMiddle
                                    font.family: root.monoFamily
                                    font.pixelSize: 10
                                    color: root.theme.fg
                                    text: "SAVED FILE : " + ((root.bugReportInfo && root.bugReportInfo.path) ? root.bugReportInfo.path : "")
                                }

                                Text {
                                    visible: Boolean(root.bugReportInfo && root.bugReportInfo.pasteUrl)
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    font.family: root.monoFamily
                                    font.pixelSize: 10
                                    color: root.theme.secondary
                                    text: "PASTE URL  : " + ((root.bugReportInfo && root.bugReportInfo.pasteUrl) ? root.bugReportInfo.pasteUrl : "")
                                }
                            }
                        }
                        }
                    }
                }
            }
        }

        // Bottom Status & Action Bar
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.family: root.monoFamily
                font.pixelSize: 11
                color: root.statusError ? root.theme.danger : root.theme.secondary
                text: "STATUS: " + root.statusMessage
            }

            Rectangle {
                implicitWidth: Math.max(136, saveSetLbl.implicitWidth + 16)
                height: 26
                scale: root.saveBtnScale
                transformOrigin: Item.Center
                color: saveMa.containsMouse ? root.theme.secondary : root.theme.bg
                border.color: root.theme.secondary
                border.width: 1
                Text {
                    id: saveSetLbl
                    anchors.centerIn: parent
                    font.family: root.monoFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: saveMa.containsMouse ? root.theme.bg : root.theme.secondary
                    text: "[ SAVE & APPLY ]"
                }
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: "#45C2FF"
                    border.width: 2
                    opacity: root.saveFlashAlpha
                    visible: opacity > 0.01
                }
                MouseArea {
                    id: saveMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.saveSettingsNow()
                }
            }

            Rectangle {
                implicitWidth: Math.max(146, rstSetLbl.implicitWidth + 16)
                height: 26
                color: rstMa.containsMouse ? root.theme.danger : root.theme.bg
                border.color: root.theme.danger
                border.width: 1
                Text {
                    id: rstSetLbl
                    anchors.centerIn: parent
                    font.family: root.monoFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: rstMa.containsMouse ? root.theme.bg : root.theme.danger
                    text: "[ ↺ Reset Defaults ]"
                }
                MouseArea {
                    id: rstMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.resetDefaults()
                }
            }

            Rectangle {
                implicitWidth: Math.max(96, doneSetLbl.implicitWidth + 16)
                height: 26
                color: doneMa.containsMouse ? root.theme.accent : root.theme.bg
                border.color: root.theme.accent
                border.width: 1
                Text {
                    id: doneSetLbl
                    anchors.centerIn: parent
                    font.family: root.monoFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: doneMa.containsMouse ? root.theme.bg : root.theme.accent
                    text: "[ ✓ Close ]"
                }
                MouseArea {
                    id: doneMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }
    }

    // Bottom-right corner resize grip
    Rectangle {
        width: 14
        height: 14
        z: 50
        anchors { right: parent.right; bottom: parent.bottom; margins: 2 }
        color: "transparent"
        Text {
            anchors.centerIn: parent
            font.family: root.monoFamily
            font.pixelSize: 11
            color: resizeSetMa.containsMouse ? root.theme.accent : root.theme.muted
            text: "◢"
        }
        MouseArea {
            id: resizeSetMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeFDiagCursor
            property real startX: 0
            property real startY: 0
            onPressed: (mouse) => {
                startX = mouse.x;
                startY = mouse.y;
                root.maximizedModal = false;
            }
            onPositionChanged: (mouse) => {
                var maxW = root.parent ? root.parent.width - root.x - 8 : 1800;
                var maxH = root.parent ? root.parent.height - root.y - 34 : 1000;
                root.width = Math.max(700, Math.min(maxW, Math.round(root.width + (mouse.x - startX))));
                root.height = Math.max(480, Math.min(maxH, Math.round(root.height + (mouse.y - startY))));
            }
        }
    }
}
