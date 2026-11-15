#include "DesktopBridge.h"
#include <dlfcn.h>

#include <csignal>
#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QEvent>
#include <QFile>
#include <QFileInfo>
#include <QKeyEvent>
#include <QPoint>
#include <QPointer>
#include <QProcessEnvironment>
#include <QScreen>
#include <QSize>
#include <QStandardPaths>
#include <QTimer>
#include <QSet>
#include <QWindow>
#include <QtQuick/QQuickItem>
#include <QtWaylandCompositor/QWaylandCompositor>
#include <QtWaylandCompositor/QWaylandOutput>
#include <QtWaylandCompositor/QWaylandOutputMode>
#include <QtWaylandCompositor/QWaylandQuickItem>
#include <QtWaylandCompositor/QWaylandQuickShellSurfaceItem>
#include <QtWaylandCompositor/QWaylandSeat>
#include <QtWaylandCompositor/QWaylandSurface>
#include <QtWaylandCompositor/QWaylandXdgOutputManagerV1>
#include <QtWaylandCompositor/QWaylandXdgOutputV1>

namespace {
constexpr int kBackendSyncTimeoutMs = 5000;
constexpr int kXWaylandMinDisplay = 14;
constexpr int kXWaylandMaxDisplay = 20;
} // namespace

DesktopBridge::DesktopBridge(QObject *parent)
    : QObject(parent)
{
    m_screenshotHelper.setWaylandSocket(m_waylandSocket);
    m_clipboardHistory.setWaylandSocket(m_waylandSocket);
    if (QCoreApplication *app = QCoreApplication::instance()) {
        app->installEventFilter(this);
    }
}

DesktopBridge::~DesktopBridge()
{
    if (QCoreApplication *app = QCoreApplication::instance()) {
        app->removeEventFilter(this);
    }
    stopAllBgTiles();
    stopXWayland();
}

bool DesktopBridge::eventFilter(QObject *watched, QEvent *event)
{
    if (!event) {
        return QObject::eventFilter(watched, event);
    }

    const QEvent::Type t = event->type();
    if (t == QEvent::ShortcutOverride || t == QEvent::KeyPress || t == QEvent::KeyRelease) {
        auto *ke = static_cast<QKeyEvent *>(event);
        const int key = ke->key();
        const bool isMediaOrVolKey = (key == Qt::Key_VolumeUp
                                      || key == Qt::Key_VolumeDown
                                      || key == Qt::Key_VolumeMute
                                      || key == Qt::Key_MicMute
                                      || key == Qt::Key_MediaPlay
                                      || key == Qt::Key_MediaTogglePlayPause
                                      || key == Qt::Key_MediaPause
                                      || key == Qt::Key_MediaNext
                                      || key == Qt::Key_MediaPrevious
                                      || key == Qt::Key_MediaStop
                                      || key == Qt::Key_MonBrightnessUp
                                      || key == Qt::Key_MonBrightnessDown);
        if (isMediaOrVolKey) {
            if (t == QEvent::KeyPress) {
                switch (key) {
                case Qt::Key_VolumeUp:
                    emit volumeActionRequested(QStringLiteral("+5%"));
                    break;
                case Qt::Key_VolumeDown:
                    emit volumeActionRequested(QStringLiteral("-5%"));
                    break;
                case Qt::Key_VolumeMute:
                    if (!ke->isAutoRepeat()) {
                        emit volumeActionRequested(QStringLiteral("mute"));
                    }
                    break;
                case Qt::Key_MicMute:
                    if (!ke->isAutoRepeat()) {
                        QProcess::startDetached(QStringLiteral("pactl"),
                                                {QStringLiteral("set-source-mute"),
                                                 QStringLiteral("@DEFAULT_SOURCE@"),
                                                 QStringLiteral("toggle")});
                    }
                    break;
                case Qt::Key_MediaPlay:
                case Qt::Key_MediaTogglePlayPause:
                    if (!ke->isAutoRepeat()) {
                        QProcess::startDetached(QStringLiteral("playerctl"), {QStringLiteral("play-pause")});
                    }
                    break;
                case Qt::Key_MediaPause:
                    if (!ke->isAutoRepeat()) {
                        QProcess::startDetached(QStringLiteral("playerctl"), {QStringLiteral("pause")});
                    }
                    break;
                case Qt::Key_MediaNext:
                    if (!ke->isAutoRepeat()) {
                        QProcess::startDetached(QStringLiteral("playerctl"), {QStringLiteral("next")});
                    }
                    break;
                case Qt::Key_MediaPrevious:
                    if (!ke->isAutoRepeat()) {
                        QProcess::startDetached(QStringLiteral("playerctl"), {QStringLiteral("previous")});
                    }
                    break;
                case Qt::Key_MediaStop:
                    if (!ke->isAutoRepeat()) {
                        QProcess::startDetached(QStringLiteral("playerctl"), {QStringLiteral("stop")});
                    }
                    break;
                case Qt::Key_MonBrightnessUp:
                    QProcess::startDetached(QStringLiteral("brightnessctl"), {QStringLiteral("set"), QStringLiteral("+5%")});
                    break;
                case Qt::Key_MonBrightnessDown:
                    QProcess::startDetached(QStringLiteral("brightnessctl"), {QStringLiteral("set"), QStringLiteral("5%-")});
                    break;
                default:
                    break;
                }
            }
            ke->accept();
            return true;
        }
    }

    return QObject::eventFilter(watched, event);
}

