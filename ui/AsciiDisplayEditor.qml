pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

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
    property var monitors: []
    property int selectedIndex: 0
    property string statusMessage: "Drag monitors on canvas to arrange; click Apply & Save."
    property bool statusIsWarning: false

    signal closeRequested()
    signal displaysUpdated(var monitors)

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

    function loadMonitors() {
        statusIsWarning = false;
        statusMessage = "Loading display layout...";
        callBackend(["displays", "list"], "displays_list");
    }

    function safeJsonParse(raw, fallback) {
        if (!raw || typeof raw !== "string") return fallback;
        var t = raw.trim();
        if (t.length === 0) return fallback;
        try {
            return JSON.parse(t);
        } catch (e) {
            return fallback;
        }
    }

    function logicalW(m) {
        if (!m) return 1920;
        var w = Number(m.width || 1920);
        var h = Number(m.height || 1080);
        var rot = Number(m.rotation || 0);
        var sc = Math.max(0.5, Number(m.scale || 1.0));
        var raw = (rot === 90 || rot === 270) ? h : w;
        return Math.round(raw / sc);
    }

    function logicalH(m) {
        if (!m) return 1080;
        var w = Number(m.width || 1920);
        var h = Number(m.height || 1080);
        var rot = Number(m.rotation || 0);
        var sc = Math.max(0.5, Number(m.scale || 1.0));
        var raw = (rot === 90 || rot === 270) ? w : h;
        return Math.round(raw / sc);
    }

    function cloneMonitors() {
        var out = [];
        for (var i = 0; i < monitors.length; i++) {
            var m = monitors[i];
            var copy = {};
            for (var k in m) {
                if (Object.prototype.hasOwnProperty.call(m, k)) {
                    copy[k] = m[k];
                }
            }
            out.push(copy);
        }
        return out;
    }

    function selectedMonitor() {
        if (!monitors || monitors.length === 0) return null;
        var idx = Math.max(0, Math.min(selectedIndex, monitors.length - 1));
        return monitors[idx];
    }

    function layoutMetrics() {
        if (!monitors || monitors.length === 0) {
            return { minX: 0, minY: 0, scale: 0.1 };
        }
        var minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9;
        for (var i = 0; i < monitors.length; i++) {
            var m = monitors[i];
            var x = Number(m.x || 0);
            var y = Number(m.y || 0);
            var w = logicalW(m);
            var h = logicalH(m);
            if (x < minX) minX = x;
            if (y < minY) minY = y;
            if (x + w > maxX) maxX = x + w;
            if (y + h > maxY) maxY = y + h;
        }
        var spanW = Math.max(1200, (maxX - minX) + 800);
        var spanH = Math.max(800, (maxY - minY) + 600);
        var cw = Math.max(200, arrangementCanvas.width - 32);
        var ch = Math.max(160, arrangementCanvas.height - 32);
        var sc = Math.min(cw / spanW, ch / spanH);
        return {
            minX: minX - 240,
            minY: minY - 180,
            scale: Math.max(0.04, Math.min(0.22, sc))
        };
    }

    function snapPosition(idx, candX, candY) {
        var list = monitors;
        if (!list || idx < 0 || idx >= list.length) return { x: Math.round(candX), y: Math.round(candY) };
        var cur = list[idx];
        var cw = logicalW(cur);
        var ch = logicalH(cur);
        var bestX = candX;
        var bestY = candY;
        var thresh = 80;
        var bestDx = thresh + 1;
        var bestDy = thresh + 1;

        for (var i = 0; i < list.length; i++) {
            if (i === idx) continue;
            var o = list[i];
            if (o.enabled === false) continue;
            var ox = Number(o.x || 0);
            var oy = Number(o.y || 0);
            var ow = logicalW(o);
            var oh = logicalH(o);

            var xCandidates = [
                { val: ox + ow, dist: Math.abs(candX - (ox + ow)) },
                { val: ox - cw, dist: Math.abs(candX - (ox - cw)) },
                { val: ox, dist: Math.abs(candX - ox) },
                { val: ox + ow - cw, dist: Math.abs(candX - (ox + ow - cw)) }
            ];
            for (var xi = 0; xi < xCandidates.length; xi++) {
                if (xCandidates[xi].dist < bestDx) {
                    bestDx = xCandidates[xi].dist;
                    bestX = xCandidates[xi].val;
                }
            }

            var yCandidates = [
                { val: oy + oh, dist: Math.abs(candY - (oy + oh)) },
                { val: oy - ch, dist: Math.abs(candY - (oy - ch)) },
                { val: oy, dist: Math.abs(candY - oy) },
                { val: oy + oh - ch, dist: Math.abs(candY - (oy + oh - ch)) }
            ];
            for (var yi = 0; yi < yCandidates.length; yi++) {
                if (yCandidates[yi].dist < bestDy) {
                    bestDy = yCandidates[yi].dist;
                    bestY = yCandidates[yi].val;
                }
            }
        }
        return { x: Math.round(bestX), y: Math.round(bestY) };
    }

    function updateSelectedField(fn) {
        if (!monitors || monitors.length === 0) return;
        var list = cloneMonitors();
        var idx = Math.max(0, Math.min(selectedIndex, list.length - 1));
        fn(list, idx);
        monitors = list;
    }

    function autoAlignMonitors() {
        var list = cloneMonitors();
        // Order primary first, then enabled monitors, then disabled
        var indices = [];
        for (var i = 0; i < list.length; i++) indices.push(i);
        indices.sort(function(a, b) {
            if (Boolean(list[a].primary) !== Boolean(list[b].primary)) return list[a].primary ? -1 : 1;
            if (Boolean(list[a].enabled) !== Boolean(list[b].enabled)) return list[a].enabled ? -1 : 1;
            return a - b;
        });
        var curX = 0;
        for (var j = 0; j < indices.length; j++) {
            var idx = indices[j];
            list[idx].x = curX;
            list[idx].y = 0;
            curX += logicalW(list[idx]);
        }
        monitors = list;
        statusIsWarning = false;
        statusMessage = "Auto-aligned monitors horizontally. Click Apply & Save.";
    }

    function cycleMode(delta) {
        updateSelectedField(function(list, idx) {
            var m = list[idx];
            var modes = m.available_modes;
            if (!Array.isArray(modes) || modes.length === 0) return;
            var curStr = Number(m.width) + "x" + Number(m.height) + "@" + Number(m.refresh || 60).toFixed(2);
            var curIdx = -1;
            for (var i = 0; i < modes.length; i++) {
                if (String(modes[i]) === curStr) { curIdx = i; break; }
            }
            if (curIdx === -1) {
                var prefix = Number(m.width) + "x" + Number(m.height) + "@";
                for (var j = 0; j < modes.length; j++) {
                    if (String(modes[j]).indexOf(prefix) === 0) { curIdx = j; break; }
                }
            }
            var nextIdx = (curIdx + delta + modes.length) % modes.length;
            var chosen = String(modes[nextIdx]);
            var parts = chosen.split("@");
            if (parts.length >= 1) {
                var wh = parts[0].split("x");
                if (wh.length === 2) {
                    m.width = parseInt(wh[0], 10) || m.width;
                    m.height = parseInt(wh[1], 10) || m.height;
                }
            }
            if (parts.length >= 2) {
                m.refresh = parseFloat(parts[1]) || m.refresh;
            }
        });
    }

    onVisibleChanged: {
        if (visible) loadMonitors();
    }

    Connections {
        target: editorRoot.getBackend()
        ignoreUnknownSignals: true

        function onBackendResult(tag, jsonOutput) {
            if (tag === "displays_list" || tag === "displays_reset") {
                var arr = editorRoot.safeJsonParse(jsonOutput, null);
                if (Array.isArray(arr)) {
                    editorRoot.monitors = arr;
                    if (editorRoot.selectedIndex >= arr.length) editorRoot.selectedIndex = 0;
                    editorRoot.statusIsWarning = false;
                    editorRoot.statusMessage = (tag === "displays_reset")
                        ? "Reset monitors from live hardware."
                        : ("Loaded " + arr.length + " display outputs.");
                }
            } else if (tag === "displays_save") {
                var saved = editorRoot.safeJsonParse(jsonOutput, null);
                if (Array.isArray(saved)) {
                    editorRoot.monitors = saved;
                    editorRoot.displaysUpdated(saved);
                    editorRoot.statusIsWarning = false;
                    editorRoot.statusMessage = "Saved monitors.json & outputs.conf; applying...";
                    editorRoot.callBackend(["displays", "apply"], "displays_apply");
                } else {
                    editorRoot.statusIsWarning = true;
                    editorRoot.statusMessage = "Save error: " + String(jsonOutput).slice(0, 80);
                }
            } else if (tag === "displays_apply") {
                var res = editorRoot.safeJsonParse(jsonOutput, null);
                if (res && typeof res === "object") {
                    if (Array.isArray(res.monitors)) {
                        editorRoot.monitors = res.monitors;
                        editorRoot.displaysUpdated(res.monitors);
                    }
                    editorRoot.statusIsWarning = false;
                    editorRoot.statusMessage = "Applied (" + (res.mode || res.status || "ok") + ").";
                } else {
                    editorRoot.statusIsWarning = false;
                    editorRoot.statusMessage = "Layout saved & applied.";
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onPressed: (mouse) => {
            editorRoot.forceActiveFocus();
            mouse.accepted = false;
        }
    }

    ColumnLayout {
        anchors { fill: parent; margins: 10 }
        spacing: 8

        // Draggable Header bar container
        Item {
            Layout.fillWidth: true
            implicitHeight: 24

            MouseArea {
                id: edDragArea
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
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.family: editorRoot.monoFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: editorRoot.theme.accent
                    text: "┌─[ ASCII DISPLAY LAYOUT EDITOR — MULTI-MONITOR ]───────────────────────────"
                }
                Rectangle {
                    z: 2
                    width: 44
                    height: 22
                    color: closeEdMa.containsMouse ? editorRoot.theme.danger : editorRoot.theme.bg
                    border.color: editorRoot.theme.danger
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        font.family: editorRoot.monoFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: closeEdMa.containsMouse ? editorRoot.theme.bg : editorRoot.theme.danger
                        text: "[ ✕ ]"
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

        // Main Split: 2D Canvas (left/top) + Inspector (right/bottom)
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: editorRoot.width < 720 ? 1 : 2
            columnSpacing: 10
            rowSpacing: 8

            // Left: Interactive 2D ASCII Monitor Arrangement Canvas
            Rectangle {
                id: arrangementCanvas
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: editorRoot.width < 720 ? -1 : 1.4
                Layout.preferredHeight: editorRoot.width < 720 ? Math.max(150, Math.round(editorRoot.height * 0.36)) : -1
                Layout.minimumHeight: 130
                color: editorRoot.theme.bg
                border.color: editorRoot.theme.muted
                border.width: 1
                clip: true

                Canvas {
                    anchors.fill: parent
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.fillStyle = String(editorRoot.theme.gridDot);
                        ctx.font = "11px 'JetBrains Mono', monospace";
                        for (var y = 16; y < height; y += 22) {
                            for (var x = 14; x < width; x += 22) {
                                ctx.fillText("·", x, y);
                            }
                        }
                    }
                }

                Text {
                    anchors { top: parent.top; left: parent.left; margins: 8 }
                    font.family: editorRoot.monoFamily
                    font.pixelSize: 10
                    color: editorRoot.theme.muted
                    text: "2D VIRTUAL CANVAS (drag boxes to reposition & edge-snap)"
                }

                Repeater {
                    model: editorRoot.monitors

                    delegate: Rectangle {
                        id: monBox
                        required property var modelData
                        required property int index

                        readonly property var metrics: editorRoot.layoutMetrics()
                        readonly property bool isSel: index === editorRoot.selectedIndex
                        readonly property bool isEn: modelData.enabled !== false
                        readonly property bool isOnkyo: Boolean(modelData.onkyo_avr)
                        readonly property real boxX: 16 + (Number(modelData.x || 0) - metrics.minX) * metrics.scale
                        readonly property real boxY: 28 + (Number(modelData.y || 0) - metrics.minY) * metrics.scale
                        readonly property real boxW: Math.max(76, editorRoot.logicalW(modelData) * metrics.scale)
                        readonly property real boxH: Math.max(54, editorRoot.logicalH(modelData) * metrics.scale)

                        x: monDragMa.drag.active ? x : boxX
                        y: monDragMa.drag.active ? y : boxY
                        width: boxW
                        height: boxH
                        z: isSel ? 10 : 1
                        opacity: isEn ? 1.0 : 0.48
                        color: isSel ? Qt.rgba(0.18, 0.14, 0.04, 0.94) : editorRoot.theme.panelBg
                        border.color: isSel ? editorRoot.theme.accent : (isOnkyo ? editorRoot.theme.secondary : editorRoot.theme.muted)
                        border.width: isSel ? 2 : 1

                        Column {
                            anchors.centerIn: parent
                            width: parent.width - 8
                            spacing: 2

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                font.family: editorRoot.monoFamily
                                font.pixelSize: 11
                                font.bold: true
                                color: monBox.isSel ? editorRoot.theme.accent : editorRoot.theme.fg
                                text: (monBox.modelData.primary ? "★ " : "") + (monBox.modelData.name || "OUT")
                            }
                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                font.family: editorRoot.monoFamily
                                font.pixelSize: 9
                                color: editorRoot.theme.fg
                                text: Number(monBox.modelData.width || 0) + "x" + Number(monBox.modelData.height || 0)
                                      + (Number(monBox.modelData.rotation || 0) !== 0 ? (" [" + monBox.modelData.rotation + "°]") : "")
                            }
                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                font.family: editorRoot.monoFamily
                                font.pixelSize: 9
                                color: monBox.isOnkyo ? editorRoot.theme.secondary : editorRoot.theme.muted
                                text: monBox.isOnkyo ? "[ONKYO AVR]" : ("(" + Number(monBox.modelData.x || 0) + "," + Number(monBox.modelData.y || 0) + ") " + Number(monBox.modelData.scale || 1) + "x")
                            }
                            Text {
                                visible: !monBox.isEn
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                font.family: editorRoot.monoFamily
                                font.pixelSize: 9
                                font.bold: true
                                color: editorRoot.theme.danger
                                text: "[DISABLED]"
                            }
                        }

                        MouseArea {
                            id: monDragMa
                            anchors.fill: parent
                            cursorShape: Qt.SizeAllCursor
                            drag.target: monBox
                            drag.minimumX: 4
                            drag.maximumX: Math.max(4, arrangementCanvas.width - monBox.width - 4)
                            drag.minimumY: 24
                            drag.maximumY: Math.max(24, arrangementCanvas.height - monBox.height - 4)

                            onPressed: {
                                editorRoot.selectedIndex = monBox.index;
                            }

                            onReleased: {
                                var m = monBox.metrics;
                                var rawX = m.minX + (monBox.x - 16) / m.scale;
                                var rawY = m.minY + (monBox.y - 28) / m.scale;
                                var snapped = editorRoot.snapPosition(monBox.index, rawX, rawY);
                                editorRoot.updateSelectedField(function(list, idx) {
                                    list[idx].x = snapped.x;
                                    list[idx].y = snapped.y;
                                });
                            }
                        }
                    }
                }
            }

            // Right: Selected Monitor Inspector
            Rectangle {
                id: inspectorPane
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: editorRoot.width < 720 ? -1 : 1.0
                color: editorRoot.theme.bg
                border.color: editorRoot.theme.muted
                border.width: 1

                readonly property var cur: editorRoot.selectedMonitor()
                readonly property bool curIsOnkyo: Boolean(cur && cur.onkyo_avr)

                Flickable {
                    anchors { fill: parent; margins: 10 }
                    clip: true
                    contentWidth: width
                    contentHeight: inspectorCol.implicitHeight
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: inspectorCol
                        width: parent.width
                        spacing: 8
                        visible: Boolean(inspectorPane.cur)

                        readonly property var cur: inspectorPane.cur
                        readonly property bool curIsOnkyo: inspectorPane.curIsOnkyo

                    Text {
                        font.family: editorRoot.monoFamily
                        font.pixelSize: 12
                        font.bold: true
                        color: editorRoot.theme.accent
                        text: "┌─[ INSPECTOR: " + (inspectorCol.cur ? inspectorCol.cur.name : "-") + " ]───────"
                    }

                    Text {
                        visible: inspectorCol.curIsOnkyo
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font.family: editorRoot.monoFamily
                        font.pixelSize: 10
                        color: editorRoot.theme.secondary
                        text: "[AUDIO GUARD] " + (inspectorCol.cur ? inspectorCol.cur.name : "AVR") + " feeds Onkyo AVR audio. Keep enabled to preserve HDMI audio."
                    }

                    // Enabled & Primary toggles
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            Layout.fillWidth: true
                            height: 26
                            readonly property bool en: Boolean(inspectorCol.cur && inspectorCol.cur.enabled !== false)
                            color: en ? editorRoot.theme.secondary : editorRoot.theme.danger
                            border.color: en ? editorRoot.theme.secondary : editorRoot.theme.danger
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                font.family: editorRoot.monoFamily
                                font.pixelSize: 10
                                font.bold: true
                                color: editorRoot.theme.bg
                                text: parent.en ? "[ ENABLED: ON ]" : "[ ENABLED: OFF ]"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var willDisable = Boolean(inspectorCol.cur && inspectorCol.cur.enabled !== false);
                                    if (willDisable && inspectorCol.curIsOnkyo) {
                                        editorRoot.statusIsWarning = true;
                                        editorRoot.statusMessage = "WARNING: Disabling " + (inspectorCol.cur ? inspectorCol.cur.name : "output") + " cuts Onkyo AVR audio!";
                                    }
                                    editorRoot.updateSelectedField(function(list, idx) {
                                        list[idx].enabled = !(list[idx].enabled !== false);
                                    });
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 26
                            readonly property bool pri: Boolean(inspectorCol.cur && inspectorCol.cur.primary)
                            color: pri ? editorRoot.theme.accent : editorRoot.theme.panelBg
                            border.color: editorRoot.theme.accent
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                font.family: editorRoot.monoFamily
                                font.pixelSize: 10
                                font.bold: true
                                color: parent.pri ? editorRoot.theme.bg : editorRoot.theme.accent
                                text: parent.pri ? "[ ★ PRIMARY ]" : "[ ★ SET PRIMARY ]"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (inspectorCol.curIsOnkyo) {
                                        editorRoot.statusIsWarning = true;
                                        editorRoot.statusMessage = "NOTE: Onkyo AVR (" + (inspectorCol.cur ? inspectorCol.cur.name : "output") + ") set as primary; another display is recommended.";
                                    }
                                    editorRoot.updateSelectedField(function(list, idx) {
                                        for (var i = 0; i < list.length; i++) {
                                            list[i].primary = (i === idx);
                                        }
                                        list[idx].enabled = true;
                                    });
                                }
                            }
                        }
                    }

                    // Rotation
                    Text {
                        font.family: editorRoot.monoFamily
                        font.pixelSize: 10
                        color: editorRoot.theme.muted
                        text: "ROTATION:"
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Repeater {
                            model: [0, 90, 180, 270]
                            delegate: Rectangle {
                                id: rotDel
                                required property int modelData
                                readonly property bool sel: Boolean(inspectorCol.cur && Number(inspectorCol.cur.rotation || 0) === modelData)
                                Layout.fillWidth: true
                                height: 24
                                color: sel ? editorRoot.theme.accent : editorRoot.theme.panelBg
                                border.color: sel ? editorRoot.theme.accent : editorRoot.theme.muted
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    font.family: editorRoot.monoFamily
                                    font.pixelSize: 10
                                    font.bold: rotDel.sel
                                    color: rotDel.sel ? editorRoot.theme.bg : editorRoot.theme.fg
                                    text: "[ " + rotDel.modelData + "° ]"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        editorRoot.updateSelectedField(function(list, idx) {
                                            list[idx].rotation = rotDel.modelData;
                                        });
                                    }
                                }
                            }
                        }
                    }

                    // Mode (Resolution & Refresh)
                    Text {
                        font.family: editorRoot.monoFamily
                        font.pixelSize: 10
                        color: editorRoot.theme.muted
                        text: "RESOLUTION & REFRESH:"
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Rectangle {
                            width: 34; height: 24
                            color: prevModeMa.containsMouse ? editorRoot.theme.accent : editorRoot.theme.panelBg
                            border.color: editorRoot.theme.muted; border.width: 1
                            Text { anchors.centerIn: parent; font.family: editorRoot.monoFamily; font.pixelSize: 11; color: prevModeMa.containsMouse ? editorRoot.theme.bg : editorRoot.theme.fg; text: "[◀]" }
                            MouseArea { id: prevModeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: editorRoot.cycleMode(-1) }
                        }
                        Rectangle {
                            Layout.fillWidth: true; height: 24
                            color: editorRoot.theme.panelBg; border.color: editorRoot.theme.gridDot; border.width: 1
                            Text {
                                anchors.centerIn: parent
                                font.family: editorRoot.monoFamily
                                font.pixelSize: 10
                                color: editorRoot.theme.fg
                                text: inspectorCol.cur
                                      ? (Number(inspectorCol.cur.width || 0) + "x" + Number(inspectorCol.cur.height || 0) + "@" + Number(inspectorCol.cur.refresh || 60).toFixed(2) + "Hz")
                                      : "-"
                            }
                        }
                        Rectangle {
                            width: 34; height: 24
                            color: nextModeMa.containsMouse ? editorRoot.theme.accent : editorRoot.theme.panelBg
                            border.color: editorRoot.theme.muted; border.width: 1
                            Text { anchors.centerIn: parent; font.family: editorRoot.monoFamily; font.pixelSize: 11; color: nextModeMa.containsMouse ? editorRoot.theme.bg : editorRoot.theme.fg; text: "[▶]" }
                            MouseArea { id: nextModeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: editorRoot.cycleMode(1) }
                        }
                    }

                    // Scale stepper
                    Text {
                        font.family: editorRoot.monoFamily
                        font.pixelSize: 10
                        color: editorRoot.theme.muted
                        text: "SCALE:"
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Repeater {
                            model: [1.0, 1.25, 1.5, 2.0]
                            delegate: Rectangle {
                                id: scaleDel
                                required property real modelData
                                readonly property bool sel: Boolean(inspectorCol.cur && Math.abs(Number(inspectorCol.cur.scale || 1.0) - modelData) < 0.05)
                                Layout.fillWidth: true
                                height: 24
                                color: sel ? editorRoot.theme.accent : editorRoot.theme.panelBg
                                border.color: sel ? editorRoot.theme.accent : editorRoot.theme.muted
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    font.family: editorRoot.monoFamily
                                    font.pixelSize: 10
                                    font.bold: scaleDel.sel
                                    color: scaleDel.sel ? editorRoot.theme.bg : editorRoot.theme.fg
                                    text: scaleDel.modelData.toFixed(scaleDel.modelData === 1.0 || scaleDel.modelData === 2.0 ? 1 : 2) + "x"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        editorRoot.updateSelectedField(function(list, idx) {
                                            list[idx].scale = scaleDel.modelData;
                                        });
                                    }
                                }
                            }
                        }
                    }

                        Text {
                            font.family: editorRoot.monoFamily
                            font.pixelSize: 10
                            color: editorRoot.theme.muted
                            text: inspectorCol.cur
                                  ? ("POSITION: x=" + Number(inspectorCol.cur.x || 0) + ", y=" + Number(inspectorCol.cur.y || 0))
                                  : ""
                        }
                    }
                }
            }
        }

        // Footer: Status feedback + [Auto-Align] [Reset] [Apply & Save]
        GridLayout {
            Layout.fillWidth: true
            columns: editorRoot.width < 660 ? 1 : 2
            columnSpacing: 8
            rowSpacing: 6

            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.family: editorRoot.monoFamily
                font.pixelSize: 10
                color: editorRoot.statusIsWarning ? editorRoot.theme.danger : editorRoot.theme.secondary
                text: "> " + editorRoot.statusMessage
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 6

                Rectangle {
                    implicitWidth: Math.min(122, alignLbl.implicitWidth + 14)
                    height: 26
                    color: alignMa.containsMouse ? editorRoot.theme.accent : editorRoot.theme.bg
                    border.color: editorRoot.theme.muted; border.width: 1
                    Text { id: alignLbl; anchors.centerIn: parent; font.family: editorRoot.monoFamily; font.pixelSize: 10; color: alignMa.containsMouse ? editorRoot.theme.bg : editorRoot.theme.fg; text: "[ ⊞ Auto-Align ]" }
                    MouseArea { id: alignMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: editorRoot.autoAlignMonitors() }
                }

                Rectangle {
                    implicitWidth: Math.min(92, rstLbl.implicitWidth + 14)
                    height: 26
                    color: resetMa.containsMouse ? editorRoot.theme.accent : editorRoot.theme.bg
                    border.color: editorRoot.theme.muted; border.width: 1
                    Text { id: rstLbl; anchors.centerIn: parent; font.family: editorRoot.monoFamily; font.pixelSize: 10; color: resetMa.containsMouse ? editorRoot.theme.bg : editorRoot.theme.fg; text: "[ ↺ Reset ]" }
                    MouseArea { id: resetMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: editorRoot.callBackend(["displays", "reset"], "displays_reset") }
                }

                Rectangle {
                    implicitWidth: Math.min(144, applyLbl.implicitWidth + 14)
                    height: 26
                    color: applyMa.containsMouse ? editorRoot.theme.secondary : editorRoot.theme.bg
                    border.color: editorRoot.theme.secondary; border.width: 1
                    Text { id: applyLbl; anchors.centerIn: parent; font.family: editorRoot.monoFamily; font.pixelSize: 10; font.bold: true; color: applyMa.containsMouse ? editorRoot.theme.bg : editorRoot.theme.secondary; text: "[ ✓ Apply & Save ]" }
                    MouseArea {
                        id: applyMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            editorRoot.statusIsWarning = false;
                            editorRoot.statusMessage = "Saving layout...";
                            editorRoot.callBackend(["displays", "save", JSON.stringify(editorRoot.monitors)], "displays_save");
                        }
                    }
                }
            }
        }
    }
}
