#include "DesktopBridge.h"

#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QSocketNotifier>
#include <QUrl>
#include <QWindow>
#include <QtWaylandCompositor/QWaylandCompositor>
#include <QtWaylandCompositor/QWaylandOutput>

#include <csignal>
#include <cstdio>
#include <cstring>
#include <dlfcn.h>
#include <memory>
#include <unordered_map>
#include <unistd.h>
#include <wayland-server-core.h>
#include <wayland-server-protocol.h>

namespace {
struct OutputGlobalWrap {
    void *realData = nullptr;
    wl_global_bind_func_t realBind = nullptr;
};

std::unordered_map<void *, std::unique_ptr<OutputGlobalWrap>> &outputWrapMap()
{
    static std::unordered_map<void *, std::unique_ptr<OutputGlobalWrap>> map;
    return map;
}

void wrappedOutputBind(struct wl_client *client, void *data, uint32_t version, uint32_t id)
{
    auto *wrap = static_cast<OutputGlobalWrap *>(data);
    if (!wrap || !wrap->realBind) {
        return;
    }
    const uint32_t qtVersion = version > 4u ? 4u : version;
    wrap->realBind(client, wrap->realData, qtVersion, id);
    if (version >= 4u) {
        if (struct wl_resource *res = wl_client_get_object(client, id)) {
            QString outName = QStringLiteral("Output-0");
            QString outDesc = QStringLiteral("ASCII-DE Output");
            if (QWaylandOutput *qOut = QWaylandOutput::fromResource(res)) {
                if (!qOut->model().isEmpty()) {
                    outName = qOut->model();
                }
                if (!qOut->manufacturer().isEmpty() || !qOut->model().isEmpty()) {
                    outDesc = (qOut->manufacturer() + QLatin1Char(' ') + outName).trimmed();
                }
            }
            const QByteArray nameUtf8 = outName.toUtf8();
            const QByteArray descUtf8 = outDesc.toUtf8();
            wl_output_send_name(res, nameUtf8.constData());
            wl_output_send_description(res, descUtf8.constData());
            wl_output_send_done(res);
        }
    }
}
} // namespace

extern "C" struct wl_global *wl_global_create(
    struct wl_display *display,
    const struct wl_interface *interface,
    int version,
    void *data,
    wl_global_bind_func_t bind)
{
    using CreateFn = struct wl_global *(*)(struct wl_display *, const struct wl_interface *, int, void *, wl_global_bind_func_t);
    static auto realCreate = reinterpret_cast<CreateFn>(::dlsym(RTLD_NEXT, "wl_global_create"));
    if (!realCreate) {
        return nullptr;
    }

    // Qt6 QWaylandXdgShell advertises xdg_wm_base v1, while xwayland-satellite requires >= v2.
    // xdg-shell v2 only adds tiled_* enum values with identical requests/events/opcodes to v1.
    if (interface && interface->name && std::strcmp(interface->name, "xdg_wm_base") == 0 && version < 2) {
        static struct wl_interface xdgWmBaseV2 = *interface;
        xdgWmBaseV2.version = 2;
        return realCreate(display, &xdgWmBaseV2, 2, data, bind);
    }

    // Qt6 QWaylandOutput advertises wl_output v2, while xwayland-satellite requires >= v4 (name event).
    if (interface && interface->name && std::strcmp(interface->name, "wl_output") == 0 && version < 4) {
        static struct wl_interface wlOutputV4 = *interface;
        wlOutputV4.version = 4;
        auto wrap = std::make_unique<OutputGlobalWrap>();
        wrap->realData = data;
        wrap->realBind = bind;
        void *wrapPtr = wrap.get();
        outputWrapMap()[data] = std::move(wrap);
        return realCreate(display, &wlOutputV4, 4, wrapPtr, &wrappedOutputBind);
    }

    return realCreate(display, interface, version, data, bind);
}

namespace {
int g_signalPipe[2] = {-1, -1};

void handleTerminationSignal(int)
{
    if (g_signalPipe[1] >= 0) {
        const char byte = 1;
        [[maybe_unused]] const ssize_t written = ::write(g_signalPipe[1], &byte, sizeof(byte));
    }
}
} // namespace