QString DesktopBridge::waylandSocket() const
{
    return m_waylandSocket;
}

void DesktopBridge::setWaylandSocket(const QString &socket)
{
    if (m_waylandSocket == socket) {
        return;
    }
    m_waylandSocket = socket;
    m_screenshotHelper.setWaylandSocket(m_waylandSocket);
    m_clipboardHistory.setWaylandSocket(m_waylandSocket);
    emit waylandSocketChanged();
}

QObject *DesktopBridge::notifications()
{
    return &m_notifications;
}

QObject *DesktopBridge::clipboardHistory()
{
    return &m_clipboardHistory;
}

QString DesktopBridge::x11Display() const
{
    return m_x11Display;
}

bool DesktopBridge::allMonitors() const
{
    return m_allMonitors;
}

void DesktopBridge::setAllMonitors(bool enabled)
{
    m_allMonitors = enabled;
}

bool DesktopBridge::startFullscreen() const
{
    return m_startFullscreen;
}

void DesktopBridge::setStartFullscreen(bool enabled)
{
    m_startFullscreen = enabled;
}

QString DesktopBridge::backendExecutablePath() const
{
    const QString siblingBin = QCoreApplication::applicationDirPath() + QStringLiteral("/ascii-de-backend");
    if (QFileInfo::exists(siblingBin) && QFileInfo(siblingBin).isExecutable()) {
        return siblingBin;
    }
    const QString inPath = QStandardPaths::findExecutable(QStringLiteral("ascii-de-backend"));
    if (!inPath.isEmpty()) {
        return inPath;
    }
    const QString homeBin = QDir::homePath() + QStringLiteral("/bin/ascii-de-backend");
    return homeBin;
}

QString DesktopBridge::runBackend(const QStringList &args)
{
    const QString exe = backendExecutablePath();
    if (!QFileInfo::exists(exe)) {
        qWarning("ascii-de-compositor: backend executable not found: %s", qPrintable(exe));
        return QStringLiteral("{}");
    }

    QProcess proc;
    proc.start(exe, args);
    if (!proc.waitForStarted(2000)) {
        qWarning("ascii-de-compositor: failed to start backend (%s): %s",
                 qPrintable(args.join(QLatin1Char(' '))),
                 qPrintable(proc.errorString()));
        return QStringLiteral("{}");
    }
    if (!proc.waitForFinished(kBackendSyncTimeoutMs)) {
        proc.kill();
        proc.waitForFinished(1000);
        qWarning("ascii-de-compositor: backend timed out (%s)", qPrintable(args.join(QLatin1Char(' '))));
        return QStringLiteral("{}");
    }

    const QByteArray out = proc.readAllStandardOutput().trimmed();
    if (out.isEmpty()) {
        return QStringLiteral("{}");
    }
    return QString::fromUtf8(out);
}

void DesktopBridge::runBackendAsync(const QStringList &args, const QString &tag)
{
    startBackendProcessAsync(args, tag);
}

void DesktopBridge::verifyPasswordAsync(const QString &password, const QString &tag)
{
    const QByteArray payload = (password + QLatin1Char('\n')).toUtf8();
    startBackendProcessAsync({QStringLiteral("power"), QStringLiteral("verify")}, tag, payload);
}

void DesktopBridge::startBackendProcessAsync(const QStringList &args, const QString &tag, const QByteArray &stdinData)
{
    if (tag == QStringLiteral("status")) {
        if (m_activeStatusProcess && m_activeStatusProcess->state() != QProcess::NotRunning) {
            return; // Skip duplicate concurrent status check to prevent process stacking
        }
    }

    const QString exe = backendExecutablePath();
    if (!QFileInfo::exists(exe)) {
        qWarning("ascii-de-compositor: backend executable not found: %s", qPrintable(exe));
        emit backendResult(tag, QStringLiteral("{}"));
        return;
    }

    auto *proc = new QProcess(this);
    if (tag == QStringLiteral("status")) {
        m_activeStatusProcess = proc;
    }
    if (!stdinData.isEmpty()) {
        connect(proc, &QProcess::started, this, [proc, stdinData]() {
            proc->write(stdinData);
            proc->closeWriteChannel();
        });
    }
    connect(proc, &QProcess::finished, this, [this, proc, tag](int exitCode, QProcess::ExitStatus exitStatus) {
        Q_UNUSED(exitCode);
        Q_UNUSED(exitStatus);
        const QByteArray out = proc->readAllStandardOutput().trimmed();
        const QString json = out.isEmpty() ? QStringLiteral("{}") : QString::fromUtf8(out);
        proc->deleteLater();
        emit backendResult(tag, json);
    });
    connect(proc, &QProcess::errorOccurred, this, [this, proc, tag](QProcess::ProcessError error) {
        qWarning("ascii-de-compositor: async backend error (%d): %s",
                 static_cast<int>(error),
                 qPrintable(proc->errorString()));
        if (proc->state() == QProcess::NotRunning) {
            proc->deleteLater();
            emit backendResult(tag, QStringLiteral("{}"));
        }
    });

    proc->start(exe, args);
}

