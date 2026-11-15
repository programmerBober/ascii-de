pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs

Rectangle {
    id: editorRoot

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
    property string monoFamily: "JetBrains Mono"
    property var availableMonitors: []
    property var settings: defaultSettings()
    property string statusMessage: "Arrange terminal & image tiles on canvas; click Save & Apply."
    property bool statusIsWarning: false

    property string selectedMonitorName: (availableMonitors && availableMonitors.length > 0 && availableMonitors[0].name) ? String(availableMonitors[0].name) : "primary"
    property string selectedTileId: ""
    property bool maximizedModal: false
    property rect savedModalRect: Qt.rect(60, 40, 1000, 660)

    // Working local copy of settings and theme backgrounds
    property var draftTiles: cloneTiles((settings && settings.bgLayoutTiles) ? settings.bgLayoutTiles : [])
    property var draftMonitorBgs: cloneMap((theme && theme.monitorBackgrounds) ? theme.monitorBackgrounds : ({}))
    property var draftMonitorImages: cloneMap((settings && settings.monitorAsciiImages) ? settings.monitorAsciiImages : ({}))

    implicitWidth: 1000
    implicitHeight: 660

    signal closeRequested()
    signal settingsUpdated(var newSettings)
    signal themeUpdated(var newTheme)

    function toggleMaximizeModal() {
        if (!editorRoot.parent) return;
        if (!maximizedModal) {
            savedModalRect = Qt.rect(editorRoot.x, editorRoot.y, editorRoot.width, editorRoot.height);
            editorRoot.x = 12;
            editorRoot.y = 34;
            editorRoot.width = Math.max(760, editorRoot.parent.width - 24);
            editorRoot.height = Math.max(500, editorRoot.parent.height - 56);
            maximizedModal = true;
        } else {
            editorRoot.width = Math.min(savedModalRect.width || 1000, editorRoot.parent.width - 40);
            editorRoot.height = Math.min(savedModalRect.height || 660, editorRoot.parent.height - 60);
            editorRoot.x = Math.round((editorRoot.parent.width - editorRoot.width) / 2);
            editorRoot.y = Math.round((editorRoot.parent.height - editorRoot.height) / 2);
            maximizedModal = false;
        }
    }

    function syncDraftFromProps() {
        draftTiles = cloneTiles((settings && settings.bgLayoutTiles) ? settings.bgLayoutTiles : []);
        draftMonitorBgs = cloneMap((theme && theme.monitorBackgrounds) ? theme.monitorBackgrounds : ({}));
        draftMonitorImages = cloneMap((settings && settings.monitorAsciiImages) ? settings.monitorAsciiImages : ({}));
        if (availableMonitors && availableMonitors.length > 0) {
            var found = false;
            for (var i = 0; i < availableMonitors.length; i++) {
                if (availableMonitors[i] && String(availableMonitors[i].name) === selectedMonitorName) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                selectedMonitorName = String(availableMonitors[0].name || "primary");
            }
        }
        autoSelectFirstTileOnMonitor();
    }

    function tilesForMonitor(monName) {
        var out = [];
        for (var i = 0; i < draftTiles.length; i++) {
            if (draftTiles[i] && String(draftTiles[i].monitor) === monName) {
                out.push(draftTiles[i]);
            }
        }
        return out;
    }

    function autoSelectFirstTileOnMonitor() {
        var list = tilesForMonitor(selectedMonitorName);
        if (list.length === 0) {
            selectedTileId = "";
            return;
        }
        for (var i = 0; i < list.length; i++) {
            if (String(list[i].id) === selectedTileId) return;
        }
        selectedTileId = String(list[0].id);
    }

    onAvailableMonitorsChanged: {
        if (availableMonitors && availableMonitors.length > 0) {
            var found = false;
            for (var i = 0; i < availableMonitors.length; i++) {
                if (availableMonitors[i] && String(availableMonitors[i].name) === selectedMonitorName) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                selectedMonitorName = String(availableMonitors[0].name || "primary");
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            syncDraftFromProps();
        }
    }

    color: theme.panelBg
    border.color: theme.accent
    border.width: 2
    focus: true

    Keys.onEscapePressed: (event) => {
        editorRoot.closeRequested();
        event.accepted = true;
    }
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            editorRoot.closeRequested();
            event.accepted = true;
        }
    }

    TapHandler {
        onTapped: editorRoot.forceActiveFocus()
    }

    function defaultSettings() {
        return {
            bgTerminalEnabled: false,
            bgTerminalCmd: "asciiquarium",
            bgTerminalInteractive: false,
            bgTerminalFontSize: 11,
            bgTerminalOpacity: 0.0,
            bgTerminalMatchGrid: true,
            bgLayoutTiles: [],
            monitorAsciiImages: ({})
        };
    }

    function cloneMap(src) {
        var out = {};
        if (!src || typeof src !== "object") return out;
        for (var k in src) {
            if (Object.prototype.hasOwnProperty.call(src, k)) {
                var val = src[k];
                if (val && typeof val === "object" && !Array.isArray(val)) {
                    out[k] = cloneMap(val);
                } else {
                    out[k] = val;
                }
            }
        }
        return out;
    }

    function cloneTiles(src) {
        var out = [];
        if (!Array.isArray(src)) return out;
        for (var i = 0; i < src.length; i++) {
            var t = src[i];
            if (!t || typeof t !== "object") continue;
            var c = {};
            for (var k in t) {
                if (Object.prototype.hasOwnProperty.call(t, k)) {
                    c[k] = t[k];
                }
            }
            out.push(c);
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

    function currentMonitor() {
        if (!availableMonitors || availableMonitors.length === 0) {
            return { name: selectedMonitorName, width: 1920, height: 1080 };
        }
        for (var i = 0; i < availableMonitors.length; i++) {
            var m = availableMonitors[i];
            if (m && String(m.name) === selectedMonitorName) return m;
        }
        return availableMonitors[0];
    }

    function monWidth() {
        var m = currentMonitor();
        return Number(m.width || 1920);
    }

    function monHeight() {
        var m = currentMonitor();
        return Number(m.height || 1080);
    }

    function selectedTile() {
        if (!selectedTileId) return null;
        for (var i = 0; i < draftTiles.length; i++) {
            if (String(draftTiles[i].id) === selectedTileId) return draftTiles[i];
        }
        return null;
    }

    function updateTile(tileId, key, val) {
        var next = [];
        for (var i = 0; i < draftTiles.length; i++) {
            var t = draftTiles[i];
            if (String(t.id) === tileId) {
                var c = {};
                for (var k in t) c[k] = t[k];
                c[key] = val;
                next.push(c);
            } else {
                next.push(t);
            }
        }
        draftTiles = next;
    }

    function removeTile(tileId) {
        var next = [];
        for (var i = 0; i < draftTiles.length; i++) {
            if (String(draftTiles[i].id) !== tileId) next.push(draftTiles[i]);
        }
        draftTiles = next;
        if (selectedTileId === tileId) selectedTileId = "";
        statusMessage = "Tile removed.";
    }

    function addTile(kind, autoApply) {
        var mw = monWidth();
        var mh = monHeight();
        var tw = Math.min(880, Math.round(mw * 0.65));
        var th = Math.min(520, Math.round(mh * 0.55));
        var id = "tile-" + Date.now();
        var newTile = {
            id: id,
            kind: kind || "terminal",
            monitor: selectedMonitorName,
            x: Math.max(0, Math.round((mw - tw) / 2)),
            y: Math.max(26, Math.round(26 + (mh - 26 - th) / 2)),
            width: tw,
            height: th,
            enabled: true,
            cmd: "asciiquarium",
            interactive: false,
            fontSize: 11,
            opacity: 0.0,
            matchGrid: true,
            imagePath: "",
            charset: "blocks",
            colorMode: "colored",
            fitMode: "fit",
            invert: false
        };
        var next = cloneTiles(draftTiles);
        next.push(newTile);
        draftTiles = next;
        selectedTileId = id;
        var m = cloneMap(draftMonitorBgs);
        if (!m[selectedMonitorName]) {
            m[selectedMonitorName] = (kind === "ascii_image") ? "ascii_image" : "terminal";
            draftMonitorBgs = m;
        }
        statusMessage = "Added " + (kind === "ascii_image" ? "Image->ASCII" : "Terminal") + " tile on " + selectedMonitorName + ".";
        if (autoApply) saveAndApply(false);
    }

    function ensureTerminalTileOnMonitor() {
        var list = tilesForMonitor(selectedMonitorName);
        for (var i = 0; i < list.length; i++) {
            if (list[i].kind === "terminal" || !list[i].kind) {
                selectedTileId = String(list[i].id);
                return;
            }
        }
        addTile("terminal", false);
    }

    function applyPreset(presetType) {
        var mw = monWidth();
        var mh = monHeight();
        var topOff = 26;
        var usableH = Math.max(160, mh - topOff);
        var stamp = Date.now();
        var next = [];
        // Keep tiles belonging to other monitors
        for (var i = 0; i < draftTiles.length; i++) {
            if (String(draftTiles[i].monitor) !== selectedMonitorName) {
                next.push(draftTiles[i]);
            }
        }

        var firstNewId = "";
        if (presetType === "split_lr") {
            var hw = Math.round(mw / 2);
            firstNewId = "tile-" + stamp + "-1";
            next.push({
                id: firstNewId,
                kind: "terminal",
                monitor: selectedMonitorName,
                x: 0,
                y: topOff,
                width: hw,
                height: usableH,
                enabled: true,
                cmd: "asciiquarium",
                interactive: false,
                fontSize: 11,
                opacity: 0.0,
                matchGrid: true,
                imagePath: "",
                charset: "blocks",
                colorMode: "colored",
                fitMode: "fit",
                invert: false
            });
            next.push({
                id: "tile-" + stamp + "-2",
                kind: "terminal",
                monitor: selectedMonitorName,
                x: hw,
                y: topOff,
                width: mw - hw,
                height: usableH,
                enabled: true,
                cmd: "htop",
                interactive: false,
                fontSize: 11,
                opacity: 0.0,
                matchGrid: true,
                imagePath: "",
                charset: "blocks",
                colorMode: "colored",
                fitMode: "fit",
                invert: false
            });
        } else if (presetType === "grid2x2") {
            var ghw = Math.round(mw / 2);
            var ghh = Math.round(usableH / 2);
            var cmds = ["asciiquarium", "cmatrix", "htop", "cava"];
            for (var r = 0; r < 2; r++) {
                for (var c = 0; c < 2; c++) {
                    var idx = r * 2 + c;
                    var tid = "tile-" + stamp + "-" + (idx + 1);
                    if (!firstNewId) firstNewId = tid;
                    next.push({
                        id: tid,
                        kind: "terminal",
                        monitor: selectedMonitorName,
                        x: c * ghw,
                        y: topOff + r * ghh,
                        width: (c === 0 ? ghw : mw - ghw),
                        height: (r === 0 ? ghh : usableH - ghh),
                        enabled: true,
                        cmd: cmds[idx] || "asciiquarium",
                        interactive: false,
                        fontSize: 10,
                        opacity: 0.0,
                        matchGrid: true,
                        imagePath: "",
                        charset: "blocks",
                        colorMode: "colored",
                        fitMode: "fit",
                        invert: false
                    });
                }
            }
        } else if (presetType === "main_stack") {
            var leftW = Math.round(mw * 0.62);
            var rightW = mw - leftW;
            var mhh = Math.round(usableH / 2);
            firstNewId = "tile-" + stamp + "-main";
            next.push({
                id: firstNewId,
                kind: "terminal",
                monitor: selectedMonitorName,
                x: 0,
                y: topOff,
                width: leftW,
                height: usableH,
                enabled: true,
                cmd: "asciiquarium",
                interactive: false,
                fontSize: 11,
                opacity: 0.0,
                matchGrid: true,
                imagePath: "",
                charset: "blocks",
                colorMode: "colored",
                fitMode: "fit",
                invert: false
            });
            next.push({
                id: "tile-" + stamp + "-top",
                kind: "terminal",
                monitor: selectedMonitorName,
                x: leftW,
                y: topOff,
                width: rightW,
                height: mhh,
                enabled: true,
                cmd: "htop",
                interactive: false,
                fontSize: 10,
                opacity: 0.0,
                matchGrid: true,
                imagePath: "",
                charset: "blocks",
                colorMode: "colored",
                fitMode: "fit",
                invert: false
            });
            next.push({
                id: "tile-" + stamp + "-bot",
                kind: "terminal",
                monitor: selectedMonitorName,
                x: leftW,
                y: topOff + mhh,
                width: rightW,
                height: usableH - mhh,
                enabled: true,
                cmd: "cava",
                interactive: false,
                fontSize: 10,
                opacity: 0.0,
                matchGrid: true,
                imagePath: "",
                charset: "blocks",
                colorMode: "colored",
                fitMode: "fit",
                invert: false
            });
        } else if (presetType === "center_box") {
            var cw = Math.min(900, Math.round(mw * 0.72));
            var ch = Math.min(520, Math.round(usableH * 0.68));
            firstNewId = "tile-" + stamp + "-box";
            next.push({
                id: firstNewId,
                kind: "terminal",
                monitor: selectedMonitorName,
                x: Math.max(0, Math.round((mw - cw) / 2)),
                y: topOff + Math.max(0, Math.round((usableH - ch) / 2)),
                width: cw,
                height: ch,
                enabled: true,
                cmd: "asciiquarium",
                interactive: false,
                fontSize: 11,
                opacity: 0.0,
                matchGrid: true,
                imagePath: "",
                charset: "blocks",
                colorMode: "colored",
                fitMode: "fit",
                invert: false
            });
        } else if (presetType === "full" || presetType === "fullscreen") {
            firstNewId = "tile-" + stamp + "-full";
            next.push({
                id: firstNewId,
                kind: "terminal",
                monitor: selectedMonitorName,
                x: 0,
                y: topOff,
                width: mw,
                height: usableH,
                enabled: true,
                cmd: "asciiquarium",
                interactive: false,
                fontSize: 11,
                opacity: 0.0,
                matchGrid: true,
                imagePath: "",
                charset: "blocks",
                colorMode: "colored",
                fitMode: "fit",
                invert: false
            });
        }
        var m = cloneMap(draftMonitorBgs);
        m[selectedMonitorName] = "terminal";
        draftMonitorBgs = m;
        draftTiles = next;
        selectedTileId = firstNewId;
        statusMessage = "Applied '" + presetType + "' live on " + selectedMonitorName + ".";
        saveAndApply(false);
    }

    function saveAndApply(closeAfter) {
        var nextCfg = {};
        for (var k in settings) {
            if (Object.prototype.hasOwnProperty.call(settings, k)) nextCfg[k] = settings[k];
        }
        nextCfg.bgLayoutTiles = draftTiles;
        nextCfg.monitorAsciiImages = draftMonitorImages;
        nextCfg.bgTerminalEnabled = draftTiles.some((t) => t && t.enabled && t.kind === "terminal");

        var nextTheme = {};
        for (var tk in theme) {
            if (Object.prototype.hasOwnProperty.call(theme, tk)) nextTheme[tk] = theme[tk];
        }
        nextTheme.monitorBackgrounds = draftMonitorBgs;

        settingsUpdated(nextCfg);
        themeUpdated(nextTheme);

        callBackend(["settings", "set", JSON.stringify(nextCfg)], "bg_settings_set");
        callBackend(["theme", "custom", JSON.stringify(nextTheme)], "bg_theme_set");

        statusMessage = "Saved & applied background layout across all monitors.";
        if (closeAfter) {
            editorRoot.closeRequested();
        }
    }

    // Image file picker dialog
    FileDialog {
        id: imageFileDialog
        title: "Select Image for ASCII Background Conversion"
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.webp *.gif *.bmp *.svg)", "All files (*)"]
        property string targetTileId: ""
        property bool isMonitorBg: false

        onAccepted: {
            var raw = String(selectedFile);
            var cleanPath = raw.replace(/^file:\/\//, "");
            if (isMonitorBg) {
                var cur = editorRoot.draftMonitorImages[editorRoot.selectedMonitorName] || {};
                var copy = {};
                for (var k in cur) copy[k] = cur[k];
                copy.imagePath = cleanPath;
                if (!copy.charset) copy.charset = "blocks";
                if (!copy.colorMode) copy.colorMode = "colored";
                if (!copy.fitMode) copy.fitMode = "fit";
                var mapCopy = editorRoot.cloneMap(editorRoot.draftMonitorImages);
                mapCopy[editorRoot.selectedMonitorName] = copy;
                editorRoot.draftMonitorImages = mapCopy;
                editorRoot.statusMessage = "Set image for " + editorRoot.selectedMonitorName + ": " + cleanPath;
                editorRoot.saveAndApply(false);
            } else if (targetTileId) {
                editorRoot.updateTile(targetTileId, "imagePath", cleanPath);
                editorRoot.statusMessage = "Updated tile image path: " + cleanPath;
                editorRoot.saveAndApply(false);
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
                drag.target: editorRoot
                drag.minimumX: -editorRoot.width + 120
                drag.maximumX: (editorRoot.parent ? editorRoot.parent.width : 1920) - 120
                drag.minimumY: 28
                drag.maximumY: (editorRoot.parent ? editorRoot.parent.height : 1080) - 40
                onPressed: editorRoot.forceActiveFocus()
                onDoubleClicked: {
                    if (editorRoot.parent) {
                        editorRoot.x = Math.round((editorRoot.parent.width - editorRoot.width) / 2);
                        editorRoot.y = Math.round((editorRoot.parent.height - editorRoot.height) / 2);
                    }
                }
            }

            RowLayout {
                anchors.fill: parent
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.family: editorRoot.monoFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: editorRoot.theme.accent
                    text: "┌─[ WALLPAPER & LIVE TERMINAL STUDIO ]────────────────────────────┐"
                }

                Rectangle {
                    z: 2
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 22
                    color: maxEdMa.containsMouse ? editorRoot.theme.accent : editorRoot.theme.bg
                    border.color: editorRoot.theme.accent
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        font.family: editorRoot.monoFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: maxEdMa.containsMouse ? editorRoot.theme.bg : editorRoot.theme.accent
                        text: editorRoot.maximizedModal ? "[❐]" : "[□]"
                    }

                    MouseArea {
                        id: maxEdMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: editorRoot.toggleMaximizeModal()
                    }
                }

                Rectangle {
                    z: 2
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 22
                    color: closeEdMa.containsMouse ? editorRoot.theme.danger : editorRoot.theme.bg
                    border.color: editorRoot.theme.danger
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        font.family: editorRoot.monoFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: closeEdMa.containsMouse ? editorRoot.theme.bg : editorRoot.theme.danger
                        text: "[✕]"
                    }

                    MouseArea {
                        id: closeEdMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: editorRoot.closeRequested()
                    }
                }
            }
        }

        // Monitor Selector Tabs Row
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                font.family: editorRoot.monoFamily
                font.pixelSize: 11
                font.bold: true
                color: editorRoot.theme.accent
                text: "MONITOR:"
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: (editorRoot.availableMonitors && editorRoot.availableMonitors.length > 0)
                           ? editorRoot.availableMonitors
                           : [{ name: "primary", width: 1920, height: 1080 }]

                    delegate: Rectangle {
                        id: monTab
                        required property var modelData
                        readonly property string monName: String(modelData.name || "Output")
                        readonly property bool active: editorRoot.selectedMonitorName === monName
                        readonly property string currentStyle: (editorRoot.draftMonitorBgs && typeof editorRoot.draftMonitorBgs[monName] === "string" && editorRoot.draftMonitorBgs[monName])
                                                               ? String(editorRoot.draftMonitorBgs[monName])
                                                               : "global"
                        readonly property int tileCount: {
                            var c = 0;
                            for (var i = 0; i < editorRoot.draftTiles.length; i++) {
                                if (String(editorRoot.draftTiles[i].monitor) === monName) c++;
                            }
                            return c;
                        }

                        implicitWidth: tabTxt.implicitWidth + 14
                        implicitHeight: 26
                        color: active ? editorRoot.theme.accent : (tabMa.containsMouse ? editorRoot.theme.gridDot : editorRoot.theme.bg)
                        border.color: active ? editorRoot.theme.accent : editorRoot.theme.muted
                        border.width: 1

                        Text {
                            id: tabTxt
                            anchors.centerIn: parent
                            font.family: editorRoot.monoFamily
                            font.pixelSize: 11
                            font.bold: monTab.active
                            color: monTab.active ? editorRoot.theme.bg : editorRoot.theme.fg
                            text: "[" + monTab.monName + " · " + monTab.currentStyle.toUpperCase() + (monTab.tileCount > 0 ? (" (" + monTab.tileCount + ")") : "") + "]"
                        }

                        MouseArea {
                            id: tabMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                editorRoot.selectedMonitorName = monTab.monName;
                                editorRoot.autoSelectFirstTileOnMonitor();
                            }
                        }
                    }
                }
            }

            Text {
                font.family: editorRoot.monoFamily
                font.pixelSize: 11
                color: editorRoot.theme.muted
                text: editorRoot.monWidth() + "×" + editorRoot.monHeight()
            }
        }

        // Main Body: Left 2D Canvas + Right Inspector
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            // Left Pane: 2D Monitor Canvas + Two-Row Action & Preset Toolbar
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 56
                Layout.minimumWidth: 360
                Layout.fillHeight: true
                spacing: 6

                // 2D Monitor Preview Canvas Box
                Rectangle {
                    id: canvasOuter
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: editorRoot.theme.bg
                    border.color: editorRoot.theme.muted
                    border.width: 1
                    clip: true

                    readonly property real monW: editorRoot.monWidth()
                    readonly property real monH: editorRoot.monHeight()
                    readonly property real scaleFactor: Math.min((canvasOuter.width - 24) / Math.max(1, monW), (canvasOuter.height - 24) / Math.max(1, monH))

                    // Scaled monitor boundary
                    Rectangle {
                        id: monRect
                        width: Math.max(60, Math.round(canvasOuter.monW * canvasOuter.scaleFactor))
                        height: Math.max(40, Math.round(canvasOuter.monH * canvasOuter.scaleFactor))
                        anchors.centerIn: parent
                        color: editorRoot.theme.panelBg
                        border.color: editorRoot.theme.accent
                        border.width: 2
                        clip: true

                        // Dotted grid texture indicator
                        Repeater {
                            model: Math.min(60, Math.round(monRect.width / 24))
                            delegate: Item {
                                required property int index
                                x: index * 24 + 12
                                y: 0
                                width: 1
                                height: monRect.height

                                Repeater {
                                    model: Math.min(40, Math.round(monRect.height / 24))
                                    delegate: Text {
                                        required property int index
                                        y: index * 24 + 12
                                        font.family: editorRoot.monoFamily
                                        font.pixelSize: 8
                                        color: editorRoot.theme.gridDot
                                        text: "·"
                                    }
                                }
                            }
                        }

                        // Top bar reserve zone (26px scaled)
                        Rectangle {
                            width: parent.width
                            height: Math.max(4, Math.round(26 * canvasOuter.scaleFactor))
                            color: editorRoot.theme.accent
                            opacity: 0.22
                            clip: true

                            Text {
                                visible: parent.height >= 9
                                anchors.centerIn: parent
                                font.family: editorRoot.monoFamily
                                font.pixelSize: 8
                                color: editorRoot.theme.accent
                                text: "[ TOP PANEL AREA ]"
                            }
                        }

                        // Monitor center label
                        Text {
                            anchors.centerIn: parent
                            font.family: editorRoot.monoFamily
                            font.pixelSize: 14
                            font.bold: true
                            color: editorRoot.theme.gridDot
                            text: editorRoot.selectedMonitorName + "\n" + canvasOuter.monW + "×" + canvasOuter.monH
                            horizontalAlignment: Text.AlignHCenter
                        }

                        // Tiles on this monitor
                        Repeater {
                            model: editorRoot.draftTiles

                            delegate: Rectangle {
                                id: tileBox
                                required property var modelData
                                readonly property bool onThisMon: String(modelData.monitor) === editorRoot.selectedMonitorName
                                readonly property bool isSelected: editorRoot.selectedTileId === String(modelData.id)

                                visible: onThisMon
                                x: Math.round(Number(modelData.x || 0) * canvasOuter.scaleFactor)
                                y: Math.round(Number(modelData.y || 26) * canvasOuter.scaleFactor)
                                width: Math.max(20, Math.round(Number(modelData.width || 400) * canvasOuter.scaleFactor))
                                height: Math.max(16, Math.round(Number(modelData.height || 300) * canvasOuter.scaleFactor))

                                color: isSelected ? "#2a2415" : (modelData.kind === "ascii_image" ? "#141c22" : "#181a1d")
                                border.color: isSelected ? editorRoot.theme.accent : (tileMa.containsMouse ? editorRoot.theme.secondary : editorRoot.theme.snapLine)
                                border.width: isSelected ? 2 : 1
                                z: isSelected ? 10 : 2

                                ColumnLayout {
                                    anchors { fill: parent; margins: 4 }
                                    spacing: 2
                                    clip: true

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Text {
                                            font.family: editorRoot.monoFamily
                                            font.pixelSize: 9
                                            font.bold: true
                                            color: tileBox.modelData.kind === "ascii_image" ? editorRoot.theme.secondary : editorRoot.theme.accent
                                            text: tileBox.modelData.kind === "ascii_image" ? "[IMG]" : "[TERM]"
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            font.family: editorRoot.monoFamily
                                            font.pixelSize: 9
                                            color: editorRoot.theme.fg
                                            text: tileBox.modelData.kind === "ascii_image"
                                                  ? (tileBox.modelData.imagePath ? tileBox.modelData.imagePath.split("/").pop() : "(no image)")
                                                  : (tileBox.modelData.cmd || "asciiquarium")
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        font.family: editorRoot.monoFamily
                                        font.pixelSize: 8
                                        color: editorRoot.theme.muted
                                        text: Math.round(tileBox.modelData.width) + "×" + Math.round(tileBox.modelData.height) + " px · ~" +
                                              Math.round(tileBox.modelData.width / Math.max(6, (tileBox.modelData.fontSize || 11) * 0.6)) + "×" +
                                              Math.round(tileBox.modelData.height / Math.max(8, (tileBox.modelData.fontSize || 11) * 1.3)) + " cells"
                                    }
                                }

                                // Interactive Drag Area
                                MouseArea {
                                    id: tileMa
                                    anchors.fill: parent
                                    cursorShape: Qt.SizeAllCursor
                                    drag.target: tileBox
                                    drag.minimumX: 0
                                    drag.maximumX: Math.max(0, monRect.width - tileBox.width)
                                    drag.minimumY: Math.round(26 * canvasOuter.scaleFactor)
                                    drag.maximumY: Math.max(0, monRect.height - tileBox.height)

                                    onPressed: {
                                        editorRoot.selectedTileId = String(tileBox.modelData.id);
                                    }

                                    onReleased: {
                                        var rawX = Math.round(tileBox.x / canvasOuter.scaleFactor);
                                        var rawY = Math.round(tileBox.y / canvasOuter.scaleFactor);
                                        // Snap to edges
                                        if (rawX < 24) rawX = 0;
                                        if (rawY < 32) rawY = 26;
                                        var mw = editorRoot.monWidth();
                                        var mh = editorRoot.monHeight();
                                        if (Math.abs(rawX + tileBox.modelData.width - mw) < 24) rawX = mw - tileBox.modelData.width;
                                        if (Math.abs(rawY + tileBox.modelData.height - mh) < 24) rawY = mh - tileBox.modelData.height;

                                        editorRoot.updateTile(String(tileBox.modelData.id), "x", rawX);
                                        editorRoot.updateTile(String(tileBox.modelData.id), "y", rawY);
                                    }
                                }

                                // Bottom-Right Corner Resize Handle
                                Rectangle {
                                    width: 10
                                    height: 10
                                    anchors { right: parent.right; bottom: parent.bottom }
                                    color: tileBox.isSelected ? editorRoot.theme.accent : editorRoot.theme.muted
                                    z: 12

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.SizeFDiagCursor
                                        property real startW: 0
                                        property real startH: 0
                                        property real startX: 0
                                        property real startY: 0

                                        onPressed: (mouse) => {
                                            editorRoot.selectedTileId = String(tileBox.modelData.id);
                                            startW = tileBox.width;
                                            startH = tileBox.height;
                                            startX = mouse.x;
                                            startY = mouse.y;
                                        }

                                        onPositionChanged: (mouse) => {
                                            var dw = (mouse.x - startX) / canvasOuter.scaleFactor;
                                            var dh = (mouse.y - startY) / canvasOuter.scaleFactor;
                                            var nw = Math.max(160, Math.round(Number(tileBox.modelData.width || 400) + dw));
                                            var nh = Math.max(100, Math.round(Number(tileBox.modelData.height || 300) + dh));
                                            editorRoot.updateTile(String(tileBox.modelData.id), "width", nw);
                                            editorRoot.updateTile(String(tileBox.modelData.id), "height", nh);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Toolbar Row 1: Add Tile + Clear Monitor
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        implicitWidth: addTermTxt.implicitWidth + 14
                        implicitHeight: 26
                        color: addTermMa.containsMouse ? editorRoot.theme.accent : editorRoot.theme.bg
                        border.color: editorRoot.theme.accent
                        border.width: 1

                        Text {
                            id: addTermTxt
                            anchors.centerIn: parent
                            font.family: editorRoot.monoFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: addTermMa.containsMouse ? editorRoot.theme.bg : editorRoot.theme.accent
                            text: "[ + Add Live Terminal ]"
                        }
                        MouseArea {
                            id: addTermMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: editorRoot.addTile("terminal", true)
                        }
                    }

                    Rectangle {
                        implicitWidth: addImgTxt.implicitWidth + 14
                        implicitHeight: 26
                        color: addImgMa.containsMouse ? editorRoot.theme.secondary : editorRoot.theme.bg
                        border.color: editorRoot.theme.secondary
                        border.width: 1

                        Text {
                            id: addImgTxt
                            anchors.centerIn: parent
                            font.family: editorRoot.monoFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: addImgMa.containsMouse ? editorRoot.theme.bg : editorRoot.theme.secondary
                            text: "[ + Add ASCII Image ]"
                        }
                        MouseArea {
                            id: addImgMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: editorRoot.addTile("ascii_image", false)
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        implicitWidth: clrTxt.implicitWidth + 12
                        implicitHeight: 26
                        color: clrMa.containsMouse ? editorRoot.theme.danger : "transparent"
                        border.color: editorRoot.theme.danger
                        border.width: 1

                        Text {
                            id: clrTxt
                            anchors.centerIn: parent
                            font.family: editorRoot.monoFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: clrMa.containsMouse ? editorRoot.theme.bg : editorRoot.theme.danger
                            text: "[ Clear Tiles ]"
                        }
                        MouseArea {
                            id: clrMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var next = [];
                                for (var i = 0; i < editorRoot.draftTiles.length; i++) {
                                    if (String(editorRoot.draftTiles[i].monitor) !== editorRoot.selectedMonitorName) {
                                        next.push(editorRoot.draftTiles[i]);
                                    }
                                }
                                editorRoot.draftTiles = next;
                                editorRoot.selectedTileId = "";
                                editorRoot.saveAndApply(false);
                                editorRoot.statusMessage = "Cleared tiles on " + editorRoot.selectedMonitorName + ".";
                            }
                        }
                    }
                }

                // Toolbar Row 2: 1-Click Live Terminal Layout Presets
                Flow {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        height: 24
                        verticalAlignment: Text.AlignVCenter
                        font.family: editorRoot.monoFamily
                        font.pixelSize: 10
                        font.bold: true
                        color: editorRoot.theme.muted
                        text: "1-CLICK PRESETS:"
                    }

                    Repeater {
                        model: [
                            { id: "center_box", label: "[ Center Box ]" },
                            { id: "fullscreen", label: "[ Fullscreen ]" },
                            { id: "split_lr",   label: "[ Split L|R ]" },
                            { id: "main_stack", label: "[ Main+Stack ]" },
                            { id: "grid2x2",    label: "[ 2x2 Grid ]" }
                        ]

                        delegate: Rectangle {
                            id: preDel
                            required property var modelData
                            implicitWidth: preTxt.implicitWidth + 10
                            implicitHeight: 24
                            color: preMa.containsMouse ? editorRoot.theme.gridDot : editorRoot.theme.panelBg
                            border.color: preMa.containsMouse ? editorRoot.theme.accent : editorRoot.theme.muted
                            border.width: 1

                            Text {
                                id: preTxt
                                anchors.centerIn: parent
                                font.family: editorRoot.monoFamily
                                font.pixelSize: 10
                                color: preMa.containsMouse ? editorRoot.theme.accent : editorRoot.theme.fg
                                text: preDel.modelData.label
                            }
                            MouseArea {
                                id: preMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: editorRoot.applyPreset(preDel.modelData.id)
                            }
                        }
                    }
                }
            }

            // Right Pane: Inspector Panel
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredWidth: 44
                Layout.minimumWidth: 320
                Layout.maximumWidth: 460
                Layout.fillHeight: true
                color: editorRoot.theme.bg
                border.color: editorRoot.theme.muted
                border.width: 1
                clip: true

                Flickable {
                    id: rightPaneScroll
                    anchors { fill: parent; margins: 8 }
                    contentWidth: width
                    contentHeight: rightPaneCol.implicitHeight
                    clip: true
                    QQC2.ScrollBar.vertical: QQC2.ScrollBar { }

                    ColumnLayout {
                        id: rightPaneCol
                        width: parent.width
                        spacing: 8

                        // Section 1: Monitor Background Style
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: sec1Col.implicitHeight + 12
                            color: editorRoot.theme.panelBg
                            border.color: editorRoot.theme.muted
                            border.width: 1

                            ColumnLayout {
                                id: sec1Col
                                anchors { fill: parent; margins: 6 }
                                spacing: 6

                                Text {
                                    font.family: editorRoot.monoFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: editorRoot.theme.accent
                                    text: "1. " + editorRoot.selectedMonitorName + " BACKGROUND STYLE"
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    columnSpacing: 4
                                    rowSpacing: 4

                                    Repeater {
                                        model: [
                                            { id: "inherit",        label: "[ Follow Global ]" },
                                            { id: "ascii_grid",     label: "[ ASCII Grid ]" },
                                            { id: "terminal",       label: "[ Live Terminal ]" },
                                            { id: "ascii_image",    label: "[ Image -> ASCII ]" },
                                            { id: "christmas_tree", label: "[ Christmas Tree ]" },
                                            { id: "newsboard",      label: "[ Newsboard ]" },
                                            { id: "visualizer",     label: "[ Visualizer ]" },
                                            { id: "snaptic_void",   label: "[ SNAPTIC Void ]" }
                                        ]

                                        delegate: Rectangle {
                                            id: bgPill
                                            required property var modelData
                                            readonly property string curSt: (editorRoot.draftMonitorBgs && editorRoot.draftMonitorBgs[editorRoot.selectedMonitorName])
                                                                            ? String(editorRoot.draftMonitorBgs[editorRoot.selectedMonitorName])
                                                                            : "inherit"
                                            readonly property bool active: curSt === modelData.id
                                            Layout.fillWidth: true
                                            height: 24
                                            color: active ? editorRoot.theme.accent : (bgPillMa.containsMouse ? editorRoot.theme.gridDot : editorRoot.theme.bg)
                                            border.color: active ? editorRoot.theme.accent : editorRoot.theme.muted
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                font.family: editorRoot.monoFamily
                                                font.pixelSize: 10
                                                font.bold: bgPill.active
                                                color: bgPill.active ? editorRoot.theme.bg : editorRoot.theme.fg
                                                text: bgPill.modelData.label
                                            }

                                            MouseArea {
                                                id: bgPillMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    var m = editorRoot.cloneMap(editorRoot.draftMonitorBgs);
                                                    if (bgPill.modelData.id === "inherit") {
                                                        delete m[editorRoot.selectedMonitorName];
                                                    } else {
                                                        m[editorRoot.selectedMonitorName] = bgPill.modelData.id;
                                                    }
                                                    editorRoot.draftMonitorBgs = m;
                                                    if (bgPill.modelData.id === "terminal") {
                                                        editorRoot.ensureTerminalTileOnMonitor();
                                                        editorRoot.saveAndApply(false);
                                                    } else {
                                                        editorRoot.saveAndApply(false);
                                                    }
                                                    editorRoot.statusMessage = "Set " + editorRoot.selectedMonitorName + " style to " + bgPill.modelData.label + ".";
                                                }
                                            }
                                        }
                                    }
                                }

                                // Full Monitor Image-to-ASCII Configuration (when style === "ascii_image")
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    visible: {
                                        var curSt = (editorRoot.draftMonitorBgs && editorRoot.draftMonitorBgs[editorRoot.selectedMonitorName])
                                                    ? String(editorRoot.draftMonitorBgs[editorRoot.selectedMonitorName])
                                                    : "inherit";
                                        return curSt === "ascii_image";
                                    }

                                    Text {
                                        font.family: editorRoot.monoFamily
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: editorRoot.theme.secondary
                                        text: "FULL-MONITOR IMAGE TO ASCII:"
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 24
                                            color: editorRoot.theme.bg
                                            border.color: editorRoot.theme.muted
                                            border.width: 1
                                            clip: true

                                            Text {
                                                anchors { fill: parent; margins: 4 }
                                                elide: Text.ElideMiddle
                                                font.family: editorRoot.monoFamily
                                                font.pixelSize: 10
                                                color: editorRoot.theme.fg
                                                text: {
                                                    var imgSpec = editorRoot.draftMonitorImages[editorRoot.selectedMonitorName];
                                                    return (imgSpec && imgSpec.imagePath) ? imgSpec.imagePath : "(click Browse to pick image...)";
                                                }
                                            }
                                        }

                                        Rectangle {
                                            implicitWidth: browseTxt.implicitWidth + 8
                                            implicitHeight: 24
                                            color: browseMa.containsMouse ? editorRoot.theme.secondary : editorRoot.theme.bg
                                            border.color: editorRoot.theme.secondary
                                            border.width: 1

                                            Text {
                                                id: browseTxt
                                                anchors.centerIn: parent
                                                font.family: editorRoot.monoFamily
                                                font.pixelSize: 10
                                                color: browseMa.containsMouse ? editorRoot.theme.bg : editorRoot.theme.secondary
                                                text: "[ Browse... ]"
                                            }

                                            MouseArea {
                                                id: browseMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    imageFileDialog.isMonitorBg = true;
                                                    imageFileDialog.targetTileId = "";
                                                    imageFileDialog.open();
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Section 2: Selected Tile Inspector
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: sec2Col.implicitHeight + 12
                            color: editorRoot.theme.panelBg
                            border.color: editorRoot.selectedTileId ? editorRoot.theme.accent : editorRoot.theme.muted
                            border.width: 1

                            ColumnLayout {
                                id: sec2Col
                                anchors { fill: parent; margins: 6 }
                                spacing: 6

                                Text {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    font.family: editorRoot.monoFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: editorRoot.theme.accent
                                    text: "2. TILES ON " + editorRoot.selectedMonitorName + " (" + editorRoot.tilesForMonitor(editorRoot.selectedMonitorName).length + ")"
                                }

                                // Selectable tile switcher pills for active monitor
                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    visible: editorRoot.tilesForMonitor(editorRoot.selectedMonitorName).length > 0

                                    Repeater {
                                        model: editorRoot.tilesForMonitor(editorRoot.selectedMonitorName)
                                        delegate: Rectangle {
                                            id: tilePillDel
                                            required property var modelData
                                            required property int index
                                            readonly property bool cur: editorRoot.selectedTileId === String(modelData.id)
                                            implicitWidth: tilePillTxt.implicitWidth + 10
                                            implicitHeight: 22
                                            color: cur ? editorRoot.theme.accent : editorRoot.theme.bg
                                            border.color: cur ? editorRoot.theme.accent : editorRoot.theme.muted
                                            border.width: 1

                                            Text {
                                                id: tilePillTxt
                                                anchors.centerIn: parent
                                                font.family: editorRoot.monoFamily
                                                font.pixelSize: 10
                                                font.bold: tilePillDel.cur
                                                color: tilePillDel.cur ? editorRoot.theme.bg : editorRoot.theme.fg
                                                text: "#" + (tilePillDel.index + 1) + " " + (tilePillDel.modelData.kind === "ascii_image"
                                                    ? (tilePillDel.modelData.imagePath ? tilePillDel.modelData.imagePath.split("/").pop() : "image")
                                                    : (tilePillDel.modelData.cmd || "term"))
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: editorRoot.selectedTileId = String(tilePillDel.modelData.id)
                                            }
                                        }
                                    }
                                }

                                ColumnLayout {
                                    visible: !editorRoot.selectedTileId
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Text {
                                        Layout.fillWidth: true
                                        font.family: editorRoot.monoFamily
                                        font.pixelSize: 11
                                        color: editorRoot.theme.muted
                                        wrapMode: Text.WordWrap
                                        text: "No tiles on " + editorRoot.selectedMonitorName + " yet.\nClick [+ Add Live Terminal] or pick a 1-Click Preset below the preview."
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }

                                ColumnLayout {
                                    id: tileFieldsCol
                                    visible: Boolean(editorRoot.selectedTileId)
                                    Layout.fillWidth: true
                                    spacing: 6

                                    readonly property var curTile: editorRoot.selectedTile()

                                    // Kind Selector & Enabled
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Rectangle {
                                            implicitWidth: termKindTxt.implicitWidth + 8
                                            implicitHeight: 22
                                            color: (tileFieldsCol.curTile && tileFieldsCol.curTile.kind === "terminal") ? editorRoot.theme.accent : editorRoot.theme.bg
                                            border.color: editorRoot.theme.accent
                                            border.width: 1

                                            Text {
                                                id: termKindTxt
                                                anchors.centerIn: parent
                                                font.family: editorRoot.monoFamily
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: (tileFieldsCol.curTile && tileFieldsCol.curTile.kind === "terminal") ? editorRoot.theme.bg : editorRoot.theme.accent
                                                text: "[ Terminal ]"
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: editorRoot.updateTile(editorRoot.selectedTileId, "kind", "terminal")
                                            }
                                        }

                                        Rectangle {
                                            implicitWidth: imgKindTxt.implicitWidth + 8
                                            implicitHeight: 22
                                            color: (tileFieldsCol.curTile && tileFieldsCol.curTile.kind === "ascii_image") ? editorRoot.theme.secondary : editorRoot.theme.bg
                                            border.color: editorRoot.theme.secondary
                                            border.width: 1

                                            Text {
                                                id: imgKindTxt
                                                anchors.centerIn: parent
                                                font.family: editorRoot.monoFamily
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: (tileFieldsCol.curTile && tileFieldsCol.curTile.kind === "ascii_image") ? editorRoot.theme.bg : editorRoot.theme.secondary
                                                text: "[ Image->ASCII ]"
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: editorRoot.updateTile(editorRoot.selectedTileId, "kind", "ascii_image")
                                            }
                                        }

                                        Item { Layout.fillWidth: true }

                                        Rectangle {
                                            implicitWidth: enbTxt.implicitWidth + 8
                                            implicitHeight: 22
                                            color: (tileFieldsCol.curTile && tileFieldsCol.curTile.enabled !== false) ? editorRoot.theme.accent : editorRoot.theme.bg
                                            border.color: editorRoot.theme.accent
                                            border.width: 1

                                            Text {
                                                id: enbTxt
                                                anchors.centerIn: parent
                                                font.family: editorRoot.monoFamily
                                                font.pixelSize: 10
                                                color: (tileFieldsCol.curTile && tileFieldsCol.curTile.enabled !== false) ? editorRoot.theme.bg : editorRoot.theme.muted
                                                text: (tileFieldsCol.curTile && tileFieldsCol.curTile.enabled !== false) ? "[ Enabled: YES ]" : "[ Enabled: NO ]"
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: editorRoot.updateTile(editorRoot.selectedTileId, "enabled", !(tileFieldsCol.curTile && tileFieldsCol.curTile.enabled !== false))
                                            }
                                        }
                                    }

                                    // Terminal specific fields
                                    ColumnLayout {
                                        visible: Boolean(tileFieldsCol.curTile && tileFieldsCol.curTile.kind === "terminal")
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Text {
                                            font.family: editorRoot.monoFamily
                                            font.pixelSize: 10
                                            color: editorRoot.theme.muted
                                            text: "COMMAND & ARGS:"
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 26
                                            color: editorRoot.theme.bg
                                            border.color: cmdInput.activeFocus ? editorRoot.theme.accent : editorRoot.theme.muted
                                            border.width: 1

                                            TextInput {
                                                id: cmdInput
                                                anchors { fill: parent; margins: 4 }
                                                font.family: editorRoot.monoFamily
                                                font.pixelSize: 11
                                                color: editorRoot.theme.fg
                                                text: (tileFieldsCol.curTile && tileFieldsCol.curTile.cmd) ? String(tileFieldsCol.curTile.cmd) : "asciiquarium"
                                                onTextEdited: {
                                                    if (editorRoot.selectedTileId) {
                                                        editorRoot.updateTile(editorRoot.selectedTileId, "cmd", text);
                                                    }
                                                }
                                                onAccepted: editorRoot.saveAndApply(false)
                                            }
                                        }

                                        // Preset Command Pills
                                        Flow {
                                            Layout.fillWidth: true
                                            spacing: 4
                                            Repeater {
                                                model: ["asciiquarium", "cmatrix", "agy-usage", "htop", "btop", "cava", "cbonsai -li", "fastfetch"]
                                                delegate: Rectangle {
                                                    id: cmdPill
                                                    required property string modelData
                                                    readonly property bool curCmd: tileFieldsCol.curTile && String(tileFieldsCol.curTile.cmd || "") === modelData
                                                    implicitWidth: cmdPillTxt.implicitWidth + 8
                                                    implicitHeight: 20
                                                    color: curCmd ? editorRoot.theme.secondary : (cmdPillMa.containsMouse ? editorRoot.theme.accent : editorRoot.theme.bg)
                                                    border.color: curCmd ? editorRoot.theme.secondary : editorRoot.theme.muted
                                                    border.width: 1

                                                    Text {
                                                        id: cmdPillTxt
                                                        anchors.centerIn: parent
                                                        font.family: editorRoot.monoFamily
                                                        font.pixelSize: 9
                                                        font.bold: cmdPill.curCmd
                                                        color: (cmdPill.curCmd || cmdPillMa.containsMouse) ? editorRoot.theme.bg : editorRoot.theme.secondary
                                                        text: cmdPill.modelData
                                                    }
                                                    MouseArea {
                                                        id: cmdPillMa
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            cmdInput.text = cmdPill.modelData;
                                                            editorRoot.updateTile(editorRoot.selectedTileId, "cmd", cmdPill.modelData);
                                                            editorRoot.saveAndApply(false);
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // Font Size & Dotted BG Blend & Interactive
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            Text {
                                                font.family: editorRoot.monoFamily
                                                font.pixelSize: 10
                                                color: editorRoot.theme.muted
                                                text: "Font: " + (tileFieldsCol.curTile ? (tileFieldsCol.curTile.fontSize || 11) : 11) + "px"
                                            }

                                            Rectangle {
                                                implicitWidth: 20
                                                implicitHeight: 20
                                                color: editorRoot.theme.bg
                                                border.color: editorRoot.theme.muted
                                                border.width: 1
                                                Text { anchors.centerIn: parent; font.family: editorRoot.monoFamily; font.pixelSize: 11; color: editorRoot.theme.fg; text: "-" }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    onClicked: {
                                                        var curFs = tileFieldsCol.curTile ? (tileFieldsCol.curTile.fontSize || 11) : 11;
                                                        editorRoot.updateTile(editorRoot.selectedTileId, "fontSize", Math.max(8, curFs - 1));
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                implicitWidth: 20
                                                implicitHeight: 20
                                                color: editorRoot.theme.bg
                                                border.color: editorRoot.theme.muted
                                                border.width: 1
                                                Text { anchors.centerIn: parent; font.family: editorRoot.monoFamily; font.pixelSize: 11; color: editorRoot.theme.fg; text: "+" }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    onClicked: {
                                                        var curFs = tileFieldsCol.curTile ? (tileFieldsCol.curTile.fontSize || 11) : 11;
                                                        editorRoot.updateTile(editorRoot.selectedTileId, "fontSize", Math.min(18, curFs + 1));
                                                    }
                                                }
                                            }

                                            Item { Layout.fillWidth: true }

                                            Rectangle {
                                                implicitWidth: blendTxt.implicitWidth + 8
                                                implicitHeight: 22
                                                color: (tileFieldsCol.curTile && tileFieldsCol.curTile.matchGrid !== false) ? editorRoot.theme.accent : editorRoot.theme.bg
                                                border.color: editorRoot.theme.accent
                                                border.width: 1

                                                Text {
                                                    id: blendTxt
                                                    anchors.centerIn: parent
                                                    font.family: editorRoot.monoFamily
                                                    font.pixelSize: 10
                                                    color: (tileFieldsCol.curTile && tileFieldsCol.curTile.matchGrid !== false) ? editorRoot.theme.bg : editorRoot.theme.muted
                                                    text: "[ Blend Dots: " + ((tileFieldsCol.curTile && tileFieldsCol.curTile.matchGrid !== false) ? "ON" : "OFF") + " ]"
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        var cur = tileFieldsCol.curTile ? (tileFieldsCol.curTile.matchGrid !== false) : true;
                                                        editorRoot.updateTile(editorRoot.selectedTileId, "matchGrid", !cur);
                                                    }
                                                }
                                            }
                                        }

                                        // Opacity Presets
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 4

                                            Text {
                                                font.family: editorRoot.monoFamily
                                                font.pixelSize: 10
                                                color: editorRoot.theme.muted
                                                text: "Opacity:"
                                            }

                                            Repeater {
                                                model: [
                                                    { val: 0.0,  label: "0% Dots" },
                                                    { val: 0.35, label: "35% Tint" },
                                                    { val: 0.75, label: "75% Pane" },
                                                    { val: 1.0,  label: "100% Solid" }
                                                ]
                                                delegate: Rectangle {
                                                    id: opacDel
                                                    required property var modelData
                                                    readonly property real curOp: tileFieldsCol.curTile ? Number(tileFieldsCol.curTile.opacity || 0.0) : 0.0
                                                    readonly property bool active: Math.abs(curOp - modelData.val) < 0.05
                                                    implicitWidth: opTxt.implicitWidth + 6
                                                    implicitHeight: 20
                                                    color: active ? editorRoot.theme.accent : editorRoot.theme.bg
                                                    border.color: active ? editorRoot.theme.accent : editorRoot.theme.muted
                                                    border.width: 1

                                                    Text {
                                                        id: opTxt
                                                        anchors.centerIn: parent
                                                        font.family: editorRoot.monoFamily
                                                        font.pixelSize: 9
                                                        color: opacDel.active ? editorRoot.theme.bg : editorRoot.theme.fg
                                                        text: opacDel.modelData.label
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            editorRoot.updateTile(editorRoot.selectedTileId, "opacity", opacDel.modelData.val);
                                                            editorRoot.saveAndApply(false);
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Image-to-ASCII specific fields
                                    ColumnLayout {
                                        visible: Boolean(tileFieldsCol.curTile && tileFieldsCol.curTile.kind === "ascii_image")
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Text {
                                            font.family: editorRoot.monoFamily
                                            font.pixelSize: 10
                                            color: editorRoot.theme.muted
                                            text: "IMAGE FILE:"
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 4

                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: 24
                                                color: editorRoot.theme.bg
                                                border.color: editorRoot.theme.muted
                                                border.width: 1
                                                clip: true

                                                TextInput {
                                                    anchors { fill: parent; margins: 4 }
                                                    font.family: editorRoot.monoFamily
                                                    font.pixelSize: 10
                                                    color: editorRoot.theme.fg
                                                    text: (tileFieldsCol.curTile && tileFieldsCol.curTile.imagePath) ? String(tileFieldsCol.curTile.imagePath) : ""
                                                    onTextEdited: {
                                                        if (editorRoot.selectedTileId) {
                                                            editorRoot.updateTile(editorRoot.selectedTileId, "imagePath", text);
                                                        }
                                                    }
                                                    onAccepted: editorRoot.saveAndApply(false)
                                                }
                                            }

                                            Rectangle {
                                                implicitWidth: bImgTxt.implicitWidth + 8
                                                implicitHeight: 24
                                                color: bImgMa.containsMouse ? editorRoot.theme.secondary : editorRoot.theme.bg
                                                border.color: editorRoot.theme.secondary
                                                border.width: 1

                                                Text {
                                                    id: bImgTxt
                                                    anchors.centerIn: parent
                                                    font.family: editorRoot.monoFamily
                                                    font.pixelSize: 10
                                                    color: bImgMa.containsMouse ? editorRoot.theme.bg : editorRoot.theme.secondary
                                                    text: "[ Browse... ]"
                                                }

                                                MouseArea {
                                                    id: bImgMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        imageFileDialog.isMonitorBg = false;
                                                        imageFileDialog.targetTileId = editorRoot.selectedTileId;
                                                        imageFileDialog.open();
                                                    }
                                                }
                                            }
                                        }

                                        // Charset & Color Mode & Fit
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            Text { font.family: editorRoot.monoFamily; font.pixelSize: 10; color: editorRoot.theme.muted; text: "Charset:" }

                                            Repeater {
                                                model: ["ascii", "blocks", "braille"]
                                                delegate: Rectangle {
                                                    id: chDel
                                                    required property string modelData
                                                    readonly property bool active: (tileFieldsCol.curTile && tileFieldsCol.curTile.charset === modelData)
                                                    implicitWidth: chTxt.implicitWidth + 6
                                                    implicitHeight: 20
                                                    color: active ? editorRoot.theme.secondary : editorRoot.theme.bg
                                                    border.color: active ? editorRoot.theme.secondary : editorRoot.theme.muted
                                                    border.width: 1

                                                    Text {
                                                        id: chTxt
                                                        anchors.centerIn: parent
                                                        font.family: editorRoot.monoFamily
                                                        font.pixelSize: 9
                                                        color: chDel.active ? editorRoot.theme.bg : editorRoot.theme.fg
                                                        text: chDel.modelData
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: editorRoot.updateTile(editorRoot.selectedTileId, "charset", chDel.modelData)
                                                    }
                                                }
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            Text { font.family: editorRoot.monoFamily; font.pixelSize: 10; color: editorRoot.theme.muted; text: "Color:" }

                                            Repeater {
                                                model: ["colored", "theme"]
                                                delegate: Rectangle {
                                                    id: colDel
                                                    required property string modelData
                                                    readonly property bool active: (tileFieldsCol.curTile && tileFieldsCol.curTile.colorMode === modelData)
                                                    implicitWidth: colTxt.implicitWidth + 6
                                                    implicitHeight: 20
                                                    color: active ? editorRoot.theme.secondary : editorRoot.theme.bg
                                                    border.color: active ? editorRoot.theme.secondary : editorRoot.theme.muted
                                                    border.width: 1

                                                    Text {
                                                        id: colTxt
                                                        anchors.centerIn: parent
                                                        font.family: editorRoot.monoFamily
                                                        font.pixelSize: 9
                                                        color: colDel.active ? editorRoot.theme.bg : editorRoot.theme.fg
                                                        text: colDel.modelData
                                                    }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: editorRoot.updateTile(editorRoot.selectedTileId, "colorMode", colDel.modelData)
                                                    }
                                                }
                                            }

                                            Item { Layout.fillWidth: true }

                                            Rectangle {
                                                implicitWidth: invTxt.implicitWidth + 6
                                                implicitHeight: 20
                                                color: (tileFieldsCol.curTile && tileFieldsCol.curTile.invert) ? editorRoot.theme.accent : editorRoot.theme.bg
                                                border.color: editorRoot.theme.accent
                                                border.width: 1

                                                Text {
                                                    id: invTxt
                                                    anchors.centerIn: parent
                                                    font.family: editorRoot.monoFamily
                                                    font.pixelSize: 9
                                                    color: (tileFieldsCol.curTile && tileFieldsCol.curTile.invert) ? editorRoot.theme.bg : editorRoot.theme.muted
                                                    text: "[ Invert: " + ((tileFieldsCol.curTile && tileFieldsCol.curTile.invert) ? "ON" : "OFF") + " ]"
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        var curInv = Boolean(tileFieldsCol.curTile && tileFieldsCol.curTile.invert);
                                                        editorRoot.updateTile(editorRoot.selectedTileId, "invert", !curInv);
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Geometry Readout & Actions
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Text {
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            font.family: editorRoot.monoFamily
                                            font.pixelSize: 10
                                            color: editorRoot.theme.muted
                                            text: "X:" + Math.round(tileFieldsCol.curTile ? tileFieldsCol.curTile.x : 0) +
                                                  " Y:" + Math.round(tileFieldsCol.curTile ? tileFieldsCol.curTile.y : 26) +
                                                  " W:" + Math.round(tileFieldsCol.curTile ? tileFieldsCol.curTile.width : 400) +
                                                  " H:" + Math.round(tileFieldsCol.curTile ? tileFieldsCol.curTile.height : 300)
                                        }

                                        Rectangle {
                                            implicitWidth: applyTileTxt.implicitWidth + 8
                                            implicitHeight: 22
                                            color: applyTileMa.containsMouse ? editorRoot.theme.secondary : editorRoot.theme.bg
                                            border.color: editorRoot.theme.secondary
                                            border.width: 1

                                            Text {
                                                id: applyTileTxt
                                                anchors.centerIn: parent
                                                font.family: editorRoot.monoFamily
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: applyTileMa.containsMouse ? editorRoot.theme.bg : editorRoot.theme.secondary
                                                text: "[✓ Apply]"
                                            }
                                            MouseArea {
                                                id: applyTileMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: editorRoot.saveAndApply(false)
                                            }
                                        }

                                        Rectangle {
                                            implicitWidth: delTileTxt.implicitWidth + 8
                                            implicitHeight: 22
                                            color: delTileMa.containsMouse ? editorRoot.theme.danger : editorRoot.theme.bg
                                            border.color: editorRoot.theme.danger
                                            border.width: 1

                                            Text {
                                                id: delTileTxt
                                                anchors.centerIn: parent
                                                font.family: editorRoot.monoFamily
                                                font.pixelSize: 10
                                                color: delTileMa.containsMouse ? editorRoot.theme.bg : editorRoot.theme.danger
                                                text: "[Delete]"
                                            }
                                            MouseArea {
                                                id: delTileMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    editorRoot.removeTile(editorRoot.selectedTileId);
                                                    editorRoot.saveAndApply(false);
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

        // Footer Actions & Status Bar
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.family: editorRoot.monoFamily
                font.pixelSize: 11
                color: editorRoot.statusIsWarning ? editorRoot.theme.danger : editorRoot.theme.accent
                text: "STATUS: " + editorRoot.statusMessage
            }

            Rectangle {
                implicitWidth: applyTxt.implicitWidth + 12
                implicitHeight: 26
                color: applyMa.containsMouse ? editorRoot.theme.secondary : editorRoot.theme.bg
                border.color: editorRoot.theme.secondary
                border.width: 1

                Text {
                    id: applyTxt
                    anchors.centerIn: parent
                    font.family: editorRoot.monoFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: applyMa.containsMouse ? editorRoot.theme.bg : editorRoot.theme.secondary
                    text: "[ APPLY LIVE ]"
                }

                MouseArea {
                    id: applyMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: editorRoot.saveAndApply(false)
                }
            }

            Rectangle {
                implicitWidth: saveTxt.implicitWidth + 12
                implicitHeight: 26
                color: saveMa.containsMouse ? editorRoot.theme.accent : editorRoot.theme.bg
                border.color: editorRoot.theme.accent
                border.width: 1

                Text {
                    id: saveTxt
                    anchors.centerIn: parent
                    font.family: editorRoot.monoFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: saveMa.containsMouse ? editorRoot.theme.bg : editorRoot.theme.accent
                    text: "[ SAVE & CLOSE ]"
                }

                MouseArea {
                    id: saveMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: editorRoot.saveAndApply(true)
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
            font.family: editorRoot.monoFamily
            font.pixelSize: 11
            color: resizeEdMa.containsMouse ? editorRoot.theme.accent : editorRoot.theme.muted
            text: "◢"
        }
        MouseArea {
            id: resizeEdMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeFDiagCursor
            property real startX: 0
            property real startY: 0
            onPressed: (mouse) => {
                startX = mouse.x;
                startY = mouse.y;
                editorRoot.maximizedModal = false;
            }
            onPositionChanged: (mouse) => {
                var maxW = editorRoot.parent ? editorRoot.parent.width - editorRoot.x - 8 : 1800;
                var maxH = editorRoot.parent ? editorRoot.parent.height - editorRoot.y - 34 : 1000;
                editorRoot.width = Math.max(740, Math.min(maxW, Math.round(editorRoot.width + (mouse.x - startX))));
                editorRoot.height = Math.max(500, Math.min(maxH, Math.round(editorRoot.height + (mouse.y - startY))));
            }
        }
    }
}
