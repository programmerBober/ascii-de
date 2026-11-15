pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

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
        danger: "#ff5555"
    })
    property string monoFamily: "JetBrains Mono"
    property string searchFilter: ""
    property string activeCategory: "ALL"

    signal closeRequested()

    color: root.theme.panelBg
    border.color: root.theme.accent
    border.width: 2
    focus: true

    Keys.onEscapePressed: (event) => {
        root.closeRequested();
        event.accepted = true;
    }
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            root.closeRequested();
            event.accepted = true;
        }
    }

    TapHandler {
        onTapped: root.forceActiveFocus()
    }

    readonly property var allKeybinds: [
        // Launch & Search
        { category: "LAUNCH", key: "Meta + Return", action: "Terminal", desc: "Launch Kitty GPU-accelerated terminal" },
        { category: "LAUNCH", key: "Meta + Space", action: "Start Menu", desc: "Search and launch applications or commands" },
        { category: "LAUNCH", key: "Meta + B", action: "Bluetooth Menu", desc: "Open Bluetooth connect, pair, and audio device menu" },
        { category: "LAUNCH", key: "Meta + ?", action: "Shortcuts Help", desc: "Open this interactive keybind reference cheat sheet" },

        // System Settings & Customization
        { category: "SYSTEM", key: "Meta + S", action: "System Settings", desc: "ASCII-DE settings (fonts, grid, audio guard, aquarium)" },
        { category: "SYSTEM", key: "Meta + T", action: "Theme Studio", desc: "Overhaul colors, themes, ASCII / SNAPTIC Data Lens styles" },
        { category: "SYSTEM", key: "Meta + P / D", action: "Display Editor", desc: "Multi-monitor 2D visual layout and resolution arranger" },
        { category: "SYSTEM", key: "Meta + I", action: "Icon Manager", desc: "Add, edit, and organize ASCII desktop launcher icons" },
        { category: "SYSTEM", key: "Meta + V", action: "Clipboard Drawer", desc: "Open clipboard history drawer to copy & paste snippets" },
        { category: "SYSTEM", key: "Meta + N", action: "Notifications", desc: "Open notification center drawer and history" },
        { category: "SYSTEM", key: "Print / Meta+Shift+S", action: "Screenshot", desc: "Capture full screen, active window, or custom region" },
        { category: "SYSTEM", key: "Meta + L", action: "Lock Screen", desc: "Lock display with password-protected ASCII security" },
        { category: "SYSTEM", key: "Meta + Alt + Del", action: "Power & Session", desc: "Lock, logout, suspend, reboot, or power off system" },

        // Window Management
        { category: "WINDOW", key: "Alt + Tab", action: "Switch Window", desc: "Cycle focus through open desktop windows" },
        { category: "WINDOW", key: "Alt + F4 / Meta+Shift+Q", action: "Close Window", desc: "Close currently focused active window" },
        { category: "WINDOW", key: "Meta + M", action: "Minimize", desc: "Minimize focused window to desktop panel" },
        { category: "WINDOW", key: "Meta + Up", action: "Maximize", desc: "Maximize window to full workspace area" },
        { category: "WINDOW", key: "Meta + Down", action: "Restore", desc: "Restore window from maximized or snapped state" },
        { category: "WINDOW", key: "Meta + Left", action: "Snap Left", desc: "Snap active window to the left half of the display" },
        { category: "WINDOW", key: "Meta + Right", action: "Snap Right", desc: "Snap active window to the right half of the display" },
        { category: "WINDOW", key: "Meta + Shift + F", action: "Fullscreen", desc: "Toggle borderless fullscreen mode" },
        { category: "WINDOW", key: "Meta + Shift + ←", action: "Move Prev Monitor", desc: "Send active window to previous connected display" },
        { category: "WINDOW", key: "Meta + Shift + →", action: "Move Next Monitor", desc: "Send active window to next connected display" },
        { category: "WINDOW", key: "Meta + Drag (Mouse)", action: "Aero Drag & Snap", desc: "Drag window by clicking anywhere; snap to edges & corners" },

        // Workspaces & Audio
        { category: "WORKSPACE", key: "Meta + 1 .. 4", action: "Switch Workspace", desc: "Jump directly to virtual workspace 1, 2, 3, or 4" },
        { category: "SYSTEM", key: "Volume Up", action: "Volume +5%", desc: "Raise master audio output volume" },
        { category: "SYSTEM", key: "Volume Down", action: "Volume -5%", desc: "Lower master audio output volume" },
        { category: "SYSTEM", key: "Volume Mute", action: "Mute Toggle", desc: "Toggle audio output mute on or off" }
    ]

    readonly property var filteredKeybinds: {
        var q = root.searchFilter.trim().toLowerCase();
        var cat = root.activeCategory;
        var list = root.allKeybinds;
        var out = [];
        for (var i = 0; i < list.length; i++) {
            var item = list[i];
            if (cat !== "ALL" && item.category !== cat) {
                continue;
            }
            if (q.length > 0) {
                var match = item.key.toLowerCase().indexOf(q) !== -1 ||
                            item.action.toLowerCase().indexOf(q) !== -1 ||
                            item.desc.toLowerCase().indexOf(q) !== -1;
                if (!match) continue;
            }
            out.push(item);
        }
        return out;
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
                    text: "┌─[ ASCII-DE SHORTCUTS & KEYBINDINGS REFERENCE ]───────────────────┐"
                }

                Rectangle {
                    z: 2
                    width: 34
                    height: 22
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

        // Search & Category Filters
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Quick Filter Input
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 28
                color: root.theme.bg
                border.color: filterInput.activeFocus ? root.theme.accent : root.theme.muted
                border.width: 1

                RowLayout {
                    anchors { fill: parent; margins: 4 }
                    spacing: 6

                    Text {
                        font.family: root.monoFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: root.theme.accent
                        text: "SEARCH:"
                    }

                    TextInput {
                        id: filterInput
                        Layout.fillWidth: true
                        font.family: root.monoFamily
                        font.pixelSize: 11
                        color: root.theme.fg
                        clip: true
                        text: root.searchFilter
                        onTextChanged: root.searchFilter = text

                        Text {
                            visible: filterInput.text.length === 0
                            anchors.verticalCenter: parent.verticalCenter
                            font.family: root.monoFamily
                            font.pixelSize: 11
                            color: root.theme.muted
                            text: "Type key or command to filter (e.g. meta, snap, terminal)..."
                        }
                    }

                    Text {
                        visible: filterInput.text.length > 0
                        font.family: root.monoFamily
                        font.pixelSize: 10
                        color: clearMa.containsMouse ? root.theme.danger : root.theme.muted
                        text: "[CLEAR]"

                        MouseArea {
                            id: clearMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                filterInput.text = "";
                                root.searchFilter = "";
                            }
                        }
                    }
                }
            }

            // Category buttons
            Row {
                spacing: 4

                Repeater {
                    model: ["ALL", "WINDOW", "SYSTEM", "LAUNCH", "WORKSPACE"]

                    delegate: Rectangle {
                        id: catBtn
                        required property string modelData
                        width: catTxt.implicitWidth + 12
                        height: 28
                        color: root.activeCategory === modelData ? root.theme.accent : (catMa.containsMouse ? root.theme.bg : "transparent")
                        border.color: root.activeCategory === modelData ? root.theme.accent : root.theme.muted
                        border.width: 1

                        Text {
                            id: catTxt
                            anchors.centerIn: parent
                            font.family: root.monoFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: root.activeCategory === catBtn.modelData ? root.theme.bg : root.theme.fg
                            text: "[" + catBtn.modelData + "]"
                        }

                        MouseArea {
                            id: catMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeCategory = catBtn.modelData;
                                root.forceActiveFocus();
                            }
                        }
                    }
                }
            }
        }

        // Table Header
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 22
            color: root.theme.bg
            border.color: root.theme.muted
            border.width: 1

            RowLayout {
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                spacing: 8

                Text {
                    Layout.preferredWidth: 200
                    font.family: root.monoFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: root.theme.accent
                    text: "SHORTCUT"
                }

                Text {
                    Layout.preferredWidth: 160
                    font.family: root.monoFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: root.theme.secondary
                    text: "ACTION"
                }

                Text {
                    Layout.fillWidth: true
                    font.family: root.monoFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: root.theme.muted
                    text: "DESCRIPTION"
                }
            }
        }

        // Scrollable List of Keybinds
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: root.theme.bg
            border.color: root.theme.muted
            border.width: 1
            clip: true

            ListView {
                id: keyListView
                anchors.fill: parent
                model: root.filteredKeybinds
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {
                    active: true
                    policy: ScrollBar.AsNeeded
                }

                delegate: Rectangle {
                    id: rowDelegate
                    required property var modelData
                    required property int index
                    width: keyListView.width
                    height: 28
                    color: rowMa.containsMouse ? root.theme.panelBg : (index % 2 === 0 ? "transparent" : "#08090a")

                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        spacing: 8

                        // Shortcut Key Badge
                        Rectangle {
                            Layout.preferredWidth: 200
                            Layout.fillHeight: true
                            color: "transparent"

                            RowLayout {
                                anchors { fill: parent; verticalCenter: parent.verticalCenter }
                                spacing: 4

                                Rectangle {
                                    implicitWidth: keyLabel.implicitWidth + 10
                                    implicitHeight: 20
                                    color: root.theme.panelBg
                                    border.color: rowMa.containsMouse ? root.theme.accent : root.theme.muted
                                    border.width: 1

                                    Text {
                                        id: keyLabel
                                        anchors.centerIn: parent
                                        font.family: root.monoFamily
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: root.theme.accent
                                        text: String(rowDelegate.modelData.key)
                                    }
                                }
                            }
                        }

                        // Action Name
                        Text {
                            Layout.preferredWidth: 160
                            elide: Text.ElideRight
                            font.family: root.monoFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: rowMa.containsMouse ? root.theme.accent : root.theme.secondary
                            text: String(rowDelegate.modelData.action)
                        }

                        // Description
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            font.family: root.monoFamily
                            font.pixelSize: 11
                            color: rowMa.containsMouse ? root.theme.fg : root.theme.muted
                            text: String(rowDelegate.modelData.desc)
                        }
                    }

                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.forceActiveFocus()
                    }
                }

                Text {
                    visible: root.filteredKeybinds.length === 0
                    anchors.centerIn: parent
                    font.family: root.monoFamily
                    font.pixelSize: 12
                    color: root.theme.muted
                    text: "(no shortcuts match '" + root.searchFilter + "')"
                }
            }
        }

        // Footer Bar
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                font.family: root.monoFamily
                font.pixelSize: 10
                color: root.theme.muted
                text: "TIP: Press Meta+? or Esc anytime to toggle. Drag titlebar to reposition; double-click to center."
            }

            Rectangle {
                implicitWidth: closeBtnTxt.implicitWidth + 16
                implicitHeight: 24
                color: closeBtnMa.containsMouse ? root.theme.accent : root.theme.bg
                border.color: root.theme.accent
                border.width: 1

                Text {
                    id: closeBtnTxt
                    anchors.centerIn: parent
                    font.family: root.monoFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: closeBtnMa.containsMouse ? root.theme.bg : root.theme.accent
                    text: "[ CLOSE (Esc) ]"
                }

                MouseArea {
                    id: closeBtnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }
    }
}