void DesktopBridge::launchApp(const QString &cmd)
{
    const QString trimmed = cmd.trimmed();
    if (trimmed.isEmpty()) {
        return;
    }

    QString effectiveCmd = trimmed;
    const bool isKitty = (trimmed == QStringLiteral("kitty")
                          || trimmed.startsWith(QStringLiteral("kitty "))
                          || trimmed.contains(QStringLiteral("/kitty")));
    const bool isFoot = (trimmed == QStringLiteral("foot")
                         || (trimmed.startsWith(QStringLiteral("foot "))
                             && !trimmed.contains(QStringLiteral("--server")))
                         || trimmed == QStringLiteral("footclient")
                         || trimmed.startsWith(QStringLiteral("footclient ")));
    if (isKitty || isFoot) {
        QString termWrapper = QCoreApplication::applicationDirPath() + QStringLiteral("/ascii-de-terminal");
        if (!QFileInfo::exists(termWrapper) || !QFileInfo(termWrapper).isExecutable()) {
            termWrapper = QStandardPaths::findExecutable(QStringLiteral("ascii-de-terminal"));
        }
        if (termWrapper.isEmpty() || !QFileInfo::exists(termWrapper)) {
            const QString homeTerm = QDir::homePath() + QStringLiteral("/bin/ascii-de-terminal");
            if (QFileInfo::exists(homeTerm) && QFileInfo(homeTerm).isExecutable()) {
                termWrapper = homeTerm;
            } else {
                termWrapper.clear();
            }
        }
        if (!termWrapper.isEmpty()) {
            const int spaceIdx = trimmed.indexOf(QLatin1Char(' '));
            if (spaceIdx == -1) {
                effectiveCmd = QStringLiteral("'%1'").arg(termWrapper);
            } else {
                effectiveCmd = QStringLiteral("'%1'%2").arg(termWrapper, trimmed.mid(spaceIdx));
            }
        }
    }
    const bool isDiscord = (trimmed == QStringLiteral("discord")
                            || trimmed.startsWith(QStringLiteral("discord "))
                            || trimmed.contains(QStringLiteral("/discord")));
    const bool isChromium = (trimmed.contains(QStringLiteral("google-chrome"))
                             || trimmed.contains(QStringLiteral("chromium"))
                             || trimmed.contains(QStringLiteral("brave"))
                             || trimmed.contains(QStringLiteral("microsoft-edge")));
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    const bool forceX11 = !m_x11Display.isEmpty() && isDiscord;
    if (forceX11) {
        // Prevent fallback to underlying host DRM session socket (wayland-0) by explicitly overriding WAYLAND_DISPLAY
        env.insert(QStringLiteral("WAYLAND_DISPLAY"), QString());
        env.insert(QStringLiteral("GDK_BACKEND"), QStringLiteral("x11"));
        env.insert(QStringLiteral("QT_QPA_PLATFORM"), QStringLiteral("xcb"));
        env.insert(QStringLiteral("ELECTRON_OZONE_PLATFORM_HINT"), QStringLiteral("x11"));
    } else if (!m_waylandSocket.isEmpty()) {
        env.insert(QStringLiteral("WAYLAND_DISPLAY"), m_waylandSocket);
        env.insert(QStringLiteral("GDK_BACKEND"), QStringLiteral("wayland,x11"));
        env.insert(QStringLiteral("QT_QPA_PLATFORM"), QStringLiteral("wayland;xcb"));
        env.insert(QStringLiteral("ELECTRON_OZONE_PLATFORM_HINT"), QStringLiteral("auto"));
    }
    if (!m_x11Display.isEmpty()) {
        env.insert(QStringLiteral("DISPLAY"), m_x11Display);
    } else {
        env.remove(QStringLiteral("DISPLAY"));
    }
    if (isDiscord && !m_x11Display.isEmpty()) {
        while (effectiveCmd.endsWith(QStringLiteral(" --"))) {
            effectiveCmd.chop(3);
            effectiveCmd = effectiveCmd.trimmed();
        }
        if (effectiveCmd.endsWith(QStringLiteral(" --url"))) {
            effectiveCmd.chop(6);
            effectiveCmd = effectiveCmd.trimmed();
        }
        effectiveCmd.replace(QStringLiteral(" --url -- "), QStringLiteral(" "));
        if (!effectiveCmd.contains(QStringLiteral("--ozone-platform"))) {
            const QString discordFlags = QStringLiteral("--ozone-platform=x11 --ignore-gpu-blocklist");
            const int dashDashIdx = effectiveCmd.indexOf(QStringLiteral(" -- "));
            if (dashDashIdx != -1) {
                effectiveCmd.insert(dashDashIdx, QStringLiteral(" ") + discordFlags);
            } else {
                effectiveCmd += QStringLiteral(" ") + discordFlags;
            }
        }
    } else if (isChromium && !forceX11) {
        while (effectiveCmd.endsWith(QStringLiteral(" --"))) {
            effectiveCmd.chop(3);
            effectiveCmd = effectiveCmd.trimmed();
        }
        if (!effectiveCmd.contains(QStringLiteral("--ozone-platform"))) {
            // Enable native Wayland and window decorations negotiation (zxdg_decoration_manager_v1)
            // so CSD drop shadows are disabled and server-side ASCII frames are used without clipping.
            // Also disable Vulkan to prevent wayland_surface_factory incompatibility warnings on Linux.
            const QString chromeFlags = QStringLiteral("--ozone-platform=wayland --enable-features=WaylandWindowDecorations --disable-features=Vulkan");
            const int dashDashIdx = effectiveCmd.indexOf(QStringLiteral(" -- "));
            if (dashDashIdx != -1) {
                effectiveCmd.insert(dashDashIdx, QStringLiteral(" ") + chromeFlags);
            } else {
                effectiveCmd += QStringLiteral(" ") + chromeFlags;
            }
        }
    }

    const QString xdgThemeDir = QDir::homePath() + QStringLiteral("/.config/ascii-de/xdg-config");
    if (QFileInfo::exists(xdgThemeDir) && QFileInfo(xdgThemeDir).isDir()) {
        env.insert(QStringLiteral("XDG_CONFIG_HOME"), xdgThemeDir);
        env.insert(QStringLiteral("XDG_CONFIG_DIRS"), QStringLiteral("/etc/xdg"));

        const QString userChromeFlags = QDir::homePath() + QStringLiteral("/.config/chrome-flags.conf");
        const QString deChromeFlags = xdgThemeDir + QStringLiteral("/chrome-flags.conf");
        if (QFileInfo::exists(userChromeFlags) && !QFileInfo::exists(deChromeFlags)) {
            QFile::link(userChromeFlags, deChromeFlags);
        }
    }

    if (env.value(QStringLiteral("QT_QPA_PLATFORMTHEME")).isEmpty()) {
        env.insert(QStringLiteral("QT_QPA_PLATFORMTHEME"), QStringLiteral("kde"));
    }

    const QString kittyConf = xdgThemeDir + QStringLiteral("/ascii-de-kitty.conf");
    if (QFileInfo::exists(kittyConf)) {
        if (effectiveCmd == QStringLiteral("kitty")) {
            effectiveCmd = QStringLiteral("kitty -o include='%1'").arg(kittyConf);
        } else if (effectiveCmd.startsWith(QStringLiteral("kitty "))
                   && !effectiveCmd.contains(QStringLiteral("--config"))
                   && !effectiveCmd.contains(QStringLiteral(" -c "))) {
            effectiveCmd = QStringLiteral("kitty -o include='%1' %2")
                               .arg(kittyConf, effectiveCmd.mid(6));
        }
    }

    if (!forceX11) {
        env.insert(QStringLiteral("QT_QPA_PLATFORM"), QStringLiteral("wayland;xcb"));
        env.insert(QStringLiteral("GDK_BACKEND"), QStringLiteral("wayland,x11"));
        env.insert(QStringLiteral("MOZ_ENABLE_WAYLAND"), QStringLiteral("1"));
    }
    if (!env.contains(QStringLiteral("SDL_VIDEODRIVER"))) {
        if (!effectiveCmd.contains(QStringLiteral("steam"))) {
            env.insert(QStringLiteral("SDL_VIDEODRIVER"), QStringLiteral("wayland,x11"));
        }
    }
    env.insert(QStringLiteral("ASCII_DE"), QStringLiteral("1"));

    env.remove(QStringLiteral("HYPRLAND_INSTANCE_SIGNATURE"));
    env.remove(QStringLiteral("SWAYSOCK"));

    QProcess proc;
    proc.setProgram(QStringLiteral("/bin/sh"));
    proc.setArguments({QStringLiteral("-c"), effectiveCmd});
    proc.setWorkingDirectory(QDir::homePath());
    proc.setProcessEnvironment(env);

    qint64 pid = 0;
    if (!proc.startDetached(&pid)) {
        qWarning("ascii-de-compositor: failed to launch '%s': %s",
                 qPrintable(trimmed),
                 qPrintable(proc.errorString()));
    }
}

