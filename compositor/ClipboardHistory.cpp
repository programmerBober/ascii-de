#include "ClipboardHistory.h"

#include <QClipboard>
#include <QGuiApplication>
#include <QMimeData>
#include <QProcess>
#include <QProcessEnvironment>
#include <QStandardPaths>

namespace {
constexpr int kMaxClipboardEntries = 25;
} // namespace

ClipboardHistory::ClipboardHistory(QObject *parent)
    : QObject(parent)
{
    if (QClipboard *cb = QGuiApplication::clipboard()) {
        connect(cb, &QClipboard::dataChanged, this, &ClipboardHistory::onClipboardDataChanged);
        const QString initial = cb->text();
        if (!initial.trimmed().isEmpty()) {
            addUniqueEntry(initial);
        }
    }
}

QStringList ClipboardHistory::entries() const
{
    return m_entries;
}

QString ClipboardHistory::waylandSocket() const
{
    return m_waylandSocket;
}

void ClipboardHistory::setWaylandSocket(const QString &socket)
{
    if (m_waylandSocket == socket) {
        return;
    }
    m_waylandSocket = socket;
    emit waylandSocketChanged();
}

void ClipboardHistory::copyEntry(int idx)
{
    if (idx < 0 || idx >= m_entries.size()) {
        return;
    }

    const QString text = m_entries.at(idx);
    if (idx > 0) {
        m_entries.move(idx, 0);
        emit entriesChanged();
    }

    if (QClipboard *cb = QGuiApplication::clipboard()) {
        m_ignoreClipboardSignal = true;
        cb->setText(text, QClipboard::Clipboard);
        if (cb->supportsSelection()) {
            cb->setText(text, QClipboard::Selection);
        }
        m_ignoreClipboardSignal = false;
    }

    syncWaylandClipboardAsync(text);
}

void ClipboardHistory::removeEntry(int idx)
{
    if (idx < 0 || idx >= m_entries.size()) {
        return;
    }
    m_entries.removeAt(idx);
    emit entriesChanged();
}

void ClipboardHistory::clear()
{
    if (m_entries.isEmpty()) {
        return;
    }
    m_entries.clear();
    emit entriesChanged();
}

void ClipboardHistory::recordText(const QString &text)
{
    if (text.trimmed().isEmpty()) {
        return;
    }
    addUniqueEntry(text);
}

void ClipboardHistory::onClipboardDataChanged()
{
    if (m_ignoreClipboardSignal) {
        m_ignoreClipboardSignal = false;
        return;
    }

    QClipboard *cb = QGuiApplication::clipboard();
    if (!cb) {
        return;
    }

    const QMimeData *mime = cb->mimeData();
    if (!mime || !mime->hasText()) {
        return;
    }

    const QString text = mime->text();
    if (text.trimmed().isEmpty()) {
        return;
    }
    if (!m_entries.isEmpty() && m_entries.first() == text) {
        return;
    }

    addUniqueEntry(text);
    syncWaylandClipboardAsync(text);
}

void ClipboardHistory::addUniqueEntry(const QString &text)
{
    if (!m_entries.isEmpty() && m_entries.first() == text) {
        return;
    }
    m_entries.removeAll(text);
    m_entries.prepend(text);
    while (m_entries.size() > kMaxClipboardEntries) {
        m_entries.removeLast();
    }
    emit entriesChanged();
}

void ClipboardHistory::syncWaylandClipboardAsync(const QString &text)
{
    if (text.isEmpty()) {
        return;
    }

    const QString socket = m_waylandSocket.trimmed();
    if (socket.isEmpty()) {
        return;
    }

    const QString wlCopyExe = QStandardPaths::findExecutable(QStringLiteral("wl-copy"));
    if (wlCopyExe.isEmpty()) {
        return;
    }

    if (m_copyProcess) {
        m_copyProcess->disconnect(this);
        if (m_copyProcess->state() != QProcess::NotRunning) {
            m_copyProcess->terminate();
        }
        m_copyProcess->deleteLater();
        m_copyProcess = nullptr;
    }

    auto *proc = new QProcess(this);
    m_copyProcess = proc;
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert(QStringLiteral("WAYLAND_DISPLAY"), socket);
    env.remove(QStringLiteral("DISPLAY"));
    proc->setProcessEnvironment(env);
    proc->setStandardOutputFile(QProcess::nullDevice());
    proc->setStandardErrorFile(QProcess::nullDevice());

    connect(proc, &QProcess::finished, this, [this, proc](int, QProcess::ExitStatus) {
        if (m_copyProcess == proc) {
            m_copyProcess = nullptr;
        }
        proc->deleteLater();
    });
    connect(proc, &QProcess::errorOccurred, this, [this, proc](QProcess::ProcessError error) {
        qWarning("ascii-de-compositor: wl-copy (clipboard history) failed (%d): %s",
                 static_cast<int>(error),
                 qPrintable(proc->errorString()));
        if (m_copyProcess == proc) {
            m_copyProcess = nullptr;
        }
        if (proc->state() == QProcess::NotRunning) {
            proc->deleteLater();
        }
    });

    // Provide text without restrictive --type flag so wl-copy automatically advertises
    // text/plain, text/plain;charset=utf-8, UTF8_STRING, STRING, and TEXT.
    // This ensures Kitty, Alacritty, and X11 apps paste seamlessly without missing formats.
    if (text.size() > 32768) {
        const QByteArray payload = text.toUtf8();
        connect(proc, &QProcess::started, proc, [proc, payload]() {
            proc->write(payload);
            proc->closeWriteChannel();
        });
        proc->start(wlCopyExe, QStringList{});
    } else {
        proc->start(wlCopyExe, {QStringLiteral("--"), text});
    }
}
