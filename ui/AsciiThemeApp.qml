pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property var theme: ({
        name: "amber",
        label: "Warm Amber CRT",
        bg: "#0d0f10",
        bgSecondary: "#121518",
        panelBg: "#14171a",
        gridDot: "#252a30",
        snapLine: "#8b949e",
        fg: "#e6dcc8",
        accent: "#ffb000",
        secondary: "#50fa7b",
        muted: "#6e7681",
        danger: "#ff5555",
        closeBtnBg: "#ff5555",
        fontFamily: "JetBrains Mono",
        fontSize: 13,
        chromeStyle: "ascii",
        backgroundStyle: "ascii_grid",
        gridChar: "·",
        xmasMonitor: "tallest",
        cornerRadius: 0,
        borderWidth: 1,
        smearDrag: false,
        impactFlash: false,
        speedLines: false,
        originSmear: false,
        monitorBackgrounds: ({}),
        bgTerminalCmd: "asciiquarium",
        customBgText: ""
    })
    property string monoFamily: "JetBrains Mono"
    property var availableMonitors: []
    property var presets: builtinPresets()
    property var draft: cloneTheme(theme)
    property string selectedPresetName: (theme && theme.name) ? String(theme.name) : "amber"
    property string statusMessage: "Pick a preset or craft a full overhaul."
    property bool statusError: false
    property bool maximizedModal: false
    property rect savedModalRect: Qt.rect(80, 60, 940, 640)

    implicitWidth: 940
    implicitHeight: 640

    signal closeRequested()
    signal themeUpdated(var newTheme)
    signal openBackgroundEditorRequested()

    function toggleMaximizeModal() {
        if (!root.parent) return;
        if (!maximizedModal) {
            savedModalRect = Qt.rect(root.x, root.y, root.width, root.height);
            root.x = 12;
            root.y = 34;
            root.width = Math.max(640, root.parent.width - 24);
            root.height = Math.max(440, root.parent.height - 56);
            maximizedModal = true;
        } else {
            root.width = Math.min(savedModalRect.width || 940, root.parent.width - 40);
            root.height = Math.min(savedModalRect.height || 640, root.parent.height - 80);
            root.x = Math.round((root.parent.width - root.width) / 2);
            root.y = Math.round((root.parent.height - root.height) / 2);
            maximizedModal = false;
        }
    }

    readonly property bool isDataLens: (draft && draft.chromeStyle === "snaptic_datalens")
    readonly property int uiRadius: (theme && theme.cornerRadius !== undefined) ? Number(theme.cornerRadius) : 0
    readonly property int uiBorder: (theme && theme.borderWidth !== undefined) ? Math.max(1, Number(theme.borderWidth)) : 1
    readonly property color closeBg: (theme && theme.closeBtnBg) ? theme.closeBtnBg : root.theme.danger
    readonly property bool previewAnimated: root.visible && Boolean(root.draft && (root.draft.backgroundStyle === "snaptic_void" || root.draft.backgroundStyle === "christmas_tree" || root.draft.backgroundStyle === "newsboard" || root.draft.backgroundStyle === "visualizer" || root.draft.smearDrag || root.draft.impactFlash))
    readonly property bool studioKinetic: Boolean(root.theme && (root.theme.impactFlash || root.theme.originSmear))
    property real previewPhase: 0.0
    property real kineticImpactAlpha: 0.0
    property real kineticSpearProgress: 0.0
    property real saveBounceScale: 1.0
    property string lastBouncedPreset: ""

    function triggerStudioImpact(presetId) {
        if (!root.studioKinetic) return;
        root.lastBouncedPreset = presetId || "";
        studioImpactAnim.restart();
        if (presetId === "__save__") {
            saveBounceAnim.restart();
        }
    }

    color: root.theme.panelBg
    border.color: root.theme.accent
    border.width: root.uiBorder
    radius: root.uiRadius
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

    function builtinPresets() {
        return [
            {
                name: "amber",
                label: "Warm Amber CRT",
                bg: "#0d0f10",
                bgSecondary: "#121518",
                panelBg: "#14171a",
                gridDot: "#252a30",
                snapLine: "#8b949e",
                fg: "#e6dcc8",
                accent: "#ffb000",
                secondary: "#50fa7b",
                muted: "#6e7681",
                danger: "#ff5555",
                closeBtnBg: "#ff5555",
                fontFamily: "JetBrains Mono",
                fontSize: 13,
                chromeStyle: "ascii",
                backgroundStyle: "ascii_grid",
                gridChar: "·",
                xmasMonitor: "tallest",
                cornerRadius: 0,
                borderWidth: 1,
                smearDrag: false,
                impactFlash: false,
                speedLines: false,
                originSmear: false
            },
            {
                name: "green",
                label: "Cyber Green Matrix",
                bg: "#0a0e0c",
                bgSecondary: "#0e1511",
                panelBg: "#101613",
                gridDot: "#1f3028",
                snapLine: "#88c0a8",
                fg: "#d8f5e5",
                accent: "#50fa7b",
                secondary: "#8be9fd",
                muted: "#627a6c",
                danger: "#ff5555",
                closeBtnBg: "#ff5555",
                fontFamily: "JetBrains Mono",
                fontSize: 13,
                chromeStyle: "ascii",
                backgroundStyle: "ascii_grid",
                gridChar: "·",
                xmasMonitor: "tallest",
                cornerRadius: 0,
                borderWidth: 1,
                smearDrag: false,
                impactFlash: false,
                speedLines: false,
                originSmear: false
            },
            {
                name: "cyan",
                label: "Ice Cyan Terminal",
                bg: "#0b1014",
                bgSecondary: "#0f171e",
                panelBg: "#121921",
                gridDot: "#20303c",
                snapLine: "#8be9fd",
                fg: "#e0f2fe",
                accent: "#38bdf8",
                secondary: "#50fa7b",
                muted: "#64748b",
                danger: "#f87171",
                closeBtnBg: "#f87171",
                fontFamily: "JetBrains Mono",
                fontSize: 13,
                chromeStyle: "ascii",
                backgroundStyle: "ascii_grid",
                gridChar: "·",
                xmasMonitor: "tallest",
                cornerRadius: 0,
                borderWidth: 1,
                smearDrag: false,
                impactFlash: false,
                speedLines: false,
                originSmear: false
            },
            {
                name: "mono",
                label: "Monochrome Slate",
                bg: "#0f0f10",
                bgSecondary: "#161618",
                panelBg: "#18181b",
                gridDot: "#2a2a2e",
                snapLine: "#a1a1aa",
                fg: "#f4f4f5",
                accent: "#e4e4e7",
                secondary: "#a1a1aa",
                muted: "#71717a",
                danger: "#ef4444",
                closeBtnBg: "#ef4444",
                fontFamily: "JetBrains Mono",
                fontSize: 13,
                chromeStyle: "ascii",
                backgroundStyle: "ascii_grid",
                gridChar: "·",
                xmasMonitor: "tallest",
                cornerRadius: 0,
                borderWidth: 1,
                smearDrag: false,
                impactFlash: false,
                speedLines: false,
                originSmear: false
            },
            {
                name: "snaptic",
                label: "SNAPTIC :: Data Lens Overhaul",
                bg: "#E8ECFC",
                bgSecondary: "#C5CEF7",
                panelBg: "#D8DDF4",
                gridDot: "#A0A8D8",
                snapLine: "#45C2FF",
                fg: "#3E4670",
                accent: "#7B84BF",
                secondary: "#45C2FF",
                muted: "#7D86B5",
                danger: "#FF3366",
                closeBtnBg: "#FF5C5C",
                fontFamily: "JetBrains Mono",
                fontSize: 13,
                chromeStyle: "snaptic_datalens",
                backgroundStyle: "snaptic_void",
                gridChar: "∘",
                cornerRadius: 10,
                borderWidth: 2,
                smearDrag: true,
                impactFlash: true,
                speedLines: true,
                originSmear: true
            },
            {
                name: "xmas",
                label: "Christmas Tree (dwcminh)",
                bg: "#090a10",
                bgSecondary: "#0e1518",
                panelBg: "#10161c",
                gridDot: "#1f3028",
                snapLine: "#44cc66",
                fg: "#e6f2e8",
                accent: "#ff474d",
                secondary: "#ffe647",
                muted: "#7a9e87",
                danger: "#ff474d",
                closeBtnBg: "#ff474d",
                fontFamily: "JetBrains Mono",
                fontSize: 13,
                chromeStyle: "ascii",
                backgroundStyle: "christmas_tree",
                gridChar: "*",
                xmasMonitor: "tallest",
                cornerRadius: 0,
                borderWidth: 1,
                smearDrag: false,
                impactFlash: false,
                speedLines: false,
                originSmear: false
            }
        ];
    }

    function getBackend() {
        // qmllint disable unqualified
        if (typeof Backend !== "undefined") return Backend;
        // qmllint enable unqualified
        return null;
    }

    function runBackend(args, tag) {
        var b = getBackend();
        if (b && b.runBackendAsync) {
            b.runBackendAsync(args, tag);
        }
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

    function cloneTheme(src) {
        var base = builtinPresets()[0];
        var s = src || {};
        var out = {};
        for (var k in base) {
            if (Object.prototype.hasOwnProperty.call(base, k)) {
                out[k] = (s[k] !== undefined && s[k] !== null) ? s[k] : base[k];
            }
        }
        var extras = ["monitorBackgrounds", "bgTerminalCmd", "customBgText"];
        for (var ei = 0; ei < extras.length; ei++) {
            var ek = extras[ei];
            if (s[ek] !== undefined && s[ek] !== null) {
                out[ek] = s[ek];
            } else if (ek === "monitorBackgrounds" && out[ek] === undefined) {
                out[ek] = ({});
            } else if (out[ek] === undefined) {
                out[ek] = "";
            }
        }
        for (var sk in s) {
            if (Object.prototype.hasOwnProperty.call(s, sk) && out[sk] === undefined && s[sk] !== null) {
                out[sk] = s[sk];
            }
        }
        return out;
    }

    function isValidHex(val) {
        return /^#[0-9a-fA-F]{6}$/.test(String(val || "").trim());
    }

    function loadStudio() {
        statusError = false;
        statusMessage = "Loading presets & active theme...";
        runBackend(["theme", "presets"], "theme_presets");
        runBackend(["theme", "get"], "theme_app_get");
    }

    function selectPresetForDraft(preset) {
        var copy = cloneTheme(preset);
        if (root.draft && root.draft.monitorBackgrounds) {
            copy.monitorBackgrounds = root.draft.monitorBackgrounds;
        }
        if (root.draft && root.draft.bgTerminalCmd) {
            copy.bgTerminalCmd = root.draft.bgTerminalCmd;
        }
        selectedPresetName = copy.name || "amber";
        draft = copy;
        statusError = false;
        statusMessage = "Previewing preset '" + (copy.label || copy.name) + "' — click Apply Overhaul to save.";
        triggerStudioImpact(selectedPresetName);
    }

    function applyPresetNow(preset) {
        var copy = cloneTheme(preset);
        if (root.draft && root.draft.monitorBackgrounds) {
            copy.monitorBackgrounds = root.draft.monitorBackgrounds;
        }
        if (root.draft && root.draft.bgTerminalCmd) {
            copy.bgTerminalCmd = root.draft.bgTerminalCmd;
        }
        selectedPresetName = copy.name || "amber";
        draft = copy;
        statusError = false;
        statusMessage = "Applying '" + (copy.label || copy.name) + "'...";
        triggerStudioImpact(selectedPresetName);
        themeUpdated(copy);
        runBackend(["theme", "set", selectedPresetName], "theme_app_apply");
    }

    function patchDraft(key, value) {
        var next = cloneTheme(draft);
        next[key] = value;
        if (key === "chromeStyle") {
            if (value === "snaptic_datalens") {
                next.cornerRadius = 10;
                next.borderWidth = 2;
            } else {
                next.cornerRadius = 0;
                next.borderWidth = 1;
            }
        }
        draft = next;
    }

    function saveCustomDraft() {
        var next = cloneTheme(draft);
        next.name = "custom";
        next.label = next.label && next.label.length > 0 ? next.label : "Custom Overhaul";
        draft = next;
        statusError = false;
        statusMessage = "Saving custom overhaul...";
        triggerStudioImpact("__save__");
        themeUpdated(next);
        runBackend(["theme", "custom", JSON.stringify(next)], "theme_app_apply");
        if (next.backgroundStyle === "terminal") {
            runBackend(["settings", "set", JSON.stringify({
                bgTerminalEnabled: true,
                bgTerminalCmd: next.bgTerminalCmd || "asciiquarium"
            })], "theme_bg_term_sync");
        }
    }

    function resetToSelectedPreset() {
        var list = presets || builtinPresets();
        var target = "amber";
        for (var i = 0; i < list.length; i++) {
            if (list[i] && list[i].name === selectedPresetName) {
                target = list[i].name;
                draft = cloneTheme(list[i]);
                break;
            }
        }
        statusError = false;
        statusMessage = "Resetting preset '" + target + "'...";
        themeUpdated(cloneTheme(draft));
        runBackend(["theme", "set", target], "theme_app_apply");
    }

    onVisibleChanged: {
        if (visible) {
            loadStudio();
        }
    }

    MouseArea {
        anchors.fill: parent
    }

    Timer {
        id: previewAnimTimer
        interval: 33
        repeat: true
        running: root.previewAnimated
        onTriggered: {
            root.previewPhase = (root.previewPhase + 0.018) % 1.0;
            previewStageCanvas.requestPaint();
        }
        onRunningChanged: {
            if (!running) {
                root.previewPhase = 0.0;
                previewStageCanvas.requestPaint();
            }
        }
    }

    ParallelAnimation {
        id: studioImpactAnim
        SequentialAnimation {
            PropertyAction { target: root; property: "kineticImpactAlpha"; value: 0.95 }
            NumberAnimation { target: root; property: "kineticImpactAlpha"; to: 0.0; duration: 180; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            PropertyAction { target: root; property: "kineticSpearProgress"; value: 0.0 }
            NumberAnimation { target: root; property: "kineticSpearProgress"; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
        }
    }

    SequentialAnimation {
        id: saveBounceAnim
        NumberAnimation { target: root; property: "saveBounceScale"; to: 0.94; duration: 55; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "saveBounceScale"; to: 1.04; duration: 110; easing.type: Easing.OutBack }
        NumberAnimation { target: root; property: "saveBounceScale"; to: 1.0; duration: 90; easing.type: Easing.OutCubic }
    }

    // Studio-wide cyan rim flash + sweeping spear bar on SNAPTIC preset/apply impact
    Rectangle {
        anchors.fill: parent
        z: 100
        color: "transparent"
        radius: root.uiRadius
        border.color: "#45C2FF"
        border.width: 3
        opacity: root.kineticImpactAlpha
        visible: opacity > 0.01
    }

    Rectangle {
        z: 101
        height: 3
        radius: 1.5
        width: Math.max(24, parent.width * 0.28)
        y: 1
        x: -width + (parent.width + width) * root.kineticSpearProgress
        color: "#45C2FF"
        opacity: root.kineticImpactAlpha
        visible: opacity > 0.01
    }

    Connections {
        target: root.getBackend()
        ignoreUnknownSignals: true

        function onBackendResult(tag, jsonOutput) {
            if (tag === "theme_presets") {
                var arr = root.safeJsonParse(jsonOutput, null);
                if (Array.isArray(arr) && arr.length > 0) {
                    root.presets = arr;
                }
            } else if (tag === "theme_app_get") {
                var th = root.safeJsonParse(jsonOutput, null);
                if (th && typeof th === "object" && th.bg) {
                    var c = root.cloneTheme(th);
                    root.draft = c;
                    if (c.name && c.name !== "custom") {
                        root.selectedPresetName = c.name;
                    }
                    root.statusError = false;
                    root.statusMessage = "Active: " + (c.label || c.name);
                }
            } else if (tag === "theme_app_apply") {
                var res = root.safeJsonParse(jsonOutput, null);
                if (res && typeof res === "object" && res.bg) {
                    var applied = root.cloneTheme(res);
                    root.draft = applied;
                    root.themeUpdated(applied);
                    root.statusError = false;
                    root.statusMessage = "Saved & applied: " + (applied.label || applied.name);
                } else {
                    root.statusError = true;
                    root.statusMessage = "Preview active (backend response invalid).";
                }
            }
        }
    }

    ColumnLayout {
        anchors { fill: parent; margins: 10 }
        spacing: 8

        // Title bar
        Item {
            Layout.fillWidth: true
            implicitHeight: 24

            MouseArea {
                id: themeDragArea
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
                text: (root.theme && root.theme.chromeStyle === "snaptic_datalens")
                      ? "[ 👁 SNAPTIC :: THEME OVERHAUL STUDIO ]"
                      : "┌─[ ASCII-DE THEME OVERHAUL STUDIO ]──────────────────────────────┐"
            }

            Rectangle {
                z: 2
                width: 34
                height: 22
                radius: Math.min(6, root.uiRadius)
                color: maxStudioMa.containsMouse ? root.theme.accent : root.theme.bg
                border.color: root.theme.accent
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    font.family: root.monoFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: maxStudioMa.containsMouse ? root.theme.bg : root.theme.accent
                    text: root.maximizedModal ? "[❐]" : "[□]"
                }

                MouseArea {
                    id: maxStudioMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleMaximizeModal()
                }
            }

            Rectangle {
                z: 2
                width: 34
                height: 22
                radius: Math.min(6, root.uiRadius)
                color: closeStudioMa.containsMouse ? root.theme.fg : root.closeBg
                border.color: root.closeBg
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    font.family: root.monoFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: closeStudioMa.containsMouse ? root.theme.bg : "#ffffff"
                    text: "[✕]"
                }

                MouseArea {
                    id: closeStudioMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeRequested()
                }
            }
        }
    }

        // Main Split: Left Overhaul Presets + Right Full Customizer
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            // Left Overhaul Presets Column
            Rectangle {
                Layout.preferredWidth: Math.min(268, Math.max(170, Math.round(root.width * 0.30)))
                Layout.fillHeight: true
                color: root.theme.bg
                border.color: root.theme.muted
                border.width: root.uiBorder
                radius: Math.min(8, root.uiRadius)

                ColumnLayout {
                    anchors { fill: parent; margins: 8 }
                    spacing: 6

                    Text {
                        font.family: root.monoFamily
                        font.pixelSize: 10
                        font.bold: true
                        color: root.theme.muted
                        text: "OVERHAUL PRESETS:"
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 6
                        model: root.presets

                        delegate: Rectangle {
                            id: presetDel
                            required property var modelData
                            readonly property bool isSel: root.selectedPresetName === modelData.name
                            readonly property bool isSnaptic: modelData.name === "snaptic"
                            width: ListView.view.width
                            height: isSnaptic ? 82 : 66
                            radius: Math.min(8, Number(modelData.cornerRadius || root.uiRadius))
                            color: isSel ? root.theme.panelBg : (presetMa.containsMouse ? root.theme.gridDot : root.theme.bg)
                            border.color: isSel ? modelData.accent : (isSnaptic ? modelData.secondary : root.theme.gridDot)
                            border.width: isSel ? 2 : 1
                            transformOrigin: Item.Center

                            onIsSelChanged: {
                                if (isSel && root.studioKinetic) {
                                    cardBounceAnim.restart();
                                }
                            }

                            Connections {
                                target: root
                                function onLastBouncedPresetChanged() {
                                    if (root.studioKinetic && root.lastBouncedPreset === presetDel.modelData.name) {
                                        cardBounceAnim.restart();
                                    }
                                }
                            }

                            SequentialAnimation {
                                id: cardBounceAnim
                                NumberAnimation { target: presetDel; property: "scale"; to: 0.94; duration: 50; easing.type: Easing.OutQuad }
                                NumberAnimation { target: presetDel; property: "scale"; to: 1.04; duration: 105; easing.type: Easing.OutBack }
                                NumberAnimation { target: presetDel; property: "scale"; to: 1.0; duration: 85; easing.type: Easing.OutCubic }
                            }

                            ColumnLayout {
                                anchors { fill: parent; margins: 6 }
                                spacing: 3

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Text {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        font.family: root.monoFamily
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: presetDel.isSnaptic ? "#7B84BF" : (presetDel.isSel ? root.theme.accent : root.theme.fg)
                                        text: (presetDel.isSnaptic ? "★ " : (presetDel.isSel ? "▸ " : "  "))
                                              + (presetDel.modelData.label || presetDel.modelData.name)
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    font.family: root.monoFamily
                                    font.pixelSize: 9
                                    color: root.theme.muted
                                    text: presetDel.isSnaptic
                                          ? "Data Lens · Periwinkle/Cyan · Smear & SpeedLines"
                                          : (presetDel.modelData.chromeStyle + " · " + presetDel.modelData.backgroundStyle)
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    // Color swatch preview strip
                                    Row {
                                        spacing: 2
                                        Repeater {
                                            model: [
                                                presetDel.modelData.bg,
                                                presetDel.modelData.bgSecondary || presetDel.modelData.bg,
                                                presetDel.modelData.panelBg,
                                                presetDel.modelData.fg,
                                                presetDel.modelData.accent,
                                                presetDel.modelData.secondary,
                                                presetDel.modelData.closeBtnBg || presetDel.modelData.danger
                                            ]
                                            delegate: Rectangle {
                                                id: swDel
                                                required property string modelData
                                                width: 14
                                                height: 12
                                                radius: 2
                                                color: swDel.modelData
                                                border.color: root.theme.muted
                                                border.width: 1
                                            }
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    Rectangle {
                                        width: applyPreTxt.implicitWidth + 10
                                        height: 18
                                        radius: Math.min(4, root.uiRadius)
                                        color: applyPreMa.containsMouse ? presetDel.modelData.accent : presetDel.modelData.panelBg
                                        border.color: presetDel.modelData.accent
                                        border.width: 1
                                        z: 2

                                        Text {
                                            id: applyPreTxt
                                            anchors.centerIn: parent
                                            font.family: root.monoFamily
                                            font.pixelSize: 9
                                            font.bold: true
                                            color: applyPreMa.containsMouse ? presetDel.modelData.bg : presetDel.modelData.fg
                                            text: "[✓ Apply Overhaul]"
                                        }

                                        MouseArea {
                                            id: applyPreMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.applyPresetNow(presetDel.modelData)
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: presetMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectPresetForDraft(presetDel.modelData)
                            }
                        }
                    }
                }
            }

            // Right Full Customizer Pane
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: root.theme.bg
                border.color: root.theme.muted
                border.width: root.uiBorder
                radius: Math.min(8, root.uiRadius)

                Flickable {
                    anchors { fill: parent; margins: 10 }
                    contentWidth: width
                    contentHeight: studioCol.implicitHeight
                    clip: true

                    ColumnLayout {
                        id: studioCol
                        width: parent.width
                        spacing: 10

                        // Animated Live Preview Stage
                        Rectangle {
                            id: previewStage
                            Layout.fillWidth: true
                            height: 88
                            clip: true
                            radius: Number(root.draft.cornerRadius || 0)
                            border.color: root.draft.accent
                            border.width: Math.max(1, Number(root.draft.borderWidth || 1))
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: root.draft.bg }
                                GradientStop { position: 1.0; color: root.draft.bgSecondary || root.draft.bg }
                            }

                            readonly property real phase: root.previewPhase
                            // 0.00..0.52 glide left->right, 0.52..0.72 impact & bounce, 0.72..1.00 settle/hold
                            readonly property bool isGliding: root.previewAnimated && phase < 0.52
                            readonly property bool isImpactFrame: root.previewAnimated && phase >= 0.52 && phase < 0.62
                            readonly property real glideT: !root.previewAnimated ? 0.5
                                : (phase < 0.52 ? (phase / 0.52) : 1.0)
                            readonly property real easedGlide: 1.0 - Math.pow(1.0 - glideT, 3)
                            readonly property real bounceScale: !root.previewAnimated ? 1.0
                                : (phase >= 0.52 && phase < 0.60 ? 0.94
                                   : (phase >= 0.60 && phase < 0.70 ? 1.05 : 1.0))
                            readonly property real smearSkew: (root.previewAnimated && Boolean(root.draft.smearDrag) && isGliding)
                                ? (-0.14 * Math.sin(glideT * Math.PI))
                                : 0.0

                            Canvas {
                                id: previewStageCanvas
                                anchors.fill: parent
                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);
                                    var bgStyle = String(root.draft.backgroundStyle || "ascii_grid");
                                    var dotCol = String(root.draft.gridDot || "#252a30");
                                    var secCol = String(root.draft.secondary || "#45C2FF");
                                    var p = root.previewPhase;

                                    if (bgStyle === "snaptic_void") {
                                        // Pulsing cyber data pools
                                        var pulse = 0.22 + 0.14 * Math.sin(p * Math.PI * 2);
                                        ctx.save();
                                        ctx.globalAlpha = pulse;
                                        ctx.fillStyle = secCol;
                                        ctx.beginPath();
                                        ctx.ellipse(width * 0.14, height * 0.58, 48, 12);
                                        ctx.fill();
                                        ctx.beginPath();
                                        ctx.ellipse(width * 0.72, height * 0.64, 60, 14);
                                        ctx.fill();
                                        // Rising sparkles ✦
                                        for (var i = 0; i < 6; i++) {
                                            var sx = ((i * 89 + 34) % Math.max(40, width - 20)) + 10;
                                            var sy = height - (((p * 120 + i * 21) % (height + 10)));
                                            ctx.globalAlpha = 0.45 + 0.35 * Math.sin(p * 6.28 + i);
                                            ctx.fillStyle = (i % 2 === 0) ? "#ffffff" : secCol;
                                            ctx.font = "10px 'JetBrains Mono'";
                                            ctx.fillText("✦", sx, sy);
                                        }
                                        ctx.restore();
                                    } else if (bgStyle === "newsboard") {
                                        ctx.save();
                                        ctx.fillStyle = dotCol;
                                        ctx.font = "8px 'JetBrains Mono'";
                                        ctx.fillText("╔══════════════════════════════════════╗", 10, 16);
                                        ctx.fillStyle = String(root.draft.accent || "#ffb000");
                                        ctx.fillText("║  THE WAYLAND TELETYPE GAZETTE ★ LIVE ║", 10, 28);
                                        ctx.fillStyle = dotCol;
                                        ctx.fillText("╚══════════════════════════════════════╝", 10, 40);
                                        ctx.fillStyle = String(root.draft.fg || "#e6dcc8");
                                        ctx.fillText(">>> WIRE: SYS OPTIMAL · 3 DISPLAYS <<<", 10, 56);
                                        ctx.restore();
                                    } else if (bgStyle === "visualizer") {
                                        ctx.save();
                                        var bars = 16;
                                        var barW = Math.max(3, Math.floor((width - 40) / bars));
                                        for (var bi = 0; bi < bars; bi++) {
                                            var bh = (0.2 + 0.65 * (0.5 + 0.5 * Math.sin(p * 8.0 + bi * 0.45))) * (height * 0.45);
                                            var bx = 20 + bi * barW;
                                            var by = height - 20 - bh;
                                            ctx.fillStyle = (bi % 2 === 0) ? String(root.draft.accent || "#ffb000") : secCol;
                                            ctx.fillRect(bx, by, barW - 1, bh);
                                        }
                                        ctx.restore();
                                    } else if (bgStyle === "ascii_grid") {
                                        ctx.fillStyle = dotCol;
                                        ctx.font = "10px 'JetBrains Mono'";
                                        var ch = String(root.draft.gridChar || "·");
                                        for (var gx = 8; gx < width - 4; gx += 16) {
                                            for (var gy = 14; gy < height - 4; gy += 16) {
                                                ctx.fillText(ch, gx, gy);
                                            }
                                        }
                                    }
                                }
                            }

                            // Trailing cyan spear lines (━━▶) while gliding
                            Column {
                                anchors.verticalCenter: miniPreviewWin.verticalCenter
                                x: miniPreviewWin.x - 46
                                spacing: 4
                                visible: previewStage.isGliding && Boolean(root.draft.smearDrag)
                                opacity: 0.85

                                Text {
                                    font.family: root.monoFamily
                                    font.pixelSize: 9
                                    font.bold: true
                                    color: root.draft.secondary || "#45C2FF"
                                    text: "━━━▶"
                                }
                                Text {
                                    font.family: root.monoFamily
                                    font.pixelSize: 9
                                    font.bold: true
                                    color: "#ffffff"
                                    text: " ━━▶"
                                }
                            }

                            // 2-frame corner impact burst (✦) on snap
                            Text {
                                visible: previewStage.isImpactFrame && Boolean(root.draft.impactFlash)
                                anchors { right: miniPreviewWin.right; top: miniPreviewWin.top; rightMargin: -10; topMargin: -8 }
                                font.family: root.monoFamily
                                font.pixelSize: 13
                                font.bold: true
                                color: "#45C2FF"
                                text: "✦"
                            }
                            Text {
                                visible: previewStage.isImpactFrame && Boolean(root.draft.impactFlash)
                                anchors { left: miniPreviewWin.left; bottom: miniPreviewWin.bottom; leftMargin: -10; bottomMargin: -6 }
                                font.family: root.monoFamily
                                font.pixelSize: 13
                                font.bold: true
                                color: "#ffffff"
                                text: "✦"
                            }

                            // Miniature preview window
                            Rectangle {
                                id: miniPreviewWin
                                width: Math.min(276, Math.max(180, previewStage.width * 0.56))
                                height: 48
                                y: 12
                                x: root.previewAnimated
                                   ? (16 + previewStage.easedGlide * Math.max(20, previewStage.width - width - 32))
                                   : ((previewStage.width - width) * 0.5)
                                scale: previewStage.bounceScale
                                Behavior on scale {
                                    enabled: root.previewAnimated
                                    NumberAnimation { duration: 150; easing.type: Easing.OutBack }
                                }
                                transform: Matrix4x4 {
                                    matrix: Qt.matrix4x4(
                                        1, previewStage.smearSkew, 0, 0,
                                        0, 1, 0, 0,
                                        0, 0, 1, 0,
                                        0, 0, 0, 1
                                    )
                                }
                                radius: Math.min(8, Number(root.draft.cornerRadius || 0))
                                color: root.draft.panelBg
                                border.color: (previewStage.isImpactFrame && Boolean(root.draft.impactFlash))
                                              ? "#45C2FF"
                                              : root.draft.accent
                                border.width: (previewStage.isImpactFrame && Boolean(root.draft.impactFlash))
                                              ? 2
                                              : Math.max(1, Number(root.draft.borderWidth || 1))

                                ColumnLayout {
                                    anchors { fill: parent; margins: 5 }
                                    spacing: 2

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6
                                        Text {
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            font.family: root.draft.fontFamily || "JetBrains Mono"
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: root.draft.fg
                                            text: (root.isDataLens ? "[ 👁 Data Lens ] " : "┌─[ ASCII Box ] ")
                                                  + (root.draft.label || root.draft.name)
                                        }
                                        Rectangle {
                                            width: 20; height: 13
                                            radius: Math.min(4, Number(root.draft.cornerRadius || 0))
                                            color: root.draft.closeBtnBg || root.draft.danger
                                            Text {
                                                anchors.centerIn: parent
                                                font.family: root.monoFamily
                                                font.pixelSize: 9
                                                font.bold: true
                                                color: "#ffffff"
                                                text: "✕"
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        font.family: root.draft.fontFamily || "JetBrains Mono"
                                        font.pixelSize: 9
                                        color: root.draft.muted || root.draft.fg
                                        text: (root.previewAnimated ? "Kinetic Smear & Impact Preview" : "Static Crisp Terminal Preview")
                                    }
                                }
                            }

                            Text {
                                anchors { left: parent.left; bottom: parent.bottom; leftMargin: 8; bottomMargin: 4 }
                                font.family: root.draft.fontFamily || "JetBrains Mono"
                                font.pixelSize: 9
                                color: root.draft.fg
                                text: "Grid: " + (root.draft.gridChar || "·") + "  Bg: " + (root.draft.backgroundStyle || "ascii_grid")
                            }

                            Text {
                                anchors { right: parent.right; bottom: parent.bottom; rightMargin: 8; bottomMargin: 4 }
                                font.family: root.monoFamily
                                font.pixelSize: 9
                                font.bold: true
                                color: root.draft.secondary
                                text: "Snap: " + root.draft.snapLine
                            }
                        }

                        // Background Style + Grid Glyph
                        Text {
                            font.family: root.monoFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: root.theme.accent
                            text: "═══ BACKGROUND STYLE & GRID GLYPH ═══"
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 3
                            rowSpacing: 4
                            columnSpacing: 4
                            Repeater {
                                model: [
                                    { id: "ascii_grid",     label: "[ ASCII Grid ]" },
                                    { id: "solid",          label: "[ Solid ]" },
                                    { id: "gradient",       label: "[ Gradient ]" },
                                    { id: "snaptic_void",   label: "[ SNAPTIC Void ]" },
                                    { id: "christmas_tree", label: "[ Christmas Tree ]" },
                                    { id: "newsboard",      label: "[ Live Newsboard ]" },
                                    { id: "visualizer",     label: "[ Music Visualizer ]" },
                                    { id: "terminal",       label: "[ Live Terminal ]" },
                                    { id: "ascii_image",    label: "[ Image -> ASCII ]" }
                                ]
                                delegate: Rectangle {
                                    id: bgStDel
                                    required property var modelData
                                    readonly property bool active: (root.draft.backgroundStyle || "ascii_grid") === modelData.id
                                    Layout.fillWidth: true
                                    height: 24
                                    radius: Math.min(4, root.uiRadius)
                                    color: active ? root.theme.accent : (bgStMa.containsMouse ? root.theme.gridDot : root.theme.panelBg)
                                    border.color: active ? root.theme.accent : root.theme.muted
                                    border.width: 1
                                    Text {
                                        anchors.centerIn: parent
                                        font.family: root.monoFamily
                                        font.pixelSize: 10
                                        font.bold: bgStDel.active
                                        color: bgStDel.active ? root.theme.bg : root.theme.fg
                                        text: bgStDel.modelData.label
                                    }
                                    MouseArea {
                                        id: bgStMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.patchDraft("backgroundStyle", bgStDel.modelData.id)
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.columnSpan: 3
                                Layout.topMargin: 4
                                implicitHeight: 30
                                radius: Math.min(4, root.uiRadius)
                                color: bgEdBtnMa.containsMouse ? root.theme.accent : root.theme.panelBg
                                border.color: root.theme.accent
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    font.family: root.monoFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: bgEdBtnMa.containsMouse ? root.theme.bg : root.theme.accent
                                    text: "[ ⛶ Open Per-Monitor Wallpaper & Tile Studio... ]"
                                }

                                MouseArea {
                                    id: bgEdBtnMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.openBackgroundEditorRequested()
                                }
                            }
                        }

                        // Inline Live Terminal quick-command bar when backgroundStyle === "terminal"
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            spacing: 4
                            visible: (root.draft.backgroundStyle || "ascii_grid") === "terminal"

                            Text {
                                font.family: root.monoFamily
                                font.pixelSize: 10
                                font.bold: true
                                color: root.theme.secondary
                                text: "LIVE TERMINAL COMMAND (applies on Save & Apply):"
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Repeater {
                                    model: ["asciiquarium", "cmatrix", "agy-usage", "btop", "htop", "cava", "cbonsai -li"]
                                    delegate: Rectangle {
                                        id: inlineTermCmdDel
                                        required property string modelData
                                        readonly property bool active: String(root.draft.bgTerminalCmd || "asciiquarium") === modelData
                                        Layout.fillWidth: true
                                        height: 22
                                        radius: Math.min(4, root.uiRadius)
                                        color: active ? root.theme.secondary : (inlineTermCmdMa.containsMouse ? root.theme.gridDot : root.theme.panelBg)
                                        border.color: active ? root.theme.secondary : root.theme.muted
                                        border.width: 1
                                        Text {
                                            anchors.centerIn: parent
                                            font.family: root.monoFamily
                                            font.pixelSize: 9
                                            font.bold: inlineTermCmdDel.active
                                            color: inlineTermCmdDel.active ? root.theme.bg : root.theme.fg
                                            text: inlineTermCmdDel.modelData
                                        }
                                        MouseArea {
                                            id: inlineTermCmdMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.patchDraft("bgTerminalCmd", inlineTermCmdDel.modelData)
                                        }
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            spacing: 4
                            visible: (root.draft.backgroundStyle || "ascii_grid") === "christmas_tree"

                            Text {
                                font.family: root.monoFamily
                                font.pixelSize: 10
                                font.bold: true
                                color: root.theme.secondary
                                text: "CHRISTMAS TREE MONITOR (default: tallest monitor)"
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: 4

                                Rectangle {
                                    id: xmasTallestBtn
                                    readonly property bool active: (root.draft.xmasMonitor || "tallest") === "tallest"
                                    width: xmasTallestLbl.implicitWidth + 14
                                    height: 24
                                    radius: Math.min(4, root.uiRadius)
                                    color: active ? root.theme.accent : (xmasTallestMa.containsMouse ? root.theme.gridDot : root.theme.panelBg)
                                    border.color: active ? root.theme.accent : root.theme.muted
                                    border.width: 1
                                    Text {
                                        id: xmasTallestLbl
                                        anchors.centerIn: parent
                                        font.family: root.monoFamily
                                        font.pixelSize: 10
                                        font.bold: xmasTallestBtn.active
                                        color: xmasTallestBtn.active ? root.theme.bg : root.theme.fg
                                        text: "[ Tallest (Auto) ]"
                                    }
                                    MouseArea {
                                        id: xmasTallestMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.patchDraft("xmasMonitor", "tallest")
                                    }
                                }

                                Repeater {
                                    model: root.availableMonitors || []
                                    delegate: Rectangle {
                                        id: xmasMonDel
                                        required property var modelData
                                        readonly property string monName: modelData && modelData.name ? modelData.name : ""
                                        readonly property bool active: (root.draft.xmasMonitor || "tallest") === monName
                                        width: xmasMonLbl.implicitWidth + 14
                                        height: 24
                                        radius: Math.min(4, root.uiRadius)
                                        color: active ? root.theme.accent : (xmasMonMa.containsMouse ? root.theme.gridDot : root.theme.panelBg)
                                        border.color: active ? root.theme.accent : root.theme.muted
                                        border.width: 1
                                        Text {
                                            id: xmasMonLbl
                                            anchors.centerIn: parent
                                            font.family: root.monoFamily
                                            font.pixelSize: 10
                                            font.bold: xmasMonDel.active
                                            color: xmasMonDel.active ? root.theme.bg : root.theme.fg
                                            text: "[" + xmasMonDel.monName + (xmasMonDel.modelData.height ? (" " + xmasMonDel.modelData.width + "x" + xmasMonDel.modelData.height) : "") + (xmasMonDel.modelData.isTallest ? " ★" : "") + "]"
                                        }
                                        MouseArea {
                                            id: xmasMonMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.patchDraft("xmasMonitor", xmasMonDel.monName)
                                        }
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
                                text: "GRID GLYPH:"
                            }
                            Repeater {
                                model: ["·", "+", "∘", "░"]
                                delegate: Rectangle {
                                    id: glDel
                                    required property string modelData
                                    readonly property bool active: (root.draft.gridChar || "·") === modelData
                                    width: 44
                                    height: 22
                                    radius: Math.min(4, root.uiRadius)
                                    color: active ? root.theme.secondary : (glMa.containsMouse ? root.theme.gridDot : root.theme.panelBg)
                                    border.color: active ? root.theme.secondary : root.theme.muted
                                    border.width: 1
                                    Text {
                                        anchors.centerIn: parent
                                        font.family: root.monoFamily
                                        font.pixelSize: 12
                                        font.bold: glDel.active
                                        color: glDel.active ? root.theme.bg : root.theme.fg
                                        text: glDel.modelData
                                    }
                                    MouseArea {
                                        id: glMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.patchDraft("gridChar", glDel.modelData)
                                    }
                                }
                            }
                        }

                        // Window Frame Style
                        Text {
                            font.family: root.monoFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: root.theme.accent
                            text: "═══ WINDOW FRAME CHROME ═══"
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Repeater {
                                model: [
                                    { id: "ascii",            label: "[ ASCII Box ┌─┐ ]" },
                                    { id: "snaptic_datalens", label: "[ SNAPTIC Data Lens 👁 ]" },
                                    { id: "minimal",          label: "[ Minimal ]" }
                                ]
                                delegate: Rectangle {
                                    id: chDel
                                    required property var modelData
                                    readonly property bool active: (root.draft.chromeStyle || "ascii") === modelData.id
                                    Layout.fillWidth: true
                                    height: 26
                                    radius: Math.min(4, root.uiRadius)
                                    color: active ? root.theme.accent : (chMa.containsMouse ? root.theme.gridDot : root.theme.panelBg)
                                    border.color: active ? root.theme.accent : root.theme.muted
                                    border.width: 1
                                    Text {
                                        anchors.centerIn: parent
                                        font.family: root.monoFamily
                                        font.pixelSize: 10
                                        font.bold: chDel.active
                                        color: chDel.active ? root.theme.bg : root.theme.fg
                                        text: chDel.modelData.label
                                    }
                                    MouseArea {
                                        id: chMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.patchDraft("chromeStyle", chDel.modelData.id)
                                    }
                                }
                            }
                        }

                        // Kinetic Impact & Smear Effects
                        Text {
                            font.family: root.monoFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: root.theme.accent
                            text: "═══ KINETIC IMPACT & SMEAR EFFECTS ═══"
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 6
                            rowSpacing: 4

                            Repeater {
                                model: [
                                    { key: "smearDrag",   label: "Velocity Drag Smear" },
                                    { key: "impactFlash", label: "Snap/Open Impact Flash" },
                                    { key: "speedLines",  label: "Workspace Radial Speed Lines" },
                                    { key: "originSmear", label: "Menu Origin Smear" }
                                ]
                                delegate: Rectangle {
                                    id: fxDel
                                    required property var modelData
                                    readonly property bool on: Boolean(root.draft[modelData.key])
                                    Layout.fillWidth: true
                                    height: 26
                                    radius: Math.min(4, root.uiRadius)
                                    color: on ? root.theme.secondary : root.theme.panelBg
                                    border.color: on ? root.theme.secondary : root.theme.muted
                                    border.width: 1

                                    Text {
                                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: parent.right; leftMargin: 6; rightMargin: 6 }
                                        elide: Text.ElideRight
                                        font.family: root.monoFamily
                                        font.pixelSize: 10
                                        font.bold: fxDel.on
                                        color: fxDel.on ? root.theme.bg : root.theme.fg
                                        text: (fxDel.on ? "[✓] " : "[ ] ") + fxDel.modelData.label
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.patchDraft(fxDel.modelData.key, !fxDel.on)
                                    }
                                }
                            }
                        }

                        // Typography
                        Text {
                            font.family: root.monoFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: root.theme.accent
                            text: "═══ TYPOGRAPHY ═══"
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Repeater {
                                model: [
                                    { id: "JetBrains Mono",              label: "JetBrains Mono" },
                                    { id: "CaskaydiaCove Nerd Font Mono", label: "CaskaydiaCove" },
                                    { id: "Hack",                        label: "Hack" },
                                    { id: "DejaVu Sans Mono",            label: "DejaVu Sans" },
                                    { id: "Adwaita Sans",                label: "Adwaita Sans" }
                                ]
                                delegate: Rectangle {
                                    id: tfDel
                                    required property var modelData
                                    readonly property bool active: (root.draft.fontFamily || "JetBrains Mono") === modelData.id
                                    Layout.fillWidth: true
                                    height: 22
                                    radius: Math.min(4, root.uiRadius)
                                    color: active ? root.theme.accent : (tfMa.containsMouse ? root.theme.gridDot : root.theme.panelBg)
                                    border.color: active ? root.theme.accent : root.theme.muted
                                    border.width: 1
                                    Text {
                                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: parent.right; leftMargin: 4; rightMargin: 4 }
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        font.family: root.monoFamily
                                        font.pixelSize: 9
                                        font.bold: tfDel.active
                                        color: tfDel.active ? root.theme.bg : root.theme.fg
                                        text: tfDel.modelData.label
                                    }
                                    MouseArea {
                                        id: tfMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.patchDraft("fontFamily", tfDel.modelData.id)
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Text {
                                font.family: root.monoFamily
                                font.pixelSize: 10
                                color: root.theme.muted
                                text: "SIZE:"
                            }
                            Repeater {
                                model: [11, 12, 13, 14, 15, 16]
                                delegate: Rectangle {
                                    id: tsDel
                                    required property int modelData
                                    readonly property bool active: Number(root.draft.fontSize || 13) === modelData
                                    Layout.fillWidth: true
                                    height: 22
                                    radius: Math.min(4, root.uiRadius)
                                    color: active ? root.theme.accent : (tsMa.containsMouse ? root.theme.gridDot : root.theme.panelBg)
                                    border.color: active ? root.theme.accent : root.theme.muted
                                    border.width: 1
                                    Text {
                                        anchors.centerIn: parent
                                        font.family: root.monoFamily
                                        font.pixelSize: 10
                                        font.bold: tsDel.active
                                        color: tsDel.active ? root.theme.bg : root.theme.fg
                                        text: tsDel.modelData + "px"
                                    }
                                    MouseArea {
                                        id: tsMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.patchDraft("fontSize", tsDel.modelData)
                                    }
                                }
                            }
                        }

                        // Color Editor
                        Text {
                            font.family: root.monoFamily
                            font.pixelSize: 10
                            font.bold: true
                            color: root.theme.accent
                            text: "═══ COLOR PALETTE EDITOR (#RRGGBB) ═══"
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Repeater {
                                model: [
                                    { key: "bg",          label: "Background",      chips: ["#0d0f10", "#0a0e0c", "#0b1014", "#E8ECFC"] },
                                    { key: "bgSecondary", label: "Gradient/Void 2", chips: ["#121518", "#0e1511", "#0f171e", "#C5CEF7"] },
                                    { key: "panelBg",     label: "Panel Surface",   chips: ["#14171a", "#101613", "#18181b", "#D8DDF4"] },
                                    { key: "fg",          label: "Foreground Text", chips: ["#e6dcc8", "#d8f5e5", "#f4f4f5", "#3E4670"] },
                                    { key: "accent",      label: "Primary Accent",  chips: ["#ffb000", "#50fa7b", "#38bdf8", "#7B84BF"] },
                                    { key: "secondary",   label: "Secondary/Cyan",  chips: ["#50fa7b", "#8be9fd", "#a1a1aa", "#45C2FF"] },
                                    { key: "snapLine",    label: "Snap Outline",    chips: ["#8b949e", "#88c0a8", "#38bdf8", "#45C2FF"] },
                                    { key: "closeBtnBg",  label: "Close / Danger",  chips: ["#ff5555", "#f87171", "#ef4444", "#FF5C5C"] }
                                ]
                                delegate: RowLayout {
                                    id: colRowDel
                                    required property var modelData
                                    readonly property string curHex: String(root.draft[modelData.key] || "#000000")
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Text {
                                        Layout.preferredWidth: 112
                                        elide: Text.ElideRight
                                        font.family: root.monoFamily
                                        font.pixelSize: 10
                                        color: root.theme.fg
                                        text: colRowDel.modelData.label
                                    }

                                    Rectangle {
                                        width: 22
                                        height: 20
                                        radius: 3
                                        color: root.isValidHex(colRowDel.curHex) ? colRowDel.curHex : "#000000"
                                        border.color: root.theme.muted
                                        border.width: 1
                                    }

                                    Rectangle {
                                        width: 82
                                        height: 22
                                        color: root.theme.panelBg
                                        border.color: hexInput.activeFocus ? root.theme.accent : root.theme.muted
                                        border.width: 1

                                        TextInput {
                                            id: hexInput
                                            anchors { fill: parent; margins: 4 }
                                            font.family: root.monoFamily
                                            font.pixelSize: 10
                                            color: root.theme.fg
                                            text: colRowDel.curHex
                                            maximumLength: 7
                                            onTextEdited: {
                                                if (root.isValidHex(text)) {
                                                    root.patchDraft(colRowDel.modelData.key, text);
                                                    if (colRowDel.modelData.key === "closeBtnBg") {
                                                        root.patchDraft("danger", text);
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Row {
                                        spacing: 3
                                        Repeater {
                                            model: colRowDel.modelData.chips
                                            delegate: Rectangle {
                                                id: chipDel
                                                required property string modelData
                                                width: 18
                                                height: 18
                                                radius: 3
                                                color: chipDel.modelData
                                                border.color: (colRowDel.curHex.toUpperCase() === chipDel.modelData.toUpperCase()) ? root.theme.accent : root.theme.muted
                                                border.width: (colRowDel.curHex.toUpperCase() === chipDel.modelData.toUpperCase()) ? 2 : 1

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        root.patchDraft(colRowDel.modelData.key, chipDel.modelData);
                                                        if (colRowDel.modelData.key === "closeBtnBg") {
                                                            root.patchDraft("danger", chipDel.modelData);
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Item { Layout.fillWidth: true }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Footer Action Bar
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
                implicitWidth: Math.min(138, rstThemeLbl.implicitWidth + 16)
                height: 26
                radius: Math.min(4, root.uiRadius)
                color: rstThemeMa.containsMouse ? root.theme.danger : root.theme.bg
                border.color: root.theme.danger
                border.width: 1
                Text {
                    id: rstThemeLbl
                    anchors.centerIn: parent
                    font.family: root.monoFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: rstThemeMa.containsMouse ? root.theme.bg : root.theme.danger
                    text: "[ ↺ Reset Preset ]"
                }
                MouseArea {
                    id: rstThemeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.resetToSelectedPreset()
                }
            }

            Rectangle {
                implicitWidth: Math.min(192, saveThemeLbl.implicitWidth + 16)
                height: 26
                scale: root.saveBounceScale
                radius: Math.min(4, root.uiRadius)
                color: saveThemeMa.containsMouse ? root.theme.secondary : root.theme.bg
                border.color: root.theme.secondary
                border.width: 1
                Text {
                    id: saveThemeLbl
                    anchors.centerIn: parent
                    font.family: root.monoFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: saveThemeMa.containsMouse ? root.theme.bg : root.theme.secondary
                    text: "[ ✓ Save & Apply Theme ]"
                }
                MouseArea {
                    id: saveThemeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.saveCustomDraft()
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
            color: resizeThemeMa.containsMouse ? root.theme.accent : root.theme.muted
            text: "◢"
        }
        MouseArea {
            id: resizeThemeMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeFDiagCursor
            property real startX: 0
            property real startY: 0
            property real startW: 0
            property real startH: 0
            onPressed: (mouse) => {
                startX = mouse.x;
                startY = mouse.y;
                startW = root.width;
                startH = root.height;
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
