/*
    SPDX-FileCopyrightText: 2026 Terminal Plasma
    SPDX-License-Identifier: GPL-2.0-or-later
*/
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtWayland.Compositor
import QtWayland.Compositor.XdgShell
import QtWayland.Compositor.WlShell

WaylandCompositor {
    id: comp
    socketName: (Backend && Backend.waylandSocket && Backend.waylandSocket.length > 0) ? Backend.waylandSocket : "wayland-ascii-0"
    retainedSelection: true

    readonly property int primaryScreenIdx: {
        var list = Qt.application.screens;
        if (!list || list.length === 0) {
            return 0;
        }
        var pref = wmState ? wmState.preferredPrimaryOutput : "";
        if (pref && pref.length > 0) {
            for (var p = 0; p < list.length; p++) {
                if (list[p] && list[p].name === pref) {
                    return p;
                }
            }
        }
        var qtPrim = Qt.application.primaryScreen ? Qt.application.primaryScreen.name : "";
        if (qtPrim && qtPrim.length > 0) {
            for (var q = 0; q < list.length; q++) {
                if (list[q] && list[q].name === qtPrim) {
                    return q;
                }
            }
        }
        for (var j = 0; j < list.length; j++) {
            if (list[j] && list[j].virtualX === 0 && list[j].virtualY === 0) {
                return j;
            }
        }
        return 0;
    }

    onPrimaryScreenIdxChanged: {
        var prim = wmState.primaryOutputByIndex(comp.primaryScreenIdx);
        wmState.primaryShell = prim ? prim.desktopShell : null;
        if (prim) {
            comp.defaultOutput = prim;
        }
        if (wmState.popupReturnWinId > 0) {
            wmState.popupReturnWinId = -1;
        }
        Qt.callLater(function() {
            var resolved = wmState.primaryOutput();
            wmState.primaryShell = resolved ? resolved.desktopShell : null;
            if (resolved) {
                comp.defaultOutput = resolved;
            }
        });
    }

    readonly property bool multiMonitorActive: Backend.allMonitors || (Backend.fullscreenMode && Qt.application.screens.length > 1)
    readonly property var targetScreens: {
        if (multiMonitorActive && Qt.application.screens && Qt.application.screens.length > 0) {
            return Qt.application.screens;
        }
        if (Qt.application.screens && Qt.application.screens.length > 0) {
            return [Qt.application.screens[comp.primaryScreenIdx]];
        }
        return [null];
    }

    onCreatedChanged: {
        if (created) {
            if (!Backend.waylandSocket || Backend.waylandSocket.length === 0) {
                Backend.waylandSocket = socketName;
            }
            Qt.callLater(function() {
                Backend.startXWayland();
            });
        }
    }

    XdgShell {
        id: xdgShell
        onToplevelCreated: (toplevel, xdgSurface) => {
            wmState.createWindowFrame(xdgSurface, toplevel, null);
        }
    }

    XdgOutputManagerV1 {
        id: xdgOutputManager
    }

    // qmllint disable import unresolved-type
    extensions: [
        IdleInhibitManagerV1 { },
        TextInputManager { },
        TextInputManagerV3 { },
        XdgDecorationManagerV1 {
            preferredMode: XdgToplevel.ServerSideDecoration
        }
    ]
    // qmllint enable import unresolved-type

    WlShell {
        id: wlShell
        onWlShellSurfaceCreated: (shellSurface) => {
            wmState.createWindowFrame(shellSurface, null, shellSurface);
        }
    }

    Connections {
        target: comp.defaultSeat
        function onKeyboardFocusChanged(newFocus, oldFocus) {
            if (!newFocus) return;
            for (var i = 0; i < wmState.windowFrames.length; i++) {
                var f = wmState.windowFrames[i];
                if (f && !f.closing && f.shellSurface && f.shellSurface.surface === newFocus) {
                    if (wmState.activeWinId !== f.winId) {
                        wmState.focusWindow(f.winId);
                    }
                    break;
                }
            }
        }
    }

    QtObject {
        id: wmState

        property int currentWorkspace: 1
        property int nextWinId: 1
        property int topZ: 10
        property real splitRatio: 0.5
        property var windowFrames: []
        property var windowSummaryList: []
        property int activeWinId: -1
        property int popupReturnWinId: -1
        property bool modDragHeld: false
        property bool superTapPending: false
        property var outputsList: []
        property var primaryShell: null
        property string preferredPrimaryOutput: ""
        property var screenshotOutput: null
        property int screenshotReturnWinId: -1
        property bool screenLocked: false
        property bool powerDialogOpen: false
        property bool notificationsDrawerOpen: false
        property bool clipboardOpen: false
        property int overlayReturnWinId: -1
        property bool volumeOsdVisible: false
        property int volumeOsdLevel: 100
        property bool volumeOsdMuted: false
        property string volumeOsdLabel: "PipeWire"
        property bool dragGhostActive: false
        property var dragGhostOut: null
        property rect dragGhostRect: Qt.rect(0, 0, 0, 0)
        property string dragGhostTitle: ""

        property var appSettings: ({
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
            onkyoAudioGuard: true
        })

        property var currentTheme: ({
            name: "amber",
            label: "Warm Amber CRT",
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

        property var activeBgTileCommands: ({})
        property bool bgTerminalLaunchPending: false
        property string tallestOutputName: ""
        property var availableMonitors: []

        function getEffectiveBgTiles() {
            if (appSettings.bgLayoutTiles && Array.isArray(appSettings.bgLayoutTiles) && appSettings.bgLayoutTiles.length > 0) {
                return appSettings.bgLayoutTiles;
            }
            if (Boolean(appSettings.bgTerminalEnabled)) {
                var pOut = primaryOutput();
                var pName = (pOut && pOut.modelData && pOut.modelData.name) ? String(pOut.modelData.name) : "";
                var cmd = String(appSettings.bgTerminalCmd || "asciiquarium").trim();
                if (cmd === "") cmd = "asciiquarium";
                return [{
                    id: "tile-1",
                    kind: "terminal",
                    monitor: pName,
                    x: Number(appSettings.bgTerminalX) || 80,
                    y: Number(appSettings.bgTerminalY) || 60,
                    width: Math.max(240, Number(appSettings.bgTerminalWidth) || 900),
                    height: Math.max(160, Number(appSettings.bgTerminalHeight) || 520),
                    enabled: true,
                    cmd: cmd,
                    interactive: Boolean(appSettings.bgTerminalInteractive),
                    fontSize: Number(appSettings.bgTerminalFontSize) || 0,
                    opacity: appSettings.bgTerminalOpacity !== undefined ? Number(appSettings.bgTerminalOpacity) : 0.0,
                    matchGrid: appSettings.bgTerminalMatchGrid !== undefined ? Boolean(appSettings.bgTerminalMatchGrid) : true
                }];
            }
            return [];
        }

        function findOutputByNameOrFallback(monName) {
            if (monName && outputsList.length > 0) {
                for (var i = 0; i < outputsList.length; i++) {
                    var o = outputsList[i];
                    if (!o) continue;
                    var oName = (o.modelData && o.modelData.name) ? String(o.modelData.name) : ("Output-" + o.outputIndex);
                    if (oName === monName || String(o.outputIndex) === monName) {
                        return o;
                    }
                }
            }
            return primaryOutput();
        }

        function matchesBgTerminalFrame(frame) {
            if (!frame || frame.closing) return false;
            var aid = frame.appId ? String(frame.appId).toLowerCase() : "";
            var ttl = frame.winTitle ? String(frame.winTitle).toLowerCase() : "";
            return aid.indexOf("ascii-de-bg-tile-") !== -1 || ttl.indexOf("ascii-de-bg-tile-") !== -1
                || aid.indexOf("ascii-de-bg-term") !== -1 || ttl.indexOf("ascii-de-bg-term") !== -1;
        }

        function extractBgTileId(frame) {
            if (!frame) return "";
            var aid = frame.appId ? String(frame.appId) : "";
            var ttl = frame.winTitle ? String(frame.winTitle) : "";
            var m = aid.match(/ascii-de-bg-tile-([a-zA-Z0-9_\-]+)/);
            if (m && m[1]) return m[1];
            m = ttl.match(/ascii-de-bg-tile-([a-zA-Z0-9_\-]+)/);
            if (m && m[1]) return m[1];
            if (aid.indexOf("ascii-de-bg-term") !== -1 || ttl.indexOf("ascii-de-bg-term") !== -1) {
                return "tile-1";
            }
            return "";
        }

        function syncBgLayoutTiles(forceRestart) {
            var tiles = getEffectiveBgTiles();
            var activeTermTiles = [];
            for (var i = 0; i < tiles.length; i++) {
                var t = tiles[i];
                if (t && t.enabled && (t.kind === "terminal" || !t.kind)) {
                    activeTermTiles.push(t);
                }
            }

            var existingBgFrames = {};
            for (var j = 0; j < windowFrames.length; j++) {
                var f = windowFrames[j];
                if (f && !f.closing && f.isBgTerminal) {
                    var tid = f.bgTileId || "tile-1";
                    existingBgFrames[tid] = f;
                }
            }

            if (activeTermTiles.length === 0) {
                for (var oldId in existingBgFrames) {
                    closeWindow(existingBgFrames[oldId].winId);
                }
                Backend.stopAllBgTiles();
                activeBgTileCommands = {};
                bgTerminalLaunchPending = false;
                return;
            }

            var activeTileIds = {};
            for (var k = 0; k < activeTermTiles.length; k++) {
                activeTileIds[activeTermTiles[k].id] = true;
            }
            for (var oldTid in existingBgFrames) {
                if (!activeTileIds[oldTid]) {
                    closeWindow(existingBgFrames[oldTid].winId);
                    Backend.stopBgTile(oldTid);
                    var copy = Object.assign({}, activeBgTileCommands);
                    delete copy[oldTid];
                    activeBgTileCommands = copy;
                }
            }

            for (var ti = 0; ti < activeTermTiles.length; ti++) {
                var tile = activeTermTiles[ti];
                var curTileId = tile.id;
                var cmd = String(tile.cmd || appSettings.bgTerminalCmd || "asciiquarium").trim();
                if (cmd === "") cmd = "asciiquarium";

                var targetOut = tile.monitor ? findOutputByNameOrFallback(tile.monitor) : primaryOutput();
                var wa = targetOut ? targetOut.workArea : Qt.rect(0, 26, 1600, 906);
                var tw = Math.max(240, Number(tile.width) || 900);
                var th = Math.max(160, Number(tile.height) || 520);
                var tx = Number(tile.x);
                var ty = Number(tile.y);
                if (isNaN(tx)) tx = 80;
                if (isNaN(ty)) ty = Math.max(wa.y + 12, 60);

                var curBgFrame = existingBgFrames[curTileId];
                var prevCmd = activeBgTileCommands[curTileId] || "";

                if (curBgFrame && !forceRestart && prevCmd === cmd) {
                    if (targetOut && curBgFrame.outputContainer !== targetOut && targetOut.windowLayer) {
                        curBgFrame.parent = targetOut.windowLayer;
                        curBgFrame.outputContainer = targetOut;
                        curBgFrame.workArea = targetOut.workArea;
                        curBgFrame.bgTileMonitor = (targetOut.modelData && targetOut.modelData.name) ? String(targetOut.modelData.name) : "";
                    }
                    curBgFrame.applyFrameGeometry(tx, Math.max(wa.y, ty), tw, th, false);
                    continue;
                }

                if (curBgFrame) {
                    closeWindow(curBgFrame.winId);
                    Backend.stopBgTile(curTileId);
                }

                var cmdMap = Object.assign({}, activeBgTileCommands);
                cmdMap[curTileId] = cmd;
                activeBgTileCommands = cmdMap;
                bgTerminalLaunchPending = true;

                var fs = Number(tile.fontSize) || Number(appSettings.bgTerminalFontSize) || 0;
                var op = tile.opacity !== undefined ? Number(tile.opacity) : (appSettings.bgTerminalOpacity !== undefined ? Number(appSettings.bgTerminalOpacity) : 0.0);
                var bgHex = (currentTheme && currentTheme.bg) ? String(currentTheme.bg) : "#0d0f10";
                var fgHex = (currentTheme && currentTheme.fg) ? String(currentTheme.fg) : "#e6dcc8";
                var accentHex = (currentTheme && currentTheme.accent) ? String(currentTheme.accent) : "#ffb000";

                Backend.launchBgTile(curTileId, cmd, tw, th, fs, op, bgHex, fgHex, accentHex);
            }
        }

        function syncBgTerminal(forceRestart) {
            syncBgLayoutTiles(forceRestart);
        }

        function promoteFrameToBgTerminal(frame) {
            if (!frame || frame.closing || frame.isBgTerminal) return;
            var tileId = extractBgTileId(frame);
            var effTiles = getEffectiveBgTiles();
            var tileCfg = null;
            for (var ti = 0; ti < effTiles.length; ti++) {
                if (effTiles[ti] && effTiles[ti].id === tileId) {
                    tileCfg = effTiles[ti];
                    break;
                }
            }
            var targetOut = (tileCfg && tileCfg.monitor) ? findOutputByNameOrFallback(tileCfg.monitor) : (frame.outputContainer || primaryOutput());
            if (targetOut && frame.outputContainer !== targetOut && targetOut.windowLayer) {
                frame.parent = targetOut.windowLayer;
                frame.outputContainer = targetOut;
                frame.workArea = targetOut.workArea;
            }

            frame.isBgTerminal = true;
            frame.bgTileId = tileId;
            frame.bgTileMonitor = (targetOut && targetOut.modelData && targetOut.modelData.name) ? String(targetOut.modelData.name) : "";
            frame.bgTerminalInteractive = Qt.binding(function() {
                if (tileCfg && tileCfg.interactive !== undefined) {
                    return Boolean(tileCfg.interactive);
                }
                return Boolean(wmState.appSettings.bgTerminalInteractive);
            });
            frame.z = -100;
            frame.initialSized = true;

            var wa = targetOut ? targetOut.workArea : Qt.rect(0, 26, 1600, 906);
            var tw = tileCfg ? Math.max(240, Number(tileCfg.width) || 900) : Math.max(240, Number(appSettings.bgTerminalWidth) || 900);
            var th = tileCfg ? Math.max(160, Number(tileCfg.height) || 520) : Math.max(160, Number(appSettings.bgTerminalHeight) || 520);
            var tx = tileCfg ? Number(tileCfg.x) : Number(appSettings.bgTerminalX);
            var ty = tileCfg ? Number(tileCfg.y) : Number(appSettings.bgTerminalY);
            if (isNaN(tx)) tx = 80;
            if (isNaN(ty)) ty = Math.max(wa.y + 12, 60);

            frame.applyFrameGeometry(tx, Math.max(wa.y, ty), tw, th, false);
            bgTerminalLaunchPending = false;
            Backend.syncSurfaceOutput(frame.surfaceItem, targetOut, wmState.outputsList);
            Backend.normalizeClientSubsurfaces(frame.surfaceItem);

            if (frame.tileMoved) {
                frame.tileMoved.connect(wmState.persistBgTileGeometry);
            }

            if (activeWinId === frame.winId && !frame.bgTerminalInteractive) {
                frame.active = false;
                focusTopWindowOnWorkspace(currentWorkspace);
            } else {
                rebuildWindowSummaryList();
            }
        }

        function persistBgTileGeometry(tileId, monitorName, x, y, width, height) {
            if (!tileId) return;
            var currentTiles = getEffectiveBgTiles().slice();
            var found = false;
            for (var i = 0; i < currentTiles.length; i++) {
                if (currentTiles[i] && currentTiles[i].id === tileId) {
                    var updatedTile = Object.assign({}, currentTiles[i], {
                        x: Math.round(x),
                        y: Math.round(y),
                        width: Math.round(width),
                        height: Math.round(height)
                    });
                    if (monitorName) updatedTile.monitor = monitorName;
                    currentTiles[i] = updatedTile;
                    found = true;
                    break;
                }
            }
            if (!found) {
                currentTiles.push({
                    id: tileId,
                    kind: "terminal",
                    monitor: monitorName || "",
                    x: Math.round(x),
                    y: Math.round(y),
                    width: Math.round(width),
                    height: Math.round(height),
                    enabled: true,
                    cmd: "asciiquarium",
                    interactive: false,
                    fontSize: 0,
                    opacity: 0.0,
                    matchGrid: true
                });
            }
            var newSettings = Object.assign({}, appSettings, {
                bgLayoutTiles: currentTiles,
                bgTerminalX: Math.round(x),
                bgTerminalY: Math.round(y),
                bgTerminalWidth: Math.round(width),
                bgTerminalHeight: Math.round(height)
            });
            appSettings = newSettings;
            Backend.runBackendAsync(["settings", "set", JSON.stringify({
                bgLayoutTiles: currentTiles,
                bgTerminalX: Math.round(x),
                bgTerminalY: Math.round(y),
                bgTerminalWidth: Math.round(width),
                bgTerminalHeight: Math.round(height)
            })], "bg_tiles_persist");
        }

        function applySettings(newSettings) {
            if (!newSettings || typeof newSettings !== "object") {
                return;
            }
            var merged = Object.assign({}, appSettings, newSettings);
            appSettings = merged;
            syncBgLayoutTiles(false);
        }

        function applyTheme(newTheme) {
            if (!newTheme || typeof newTheme !== "object" || !newTheme.bg) {
                return;
            }
            currentTheme = newTheme;
            var patch = {};
            if (newTheme.name) patch.theme = newTheme.name;
            if (newTheme.fontFamily) patch.fontFamily = newTheme.fontFamily;
            if (newTheme.fontSize) patch.fontSize = Number(newTheme.fontSize);
            if (Object.keys(patch).length > 0) {
                applySettings(patch);
            }
        }

        function triggerSpeedLines() {
            if (!currentTheme || currentTheme.speedLines !== true) {
                return;
            }
            for (var i = 0; i < outputsList.length; i++) {
                var out = outputsList[i];
                if (out && out.outputRoot) {
                    out.outputRoot.triggerSpeedLines();
                }
            }
        }

        Component.onCompleted: {
            var rawSettings = Backend.runBackend(["settings", "get"]);
            if (rawSettings && rawSettings.trim().length > 0) {
                try {
                    var parsedSettings = JSON.parse(rawSettings);
                    if (parsedSettings && typeof parsedSettings === "object" && parsedSettings.gridDensity !== undefined) {
                        applySettings(parsedSettings);
                    }
                } catch (e2) {
                    // Keep default settings
                }
            }
            var rawTheme = Backend.runBackend(["theme", "get"]);
            if (rawTheme && rawTheme.trim().length > 0) {
                try {
                    var parsed = JSON.parse(rawTheme);
                    if (parsed && parsed.bg) {
                        applyTheme(parsed);
                    }
                } catch (e) {
                    // Keep default amber theme
                }
            }
            var rawDisplays = Backend.runBackend(["displays", "list"]);
            if (rawDisplays && rawDisplays.trim().length > 0) {
                try {
                    var parsedDisplays = JSON.parse(rawDisplays);
                    syncPreferredPrimaryFromMonitors(parsedDisplays);
                } catch (e3) {
                    // Keep screen-order fallback
                }
            }
        }

        function syncPreferredPrimaryFromMonitors(mons) {
            if (!Array.isArray(mons)) {
                return;
            }
            for (var i = 0; i < mons.length; i++) {
                var m = mons[i];
                if (m && m.primary === true && m.name && String(m.name).length > 0) {
                    preferredPrimaryOutput = String(m.name);
                    return;
                }
            }
        }

        function primaryOutputByIndex(targetIdx) {
            if (comp.multiMonitorActive) {
                for (var i = 0; i < outputsList.length; i++) {
                    if (outputsList[i] && outputsList[i].outputIndex === targetIdx) {
                        return outputsList[i];
                    }
                }
            }
            return primaryOutput();
        }

        function primaryOutput() {
            for (var i = 0; i < outputsList.length; i++) {
                if (outputsList[i] && outputsList[i].isPrimary) {
                    return outputsList[i];
                }
            }
            return outputsList.length > 0 ? outputsList[0] : null;
        }

        function syncXdgOutput(out) {
            if (!out) return;
            Backend.registerXdgOutput(
                xdgOutputManager,
                out,
                out.model,
                Math.round(out.globalX),
                Math.round(out.globalY),
                Math.round(out.outputWidth),
                Math.round(out.outputHeight)
            );
        }

        function updateMonitorMetrics() {
            var bestName = "";
            var bestH = -1;
            var bestRatio = -1;
            var list = [];
            for (var i = 0; i < outputsList.length; i++) {
                var o = outputsList[i];
                if (!o) continue;
                var oName = (o.modelData && o.modelData.name) ? String(o.modelData.name) : ("Output-" + o.outputIndex);
                var gw = (o.modelData && o.modelData.geometry && o.modelData.geometry.width > 0)
                    ? Math.round(o.modelData.geometry.width) : Math.max(1, Math.round(o.outputWidth));
                var gh = (o.modelData && o.modelData.geometry && o.modelData.geometry.height > 0)
                    ? Math.round(o.modelData.geometry.height) : Math.max(1, Math.round(o.outputHeight));
                var ratio = gh / Math.max(1, gw);
                if (gh > bestH || (gh === bestH && ratio > bestRatio)) {
                    bestH = gh;
                    bestRatio = ratio;
                    bestName = oName;
                }
                list.push({ name: oName, width: gw, height: gh });
            }
            for (var j = 0; j < list.length; j++) {
                list[j].isTallest = (list[j].name === bestName);
                list[j].label = list[j].name + " (" + list[j].width + "x" + list[j].height + (list[j].isTallest ? " · tallest" : "") + ")";
            }
            tallestOutputName = bestName;
            availableMonitors = list;
        }

        function registerOutput(out) {
            if (!out) return;
            syncXdgOutput(out);
            var next = outputsList.filter(function(o) { return o && o !== out; });
            next.push(out);
            next.sort(function(a, b) { return a.outputIndex - b.outputIndex; });
            outputsList = next;
            updateMonitorMetrics();
            var prim = primaryOutput();
            primaryShell = prim ? prim.desktopShell : null;
            if (prim) {
                comp.defaultOutput = prim;
            }
        }

        function unregisterOutput(out) {
            if (!out) return;
            var remaining = outputsList.filter(function(o) { return o && o !== out; });
            var fallback = remaining.length > 0 ? remaining[0] : null;
            if (fallback) {
                for (var i = 0; i < windowFrames.length; i++) {
                    var f = windowFrames[i];
                    if (f && f.outputContainer === out) {
                        transferFrameToOutput(f, fallback, 40, fallback.workArea.y + 20);
                    }
                }
            }
            outputsList = remaining;
            updateMonitorMetrics();
            var prim = primaryOutput();
            primaryShell = prim ? prim.desktopShell : null;
            if (prim) {
                comp.defaultOutput = prim;
            }
        }

        function findOutputAtGlobal(gx, gy) {
            if (outputsList.length === 0) return null;
            var best = null;
            var bestDist = Infinity;
            for (var i = 0; i < outputsList.length; i++) {
                var out = outputsList[i];
                if (!out) continue;
                var ox = out.globalX;
                var oy = out.globalY;
                var ow = out.outputWidth;
                var oh = out.outputHeight;
                if (gx >= ox && gx < ox + ow && gy >= oy && gy < oy + oh) {
                    return out;
                }
                var cx = Math.max(ox, Math.min(gx, ox + ow));
                var cy = Math.max(oy, Math.min(gy, oy + oh));
                var dist = Math.abs(gx - cx) + Math.abs(gy - cy);
                if (dist < bestDist) {
                    bestDist = dist;
                    best = out;
                }
            }
            return best;
        }

        function transferFrameToOutput(frame, targetOut, localX, localY) {
            if (!frame || !targetOut || frame.outputContainer === targetOut) {
                return;
            }
            var wa = targetOut.workArea;
            var fw = Math.min(Math.max(frame.minWinW, wa.width - 16), Math.max(frame.minWinW, frame.width));
            var fh = Math.min(Math.max(frame.minWinH, wa.height - 16), Math.max(frame.minWinH, frame.height));
            var minX = -(fw - 60);
            var maxX = Math.max(0, wa.width - 60);
            var minY = wa.y;
            var maxY = Math.max(wa.y, wa.y + wa.height - Math.max(30, frame.topH));
            var nx = Math.round(Math.max(minX, Math.min(maxX, localX)));
            var ny = Math.round(Math.max(minY, Math.min(maxY, localY)));

            frame.parent = targetOut.windowLayer;
            frame.outputContainer = targetOut;
            frame.restoreRect = Qt.rect(nx, ny, fw, fh);
            frame.applyFrameGeometry(nx, ny, fw, fh, false);
            Backend.syncSurfaceOutput(frame.surfaceItem, targetOut, wmState.outputsList);
            Backend.normalizeClientSubsurfaces(frame.surfaceItem);
            Qt.callLater(function() {
                if (frame && !frame.closing && wmState.activeWinId === frame.winId) {
                    frame.focusSurface();
                }
            });
            rebuildWindowSummaryList();
        }

        function clearDragVisuals(exceptOut) {
            clearAllSnapPreviews(exceptOut);
            if (!exceptOut) {
                dragGhostActive = false;
                dragGhostOut = null;
                dragGhostTitle = "";
            }
        }

        function clearAllSnapPreviews(exceptOut) {
            for (var i = 0; i < outputsList.length; i++) {
                var out = outputsList[i];
                if (out && out !== exceptOut && out.gridCanvas) {
                    out.gridCanvas.activeSnapZone = "";
                    out.gridCanvas.snapPreviewRect = Qt.rect(0, 0, 0, 0);
                }
            }
        }

        function handleFrameDragMoved(winId, gx, gy) {
            var frame = findFrameById(winId);
            if (!frame || frame.closing) return;
            if (frame.isBgTerminal) {
                clearAllSnapPreviews(null);
                return;
            }
            var srcOut = frame.outputContainer || primaryOutput();
            if (!srcOut) return;

            var crossEnabled = (appSettings.crossMonitorDragging !== false);
            var hoverOut = crossEnabled ? (findOutputAtGlobal(gx, gy) || srcOut) : srcOut;
            if (!hoverOut || !hoverOut.gridCanvas) return;

            clearAllSnapPreviews(hoverOut);
            var lx = gx - hoverOut.globalX;
            var ly = gy - hoverOut.globalY;
            var zone = frame.detectSnapZoneInArea(lx, ly, hoverOut.workArea);
            hoverOut.gridCanvas.activeSnapZone = zone;
            hoverOut.gridCanvas.snapPreviewRect = zone !== ""
                ? frame.computeSnapRectInArea(zone, hoverOut.workArea, splitRatio)
                : Qt.rect(0, 0, 0, 0);

            if (crossEnabled && srcOut && hoverOut !== srcOut) {
                var fgx = srcOut.globalX + frame.x;
                var fgy = srcOut.globalY + frame.y;
                var gw = frame.width;
                var gh = frame.height;
                var gxLocal = fgx - hoverOut.globalX;
                var gyLocal = fgy - hoverOut.globalY;
                dragGhostOut = hoverOut;
                dragGhostRect = Qt.rect(gxLocal, gyLocal, gw, gh);
                dragGhostTitle = frame.winTitle || "wayland-app";
                dragGhostActive = true;
            } else {
                dragGhostActive = false;
                dragGhostOut = null;
            }
        }

        function handleFrameDragEnded(winId, gx, gy) {
            clearDragVisuals(null);
            var frame = findFrameById(winId);
            if (!frame || frame.closing) return;
            if (frame.isBgTerminal) {
                clearAllSnapPreviews(null);
                return;
            }
            var srcOut = frame.outputContainer || primaryOutput();
            if (!srcOut) return;

            var crossEnabled = (appSettings.crossMonitorDragging !== false);
            var cursorOut = crossEnabled ? (findOutputAtGlobal(gx, gy) || srcOut) : srcOut;
            var fgx = srcOut.globalX + frame.x;
            var fgy = srcOut.globalY + frame.y;

            var lx = gx - cursorOut.globalX;
            var ly = gy - cursorOut.globalY;
            var zone = frame.detectSnapZoneInArea(lx, ly, cursorOut.workArea);
            var targetOut = cursorOut;

            if (targetOut && targetOut !== srcOut) {
                transferFrameToOutput(frame, targetOut, fgx - targetOut.globalX, fgy - targetOut.globalY);
            }
            if (zone !== "" && !frame.isBgTerminal) {
                frame.applySnap(zone);
                triggerSpeedLines();
            } else {
                var finalOut = frame.outputContainer || targetOut;
                if (finalOut) {
                    frame.y = Math.max(finalOut.workArea.y, frame.y);
                }
                frame.windowStateChanged();
            }
            if (frame.isBgTerminal) {
                var bx = Math.round(frame.x);
                var by = Math.round(frame.y);
                var monName = (frame.outputContainer && frame.outputContainer.modelData && frame.outputContainer.modelData.name)
                    ? String(frame.outputContainer.modelData.name) : "";
                persistBgTileGeometry(frame.bgTileId || "tile-1", monName, bx, by, frame.width, frame.height);
                if (frame.bgTerminalInteractive) {
                    focusWindow(frame.winId);
                }
            } else {
                focusWindow(frame.winId);
            }
        }

        function findFrameById(winId) {
            for (var i = 0; i < windowFrames.length; i++) {
                if (windowFrames[i] && windowFrames[i].winId === winId) {
                    return windowFrames[i];
                }
            }
            return null;
        }

        function activeFrame() {
            return findFrameById(activeWinId);
        }

        function rebuildWindowSummaryList() {
            var out = [];
            for (var i = 0; i < windowFrames.length; i++) {
                var f = windowFrames[i];
                if (!f || f.closing) continue;
                if (f.isBgTerminal && !Boolean(appSettings.bgTerminalInteractive)) continue;
                (function(frame) {
                    out.push({
                        winId: frame.winId,
                        title: frame.winTitle,
                        appId: frame.appId,
                        x: frame.x,
                        y: frame.y,
                        width: frame.width,
                        height: frame.height,
                        minimized: frame.minimized,
                        maximized: frame.maximized,
                        active: frame.active,
                        workspace: frame.workspace,
                        focusFn: function() { wmState.focusWindow(frame.winId); },
                        toggleMinFn: function() { wmState.toggleMinimizeWindow(frame.winId); },
                        closeFn: function() { wmState.closeWindow(frame.winId); }
                    });
                })(f);
            }
            windowSummaryList = out;
        }

        function focusWindow(winId) {
            var target = findFrameById(winId);
            if (!target) {
                activeWinId = -1;
                for (var k = 0; k < windowFrames.length; k++) {
                    if (windowFrames[k]) windowFrames[k].active = false;
                }
                rebuildWindowSummaryList();
                return;
            }
            for (var m = 0; m < windowFrames.length; m++) {
                var ch = windowFrames[m];
                if (ch && !ch.closing && !ch.minimized && ch.parentFrame === target && ch.xdgToplevel && ch.xdgToplevel.modal) {
                    target = ch;
                    winId = ch.winId;
                    break;
                }
            }
            if (primaryShell && primaryShell.hasOpenPopup) {
                popupReturnWinId = -1;
                primaryShell.closeAllPopups();
            }
            if (target.workspace !== currentWorkspace) {
                currentWorkspace = target.workspace;
            }
            if (target.minimized) {
                target.minimized = false;
            }
            if (!target.isBgTerminal) {
                topZ += 1;
                target.z = topZ;
            } else {
                target.z = -100;
            }
            activeWinId = winId;
            for (var i = 0; i < windowFrames.length; i++) {
                if (windowFrames[i]) {
                    windowFrames[i].active = (windowFrames[i].winId === winId);
                }
            }
            if (target.outputContainer && target.outputContainer.outputWindow) {
                target.outputContainer.outputWindow.raise();
                target.outputContainer.outputWindow.requestActivate();
            }
            target.focusSurface();
            rebuildWindowSummaryList();
        }

        function focusTopWindowOnWorkspace(ws) {
            var best = null;
            for (var i = 0; i < windowFrames.length; i++) {
                var f = windowFrames[i];
                if (f && f.workspace === ws && !f.minimized) {
                    if (!best || f.z > best.z) {
                        best = f;
                    }
                }
            }
            if (best) {
                focusWindow(best.winId);
            } else {
                activeWinId = -1;
                for (var j = 0; j < windowFrames.length; j++) {
                    if (windowFrames[j]) windowFrames[j].active = false;
                }
                var prim = primaryOutput();
                if (prim && prim.outputRoot) {
                    prim.outputRoot.forceActiveFocus();
                }
                rebuildWindowSummaryList();
            }
        }

        function toggleMinimizeWindow(winId) {
            var f = findFrameById(winId);
            if (!f) return;
            f.minimized = !f.minimized;
            if (f.minimized) {
                if (activeWinId === winId) {
                    focusTopWindowOnWorkspace(currentWorkspace);
                } else {
                    rebuildWindowSummaryList();
                }
            } else {
                focusWindow(winId);
            }
        }

        function toggleMaximizeWindow(winId) {
            var f = findFrameById(winId);
            if (!f) return;
            if (f.clientFullscreen) {
                f.exitFullscreen();
            } else if (f.maximized || f.snapMode !== "") {
                f.restoreFloating();
            } else {
                f.applySnap("maximize");
            }
            focusWindow(winId);
        }

        function toggleFullscreenWindow(winId) {
            var f = findFrameById(winId);
            if (!f) return;
            if (f.clientFullscreen) {
                f.exitFullscreen();
            } else {
                f.enterFullscreen(f.outputContainer || primaryOutput());
            }
            focusWindow(winId);
        }

        function closeWindow(winId) {
            var f = findFrameById(winId);
            if (!f) return;
            if (f.xdgToplevel && typeof f.xdgToplevel.sendClose === "function") {
                f.xdgToplevel.sendClose();
            } else if (f.shellSurface && f.shellSurface.surface) {
                comp.destroyClientForSurface(f.shellSurface.surface);
            } else {
                removeWindowFrame(winId);
            }
        }

        function removeWindowFrame(winId) {
            var next = [];
            var removed = null;
            for (var i = 0; i < windowFrames.length; i++) {
                var f = windowFrames[i];
                if (!f) continue;
                if (f.winId === winId) {
                    removed = f;
                } else {
                    next.push(f);
                }
            }
            windowFrames = next;
            if (removed) {
                removed.closing = true;
                removed.destroy();
            }
            if (activeWinId === winId) {
                focusTopWindowOnWorkspace(currentWorkspace);
            } else {
                rebuildWindowSummaryList();
            }
        }

        function createWindowFrame(shellSurfaceObj, xdgTop, wlShellSurf) {
            var rawAppId = (xdgTop && xdgTop.appId) ? String(xdgTop.appId) : "";
            var rawTitle = (xdgTop && xdgTop.title) ? String(xdgTop.title) : ((wlShellSurf && wlShellSurf.title) ? String(wlShellSurf.title) : "");
            var isBgTerm = (rawAppId.indexOf("ascii-de-bg-tile-") !== -1
                || rawTitle.indexOf("ascii-de-bg-tile-") !== -1
                || rawAppId === "ascii-de-bg-term"
                || rawTitle === "ascii-de-bg-term");
            var detectedTileId = "";
            var tileConfig = null;
            if (isBgTerm) {
                var m = rawAppId.match(/ascii-de-bg-tile-([a-zA-Z0-9_\-]+)/);
                if (m && m[1]) detectedTileId = m[1];
                else {
                    m = rawTitle.match(/ascii-de-bg-tile-([a-zA-Z0-9_\-]+)/);
                    if (m && m[1]) detectedTileId = m[1];
                    else detectedTileId = "tile-1";
                }
                var effTiles = wmState.getEffectiveBgTiles();
                for (var ti = 0; ti < effTiles.length; ti++) {
                    if (effTiles[ti] && effTiles[ti].id === detectedTileId) {
                        tileConfig = effTiles[ti];
                        break;
                    }
                }
            }
            var parentWinFrame = null;
            if (!isBgTerm && xdgTop && xdgTop.parentToplevel) {
                for (var p = 0; p < windowFrames.length; p++) {
                    var pf = windowFrames[p];
                    if (pf && !pf.closing && pf.xdgToplevel === xdgTop.parentToplevel) {
                        parentWinFrame = pf;
                        break;
                    }
                }
            }
            var act = isBgTerm ? null : (parentWinFrame || activeFrame());
            var targetOut = null;
            if (isBgTerm && tileConfig && tileConfig.monitor) {
                targetOut = wmState.findOutputByNameOrFallback(tileConfig.monitor);
            }
            if (!targetOut) {
                targetOut = (act && act.outputContainer) ? act.outputContainer : primaryOutput();
            }
            if (!targetOut || !targetOut.windowLayer) {
                return;
            }

            var id = nextWinId++;
            var visibleCount = 0;
            for (var i = 0; i < windowFrames.length; i++) {
                if (windowFrames[i] && windowFrames[i].workspace === currentWorkspace) {
                    visibleCount++;
                }
            }
            var wa = targetOut.workArea;
            var initW = Math.min(960, Math.max(480, Math.round(wa.width * 0.6)));
            var initH = Math.min(620, Math.max(360, Math.round(wa.height * 0.65)));
            if (xdgTop && xdgTop.minSize && xdgTop.minSize.width > 0 && xdgTop.minSize.height > 0) {
                initW = Math.max(initW, Math.round(xdgTop.minSize.width) + 20);
                initH = Math.max(initH, Math.round(xdgTop.minSize.height) + 44);
            }
            if (xdgTop && xdgTop.maxSize && xdgTop.maxSize.width > 0 && xdgTop.maxSize.width >= (xdgTop.minSize ? xdgTop.minSize.width : 0)) {
                initW = Math.min(initW, Math.round(xdgTop.maxSize.width) + 20);
            }
            if (xdgTop && xdgTop.maxSize && xdgTop.maxSize.height > 0 && xdgTop.maxSize.height >= (xdgTop.minSize ? xdgTop.minSize.height : 0)) {
                initH = Math.min(initH, Math.round(xdgTop.maxSize.height) + 44);
            }
            var offset = (visibleCount % 7) * 28;
            var initX = parentWinFrame
                ? Math.max(8, Math.min(Math.max(8, wa.width - initW), Math.round(parentWinFrame.x + (parentWinFrame.width - initW) * 0.5)))
                : Math.max(16, Math.round((wa.width - initW) * 0.5) + offset - 40);
            var initY = parentWinFrame
                ? Math.max(wa.y + 8, Math.min(Math.max(wa.y + 8, wa.y + wa.height - initH), Math.round(parentWinFrame.y + (parentWinFrame.height - initH) * 0.5)))
                : Math.max(wa.y + 12, wa.y + Math.round((wa.height - initH) * 0.35) + offset);

            if (isBgTerm) {
                wmState.bgTerminalLaunchPending = false;
                if (tileConfig) {
                    initW = Math.max(240, Number(tileConfig.width) || 900);
                    initH = Math.max(160, Number(tileConfig.height) || 520);
                    var cfgTileX = Number(tileConfig.x);
                    var cfgTileY = Number(tileConfig.y);
                    initX = isNaN(cfgTileX) ? 80 : cfgTileX;
                    initY = isNaN(cfgTileY) ? Math.max(wa.y + 12, 60) : Math.max(wa.y, cfgTileY);
                } else {
                    initW = Math.max(240, Number(appSettings.bgTerminalWidth) || 900);
                    initH = Math.max(160, Number(appSettings.bgTerminalHeight) || 520);
                    var cfgX = Number(appSettings.bgTerminalX);
                    var cfgY = Number(appSettings.bgTerminalY);
                    initX = isNaN(cfgX) ? 80 : cfgX;
                    initY = isNaN(cfgY) ? Math.max(wa.y + 12, 60) : Math.max(wa.y, cfgY);
                }
            }

            if (!isBgTerm) topZ += 1;
            var frame = frameComponent.createObject(targetOut.windowLayer, {
                winId: id,
                winIndex: id,
                isBgTerminal: isBgTerm,
                bgTileId: detectedTileId,
                bgTileMonitor: (targetOut && targetOut.modelData && targetOut.modelData.name) ? String(targetOut.modelData.name) : "",
                bgTerminalInteractive: Qt.binding(function() {
                    if (tileConfig && tileConfig.interactive !== undefined) {
                        return Boolean(tileConfig.interactive);
                    }
                    return Boolean(wmState.appSettings.bgTerminalInteractive);
                }),
                shellSurface: shellSurfaceObj,
                xdgToplevel: xdgTop,
                wlShellSurface: wlShellSurf,
                parentFrame: parentWinFrame,
                workspace: parentWinFrame ? parentWinFrame.workspace : currentWorkspace,
                x: initX,
                y: initY,
                width: initW,
                height: initH,
                z: isBgTerm ? -100 : topZ,
                restoreRect: Qt.rect(initX, initY, initW, initH),
                outputContainer: targetOut,
                workArea: targetOut.workArea,
                splitRatio: Qt.binding(function() { return wmState.splitRatio; }),
                theme: Qt.binding(function() { return wmState.currentTheme; }),
                modDragHeld: Qt.binding(function() { return wmState.modDragHeld; }),
                multiMonitorMode: Qt.binding(function() { return comp.multiMonitorActive && wmState.outputsList.length > 1; }),
                crossMonitorDragging: Qt.binding(function() { return wmState.appSettings.crossMonitorDragging !== false; }),
                snapEnabled: Qt.binding(function() { return wmState.appSettings.snapEnabled !== false; }),
                snapThresholdPx: Qt.binding(function() { return Number(wmState.appSettings.snapThresholdPx) || 24; }),
                fontFamily: Qt.binding(function() { return wmState.appSettings.fontFamily || "JetBrains Mono"; }),
                fontSize: Qt.binding(function() { return Number(wmState.appSettings.fontSize) || 13; }),
                gridCanvas: targetOut.gridCanvas,
                allOutputs: Qt.binding(function() { return wmState.outputsList; })
            });

            if (!frame) return;

            Backend.syncSurfaceOutput(frame.surfaceItem, targetOut, wmState.outputsList);
            Backend.normalizeClientSubsurfaces(frame.surfaceItem);

            frame.workArea = Qt.binding(function() {
                return frame.outputContainer ? frame.outputContainer.workArea : Qt.rect(0, 26, 1600, 906);
            });
            frame.gridCanvas = Qt.binding(function() {
                return frame.outputContainer ? frame.outputContainer.gridCanvas : null;
            });

            frame.visible = Qt.binding(function() {
                return !frame.minimized && frame.workspace === wmState.currentWorkspace;
            });
            frame.requestFocus.connect(wmState.focusWindow);
            frame.requestClose.connect(wmState.closeWindow);
            frame.requestToggleMinimize.connect(wmState.toggleMinimizeWindow);
            frame.requestToggleMaximize.connect(wmState.toggleMaximizeWindow);
            frame.requestToggleFullscreen.connect(wmState.toggleFullscreenWindow);
            frame.windowStateChanged.connect(wmState.rebuildWindowSummaryList);
            frame.surfaceClosed.connect(wmState.removeWindowFrame);
            frame.dragMoved.connect(wmState.handleFrameDragMoved);
            frame.dragEnded.connect(wmState.handleFrameDragEnded);
            frame.modReleaseRequested.connect(function() {
                wmState.modDragHeld = false;
                wmState.superTapPending = false;
            });

            if (frame.tileMoved) {
                frame.tileMoved.connect(wmState.persistBgTileGeometry);
            }

            if (xdgTop) {
                xdgTop.appIdChanged.connect(function() {
                    if (wmState.matchesBgTerminalFrame(frame)) {
                        wmState.promoteFrameToBgTerminal(frame);
                    }
                });
                xdgTop.titleChanged.connect(function() {
                    if (wmState.matchesBgTerminalFrame(frame)) {
                        wmState.promoteFrameToBgTerminal(frame);
                    }
                });
                xdgTop.setMaximized.connect(function() { if (frame && !frame.closing && !frame.clientFullscreen) frame.applySnap("maximize"); });
                xdgTop.unsetMaximized.connect(function() { if (frame && !frame.closing && !frame.clientFullscreen) frame.restoreFloating(); });
                xdgTop.setFullscreen.connect(function(requestedOut) {
                    if (!frame || frame.closing) return;
                    var destOut = frame.outputContainer || wmState.primaryOutput();
                    if (requestedOut && wmState.outputsList.indexOf(requestedOut) !== -1) {
                        destOut = requestedOut;
                    }
                    if (destOut) {
                        frame.enterFullscreen(destOut);
                        wmState.focusWindow(frame.winId);
                    }
                });
                xdgTop.unsetFullscreen.connect(function() {
                    if (!frame || frame.closing) return;
                    frame.exitFullscreen();
                    wmState.focusWindow(frame.winId);
                });
                xdgTop.setMinimized.connect(function() { if (frame && !frame.closing) wmState.toggleMinimizeWindow(frame.winId); });
            }

            if (wlShellSurf && typeof wlShellSurf.setFullScreen !== "undefined") {
                wlShellSurf.setFullScreen.connect(function(method, framerate, requestedOut) {
                    if (!frame || frame.closing) return;
                    var destOut = frame.outputContainer || wmState.primaryOutput();
                    if (requestedOut && wmState.outputsList.indexOf(requestedOut) !== -1) {
                        destOut = requestedOut;
                    }
                    if (destOut) {
                        frame.enterFullscreen(destOut);
                        wmState.focusWindow(frame.winId);
                    }
                });
            }

            var updated = windowFrames.slice();
            updated.push(frame);
            windowFrames = updated;
            var isInteractive = (tileConfig && tileConfig.interactive !== undefined) ? Boolean(tileConfig.interactive) : Boolean(appSettings.bgTerminalInteractive);
            if (!isBgTerm || isInteractive) {
                focusWindow(id);
            } else {
                rebuildWindowSummaryList();
            }
        }

        function switchWorkspace(ws) {
            if (ws < 1 || ws > 4 || ws === currentWorkspace) {
                return;
            }
            currentWorkspace = ws;
            focusTopWindowOnWorkspace(ws);
            triggerSpeedLines();
        }

        function snapActiveWindow(zone) {
            var f = activeFrame();
            if (!f) return;
            if (zone === "restore") {
                if (f.maximized || f.snapMode !== "") {
                    f.restoreFloating();
                } else {
                    toggleMinimizeWindow(f.winId);
                }
                return;
            }
            f.applySnap(zone);
            triggerSpeedLines();
        }

        function cascadeWindows() {
            var idxByOut = {};
            for (var i = 0; i < windowFrames.length; i++) {
                var f = windowFrames[i];
                if (f && f.workspace === currentWorkspace) {
                    var out = f.outputContainer || primaryOutput();
                    var key = out ? String(out.outputIndex) : "0";
                    var idx = idxByOut[key] || 0;
                    var wa = out ? out.workArea : Qt.rect(0, 26, 1600, 906);
                    var cw = Math.min(920, Math.round(wa.width * 0.62));
                    var ch = Math.min(580, Math.round(wa.height * 0.68));
                    f.clientFullscreen = false;
                    f.minimized = false;
                    f.maximized = false;
                    f.snapMode = "";
                    var cx = wa.x + 36 + (idx % 8) * 32;
                    var cy = wa.y + 24 + (idx % 8) * 28;
                    f.restoreRect = Qt.rect(cx, cy, cw, ch);
                    f.applyFrameGeometry(cx, cy, cw, ch, false);
                    topZ += 1;
                    f.z = topZ;
                    idxByOut[key] = idx + 1;
                }
            }
            focusTopWindowOnWorkspace(currentWorkspace);
        }

        function tileSideBySide() {
            var groups = {};
            for (var i = 0; i < windowFrames.length; i++) {
                var f = windowFrames[i];
                if (f && !f.closing && f.workspace === currentWorkspace && !f.minimized) {
                    var out = f.outputContainer || primaryOutput();
                    var key = out ? String(out.outputIndex) : "0";
                    if (!groups[key]) groups[key] = [];
                    groups[key].push(f);
                }
            }
            var keys = Object.keys(groups);
            if (keys.length === 0) return;
            splitRatio = 0.5;
            for (var g = 0; g < keys.length; g++) {
                var vis = groups[keys[g]];
                if (vis.length === 1) {
                    vis[0].applySnap("maximize");
                    continue;
                }
                for (var j = 0; j < vis.length; j++) {
                    vis[j].applySnap((j % 2) === 0 ? "left" : "right");
                }
            }
            rebuildWindowSummaryList();
        }

        function applySplitRatio(targetOut, newRatio) {
            splitRatio = Math.min(0.75, Math.max(0.25, newRatio));
            for (var i = 0; i < windowFrames.length; i++) {
                var f = windowFrames[i];
                if (f && !f.minimized && f.workspace === currentWorkspace && (!targetOut || f.outputContainer === targetOut)) {
                    if (f.snapMode === "left" || f.snapMode === "right") {
                        var r = f.computeSnapRect(f.snapMode);
                        f.applyFrameGeometry(r.x, r.y, r.width, r.height, true);
                    }
                }
            }
        }

        function cycleAltTab() {
            var vis = [];
            for (var i = 0; i < windowSummaryList.length; i++) {
                if (windowSummaryList[i].workspace === currentWorkspace) {
                    vis.push(windowSummaryList[i]);
                }
            }
            if (vis.length === 0) return;
            if (!primaryShell) return;
            if (!primaryShell.altTabOpen) {
                primaryShell.altTabOpen = true;
                primaryShell.altTabIndex = vis.length > 1 ? 1 : 0;
            } else {
                primaryShell.altTabIndex = (primaryShell.altTabIndex + 1) % vis.length;
            }
            var chosen = vis[primaryShell.altTabIndex];
            if (chosen) {
                focusWindow(chosen.winId);
            }
        }

        function openScreenshotOverlay() {
            if (screenLocked) return;
            if (primaryShell && primaryShell.hasOpenPopup) {
                primaryShell.closeAllPopups();
            }
            powerDialogOpen = false;
            notificationsDrawerOpen = false;
            clipboardOpen = false;
            var af = activeFrame();
            var targetOut = (af && af.outputContainer) ? af.outputContainer : primaryOutput();
            if (!targetOut) return;
            screenshotReturnWinId = activeWinId;
            // qmllint disable unqualified
            Backend.clearSeatKeyboardFocus(comp);
            // qmllint enable unqualified
            if (targetOut.outputWindow) {
                targetOut.outputWindow.raise();
                targetOut.outputWindow.requestActivate();
            }
            screenshotOutput = targetOut;
        }

        function finishScreenshotOverlay() {
            screenshotOutput = null;
            var retId = screenshotReturnWinId;
            screenshotReturnWinId = -1;
            if (retId > 0) {
                var retFrame = findFrameById(retId);
                if (retFrame && !retFrame.closing) {
                    focusWindow(retId);
                }
            }
        }

        function isAnyClientInhibitingIdle() {
            for (var i = 0; i < windowFrames.length; i++) {
                var f = windowFrames[i];
                if (f && !f.closing && !f.minimized && f.inhibitsIdle) {
                    return true;
                }
            }
            return false;
        }

        function restoreOverlayFocus() {
            var retId = overlayReturnWinId;
            overlayReturnWinId = -1;
            if (retId > 0) {
                var retFrame = findFrameById(retId);
                if (retFrame && !retFrame.closing && !retFrame.minimized) {
                    focusWindow(retId);
                    return;
                }
            }
            focusTopWindowOnWorkspace(currentWorkspace);
        }

        function beginOverlayCapture() {
            modDragHeld = false;
            superTapPending = false;
            if (primaryShell && primaryShell.hasOpenPopup) {
                primaryShell.closeAllPopups();
            }
            if (overlayReturnWinId <= 0 && activeWinId > 0) {
                overlayReturnWinId = activeWinId;
            }
            // qmllint disable unqualified
            Backend.clearSeatKeyboardFocus(comp);
            // qmllint enable unqualified
            var prim = primaryOutput();
            if (prim && prim.outputWindow) {
                prim.outputWindow.raise();
                prim.outputWindow.requestActivate();
            }
        }

        function setScreenLocked(lockIt) {
            var next = Boolean(lockIt);
            if (next === screenLocked) return;
            if (next) {
                powerDialogOpen = false;
                notificationsDrawerOpen = false;
                clipboardOpen = false;
                beginOverlayCapture();
                screenLocked = true;
            } else {
                screenLocked = false;
                restoreOverlayFocus();
            }
        }

        function togglePowerDialog() {
            if (screenLocked) return;
            if (!powerDialogOpen) {
                notificationsDrawerOpen = false;
                clipboardOpen = false;
                beginOverlayCapture();
                powerDialogOpen = true;
            } else {
                powerDialogOpen = false;
                restoreOverlayFocus();
            }
        }

        function toggleNotificationsDrawer() {
            if (screenLocked) return;
            if (!notificationsDrawerOpen) {
                powerDialogOpen = false;
                clipboardOpen = false;
                beginOverlayCapture();
                notificationsDrawerOpen = true;
            } else {
                notificationsDrawerOpen = false;
                restoreOverlayFocus();
            }
        }

        function toggleClipboardHistory() {
            if (screenLocked) return;
            if (!clipboardOpen) {
                powerDialogOpen = false;
                notificationsDrawerOpen = false;
                beginOverlayCapture();
                clipboardOpen = true;
            } else {
                clipboardOpen = false;
                restoreOverlayFocus();
            }
        }

        function adjustVolume(action) {
            var args = (action === "mute") ? ["audio", "mute"] : ["audio", "vol", String(action)];
            if (action === "mute") {
                volumeOsdMuted = !volumeOsdMuted;
            } else {
                var step = (String(action).indexOf("-") === 0) ? -5 : 5;
                volumeOsdLevel = Math.max(0, Math.min(150, volumeOsdLevel + step));
                volumeOsdMuted = false;
            }
            volumeOsdVisible = true;
            volumeOsdTimer.restart();
            // qmllint disable unqualified
            Backend.runBackendAsync(args, "audio");
            // qmllint enable unqualified
        }

        function moveActiveWindowToOutput(delta) {
            if (screenLocked) return;
            var f = activeFrame();
            if (!f || f.closing || outputsList.length < 2) return;
            var sorted = outputsList.slice().sort(function(a, b) {
                if (a.globalX !== b.globalX) return a.globalX - b.globalX;
                if (a.globalY !== b.globalY) return a.globalY - b.globalY;
                return a.outputIndex - b.outputIndex;
            });
            var curOut = f.outputContainer || primaryOutput();
            var idx = sorted.indexOf(curOut);
            if (idx < 0) idx = 0;
            var nextOut = sorted[(idx + delta + sorted.length) % sorted.length];
            if (!nextOut || nextOut === curOut) return;

            if (f.clientFullscreen) {
                f.enterFullscreen(nextOut);
            } else {
                var prevZone = f.maximized ? "maximize" : f.snapMode;
                var relX = curOut ? ((f.x - curOut.workArea.x) / Math.max(1, curOut.workArea.width)) : 0.1;
                var relY = curOut ? ((f.y - curOut.workArea.y) / Math.max(1, curOut.workArea.height)) : 0.1;
                var nx = Math.round(nextOut.workArea.x + relX * nextOut.workArea.width);
                var ny = Math.round(nextOut.workArea.y + relY * nextOut.workArea.height);
                transferFrameToOutput(f, nextOut, nx, ny);
                if (prevZone && prevZone !== "") {
                    f.applySnap(prevZone);
                }
            }
            focusWindow(f.winId);
            triggerSpeedLines();
        }
    }

    Timer {
        id: volumeOsdTimer
        interval: 1600
        repeat: false
        onTriggered: wmState.volumeOsdVisible = false
    }

    Connections {
        // qmllint disable unqualified
        target: Backend
        // qmllint enable unqualified
        ignoreUnknownSignals: true

        function onBackendResult(tag, jsonOutput) {
            if (tag === "status" || tag === "audio") {
                if (!jsonOutput || typeof jsonOutput !== "string") return;
                try {
                    var parsed = JSON.parse(jsonOutput.trim());
                    if (parsed && typeof parsed === "object" && parsed.audio_vol !== undefined) {
                        wmState.volumeOsdLevel = Number(parsed.audio_vol);
                        wmState.volumeOsdMuted = Boolean(parsed.audio_muted);
                        if (parsed.audio_label) {
                            wmState.volumeOsdLabel = String(parsed.audio_label);
                        }
                    }
                } catch (e) {
                    // ignore partial telemetry parse
                }
            }
        }

        function onVolumeActionRequested(action) {
            wmState.adjustVolume(action);
        }

        function onX11DisplayChanged() {
            if (Backend.x11Display && Backend.x11Display.length > 0) {
                wmState.syncBgLayoutTiles(false);
            }
        }
    }

    Component {
        id: frameComponent
        AsciiWindowFrame {}
    }

    Instantiator {
        id: outputInstantiator
        model: comp.targetScreens

        onObjectAdded: (index, object) => {
            wmState.registerOutput(object);
        }
        onObjectRemoved: (index, object) => {
            wmState.unregisterOutput(object);
        }

        delegate: WaylandOutput {
            id: waylandOut
            required property int index
            required property var modelData

            readonly property int outputIndex: index
            readonly property bool isPrimary: comp.multiMonitorActive ? (index === comp.primaryScreenIdx) : (index === 0)
            readonly property real globalX: (comp.multiMonitorActive && waylandOut.modelData) ? waylandOut.modelData.virtualX : outputWin.x
            readonly property real globalY: (comp.multiMonitorActive && waylandOut.modelData) ? waylandOut.modelData.virtualY : outputWin.y
            readonly property real outputWidth: outputWin.width
            readonly property real outputHeight: outputWin.height
            readonly property alias workArea: outputRoot.workArea
            readonly property alias gridCanvas: gridCanvas
            readonly property alias windowLayer: windowLayer
            readonly property alias desktopShell: desktopShell
            readonly property alias outputWindow: outputWin
            readonly property alias outputRoot: outputRoot

            compositor: comp
            window: outputWin
            position: Qt.point(waylandOut.globalX, waylandOut.globalY)
            sizeFollowsWindow: false
            scaleFactor: 1
            manufacturer: "ASCII-DE"
            model: (modelData && modelData.name && modelData.name.length > 0) ? modelData.name : ("Output-" + index)

            onGlobalXChanged: wmState.syncXdgOutput(waylandOut)
            onGlobalYChanged: wmState.syncXdgOutput(waylandOut)
            onOutputWidthChanged: wmState.syncXdgOutput(waylandOut)
            onOutputHeightChanged: wmState.syncXdgOutput(waylandOut)

            property Window managedWindow: Window {
                id: outputWin
                screen: waylandOut.modelData ? waylandOut.modelData : undefined
                x: (comp.multiMonitorActive && waylandOut.modelData) ? waylandOut.modelData.virtualX : 0
                y: (comp.multiMonitorActive && waylandOut.modelData) ? waylandOut.modelData.virtualY : 0
                width: {
                    if (comp.multiMonitorActive && waylandOut.modelData) {
                        return Backend.fullscreenMode
                            ? Math.max(640, waylandOut.modelData.width)
                            : Math.min(1280, Math.max(640, waylandOut.modelData.width));
                    }
                    return 1600;
                }
                height: {
                    if (comp.multiMonitorActive && waylandOut.modelData) {
                        return Backend.fullscreenMode
                            ? Math.max(480, waylandOut.modelData.height)
                            : Math.min(800, Math.max(480, waylandOut.modelData.height));
                    }
                    return 960;
                }
                visible: true
                flags: Backend.fullscreenMode ? (Qt.Window | Qt.FramelessWindowHint) : Qt.Window
                visibility: Backend.fullscreenMode ? Window.FullScreen : Window.AutomaticVisibility
                Component.onCompleted: {
                    if (Backend.fullscreenMode && waylandOut.modelData) {
                        outputWin.screen = waylandOut.modelData;
                        outputWin.showFullScreen();
                    }
                }
                title: waylandOut.isPrimary
                    ? "ASCII-DE :: Native Wayland Desktop Environment"
                    : ("ASCII-DE :: Display " + waylandOut.model)
                color: wmState.currentTheme.bg
                onActiveChanged: {
                    if (!active) {
                        wmState.modDragHeld = false;
                        wmState.superTapPending = false;
                    }
                    if (active && waylandOut.isPrimary && desktopShell && desktopShell.startMenuOpen) {
                        desktopShell.focusStartSearch();
                    }
                }

                Item {
                    id: outputRoot
                    anchors.fill: parent
                    focus: waylandOut.isPrimary

                    readonly property bool hasFullscreenFrame: {
                        var _watch = wmState.windowSummaryList.length;
                        for (var i = 0; i < wmState.windowFrames.length; i++) {
                            var f = wmState.windowFrames[i];
                            if (f && !f.closing && !f.minimized && f.clientFullscreen && f.workspace === wmState.currentWorkspace && f.outputContainer === waylandOut) {
                                return _watch >= 0;
                            }
                        }
                        return false;
                    }

                    readonly property rect workArea: waylandOut.isPrimary
                        ? Qt.rect(0, 26, outputWin.width, Math.max(120, outputWin.height - 26 - 28))
                        : Qt.rect(0, 26, outputWin.width, Math.max(120, outputWin.height - 26))

                    readonly property bool hasSplitPair: {
                        var _watch = wmState.windowSummaryList.length;
                        var hasLeft = false;
                        var hasRight = false;
                        for (var i = 0; i < wmState.windowFrames.length; i++) {
                            var f = wmState.windowFrames[i];
                            if (f && !f.minimized && f.workspace === wmState.currentWorkspace && f.outputContainer === waylandOut) {
                                if (f.snapMode === "left") hasLeft = true;
                                if (f.snapMode === "right") hasRight = true;
                            }
                        }
                        return _watch >= 0 && hasLeft && hasRight;
                    }

                    // Track Alt/Meta modifier for KDE-style Alt/Meta+Click drag anywhere & Super tap
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R || event.key === Qt.Key_Meta) {
                            wmState.modDragHeld = true;
                            wmState.superTapPending = true;
                        } else if (event.key === Qt.Key_Alt) {
                            wmState.modDragHeld = true;
                            wmState.superTapPending = false;
                        } else {
                            wmState.superTapPending = false;
                        }
                        wmState.modDragHeld = wmState.modDragHeld || ((event.modifiers & (Qt.AltModifier | Qt.MetaModifier)) !== 0);
                    }

                    Keys.onReleased: (event) => {
                        if (event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R || event.key === Qt.Key_Meta) {
                            if (wmState.superTapPending && wmState.primaryShell && !outputRoot.hasFullscreenFrame && !wmState.screenLocked && !wmState.powerDialogOpen) {
                                wmState.primaryShell.startMenuOpen = !wmState.primaryShell.startMenuOpen;
                            }
                            wmState.superTapPending = false;
                            wmState.modDragHeld = (event.modifiers & Qt.AltModifier) !== 0;
                        } else if (event.key === Qt.Key_Alt) {
                            wmState.modDragHeld = (event.modifiers & Qt.MetaModifier) !== 0;
                            if (wmState.primaryShell && wmState.primaryShell.altTabOpen) {
                                wmState.primaryShell.altTabOpen = false;
                            }
                        }
                    }

                    Shortcut {
                        enabled: waylandOut.isPrimary && !wmState.screenLocked
                        sequence: "Meta+Space"
                        context: Qt.ApplicationShortcut
                        onActivated: if (wmState.primaryShell) wmState.primaryShell.startMenuOpen = !wmState.primaryShell.startMenuOpen
                    }
                    Shortcut {
                        enabled: waylandOut.isPrimary && !wmState.screenLocked
                        sequence: "Alt+Tab"
                        context: Qt.ApplicationShortcut
                        onActivated: wmState.cycleAltTab()
                    }
                    Shortcut {
                        enabled: waylandOut.isPrimary && !wmState.screenLocked
                        sequence: "Meta+Return"
                        context: Qt.ApplicationShortcut
                        onActivated: Backend.launchApp("ascii-de-terminal")
                    }
                    Shortcut {
                        enabled: waylandOut.isPrimary && !wmState.screenLocked
                        sequence: "Meta+B"
                        context: Qt.ApplicationShortcut
                        onActivated: Backend.launchApp("bt-menu")
                    }
                    Shortcut {
                        enabled: waylandOut.isPrimary && !wmState.screenLocked
                        sequences: ["Alt+F4", "Meta+Shift+Q"]
                        context: Qt.ApplicationShortcut
                        onActivated: if (wmState.activeWinId > 0) wmState.closeWindow(wmState.activeWinId)
                    }
                    Shortcut {
                        enabled: waylandOut.isPrimary && !wmState.screenLocked
                        sequence: "Meta+M"
                        context: Qt.ApplicationShortcut
                        onActivated: if (wmState.activeWinId > 0) wmState.toggleMinimizeWindow(wmState.activeWinId)
                    }
                    Shortcut {
                        enabled: waylandOut.isPrimary && !wmState.screenLocked
                        sequence: "Meta+Shift+Left"
                        context: Qt.ApplicationShortcut
                        onActivated: wmState.moveActiveWindowToOutput(-1)
                    }
                    Shortcut {
                        enabled: waylandOut.isPrimary && !wmState.screenLocked
                        sequence: "Meta+Shift+Right"
                        context: Qt.ApplicationShortcut
                        onActivated: wmState.moveActiveWindowToOutput(1)
                    }
                    Shortcut {
                        enabled: waylandOut.isPrimary && !wmState.screenLocked
                        sequence: "Meta+Left"
                        context: Qt.ApplicationShortcut
                        onActivated: wmState.snapActiveWindow("left")
                    }
                    Shortcut {
                        enabled: waylandOut.isPrimary && !wmState.screenLocked
                        sequence: "Meta+Right"
                        context: Qt.ApplicationShortcut
                        onActivated: wmState.snapActiveWindow("right")
                    }
                    Shortcut {
                        enabled: waylandOut.isPrimary && !wmState.screenLocked
                        sequence: "Meta+Up"
                        context: Qt.ApplicationShortcut
                        onActivated: wmState.snapActiveWindow("maximize")
                    }
                    Shortcut {
                        enabled: waylandOut.isPrimary && !wmState.screenLocked
                        sequence: "Meta+Down"
                        context: Qt.ApplicationShortcut
                        onActivated: wmState.snapActiveWindow("restore")
                    }
                    Shortcut {
                        enabled: waylandOut.isPrimary && !wmState.screenLocked
                        sequence: "Meta+Shift+F"
                        context: Qt.ApplicationShortcut
                        onActivated: wmState.toggleFullscreenWindow(wmState.activeWinId)
                    }
                    Shortcut {
                        enabled: waylandOut.isPrimary && !wmState.screenLocked
                        sequence: "Meta+I"
                        context: Qt.ApplicationShortcut
                        onActivated: if (wmState.primaryShell) wmState.primaryShell.iconManagerOpen = !wmState.primaryShell.iconManagerOpen
                    }
                    Shortcut {
                        enabled: waylandOut.isPrimary && !wmState.screenLocked
                        sequences: ["Meta+P", "Meta+D"]
                        context: Qt.ApplicationShortcut
                        onActivated: if (wmState.primaryShell) wmState.primaryShell.displayEditorOpen = !wmState.primaryShell.displayEditorOpen
                    }
                    Shortcut {
                        enabled: waylandOut.isPrimary && !wmState.screenLocked
                        sequence: "Meta+S"
                        context: Qt.ApplicationShortcut
                        onActivated: if (wmState.primaryShell) wmState.primaryShell.settingsOpen = !wmState.primaryShell.settingsOpen
                    }
                    Shortcut {
                        enabled: waylandOut.isPrimary && !wmState.screenLocked
                        sequence: "Meta+T"
                        context: Qt.ApplicationShortcut
                        onActivated: if (wmState.primaryShell) wmState.primaryShell.themeAppOpen = !wmState.primaryShell.themeAppOpen
                    }
                    Shortcut {
                        enabled: waylandOut.isPrimary && !wmState.screenLocked
                        sequences: ["Meta+?", "Meta+Shift+Slash", "Meta+F1"]
                        context: Qt.ApplicationShortcut
                        onActivated: if (wmState.primaryShell) wmState.primaryShell.openKeybindHelp()
                    }
                    Shortcut {
                        enabled: waylandOut.isPrimary && !wmState.screenLocked
                        sequences: ["Print", "Meta+Shift+S"]
                        context: Qt.ApplicationShortcut
                        onActivated: wmState.openScreenshotOverlay()
                    }
                    Shortcut {
                        enabled: waylandOut.isPrimary && !wmState.screenLocked
                        sequence: "Meta+V"
                        context: Qt.ApplicationShortcut
                        onActivated: wmState.toggleClipboardHistory()
                    }
                    Shortcut {
                        enabled: waylandOut.isPrimary && !wmState.screenLocked
                        sequence: "Meta+N"
                        context: Qt.ApplicationShortcut
                        onActivated: wmState.toggleNotificationsDrawer()
                    }
                    Shortcut {
                        enabled: waylandOut.isPrimary && !wmState.screenLocked
                        sequence: "Meta+L"
                        context: Qt.ApplicationShortcut
                        onActivated: wmState.setScreenLocked(true)
                    }
                    Shortcut {
                        enabled: waylandOut.isPrimary && !wmState.screenLocked
                        sequence: "Meta+Alt+Delete"
                        context: Qt.ApplicationShortcut
                        onActivated: wmState.togglePowerDialog()
                    }
                    Shortcut {
                        enabled: waylandOut.isPrimary && !wmState.screenLocked
                        sequence: "Volume Up"
                        context: Qt.ApplicationShortcut
                        onActivated: wmState.adjustVolume("+5%")
                    }
                    Shortcut {
                        enabled: waylandOut.isPrimary && !wmState.screenLocked
                        sequence: "Volume Down"
                        context: Qt.ApplicationShortcut
                        onActivated: wmState.adjustVolume("-5%")
                    }
                    Shortcut {
                        enabled: waylandOut.isPrimary && !wmState.screenLocked
                        sequence: "Volume Mute"
                        context: Qt.ApplicationShortcut
                        onActivated: wmState.adjustVolume("mute")
                    }
                    Shortcut {
                        enabled: waylandOut.isPrimary && !wmState.screenLocked
                        sequence: "Meta+1"
                        context: Qt.ApplicationShortcut
                        onActivated: wmState.switchWorkspace(1)
                    }
                    Shortcut {
                        enabled: waylandOut.isPrimary && !wmState.screenLocked
                        sequence: "Meta+2"
                        context: Qt.ApplicationShortcut
                        onActivated: wmState.switchWorkspace(2)
                    }
                    Shortcut {
                        enabled: waylandOut.isPrimary && !wmState.screenLocked
                        sequence: "Meta+3"
                        context: Qt.ApplicationShortcut
                        onActivated: wmState.switchWorkspace(3)
                    }
                    Shortcut {
                        enabled: waylandOut.isPrimary && !wmState.screenLocked
                        sequence: "Meta+4"
                        context: Qt.ApplicationShortcut
                        onActivated: wmState.switchWorkspace(4)
                    }

                    // Layer 0: Dot-to-Gray-Line ASCII Matrix
                    AsciiGridCanvas {
                        id: gridCanvas
                        anchors.fill: parent
                        z: 0
                        theme: wmState.currentTheme
                        showGridDots: wmState.appSettings.showGridDots !== false
                        gridDensity: wmState.appSettings.gridDensity || "normal"
                        bgStyleOverride: {
                            var outName = (waylandOut.modelData && waylandOut.modelData.name) ? String(waylandOut.modelData.name) : ("Output-" + waylandOut.outputIndex);
                            if (wmState.currentTheme && wmState.currentTheme.monitorBackgrounds && wmState.currentTheme.monitorBackgrounds[outName]) {
                                return String(wmState.currentTheme.monitorBackgrounds[outName]);
                            }
                            return "";
                        }
                        monitorAsciiImage: {
                            var outName = (waylandOut.modelData && waylandOut.modelData.name) ? String(waylandOut.modelData.name) : ("Output-" + waylandOut.outputIndex);
                            if (wmState.appSettings.monitorAsciiImages && wmState.appSettings.monitorAsciiImages[outName]) {
                                return wmState.appSettings.monitorAsciiImages[outName];
                            }
                            return null;
                        }
                        imageTiles: {
                            var outName = (waylandOut.modelData && waylandOut.modelData.name) ? String(waylandOut.modelData.name) : ("Output-" + waylandOut.outputIndex);
                            var tiles = wmState.getEffectiveBgTiles();
                            var result = [];
                            for (var ti = 0; ti < tiles.length; ti++) {
                                var t = tiles[ti];
                                if (t && t.enabled && t.kind === "ascii_image") {
                                    var tMon = t.monitor ? String(t.monitor) : "";
                                    if (tMon === outName || (!tMon && waylandOut.isPrimary)) {
                                        result.push(t);
                                    }
                                }
                            }
                            return result;
                        }
                        showXmasTree: {
                            var pref = (wmState.currentTheme && wmState.currentTheme.xmasMonitor) ? String(wmState.currentTheme.xmasMonitor) : "tallest";
                            var outName = (waylandOut.modelData && waylandOut.modelData.name) ? String(waylandOut.modelData.name) : ("Output-" + waylandOut.outputIndex);
                            if (!pref || pref === "tallest") {
                                return outName === wmState.tallestOutputName;
                            }
                            return outName === pref;
                        }
                    }

                    // Layer 1: Native Wayland Client Windows
                    Item {
                        id: windowLayer
                        anchors.fill: parent
                        z: (outputRoot.hasFullscreenFrame
                            && !wmState.screenLocked
                            && !wmState.powerDialogOpen
                            && !wmState.notificationsDrawerOpen
                            && !wmState.clipboardOpen
                            && (!desktopShell || !desktopShell.hasOpenPopup)) ? 55000 : 100

                        Rectangle {
                            id: crossDragGhost
                            visible: wmState.dragGhostActive && wmState.dragGhostOut === waylandOut && wmState.dragGhostRect.width > 16
                            z: 99999
                            x: wmState.dragGhostRect.x
                            y: wmState.dragGhostRect.y
                            width: wmState.dragGhostRect.width
                            height: wmState.dragGhostRect.height
                            radius: Number(wmState.currentTheme.cornerRadius) || 0
                            color: Qt.rgba(0.08, 0.10, 0.12, 0.82)
                            border.width: 1
                            border.color: wmState.currentTheme.accent

                            // Top title bar preview
                            Rectangle {
                                anchors {
                                    top: parent.top
                                    left: parent.left
                                    right: parent.right
                                }
                                height: 26
                                color: wmState.currentTheme.panelBg || "#14171a"
                                border.width: 1
                                border.color: wmState.currentTheme.accent

                                Text {
                                    anchors.centerIn: parent
                                    width: Math.max(40, parent.width - 24)
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    font.family: wmState.appSettings.fontFamily || "JetBrains Mono"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: wmState.currentTheme.accent
                                    text: "┌─[ ⇄ MOVE TO DISPLAY :: " + wmState.dragGhostTitle + " ]─┐"
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                font.family: wmState.appSettings.fontFamily || "JetBrains Mono"
                                font.pixelSize: 12
                                color: wmState.currentTheme.secondary || "#50fa7b"
                                text: "[ RELEASE TO DROP WINDOW ]"
                            }
                        }
                    }

                    // Interactive Windows 11-style ASCII split-divider ║ between left/right snapped windows
                    Rectangle {
                        id: splitDivider
                        visible: outputRoot.hasSplitPair && (wmState.appSettings.showSplitDivider !== false)
                        z: 20000
                        x: Math.round(outputRoot.workArea.x + outputRoot.workArea.width * wmState.splitRatio) - 4
                        y: outputRoot.workArea.y
                        width: 8
                        height: outputRoot.workArea.height
                        color: splitMouse.containsMouse || splitMouse.pressed ? wmState.currentTheme.panelBg : "transparent"

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 0
                            font.family: "JetBrains Mono"
                            font.pixelSize: 13
                            renderType: Text.NativeRendering
                            color: splitMouse.containsMouse || splitMouse.pressed ? wmState.currentTheme.accent : wmState.currentTheme.muted
                            lineHeightMode: Text.FixedHeight
                            lineHeight: 16
                            text: {
                                var count = Math.max(1, Math.ceil(splitDivider.height / 16) + 2);
                                return Array(count + 1).join("║\n");
                            }
                        }

                        MouseArea {
                            id: splitMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.SplitHCursor
                            onPositionChanged: (mouse) => {
                                if (!pressed) return;
                                var gp = splitMouse.mapToItem(outputRoot, mouse.x, mouse.y);
                                wmState.applySplitRatio(waylandOut, (gp.x - outputRoot.workArea.x) / Math.max(1, outputRoot.workArea.width));
                            }
                            onReleased: {
                                for (var i = 0; i < wmState.windowFrames.length; i++) {
                                    var f = wmState.windowFrames[i];
                                    if (f && !f.minimized && f.workspace === wmState.currentWorkspace && f.outputContainer === waylandOut) {
                                        if (f.snapMode === "left" || f.snapMode === "right") {
                                            var r = f.computeSnapRect(f.snapMode);
                                            f.applyFrameGeometry(r.x, r.y, r.width, r.height, false);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Layer 2: Desktop Icons, Bars, Popups, Icon Manager
                    AsciiDesktopShell {
                        id: desktopShell
                        anchors.fill: parent
                        z: 50000
                        secondaryScreenMode: !waylandOut.isPrimary
                        screenName: waylandOut.model
                        windowList: wmState.windowSummaryList
                        currentWorkspace: wmState.currentWorkspace
                        theme: wmState.currentTheme
                        appSettings: wmState.appSettings
                        // qmllint disable unqualified
                        unreadNotifCount: Backend.notifications ? Backend.notifications.unreadCount : 0
                        clipboardCount: Backend.clipboardHistory ? Backend.clipboardHistory.entries.length : 0
                        // qmllint enable unqualified
                        notificationsOpen: wmState.notificationsDrawerOpen
                        clipboardOpen: wmState.clipboardOpen
                        onSwitchWorkspace: (ws) => wmState.switchWorkspace(ws)
                        onRequestSpawnApp: (cmd) => Backend.launchApp(cmd)
                        onRequestCascadeWindows: () => wmState.cascadeWindows()
                        onRequestTileSideBySide: () => wmState.tileSideBySide()
                        onRequestScreenshot: wmState.openScreenshotOverlay()
                        onRequestToggleNotifications: wmState.toggleNotificationsDrawer()
                        onRequestToggleClipboard: wmState.toggleClipboardHistory()
                        onRequestPowerDialog: wmState.togglePowerDialog()
                        onRequestLockScreen: wmState.setScreenLocked(true)
                        onThemeUpdated: (newTheme) => wmState.applyTheme(newTheme)
                        onSettingsUpdated: (newSettings) => wmState.applySettings(newSettings)
                        onDisplaysUpdated: (mons) => wmState.syncPreferredPrimaryFromMonitors(mons)
                        availableMonitors: wmState.availableMonitors
                        onHasOpenPopupChanged: {
                            wmState.modDragHeld = false;
                            wmState.superTapPending = false;
                            if (!waylandOut.isPrimary) {
                                return;
                            }
                            if (desktopShell.hasOpenPopup) {
                                wmState.popupReturnWinId = wmState.activeWinId;
                                Backend.clearSeatKeyboardFocus(comp);
                                if (outputWin) {
                                    outputWin.raise();
                                    outputWin.requestActivate();
                                }
                                Qt.callLater(function() {
                                    if (desktopShell.startMenuOpen) {
                                        desktopShell.focusStartSearch();
                                    } else if (desktopShell.keybindHelpOpen) {
                                        desktopShell.focusKeybindHelp();
                                    } else if (desktopShell.settingsOpen) {
                                        desktopShell.focusSettings();
                                    } else if (desktopShell.themeAppOpen) {
                                        desktopShell.focusThemeApp();
                                    } else if (desktopShell.displayEditorOpen) {
                                        desktopShell.focusDisplayEditor();
                                    }
                                });
                            } else {
                                var retId = wmState.popupReturnWinId;
                                wmState.popupReturnWinId = -1;
                                if (retId > 0 && wmState.activeWinId === retId) {
                                    var retFrame = wmState.findFrameById(retId);
                                    if (retFrame && !retFrame.closing) {
                                        wmState.focusWindow(retId);
                                    }
                                }
                            }
                        }
                    }

                    // Layer 2.5: ASCII/SNAPTIC Screenshot Capture Overlay (above fullscreen windows & panels)
                    property var pendingShot: null

                    Timer {
                        id: shotDelayTimer
                        interval: 40
                        repeat: false
                        onTriggered: {
                            var req = outputRoot.pendingShot;
                            outputRoot.pendingShot = null;
                            if (!req) return;
                            var res = null;
                            // qmllint disable unqualified
                            if (req.kind === "region") {
                                res = Backend.captureWindow(waylandOut.outputWindow, req.rx, req.ry, req.rw, req.rh, req.save, req.copy);
                            } else if (req.kind === "monitor") {
                                res = Backend.captureWindow(waylandOut.outputWindow, 0, 0, 0, 0, req.save, req.copy);
                            } else if (req.kind === "all") {
                                var recs = [];
                                for (var i = 0; i < wmState.outputsList.length; i++) {
                                    var o = wmState.outputsList[i];
                                    if (o && o.outputWindow) {
                                        recs.push({
                                            window: o.outputWindow,
                                            x: Math.round(o.globalX),
                                            y: Math.round(o.globalY),
                                            width: Math.round(o.outputWidth),
                                            height: Math.round(o.outputHeight)
                                        });
                                    }
                                }
                                res = Backend.captureAllOutputs(recs, req.save, req.copy);
                            }
                            // qmllint enable unqualified
                            if (res) {
                                screenshotOverlay.showCaptureFeedback(res);
                                // qmllint disable unqualified
                                if (Backend.notifications && (res.ok || !res.cancelled)) {
                                    Backend.notifications.pushLocalNotification(
                                        "Screenshot",
                                        res.ok ? "Screenshot Saved" : "Screenshot Failed",
                                        res.path ? String(res.path) : String(res.message || res.error || ""),
                                        res.ok ? 1 : 2,
                                        4500
                                    );
                                }
                                // qmllint enable unqualified
                            }
                            wmState.finishScreenshotOverlay();
                        }
                    }

                    AsciiScreenshotOverlay {
                        id: screenshotOverlay
                        anchors.fill: parent
                        z: 58000
                        active: wmState.screenshotOutput === waylandOut
                        theme: wmState.currentTheme
                        monoFamily: wmState.appSettings.fontFamily || wmState.currentTheme.fontFamily || "JetBrains Mono"
                        monitorCount: wmState.outputsList.length
                        onRequestCaptureRegion: (rx, ry, rw, rh, save, copy) => {
                            wmState.screenshotOutput = null;
                            outputRoot.pendingShot = { kind: "region", rx: rx, ry: ry, rw: rw, rh: rh, save: save, copy: copy };
                            shotDelayTimer.restart();
                        }
                        onRequestCaptureMonitor: (save, copy) => {
                            wmState.screenshotOutput = null;
                            outputRoot.pendingShot = { kind: "monitor", save: save, copy: copy };
                            shotDelayTimer.restart();
                        }
                        onRequestCaptureAll: (save, copy) => {
                            wmState.screenshotOutput = null;
                            outputRoot.pendingShot = { kind: "all", save: save, copy: copy };
                            shotDelayTimer.restart();
                        }
                        onCancelled: wmState.finishScreenshotOverlay()
                    }

                    // Layer 2.7: Notifications Toast Stack, Drawer & Clipboard History (primary output)
                    AsciiNotificationsAndClip {
                        id: notifAndClipOverlay
                        anchors.fill: parent
                        z: 62000
                        visible: waylandOut.isPrimary && !wmState.screenLocked
                        theme: wmState.currentTheme
                        monoFamily: wmState.appSettings.fontFamily || wmState.currentTheme.fontFamily || "JetBrains Mono"
                        notificationsDrawerOpen: waylandOut.isPrimary && wmState.notificationsDrawerOpen
                        clipboardOpen: waylandOut.isPrimary && wmState.clipboardOpen
                        // qmllint disable unqualified
                        activeToasts: Backend.notifications ? Backend.notifications.activeToasts : []
                        history: Backend.notifications ? Backend.notifications.history : []
                        unreadCount: Backend.notifications ? Backend.notifications.unreadCount : 0
                        clipboardEntries: Backend.clipboardHistory ? Backend.clipboardHistory.entries : []
                        onDismissToastRequested: (id) => { if (Backend.notifications) Backend.notifications.dismissToast(id); }
                        onRemoveHistoryRequested: (id) => { if (Backend.notifications) Backend.notifications.removeHistoryItem(id); }
                        onClearHistoryRequested: { if (Backend.notifications) Backend.notifications.clearHistory(); }
                        onInvokeActionRequested: (id, actionKey) => { if (Backend.notifications) Backend.notifications.invokeAction(id, actionKey); }
                        onMarkAllReadRequested: { if (Backend.notifications) Backend.notifications.markAllRead(); }
                        onCopyClipboardRequested: (idx) => { if (Backend.clipboardHistory) Backend.clipboardHistory.copyEntry(idx); }
                        onRemoveClipboardRequested: (idx) => { if (Backend.clipboardHistory) Backend.clipboardHistory.removeEntry(idx); }
                        onClearClipboardRequested: { if (Backend.clipboardHistory) Backend.clipboardHistory.clear(); }
                        // qmllint enable unqualified
                        onCloseRequested: {
                            wmState.notificationsDrawerOpen = false;
                            wmState.clipboardOpen = false;
                            wmState.restoreOverlayFocus();
                        }
                    }

                    // Layer 2.8: Volume OSD Pill (renders cleanly over fullscreen windows too)
                    Rectangle {
                        id: volumeOsdPill
                        visible: wmState.volumeOsdVisible && !wmState.screenLocked
                        z: 65000
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 44
                        width: Math.max(270, volOsdText.implicitWidth + 28)
                        height: 34
                        radius: Number(wmState.currentTheme.cornerRadius) || 0
                        color: wmState.currentTheme.panelBg || "#14171a"
                        border.width: Math.max(1, Number(wmState.currentTheme.borderWidth) || 1)
                        border.color: wmState.volumeOsdMuted ? (wmState.currentTheme.danger || "#ff5555") : (wmState.currentTheme.accent || "#ffb000")

                        Text {
                            id: volOsdText
                            anchors.centerIn: parent
                            font.family: wmState.appSettings.fontFamily || wmState.currentTheme.fontFamily || "JetBrains Mono"
                            font.pixelSize: 12
                            font.bold: true
                            color: wmState.volumeOsdMuted ? (wmState.currentTheme.danger || "#ff5555") : (wmState.currentTheme.fg || "#e6dcc8")
                            text: {
                                var pct = Math.max(0, Math.min(150, wmState.volumeOsdLevel));
                                var filled = Math.round((Math.min(100, pct) / 100.0) * 12);
                                var bar = "█".repeat(filled) + "░".repeat(12 - filled);
                                return wmState.volumeOsdMuted
                                    ? ("[ 🔇 MUTED :: " + bar + " ]")
                                    : ("[ 🔊 VOL " + pct + "% :: " + bar + " ]");
                            }
                        }
                    }

                    // Layer 2.9: Multi-Monitor Lock Screen & Power/Session Dialog (ALL outputs)
                    AsciiPowerAndLock {
                        id: powerAndLockOverlay
                        anchors.fill: parent
                        z: 70000
                        locked: wmState.screenLocked
                        powerDialogOpen: wmState.powerDialogOpen
                        isPrimary: waylandOut.isPrimary
                        screenName: waylandOut.model
                        theme: wmState.currentTheme
                        clock24h: wmState.appSettings.clock24h !== false
                        clockShowSeconds: wmState.appSettings.clockShowSeconds !== false
                        onLockRequested: wmState.setScreenLocked(true)
                        onUnlocked: wmState.setScreenLocked(false)
                        onClosePowerDialog: {
                            wmState.powerDialogOpen = false;
                            wmState.restoreOverlayFocus();
                        }
                        onLogoutRequested: {
                            // qmllint disable unqualified
                            Backend.quitCompositor();
                            // qmllint enable unqualified
                        }
                    }

                    // Layer 3: GPU-accelerated SNAPTIC Radial Speed-Line Warp Overlay
                    function triggerSpeedLines() {
                        speedLinesLayer.speedProgress = 0.0;
                        speedLinesAnim.restart();
                    }

                    Item {
                        id: speedLinesLayer
                        anchors.fill: parent
                        z: 60000
                        opacity: 0
                        visible: opacity > 0
                        clip: true
                        property real speedProgress: 0.0

                        ParallelAnimation {
                            id: speedLinesAnim
                            NumberAnimation {
                                target: speedLinesLayer
                                property: "speedProgress"
                                from: 0.0
                                to: 1.0
                                duration: 220
                                easing.type: Easing.OutCubic
                            }
                            SequentialAnimation {
                                PropertyAction { target: speedLinesLayer; property: "opacity"; value: 0.96 }
                                PauseAnimation { duration: 60 }
                                NumberAnimation {
                                    target: speedLinesLayer
                                    property: "opacity"
                                    from: 0.96
                                    to: 0.0
                                    duration: 160
                                    easing.type: Easing.InQuad
                                }
                            }
                        }

                        Repeater {
                            model: 36
                            delegate: Item {
                                id: rayContainer
                                required property int index
                                readonly property real deg: (index / 36.0) * 360.0 + ((index % 3) * 1.4) + speedLinesLayer.speedProgress * 2.5
                                readonly property real outerR: Math.hypot(speedLinesLayer.width * 0.5, speedLinesLayer.height * 0.5) * 1.15
                                readonly property real innerR: Math.min(speedLinesLayer.width, speedLinesLayer.height) * (0.24 + speedLinesLayer.speedProgress * 0.14) + ((index % 4) * 26)
                                x: speedLinesLayer.width * 0.5
                                y: speedLinesLayer.height * 0.5
                                width: 0
                                height: 0
                                rotation: deg

                                Rectangle {
                                    x: rayContainer.innerR
                                    y: -height * 0.5
                                    width: Math.max(40, rayContainer.outerR - rayContainer.innerR)
                                    height: ((rayContainer.index % 3 === 0) ? 9 : 4.5) * (1.0 - speedLinesLayer.speedProgress * 0.45)
                                    radius: height * 0.5
                                    color: (rayContainer.index % 2 === 0)
                                        ? "#FFFFFF"
                                        : ((wmState.currentTheme && wmState.currentTheme.secondary) ? wmState.currentTheme.secondary : "#45C2FF")
                                    opacity: (rayContainer.index % 2 === 0) ? 0.92 : 0.78
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