void DesktopBridge::launchBgTerminal(const QString &cmd, int widthPx, int heightPx)
{
    launchBgTile(QStringLiteral("legacy"), cmd, widthPx, heightPx, 11, 0.0, QStringLiteral("#0d0f10"), QStringLiteral("#e6dcc8"), QStringLiteral("#ffb000"));
}

qint64 DesktopBridge::launchBgTile(const QString &tileId, const QString &cmd, int widthPx, int heightPx, int fontSizePx, double opacity, const QString &bgHex, const QString &fgHex, const QString &accentHex)
{
    const QString tid = tileId.trimmed().isEmpty() ? QStringLiteral("1") : tileId.trimmed();
    stopBgTile(tid);

    const QString trimmed = cmd.trimmed().isEmpty() ? QStringLiteral("asciiquarium") : cmd.trimmed();
    const int w = qBound(120, widthPx, 3840);
    const int h = qBound(80, heightPx, 2160);
    const int fs = (fontSizePx >= 8 && fontSizePx <= 24) ? fontSizePx : 11;
    const double op = qBound(0.0, opacity, 1.0);

    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    const QString xdgThemeDir = QDir::homePath() + QStringLiteral("/.config/ascii-de/xdg-config");
    if (QFileInfo::exists(xdgThemeDir) && QFileInfo(xdgThemeDir).isDir()) {
        env.insert(QStringLiteral("XDG_CONFIG_HOME"), xdgThemeDir);
        env.insert(QStringLiteral("XDG_CONFIG_DIRS"), QStringLiteral("/etc/xdg"));
    }
    env.insert(QStringLiteral("ASCII_DE"), QStringLiteral("1"));
    env.remove(QStringLiteral("HYPRLAND_INSTANCE_SIGNATURE"));
    env.remove(QStringLiteral("SWAYSOCK"));

    const QString appId = QStringLiteral("ascii-de-bg-tile-%1").arg(tid);

    const QString alacrittyBin = QStandardPaths::findExecutable(QStringLiteral("alacritty"));
    const bool useAlacritty = !alacrittyBin.isEmpty() && !m_waylandSocket.isEmpty();

    QString program;
    QStringList args;

    if (useAlacritty) {
        program = alacrittyBin;
        env.insert(QStringLiteral("WAYLAND_DISPLAY"), m_waylandSocket);
        env.remove(QStringLiteral("DISPLAY"));

        args << QStringLiteral("--class") << appId
             << QStringLiteral("-T") << appId
             << QStringLiteral("-o") << QStringLiteral("window.decorations=\"None\"")
             << QStringLiteral("-o") << QStringLiteral("window.padding.x=4")
             << QStringLiteral("-o") << QStringLiteral("window.padding.y=4")
             << QStringLiteral("-o") << QStringLiteral("window.opacity=%1").arg(QString::number(op, 'f', 2))
             << QStringLiteral("-o") << QStringLiteral("font.size=%1").arg(fs)
             << QStringLiteral("-o") << QStringLiteral("font.normal.family=\"JetBrains Mono\"");

        if (!bgHex.isEmpty()) {
            args << QStringLiteral("-o") << QStringLiteral("colors.primary.background=\"%1\"").arg(bgHex);
        }
        if (!fgHex.isEmpty()) {
            args << QStringLiteral("-o") << QStringLiteral("colors.primary.foreground=\"%1\"").arg(fgHex);
        }
        if (!accentHex.isEmpty()) {
            args << QStringLiteral("-o") << QStringLiteral("colors.cursor.cursor=\"%1\"").arg(accentHex);
        }

        args << QStringLiteral("-e") << QStringLiteral("/bin/sh") << QStringLiteral("-lc") << trimmed;
    } else {
        // Fallback to kitty on X11 ONLY (never m_waylandSocket)
        program = QStringLiteral("kitty");
        env.remove(QStringLiteral("WAYLAND_DISPLAY"));
        if (!m_x11Display.isEmpty()) {
            env.insert(QStringLiteral("DISPLAY"), m_x11Display);
        }

        args << QStringLiteral("--app-id") << appId
             << QStringLiteral("--title") << appId
             << QStringLiteral("-o") << QStringLiteral("confirm_os_window_close=0")
             << QStringLiteral("-o") << QStringLiteral("remember_window_size=no")
             << QStringLiteral("-o") << QStringLiteral("hide_window_decorations=yes")
             << QStringLiteral("-o") << QStringLiteral("window_padding_width=4");

        // Pass include first so subsequent overrides take precedence
        const QString kittyConf = xdgThemeDir + QStringLiteral("/ascii-de-kitty.conf");
        if (QFileInfo::exists(kittyConf)) {
            args << QStringLiteral("-o") << QStringLiteral("include=%1").arg(kittyConf);
        }

        args << QStringLiteral("-o") << QStringLiteral("font_size=%1.0").arg(fs)
             << QStringLiteral("-o") << QStringLiteral("background_opacity=%1").arg(QString::number(op, 'f', 2))
             << QStringLiteral("-o") << QStringLiteral("initial_window_width=%1").arg(w)
             << QStringLiteral("-o") << QStringLiteral("initial_window_height=%1").arg(h);

        if (!bgHex.isEmpty()) {
            args << QStringLiteral("-o") << QStringLiteral("background=%1").arg(bgHex);
        }
        if (!fgHex.isEmpty()) {
            args << QStringLiteral("-o") << QStringLiteral("foreground=%1").arg(fgHex);
        }
        if (!accentHex.isEmpty()) {
            args << QStringLiteral("-o") << QStringLiteral("cursor=%1").arg(accentHex);
        }

        args << QStringLiteral("-e") << QStringLiteral("/bin/sh") << QStringLiteral("-lc") << trimmed;
    }

    QProcess proc;
    proc.setProgram(program);
    proc.setArguments(args);
    proc.setWorkingDirectory(QDir::homePath());
    proc.setProcessEnvironment(env);

    qint64 pid = 0;
    if (proc.startDetached(&pid)) {
        m_bgTilePids.insert(tid, pid);
        return pid;
    } else {
        qWarning("ascii-de-compositor: failed to launch bg tile '%s' (%s) with %s: %s",
                 qPrintable(tid),
                 qPrintable(trimmed),
                 qPrintable(program),
                 qPrintable(proc.errorString()));
        return 0;
    }
}

