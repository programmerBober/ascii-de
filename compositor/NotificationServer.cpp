#include "NotificationServer.h"

#include <QDBusConnection>
#include <QDBusError>
#include <QDateTime>
#include <QtGlobal>

namespace {
constexpr int kDefaultToastTimeoutMs = 5000;
constexpr int kMinToastTimeoutMs = 1000;
constexpr int kMaxToastTimeoutMs = 30000;
constexpr int kMaxHistoryItems = 50;

constexpr uint kCloseReasonExpired = 1;
constexpr uint kCloseReasonDismissed = 2;
constexpr uint kCloseReasonClosedByCall = 3;
} // namespace

NotificationsDbusAdaptor::NotificationsDbusAdaptor(NotificationServer *parent)
    : QDBusAbstractAdaptor(parent)
    , m_server(parent)
{
}

QStringList NotificationsDbusAdaptor::GetCapabilities()
{
    return {
        QStringLiteral("body"),
        QStringLiteral("body-markup"),
        QStringLiteral("actions"),
        QStringLiteral("persistence")
    };
}

QString NotificationsDbusAdaptor::GetServerInformation(
    QString &vendor,
    QString &version,
    QString &specVersion)
{
    vendor = QStringLiteral("ASCII-DE");
    version = QStringLiteral("1.0");
    specVersion = QStringLiteral("1.2");
    return QStringLiteral("ascii-de-notifications");
}

uint NotificationsDbusAdaptor::Notify(
    const QString &appName,
    uint replacesId,
    const QString &appIcon,
    const QString &summary,
    const QString &body,
    const QStringList &actions,
    const QVariantMap &hints,
    int expireTimeout)
{
    if (!m_server) {
        return 0;
    }
    return m_server->handleDbusNotify(
        appName, replacesId, appIcon, summary, body, actions, hints, expireTimeout);
}

void NotificationsDbusAdaptor::CloseNotification(uint id)
{
    if (m_server) {
        m_server->handleDbusClose(id);
    }
}

NotificationServer::NotificationServer(QObject *parent)
    : QObject(parent)
    , m_adaptor(new NotificationsDbusAdaptor(this))
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        qInfo("ascii-de-compositor: session D-Bus unavailable; notification daemon running in local-only mode");
        return;
    }

    bus.registerObject(
        QStringLiteral("/org/freedesktop/Notifications"),
        this,
        QDBusConnection::ExportAdaptors);

    if (bus.registerService(QStringLiteral("org.freedesktop.Notifications"))) {
        m_dbusRegistered = true;
        emit dbusRegisteredChanged();
    } else {
        qInfo("ascii-de-compositor: org.freedesktop.Notifications already owned on session bus (%s); "
              "local notifications remain active",
              qPrintable(bus.lastError().message()));
    }
}

NotificationServer::~NotificationServer()
{
    for (QTimer *timer : std::as_const(m_toastTimers)) {
        if (timer) {
            timer->stop();
            timer->deleteLater();
        }
    }
    m_toastTimers.clear();

    if (m_dbusRegistered) {
        QDBusConnection bus = QDBusConnection::sessionBus();
        if (bus.isConnected()) {
            bus.unregisterService(QStringLiteral("org.freedesktop.Notifications"));
            bus.unregisterObject(QStringLiteral("/org/freedesktop/Notifications"));
        }
    }
}

QVariantList NotificationServer::activeToasts() const
{
    return m_activeToasts;
}

QVariantList NotificationServer::history() const
{
    return m_history;
}

int NotificationServer::unreadCount() const
{
    int count = 0;
    for (const QVariant &entry : m_history) {
        if (!entry.toMap().value(QStringLiteral("read")).toBool()) {
            ++count;
        }
    }
    return count;
}

bool NotificationServer::dbusRegistered() const
{
    return m_dbusRegistered;
}

QVariantList NotificationServer::parseActions(const QStringList &actions)
{
    QVariantList out;
    for (int i = 0; i + 1 < actions.size(); i += 2) {
        QVariantMap item;
        item.insert(QStringLiteral("key"), actions.at(i));
        item.insert(QStringLiteral("label"), actions.at(i + 1));
        out.append(item);
    }
    return out;
}

