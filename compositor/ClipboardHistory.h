#pragma once

#include <QObject>
#include <QPointer>
#include <QString>
#include <QStringList>

class QProcess;

class ClipboardHistory : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList entries READ entries NOTIFY entriesChanged)
    Q_PROPERTY(QString waylandSocket READ waylandSocket WRITE setWaylandSocket NOTIFY waylandSocketChanged)

public:
    explicit ClipboardHistory(QObject *parent = nullptr);
    ~ClipboardHistory() override = default;

    [[nodiscard]] QStringList entries() const;

    [[nodiscard]] QString waylandSocket() const;
    void setWaylandSocket(const QString &socket);

    Q_INVOKABLE void copyEntry(int idx);
    Q_INVOKABLE void removeEntry(int idx);
    Q_INVOKABLE void clear();
    Q_INVOKABLE void recordText(const QString &text);

signals:
    void entriesChanged();
    void waylandSocketChanged();

private slots:
    void onClipboardDataChanged();

private:
    void addUniqueEntry(const QString &text);
    void syncWaylandClipboardAsync(const QString &text);

    QStringList m_entries;
    QString m_waylandSocket = QStringLiteral("wayland-ascii-0");
    bool m_ignoreClipboardSignal = false;
    QPointer<QProcess> m_copyProcess;
};