void DesktopBridge::stopBgTile(const QString &tileId)
{
    const QString tid = tileId.trimmed();
    if (m_bgTilePids.contains(tid)) {
        qint64 pid = m_bgTilePids.take(tid);
        if (pid > 0) {
            ::kill(static_cast<pid_t>(pid), SIGTERM);
        }
    }
}

void DesktopBridge::stopAllBgTiles()
{
    for (auto it = m_bgTilePids.begin(); it != m_bgTilePids.end(); ++it) {
        if (it.value() > 0) {
            ::kill(static_cast<pid_t>(it.value()), SIGTERM);
        }
    }
    m_bgTilePids.clear();
}

QString DesktopBridge::findFreeXDisplay() const
{
    for (int d = kXWaylandMinDisplay; d <= kXWaylandMaxDisplay; ++d) {
        const QString unixSocket = QStringLiteral("/tmp/.X11-unix/X%1").arg(d);
        const QString lockFile = QStringLiteral("/tmp/.X%1-lock").arg(d);
        if (!QFile::exists(unixSocket) && !QFile::exists(lockFile)) {
            return QStringLiteral(":%1").arg(d);
        }
    }
    return QString();
}

void DesktopBridge::startXWayland()
{
    if (m_xwaylandProcess && m_xwaylandProcess->state() != QProcess::NotRunning) {
        return;
    }

    QString xwaylandExe = QStandardPaths::findExecutable(QStringLiteral("xwayland-satellite"));
    bool useSatellite = !xwaylandExe.isEmpty();
    if (!useSatellite && QFileInfo::exists(QStringLiteral("/usr/bin/xwayland-satellite"))
        && QFileInfo(QStringLiteral("/usr/bin/xwayland-satellite")).isExecutable()) {
        xwaylandExe = QStringLiteral("/usr/bin/xwayland-satellite");
        useSatellite = true;
    }
    if (!useSatellite) {
        xwaylandExe = QStandardPaths::findExecutable(QStringLiteral("Xwayland"));
        if (xwaylandExe.isEmpty()) {
            qInfo("ascii-de-compositor: neither xwayland-satellite nor Xwayland found, skipping X11 bridge");
            return;
        }
    }

    const QString candidateDisplay = findFreeXDisplay();
    if (candidateDisplay.isEmpty()) {
        qWarning("ascii-de-compositor: no free X11 display in :14..:20");
        return;
    }

    auto *proc = new QProcess(this);
    m_xwaylandProcess = proc;

    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    if (!m_waylandSocket.isEmpty()) {
        env.insert(QStringLiteral("WAYLAND_DISPLAY"), m_waylandSocket);
    }
    env.remove(QStringLiteral("DISPLAY"));
    proc->setProcessEnvironment(env);
    proc->setProcessChannelMode(QProcess::ForwardedChannels);

    connect(proc, &QProcess::started, this, [this, candidateDisplay]() {
        // Wait briefly for the X11 UNIX socket to appear before publishing DISPLAY
        QTimer::singleShot(150, this, [this, candidateDisplay]() {
            if (m_xwaylandProcess && m_xwaylandProcess->state() == QProcess::Running) {
                if (m_x11Display != candidateDisplay) {
                    m_x11Display = candidateDisplay;
                    emit x11DisplayChanged();
                }
                if (qEnvironmentVariableIntValue("ASCII_DE_SESSION") == 1) {
                    QProcessEnvironment actEnv = QProcessEnvironment::systemEnvironment();
                    actEnv.insert(QStringLiteral("DISPLAY"), candidateDisplay);
                    if (!m_waylandSocket.isEmpty()) {
                        actEnv.insert(QStringLiteral("WAYLAND_DISPLAY"), m_waylandSocket);
                    }
                    QProcess actProc;
                    actProc.setProgram(QStringLiteral("dbus-update-activation-environment"));
                    actProc.setArguments({
                        QStringLiteral("--systemd"),
                        QStringLiteral("DISPLAY"),
                        QStringLiteral("WAYLAND_DISPLAY"),
                        QStringLiteral("XDG_CURRENT_DESKTOP"),
                        QStringLiteral("DESKTOP_SESSION")
                    });
                    actProc.setProcessEnvironment(actEnv);
                    actProc.startDetached();
                }
            }
        });
    });

    connect(proc, &QProcess::finished, this, [this, proc](int exitCode, QProcess::ExitStatus exitStatus) {
        Q_UNUSED(exitCode);
        Q_UNUSED(exitStatus);
        if (!m_x11Display.isEmpty()) {
            m_x11Display.clear();
            emit x11DisplayChanged();
        }
        if (m_xwaylandProcess == proc) {
            m_xwaylandProcess.clear();
        }
        proc->deleteLater();
    });

    connect(proc, &QProcess::errorOccurred, this, [this, proc](QProcess::ProcessError error) {
        qWarning("ascii-de-compositor: X11 bridge error (%d): %s",
                 static_cast<int>(error),
                 qPrintable(proc->errorString()));
    });

    if (useSatellite) {
        proc->start(xwaylandExe, {candidateDisplay});
    } else {
        proc->start(xwaylandExe, {
            candidateDisplay,
            QStringLiteral("-ac"),
            QStringLiteral("-nolisten"),
            QStringLiteral("tcp"),
            QStringLiteral("-rootless")
        });
    }
}