int NotificationServer::indexById(const QVariantList &list, uint id)
{
    for (int i = 0; i < list.size(); ++i) {
        if (list.at(i).toMap().value(QStringLiteral("id")).toUInt() == id) {
            return i;
        }
    }
    return -1;
}

uint NotificationServer::handleDbusNotify(
    const QString &appName,
    uint replacesId,
    const QString &appIcon,
    const QString &summary,
    const QString &body,
    const QStringList &actions,
    const QVariantMap &hints,
    int expireTimeout)
{
    const bool isOnkyo = appName.contains(QStringLiteral("Onkyo"), Qt::CaseInsensitive)
                         || summary.contains(QStringLiteral("Onkyo"), Qt::CaseInsensitive)
                         || body.contains(QStringLiteral("HT-R758"), Qt::CaseInsensitive);

    uint id = replacesId;
    if (id == 0) {
        // Debounce: reuse active toast ID for identical app + summary or Onkyo audio toasts
        for (const QVariant &v : std::as_const(m_activeToasts)) {
            const QVariantMap existing = v.toMap();
            const QString exApp = existing.value(QStringLiteral("appName")).toString();
            const QString exSummary = existing.value(QStringLiteral("summary")).toString();
            const QString exBody = existing.value(QStringLiteral("body")).toString();

            const bool appSummaryMatch = (exApp.compare(appName, Qt::CaseInsensitive) == 0
                                          && exSummary.compare(summary, Qt::CaseInsensitive) == 0);
            const bool onkyoMatch = isOnkyo && (exApp.contains(QStringLiteral("Onkyo"), Qt::CaseInsensitive)
                                                || exSummary.contains(QStringLiteral("Onkyo"), Qt::CaseInsensitive));

            if (appSummaryMatch || onkyoMatch) {
                // If an identical Onkyo toast is already actively displayed, refresh expiry and quietly suppress duplicate toast
                if (onkyoMatch && exSummary == summary && exBody == body) {
                    const uint exId = existing.value(QStringLiteral("id")).toUInt();
                    scheduleExpiry(exId, kDefaultToastTimeoutMs);
                    return exId;
                }
                id = existing.value(QStringLiteral("id")).toUInt();
                break;
            }
        }

        if (id == 0) {
            id = m_nextId++;
            if (m_nextId == 0) {
                m_nextId = 1;
            }
        }
    } else if (id >= m_nextId) {
        m_nextId = id + 1;
    }

    int urgency = 1;
    if (hints.contains(QStringLiteral("urgency"))) {
        urgency = qBound(0, hints.value(QStringLiteral("urgency")).toInt(), 2);
    }

    QVariantMap item;
    item.insert(QStringLiteral("id"), id);
    item.insert(QStringLiteral("appName"), appName.trimmed().isEmpty() ? QStringLiteral("System") : appName);
    item.insert(QStringLiteral("appIcon"), appIcon);
    item.insert(QStringLiteral("summary"), summary);
    item.insert(QStringLiteral("body"), body);
    item.insert(QStringLiteral("urgency"), urgency);
    item.insert(QStringLiteral("timestamp"), QDateTime::currentDateTime().toString(QStringLiteral("HH:mm:ss")));
    item.insert(QStringLiteral("actions"), parseActions(actions));
    item.insert(QStringLiteral("read"), false);

    const int toastIdx = indexById(m_activeToasts, id);
    if (toastIdx >= 0) {
        m_activeToasts.replace(toastIdx, item);
    } else {
        m_activeToasts.prepend(item);
    }

    const bool transient = hints.value(QStringLiteral("transient")).toBool();
    if (!transient) {
        const int histIdx = indexById(m_history, id);
        if (histIdx >= 0) {
            m_history.removeAt(histIdx);
        }
        m_history.prepend(item);
        while (m_history.size() > kMaxHistoryItems) {
            m_history.removeLast();
        }
    }

    int effectiveTimeout = expireTimeout;
    if (effectiveTimeout < 0) {
        effectiveTimeout = (urgency >= 2) ? 0 : kDefaultToastTimeoutMs;
    }
    if (effectiveTimeout > 0) {
        scheduleExpiry(id, qBound(kMinToastTimeoutMs, effectiveTimeout, kMaxToastTimeoutMs));
    } else {
        cancelTimer(id);
    }

    emit notificationsChanged();
    return id;
}

