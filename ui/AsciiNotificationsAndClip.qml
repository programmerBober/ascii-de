pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    // --- Public interface contract ---
    property var activeToasts: []
    property var history: []
    property int unreadCount: 0
    property var clipboardEntries: []

    property bool notificationsDrawerOpen: false
    property bool clipboardOpen: false
    property int topBarHeight: 28

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

    readonly property bool hasOpenModal: root.notificationsDrawerOpen || root.clipboardOpen

    signal dismissToastRequested(int id)
    signal removeHistoryRequested(int id)
    signal clearHistoryRequested()
    signal invokeActionRequested(int id, string actionKey)
    signal markAllReadRequested()
    signal copyClipboardRequested(int idx)
    signal removeClipboardRequested(int idx)
    signal clearClipboardRequested()
    signal closeRequested()

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

    property string clipQuery: ""
    property int clipSelectedRow: 0

    readonly property var visibleToasts: {
        const list = root.activeToasts || [];
        return list.slice(0, 4);
    }

    readonly property var filteredClipboard: {
        const list = root.clipboardEntries || [];
        const q = root.clipQuery.trim().toLowerCase();
        const out = [];
        for (let i = 0; i < list.length; i++) {
            const raw = String(list[i] || "");
            if (q.length === 0 || raw.toLowerCase().indexOf(q) !== -1) {
                const oneLine = raw.replace(/\r?\n/g, " ↵ ");
                out.push({
                    rawIndex: i,
                    text: raw,
                    preview: oneLine.length > 140 ? (oneLine.slice(0, 137) + "...") : oneLine
                });
            }
        }
        return out;
    }

    visible: root.hasOpenModal || root.visibleToasts.length > 0

    function urgencyColor(u) {
        const val = Number(u);
        if (val >= 2) return root.colDanger;
        if (val <= 0) return root.colMuted;
        return root.colAccent;
    }

    function urgencyLabel(u) {
        const val = Number(u);
        if (val >= 2) return "[CRIT]";
        if (val <= 0) return "[LOW]";
        return "[INFO]";
    }

    onNotificationsDrawerOpenChanged: {
        if (notificationsDrawerOpen) {
            root.markAllReadRequested();
            if (!clipboardOpen) {
                modalLayer.forceActiveFocus();
            }
        }
    }

    onClipboardOpenChanged: {
        if (clipboardOpen) {
            clipQuery = "";
            clipSelectedRow = 0;
            clipSearchInput.forceActiveFocus();
        } else {
            clipQuery = "";
        }
    }

    // --- Layer A: Modal Scrim + Drawer + Clipboard History (only when open) ---
    Item {
        id: modalLayer
        anchors.fill: parent
        visible: root.hasOpenModal
        enabled: root.hasOpenModal
        focus: root.hasOpenModal

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                event.accepted = true;
                root.closeRequested();
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(root.colBg, 0.45)

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeRequested()
            }
        }

        // Notification Center Drawer (right-docked)
        Rectangle {
            id: drawerPanel
            visible: root.notificationsDrawerOpen
            anchors.top: parent.top
            anchors.topMargin: root.topBarHeight + 8
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 36
            width: Math.min(420, Math.max(240, parent.width - 24))
            color: Qt.alpha(root.colPanelBg, 0.97)
            border.width: root.themeBorderWidth
            border.color: root.colAccent
            radius: Math.min(8, root.themeRadius)

            // Shield clicks inside drawer from closing modalLayer
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: (mouse) => { mouse.accepted = true; }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: (root.isDataLens ? "[ ⊡ NOTIFICATIONS (" : "[ ◈ NOTIFICATIONS (")
                              + (root.history ? root.history.length : 0) + ") ]"
                        color: root.colAccent
                        font.family: root.monoFamily
                        font.pixelSize: 12
                        font.bold: true
                    }

                    Rectangle {
                        implicitWidth: clearHistText.implicitWidth + 12
                        implicitHeight: 24
                        color: clearHistMouse.containsMouse ? Qt.alpha(root.colDanger, 0.2) : root.colBg
                        border.width: 1
                        border.color: root.colDanger
                        radius: Math.min(4, root.themeRadius)

                        Text {
                            id: clearHistText
                            anchors.centerIn: parent
                            text: "[ CLEAR ]"
                            color: root.colDanger
                            font.family: root.monoFamily
                            font.pixelSize: 10
                            font.bold: true
                        }

                        MouseArea {
                            id: clearHistMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.clearHistoryRequested()
                        }
                    }

                    Rectangle {
                        implicitWidth: closeDrawerText.implicitWidth + 12
                        implicitHeight: 24
                        color: closeDrawerMouse.containsMouse ? root.colAccent : root.colBg
                        border.width: 1
                        border.color: root.colMuted
                        radius: Math.min(4, root.themeRadius)

                        Text {
                            id: closeDrawerText
                            anchors.centerIn: parent
                            text: "[ X ]"
                            color: closeDrawerMouse.containsMouse ? root.colBg : root.colFg
                            font.family: root.monoFamily
                            font.pixelSize: 10
                            font.bold: true
                        }

                        MouseArea {
                            id: closeDrawerMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeRequested()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Qt.alpha(root.colMuted, 0.4)
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.centerIn: parent
                        visible: !root.history || root.history.length === 0
                        text: "[ NO NOTIFICATIONS IN HISTORY ]"
                        color: root.colMuted
                        font.family: root.monoFamily
                        font.pixelSize: 11
                    }

                    ListView {
                        id: historyList
                        anchors.fill: parent
                        clip: true
                        spacing: 6
                        model: root.history || []

                        delegate: Rectangle {
                            id: histCard
                            required property var modelData
                            required property int index

                            width: historyList.width
                            implicitHeight: histCol.implicitHeight + 16
                            color: root.colBg
                            border.width: 1
                            border.color: root.urgencyColor(modelData.urgency)
                            radius: Math.min(6, root.themeRadius)

                            ColumnLayout {
                                id: histCol
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Text {
                                        text: root.urgencyLabel(histCard.modelData.urgency)
                                        color: root.urgencyColor(histCard.modelData.urgency)
                                        font.family: root.monoFamily
                                        font.pixelSize: 10
                                        font.bold: true
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        text: String(histCard.modelData.appName || "System")
                                        color: root.colSecondary
                                        font.family: root.monoFamily
                                        font.pixelSize: 11
                                        font.bold: true
                                    }

                                    Text {
                                        text: String(histCard.modelData.timestamp || "")
                                        color: root.colMuted
                                        font.family: root.monoFamily
                                        font.pixelSize: 10
                                    }

                                    Rectangle {
                                        implicitWidth: 20
                                        implicitHeight: 18
                                        color: rmHistMouse.containsMouse ? root.colDanger : "transparent"
                                        border.width: 1
                                        border.color: rmHistMouse.containsMouse ? root.colDanger : root.colMuted
                                        radius: Math.min(3, root.themeRadius)

                                        Text {
                                            anchors.centerIn: parent
                                            text: "x"
                                            color: rmHistMouse.containsMouse ? root.colBg : root.colMuted
                                            font.family: root.monoFamily
                                            font.pixelSize: 10
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: rmHistMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.removeHistoryRequested(Number(histCard.modelData.id || 0))
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                    textFormat: Text.PlainText
                                    text: String(histCard.modelData.summary || "")
                                    color: root.colFg
                                    font.family: root.monoFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                    visible: text.length > 0
                                }

                                Text {
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                    textFormat: Text.PlainText
                                    text: String(histCard.modelData.body || "")
                                    color: Qt.alpha(root.colFg, 0.82)
                                    font.family: root.monoFamily
                                    font.pixelSize: 10
                                    visible: text.length > 0
                                }
                            }
                        }
                    }
                }
            }
        }

        // Clipboard History Modal (centered)
        Rectangle {
            id: clipboardModal
            visible: root.clipboardOpen
            anchors.centerIn: parent
            width: Math.min(560, Math.max(260, parent.width - 32))
            height: Math.min(480, Math.max(220, parent.height - 80))
            color: Qt.alpha(root.colPanelBg, 0.98)
            border.width: root.themeBorderWidth
            border.color: root.colSecondary
            radius: Math.min(8, root.themeRadius)

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: (mouse) => { mouse.accepted = true; }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: "[ ⊡ CLIPBOARD HISTORY (" + (root.clipboardEntries ? root.clipboardEntries.length : 0) + "/25) ]"
                        color: root.colSecondary
                        font.family: root.monoFamily
                        font.pixelSize: 12
                        font.bold: true
                    }

                    Rectangle {
                        implicitWidth: clipClearText.implicitWidth + 12
                        implicitHeight: 24
                        color: clipClearMouse.containsMouse ? Qt.alpha(root.colDanger, 0.2) : root.colBg
                        border.width: 1
                        border.color: root.colDanger
                        radius: Math.min(4, root.themeRadius)

                        Text {
                            id: clipClearText
                            anchors.centerIn: parent
                            text: "[ CLEAR ]"
                            color: root.colDanger
                            font.family: root.monoFamily
                            font.pixelSize: 10
                            font.bold: true
                        }

                        MouseArea {
                            id: clipClearMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.clearClipboardRequested()
                        }
                    }

                    Rectangle {
                        implicitWidth: clipEscText.implicitWidth + 12
                        implicitHeight: 24
                        color: clipEscMouse.containsMouse ? root.colAccent : root.colBg
                        border.width: 1
                        border.color: root.colMuted
                        radius: Math.min(4, root.themeRadius)

                        Text {
                            id: clipEscText
                            anchors.centerIn: parent
                            text: "[ ESC ]"
                            color: clipEscMouse.containsMouse ? root.colBg : root.colFg
                            font.family: root.monoFamily
                            font.pixelSize: 10
                            font.bold: true
                        }

                        MouseArea {
                            id: clipEscMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeRequested()
                        }
                    }
                }

                // Filter input
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 32
                    color: root.colBg
                    border.width: 1
                    border.color: clipSearchInput.activeFocus ? root.colAccent : root.colMuted
                    radius: Math.min(4, root.themeRadius)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 6

                        Text {
                            text: ">"
                            color: root.colAccent
                            font.family: root.monoFamily
                            font.pixelSize: 12
                            font.bold: true
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: clipSearchInput.text.length === 0
                                text: "filter clipboard entries..."
                                color: root.colMuted
                                font.family: root.monoFamily
                                font.pixelSize: 11
                            }

                            TextInput {
                                id: clipSearchInput
                                anchors.fill: parent
                                verticalAlignment: TextInput.AlignVCenter
                                color: root.colFg
                                selectionColor: root.colAccent
                                selectedTextColor: root.colBg
                                font.family: root.monoFamily
                                font.pixelSize: 11
                                clip: true
                                onTextChanged: {
                                    root.clipQuery = text;
                                    root.clipSelectedRow = 0;
                                }
                                Keys.onPressed: (event) => {
                                    if (event.key === Qt.Key_Escape) {
                                        event.accepted = true;
                                        root.closeRequested();
                                    } else if (event.key === Qt.Key_Down) {
                                        event.accepted = true;
                                        if (root.filteredClipboard.length > 0) {
                                            root.clipSelectedRow = Math.min(root.filteredClipboard.length - 1, root.clipSelectedRow + 1);
                                        }
                                    } else if (event.key === Qt.Key_Up) {
                                        event.accepted = true;
                                        root.clipSelectedRow = Math.max(0, root.clipSelectedRow - 1);
                                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        event.accepted = true;
                                        if (root.filteredClipboard.length > 0) {
                                            const row = root.filteredClipboard[Math.min(root.clipSelectedRow, root.filteredClipboard.length - 1)];
                                            root.copyClipboardRequested(row.rawIndex);
                                            root.closeRequested();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.centerIn: parent
                        visible: root.filteredClipboard.length === 0
                        text: root.clipQuery.length > 0 ? "[ NO MATCHING CLIPBOARD ENTRIES ]" : "[ CLIPBOARD HISTORY EMPTY ]"
                        color: root.colMuted
                        font.family: root.monoFamily
                        font.pixelSize: 11
                    }

                    ListView {
                        id: clipList
                        anchors.fill: parent
                        clip: true
                        spacing: 5
                        model: root.filteredClipboard

                        delegate: Rectangle {
                            id: clipCard
                            required property var modelData
                            required property int index

                            readonly property bool isRowActive: clipCardMouse.containsMouse || root.clipSelectedRow === index
                            width: clipList.width
                            implicitHeight: Math.max(34, clipPreviewText.implicitHeight + 14)
                            color: isRowActive ? Qt.alpha(root.colSecondary, 0.14) : root.colBg
                            border.width: 1
                            border.color: isRowActive ? root.colSecondary : Qt.alpha(root.colMuted, 0.55)
                            radius: Math.min(4, root.themeRadius)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Text {
                                    text: "#" + (clipCard.modelData.rawIndex + 1)
                                    color: root.colAccent
                                    font.family: root.monoFamily
                                    font.pixelSize: 10
                                    font.bold: true
                                }

                                Text {
                                    id: clipPreviewText
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                    text: String(clipCard.modelData.preview || "")
                                    color: root.colFg
                                    font.family: root.monoFamily
                                    font.pixelSize: 11
                                }

                                Rectangle {
                                    z: 2
                                    implicitWidth: 20
                                    implicitHeight: 18
                                    color: clipRmMouse.containsMouse ? root.colDanger : "transparent"
                                    border.width: 1
                                    border.color: clipRmMouse.containsMouse ? root.colDanger : root.colMuted
                                    radius: Math.min(3, root.themeRadius)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "x"
                                        color: clipRmMouse.containsMouse ? root.colBg : root.colMuted
                                        font.family: root.monoFamily
                                        font.pixelSize: 10
                                        font.bold: true
                                    }

                                    MouseArea {
                                        id: clipRmMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.removeClipboardRequested(clipCard.modelData.rawIndex)
                                    }
                                }
                            }

                            MouseArea {
                                id: clipCardMouse
                                z: 1
                                anchors.fill: parent
                                anchors.rightMargin: 28
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.copyClipboardRequested(clipCard.modelData.rawIndex);
                                    root.closeRequested();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // --- Layer B: Top-Right Live Notification Toast Stack (non-blocking) ---
    Column {
        id: toastStack
        visible: root.visibleToasts.length > 0 && !root.notificationsDrawerOpen
        anchors.top: parent.top
        anchors.topMargin: root.topBarHeight + 10
        anchors.right: parent.right
        anchors.rightMargin: 14
        width: Math.min(370, Math.max(240, root.width - 28))
        spacing: 8

        Repeater {
            model: root.visibleToasts

            delegate: Rectangle {
                id: toastCard
                required property var modelData
                required property int index

                width: toastStack.width
                implicitHeight: toastCol.implicitHeight + 16
                color: Qt.alpha(root.colPanelBg, 0.96)
                border.width: root.themeBorderWidth
                border.color: root.urgencyColor(modelData.urgency)
                radius: Math.min(6, root.themeRadius)

                ColumnLayout {
                    id: toastCol
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: root.urgencyLabel(toastCard.modelData.urgency)
                            color: root.urgencyColor(toastCard.modelData.urgency)
                            font.family: root.monoFamily
                            font.pixelSize: 10
                            font.bold: true
                        }

                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: String(toastCard.modelData.appName || "System")
                            color: root.colSecondary
                            font.family: root.monoFamily
                            font.pixelSize: 11
                            font.bold: true
                        }

                        Text {
                            text: String(toastCard.modelData.timestamp || "")
                            color: root.colMuted
                            font.family: root.monoFamily
                            font.pixelSize: 10
                        }

                        Rectangle {
                            implicitWidth: 20
                            implicitHeight: 18
                            color: toastDismissMouse.containsMouse ? root.colDanger : root.colBg
                            border.width: 1
                            border.color: toastDismissMouse.containsMouse ? root.colDanger : root.colMuted
                            radius: Math.min(3, root.themeRadius)

                            Text {
                                anchors.centerIn: parent
                                text: "x"
                                color: toastDismissMouse.containsMouse ? root.colBg : root.colFg
                                font.family: root.monoFamily
                                font.pixelSize: 10
                                font.bold: true
                            }

                            MouseArea {
                                id: toastDismissMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.dismissToastRequested(Number(toastCard.modelData.id || 0))
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                        text: String(toastCard.modelData.summary || "")
                        color: root.colFg
                        font.family: root.monoFamily
                        font.pixelSize: 11
                        font.bold: true
                        visible: text.length > 0
                    }

                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                        maximumLineCount: 4
                        elide: Text.ElideRight
                        text: String(toastCard.modelData.body || "")
                        color: Qt.alpha(root.colFg, 0.85)
                        font.family: root.monoFamily
                        font.pixelSize: 10
                        visible: text.length > 0
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: Boolean(toastCard.modelData.actions && toastCard.modelData.actions.length > 0)

                        Repeater {
                            model: toastCard.modelData.actions || []

                            delegate: Rectangle {
                                id: actionChip
                                required property var modelData

                                implicitWidth: actionLabel.implicitWidth + 12
                                implicitHeight: 22
                                color: actionMouse.containsMouse ? root.colAccent : root.colBg
                                border.width: 1
                                border.color: root.colAccent
                                radius: Math.min(4, root.themeRadius)

                                Text {
                                    id: actionLabel
                                    anchors.centerIn: parent
                                    text: "[ " + String(actionChip.modelData.label || actionChip.modelData.key || "OK") + " ]"
                                    color: actionMouse.containsMouse ? root.colBg : root.colAccent
                                    font.family: root.monoFamily
                                    font.pixelSize: 10
                                    font.bold: true
                                }

                                MouseArea {
                                    id: actionMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.invokeActionRequested(
                                        Number(toastCard.modelData.id || 0),
                                        String(actionChip.modelData.key || ""))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
