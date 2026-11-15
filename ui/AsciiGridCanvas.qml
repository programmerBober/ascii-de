/*
    SPDX-FileCopyrightText: 2026 Terminal Plasma
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick

Item {
    id: gridRoot

    property bool showXmasTree: true
    property bool xmasIntroDone: false
    readonly property string xmasSource: xmasIntroDone ? Qt.resolvedUrl("xmas_tree.webp") : Qt.resolvedUrl("xmas_tree_intro.webp")
    property string visualizerMode: (theme && theme.visualizerMode) ? theme.visualizerMode : "stripes"
    property var customAudioBands: []
    property real customMusicEnergy: -1.0

    function restartXmasIntro() {
        xmasIntroDone = false;
        if (xmasTreeAnim) {
            xmasTreeAnim.currentFrame = 0;
        }
    }

    function updateAudioSpectrum(bands, energy) {
        if (bands && bands.length) {
            customAudioBands = bands;
        }
        if (energy !== undefined && energy >= 0.0) {
            customMusicEnergy = energy;
        }
    }

    property var theme: ({
        name: "amber",
        bg: "#0d0f10",
        bgSecondary: "#0d0f10",
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
        customBgText: "",
        xmasMonitor: "tallest",
        gridChar: "·",
        cornerRadius: 0,
        borderWidth: 1,
        smearDrag: false,
        impactFlash: false,
        speedLines: false,
        originSmear: false
    })

    property string bgStyleOverride: ""
    property var monitorAsciiImage: null
    property var imageTiles: []

    property bool showGridDots: true
    property string gridDensity: "normal" // "sparse", "normal", "dense"
    readonly property int colWidth: gridDensity === "sparse" ? 16 : (gridDensity === "dense" ? 9 : 12)
    readonly property int rowHeight: gridDensity === "sparse" ? 28 : (gridDensity === "dense" ? 16 : 22)
    readonly property string bgStyle: bgStyleOverride !== "" ? bgStyleOverride : ((theme && theme.backgroundStyle) ? theme.backgroundStyle : "ascii_grid")
    readonly property string effectiveFontFamily: (theme && theme.fontFamily) ? theme.fontFamily : "JetBrains Mono"
    readonly property bool isLensSnap: bgStyle === "snaptic_void" || (theme && theme.chromeStyle === "snaptic_datalens")
    readonly property string secColor: (theme && theme.secondary) ? theme.secondary : "#45C2FF"
    readonly property string gridColor: (theme && theme.gridDot) ? theme.gridDot : "#252a30"

    property string activeSnapZone: ""
    property rect snapPreviewRect: Qt.rect(0, 0, 0, 0)
    property real voidTime: 0.0

    onWidthChanged: dotCanvas.requestPaint()
    onHeightChanged: dotCanvas.requestPaint()
    onShowGridDotsChanged: dotCanvas.requestPaint()
    onGridDensityChanged: {
        dotCanvas.requestPaint();
        if (!isLensSnap) snapCanvas.requestPaint();
    }
    onThemeChanged: {
        dotCanvas.requestPaint();
        stairsStamp.requestPaint();
        if (!isLensSnap) snapCanvas.requestPaint();
    }
    onActiveSnapZoneChanged: {
        if (!isLensSnap) snapCanvas.requestPaint();
    }
    onSnapPreviewRectChanged: {
        if (!isLensSnap) snapCanvas.requestPaint();
    }

    // Cheap GPU property clock — NO per-frame Canvas software repaints!
    FrameAnimation {
        id: bgFrameAnim
        running: gridRoot.visible && (
            gridRoot.bgStyle === "snaptic_void"
            || (gridRoot.bgStyle === "christmas_tree" && gridRoot.showXmasTree)
            || gridRoot.bgStyle === "newsboard"
            || gridRoot.bgStyle === "visualizer"
            || gridRoot.bgStyle === "visualizer_stripes"
            || gridRoot.bgStyle === "visualizer_dots"
        )
        onTriggered: gridRoot.voidTime += frameTime
    }

    // Base fill / gradient according to theme.backgroundStyle
    Rectangle {
        anchors.fill: parent
        visible: gridRoot.bgStyle !== "gradient" && gridRoot.bgStyle !== "snaptic_void"
        color: (gridRoot.theme && gridRoot.theme.bg) ? gridRoot.theme.bg : "#0d0f10"
    }

    Rectangle {
        anchors.fill: parent
        visible: gridRoot.bgStyle === "gradient" || gridRoot.bgStyle === "snaptic_void"
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: (gridRoot.theme && gridRoot.theme.bg) ? gridRoot.theme.bg : "#E8ECFC"
            }
            GradientStop {
                position: 1.0
                color: (gridRoot.theme && gridRoot.theme.bgSecondary)
                    ? gridRoot.theme.bgSecondary
                    : ((gridRoot.theme && gridRoot.theme.bg) ? gridRoot.theme.bg : "#C5CEF7")
            }
        }
    }

    // 3D Rotating dwcminh ASCII Christmas Tree backdrop (defaults to tallest monitor)
    Rectangle {
        anchors.fill: parent
        visible: gridRoot.bgStyle === "christmas_tree" && gridRoot.showXmasTree
        color: "#090a10"
        clip: true

        // 1. Soft atmospheric deep pine radiant glow behind tree
        Rectangle {
            id: treeAura
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 36
            width: Math.min(parent.width * 0.72, 650)
            height: Math.min(parent.height * 0.76, 880)
            radius: width * 0.5
            color: "#143a24"
            opacity: 0.28 + 0.10 * Math.sin(gridRoot.voidTime * 1.5)
            scale: 0.95 + 0.05 * Math.sin(gridRoot.voidTime * 1.2)
        }

        // 2. Radiant golden star bloom halo at topper height
        Rectangle {
            id: starHalo
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(16, xmasTreeAnim.y + xmasTreeAnim.height * 0.17 - 75)
            width: 150
            height: 150
            radius: 75
            color: "#ffc83b"
            opacity: gridRoot.xmasIntroDone ? (0.24 + 0.12 * Math.sin(gridRoot.voidTime * 3.2)) : 0.08
            scale: 0.90 + 0.12 * Math.sin(gridRoot.voidTime * 2.8)
        }

        AnimatedImage {
            id: xmasTreeAnim
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            anchors.topMargin: 28
            anchors.bottomMargin: 28
            fillMode: Image.PreserveAspectFit
            smooth: true
            cache: true
            asynchronous: true
            source: gridRoot.xmasSource
            playing: visible
            onCurrentFrameChanged: {
                if (!gridRoot.xmasIntroDone && frameCount > 1 && currentFrame >= frameCount - 1) {
                    gridRoot.xmasIntroDone = true;
                }
            }
        }
    }

    // Static cached ASCII dot matrix (threaded, paints ONCE on init/resize/theme change)
    Canvas {
        id: dotCanvas
        anchors.fill: parent
        visible: gridRoot.showGridDots && (
            gridRoot.bgStyle === "ascii_grid"
            || gridRoot.bgStyle === "terminal"
            || gridRoot.bgStyle === "ascii_image"
            || gridRoot.bgStyle === "snaptic_void"
            || gridRoot.bgStyle === "visualizer_dots"
            || (gridRoot.bgStyle === "christmas_tree" && !gridRoot.showXmasTree)
        )
        opacity: gridRoot.bgStyle === "snaptic_void" ? 0.30 : (gridRoot.bgStyle === "christmas_tree" ? 0.48 : 1.0)
        renderStrategy: Canvas.Threaded

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (!visible || width <= 0 || height <= 0) {
                return;
            }
            var step = gridRoot.bgStyle === "snaptic_void" ? 2 : 1;
            var cw = gridRoot.colWidth * step;
            var rh = gridRoot.rowHeight * step;
            var cols = Math.ceil(width / cw);
            var rows = Math.ceil(height / rh);
            var gridColor = (gridRoot.theme && gridRoot.theme.gridDot) ? gridRoot.theme.gridDot : "#252a30";
            var glyph = (gridRoot.theme && gridRoot.theme.gridChar && gridRoot.theme.gridChar.length > 0)
                ? gridRoot.theme.gridChar
                : (gridRoot.bgStyle === "snaptic_void" ? "∘" : "·");

            ctx.fillStyle = gridColor;
            ctx.font = (gridRoot.bgStyle === "snaptic_void" ? "12px '" : "13px '") + gridRoot.effectiveFontFamily + "'";
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";

            for (var r = 0; r < rows; r++) {
                var py = r * rh + rh * 0.5;
                for (var c = 0; c < cols; c++) {
                    var px = c * cw + cw * 0.5;
                    ctx.fillText(glyph, px, py);
                }
            }
        }
    }

    // GPU-composited SNAPTIC Data-Void Layer (zero per-frame Canvas rasterization!)
    Item {
        id: snapticVoidLayer
        anchors.fill: parent
        visible: gridRoot.bgStyle === "snaptic_void"
        clip: true

        // 1. Pulsing Glowing Cyan Data Pools + Expanding Ripple Rings (GPU ellipses)
        Repeater {
            model: [
                { cx: 0.76, cy: 0.72, rx: 0.19, ry: 0.11, phase: 0.0 },
                { cx: 0.18, cy: 0.25, rx: 0.13, ry: 0.075, phase: 0.37 },
                { cx: 0.45, cy: 0.86, rx: 0.15, ry: 0.08, phase: 0.71 }
            ]

            delegate: Item {
                id: poolItem
                required property var modelData
                required property int index

                readonly property real baseW: Math.max(40, gridRoot.width * modelData.rx * 2.0)
                readonly property real baseH: Math.max(24, gridRoot.height * modelData.ry * 2.0)
                readonly property real squashY: baseH / baseW

                x: gridRoot.width * modelData.cx - baseW * 0.5
                y: gridRoot.height * modelData.cy - baseW * 0.5
                width: baseW
                height: baseW
                transform: Scale {
                    origin.x: poolItem.baseW * 0.5
                    origin.y: poolItem.baseW * 0.5
                    yScale: poolItem.squashY
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width * 0.5
                    color: gridRoot.secColor
                    opacity: 0.12 + 0.05 * Math.sin(gridRoot.voidTime * 1.8 + poolItem.index)
                }

                Repeater {
                    model: 3
                    delegate: Rectangle {
                        id: ringRect
                        required property int index
                        readonly property real rp: (gridRoot.voidTime * 0.36 + poolItem.modelData.phase + index * 0.333) % 1.0
                        anchors.centerIn: parent
                        width: parent.width
                        height: parent.height
                        radius: width * 0.5
                        color: "transparent"
                        border.color: index === 0 ? "#FFFFFF" : gridRoot.secColor
                        border.width: 2.0
                        scale: 0.35 + rp * 1.15
                        opacity: (1.0 - rp) * 0.45
                    }
                }
            }
        }

        // 2. Isometric Wireframe Stairs (cached tiny Canvas stamp, GPU bobbing)
        Canvas {
            id: stairsStamp
            width: 340
            height: 210
            x: gridRoot.width * 0.62 - 12
            y: gridRoot.height * 0.70 - 125 + Math.sin(gridRoot.voidTime * 1.25) * 7.0
            renderStrategy: Canvas.Threaded

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.strokeStyle = gridRoot.gridColor;
                ctx.lineWidth = 1.3;
                var baseX = 12;
                var baseY = 125;
                for (var step = 0; step < 4; step++) {
                    var sx = baseX + step * 52;
                    var sy = baseY - step * 34;
                    var sw = 96;
                    var sh = 34;
                    ctx.globalAlpha = 0.34;
                    ctx.beginPath();
                    ctx.moveTo(sx, sy);
                    ctx.lineTo(sx + sw, sy - 22);
                    ctx.lineTo(sx + sw + 48, sy + 4);
                    ctx.lineTo(sx + 48, sy + 26);
                    ctx.closePath();
                    ctx.stroke();

                    ctx.globalAlpha = 0.22;
                    ctx.beginPath();
                    ctx.moveTo(sx, sy);
                    ctx.lineTo(sx, sy + sh);
                    ctx.lineTo(sx + 48, sy + 26 + sh);
                    ctx.lineTo(sx + 48, sy + 26);
                    ctx.stroke();
                }
            }
        }

        // 3. Floating Wireframe Diamonds & Isometric Cubes (pre-cached mini stamps, GPU bobbing)
        Repeater {
            model: [
                { cx: 0.14, cy: 0.30, size: 26, speed: 1.3, ph: 0.2, kind: 0 },
                { cx: 0.84, cy: 0.24, size: 20, speed: 1.7, ph: 1.4, kind: 1 },
                { cx: 0.33, cy: 0.66, size: 18, speed: 1.5, ph: 2.6, kind: 1 },
                { cx: 0.54, cy: 0.20, size: 22, speed: 1.1, ph: 3.9, kind: 0 }
            ]

            delegate: Canvas {
                id: shapeStamp
                required property var modelData
                required property int index

                readonly property real sz: modelData.size
                width: Math.ceil(sz * 2.4 + 16)
                height: Math.ceil(sz * 2.4 + 16)
                x: gridRoot.width * modelData.cx - width * 0.5
                y: gridRoot.height * modelData.cy - height * 0.5 + Math.sin(gridRoot.voidTime * modelData.speed + modelData.ph) * 9.0
                opacity: 0.38
                renderStrategy: Canvas.Threaded

                readonly property color strokeCol: (index % 2 === 0) ? "#FFFFFF" : gridRoot.secColor
                onStrokeColChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    var cx = width * 0.5;
                    var cy = height * 0.5;
                    var s = shapeStamp.sz;
                    ctx.strokeStyle = shapeStamp.strokeCol;
                    ctx.lineWidth = 1.4;
                    if (shapeStamp.modelData.kind === 0) {
                        ctx.beginPath();
                        ctx.moveTo(cx, cy - s);
                        ctx.lineTo(cx + s * 0.85, cy);
                        ctx.lineTo(cx, cy + s);
                        ctx.lineTo(cx - s * 0.85, cy);
                        ctx.closePath();
                        ctx.stroke();
                    } else {
                        var h = s * 0.7;
                        ctx.strokeRect(cx - h, cy - h, h * 2, h * 2);
                        ctx.beginPath();
                        ctx.moveTo(cx - h, cy - h);
                        ctx.lineTo(cx - h + 10, cy - h - 10);
                        ctx.lineTo(cx + h + 10, cy - h - 10);
                        ctx.lineTo(cx + h, cy - h);
                        ctx.moveTo(cx + h + 10, cy - h - 10);
                        ctx.lineTo(cx + h + 10, cy + h - 10);
                        ctx.lineTo(cx + h, cy + h);
                        ctx.stroke();
                    }
                }
            }
        }

        // 4. Ascending Cache Sparkles & Digital Spear Streaks (pure lightweight GPU sprites)
        Repeater {
            model: 16
            delegate: Item {
                id: moteItem
                required property int index

                readonly property real seedX: ((index * 173 + 41) % 97) / 97.0
                readonly property real seedY: ((index * 257 + 19) % 101) / 101.0
                readonly property real speed: 0.045 + (index % 5) * 0.018
                readonly property real fracY: ((seedY - gridRoot.voidTime * speed) % 1.0 + 1.0) % 1.0
                readonly property real edgeFade: Math.sin(fracY * Math.PI)

                x: seedX * gridRoot.width + Math.sin(gridRoot.voidTime * 1.4 + index) * 10.0 - 8
                y: fracY * gridRoot.height - 8
                width: 16
                height: 26
                opacity: 0.25 + 0.55 * edgeFade

                Rectangle {
                    visible: moteItem.index % 3 === 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 2
                    height: 16 + (moteItem.index % 3) * 7
                    color: (moteItem.index % 2 === 0) ? "#FFFFFF" : gridRoot.secColor
                }

                Text {
                    visible: moteItem.index % 3 !== 0
                    anchors.centerIn: parent
                    font.family: gridRoot.effectiveFontFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: (moteItem.index % 2 === 0) ? gridRoot.secColor : "#FFFFFF"
                    text: "✦"
                }
            }
        }
    }

    // Live Newsboard Wallpaper: Monospace System & Tech Broadsheet
    Item {
        id: newsboardLayer
        anchors.fill: parent
        anchors.margins: 20
        visible: gridRoot.bgStyle === "newsboard"
        clip: true

        readonly property string fgCol: (gridRoot.theme && gridRoot.theme.fg) ? gridRoot.theme.fg : "#e6dcc8"
        readonly property string accentCol: (gridRoot.theme && gridRoot.theme.accent) ? gridRoot.theme.accent : "#ffb000"
        readonly property string secCol: gridRoot.secColor
        readonly property string mutedCol: (gridRoot.theme && gridRoot.theme.muted) ? gridRoot.theme.muted : "#6e7681"
        readonly property string borderCol: (gridRoot.theme && gridRoot.theme.gridDot) ? gridRoot.theme.gridDot : "#252a30"

        property string liveTimeStr: Qt.formatDateTime(new Date(), "yyyy-MM-dd  ·  hh:mm:ss")
        property int wireIndex: 0

        Timer {
            interval: 1000
            running: newsboardLayer.visible
            repeat: true
            onTriggered: {
                newsboardLayer.liveTimeStr = Qt.formatDateTime(new Date(), "yyyy-MM-dd  ·  hh:mm:ss");
                newsboardLayer.wireIndex = (newsboardLayer.wireIndex + 1) % 6;
            }
        }

        Column {
            anchors.fill: parent
            spacing: 12

            // Masthead Banner
            Rectangle {
                width: parent.width
                height: 64
                color: Qt.alpha(newsboardLayer.borderCol, 0.35)
                border.color: newsboardLayer.borderCol
                border.width: 1

                Column {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.family: gridRoot.effectiveFontFamily
                        font.pixelSize: 14
                        font.bold: true
                        color: newsboardLayer.accentCol
                        text: "★ ★ ★  THE WAYLAND TELETYPE & SYSTEM GAZETTE  ★ ★ ★"
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.family: gridRoot.effectiveFontFamily
                        font.pixelSize: 11
                        color: newsboardLayer.mutedCol
                        text: "[ VOL. 2026 · ISSUE #142 ]   [ " + newsboardLayer.liveTimeStr + " ]   [ STATION: LOCALHOST ]"
                    }
                }
            }

            // 3 Column Grid
            Item {
                width: parent.width
                height: Math.max(120, parent.height - 115)

                Row {
                    anchors.fill: parent
                    spacing: 12

                    // Column 1: System Telemetry
                    Rectangle {
                        width: Math.max(80, (parent.width - 24) / 3)
                        height: parent.height
                        color: Qt.alpha(newsboardLayer.borderCol, 0.20)
                        border.color: newsboardLayer.borderCol
                        border.width: 1

                        Column {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 8

                            Text {
                                font.family: gridRoot.effectiveFontFamily
                                font.pixelSize: 12
                                font.bold: true
                                color: newsboardLayer.accentCol
                                text: "┌─[ 01 · SYSTEM TELEMETRY ]"
                            }
                            Text {
                                width: parent.width - 28
                                wrapMode: Text.Wrap
                                font.family: gridRoot.effectiveFontFamily
                                font.pixelSize: 11
                                color: newsboardLayer.fgCol
                                text: "│ COMPOSITOR : ascii-de-compositor\n" +
                                      "│ PROTOCOL   : Wayland wl_output v4\n" +
                                      "│ RENDERING  : QtQuick Wayland (EGL/DRM)\n" +
                                      "│ AUDIO SINK : PipeWire · WirePlumber\n" +
                                      "│ CURRENT THEME: " + ((gridRoot.theme && gridRoot.theme.name) ? gridRoot.theme.name : "amber") + "\n" +
                                      "│ FONT       : " + gridRoot.effectiveFontFamily + "\n" +
                                      "│ UPTIME     : OPERATIONAL (NO LEAKS)\n" +
                                      "└──────────────────────────────────────"
                            }
                        }
                    }

                    // Column 2: Live Tech Wires & Headlines
                    Rectangle {
                        width: Math.max(80, (parent.width - 24) / 3)
                        height: parent.height
                        color: Qt.alpha(newsboardLayer.borderCol, 0.20)
                        border.color: newsboardLayer.borderCol
                        border.width: 1

                        Column {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 8

                            Text {
                                font.family: gridRoot.effectiveFontFamily
                                font.pixelSize: 12
                                font.bold: true
                                color: newsboardLayer.secCol
                                text: "┌─[ 02 · DISPATCH & WIRES ]"
                            }

                            Repeater {
                                model: [
                                    { time: "22:15", title: "ASCII-DE WAYLAND COMPOSITOR ONLINE" },
                                    { time: "22:10", title: "PIPEWIRE AUDIO & SESSION TELEMETRY" },
                                    { time: "22:05", title: "MEMORY USAGE CLEAN · 0 LEAKS REPORTED" },
                                    { time: "22:00", title: "NOTIFICATION SERVER & CLIPBOARD READY" },
                                    { time: "21:50", title: "XWAYLAND SURFACE SYNC ENGAGED" },
                                    { time: "21:40", title: "MULTI-MONITOR LAYOUT ENGINE ACTIVE" }
                                ]
                                delegate: Text {
                                    required property var modelData
                                    required property int index
                                    width: parent.width - 28
                                    elide: Text.ElideRight
                                    font.family: gridRoot.effectiveFontFamily
                                    font.pixelSize: 11
                                    color: (newsboardLayer.wireIndex === index) ? newsboardLayer.accentCol : newsboardLayer.fgCol
                                    text: "│ [" + modelData.time + "] " + modelData.title + ((newsboardLayer.wireIndex === index) ? " ◄" : "")
                                }
                            }

                            Text {
                                font.family: gridRoot.effectiveFontFamily
                                font.pixelSize: 11
                                color: newsboardLayer.mutedCol
                                text: "└──────────────────────────────────────"
                            }
                        }
                    }

                    // Column 3: Quick Commands & Hotkeys
                    Rectangle {
                        width: Math.max(80, (parent.width - 24) / 3)
                        height: parent.height
                        color: Qt.alpha(newsboardLayer.borderCol, 0.20)
                        border.color: newsboardLayer.borderCol
                        border.width: 1

                        Column {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 8

                            Text {
                                font.family: gridRoot.effectiveFontFamily
                                font.pixelSize: 12
                                font.bold: true
                                color: newsboardLayer.accentCol
                                text: "┌─[ 03 · COMMAND DIRECTORY ]"
                            }
                            Text {
                                width: parent.width - 28
                                font.family: gridRoot.effectiveFontFamily
                                font.pixelSize: 11
                                color: newsboardLayer.fgCol
                                text: "│ Meta + Enter  : Monospace Terminal\n" +
                                      "│ Meta + Space  : Application Launcher\n" +
                                      "│ Meta + V      : Clipboard Drawer\n" +
                                      "│ Meta + N      : Notification Center\n" +
                                      "│ Meta + S      : System Settings\n" +
                                      "│ Meta + T      : Theme Studio & Visuals\n" +
                                      "│ Meta + P      : Display Editor\n" +
                                      "│ Meta + F / Q  : Fullscreen / Close\n" +
                                      "└──────────────────────────────────────"
                            }
                        }
                    }
                }
            }

            // Bottom Ticker Bar
            Rectangle {
                width: parent.width
                height: 28
                color: Qt.alpha(newsboardLayer.borderCol, 0.35)
                border.color: newsboardLayer.borderCol
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    font.family: gridRoot.effectiveFontFamily
                    font.pixelSize: 11
                    color: newsboardLayer.secCol
                    text: ">>> WIRE: ALL SYSTEMS NOMINAL · NVIDIA EGL/DRM ACCELERATED · ONKYO 5.1 SURROUND READY · HAPPY HACKING <<<"
                }
            }
        }
    }

    // Music-responsive Visualizer: Real-time procedural & reactive equalizer/matrix
    Item {
        id: visualizerLayer
        anchors.fill: parent
        visible: gridRoot.bgStyle === "visualizer" || gridRoot.bgStyle === "visualizer_stripes" || gridRoot.bgStyle === "visualizer_dots"
        clip: true

        readonly property string visMode: (gridRoot.bgStyle === "visualizer_dots" || gridRoot.visualizerMode === "dots") ? "dots" : "stripes"
        readonly property int stripeCount: 28

        function getBandHeight(idx) {
            if (gridRoot.customAudioBands && gridRoot.customAudioBands.length > idx) {
                return Math.max(0.04, Math.min(1.0, gridRoot.customAudioBands[idx]));
            }
            var t = gridRoot.voidTime;
            var bass = Math.sin(t * 3.6) * 0.45 + Math.sin(t * 7.2) * 0.30;
            var mid = Math.sin(t * 4.8 + idx * 0.4) * 0.35 + Math.cos(t * 2.2 + idx * 0.25) * 0.25;
            var treble = Math.sin(t * 6.4 + idx * 0.7) * 0.30 * (1.0 - idx / 28.0);
            var energy = (gridRoot.customMusicEnergy >= 0.0) ? gridRoot.customMusicEnergy : 0.85;
            var val = (0.28 + (idx < 7 ? bass * 0.55 : (idx < 18 ? mid * 0.45 : treble * 0.45)) + Math.sin(idx * 0.6 + t * 2.4) * 0.18) * energy;
            return Math.max(0.05, Math.min(0.96, val));
        }

        // Mode 1: Equalizer Stripes
        Item {
            anchors.fill: parent
            visible: visualizerLayer.visMode === "stripes"

            Row {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.max(4, Math.floor((parent.width - 64) / visualizerLayer.stripeCount) - 18)

                Repeater {
                    model: visualizerLayer.stripeCount

                    delegate: Item {
                        id: stripeItem
                        required property int index

                        readonly property real bandVal: visualizerLayer.getBandHeight(index)
                        readonly property real maxH: Math.min(gridRoot.height * 0.65, 480)
                        readonly property real currentH: maxH * bandVal

                        width: 18
                        height: maxH

                        // Glowing vertical bar
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 14
                            height: stripeItem.currentH
                            radius: 3
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: (stripeItem.index % 2 === 0) ? gridRoot.secColor : (gridRoot.theme.accent || "#ffb000") }
                                GradientStop { position: 1.0; color: Qt.alpha(gridRoot.theme.bg || "#0d0f10", 0.1) }
                            }
                            opacity: 0.65 + 0.35 * stripeItem.bandVal
                        }

                        // Floating peak indicator dot
                        Text {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Math.min(stripeItem.maxH - 14, stripeItem.currentH + 8)
                            anchors.horizontalCenter: parent.horizontalCenter
                            font.family: gridRoot.effectiveFontFamily
                            font.pixelSize: 14
                            font.bold: true
                            color: "#ffffff"
                            text: "¨"
                        }

                        // Bottom frequency label
                        Text {
                            anchors.top: parent.bottom
                            anchors.topMargin: 4
                            anchors.horizontalCenter: parent.horizontalCenter
                            font.family: gridRoot.effectiveFontFamily
                            font.pixelSize: 9
                            color: gridRoot.theme.muted || "#6e7681"
                            text: (stripeItem.index * 350 + 60) + "Hz"
                            visible: stripeItem.index % 3 === 0
                        }
                    }
                }
            }
        }

        // Mode 2: Audio Reactive Rippling Dot Matrix
        Item {
            anchors.fill: parent
            visible: visualizerLayer.visMode === "dots"

            Repeater {
                model: 48

                delegate: Item {
                    id: waveDotItem
                    required property int index

                    readonly property real colFrac: (index % 12) / 12.0
                    readonly property real rowFrac: Math.floor(index / 12) / 4.0
                    readonly property real wavePhase: gridRoot.voidTime * 3.5 + colFrac * 6.28 + rowFrac * 3.14
                    readonly property real waveAmp: Math.sin(wavePhase) * 0.5 + 0.5

                    x: gridRoot.width * (0.10 + colFrac * 0.80)
                    y: gridRoot.height * (0.20 + rowFrac * 0.60) + Math.sin(wavePhase) * 22.0
                    width: 28
                    height: 28

                    Text {
                        anchors.centerIn: parent
                        font.family: gridRoot.effectiveFontFamily
                        font.pixelSize: 12 + Math.floor(waveDotItem.waveAmp * 8.0)
                        font.bold: waveDotItem.waveAmp > 0.6
                        color: waveDotItem.waveAmp > 0.7 ? "#ffffff" : ((waveDotItem.index % 2 === 0) ? gridRoot.secColor : (gridRoot.theme.accent || "#ffb000"))
                        text: waveDotItem.waveAmp > 0.85 ? "✦" : (waveDotItem.waveAmp > 0.65 ? "●" : (waveDotItem.waveAmp > 0.4 ? "o" : "·"))
                        opacity: 0.35 + 0.65 * waveDotItem.waveAmp
                    }
                }
            }
        }
    }

    // Full-Monitor and Tiled Image-to-ASCII Layer
    Item {
        id: asciiImageLayer
        anchors.fill: parent
        visible: gridRoot.bgStyle === "ascii_image" || (gridRoot.imageTiles && gridRoot.imageTiles.length > 0)
        clip: true

        property var cacheMap: ({})
        property string pendingRequests: ""

        function getBackend() {
            // qmllint disable unqualified
            if (typeof Backend !== "undefined") return Backend;
            // qmllint enable unqualified
            return null;
        }

        function requestConversion(tag, imagePath, cols, rows, charset, colorMode, invert, bgHex) {
            if (!imagePath || imagePath.length === 0) return;
            var b = getBackend();
            if (!b || typeof b.runBackendAsync !== "function") return;

            var reqKey = tag + "|" + imagePath + "|" + cols + "|" + rows + "|" + charset + "|" + colorMode + "|" + (invert ? "1" : "0") + "|" + bgHex;
            if (pendingRequests === reqKey) return;
            pendingRequests = reqKey;

            var payload = JSON.stringify({
                imagePath: imagePath,
                cols: cols,
                rows: rows,
                charset: charset || "ascii",
                colorMode: colorMode || "colored",
                invert: Boolean(invert),
                bg: bgHex || "#0d0f10"
            });
            b.runBackendAsync(["bg-ascii", "convert", payload], tag);
        }

        Connections {
            target: asciiImageLayer.getBackend()
            ignoreUnknownSignals: true

            function onBackendResult(tag, jsonOutput) {
                if (!tag || !jsonOutput) return;
                if (tag === "bg_ascii_full" || tag.indexOf("bg_ascii_tile_") === 0) {
                    try {
                        var parsed = JSON.parse(jsonOutput.trim());
                        if (parsed && parsed.ok) {
                            var newMap = Object.assign({}, asciiImageLayer.cacheMap);
                            newMap[tag] = parsed;
                            asciiImageLayer.cacheMap = newMap;
                        }
                    } catch (e) {
                        // ignore parse errors
                    }
                }
            }
        }

        // 1. Full-Monitor ASCII Image (when bgStyle === "ascii_image")
        Item {
            id: fullMonitorAsciiItem
            anchors.fill: parent
            visible: gridRoot.bgStyle === "ascii_image" && Boolean(gridRoot.monitorAsciiImage && gridRoot.monitorAsciiImage.imagePath)

            readonly property var spec: gridRoot.monitorAsciiImage
            readonly property string imgPath: spec ? String(spec.imagePath || "") : ""
            readonly property string charset: spec ? String(spec.charset || "ascii") : "ascii"
            readonly property string colorMode: spec ? String(spec.colorMode || "colored") : "colored"
            readonly property bool invert: spec ? Boolean(spec.invert) : false
            readonly property real opacityVal: spec && spec.opacity !== undefined ? Number(spec.opacity) : 1.0
            readonly property int cols: Math.max(16, Math.min(360, Math.floor(gridRoot.width / gridRoot.colWidth)))
            readonly property int rows: Math.max(8, Math.min(180, Math.floor(gridRoot.height / gridRoot.rowHeight)))
            readonly property var cachedData: asciiImageLayer.cacheMap["bg_ascii_full"]

            opacity: opacityVal

            onImgPathChanged: triggerConvert()
            onCharsetChanged: triggerConvert()
            onColorModeChanged: triggerConvert()
            onInvertChanged: triggerConvert()
            onColsChanged: triggerConvert()
            onRowsChanged: triggerConvert()

            function triggerConvert() {
                if (!visible || !imgPath) return;
                var bgHex = (gridRoot.theme && gridRoot.theme.bg) ? gridRoot.theme.bg : "#0d0f10";
                asciiImageLayer.requestConversion("bg_ascii_full", imgPath, cols, rows, charset, colorMode, invert, bgHex);
            }

            Component.onCompleted: triggerConvert()

            Text {
                anchors.centerIn: parent
                font.family: gridRoot.effectiveFontFamily
                font.pixelSize: gridRoot.theme && gridRoot.theme.fontSize ? gridRoot.theme.fontSize : 11
                lineHeight: 0.92
                color: (fullMonitorAsciiItem.colorMode === "theme") ? (gridRoot.theme.fg || "#e6dcc8") : "#ffffff"
                textFormat: (fullMonitorAsciiItem.colorMode === "theme" || (fullMonitorAsciiItem.cachedData && !fullMonitorAsciiItem.cachedData.html))
                    ? Text.PlainText
                    : Text.RichText
                text: fullMonitorAsciiItem.cachedData
                    ? (fullMonitorAsciiItem.colorMode === "theme" ? fullMonitorAsciiItem.cachedData.plain : (fullMonitorAsciiItem.cachedData.html || fullMonitorAsciiItem.cachedData.plain))
                    : "[ Converting image to ASCII... ]"
            }
        }

        // 2. Per-Tile Image-to-ASCII Items (kind === "ascii_image")
        Repeater {
            model: gridRoot.imageTiles || []

            delegate: Item {
                id: tileDel
                required property var modelData
                required property int index

                readonly property var tile: modelData
                readonly property string tileId: tile ? String(tile.id || ("tile-" + index)) : ("tile-" + index)
                readonly property string imgPath: tile ? String(tile.imagePath || "") : ""
                readonly property string charset: tile ? String(tile.charset || "ascii") : "ascii"
                readonly property string colorMode: tile ? String(tile.colorMode || "colored") : "colored"
                readonly property bool invert: tile ? Boolean(tile.invert) : false
                readonly property real tileOpacity: tile && tile.opacity !== undefined ? Number(tile.opacity) : 1.0
                readonly property int tileW: tile && tile.width > 0 ? tile.width : 400
                readonly property int tileH: tile && tile.height > 0 ? tile.height : 300
                readonly property int cols: Math.max(12, Math.min(240, Math.floor(tileW / gridRoot.colWidth)))
                readonly property int rows: Math.max(6, Math.min(120, Math.floor(tileH / gridRoot.rowHeight)))
                readonly property string tag: "bg_ascii_tile_" + tileId
                readonly property var cachedData: asciiImageLayer.cacheMap[tag]

                x: tile && tile.x !== undefined ? tile.x : 20
                y: tile && tile.y !== undefined ? tile.y : 30
                width: tileW
                height: tileH
                visible: Boolean(tile && tile.enabled !== false && tile.kind === "ascii_image" && imgPath.length > 0)
                opacity: tileOpacity

                onImgPathChanged: triggerConvert()
                onCharsetChanged: triggerConvert()
                onColorModeChanged: triggerConvert()
                onInvertChanged: triggerConvert()
                onColsChanged: triggerConvert()
                onRowsChanged: triggerConvert()

                function triggerConvert() {
                    if (!visible || !imgPath) return;
                    var bgHex = (gridRoot.theme && gridRoot.theme.bg) ? gridRoot.theme.bg : "#0d0f10";
                    asciiImageLayer.requestConversion(tag, imgPath, cols, rows, charset, colorMode, invert, bgHex);
                }

                Component.onCompleted: triggerConvert()

                // Subtle dotted frame border matching theme palette
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: (gridRoot.theme && gridRoot.theme.gridDot) ? gridRoot.theme.gridDot : "#252a30"
                    border.width: 1
                    radius: 2
                    opacity: 0.65
                }

                Text {
                    anchors.centerIn: parent
                    font.family: gridRoot.effectiveFontFamily
                    font.pixelSize: tileDel.tile && tileDel.tile.fontSize > 0 ? tileDel.tile.fontSize : (gridRoot.theme && gridRoot.theme.fontSize ? gridRoot.theme.fontSize : 11)
                    lineHeight: 0.92
                    color: (tileDel.colorMode === "theme") ? (gridRoot.theme.fg || "#e6dcc8") : "#ffffff"
                    textFormat: (tileDel.colorMode === "theme" || (tileDel.cachedData && !tileDel.cachedData.html))
                        ? Text.PlainText
                        : Text.RichText
                    text: tileDel.cachedData
                        ? (tileDel.colorMode === "theme" ? tileDel.cachedData.plain : (tileDel.cachedData.html || tileDel.cachedData.plain))
                        : "[ " + tileDel.tileId + ": Converting ASCII Image... ]"
                }
            }
        }
    }

    // Dynamic overlay 1: GPU-animated SNAPTIC Data Lens Aero Snap preview (zero Canvas cost during drag)
    Rectangle {
        id: lensSnapOverlay
        visible: gridRoot.isLensSnap && gridRoot.activeSnapZone !== "" && gridRoot.snapPreviewRect.width > 0 && gridRoot.snapPreviewRect.height > 0
        x: gridRoot.snapPreviewRect.x + 4
        y: gridRoot.snapPreviewRect.y + 4
        width: Math.max(20, gridRoot.snapPreviewRect.width - 8)
        height: Math.max(20, gridRoot.snapPreviewRect.height - 8)
        radius: (gridRoot.theme && gridRoot.theme.cornerRadius > 0) ? Math.min(14, gridRoot.theme.cornerRadius) : 10
        color: Qt.alpha(gridRoot.theme && gridRoot.theme.snapLine ? gridRoot.theme.snapLine : "#45C2FF", 0.16)
        border.color: gridRoot.theme && gridRoot.theme.snapLine ? gridRoot.theme.snapLine : "#45C2FF"
        border.width: 3

        SequentialAnimation on opacity {
            running: lensSnapOverlay.visible
            loops: Animation.Infinite
            NumberAnimation { from: 0.65; to: 1.0; duration: 320; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1.0; to: 0.65; duration: 320; easing.type: Easing.InOutSine }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: Math.max(4, parent.radius - 2)
            color: "transparent"
            border.color: "#FFFFFF"
            border.width: 1
            opacity: 0.72
        }
    }

    // Dynamic overlay 2: Static-on-zone-change ASCII box-drawing snap preview
    Canvas {
        id: snapCanvas
        anchors.fill: parent
        visible: !gridRoot.isLensSnap && gridRoot.activeSnapZone !== "" && gridRoot.snapPreviewRect.width > 0 && gridRoot.snapPreviewRect.height > 0
        renderStrategy: Canvas.Threaded

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (!visible || width <= 0 || height <= 0) {
                return;
            }

            var sr = gridRoot.snapPreviewRect;
            var snapHex = (gridRoot.theme && gridRoot.theme.snapLine) ? gridRoot.theme.snapLine : "#8b949e";
            var cw = gridRoot.colWidth;
            var rh = gridRoot.rowHeight;
            var c0 = Math.max(0, Math.round(sr.x / cw));
            var r0 = Math.max(0, Math.round(sr.y / rh));
            var c1 = Math.max(c0 + 2, Math.round((sr.x + sr.width) / cw) - 1);
            var r1 = Math.max(r0 + 2, Math.round((sr.y + sr.height) / rh) - 1);
            var bgHex = (gridRoot.theme && gridRoot.theme.bg) ? gridRoot.theme.bg : "#0d0f10";

            ctx.fillStyle = "rgba(139, 148, 158, 0.08)";
            ctx.fillRect(c0 * cw, r0 * rh, (c1 - c0 + 1) * cw, (r1 - r0 + 1) * rh);

            ctx.font = "bold 14px '" + gridRoot.effectiveFontFamily + "'";
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";

            for (var c = c0; c <= c1; c++) {
                var xTop = c * cw;
                var yTop = r0 * rh;
                var yBot = r1 * rh;

                ctx.fillStyle = bgHex;
                ctx.fillRect(xTop, yTop, cw, rh);
                ctx.fillRect(xTop, yBot, cw, rh);

                ctx.fillStyle = snapHex;
                var topCh = (c === c0) ? "┌" : (c === c1 ? "┐" : "─");
                var botCh = (c === c0) ? "└" : (c === c1 ? "┘" : "─");
                ctx.fillText(topCh, xTop + cw * 0.5, yTop + rh * 0.5);
                ctx.fillText(botCh, xTop + cw * 0.5, yBot + rh * 0.5);
            }

            for (var r = r0 + 1; r < r1; r++) {
                var yMid = r * rh;
                var xLeft = c0 * cw;
                var xRight = c1 * cw;

                ctx.fillStyle = bgHex;
                ctx.fillRect(xLeft, yMid, cw, rh);
                ctx.fillRect(xRight, yMid, cw, rh);

                ctx.fillStyle = snapHex;
                ctx.fillText("│", xLeft + cw * 0.5, yMid + rh * 0.5);
                ctx.fillText("│", xRight + cw * 0.5, yMid + rh * 0.5);
            }
        }
    }
}