void NotificationServer::handleDbusClose(uint id)
{
    cancelTimer(id);
    const int toastIdx = indexById(m_activeToasts, id);
    if (toastIdx >= 0) {
        m_activeToasts.removeAt(toastIdx);
        emit notificationsChanged();
    }
    emitDbusClosed(id, kCloseReasonClosedByCall);
}

uint NotificationServer::pushLocalNotification(
    const QString &appName,
    const QString &summary,
    const QString &body,
    int urgency,
    int timeoutMs)
{
    QVariantMap hints;
    hints.insert(QStringLiteral("urgency"), qBound(0, urgency, 2));
    return handleDbusNotify(
        appName,
        0,
        QString(),
        summary,
        body,
        QStringList(),
        hints,
        timeoutMs);
}

void NotificationServer::dismissToast(uint id)
{
    cancelTimer(id);
    bool changed = false;

    const int toastIdx = indexById(m_activeToasts, id);
    if (toastIdx >= 0) {
        m_activeToasts.removeAt(toastIdx);
        changed = true;
    }

    const int histIdx = indexById(m_history, id);
    if (histIdx >= 0) {
        QVariantMap item = m_history.at(histIdx).toMap();
        if (!item.value(QStringLiteral("read")).toBool()) {
            item.insert(QStringLiteral("read"), true);
            m_history.replace(histIdx, item);
            changed = true;
        }
    }

    if (changed) {
        emit notificationsChanged();
    }
    emitDbusClosed(id, kCloseReasonDismissed);
}

void NotificationServer::removeHistoryItem(uint id)
{
    cancelTimer(id);
    bool changed = false;

    const int toastIdx = indexById(m_activeToasts, id);
    if (toastIdx >= 0) {
        m_activeToasts.removeAt(toastIdx);
        changed = true;
        emitDbusClosed(id, kCloseReasonDismissed);
    }

    const int histIdx = indexById(m_history, id);
    if (histIdx >= 0) {
        m_history.removeAt(histIdx);
        changed = true;
    }

    if (changed) {
        emit notificationsChanged();
    }
}

void NotificationServer::clearHistory()
{
    if (m_history.isEmpty()) {
        return;
    }
    m_history.clear();
    emit notificationsChanged();
}

void NotificationServer::markAllRead()
{
    bool changed = false;
    for (int i = 0; i < m_history.size(); ++i) {
        QVariantMap item = m_history.at(i).toMap();
        if (!item.value(QStringLiteral("read")).toBool()) {
            item.insert(QStringLiteral("read"), true);
            m_history.replace(i, item);
            changed = true;
        }
    }
    if (changed) {
        emit notificationsChanged();
    }
}

void NotificationServer::invokeAction(uint id, const QString &actionKey)
{
    emitDbusAction(id, actionKey);
    dismissToast(id);
}

void NotificationServer::scheduleExpiry(uint id, int timeoutMs)
{
    cancelTimer(id);
    auto *timer = new QTimer(this);
    timer->setSingleShot(true);
    connect(timer, &QTimer::timeout, this, [this, id]() {
        expireToast(id);
    });
    m_toastTimers.insert(id, timer);
    timer->start(timeoutMs);
}

void NotificationServer::cancelTimer(uint id)
{
    if (QTimer *timer = m_toastTimers.take(id)) {
        timer->stop();
        timer->deleteLater();
    }
}

void NotificationServer::expireToast(uint id)
{
    cancelTimer(id);
    const int toastIdx = indexById(m_activeToasts, id);
    if (toastIdx >= 0) {
        m_activeToasts.removeAt(toastIdx);
        emit notificationsChanged();
    }
    emitDbusClosed(id, kCloseReasonExpired);
}

void NotificationServer::emitDbusClosed(uint id, uint reason)
{
    if (m_dbusRegistered && m_adaptor) {
        emit m_adaptor->NotificationClosed(id, reason);
    }
}

void NotificationServer::emitDbusAction(uint id, const QString &actionKey)
{
    if (m_dbusRegistered && m_adaptor) {
        emit m_adaptor->ActionInvoked(id, actionKey);
    }
}