int main(int argc, char *argv[])
{
    for (int i = 1; i < argc; ++i) {
        if (std::strcmp(argv[i], "--version") == 0) {
#ifdef ASCII_DE_VERSION
            std::printf("ascii-de-compositor %s\n", ASCII_DE_VERSION);
#else
            std::printf("ascii-de-compositor 0.1.0\n");
#endif
            return 0;
        }
    }

    bool earlyAllMonitors = qEnvironmentVariableIntValue("ASCII_DE_ALL_MONITORS") == 1;
    for (int i = 1; i < argc; ++i) {
        if (std::strcmp(argv[i], "--all-monitors") == 0) {
            earlyAllMonitors = true;
            break;
        }
    }
    if (qEnvironmentVariableIsEmpty("QT_WAYLAND_HARDWARE_INTEGRATION")) {
        qputenv("QT_WAYLAND_HARDWARE_INTEGRATION", "linux-dmabuf-v1");
    }
    if (earlyAllMonitors && qEnvironmentVariableIsEmpty("QSG_RENDER_LOOP")) {
        // Avoid multi-thread QWaylandQuickItem/QRhi texture races across monitor windows
        qputenv("QSG_RENDER_LOOP", "basic");
    }

    // Required by QtWaylandCompositor to share OpenGL textures with client surfaces
    QCoreApplication::setAttribute(Qt::AA_ShareOpenGLContexts);

    QGuiApplication app(argc, argv);
    app.setOrganizationName(QStringLiteral("ascii-de"));
    app.setApplicationName(QStringLiteral("ascii-de-compositor"));
#ifdef ASCII_DE_VERSION
    app.setApplicationVersion(QStringLiteral(ASCII_DE_VERSION));
#else
    app.setApplicationVersion(QStringLiteral("0.1.0"));
#endif

    if (::pipe(g_signalPipe) == 0) {
        auto *notifier = new QSocketNotifier(g_signalPipe[0], QSocketNotifier::Read, &app);
        QObject::connect(notifier, &QSocketNotifier::activated, &app, [notifier]() {
            notifier->setEnabled(false);
            char buf[8];
            [[maybe_unused]] const ssize_t n = ::read(g_signalPipe[0], buf, sizeof(buf));
            QCoreApplication::quit();
        });
        std::signal(SIGINT, handleTerminationSignal);
        std::signal(SIGTERM, handleTerminationSignal);
    }

    QString qmlPath;
    QString socketOverride;
    bool startFullscreen = qEnvironmentVariableIntValue("ASCII_DE_FULLSCREEN") == 1;
    bool allMonitors = qEnvironmentVariableIntValue("ASCII_DE_ALL_MONITORS") == 1;

    const QStringList args = app.arguments();
    for (int i = 1; i < args.size(); ++i) {
        const QString &arg = args.at(i);
        if ((arg == QStringLiteral("--qml")) && (i + 1 < args.size())) {
            qmlPath = args.at(++i);
        } else if ((arg == QStringLiteral("--socket")) && (i + 1 < args.size())) {
            socketOverride = args.at(++i);
        } else if (arg == QStringLiteral("--fullscreen")) {
            startFullscreen = true;
        } else if (arg == QStringLiteral("--all-monitors")) {
            allMonitors = true;
        }
    }

    if (qmlPath.isEmpty()) {
        QStringList candidates;
        const QString envQmlDir = qEnvironmentVariable("ASCII_DE_QML_DIR").trimmed();
        if (!envQmlDir.isEmpty()) {
            candidates << (envQmlDir + QStringLiteral("/MainCompositor.qml"));
        }
        candidates << QStringLiteral("/usr/share/ascii-de/ui/MainCompositor.qml")
                   << (QDir::homePath() + QStringLiteral("/.local/share/ascii-de/ui/MainCompositor.qml"))
                   << (QDir::homePath() + QStringLiteral("/Projecten/ascii-de/ui/MainCompositor.qml"));

        for (const QString &cand : std::as_const(candidates)) {
            if (QFileInfo::exists(cand)) {
                qmlPath = cand;
                break;
            }
        }
        if (qmlPath.isEmpty()) {
            qmlPath = candidates.last();
        }
    }

    if (!QFileInfo::exists(qmlPath)) {
        qCritical("ascii-de-compositor: QML entry file not found: %s", qPrintable(qmlPath));
        return 1;
    }

    DesktopBridge bridge;
    if (!socketOverride.isEmpty()) {
        bridge.setWaylandSocket(socketOverride);
    }
    bridge.setAllMonitors(allMonitors);
    bridge.setStartFullscreen(startFullscreen);

    QQmlApplicationEngine engine;
    engine.addImportPath(QFileInfo(qmlPath).absolutePath());
    engine.rootContext()->setContextProperty(QStringLiteral("Backend"), &bridge);
    engine.rootContext()->setContextProperty(QStringLiteral("ASCII_DE_ALL_MONITORS"), allMonitors);
    engine.rootContext()->setContextProperty(QStringLiteral("ASCII_DE_FULLSCREEN"), startFullscreen);

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(1); },
        Qt::QueuedConnection);

    engine.load(QUrl::fromLocalFile(qmlPath));
    if (engine.rootObjects().isEmpty()) {
        qCritical("ascii-de-compositor: failed to load QML root object from %s", qPrintable(qmlPath));
        return 1;
    }

    for (QObject *root : engine.rootObjects()) {
        if (auto *comp = qobject_cast<QWaylandCompositor *>(root)) {
            comp->setRetainedSelectionEnabled(true);
        }
    }

    if (startFullscreen) {
        for (QObject *root : engine.rootObjects()) {
            if (auto *win = qobject_cast<QWindow *>(root)) {
                if (win->visibility() != QWindow::FullScreen) {
                    win->showFullScreen();
                }
            }
            for (QWindow *childWin : root->findChildren<QWindow *>()) {
                if (childWin->visibility() != QWindow::FullScreen) {
                    childWin->showFullScreen();
                }
            }
        }
    }

    QObject::connect(&app, &QCoreApplication::aboutToQuit, &app, [&engine]() {
        for (QObject *root : engine.rootObjects()) {
            for (QWindow *childWin : root->findChildren<QWindow *>()) {
                childWin->hide();
            }
            if (auto *win = qobject_cast<QWindow *>(root)) {
                win->hide();
            }
        }
    });

    const int rc = app.exec();
    // Disconnect client windows cleanly before QtWaylandCompositor destructor runs
    for (QObject *root : engine.rootObjects()) {
        delete root;
    }
    if (g_signalPipe[0] >= 0) {
        ::close(g_signalPipe[0]);
    }
    if (g_signalPipe[1] >= 0) {
        ::close(g_signalPipe[1]);
    }
    return rc;
}