void DesktopBridge::registerXdgOutput(QObject *managerObj, QObject *outputObj, const QString &name, int x, int y, int w, int h)
{
    auto *manager = qobject_cast<QWaylandXdgOutputManagerV1 *>(managerObj);
    auto *output = qobject_cast<QWaylandOutput *>(outputObj);
    if (!manager || !output) {
        return;
    }
    if (!manager->isInitialized()) {
        manager->initialize();
    }
    QWaylandXdgOutputV1 *xdgOut = nullptr;
    for (QWaylandXdgOutputV1 *existing : manager->findChildren<QWaylandXdgOutputV1 *>(QString(), Qt::FindDirectChildrenOnly)) {
        if (existing->output() == output) {
            xdgOut = existing;
            break;
        }
    }
    if (!xdgOut) {
        // Parent to manager (not output) so ~QWaylandXdgOutputV1 never dereferences a
        // destroyed manager during compositor teardown; also delete if output goes first.
        xdgOut = new QWaylandXdgOutputV1(output, manager);
        xdgOut->setParent(manager);
        // zxdg_output_v1 name and description are immutable after creation; set only once.
        xdgOut->setName(name);
        xdgOut->setDescription(QStringLiteral("ASCII-DE ") + name);
        QPointer<QWaylandXdgOutputV1> safeXdgOut(xdgOut);
        QObject::connect(output, &QObject::destroyed, xdgOut, [safeXdgOut]() {
            delete safeXdgOut.data();
        });
    }
    output->setSizeFollowsWindow(false);
    output->setScaleFactor(1);

    const QSize targetSize(qMax(1, w), qMax(1, h));
    int refreshMhz = 60000;
    if (QWindow *win = output->window()) {
        if (QScreen *scr = win->screen()) {
            if (scr->refreshRate() > 1.0) {
                refreshMhz = qRound(scr->refreshRate() * 1000.0);
            }
        }
    }
    const QWaylandOutputMode targetMode(targetSize, refreshMhz);
    if (!output->modes().contains(targetMode)) {
        output->addMode(targetMode, true);
    }
    output->setCurrentMode(targetMode);

    xdgOut->setLogicalPosition(QPoint(x, y));
    xdgOut->setLogicalSize(targetSize);
}

