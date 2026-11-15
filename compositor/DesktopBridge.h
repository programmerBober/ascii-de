#pragma once

#include "ClipboardHistory.h"
#include "NotificationServer.h"
#include "ScreenshotHelper.h"

#include <QMap>
#include <QObject>
#include <QPointer>
#include <QProcess>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

class DesktopBridge : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString waylandSocket READ waylandSocket WRITE setWaylandSocket NOTIFY waylandSocketChanged)
    Q_PROPERTY(QString x11Display READ x11Display NOTIFY x11DisplayChanged)
    Q_PROPERTY(bool allMonitors READ allMonitors CONSTANT)
    Q_PROPERTY(bool startFullscreen READ startFullscreen CONSTANT)
    Q_PROPERTY(bool fullscreenMode READ startFullscreen CONSTANT)
    Q_PROPERTY(QObject *notifications READ notifications CONSTANT)
    Q_PROPERTY(QObject *clipboardHistory READ clipboardHistory CONSTANT)

public:
    explicit DesktopBridge(QObject *parent = nullptr);
    ~DesktopBridge() override;

    [[nodiscard]] QString waylandSocket() const;
    void setWaylandSocket(const QString &socket);

    [[nodiscard]] QString x11Display() const;

    [[nodiscard]] bool allMonitors() const;
    void setAllMonitors(bool enabled);

    [[nodiscard]] bool startFullscreen() const;
    void setStartFullscreen(bool enabled);

    [[nodiscard]] QObject *notifications();
    [[nodiscard]] QObject *clipboardHistory();

    Q_INVOKABLE QString runBackend(const QStringList &args);
    Q_INVOKABLE void runBackendAsync(const QStringList &args, const QString &tag);
    Q_INVOKABLE void verifyPasswordAsync(const QString &password, const QString &tag);
    Q_INVOKABLE void launchApp(const QString &cmd);
    Q_INVOKABLE void launchBgTerminal(const QString &cmd, int widthPx, int heightPx);
    Q_INVOKABLE qint64 launchBgTile(const QString &tileId, const QString &cmd, int widthPx, int heightPx, int fontSizePx, double opacity, const QString &bgHex, const QString &fgHex, const QString &accentHex);
    Q_INVOKABLE void stopBgTile(const QString &tileId);
    Q_INVOKABLE void stopAllBgTiles();
    Q_INVOKABLE void startXWayland();
    Q_INVOKABLE void forwardX11Wheel(int deltaY, int deltaX = 0);
    Q_INVOKABLE void registerXdgOutput(QObject *managerObj, QObject *outputObj, const QString &name, int x, int y, int w, int h);
    Q_INVOKABLE void clearSeatKeyboardFocus(QObject *compositorObj);
    Q_INVOKABLE void syncSurfaceOutput(QObject *surfaceObj, QObject *targetOutputObj, const QVariantList &allOutputObjs);
    Q_INVOKABLE void normalizeClientSubsurfaces(QObject *surfaceItemObj);
    Q_INVOKABLE void attachSubsurfaceFixer(QObject *surfaceItemObj);
    Q_INVOKABLE QVariantMap captureWindow(QObject *windowObj, int cropX, int cropY, int cropW, int cropH, bool saveToDisk, bool copyToClipboard);
    Q_INVOKABLE QVariantMap captureAllOutputs(const QVariantList &outputRecords, bool saveToDisk, bool copyToClipboard);
    Q_INVOKABLE void quitCompositor();

signals:
    void waylandSocketChanged();
    void x11DisplayChanged();
    void backendResult(const QString &tag, const QString &jsonOutput);
    void volumeActionRequested(const QString &action);

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    [[nodiscard]] QString backendExecutablePath() const;
    [[nodiscard]] QString findFreeXDisplay() const;
    void startBackendProcessAsync(const QStringList &args, const QString &tag, const QByteArray &stdinData = {});
    void stopXWayland();

    QString m_waylandSocket = QStringLiteral("wayland-ascii-0");
    QString m_x11Display;
    QPointer<QProcess> m_xwaylandProcess;
    QPointer<QProcess> m_activeStatusProcess;
    ScreenshotHelper m_screenshotHelper{this};
    NotificationServer m_notifications{this};
    ClipboardHistory m_clipboardHistory{this};
    QMap<QString, qint64> m_bgTilePids;
    bool m_allMonitors = false;
    bool m_startFullscreen = false;
};
