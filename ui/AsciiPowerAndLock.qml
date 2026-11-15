pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    // --- Public interface contract ---
    property bool locked: false
    property bool powerDialogOpen: false
    property bool isPrimary: true
    property string screenName: ""
    property string username: ""
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
        cornerRadius: 0,
        borderWidth: 1,
        fontFamily: "JetBrains Mono",
        chromeStyle: "ascii",
        impactFlash: false,
        originSmear: false
    })
    property string monoFamily: (theme && theme.fontFamily) ? theme.fontFamily : "JetBrains Mono"
    property bool clock24h: true
    property bool clockShowSeconds: true

    // --- Internal auth / confirmation state ---
    property bool verifying: false
    property string lockError: ""
    property string confirmAction: ""
    property string powerStatus: ""
    property real shakeOffset: 0
    property string nowClockText: "00:00:00"
    property string nowDateText: "---- -- --"

    signal unlocked()
    signal lockRequested()
    signal closePowerDialog()
    signal logoutRequested()
    signal verifyPasswordRequested(string password)
    signal actionTriggered(string action)

    visible: root.locked || (root.powerDialogOpen && root.isPrimary)

    // --- Theme tokens ---
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

    function getBackend() {
        // qmllint disable unqualified
        if (typeof Backend !== "undefined") return Backend;
        // qmllint enable unqualified
        return null;
    }

    function pad2(n) {
        return (n < 10 ? "0" : "") + n;
    }

    function updateClock() {
        var d = new Date();
        var hh = d.getHours();
        var suffix = "";
        if (!root.clock24h) {
            suffix = hh >= 12 ? " PM" : " AM";
            hh = hh % 12;
            if (hh === 0) hh = 12;
        }
        var timeStr = pad2(hh) + ":" + pad2(d.getMinutes());
        if (root.clockShowSeconds) {
            timeStr += ":" + pad2(d.getSeconds());
        }
        root.nowClockText = timeStr + suffix;
        var days = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
        var months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
        root.nowDateText = days[d.getDay()] + " " + d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate())
                           + " (" + months[d.getMonth()] + ")";
    }

    function focusPrimaryTrap() {
        if (root.locked && root.isPrimary) {
            Qt.callLater(function() {
                if (root.locked && root.isPrimary) {
                    pwInput.forceActiveFocus();
                }
            });
        } else if (root.powerDialogOpen && root.isPrimary && !root.locked) {
            Qt.callLater(function() {
                if (root.powerDialogOpen && root.isPrimary && !root.locked) {
                    powerPanel.forceActiveFocus();
                }
            });
        }
    }

    function submitPassword() {
        if (root.verifying) return;
        var candidate = pwInput.text;
        if (!candidate || candidate.length === 0) {
            handleVerifyResult(false, "ENTER PASSWORD TO UNLOCK");
            return;
        }
        root.verifying = true;
        root.lockError = "";
        root.verifyPasswordRequested(candidate);

        var b = getBackend();
        if (b && typeof b.verifyPasswordAsync === "function") {
            b.verifyPasswordAsync(candidate, "power_verify");
        }
    }

    function handleVerifyResult(ok, errMsg) {
        root.verifying = false;
        if (ok) {
            pwInput.text = "";
            root.lockError = "";
            root.shakeOffset = 0;
            root.unlocked();
        } else {
            pwInput.text = "";
            root.lockError = (errMsg && errMsg.length > 0) ? errMsg : "ACCESS DENIED — INVALID PASSWORD";
            shakeAnim.restart();
            focusPrimaryTrap();
        }
    }

    function requestConfirm(action) {
        root.confirmAction = action;
        root.powerStatus = "";
    }

    function executePowerAction(action) {
        root.confirmAction = "";
        root.actionTriggered(action);
        if (action === "lock") {
            root.closePowerDialog();
            root.lockRequested();
            return;
        }
        if (action === "logout") {
            root.closePowerDialog();
            root.logoutRequested();
            const bOut = getBackend();
            if (bOut && typeof bOut.quitCompositor === "function") {
                bOut.quitCompositor();
            }
            return;
        }
        var b = getBackend();
        if (b && typeof b.runBackendAsync === "function") {
            root.powerStatus = "EXECUTING " + action.toUpperCase() + "...";
            b.runBackendAsync(["power", action], "power_action");
        } else {
            root.powerStatus = "BACKEND UNAVAILABLE";
        }
    }

    function safeJsonParse(raw) {
        if (!raw || typeof raw !== "string") return null;
        var t = raw.trim();
        if (!t.length) return null;
        try {
            return JSON.parse(t);
        } catch (e) {
            return null;
        }
    }

    Component.onCompleted: updateClock()

    onLockedChanged: {
        verifying = false;
        lockError = "";
        shakeOffset = 0;
        pwInput.text = "";
        if (locked) {
            confirmAction = "";
            updateClock();
            focusPrimaryTrap();
        }
    }

    onPowerDialogOpenChanged: {
        confirmAction = "";
        powerStatus = "";
        if (powerDialogOpen && !locked) {
            focusPrimaryTrap();
        }
    }

    Timer {
        id: clockTimer
        interval: 1000
        repeat: true
        running: root.locked && root.isPrimary
        onTriggered: root.updateClock()
    }

    Connections {
        target: root.getBackend()
        ignoreUnknownSignals: true

        function onBackendResult(tag, jsonOutput) {
            if (tag === "power_verify" && root.locked && root.isPrimary) {
                const parsed = root.safeJsonParse(jsonOutput);
                const ok = Boolean(parsed && parsed.ok === true);
                const err = (parsed && parsed.error) ? String(parsed.error) : "";
                root.handleVerifyResult(ok, err);
            } else if (tag === "power_action" && root.isPrimary) {
                const act = root.safeJsonParse(jsonOutput);
                if (act && act.ok) {
                    root.closePowerDialog();
                    root.powerStatus = "";
                } else {
                    root.powerStatus = (act && act.error) ? String(act.error) : "ACTION FAILED";
                }
            }
        }
    }

    // =========================================================================
    // 1. MULTI-MONITOR SAFE LOCK SCREEN OVERLAY
    // =========================================================================
    Rectangle {
        id: lockOverlay
        anchors.fill: parent
        visible: root.locked
        z: 20
        color: root.isDataLens ? "#080b18" : root.colBg
        opacity: 0.98

        // Hard pointer grab across all outputs when locked
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            preventStealing: true
            onPressed: (mouse) => {
                mouse.accepted = true;
                if (root.isPrimary) {
                    pwInput.forceActiveFocus();
                }
            }
            onWheel: (wheel) => { wheel.accepted = true; }
        }

        // Subtle ASCII / void framing border
        Rectangle {
            anchors { fill: parent; margins: 14 }
            color: "transparent"
            border.color: root.isPrimary ? root.colAccent : root.colMuted
            border.width: 1
            opacity: root.isPrimary ? 0.45 : 0.28
        }

        // Secondary monitor lock curtain (no duplicate password box)
        Column {
            visible: !root.isPrimary
            anchors.centerIn: parent
            spacing: 8

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                font.family: root.monoFamily
                font.pixelSize: 13
                font.bold: true
                color: root.colMuted
                text: "┌────────────────────────────────────────┐"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                font.family: root.monoFamily
                font.pixelSize: 13
                font.bold: true
                color: root.colAccent
                text: "[ DISPLAY: " + (root.screenName.length > 0 ? root.screenName : "SECONDARY") + " :: LOCKED ]"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                font.family: root.monoFamily
                font.pixelSize: 11
                color: root.colMuted
                text: "UNLOCK ON PRIMARY DISPLAY"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                font.family: root.monoFamily
                font.pixelSize: 13
                font.bold: true
                color: root.colMuted
                text: "└────────────────────────────────────────┘"
            }
        }

        // Primary monitor interactive lock prompt
        Item {
            id: lockCardHolder
            visible: root.isPrimary
            width: Math.min(460, Math.max(260, parent.width - 48))
            height: Math.min(Math.max(200, parent.height - 32), lockCardCol.implicitHeight + 36)
            anchors.verticalCenter: parent.verticalCenter
            x: Math.round((parent.width - width) * 0.5 + root.shakeOffset)

            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: root; property: "shakeOffset"; to: -12; duration: 40 }
                NumberAnimation { target: root; property: "shakeOffset"; to: 12; duration: 45 }
                NumberAnimation { target: root; property: "shakeOffset"; to: -8; duration: 45 }
                NumberAnimation { target: root; property: "shakeOffset"; to: 6; duration: 40 }
                NumberAnimation { target: root; property: "shakeOffset"; to: 0; duration: 40 }
            }

            Rectangle {
                id: lockCard
                anchors.fill: parent
                color: root.colPanelBg
                radius: root.themeRadius
                border.color: root.lockError.length > 0 ? root.colDanger : root.colAccent
                border.width: root.isDataLens ? 2 : root.themeBorderWidth

                Flickable {
                    anchors { fill: parent; margins: 18 }
                    clip: true
                    contentWidth: width
                    contentHeight: lockCardCol.implicitHeight
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: lockCardCol
                        width: parent.width
                        spacing: 12

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        font.family: root.monoFamily
                        font.pixelSize: 12
                        font.bold: true
                        color: root.colAccent
                        text: "┌─[ ASCII-DE :: SESSION LOCKED ]─┐"
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        font.family: root.monoFamily
                        font.pixelSize: 34
                        font.bold: true
                        color: root.colFg
                        text: root.nowClockText
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        font.family: root.monoFamily
                        font.pixelSize: 11
                        color: root.colMuted
                        text: root.nowDateText
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        color: root.colBg
                        border.color: root.colSecondary
                        border.width: 1
                        radius: Math.max(0, root.themeRadius - 4)

                        Text {
                            anchors.centerIn: parent
                            font.family: root.monoFamily
                            font.pixelSize: 12
                            font.bold: true
                            color: root.colSecondary
                            text: (root.username.length > 0 ? ("[ USER: " + root.username) : "[ SESSION LOCK")
                                  + (root.screenName.length > 0 ? " | " + root.screenName : "")
                                  + " ]"
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        font.family: root.monoFamily
                        font.pixelSize: 11
                        color: root.colMuted
                        text: "PASSWORD (unix_chkpwd):"
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        color: root.colBg
                        radius: Math.max(0, root.themeRadius - 4)
                        border.color: root.lockError.length > 0
                                      ? root.colDanger
                                      : (pwInput.activeFocus ? root.colAccent : root.colMuted)
                        border.width: pwInput.activeFocus ? 2 : 1

                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            spacing: 6

                            Text {
                                font.family: root.monoFamily
                                font.pixelSize: 12
                                font.bold: true
                                color: root.colAccent
                                text: ">"
                            }

                            TextInput {
                                id: pwInput
                                Layout.fillWidth: true
                                font.family: root.monoFamily
                                font.pixelSize: 13
                                color: root.colFg
                                selectionColor: root.colAccent
                                selectedTextColor: root.colBg
                                echoMode: TextInput.Password
                                passwordCharacter: "•"
                                clip: true
                                enabled: !root.verifying
                                focus: root.locked && root.isPrimary

                                onActiveFocusChanged: {
                                    if (!activeFocus && root.locked && root.isPrimary) {
                                        root.focusPrimaryTrap();
                                    }
                                }

                                Keys.onReturnPressed: root.submitPassword()
                                Keys.onEnterPressed: root.submitPassword()
                                Keys.onEscapePressed: {
                                    pwInput.text = "";
                                    root.lockError = "";
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: root.lockError.length > 0
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        font.family: root.monoFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: root.colDanger
                        text: "[ ! ] " + root.lockError
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            radius: Math.max(0, root.themeRadius - 4)
                            color: unlockMa.containsMouse && !root.verifying ? root.colAccent : root.colBg
                            border.color: root.verifying ? root.colMuted : root.colAccent
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                font.family: root.monoFamily
                                font.pixelSize: 12
                                font.bold: true
                                color: unlockMa.containsMouse && !root.verifying ? root.colBg : root.colAccent
                                text: root.verifying ? "[ VERIFYING... ]" : "[ UNLOCK ]"
                            }

                            MouseArea {
                                id: unlockMa
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !root.verifying
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.submitPassword()
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 92
                            Layout.preferredHeight: 32
                            radius: Math.max(0, root.themeRadius - 4)
                            color: clrMa.containsMouse ? root.colMuted : root.colBg
                            border.color: root.colMuted
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                font.family: root.monoFamily
                                font.pixelSize: 11
                                color: clrMa.containsMouse ? root.colBg : root.colFg
                                text: "[ CLEAR ]"
                            }

                            MouseArea {
                                id: clrMa
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !root.verifying
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    pwInput.text = "";
                                    root.lockError = "";
                                    pwInput.forceActiveFocus();
                                }
                            }
                        }
                    }
                    }
                }
            }
        }
    }

    // =========================================================================
    // 2. POWER & SESSION DIALOG
    // =========================================================================
    Item {
        id: powerOverlay
        anchors.fill: parent
        visible: !root.locked && root.powerDialogOpen && root.isPrimary
        z: 10

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.58
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (root.confirmAction.length > 0) {
                    root.confirmAction = "";
                } else {
                    root.closePowerDialog();
                }
            }
        }

        Rectangle {
            id: powerPanel
            width: Math.min(440, Math.max(260, parent.width - 40))
            height: Math.min(Math.max(220, parent.height - 32), powerCol.implicitHeight + 24)
            anchors.centerIn: parent
            color: root.colPanelBg
            radius: root.themeRadius
            border.color: root.colAccent
            border.width: root.isDataLens ? 2 : root.themeBorderWidth
            focus: !root.locked && root.powerDialogOpen && root.isPrimary

            Keys.onEscapePressed: (event) => {
                event.accepted = true;
                if (root.confirmAction.length > 0) {
                    root.confirmAction = "";
                } else {
                    root.closePowerDialog();
                }
            }

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_L) {
                    event.accepted = true;
                    root.executePowerAction("lock");
                }
            }

            MouseArea {
                anchors.fill: parent
            }

            Flickable {
                anchors { fill: parent; margins: 12 }
                clip: true
                contentWidth: width
                contentHeight: powerCol.implicitHeight
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: powerCol
                    width: parent.width
                    spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        font.family: root.monoFamily
                        font.pixelSize: 12
                        font.bold: true
                        color: root.colAccent
                        text: "┌─[ SESSION & POWER CONTROL ]───────────┐"
                    }

                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 22
                        color: pCloseMa.containsMouse ? root.colDanger : root.colBg
                        border.color: root.colDanger
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            font.family: root.monoFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: pCloseMa.containsMouse ? root.colBg : root.colDanger
                            text: "[✕]"
                        }

                        MouseArea {
                            id: pCloseMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closePowerDialog()
                        }
                    }
                }

                Repeater {
                    model: [
                        { id: "lock",     label: "[ 🔒 LOCK (Meta+L) ]", hint: "PAM / unix_chkpwd",  danger: false, confirm: false },
                        { id: "logout",   label: "[ ⏻ LOGOUT        ]", hint: "Exit compositor",    danger: false, confirm: true },
                        { id: "suspend",  label: "[ ☾ SUSPEND       ]", hint: "systemctl suspend",  danger: false, confirm: true },
                        { id: "reboot",   label: "[ ↻ REBOOT        ]", hint: "systemctl reboot",   danger: true,  confirm: true },
                        { id: "poweroff", label: "[ ⏻ SHUTDOWN      ]", hint: "systemctl poweroff", danger: true,  confirm: true }
                    ]

                    delegate: Rectangle {
                        id: actDel
                        required property var modelData
                        readonly property bool isArmed: root.confirmAction === modelData.id
                        readonly property color btnColor: modelData.danger ? root.colDanger : root.colAccent
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: Math.max(0, root.themeRadius - 5)
                        color: isArmed || actMa.containsMouse ? btnColor : root.colBg
                        border.color: btnColor
                        border.width: 1

                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            spacing: 8

                            Text {
                                Layout.fillWidth: true
                                font.family: root.monoFamily
                                font.pixelSize: 12
                                font.bold: true
                                color: actDel.isArmed || actMa.containsMouse ? root.colBg : actDel.btnColor
                                text: actDel.modelData.label
                            }

                            Text {
                                font.family: root.monoFamily
                                font.pixelSize: 10
                                color: actDel.isArmed || actMa.containsMouse ? root.colBg : root.colMuted
                                text: actDel.modelData.hint
                            }
                        }

                        MouseArea {
                            id: actMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (actDel.modelData.confirm) {
                                    root.requestConfirm(actDel.modelData.id);
                                } else {
                                    root.executePowerAction(actDel.modelData.id);
                                }
                            }
                        }
                    }
                }

                // Inline confirmation bar for destructive / session-ending actions
                Rectangle {
                    Layout.fillWidth: true
                    visible: root.confirmAction.length > 0
                    Layout.preferredHeight: 36
                    radius: Math.max(0, root.themeRadius - 5)
                    color: root.colBg
                    border.color: root.colDanger
                    border.width: 1

                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            font.family: root.monoFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: root.colDanger
                            text: "CONFIRM " + root.confirmAction.toUpperCase() + "?"
                        }

                        Rectangle {
                            Layout.preferredWidth: 108
                            Layout.preferredHeight: 24
                            color: yesMa.containsMouse ? root.colDanger : root.colPanelBg
                            border.color: root.colDanger
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                font.family: root.monoFamily
                                font.pixelSize: 11
                                font.bold: true
                                color: yesMa.containsMouse ? root.colBg : root.colDanger
                                text: "[ ✓ CONFIRM ]"
                            }

                            MouseArea {
                                id: yesMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.executePowerAction(root.confirmAction)
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 78
                            Layout.preferredHeight: 24
                            color: noMa.containsMouse ? root.colMuted : root.colPanelBg
                            border.color: root.colMuted
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                font.family: root.monoFamily
                                font.pixelSize: 11
                                color: noMa.containsMouse ? root.colBg : root.colFg
                                text: "[ BACK ]"
                            }

                            MouseArea {
                                id: noMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.confirmAction = ""
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.powerStatus.length > 0
                    font.family: root.monoFamily
                    font.pixelSize: 10
                    color: root.colSecondary
                    text: root.powerStatus
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    radius: Math.max(0, root.themeRadius - 5)
                    color: cancelMa.containsMouse ? root.colMuted : root.colBg
                    border.color: root.colMuted
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        font.family: root.monoFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: cancelMa.containsMouse ? root.colBg : root.colFg
                        text: "[ CANCEL (Esc) ]"
                    }

                    MouseArea {
                        id: cancelMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.confirmAction = "";
                            root.closePowerDialog();
                        }
                    }
                }
                }
            }
        }
    }
}