void DesktopBridge::clearSeatKeyboardFocus(QObject *compositorObj)
{
    auto *compositor = qobject_cast<QWaylandCompositor *>(compositorObj);
    if (compositor && compositor->defaultSeat()) {
        compositor->defaultSeat()->setKeyboardFocus(nullptr);
    }
}

void DesktopBridge::normalizeClientSubsurfaces(QObject *surfaceItemObj)
{
    Q_UNUSED(surfaceItemObj);
}

void DesktopBridge::attachSubsurfaceFixer(QObject *surfaceItemObj)
{
    Q_UNUSED(surfaceItemObj);
}

void DesktopBridge::forwardX11Wheel(int deltaY, int deltaX)
{
    if (m_x11Display.isEmpty()) {
        return;
    }

    // Guard: skip XTest wheel injection only if ascii-de-x11-scroll-bridge daemon is alive
    // (PID exists AND heartbeat file mtime < 10s old), preventing double-scrolling while
    // ensuring compositor fallback takes over automatically if the daemon stalls or exits.
    static qint64 s_lastCheckMs = 0;
    static bool s_daemonRunning = false;
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    if (now - s_lastCheckMs > 2000) {
        s_lastCheckMs = now;
        const bool pidAlive = (QProcess::execute(QStringLiteral("pgrep"),
                               {QStringLiteral("-f"), QStringLiteral("ascii-de-x11-scroll-bridge")}) == 0);
        bool hbFresh = false;
        if (pidAlive) {
            QString runtimeDir = qEnvironmentVariable("XDG_RUNTIME_DIR");
            if (runtimeDir.isEmpty()) {
                runtimeDir = QStringLiteral("/tmp");
            }
            const QFileInfo hbInfo(runtimeDir + QStringLiteral("/ascii-de-scroll-bridge.alive"));
            if (hbInfo.exists()) {
                const qint64 ageSecs = hbInfo.lastModified().secsTo(QDateTime::currentDateTimeUtc());
                hbFresh = (ageSecs >= -5 && ageSecs < 10);
            }
        }
        s_daemonRunning = pidAlive && hbFresh;
    }
    if (s_daemonRunning) {
        return;
    }

    typedef void *DisplayPtr;
    typedef DisplayPtr (*XOpenDisplayFn)(const char *);
    typedef int (*XTestFakeButtonEventFn)(DisplayPtr, unsigned int, int, unsigned long);
    typedef int (*XFlushFn)(DisplayPtr);

    static XOpenDisplayFn fnOpenDisplay = nullptr;
    static XTestFakeButtonEventFn fnFakeButton = nullptr;
    static XFlushFn fnFlush = nullptr;
    static bool resolved = false;
    static DisplayPtr s_x11Display = nullptr;

    if (!resolved) {
        resolved = true;
        void *libX11 = ::dlopen("libX11.so.6", RTLD_LAZY | RTLD_GLOBAL);
        void *libXtst = ::dlopen("libXtst.so.6", RTLD_LAZY | RTLD_GLOBAL);
        if (libX11 && libXtst) {
            fnOpenDisplay = reinterpret_cast<XOpenDisplayFn>(::dlsym(libX11, "XOpenDisplay"));
            fnFakeButton = reinterpret_cast<XTestFakeButtonEventFn>(::dlsym(libXtst, "XTestFakeButtonEvent"));
            fnFlush = reinterpret_cast<XFlushFn>(::dlsym(libX11, "XFlush"));
        }
    }

    if (!fnOpenDisplay || !fnFakeButton || !fnFlush) {
        return;
    }

    if (!s_x11Display) {
        s_x11Display = fnOpenDisplay(m_x11Display.toUtf8().constData());
    }
    if (!s_x11Display) {
        return;
    }

    if (deltaY != 0) {
        const unsigned int btn = (deltaY > 0) ? 4 : 5;
        fnFakeButton(s_x11Display, btn, 1, 0); // 1 = True (press), 0 = CurrentTime
        fnFakeButton(s_x11Display, btn, 0, 0); // 0 = False (release)
    }
    if (deltaX != 0) {
        const unsigned int btn = (deltaX > 0) ? 7 : 6;
        fnFakeButton(s_x11Display, btn, 1, 0);
        fnFakeButton(s_x11Display, btn, 0, 0);
    }
    fnFlush(s_x11Display);
}

