#pragma once

#include <QDBusAbstractAdaptor>
#include <QHash>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

class NotificationServer;

class NotificationsDbusAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.Notifications")

public:
    explicit NotificationsDbusAdaptor(NotificationServer *parent);

public slots:
    QStringList GetCapabilities();
    QString GetServerInformation(QString &vendor, QString &version, QString &specVersion);
    uint Notify(
        const QString &appName,
        uint replacesId,
        const QString &appIcon,
        const QString &summary,
        const QString &body,
        const QStringList &actions,
        const QVariantMap &hints,
        int expireTimeout);
    void CloseNotification(uint id);

signals:
    void NotificationClosed(uint id, uint reason);
    void ActionInvoked(uint id, const QString &actionKey);

private:
    NotificationServer *m_server = nullptr;
};

class NotificationServer : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList activeToasts READ activeToasts NOTIFY notificationsChanged)
    Q_PROPERTY(QVariantList history READ history NOTIFY notificationsChanged)
    Q_PROPERTY(int unreadCount READ unreadCount NOTIFY notificationsChanged)
    Q_PROPERTY(bool dbusRegistered READ dbusRegistered NOTIFY dbusRegisteredChanged)

public:
    explicit NotificationServer(QObject *parent = nullptr);
    ~NotificationServer() override;

    [[nodiscard]] QVariantList activeToasts() const;
    [[nodiscard]] QVariantList history() const;
    [[nodiscard]] int unreadCount() const;
    [[nodiscard]] bool dbusRegistered() const;

    uint handleDbusNotify(
        const QString &appName,
        uint replacesId,
        const QString &appIcon,
        const QString &summary,
        const QString &body,
        const QStringList &actions,
        const QVariantMap &hints,
        int expireTimeout);
    void handleDbusClose(uint id);

    Q_INVOKABLE uint pushLocalNotification(
        const QString &appName,
        const QString &summary,
        const QString &body,
        int urgency = 1,
        int timeoutMs = 5000);
    Q_INVOKABLE void dismissToast(uint id);
    Q_INVOKABLE void removeHistoryItem(uint id);
    Q_INVOKABLE void clearHistory();
    Q_INVOKABLE void markAllRead();
    Q_INVOKABLE void invokeAction(uint id, const QString &actionKey);

signals:
    void notificationsChanged();
    void dbusRegisteredChanged();

private:
    void scheduleExpiry(uint id, int timeoutMs);
    void cancelTimer(uint id);
    void expireToast(uint id);
    void emitDbusClosed(uint id, uint reason);
    void emitDbusAction(uint id, const QString &actionKey);

    static QVariantList parseActions(const QStringList &actions);
    static int indexById(const QVariantList &list, uint id);

    NotificationsDbusAdaptor *m_adaptor = nullptr;
    QVariantList m_activeToasts;
    QVariantList m_history;
    QHash<uint, QTimer *> m_toastTimers;
    uint m_nextId = 1;
    bool m_dbusRegistered = false;
};
