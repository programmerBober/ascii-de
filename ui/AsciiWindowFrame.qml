/*
    SPDX-FileCopyrightText: 2026 Terminal Plasma
    SPDX-License-Identifier: GPL-2.0-or-later
*/
pragma ComponentBehavior: Bound
import QtQuick
import QtWayland.Compositor
import QtWayland.Compositor.XdgShell

Item {
    id: frameRoot

    property int winId: 0
    property int winIndex: 1
    property ShellSurface shellSurface: null
    property XdgToplevel xdgToplevel: null
    property var wlShellSurface: null
    property bool closing: false
    property bool initializedShell: false
    property int workspace: 1
    property bool active: false
    property bool minimized: false
    property bool maximized: false
    property bool clientFullscreen: false
    property string snapMode: "" // "", "left", "right", "maximize", "topleft", "topright", "bottomleft", "bottomright"
    property rect restoreRect: Qt.rect(120, 80, 900, 560)
    property rect preFullscreenRect: Qt.rect(120, 80, 900, 560)
    property string preFullscreenSnapMode: ""
    property bool preFullscreenMaximized: false
    property rect workArea: outputContainer ? outputContainer.workArea : Qt.rect(0, 26, 1600, 906)
    property real splitRatio: 0.5
    property var gridCanvas: null
    property var outputContainer: null
    property var parentFrame: null
    property bool multiMonitorMode: false
    property bool modDragHeld: false
    property bool snapEnabled: true
    property int snapThresholdPx: 24
    property bool crossMonitorDragging: true
    property string fontFamily: "JetBrains Mono"
    property int fontSize: 13
    property bool isBgTerminal: false
    property bool bgTerminalInteractive: false
    property string bgTileId: ""
    property string bgTileMonitor: ""
    readonly property rect clientWinGeom: (!closing && xdgToplevel && xdgToplevel.xdgSurface)
        ? xdgToplevel.xdgSurface.windowGeometry
        : Qt.rect(0, 0, 0, 0)
    readonly property int csdOffsetX: (clientWinGeom.width > 0 && clientWinGeom.x > 0) ? Math.round(clientWinGeom.x) : 0
    readonly property int csdOffsetY: (clientWinGeom.height > 0 && clientWinGeom.y > 0) ? Math.round(clientWinGeom.y) : 0
    // XDG Shell protocol state integers (xdg_toplevel_state)
    readonly property int stateTiledLeft: 5
    readonly property int stateTiledRight: 6
    readonly property int stateTiledTop: 7
    readonly property int stateTiledBottom: 8

    readonly property alias surfaceItem: clientSurfaceItem
    property var allOutputs: []

    function syncSurfaceOutput() {
        if (clientSurfaceItem && outputContainer) {
            // qmllint disable unqualified
            Backend.syncSurfaceOutput(clientSurfaceItem, outputContainer, allOutputs);
            Backend.normalizeClientSubsurfaces(clientSurfaceItem);
            // qmllint enable unqualified
        }
    }

    onOutputContainerChanged: {
        syncSurfaceOutput();
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
        gridChar: "·",
        cornerRadius: 0,
        borderWidth: 1,
        smearDrag: false,
        impactFlash: false,
        speedLines: false,
        originSmear: false
    })

    readonly property string winTitle: {
        if (!closing && xdgToplevel && xdgToplevel.title && xdgToplevel.title.length > 0) {
            return xdgToplevel.title;
        }
        if (!closing && shellSurface && wlShellSurface && wlShellSurface.title && wlShellSurface.title.length > 0) {
            return wlShellSurface.title;
        }
        return appId.length > 0 ? appId : "wayland-app";
    }

    readonly property string appId: {
        if (!closing && xdgToplevel && xdgToplevel.appId) {
            return xdgToplevel.appId;
        }
        if (!closing && shellSurface && wlShellSurface && wlShellSurface.className) {
            return wlShellSurface.className;
        }
        return "";
    }

    readonly property string chromeStyle: (frameRoot.theme && frameRoot.theme.chromeStyle) ? frameRoot.theme.chromeStyle : "ascii"
    readonly property bool isSnaptic: chromeStyle === "snaptic_datalens"
    readonly property bool isMinimal: chromeStyle === "minimal"
    readonly property bool isAscii: !isSnaptic && !isMinimal
    readonly property int frameCornerRadius: (clientFullscreen || maximized || snapMode === "maximize") ? 0 : (isSnaptic ? (Number(frameRoot.theme.cornerRadius) || 10) : 0)
    readonly property int frameBorderWidth: Math.max(1, Number(frameRoot.theme.borderWidth) || (isSnaptic ? 2 : 1))
    readonly property int topH: (clientFullscreen || isBgTerminal) ? 0 : (isSnaptic ? 32 : 26)
    readonly property int railW: (clientFullscreen || isBgTerminal || maximized || snapMode === "maximize") ? 0 : (isAscii ? 10 : frameBorderWidth)
    readonly property int botH: (clientFullscreen || isBgTerminal || maximized || snapMode === "maximize") ? 0 : (isAscii ? 18 : frameBorderWidth)
    readonly property int minWinW: 280
    readonly property int minWinH: 160
    readonly property bool inhibitsIdle: Boolean(!closing && clientSurfaceItem && clientSurfaceItem.surface && clientSurfaceItem.surface.inhibitsIdle)
    readonly property int effMinW: {
        var cw = railW * 2;
        var cMin = (!closing && xdgToplevel && xdgToplevel.minSize && xdgToplevel.minSize.width > 0) ? Math.round(xdgToplevel.minSize.width) : 0;
        var cMax = (!closing && xdgToplevel && xdgToplevel.maxSize && xdgToplevel.maxSize.width > 0) ? Math.round(xdgToplevel.maxSize.width) : 0;
        var fMin = cMin > 0 ? (cMin + cw) : minWinW;
        if (cMax > 0 && cMin === 0) {
            fMin = Math.min(minWinW, cMax + cw);
        }
        return Math.max(140, fMin);
    }
    readonly property int effMinH: {
        var ch = topH + botH;
        var cMin = (!closing && xdgToplevel && xdgToplevel.minSize && xdgToplevel.minSize.height > 0) ? Math.round(xdgToplevel.minSize.height) : 0;
        var cMax = (!closing && xdgToplevel && xdgToplevel.maxSize && xdgToplevel.maxSize.height > 0) ? Math.round(xdgToplevel.maxSize.height) : 0;
        var fMin = cMin > 0 ? (cMin + ch) : minWinH;
        if (cMax > 0 && cMin === 0) {
            fMin = Math.min(minWinH, cMax + ch);
        }
        return Math.max(100, fMin);
    }
    readonly property int effMaxW: {
        var cw = railW * 2;
        var cMax = (!closing && xdgToplevel && xdgToplevel.maxSize && xdgToplevel.maxSize.width > 0) ? Math.round(xdgToplevel.maxSize.width) : 0;
        if (cMax <= 0) return 0;
        var fMax = cMax + cw;
        return (fMax >= effMinW) ? fMax : 0; // guard set_min_size > maxSize
    }
    readonly property int effMaxH: {
        var ch = topH + botH;
        var cMax = (!closing && xdgToplevel && xdgToplevel.maxSize && xdgToplevel.maxSize.height > 0) ? Math.round(xdgToplevel.maxSize.height) : 0;
        if (cMax <= 0) return 0;
        var fMax = cMax + ch;
        return (fMax >= effMinH) ? fMax : 0; // guard set_min_size > maxSize
    }
    function clampFrameWidth(fw) {
        if (clientFullscreen || maximized || snapMode === "maximize") {
            return Math.round(fw);
        }
        var w = Math.max(effMinW, Math.round(fw));
        if (effMaxW > 0) {
            w = Math.min(effMaxW, w);
        }
        return w;
    }
    function clampFrameHeight(fh) {
        if (clientFullscreen || maximized || snapMode === "maximize") {
            return Math.round(fh);
        }
        var h = Math.max(effMinH, Math.round(fh));
        if (effMaxH > 0) {
            h = Math.min(effMaxH, h);
        }
        return h;
    }
    property bool initialSized: false
    property bool userResized: false
    property bool resizingNow: false
    property real smearSkewX: 0.0
    property real smearSkewY: 0.0
    property real smearStretchX: 1.0
    property real smearStretchY: 1.0
    property real trailLagX: 0.0
    property real trailLagY: 0.0
    property real trailAlpha: 0.0
    property real lastDragLocalX: 0.0
    property real lastDragLocalY: 0.0
    property double lastDragTimeMs: 0
    property bool dragVelocityPrimed: false
    property real impactBurst: 0.0

    Behavior on smearSkewX { enabled: Boolean(frameRoot.theme && frameRoot.theme.smearDrag); NumberAnimation { duration: 135; easing.type: Easing.OutQuad } }
    Behavior on smearSkewY { enabled: Boolean(frameRoot.theme && frameRoot.theme.smearDrag); NumberAnimation { duration: 135; easing.type: Easing.OutQuad } }
    Behavior on smearStretchX { enabled: Boolean(frameRoot.theme && frameRoot.theme.smearDrag); NumberAnimation { duration: 135; easing.type: Easing.OutQuad } }
    Behavior on smearStretchY { enabled: Boolean(frameRoot.theme && frameRoot.theme.smearDrag); NumberAnimation { duration: 135; easing.type: Easing.OutQuad } }
    Behavior on trailLagX { enabled: Boolean(frameRoot.theme && frameRoot.theme.smearDrag); NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
    Behavior on trailLagY { enabled: Boolean(frameRoot.theme && frameRoot.theme.smearDrag); NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
    Behavior on trailAlpha { enabled: Boolean(frameRoot.theme && frameRoot.theme.smearDrag); NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }

    transform: [
        Scale {
            id: impactScale
            origin.x: frameRoot.width * 0.5
            origin.y: frameRoot.height * 0.5
            xScale: 1.0
            yScale: 1.0
        },
        Scale {
            origin.x: frameRoot.width * 0.5
            origin.y: frameRoot.height * 0.5
            xScale: frameRoot.smearStretchX
            yScale: frameRoot.smearStretchY
        },
        Matrix4x4 {
            matrix: Qt.matrix4x4(
                1, frameRoot.smearSkewX, 0, 0,
                frameRoot.smearSkewY, 1, 0, 0,
                0, 0, 1, 0,
                0, 0, 0, 1
            )
        }
    ]

    function resetDragSmear() {
        smearSkewX = 0.0;
        smearSkewY = 0.0;
        smearStretchX = 1.0;
        smearStretchY = 1.0;
        trailLagX = 0.0;
        trailLagY = 0.0;
        trailAlpha = 0.0;
        dragVelocityPrimed = false;
    }

    Timer {
        id: smearDecayTimer
        interval: 45
        repeat: false
        onTriggered: frameRoot.resetDragSmear()
    }

    ParallelAnimation {
        id: impactAnim
        SequentialAnimation {
            NumberAnimation { target: impactScale; property: "xScale"; from: 0.85; to: 1.07; duration: 95; easing.type: Easing.OutCubic }
            NumberAnimation { target: impactScale; property: "xScale"; to: 0.98; duration: 75; easing.type: Easing.InOutQuad }
            NumberAnimation { target: impactScale; property: "xScale"; to: 1.0; duration: 80; easing.type: Easing.OutQuad }
        }
        SequentialAnimation {
            NumberAnimation { target: impactScale; property: "yScale"; from: 0.85; to: 1.07; duration: 95; easing.type: Easing.OutCubic }
            NumberAnimation { target: impactScale; property: "yScale"; to: 0.98; duration: 75; easing.type: Easing.InOutQuad }
            NumberAnimation { target: impactScale; property: "yScale"; to: 1.0; duration: 80; easing.type: Easing.OutQuad }
        }
        SequentialAnimation {
            // High-contrast 2-frame cyan/white/indigo impact flash
            PropertyAction { target: impactFlashOverlay; property: "border.color"; value: "#FFFFFF" }
            PropertyAction { target: impactFlashOverlay; property: "opacity"; value: 0.95 }
            PauseAnimation { duration: 22 }
            PropertyAction { target: impactFlashOverlay; property: "border.color"; value: "#45C2FF" }
            PauseAnimation { duration: 22 }
            PropertyAction { target: impactFlashOverlay; property: "border.color"; value: "#3E4670" }
            NumberAnimation { target: impactFlashOverlay; property: "opacity"; to: 0.0; duration: 70; easing.type: Easing.OutQuad }
        }
        SequentialAnimation {
            PropertyAction { target: frameRoot; property: "impactBurst"; value: 0.0 }
            PropertyAction { target: impactCornerSpears; property: "opacity"; value: 1.0 }
            ParallelAnimation {
                NumberAnimation { target: frameRoot; property: "impactBurst"; from: 0.0; to: 1.0; duration: 210; easing.type: Easing.OutCubic }
                NumberAnimation { target: impactCornerSpears; property: "opacity"; from: 1.0; to: 0.0; duration: 210; easing.type: Easing.InQuad }
            }
        }
    }

    function triggerImpact() {
        if (frameRoot.theme && frameRoot.theme.impactFlash === true) {
            impactAnim.restart();
        }
    }

    function updateDragVelocity(localX, localY) {
        if (!frameRoot.theme || frameRoot.theme.smearDrag !== true) {
            resetDragSmear();
            return;
        }
        var now = Date.now();
        if (!dragVelocityPrimed) {
            dragVelocityPrimed = true;
            lastDragLocalX = localX;
            lastDragLocalY = localY;
            lastDragTimeMs = now;
            return;
        }
        var dt = Math.max(8, now - lastDragTimeMs);
        var vx = (localX - lastDragLocalX) / dt; // px/ms
        var vy = (localY - lastDragLocalY) / dt; // px/ms
        lastDragLocalX = localX;
        lastDragLocalY = localY;
        lastDragTimeMs = now;

        smearSkewX = Math.max(-0.18, Math.min(0.18, -vx * 0.095));
        smearSkewY = Math.max(-0.05, Math.min(0.05, -vy * 0.025));

        var speedX = Math.min(2.2, Math.abs(vx));
        var speedY = Math.min(2.2, Math.abs(vy));
        smearStretchX = 1.0 + speedX * 0.045 - speedY * 0.025;
        smearStretchY = 1.0 + speedY * 0.045 - speedX * 0.025;

        trailLagX = Math.max(-44, Math.min(44, vx * 22.0));
        trailLagY = Math.max(-28, Math.min(28, vy * 16.0));
        var mag = Math.hypot(vx, vy);
        trailAlpha = Math.min(1.0, Math.max(0.0, (mag - 0.08) * 1.15));
        smearDecayTimer.restart();
    }

    signal requestFocus(int winId)
    signal requestClose(int winId)
    signal requestToggleMinimize(int winId)
    signal requestToggleMaximize(int winId)
    signal requestToggleFullscreen(int winId)
    signal snapCommitted(int winId, string zone, rect targetRect)
    signal windowStateChanged()
    signal surfaceClosed(int winId)
    signal dragMoved(int winId, real globalX, real globalY)
    signal dragEnded(int winId, real globalX, real globalY)
    signal modReleaseRequested()
    signal tileMoved(string tileId, string monitor, int x, int y, int width, int height)

    onXChanged: {
        if (clientFullscreen && x !== 0) {
            x = 0;
        }
    }
    onYChanged: {
        if (clientFullscreen && y !== 0) {
            y = 0;
        }
    }

    readonly property font monoFont: Qt.font({
        family: (frameRoot.theme && frameRoot.theme.fontFamily) ? frameRoot.theme.fontFamily : frameRoot.fontFamily,
        pixelSize: (frameRoot.theme && frameRoot.theme.fontSize) ? Number(frameRoot.theme.fontSize) : frameRoot.fontSize
    })

    FontMetrics {
        id: fm
        font: frameRoot.monoFont
    }

    readonly property int charW: Math.max(7, Math.round(fm.advanceWidth("─")))
    readonly property int railStepH: Math.max(10, Math.floor(fm.ascent + fm.descent) - 2)
    readonly property color borderColor: frameRoot.active ? frameRoot.theme.accent : frameRoot.theme.muted
    readonly property color barBgColor: frameRoot.active ? frameRoot.theme.panelBg : frameRoot.theme.bg
    readonly property color textColor: frameRoot.active ? frameRoot.theme.fg : frameRoot.theme.muted

    function sendClientConfigure(clientW, clientH, isResizing) {
        if (closing) {
            return;
        }
        var allowZero = (clientW === 0 && clientH === 0 && !frameRoot.initialSized && !frameRoot.clientFullscreen && !frameRoot.maximized && frameRoot.snapMode === "");
        var cw = allowZero ? 0 : Math.max(120, Math.round(clientW));
        var ch = allowZero ? 0 : Math.max(80, Math.round(clientH));
        if (frameRoot.isBgTerminal) {
            cw = Math.max(120, Math.round(frameRoot.width));
            ch = Math.max(80, Math.round(frameRoot.height));
        } else if (frameRoot.clientFullscreen && frameRoot.outputContainer) {
            cw = Math.max(120, Math.round(frameRoot.outputContainer.outputWidth));
            ch = Math.max(80, Math.round(frameRoot.outputContainer.outputHeight));
        } else if ((frameRoot.maximized || frameRoot.snapMode === "maximize") && frameRoot.outputContainer) {
            let effWa = frameRoot.workArea;
            cw = Math.max(120, Math.round(effWa.width - frameRoot.railW * 2));
            ch = Math.max(80, Math.round(effWa.height - frameRoot.topH - frameRoot.botH));
        } else if (frameRoot.snapMode !== "") {
            cw = Math.max(120, Math.round(clientW > 0 ? clientW : (frameRoot.width - frameRoot.railW * 2)));
            ch = Math.max(80, Math.round(clientH > 0 ? clientH : (frameRoot.height - frameRoot.topH - frameRoot.botH)));
        }
        if (xdgToplevel && shellSurface && typeof xdgToplevel.sendConfigure === "function") {
            let states = [];
            if (frameRoot.active) {
                states.push(XdgToplevel.ActivatedState);
            }
            if (frameRoot.clientFullscreen) {
                states.push(XdgToplevel.FullscreenState);
            } else {
                states.push(frameRoot.stateTiledLeft);
                states.push(frameRoot.stateTiledRight);
                states.push(frameRoot.stateTiledTop);
                states.push(frameRoot.stateTiledBottom);
                if (frameRoot.maximized || frameRoot.snapMode !== "") {
                    states.push(XdgToplevel.MaximizedState);
                }
            }
            if (isResizing) {
                states.push(XdgToplevel.ResizingState);
            }
            xdgToplevel.sendConfigure(Qt.size(cw, ch), states);
        } else if (wlShellSurface && shellSurface && typeof wlShellSurface.sendConfigure === "function") {
            wlShellSurface.sendConfigure(Qt.size(Math.max(120, cw), Math.max(80, ch)), 0);
        }
    }

    function applyFrameGeometry(fx, fy, fw, fh, isResizing) {
        var nextW = clampFrameWidth(fw);
        var nextH = clampFrameHeight(fh);
        x = Math.round(fx);
        y = Math.round(fy);
        width = nextW;
        height = nextH;
        var nextRailW = (clientFullscreen || maximized || snapMode === "maximize") ? 0 : (isAscii ? 10 : frameBorderWidth);
        var nextBotH = (clientFullscreen || maximized || snapMode === "maximize") ? 0 : (isAscii ? 18 : frameBorderWidth);
        var nextTopH = clientFullscreen ? 0 : (isSnaptic ? 32 : 26);
        sendClientConfigure(nextW - nextRailW * 2, nextH - nextTopH - nextBotH, isResizing);
        windowStateChanged();
    }

    function computeSnapRectInArea(zone, wa, sr) {
        var leftW = Math.round(wa.width * sr);
        var halfH = Math.round(wa.height * 0.5);
        switch (zone) {
        case "left":
            return Qt.rect(wa.x, wa.y, leftW, wa.height);
        case "right":
            return Qt.rect(wa.x + leftW, wa.y, wa.width - leftW, wa.height);
        case "maximize":
            return Qt.rect(wa.x, wa.y, wa.width, wa.height);
        case "topleft":
            return Qt.rect(wa.x, wa.y, leftW, halfH);
        case "topright":
            return Qt.rect(wa.x + leftW, wa.y, wa.width - leftW, halfH);
        case "bottomleft":
            return Qt.rect(wa.x, wa.y + halfH, leftW, wa.height - halfH);
        case "bottomright":
            return Qt.rect(wa.x + leftW, wa.y + halfH, wa.width - leftW, wa.height - halfH);
        default:
            return Qt.rect(0, 0, 0, 0);
        }
    }

    function computeSnapRect(zone) {
        return computeSnapRectInArea(zone, frameRoot.workArea, frameRoot.splitRatio);
    }

    function detectSnapZoneInArea(gx, gy, wa) {
        if (!frameRoot.snapEnabled) {
            return "";
        }
        var edge = Math.max(8, frameRoot.snapThresholdPx);
        var nearLeft = gx <= wa.x + edge;
        var nearRight = gx >= wa.x + wa.width - edge;
        var nearTop = gy <= wa.y + edge;
        var nearBottom = gy >= wa.y + wa.height - edge;

        if (nearLeft && nearTop) return "topleft";
        if (nearRight && nearTop) return "topright";
        if (nearLeft && nearBottom) return "bottomleft";
        if (nearRight && nearBottom) return "bottomright";
        if (nearLeft) return "left";
        if (nearRight) return "right";
        if (nearTop) return "maximize";
        return "";
    }

    function detectSnapZone(gx, gy) {
        return detectSnapZoneInArea(gx, gy, frameRoot.workArea);
    }

    function updateDragMove(localX, localY) {
        updateDragVelocity(localX, localY);
        if (multiMonitorMode && outputContainer && crossMonitorDragging) {
            dragMoved(winId, outputContainer.globalX + localX, outputContainer.globalY + localY);
            return;
        }
        if (gridCanvas) {
            let zone = detectSnapZone(localX, localY);
            gridCanvas.activeSnapZone = zone;
            gridCanvas.snapPreviewRect = zone !== "" ? computeSnapRect(zone) : Qt.rect(0, 0, 0, 0);
        }
    }

    function finishDragMove(localX, localY) {
        smearDecayTimer.stop();
        resetDragSmear();
        if (multiMonitorMode && outputContainer && crossMonitorDragging) {
            dragEnded(winId, outputContainer.globalX + localX, outputContainer.globalY + localY);
            return;
        }
        var zone = detectSnapZone(localX, localY);
        if (gridCanvas) {
            gridCanvas.activeSnapZone = "";
            gridCanvas.snapPreviewRect = Qt.rect(0, 0, 0, 0);
        }
        if (zone !== "") {
            applySnap(zone);
        } else {
            y = Math.max(workArea.y, y);
            windowStateChanged();
        }
    }

    function applySnap(zone) {
        if (zone === "") {
            return;
        }
        clientFullscreen = false;
        if (snapMode === "" && !maximized) {
            restoreRect = Qt.rect(x, y, width, height);
        }
        snapMode = zone;
        maximized = (zone === "maximize");
        var target = computeSnapRect(zone);
        applyFrameGeometry(target.x, target.y, target.width, target.height, false);
        snapCommitted(winId, zone, target);
        triggerImpact();
        syncSurfaceOutput();
    }

    function restoreFloating() {
        clientFullscreen = false;
        snapMode = "";
        maximized = false;
        var wa = frameRoot.workArea;
        var rw = Math.min(Math.max(minWinW, wa.width - 16), Math.max(minWinW, restoreRect.width));
        var rh = Math.min(Math.max(minWinH, wa.height - 16), Math.max(minWinH, restoreRect.height));
        var rx = Math.max(0, Math.min(Math.max(0, wa.width - rw), restoreRect.x));
        var ry = Math.max(wa.y, Math.min(Math.max(wa.y, wa.y + wa.height - rh), restoreRect.y));
        restoreRect = Qt.rect(rx, ry, rw, rh);
        applyFrameGeometry(rx, ry, rw, rh, false);
        snapCommitted(winId, "", restoreRect);
        syncSurfaceOutput();
    }

    function enterFullscreen(targetOut) {
        var dest = targetOut || frameRoot.outputContainer;
        if (!dest) {
            return;
        }
        if (!clientFullscreen) {
            preFullscreenRect = Qt.rect(x, y, width, height);
            preFullscreenSnapMode = snapMode;
            preFullscreenMaximized = maximized;
        }
        if (dest !== frameRoot.outputContainer && dest.windowLayer) {
            frameRoot.parent = dest.windowLayer;
            frameRoot.outputContainer = dest;
            frameRoot.workArea = dest.workArea;
        }
        clientFullscreen = true;
        snapMode = "";
        maximized = false;
        minimized = false;
        applyFrameGeometry(0, 0, Math.max(minWinW, dest.outputWidth), Math.max(minWinH, dest.outputHeight), false);
        syncSurfaceOutput();
    }

    function exitFullscreen() {
        if (!clientFullscreen) {
            return;
        }
        clientFullscreen = false;
        if (preFullscreenMaximized || preFullscreenSnapMode !== "") {
            applySnap(preFullscreenSnapMode !== "" ? preFullscreenSnapMode : "maximize");
            syncSurfaceOutput();
            return;
        }
        var wa = frameRoot.workArea;
        var rw = Math.min(Math.max(minWinW, wa.width - 16), Math.max(minWinW, preFullscreenRect.width));
        var rh = Math.min(Math.max(minWinH, wa.height - 16), Math.max(minWinH, preFullscreenRect.height));
        var rx = Math.max(0, Math.min(Math.max(0, wa.width - rw), preFullscreenRect.x));
        var ry = Math.max(wa.y, Math.min(Math.max(wa.y, wa.y + wa.height - rh), preFullscreenRect.y));
        snapMode = "";
        maximized = false;
        restoreRect = Qt.rect(rx, ry, rw, rh);
        applyFrameGeometry(rx, ry, rw, rh, false);
        syncSurfaceOutput();
    }

    function markClosed() {
        if (!closing) {
            closing = true;
            wlShellSurface = null;
            surfaceClosed(winId);
        }
    }

    Component.onCompleted: {
        if (shellSurface || xdgToplevel || wlShellSurface) {
            initializedShell = true;
        }
        sendClientConfigure(0, 0, false);
        triggerImpact();
        syncSurfaceOutput();
    }

    onShellSurfaceChanged: {
        if (shellSurface) {
            initializedShell = true;
        } else if (initializedShell) {
            markClosed();
        }
    }

    onXdgToplevelChanged: {
        if (xdgToplevel) {
            initializedShell = true;
        } else if (initializedShell && !wlShellSurface) {
            markClosed();
        }
    }

    onWlShellSurfaceChanged: {
        if (wlShellSurface) {
            initializedShell = true;
        } else if (initializedShell && !xdgToplevel) {
            markClosed();
        }
    }

    function focusSurface() {
        if (closing) {
            return;
        }
        if (clientSurfaceItem && shellSurface) {
            clientSurfaceItem.takeFocus();
        }
        sendClientConfigure(width - railW * 2, height - topH - botH, false);
    }

    onActiveChanged: {
        if (!closing) {
            sendClientConfigure(width - railW * 2, height - topH - botH, resizingNow);
            windowStateChanged();
        }
    }

    onWinTitleChanged: windowStateChanged()
    onAppIdChanged: windowStateChanged()
    onMinimizedChanged: windowStateChanged()
    onMaximizedChanged: windowStateChanged()
    onClientFullscreenChanged: windowStateChanged()

    // Velocity smear ghost trails & trailing speed spears (SNAPTIC kinetic drag)
    Rectangle {
        id: smearGhostOuter
        visible: frameRoot.trailAlpha > 0.02
        x: -frameRoot.trailLagX * 1.15
        y: -frameRoot.trailLagY * 1.15
        width: frameRoot.width
        height: frameRoot.height
        z: -3
        opacity: frameRoot.trailAlpha * 0.48
        radius: frameRoot.frameCornerRadius
        color: Qt.rgba(0.63, 0.66, 0.85, 0.10)
        border.width: 2
        border.color: "#A0A8D8"

        Text {
            visible: Math.abs(frameRoot.trailLagX) > 6
            anchors.verticalCenter: parent.verticalCenter
            x: frameRoot.trailLagX > 0 ? -implicitWidth - 6 : parent.width + 6
            text: frameRoot.trailLagX > 0 ? "━━━▶" : "◀━━━"
            font.family: frameRoot.monoFont.family
            font.pixelSize: frameRoot.monoFont.pixelSize
            font.bold: true
            color: "#A0A8D8"
        }
    }

    Rectangle {
        id: smearGhostInner
        visible: frameRoot.trailAlpha > 0.02
        x: -frameRoot.trailLagX * 0.55
        y: -frameRoot.trailLagY * 0.55
        width: frameRoot.width
        height: frameRoot.height
        z: -2
        opacity: frameRoot.trailAlpha * 0.72
        radius: frameRoot.frameCornerRadius
        color: Qt.rgba(0.27, 0.76, 1.0, 0.14)
        border.width: 2
        border.color: "#45C2FF"

        Text {
            visible: Math.abs(frameRoot.trailLagX) > 5
            y: 12
            x: frameRoot.trailLagX > 0 ? -implicitWidth - 4 : parent.width + 4
            text: frameRoot.trailLagX > 0 ? "━━▶" : "◀━━"
            font.family: frameRoot.monoFont.family
            font.pixelSize: frameRoot.monoFont.pixelSize
            font.bold: true
            color: "#45C2FF"
        }
    }

    // Non-ASCII outer frame shell (SNAPTIC Data Lens & Minimal)
    Rectangle {
        id: nonAsciiShell
        visible: !frameRoot.isAscii
        anchors.fill: parent
        z: -1
        color: frameRoot.theme.bg || "#0d0f10"
        radius: frameRoot.frameCornerRadius
    }

    Rectangle {
        id: nonAsciiBorderOverlay
        visible: !frameRoot.isAscii && !frameRoot.isBgTerminal && !frameRoot.clientFullscreen && !frameRoot.maximized && frameRoot.snapMode !== "maximize"
        anchors.fill: parent
        z: 20
        color: "transparent"
        radius: frameRoot.frameCornerRadius
        border.width: frameRoot.frameBorderWidth
        border.color: frameRoot.borderColor
    }

    // Top bar: ASCII ┌─[...]─┐ or SNAPTIC Data Lens or Minimal
    Rectangle {
        id: titleBar
        visible: !frameRoot.clientFullscreen && !frameRoot.isBgTerminal
        x: 0
        y: 0
        width: frameRoot.width
        height: frameRoot.topH
        color: frameRoot.isAscii ? frameRoot.barBgColor : "transparent"

        // Rounded top header fill for SNAPTIC Data Lens / Minimal
        Rectangle {
            visible: !frameRoot.isAscii
            anchors.fill: parent
            color: frameRoot.barBgColor
            radius: frameRoot.frameCornerRadius

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                height: Math.min(parent.height * 0.5, frameRoot.frameCornerRadius)
                color: parent.color
            }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                height: 1
                color: frameRoot.borderColor
                opacity: 0.45
            }
        }

        MouseArea {
            id: titleDragArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            property real startMouseX: 0
            property real startMouseY: 0
            property real startWinX: 0
            property real startWinY: 0
            property bool dragging: false
            property bool pulledOut: false

            onPressed: (mouse) => {
                if (!frameRoot.isBgTerminal || frameRoot.bgTerminalInteractive) {
                    frameRoot.requestFocus(frameRoot.winId);
                }
                var gp = titleDragArea.mapToItem(frameRoot.parent, mouse.x, mouse.y);
                startMouseX = gp.x;
                startMouseY = gp.y;
                startWinX = frameRoot.x;
                startWinY = frameRoot.y;
                dragging = true;
                pulledOut = false;
            }

            onPositionChanged: (mouse) => {
                if (!dragging) {
                    return;
                }
                var gp = titleDragArea.mapToItem(frameRoot.parent, mouse.x, mouse.y);
                var dx = gp.x - startMouseX;
                var dy = gp.y - startMouseY;

                // Pull cleanly out of maximized/snapped state on drag threshold
                if (!pulledOut && (frameRoot.maximized || frameRoot.snapMode !== "") && (Math.abs(dx) > 5 || Math.abs(dy) > 5)) {
                    pulledOut = true;
                    let rw = Math.max(frameRoot.minWinW, frameRoot.restoreRect.width);
                    let rh = Math.max(frameRoot.minWinH, frameRoot.restoreRect.height);
                    let ratio = Math.min(0.85, Math.max(0.15, mouse.x / Math.max(1, frameRoot.width)));
                    frameRoot.snapMode = "";
                    frameRoot.maximized = false;
                    startWinX = gp.x - rw * ratio;
                    startWinY = Math.max(frameRoot.workArea.y, gp.y - frameRoot.topH * 0.5);
                    startMouseX = gp.x;
                    startMouseY = gp.y;
                    frameRoot.applyFrameGeometry(startWinX, startWinY, rw, rh, false);
                    frameRoot.snapCommitted(frameRoot.winId, "", Qt.rect(startWinX, startWinY, rw, rh));
                    dx = 0;
                    dy = 0;
                }

                frameRoot.x = Math.round(startWinX + dx);
                var rawY = Math.round(startWinY + dy);
                frameRoot.y = (frameRoot.multiMonitorMode && frameRoot.crossMonitorDragging) ? rawY : Math.max(frameRoot.workArea.y, rawY);

                frameRoot.updateDragMove(gp.x, gp.y);
            }

            onReleased: (mouse) => {
                if (!dragging) {
                    return;
                }
                dragging = false;
                var gp = titleDragArea.mapToItem(frameRoot.parent, mouse.x, mouse.y);
                frameRoot.finishDragMove(gp.x, gp.y);
            }

            onDoubleClicked: {
                dragging = false;
                pulledOut = false;
                frameRoot.requestToggleMaximize(frameRoot.winId);
            }
        }

        Text {
            id: topLeftCorner
            visible: frameRoot.isAscii
            anchors {
                left: parent.left
                leftMargin: 1
                verticalCenter: parent.verticalCenter
            }
            text: (frameRoot.maximized || frameRoot.snapMode === "maximize") ? "├─[" : "┌─["
            font: frameRoot.monoFont
            renderType: Text.NativeRendering
            color: frameRoot.borderColor
        }

        Text {
            id: titleText
            visible: frameRoot.isAscii
            readonly property string idxPrefix: (frameRoot.winIndex < 10 ? "0" : "") + frameRoot.winIndex + ": "
            readonly property real reserved: topLeftCorner.implicitWidth + titleCloseBracket.implicitWidth + btnRow.width + topRightCorner.implicitWidth + 12
            width: Math.min(implicitWidth, Math.max(36, titleBar.width - reserved))
            anchors {
                left: topLeftCorner.right
                verticalCenter: parent.verticalCenter
            }
            text: " " + idxPrefix + frameRoot.winTitle + " "
            textFormat: Text.PlainText
            elide: Text.ElideRight
            maximumLineCount: 1
            font.family: frameRoot.monoFont.family
            font.pixelSize: frameRoot.monoFont.pixelSize
            font.bold: frameRoot.active
            renderType: Text.NativeRendering
            color: frameRoot.textColor
        }

        Text {
            id: titleCloseBracket
            visible: frameRoot.isAscii
            anchors {
                left: titleText.right
                verticalCenter: parent.verticalCenter
            }
            text: "]"
            font: frameRoot.monoFont
            renderType: Text.NativeRendering
            color: frameRoot.borderColor
        }

        // Auto-fitting horizontal ─ rail
        Item {
            id: topDashFill
            visible: frameRoot.isAscii
            clip: true
            anchors {
                left: titleCloseBracket.right
                right: btnRow.left
                top: parent.top
                bottom: parent.bottom
            }

            Text {
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }
                visible: topDashFill.width > 0
                text: "─".repeat(Math.max(1, Math.ceil(topDashFill.width / frameRoot.charW) + 2))
                font: frameRoot.monoFont
                renderType: Text.NativeRendering
                color: frameRoot.borderColor
            }
        }

        Row {
            id: btnRow
            visible: frameRoot.isAscii
            anchors {
                right: topRightCorner.left
                verticalCenter: parent.verticalCenter
            }
            spacing: 0

            // [ _ ] Minimize
            Rectangle {
                width: minTxt.implicitWidth
                height: frameRoot.topH - 4
                color: minMouse.pressed ? frameRoot.theme.accent : (minMouse.containsMouse ? "#1f2429" : "transparent")
                Text {
                    id: minTxt
                    anchors.centerIn: parent
                    text: "[ _ ]"
                    font: frameRoot.monoFont
                    renderType: Text.NativeRendering
                    color: minMouse.pressed ? frameRoot.theme.bg : (minMouse.containsMouse ? frameRoot.theme.accent : frameRoot.textColor)
                }
                MouseArea {
                    id: minMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: frameRoot.requestToggleMinimize(frameRoot.winId)
                }
            }

            // [ □ ] / [ ❐ ] Maximize / Restore
            Rectangle {
                width: maxTxt.implicitWidth
                height: frameRoot.topH - 4
                color: maxMouse.pressed ? frameRoot.theme.secondary : (maxMouse.containsMouse ? "#1f2429" : "transparent")
                Text {
                    id: maxTxt
                    anchors.centerIn: parent
                    text: (frameRoot.maximized || frameRoot.snapMode !== "") ? "[ ❐ ]" : "[ □ ]"
                    font: frameRoot.monoFont
                    renderType: Text.NativeRendering
                    color: maxMouse.pressed ? frameRoot.theme.bg : (maxMouse.containsMouse ? frameRoot.theme.secondary : frameRoot.textColor)
                }
                MouseArea {
                    id: maxMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: frameRoot.requestToggleMaximize(frameRoot.winId)
                }
            }

            // [ ⛶ ] Fullscreen
            Rectangle {
                width: fsTxt.implicitWidth
                height: frameRoot.topH - 4
                color: fsMouse.pressed ? frameRoot.theme.accent : (fsMouse.containsMouse ? "#1f2429" : "transparent")
                Text {
                    id: fsTxt
                    anchors.centerIn: parent
                    text: "[ ⛶ ]"
                    font: frameRoot.monoFont
                    renderType: Text.NativeRendering
                    color: fsMouse.pressed ? frameRoot.theme.bg : (fsMouse.containsMouse ? frameRoot.theme.accent : frameRoot.textColor)
                }
                MouseArea {
                    id: fsMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: frameRoot.requestToggleFullscreen(frameRoot.winId)
                }
            }

            // [ ✕ ] Close
            Rectangle {
                width: closeTxt.implicitWidth
                height: frameRoot.topH - 4
                color: closeMouse.pressed ? frameRoot.theme.danger : (closeMouse.containsMouse ? "#2a1618" : "transparent")
                Text {
                    id: closeTxt
                    anchors.centerIn: parent
                    text: "[ ✕ ]"
                    font: frameRoot.monoFont
                    renderType: Text.NativeRendering
                    color: closeMouse.pressed ? frameRoot.theme.bg : (closeMouse.containsMouse ? frameRoot.theme.danger : frameRoot.textColor)
                }
                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: frameRoot.requestClose(frameRoot.winId)
                }
            }
        }

        Text {
            id: topRightCorner
            visible: frameRoot.isAscii
            anchors {
                right: parent.right
                rightMargin: 1
                verticalCenter: parent.verticalCenter
            }
            text: (frameRoot.maximized || frameRoot.snapMode === "maximize") ? "─┤" : "─┐"
            font: frameRoot.monoFont
            renderType: Text.NativeRendering
            color: frameRoot.borderColor
        }

        // SNAPTIC Data Lens / Minimal header layout
        Item {
            id: lensHeader
            visible: !frameRoot.isAscii
            anchors {
                fill: parent
                leftMargin: 10
                rightMargin: 10
            }

            Rectangle {
                id: lensBadge
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }
                width: Math.min(lensBadgeText.implicitWidth + 18, Math.max(60, parent.width - lensBtnRow.width - 16))
                height: frameRoot.isSnaptic ? 22 : 20
                radius: frameRoot.isSnaptic ? 6 : 0
                color: frameRoot.isSnaptic
                    ? (frameRoot.active ? (frameRoot.theme.bg || "#E8ECFC") : "transparent")
                    : "transparent"
                border.width: frameRoot.isSnaptic ? 1 : 0
                border.color: frameRoot.active
                    ? (frameRoot.theme.secondary || "#45C2FF")
                    : (frameRoot.theme.muted || "#7D86B5")

                Text {
                    id: lensBadgeText
                    anchors {
                        left: parent.left
                        right: parent.right
                        leftMargin: 8
                        rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    text: frameRoot.isSnaptic
                        ? ("👁 " + frameRoot.winTitle)
                        : frameRoot.winTitle
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.family: frameRoot.monoFont.family
                    font.pixelSize: Math.max(11, frameRoot.monoFont.pixelSize - 1)
                    font.bold: frameRoot.active
                    renderType: Text.NativeRendering
                    color: frameRoot.textColor
                }
            }

            Row {
                id: lensBtnRow
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                spacing: 6

                // Minimize pill [-]
                Rectangle {
                    width: 28
                    height: frameRoot.isSnaptic ? 20 : 18
                    radius: frameRoot.isSnaptic ? 5 : 0
                    color: lensMinMouse.pressed
                        ? (frameRoot.theme.accent || "#7B84BF")
                        : (lensMinMouse.containsMouse ? (frameRoot.theme.bg || "#E8ECFC") : "transparent")
                    border.width: frameRoot.isSnaptic ? 1 : 0
                    border.color: frameRoot.borderColor
                    Text {
                        anchors.centerIn: parent
                        text: frameRoot.isSnaptic ? "[-]" : "_"
                        font.family: frameRoot.monoFont.family
                        font.pixelSize: Math.max(11, frameRoot.monoFont.pixelSize - 1)
                        font.bold: true
                        color: lensMinMouse.pressed ? (frameRoot.theme.bg || "#ffffff") : frameRoot.textColor
                    }
                    MouseArea {
                        id: lensMinMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: frameRoot.requestToggleMinimize(frameRoot.winId)
                    }
                }

                // Maximize / Restore pill [口]
                Rectangle {
                    width: 30
                    height: frameRoot.isSnaptic ? 20 : 18
                    radius: frameRoot.isSnaptic ? 5 : 0
                    color: lensMaxMouse.pressed
                        ? (frameRoot.theme.secondary || "#45C2FF")
                        : (lensMaxMouse.containsMouse ? (frameRoot.theme.bg || "#E8ECFC") : "transparent")
                    border.width: frameRoot.isSnaptic ? 1 : 0
                    border.color: frameRoot.borderColor
                    Text {
                        anchors.centerIn: parent
                        text: (frameRoot.maximized || frameRoot.snapMode !== "")
                            ? (frameRoot.isSnaptic ? "[❐]" : "❐")
                            : (frameRoot.isSnaptic ? "[口]" : "□")
                        font.family: frameRoot.monoFont.family
                        font.pixelSize: Math.max(11, frameRoot.monoFont.pixelSize - 1)
                        font.bold: true
                        color: lensMaxMouse.pressed ? (frameRoot.theme.bg || "#ffffff") : frameRoot.textColor
                    }
                    MouseArea {
                        id: lensMaxMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: frameRoot.requestToggleMaximize(frameRoot.winId)
                    }
                }

                // Fullscreen pill [⛶]
                Rectangle {
                    width: 30
                    height: frameRoot.isSnaptic ? 20 : 18
                    radius: frameRoot.isSnaptic ? 5 : 0
                    color: lensFsMouse.pressed
                        ? (frameRoot.theme.accent || "#7B84BF")
                        : (lensFsMouse.containsMouse ? (frameRoot.theme.bg || "#E8ECFC") : "transparent")
                    border.width: frameRoot.isSnaptic ? 1 : 0
                    border.color: frameRoot.borderColor
                    Text {
                        anchors.centerIn: parent
                        text: frameRoot.isSnaptic ? "[⛶]" : "⛶"
                        font.family: frameRoot.monoFont.family
                        font.pixelSize: Math.max(11, frameRoot.monoFont.pixelSize - 1)
                        font.bold: true
                        color: lensFsMouse.pressed ? (frameRoot.theme.bg || "#ffffff") : frameRoot.textColor
                    }
                    MouseArea {
                        id: lensFsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: frameRoot.requestToggleFullscreen(frameRoot.winId)
                    }
                }

                // Close pill [X]
                Rectangle {
                    width: 30
                    height: frameRoot.isSnaptic ? 20 : 18
                    radius: frameRoot.isSnaptic ? 5 : 0
                    readonly property color closeBg: (frameRoot.theme && frameRoot.theme.closeBtnBg)
                        ? frameRoot.theme.closeBtnBg
                        : (frameRoot.theme.danger || "#FF5C5C")
                    color: frameRoot.isSnaptic
                        ? (lensCloseMouse.pressed ? (frameRoot.theme.danger || "#FF3366") : (lensCloseMouse.containsMouse ? Qt.lighter(closeBg, 1.12) : closeBg))
                        : (lensCloseMouse.pressed ? closeBg : (lensCloseMouse.containsMouse ? closeBg : "transparent"))
                    Text {
                        anchors.centerIn: parent
                        text: frameRoot.isSnaptic ? "[X]" : "✕"
                        font.family: frameRoot.monoFont.family
                        font.pixelSize: Math.max(11, frameRoot.monoFont.pixelSize - 1)
                        font.bold: true
                        color: (frameRoot.isSnaptic || lensCloseMouse.containsMouse || lensCloseMouse.pressed)
                            ? "#FFFFFF"
                            : frameRoot.textColor
                    }
                    MouseArea {
                        id: lensCloseMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: frameRoot.requestClose(frameRoot.winId)
                    }
                }
            }
        }
    }

    // Left │ rail
    Rectangle {
        id: leftRail
        visible: frameRoot.isAscii && frameRoot.railW > 0
        clip: true
        x: 0
        y: frameRoot.topH
        width: frameRoot.railW
        height: Math.max(0, frameRoot.height - frameRoot.topH - frameRoot.botH)
        color: frameRoot.theme.bg

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: -2
            font: frameRoot.monoFont
            renderType: Text.NativeRendering
            color: frameRoot.borderColor
            lineHeightMode: Text.FixedHeight
            lineHeight: frameRoot.railStepH
            text: {
                var count = Math.max(1, Math.ceil(leftRail.height / frameRoot.railStepH) + 2);
                return Array(count + 1).join("│\n");
            }
        }
    }

    // Right │ rail
    Rectangle {
        id: rightRail
        visible: frameRoot.isAscii && frameRoot.railW > 0
        clip: true
        x: frameRoot.width - frameRoot.railW
        y: frameRoot.topH
        width: frameRoot.railW
        height: Math.max(0, frameRoot.height - frameRoot.topH - frameRoot.botH)
        color: frameRoot.theme.bg

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: -2
            font: frameRoot.monoFont
            renderType: Text.NativeRendering
            color: frameRoot.borderColor
            lineHeightMode: Text.FixedHeight
            lineHeight: frameRoot.railStepH
            text: {
                var count = Math.max(1, Math.ceil(rightRail.height / frameRoot.railStepH) + 2);
                return Array(count + 1).join("│\n");
            }
        }
    }

    // Bottom └─...─┘ rail
    Rectangle {
        id: bottomRail
        visible: frameRoot.isAscii && frameRoot.botH > 0
        clip: true
        x: 0
        y: frameRoot.height - frameRoot.botH
        width: frameRoot.width
        height: frameRoot.botH
        color: frameRoot.theme.bg

        Text {
            id: bottomLeftCorner
            anchors {
                left: parent.left
                leftMargin: 1
                verticalCenter: parent.verticalCenter
            }
            text: "└"
            font: frameRoot.monoFont
            renderType: Text.NativeRendering
            color: frameRoot.borderColor
        }

        Item {
            id: bottomDashFill
            clip: true
            anchors {
                left: bottomLeftCorner.right
                right: bottomRightCorner.left
                top: parent.top
                bottom: parent.bottom
            }

            Text {
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                }
                visible: bottomDashFill.width > 0
                text: "─".repeat(Math.max(1, Math.ceil(bottomDashFill.width / frameRoot.charW) + 2))
                font: frameRoot.monoFont
                renderType: Text.NativeRendering
                color: frameRoot.borderColor
            }
        }

        Text {
            id: bottomRightCorner
            anchors {
                right: parent.right
                rightMargin: 1
                verticalCenter: parent.verticalCenter
            }
            text: "┘"
            font: frameRoot.monoFont
            renderType: Text.NativeRendering
            color: frameRoot.borderColor
        }
    }

    // Interior native high-resolution Wayland client viewport (unclipped so XDG popups/menus aren't cut off when floating, clipped when maximized/fullscreen/snapped)
    Item {
        id: clientViewport
        clip: true
        x: frameRoot.railW
        y: frameRoot.topH
        width: Math.max(80, frameRoot.width - frameRoot.railW * 2)
        height: Math.max(40, frameRoot.height - frameRoot.topH - frameRoot.botH)

        // Solid theme or black backdrop behind client surfaces (games, video, transparent terminals when maximized or fullscreen)
        Rectangle {
            id: clientBackdrop
            visible: !frameRoot.isBgTerminal && (frameRoot.clientFullscreen || frameRoot.maximized || frameRoot.snapMode !== "")
            anchors.fill: parent
            color: frameRoot.clientFullscreen ? "#000000" : (frameRoot.theme.bg || "#0d0f10")
            z: -1
        }

        Item {
            id: qtMoveSink
            visible: false
        }

        ShellSurfaceItem {
            id: clientSurfaceItem
            moveItem: qtMoveSink
            x: -frameRoot.csdOffsetX
            y: -frameRoot.csdOffsetY
            width: (frameRoot.csdOffsetX > 0 || implicitWidth > 0) ? implicitWidth : clientViewport.width
            height: (frameRoot.csdOffsetY > 0 || implicitHeight > 0) ? implicitHeight : clientViewport.height
            shellSurface: frameRoot.shellSurface
            output: frameRoot.outputContainer
            autoCreatePopupItems: true
            enabled: !frameRoot.isBgTerminal || frameRoot.bgTerminalInteractive
            focusOnClick: !frameRoot.isBgTerminal || frameRoot.bgTerminalInteractive

            onSurfaceDestroyed: frameRoot.markClosed()

            Component.onCompleted: {
                // qmllint disable unqualified
                Backend.attachSubsurfaceFixer(clientSurfaceItem);
                // qmllint enable unqualified
                frameRoot.syncSurfaceOutput();
            }

            onSurfaceChanged: {
                if (clientSurfaceItem.surface) {
                    // qmllint disable unqualified
                    Backend.attachSubsurfaceFixer(clientSurfaceItem);
                    // qmllint enable unqualified
                    frameRoot.syncSurfaceOutput();
                }
            }

            property int lastSurfaceW: 0
            property int lastSurfaceH: 0

            function syncInitialSizeFromSurface() {
                let contentW = (frameRoot.clientWinGeom.width > 0) ? Math.round(frameRoot.clientWinGeom.width) : Math.round(implicitWidth);
                let contentH = (frameRoot.clientWinGeom.height > 0) ? Math.round(frameRoot.clientWinGeom.height) : Math.round(implicitHeight);
                if (contentW <= 0 || contentH <= 0) {
                    return;
                }
                if (contentW === lastSurfaceW && contentH === lastSurfaceH) {
                    return;
                }
                lastSurfaceW = contentW;
                lastSurfaceH = contentH;
                // qmllint disable unqualified
                Backend.normalizeClientSubsurfaces(clientSurfaceItem);
                // qmllint enable unqualified
                if (frameRoot.isBgTerminal) {
                    frameRoot.sendClientConfigure(frameRoot.width, frameRoot.height, false);
                    return;
                }
                if (!frameRoot.initialSized && !frameRoot.clientFullscreen && !frameRoot.maximized && frameRoot.snapMode === "" && !frameRoot.userResized) {
                    let maxW = Math.max(frameRoot.effMinW, frameRoot.workArea.width - 40);
                    let maxH = Math.max(frameRoot.effMinH, frameRoot.workArea.height - 40);
                    let fw = Math.min(maxW, frameRoot.clampFrameWidth(contentW + frameRoot.railW * 2));
                    let fh = Math.min(maxH, frameRoot.clampFrameHeight(contentH + frameRoot.topH + frameRoot.botH));
                    let nx = Math.max(frameRoot.workArea.x + 16, Math.min(frameRoot.workArea.x + frameRoot.workArea.width - fw - 16, Math.round(frameRoot.workArea.x + (frameRoot.workArea.width - fw) * 0.5)));
                    let ny = Math.max(frameRoot.workArea.y + 12, Math.min(frameRoot.workArea.y + frameRoot.workArea.height - fh - 12, Math.round(frameRoot.workArea.y + (frameRoot.workArea.height - fh) * 0.35)));
                    frameRoot.initialSized = true;
                    frameRoot.applyFrameGeometry(nx, ny, fw, fh, false);
                    frameRoot.restoreRect = Qt.rect(nx, ny, fw, fh);
                    frameRoot.windowStateChanged();
                } else {
                    let expectedW = frameRoot.clientFullscreen
                        ? (frameRoot.outputContainer ? frameRoot.outputContainer.outputWidth : frameRoot.width)
                        : (frameRoot.maximized || frameRoot.snapMode === "maximize")
                            ? (frameRoot.workArea.width - frameRoot.railW * 2)
                            : (frameRoot.width - frameRoot.railW * 2);
                    let expectedH = frameRoot.clientFullscreen
                        ? (frameRoot.outputContainer ? frameRoot.outputContainer.outputHeight : frameRoot.height)
                        : (frameRoot.maximized || frameRoot.snapMode === "maximize")
                            ? (frameRoot.workArea.height - frameRoot.topH - frameRoot.botH)
                            : (frameRoot.height - frameRoot.topH - frameRoot.botH);
                    if (!frameRoot.clientFullscreen && !frameRoot.maximized && frameRoot.snapMode === "" && frameRoot.initialSized && !frameRoot.resizingNow && (contentW > expectedW + 4 || contentH > expectedH + 4)) {
                        let maxW = Math.max(frameRoot.effMinW, frameRoot.workArea.width - 16);
                        let maxH = Math.max(frameRoot.effMinH, frameRoot.workArea.height - 16);
                        let fitW = Math.min(maxW, frameRoot.clampFrameWidth(Math.max(expectedW, contentW) + frameRoot.railW * 2));
                        let fitH = Math.min(maxH, frameRoot.clampFrameHeight(Math.max(expectedH, contentH) + frameRoot.topH + frameRoot.botH));
                        let nx = Math.max(frameRoot.workArea.x + 8, Math.min(frameRoot.workArea.x + frameRoot.workArea.width - fitW - 8, frameRoot.x));
                        let ny = Math.max(frameRoot.workArea.y + 8, Math.min(frameRoot.workArea.y + frameRoot.workArea.height - fitH - 8, frameRoot.y));
                        frameRoot.applyFrameGeometry(nx, ny, fitW, fitH, false);
                        frameRoot.restoreRect = Qt.rect(nx, ny, fitW, fitH);
                        frameRoot.windowStateChanged();
                    } else if (Math.abs(contentW - expectedW) > 2 || Math.abs(contentH - expectedH) > 2) {
                        frameRoot.sendClientConfigure(expectedW, expectedH, false);
                    }
                }
            }

            onImplicitWidthChanged: syncInitialSizeFromSurface()
            onImplicitHeightChanged: syncInitialSizeFromSurface()
        }

        Connections {
            target: frameRoot
            function onClientWinGeomChanged() {
                clientSurfaceItem.syncInitialSizeFromSurface();
            }
        }

        // Seamless click-to-focus capture (passive handler; never swallows clicks or cancels mouse grab)
        TapHandler {
            enabled: (!frameRoot.isBgTerminal || frameRoot.bgTerminalInteractive) && !frameRoot.modDragHeld
            gesturePolicy: TapHandler.DragThreshold
            grabPermissions: PointerHandler.CanTakeOverFromAnything | PointerHandler.ApprovesTakeOverByAnything
            onPressedChanged: {
                if (pressed) {
                    frameRoot.requestFocus(frameRoot.winId);
                }
            }
            onTapped: {
                if (!frameRoot.active) {
                    frameRoot.requestFocus(frameRoot.winId);
                }
            }
        }

        // Direct low-latency X11 wheel forwarder for Discord & XWayland clients
        WheelHandler {
            enabled: (!frameRoot.isBgTerminal || frameRoot.bgTerminalInteractive) && !frameRoot.modDragHeld
            target: null
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                event.accepted = false;
                let idStr = frameRoot.appId.toLowerCase();
                if (idStr.indexOf("discord") !== -1 || idStr.indexOf("steam") !== -1) {
                    // qmllint disable unqualified
                    if (typeof Backend !== "undefined" && typeof Backend.forwardX11Wheel === "function") {
                        Backend.forwardX11Wheel(event.angleDelta.y, event.angleDelta.x);
                    }
                    // qmllint enable unqualified
                }
            }
        }
    }

    // Subtle draggable top pill for Live Background Terminal (always movable even when non-interactive)
    Rectangle {
        id: bgMoveBar
        visible: frameRoot.isBgTerminal && !frameRoot.clientFullscreen
        anchors.top: parent.top
        anchors.left: parent.left
        width: Math.min(parent.width, bgMoveTxt.implicitWidth + 16)
        height: 18
        z: 35
        color: (bgMoveMa.containsMouse || bgMoveMa.dragging) ? frameRoot.theme.panelBg : "transparent"
        border.color: (bgMoveMa.containsMouse || bgMoveMa.dragging) ? frameRoot.theme.accent : frameRoot.theme.muted
        border.width: (bgMoveMa.containsMouse || bgMoveMa.dragging) ? 1 : 0
        opacity: (bgMoveMa.containsMouse || bgMoveMa.dragging) ? 0.92 : 0.0
        Behavior on opacity { NumberAnimation { duration: 140 } }

        Text {
            id: bgMoveTxt
            anchors.centerIn: parent
            font.family: frameRoot.monoFont.family
            font.pixelSize: 10
            color: (bgMoveMa.containsMouse || bgMoveMa.dragging) ? frameRoot.theme.accent : frameRoot.theme.muted
            text: "[ ✥ MOVE BG" + (frameRoot.bgTileId ? (" #" + frameRoot.bgTileId) : "") + (frameRoot.bgTerminalInteractive ? " · INTERACTIVE" : "") + " ]"
        }

        MouseArea {
            id: bgMoveMa
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.SizeAllCursor
            property real startMouseX: 0
            property real startMouseY: 0
            property real startWinX: 0
            property real startWinY: 0
            property bool dragging: false

            onPressed: (mouse) => {
                var gp = bgMoveMa.mapToItem(frameRoot.parent, mouse.x, mouse.y);
                startMouseX = gp.x;
                startMouseY = gp.y;
                startWinX = frameRoot.x;
                startWinY = frameRoot.y;
                dragging = true;
            }
            onPositionChanged: (mouse) => {
                if (!dragging) return;
                var gp = bgMoveMa.mapToItem(frameRoot.parent, mouse.x, mouse.y);
                frameRoot.x = Math.round(startWinX + (gp.x - startMouseX));
                frameRoot.y = Math.max(frameRoot.workArea.y, Math.round(startWinY + (gp.y - startMouseY)));
                var gx = (frameRoot.outputContainer ? frameRoot.outputContainer.globalX : 0) + frameRoot.x + mouse.x;
                var gy = (frameRoot.outputContainer ? frameRoot.outputContainer.globalY : 0) + frameRoot.y + mouse.y;
                frameRoot.dragMoved(frameRoot.winId, gx, gy);
            }
            onReleased: (mouse) => {
                if (!dragging) return;
                dragging = false;
                var gx = (frameRoot.outputContainer ? frameRoot.outputContainer.globalX : 0) + frameRoot.x + mouse.x;
                var gy = (frameRoot.outputContainer ? frameRoot.outputContainer.globalY : 0) + frameRoot.y + mouse.y;
                frameRoot.dragEnded(frameRoot.winId, gx, gy);
                if (frameRoot.bgTileId.length > 0) {
                    let outName = (frameRoot.outputContainer && frameRoot.outputContainer.modelData && frameRoot.outputContainer.modelData.name)
                        ? String(frameRoot.outputContainer.modelData.name)
                        : (frameRoot.bgTileMonitor || "primary");
                    frameRoot.tileMoved(frameRoot.bgTileId, outName, frameRoot.x, frameRoot.y, frameRoot.width, frameRoot.height);
                }
            }
        }
    }

    // Subtle bottom-right corner resize handle for background tile
    Rectangle {
        id: bgResizeHandle
        visible: frameRoot.isBgTerminal && !frameRoot.clientFullscreen && (bgMoveMa.containsMouse || bgResizeMa.containsMouse || bgResizeMa.dragging || frameRoot.bgTerminalInteractive)
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: 14
        height: 14
        z: 36
        color: (bgResizeMa.containsMouse || bgResizeMa.dragging) ? frameRoot.theme.accent : frameRoot.theme.panelBg
        border.color: frameRoot.theme.accent
        border.width: 1

        Text {
            anchors.centerIn: parent
            font.family: frameRoot.monoFont.family
            font.pixelSize: 9
            color: (bgResizeMa.containsMouse || bgResizeMa.dragging) ? frameRoot.theme.bg : frameRoot.theme.accent
            text: "⌟"
        }

        MouseArea {
            id: bgResizeMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeFDiagCursor
            property real startMouseX: 0
            property real startMouseY: 0
            property real startW: 0
            property real startH: 0
            property bool dragging: false

            onPressed: (mouse) => {
                var gp = bgResizeMa.mapToItem(frameRoot.parent, mouse.x, mouse.y);
                startMouseX = gp.x;
                startMouseY = gp.y;
                startW = frameRoot.width;
                startH = frameRoot.height;
                dragging = true;
            }
            onPositionChanged: (mouse) => {
                if (!dragging) return;
                var gp = bgResizeMa.mapToItem(frameRoot.parent, mouse.x, mouse.y);
                var nw = Math.max(160, Math.round(startW + (gp.x - startMouseX)));
                var nh = Math.max(100, Math.round(startH + (gp.y - startMouseY)));
                frameRoot.applyFrameGeometry(frameRoot.x, frameRoot.y, nw, nh, true);
            }
            onReleased: (mouse) => {
                if (!dragging) return;
                dragging = false;
                frameRoot.applyFrameGeometry(frameRoot.x, frameRoot.y, frameRoot.width, frameRoot.height, false);
                if (frameRoot.bgTileId.length > 0) {
                    let outName = (frameRoot.outputContainer && frameRoot.outputContainer.modelData && frameRoot.outputContainer.modelData.name)
                        ? String(frameRoot.outputContainer.modelData.name)
                        : (frameRoot.bgTileMonitor || "primary");
                    frameRoot.tileMoved(frameRoot.bgTileId, outName, frameRoot.x, frameRoot.y, frameRoot.width, frameRoot.height);
                }
            }
        }
    }

    // Impact border flash overlay + 4 diagonal corner impact spear flashes
    Rectangle {
        id: impactFlashOverlay
        anchors.fill: parent
        z: 40
        opacity: 0
        visible: opacity > 0
        radius: frameRoot.frameCornerRadius
        color: Qt.rgba(1.0, 1.0, 1.0, 0.22)
        border.width: 3
        border.color: "#45C2FF"
    }

    Item {
        id: impactCornerSpears
        anchors.fill: parent
        z: 41
        opacity: 0
        visible: opacity > 0

        readonly property real offsetDist: 6 + frameRoot.impactBurst * 20

        Text {
            x: -impactCornerSpears.offsetDist
            y: -impactCornerSpears.offsetDist
            text: "╲✦"
            font.family: frameRoot.monoFont.family
            font.pixelSize: 15
            font.bold: true
            color: "#45C2FF"
        }
        Text {
            x: parent.width - implicitWidth + impactCornerSpears.offsetDist
            y: -impactCornerSpears.offsetDist
            text: "✦╱"
            font.family: frameRoot.monoFont.family
            font.pixelSize: 15
            font.bold: true
            color: "#FFFFFF"
        }
        Text {
            x: -impactCornerSpears.offsetDist
            y: parent.height - implicitHeight + impactCornerSpears.offsetDist
            text: "╱✦"
            font.family: frameRoot.monoFont.family
            font.pixelSize: 15
            font.bold: true
            color: "#FFFFFF"
        }
        Text {
            x: parent.width - implicitWidth + impactCornerSpears.offsetDist
            y: parent.height - implicitHeight + impactCornerSpears.offsetDist
            text: "✦╲"
            font.family: frameRoot.monoFont.family
            font.pixelSize: 15
            font.bold: true
            color: "#45C2FF"
        }
    }

    // Alt / Meta + LeftClick move or RightClick resize anywhere on window (KDE-style; disabled in fullscreen games)
    MouseArea {
        id: modDragOverlay
        anchors.fill: parent
        z: 30
        visible: frameRoot.modDragHeld && !frameRoot.clientFullscreen
        enabled: frameRoot.modDragHeld && !frameRoot.clientFullscreen
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        property int dragBtn: 0
        property real startGX: 0
        property real startGY: 0
        property real origX: 0
        property real origY: 0
        property real origW: 0
        property real origH: 0

        onPressed: (mouse) => {
            frameRoot.requestFocus(frameRoot.winId);
            var gp = modDragOverlay.mapToItem(frameRoot.parent, mouse.x, mouse.y);
            dragBtn = mouse.button;
            startGX = gp.x;
            startGY = gp.y;
            origX = frameRoot.x;
            origY = frameRoot.y;
            origW = frameRoot.width;
            origH = frameRoot.height;
            if (dragBtn === Qt.RightButton) {
                frameRoot.userResized = true;
                frameRoot.resizingNow = true;
            }
        }

        onPositionChanged: (mouse) => {
            if (dragBtn === 0) return;
            if ((mouse.modifiers & (Qt.AltModifier | Qt.MetaModifier)) === 0) {
                const endP = modDragOverlay.mapToItem(frameRoot.parent, mouse.x, mouse.y);
                if (dragBtn === Qt.LeftButton) {
                    frameRoot.finishDragMove(endP.x, endP.y);
                } else if (dragBtn === Qt.RightButton) {
                    frameRoot.resizingNow = false;
                    frameRoot.applyFrameGeometry(frameRoot.x, frameRoot.y, frameRoot.width, frameRoot.height, false);
                }
                dragBtn = 0;
                frameRoot.modReleaseRequested();
                return;
            }
            var gp = modDragOverlay.mapToItem(frameRoot.parent, mouse.x, mouse.y);
            var dx = gp.x - startGX;
            var dy = gp.y - startGY;
            if (dragBtn === Qt.LeftButton) {
                if (frameRoot.maximized || frameRoot.snapMode !== "") {
                    frameRoot.snapMode = "";
                    frameRoot.maximized = false;
                    origW = frameRoot.restoreRect.width;
                    origH = frameRoot.restoreRect.height;
                    origX = gp.x - origW * 0.5;
                    origY = Math.max(frameRoot.workArea.y, gp.y - 13);
                    startGX = gp.x;
                    startGY = gp.y;
                    frameRoot.applyFrameGeometry(origX, origY, origW, origH, false);
                    dx = 0;
                    dy = 0;
                }
                frameRoot.x = Math.round(origX + dx);
                let rawModY = Math.round(origY + dy);
                frameRoot.y = (frameRoot.multiMonitorMode && frameRoot.crossMonitorDragging) ? rawModY : Math.max(frameRoot.workArea.y, rawModY);
                frameRoot.updateDragMove(gp.x, gp.y);
            } else if (dragBtn === Qt.RightButton) {
                frameRoot.snapMode = "";
                frameRoot.maximized = false;
                frameRoot.applyFrameGeometry(origX, origY, origW + dx, origH + dy, true);
            }
        }

        onReleased: (mouse) => {
            var gp = modDragOverlay.mapToItem(frameRoot.parent, mouse.x, mouse.y);
            if (dragBtn === Qt.LeftButton) {
                frameRoot.finishDragMove(gp.x, gp.y);
            } else if (dragBtn === Qt.RightButton) {
                frameRoot.resizingNow = false;
                frameRoot.applyFrameGeometry(frameRoot.x, frameRoot.y, frameRoot.width, frameRoot.height, false);
            }
            dragBtn = 0;
        }
    }

    // 8-direction border and corner resize handles
    component ResizeHandle: MouseArea {
        property bool resizeLeft: false
        property bool resizeRight: false
        property bool resizeTop: false
        property bool resizeBottom: false

        property real startGX: 0
        property real startGY: 0
        property real origX: 0
        property real origY: 0
        property real origW: 0
        property real origH: 0

        z: 25
        visible: !frameRoot.clientFullscreen && !frameRoot.maximized && frameRoot.snapMode !== "maximize"
        acceptedButtons: Qt.LeftButton

        onPressed: (mouse) => {
            frameRoot.requestFocus(frameRoot.winId);
            var gp = mapToItem(frameRoot.parent, mouse.x, mouse.y);
            startGX = gp.x;
            startGY = gp.y;
            origX = frameRoot.x;
            origY = frameRoot.y;
            origW = frameRoot.width;
            origH = frameRoot.height;
            frameRoot.snapMode = "";
            frameRoot.userResized = true;
            frameRoot.resizingNow = true;
        }

        onPositionChanged: (mouse) => {
            if (!pressed) return;
            var gp = mapToItem(frameRoot.parent, mouse.x, mouse.y);
            var dx = gp.x - startGX;
            var dy = gp.y - startGY;

            var nx = origX;
            var ny = origY;
            var nw = origW;
            var nh = origH;

            if (resizeLeft) {
                nw = frameRoot.clampFrameWidth(origW - dx);
                nx = origX + (origW - nw);
            } else if (resizeRight) {
                nw = frameRoot.clampFrameWidth(origW + dx);
            }
            if (resizeTop) {
                nh = frameRoot.clampFrameHeight(origH - dy);
                ny = Math.max(frameRoot.workArea.y, origY + (origH - nh));
                if (ny === frameRoot.workArea.y) {
                    nh = frameRoot.clampFrameHeight(origY + origH - ny);
                    ny = origY + origH - nh;
                }
            } else if (resizeBottom) {
                nh = frameRoot.clampFrameHeight(origH + dy);
            }

            frameRoot.applyFrameGeometry(nx, ny, nw, nh, true);
        }

        onReleased: {
            frameRoot.resizingNow = false;
            frameRoot.restoreRect = Qt.rect(frameRoot.x, frameRoot.y, frameRoot.width, frameRoot.height);
            frameRoot.applyFrameGeometry(frameRoot.x, frameRoot.y, frameRoot.width, frameRoot.height, false);
        }
    }

    // North, South, West, East edges
    ResizeHandle {
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 10; rightMargin: 10 }
        height: 3
        resizeTop: true
        cursorShape: Qt.SizeVerCursor
    }
    ResizeHandle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 10; rightMargin: 10 }
        height: 6
        resizeBottom: true
        cursorShape: Qt.SizeVerCursor
    }
    ResizeHandle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 10; bottomMargin: 10 }
        width: 6
        resizeLeft: true
        cursorShape: Qt.SizeHorCursor
    }
    ResizeHandle {
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: 10; bottomMargin: 10 }
        width: 6
        resizeRight: true
        cursorShape: Qt.SizeHorCursor
    }
    // 4 Corners (NW, NE, SW, SE)
    ResizeHandle {
        anchors { left: parent.left; top: parent.top }
        width: 10; height: 10
        resizeLeft: true; resizeTop: true
        cursorShape: Qt.SizeFDiagCursor
    }
    ResizeHandle {
        anchors { right: parent.right; top: parent.top }
        width: 10; height: 10
        resizeRight: true; resizeTop: true
        cursorShape: Qt.SizeBDiagCursor
    }
    ResizeHandle {
        anchors { left: parent.left; bottom: parent.bottom }
        width: 10; height: 10
        resizeLeft: true; resizeBottom: true
        cursorShape: Qt.SizeBDiagCursor
    }
    ResizeHandle {
        anchors { right: parent.right; bottom: parent.bottom }
        width: 10; height: 10
        resizeRight: true; resizeBottom: true
        cursorShape: Qt.SizeFDiagCursor
    }
}