void DesktopBridge::syncSurfaceOutput(QObject *surfaceObj, QObject *targetOutputObj, const QVariantList &allOutputObjs)
{
    Q_UNUSED(allOutputObjs);
    auto *targetOut = qobject_cast<QWaylandOutput*>(targetOutputObj);
    if (!targetOut && targetOutputObj) {
        targetOut = targetOutputObj->property("output").value<QWaylandOutput*>();
    }
    if (!targetOut) {
        return;
    }

    if (auto *qitem = qobject_cast<QWaylandQuickItem*>(surfaceObj)) {
        qitem->setOutput(targetOut);
        const auto children = qitem->childItems();
        for (QQuickItem *child : children) {
            if (auto *childItem = qobject_cast<QWaylandQuickItem*>(child)) {
                childItem->setOutput(targetOut);
            }
        }
    }
}

QVariantMap DesktopBridge::captureWindow(QObject *windowObj, int cropX, int cropY, int cropW, int cropH, bool saveToDisk, bool copyToClipboard)
{
    return m_screenshotHelper.captureWindow(windowObj, cropX, cropY, cropW, cropH, saveToDisk, copyToClipboard);
}

QVariantMap DesktopBridge::captureAllOutputs(const QVariantList &outputRecords, bool saveToDisk, bool copyToClipboard)
{
    return m_screenshotHelper.captureAllOutputs(outputRecords, saveToDisk, copyToClipboard);
}

void DesktopBridge::stopXWayland()
{
    if (!m_xwaylandProcess) {
        return;
    }
    m_xwaylandProcess->disconnect(this);
    if (m_xwaylandProcess->state() != QProcess::NotRunning) {
        m_xwaylandProcess->terminate();
        if (!m_xwaylandProcess->waitForFinished(1000)) {
            m_xwaylandProcess->kill();
            m_xwaylandProcess->waitForFinished(500);
        }
    }
    m_xwaylandProcess.clear();
}

void DesktopBridge::quitCompositor()
{
    stopXWayland();
    QCoreApplication::quit();
}
