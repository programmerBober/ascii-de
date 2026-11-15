pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    // --- Public interface contract ---
    property bool active: false
    property var theme: ({
        name: "amber",
        bg: "#0d0f10",
        panelBg: "#14171a",
        fg: "#e6dcc8",
        accent: "#ffb000",
        secondary: "#50fa7b",
        muted: "#6e7681",
        danger: "#ff5555",
        cornerRadius: 0,
        borderWidth: 1,
        fontFamily: "JetBrains Mono",
        chromeStyle: "ascii"
    })
    property string monoFamily: (theme && theme.fontFamily) ? theme.fontFamily : "JetBrains Mono"
    property int monitorCount: 1
    property string captureMode: "region"   // "region" | "monitor" | "all"
    property bool saveToDisk: true          // true = SAVE + COPY, false = COPY ONLY

    signal requestCaptureRegion(int rx, int ry, int rw, int rh, bool save, bool copy)
    signal requestCaptureMonitor(bool save, bool copy)
    signal requestCaptureAll(bool save, bool copy)
    signal cancelled()

    visible: root.active || flashLayer.opacity > 0 || toastBanner.visible

    // --- Theme helpers ---
    readonly property color colBg: (theme && theme.bg) ? theme.bg : "#0d0f10"
    readonly property color colPanelBg: (theme && theme.panelBg) ? theme.panelBg : "#14171a"
    readonly property color colFg: (theme && theme.fg) ? theme.fg : "#e6dcc8"
    readonly property color colAccent: (theme && theme.accent) ? theme.accent : "#ffb000"
    readonly property color colSecondary: (theme && theme.secondary) ? theme.secondary : "#50fa7b"
    readonly property color colMuted: (theme && theme.muted) ? theme.muted : "#6e7681"
    readonly property color colDanger: (theme && theme.danger) ? theme.danger : "#ff5555"
    readonly property int themeRadius: (theme && theme.cornerRadius !== undefined) ? Number(theme.cornerRadius) : 0
    readonly property int themeBorderWidth: (theme && theme.borderWidth !== undefined) ? Math.max(1, Number(theme.borderWidth)) : 1
    readonly property bool isDataLens: Boolean(theme && theme.chromeStyle === "snaptic_datalens")

    // --- Selection geometry ---
    property bool dragging: false
    property real startX: 0
    property real startY: 0
    property real curX: 0
    property real curY: 0
    property real hoverX: width * 0.5
    property real hoverY: height * 0.5
    property bool hasHover: false

    readonly property int selX: Math.round(Math.max(0, Math.min(startX, curX)))
    readonly property int selY: Math.round(Math.max(0, Math.min(startY, curY)))
    readonly property int selW: Math.round(Math.min(width, Math.max(startX, curX)) - selX)
    readonly property int selH: Math.round(Math.min(height, Math.max(startY, curY)) - selY)
    readonly property bool hasSelection: dragging && selW >= 4 && selH >= 4

    // --- Feedback toast state ---
    property string toastText: ""
    property bool toastIsError: false

    onActiveChanged: {
        dragging = false;
        startX = 0;
        startY = 0;
        curX = 0;
        curY = 0;
        hasHover = false;
        if (active) {
            captureMode = "region";
            captureLayer.forceActiveFocus();
        }
    }

    function resetDrag() {
        dragging = false;
        startX = 0;
        startY = 0;
        curX = 0;
        curY = 0;
    }

    function triggerCancel() {
        resetDrag();
        root.cancelled();
    }

    function triggerRegionCapture(rx, ry, rw, rh) {
        resetDrag();
        root.requestCaptureRegion(rx, ry, rw, rh, root.saveToDisk, true);
    }

    function triggerMonitorCapture() {
        resetDrag();
        root.requestCaptureMonitor(root.saveToDisk, true);
    }

    function triggerAllCapture() {
        resetDrag();
        root.requestCaptureAll(root.saveToDisk, true);
    }

    function showCaptureFeedback(result) {
        if (!result || typeof result !== "object") {
            return;
        }
        if (result.ok) {
            toastIsError = false;
            const dims = (result.width || 0) + "x" + (result.height || 0);
            const parts = ["CAPTURED " + dims];
            if (result.clipboardCopied) {
                parts.push("COPIED");
            }
            if (result.path && String(result.path).length > 0) {
                const fullPath = String(result.path);
                const slash = fullPath.lastIndexOf("/");
                const fileName = slash >= 0 ? fullPath.slice(slash + 1) : fullPath;
                parts.push("SAVED " + fileName);
            }
            toastText = "[ " + (root.isDataLens ? "✓ " : "* ") + parts.join(" • ") + " ]";
            flashAnim.restart();
        } else {
            toastIsError = true;
            toastText = "[ ! SCREENSHOT FAILED: " + (result.error || "Unknown error") + " ]";
        }
        toastBanner.visible = true;
        toastTimer.restart();
    }

    // --- Interactive Capture Layer (active only while capturing) ---
    Item {
        id: captureLayer
        anchors.fill: parent
        visible: root.active
        enabled: root.active
        focus: root.active

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                event.accepted = true;
                root.triggerCancel();
            } else if (event.key === Qt.Key_R || event.key === Qt.Key_1) {
                event.accepted = true;
                root.captureMode = "region";
            } else if (event.key === Qt.Key_M || event.key === Qt.Key_2) {
                event.accepted = true;
                root.captureMode = "monitor";
                root.triggerMonitorCapture();
            } else if (event.key === Qt.Key_A || event.key === Qt.Key_3) {
                event.accepted = true;
                root.captureMode = "all";
                root.triggerAllCapture();
            } else if (event.key === Qt.Key_C) {
                event.accepted = true;
                root.saveToDisk = !root.saveToDisk;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                event.accepted = true;
                if (root.hasSelection && root.selW >= 8 && root.selH >= 8) {
                    root.triggerRegionCapture(root.selX, root.selY, root.selW, root.selH);
                } else if (root.captureMode === "all") {
                    root.triggerAllCapture();
                } else {
                    root.triggerMonitorCapture();
                }
            }
        }

        // Full scrim when no active drag cutout is present
        Rectangle {
            anchors.fill: parent
            visible: !root.hasSelection
            color: Qt.alpha(root.colBg, root.captureMode === "monitor" ? 0.34 : 0.46)
        }

        // 4-quadrant dim scrim around active drag rectangle (leaves cutout crystal clear)
        Rectangle {
            visible: root.hasSelection
            x: 0
            y: 0
            width: parent.width
            height: root.selY
            color: Qt.alpha(root.colBg, 0.56)
        }
        Rectangle {
            visible: root.hasSelection
            x: 0
            y: root.selY + root.selH
            width: parent.width
            height: Math.max(0, parent.height - (root.selY + root.selH))
            color: Qt.alpha(root.colBg, 0.56)
        }
        Rectangle {
            visible: root.hasSelection
            x: 0
            y: root.selY
            width: root.selX
            height: root.selH
            color: Qt.alpha(root.colBg, 0.56)
        }
        Rectangle {
            visible: root.hasSelection
            x: root.selX + root.selW
            y: root.selY
            width: Math.max(0, parent.width - (root.selX + root.selW))
            height: root.selH
            color: Qt.alpha(root.colBg, 0.56)
        }

        // Full-monitor highlight frame when in MONITOR mode
        Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            visible: root.captureMode === "monitor" && !root.hasSelection
            color: "transparent"
            border.width: 2
            border.color: root.colSecondary
            radius: Math.min(8, root.themeRadius)
        }

        // Crosshair guide lines in REGION mode
        Rectangle {
            visible: root.captureMode === "region" && root.hasHover && !root.dragging
            x: Math.round(root.hoverX)
            y: 0
            width: 1
            height: parent.height
            color: Qt.alpha(root.colAccent, 0.38)
        }
        Rectangle {
            visible: root.captureMode === "region" && root.hasHover && !root.dragging
            x: 0
            y: Math.round(root.hoverY)
            width: parent.width
            height: 1
            color: Qt.alpha(root.colAccent, 0.38)
        }

        // Hover coordinate chip before dragging
        Rectangle {
            visible: root.captureMode === "region" && root.hasHover && !root.dragging
            x: Math.min(parent.width - width - 12, Math.max(12, Math.round(root.hoverX) + 14))
            y: Math.min(parent.height - height - 12, Math.max(76, Math.round(root.hoverY) + 14))
            width: hoverCoordLabel.implicitWidth + 14
            height: hoverCoordLabel.implicitHeight + 8
            color: Qt.alpha(root.colPanelBg, 0.92)
            border.width: 1
            border.color: Qt.alpha(root.colAccent, 0.75)
            radius: Math.min(4, root.themeRadius)

            Text {
                id: hoverCoordLabel
                anchors.centerIn: parent
                text: Math.round(root.hoverX) + "," + Math.round(root.hoverY)
                color: root.colFg
                font.family: root.monoFamily
                font.pixelSize: 11
                font.bold: true
            }
        }

        // Active selection rectangle + corner ticks + live WxH readout
        Item {
            id: selectionBox
            visible: root.hasSelection
            x: root.selX
            y: root.selY
            width: root.selW
            height: root.selH

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: 2
                border.color: root.colAccent
            }

            // Crisp corner brackets
            Rectangle { x: -1; y: -1; width: 12; height: 3; color: root.colSecondary }
            Rectangle { x: -1; y: -1; width: 3; height: 12; color: root.colSecondary }
            Rectangle { x: parent.width - 11; y: -1; width: 12; height: 3; color: root.colSecondary }
            Rectangle { x: parent.width - 2; y: -1; width: 3; height: 12; color: root.colSecondary }
            Rectangle { x: -1; y: parent.height - 2; width: 12; height: 3; color: root.colSecondary }
            Rectangle { x: -1; y: parent.height - 11; width: 3; height: 12; color: root.colSecondary }
            Rectangle { x: parent.width - 11; y: parent.height - 2; width: 12; height: 3; color: root.colSecondary }
            Rectangle { x: parent.width - 2; y: parent.height - 11; width: 3; height: 12; color: root.colSecondary }

            // Live pixel size badge
            Rectangle {
                id: sizeReadoutBadge
                x: Math.max(-selectionBox.x + 8, Math.min(parent.width - width, 0))
                y: selectionBox.y >= 34 ? -height - 6 : (parent.height + 6 < (captureLayer.height - selectionBox.y) ? parent.height + 6 : 6)
                width: sizeReadoutText.implicitWidth + 16
                height: sizeReadoutText.implicitHeight + 8
                color: root.colPanelBg
                border.width: 1
                border.color: root.colAccent
                radius: Math.min(4, root.themeRadius)

                Text {
                    id: sizeReadoutText
                    anchors.centerIn: parent
                    text: root.selW + "x" + root.selH + "  (" + root.selX + "," + root.selY + ")"
                    color: root.colAccent
                    font.family: root.monoFamily
                    font.pixelSize: 12
                    font.bold: true
                }
            }
        }

        // Full-screen drag & click surface (sits underneath HUD toolbar)
        MouseArea {
            id: scrimMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: root.captureMode === "region" ? Qt.CrossCursor : Qt.PointingHandCursor

            onPositionChanged: (mouse) => {
                root.hoverX = mouse.x;
                root.hoverY = mouse.y;
                root.hasHover = true;
                if (root.dragging) {
                    root.curX = Math.max(0, Math.min(root.width, mouse.x));
                    root.curY = Math.max(0, Math.min(root.height, mouse.y));
                }
            }

            onExited: {
                if (!root.dragging) {
                    root.hasHover = false;
                }
            }

            onPressed: (mouse) => {
                captureLayer.forceActiveFocus();
                if (mouse.button === Qt.RightButton) {
                    if (root.dragging) {
                        root.resetDrag();
                    } else {
                        root.triggerCancel();
                    }
                    return;
                }
                if (root.captureMode === "monitor") {
                    root.triggerMonitorCapture();
                    return;
                }
                if (root.captureMode === "all") {
                    root.triggerAllCapture();
                    return;
                }
                root.startX = mouse.x;
                root.startY = mouse.y;
                root.curX = mouse.x;
                root.curY = mouse.y;
                root.dragging = true;
            }

            onReleased: (mouse) => {
                if (mouse.button !== Qt.LeftButton || !root.dragging) {
                    return;
                }
                root.curX = Math.max(0, Math.min(root.width, mouse.x));
                root.curY = Math.max(0, Math.min(root.height, mouse.y));
                var rx = root.selX;
                var ry = root.selY;
                var rw = root.selW;
                var rh = root.selH;
                root.dragging = false;
                if (rw >= 8 && rh >= 8) {
                    root.triggerRegionCapture(rx, ry, rw, rh);
                } else {
                    root.resetDrag();
                }
            }
        }

        // Top-center floating cyberpunk / ASCII HUD toolbar
        Rectangle {
            id: hudBar
            z: 10
            anchors.top: parent.top
            anchors.topMargin: 18
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width - 24, hudRow.implicitWidth + 24)
            height: 44
            color: Qt.alpha(root.colPanelBg, 0.96)
            border.width: root.themeBorderWidth
            border.color: root.colAccent
            radius: Math.min(8, root.themeRadius)

            // Shield mouse events from falling through to scrimMouse
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                hoverEnabled: true
                onPressed: (mouse) => { mouse.accepted = true; }
            }

            RowLayout {
                id: hudRow
                anchors.centerIn: parent
                spacing: 8

                Text {
                    text: root.isDataLens ? "[ ⊡ SNAPTIC ]" : "[ ◈ CAPTURE ]"
                    color: root.colAccent
                    font.family: root.monoFamily
                    font.pixelSize: 12
                    font.bold: true
                }

                Rectangle {
                    implicitWidth: 1
                    implicitHeight: 20
                    color: Qt.alpha(root.colMuted, 0.5)
                }

                // Mode: REGION
                Rectangle {
                    readonly property bool selected: root.captureMode === "region"
                    implicitWidth: regionLabel.implicitWidth + 16
                    implicitHeight: 28
                    color: selected ? root.colAccent : (regionMouse.containsMouse ? Qt.alpha(root.colAccent, 0.16) : root.colBg)
                    border.width: 1
                    border.color: selected ? root.colAccent : root.colMuted
                    radius: Math.min(4, root.themeRadius)

                    Text {
                        id: regionLabel
                        anchors.centerIn: parent
                        text: "[ REGION ]"
                        color: parent.selected ? root.colBg : root.colFg
                        font.family: root.monoFamily
                        font.pixelSize: 11
                        font.bold: true
                    }

                    MouseArea {
                        id: regionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.captureMode = "region";
                            root.resetDrag();
                        }
                    }
                }

                // Mode: MONITOR
                Rectangle {
                    readonly property bool selected: root.captureMode === "monitor"
                    implicitWidth: monitorLabel.implicitWidth + 16
                    implicitHeight: 28
                    color: selected ? root.colSecondary : (monitorMouse.containsMouse ? Qt.alpha(root.colSecondary, 0.16) : root.colBg)
                    border.width: 1
                    border.color: selected ? root.colSecondary : root.colMuted
                    radius: Math.min(4, root.themeRadius)

                    Text {
                        id: monitorLabel
                        anchors.centerIn: parent
                        text: "[ MONITOR ]"
                        color: parent.selected ? root.colBg : root.colFg
                        font.family: root.monoFamily
                        font.pixelSize: 11
                        font.bold: true
                    }

                    MouseArea {
                        id: monitorMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.captureMode = "monitor";
                            root.triggerMonitorCapture();
                        }
                    }
                }

                // Mode: ALL MONITORS
                Rectangle {
                    readonly property bool selected: root.captureMode === "all"
                    implicitWidth: allLabel.implicitWidth + 16
                    implicitHeight: 28
                    color: selected ? root.colSecondary : (allMouse.containsMouse ? Qt.alpha(root.colSecondary, 0.16) : root.colBg)
                    border.width: 1
                    border.color: selected ? root.colSecondary : root.colMuted
                    radius: Math.min(4, root.themeRadius)

                    Text {
                        id: allLabel
                        anchors.centerIn: parent
                        text: root.monitorCount > 1 ? ("[ ALL MONITORS (" + root.monitorCount + ") ]") : "[ ALL MONITORS ]"
                        color: parent.selected ? root.colBg : root.colFg
                        font.family: root.monoFamily
                        font.pixelSize: 11
                        font.bold: true
                    }

                    MouseArea {
                        id: allMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.captureMode = "all";
                            root.triggerAllCapture();
                        }
                    }
                }

                Rectangle {
                    implicitWidth: 1
                    implicitHeight: 20
                    color: Qt.alpha(root.colMuted, 0.5)
                }

                // Toggle: SAVE + COPY vs COPY ONLY
                Rectangle {
                    implicitWidth: saveToggleLabel.implicitWidth + 16
                    implicitHeight: 28
                    color: saveToggleMouse.containsMouse ? Qt.alpha(root.colSecondary, 0.18) : root.colBg
                    border.width: 1
                    border.color: root.saveToDisk ? root.colSecondary : root.colAccent
                    radius: Math.min(4, root.themeRadius)

                    Text {
                        id: saveToggleLabel
                        anchors.centerIn: parent
                        text: root.saveToDisk ? "[ SAVE + COPY ]" : "[ COPY ONLY ]"
                        color: root.saveToDisk ? root.colSecondary : root.colAccent
                        font.family: root.monoFamily
                        font.pixelSize: 11
                        font.bold: true
                    }

                    MouseArea {
                        id: saveToggleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.saveToDisk = !root.saveToDisk
                    }
                }

                // Cancel button
                Rectangle {
                    implicitWidth: cancelLabel.implicitWidth + 16
                    implicitHeight: 28
                    color: cancelMouse.containsMouse ? root.colDanger : root.colBg
                    border.width: 1
                    border.color: root.colDanger
                    radius: Math.min(4, root.themeRadius)

                    Text {
                        id: cancelLabel
                        anchors.centerIn: parent
                        text: "[ X CANCEL ]"
                        color: cancelMouse.containsMouse ? root.colBg : root.colDanger
                        font.family: root.monoFamily
                        font.pixelSize: 11
                        font.bold: true
                    }

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.triggerCancel()
                    }
                }
            }
        }

        // Bottom hint strip
        Rectangle {
            z: 10
            visible: !root.hasSelection
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20
            anchors.horizontalCenter: parent.horizontalCenter
            width: hintText.implicitWidth + 24
            height: hintText.implicitHeight + 12
            color: Qt.alpha(root.colPanelBg, 0.90)
            border.width: 1
            border.color: Qt.alpha(root.colMuted, 0.65)
            radius: Math.min(6, root.themeRadius)

            Text {
                id: hintText
                anchors.centerIn: parent
                text: "DRAG REGION TO CAPTURE  •  [M] MONITOR  •  [A] ALL MONITORS  •  [C] TOGGLE SAVE  •  [ESC / RMB] CANCEL"
                color: root.colMuted
                font.family: root.monoFamily
                font.pixelSize: 11
            }
        }
    }

    // --- Shutter flash feedback (never blocks input) ---
    Rectangle {
        id: flashLayer
        anchors.fill: parent
        color: "#ffffff"
        opacity: 0.0
        visible: opacity > 0

        SequentialAnimation {
            id: flashAnim
            PropertyAction { target: flashLayer; property: "opacity"; value: 0.36 }
            NumberAnimation {
                target: flashLayer
                property: "opacity"
                from: 0.36
                to: 0.0
                duration: 210
                easing.type: Easing.OutCubic
            }
        }
    }

    // --- Non-blocking result toast (never steals focus or mouse) ---
    Rectangle {
        id: toastBanner
        visible: false
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 42
        width: Math.min(parent.width - 40, toastLabel.implicitWidth + 24)
        height: toastLabel.implicitHeight + 14
        color: Qt.alpha(root.colPanelBg, 0.95)
        border.width: root.themeBorderWidth
        border.color: root.toastIsError ? root.colDanger : root.colSecondary
        radius: Math.min(6, root.themeRadius)

        Text {
            id: toastLabel
            anchors.centerIn: parent
            width: Math.min(implicitWidth, toastBanner.width - 20)
            elide: Text.ElideMiddle
            text: root.toastText
            color: root.toastIsError ? root.colDanger : root.colSecondary
            font.family: root.monoFamily
            font.pixelSize: 12
            font.bold: true
        }

        Timer {
            id: toastTimer
            interval: 2600
            repeat: false
            onTriggered: toastBanner.visible = false
        }
    }
}
