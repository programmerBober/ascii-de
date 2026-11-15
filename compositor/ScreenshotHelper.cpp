#include "ScreenshotHelper.h"

#include <QBuffer>
#include <QClipboard>
#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QPainter>
#include <QProcess>
#include <QProcessEnvironment>
#include <QQuickWindow>
#include <QRect>
#include <QSaveFile>
#include <QStandardPaths>
#include <QtMath>

#include <algorithm>
#include <limits>
#include <vector>

ScreenshotHelper::ScreenshotHelper(QObject *parent)
    : QObject(parent)
{
}

QString ScreenshotHelper::waylandSocket() const
{
    return m_waylandSocket;
}

void ScreenshotHelper::setWaylandSocket(const QString &socket)
{
    if (m_waylandSocket == socket) {
        return;
    }
    m_waylandSocket = socket;
    emit waylandSocketChanged();
}

QVariantMap ScreenshotHelper::makeResult(
    bool ok,
    const QString &path,
    int width,
    int height,
    bool clipboardCopied,
    const QString &error)
{
    QVariantMap out;
    out.insert(QStringLiteral("ok"), ok);
    out.insert(QStringLiteral("path"), path);
    out.insert(QStringLiteral("width"), width);
    out.insert(QStringLiteral("height"), height);
    out.insert(QStringLiteral("clipboardCopied"), clipboardCopied);
    out.insert(QStringLiteral("error"), error);
    return out;
}

QVariantMap ScreenshotHelper::captureWindow(
    QObject *windowObj,
    int cropX,
    int cropY,
    int cropW,
    int cropH,
    bool saveToDisk,
    bool copyToClipboard)
{
    auto *quickWin = qobject_cast<QQuickWindow *>(windowObj);
    if (!quickWin) {
        return makeResult(false, QString(), 0, 0, false, QStringLiteral("Invalid QQuickWindow object"));
    }

    QImage img = quickWin->grabWindow();
    if (img.isNull()) {
        return makeResult(false, QString(), 0, 0, false, QStringLiteral("QQuickWindow::grabWindow() returned null image"));
    }

    if (cropW > 0 && cropH > 0) {
        const qreal dpr = img.devicePixelRatio() > 0.0
                              ? img.devicePixelRatio()
                              : qMax<qreal>(1.0, quickWin->devicePixelRatio());
        const QRect cropRect(
            qRound(cropX * dpr),
            qRound(cropY * dpr),
            qMax(1, qRound(cropW * dpr)),
            qMax(1, qRound(cropH * dpr)));
        const QRect bounded = cropRect.intersected(img.rect());
        if (bounded.isEmpty()) {
            return makeResult(false, QString(), 0, 0, false, QStringLiteral("Crop region is outside window bounds"));
        }
        img = img.copy(bounded);
    }

    img.setDevicePixelRatio(1.0);
    return finalizeCapture(img, saveToDisk, copyToClipboard);
}

QVariantMap ScreenshotHelper::captureAllOutputs(
    const QVariantList &outputRecords,
    bool saveToDisk,
    bool copyToClipboard)
{
    struct GrabbedOutput {
        QImage image;
        int x = 0;
        int y = 0;
        int width = 0;
        int height = 0;
    };

    std::vector<GrabbedOutput> grabbed;
    grabbed.reserve(static_cast<std::size_t>(outputRecords.size()));

    int minX = std::numeric_limits<int>::max();
    int minY = std::numeric_limits<int>::max();
    int maxX = std::numeric_limits<int>::min();
    int maxY = std::numeric_limits<int>::min();
    qreal maxDpr = 1.0;

    for (const QVariant &entry : outputRecords) {
        const QVariantMap map = entry.toMap();
        QObject *winObj = map.value(QStringLiteral("window")).value<QObject *>();
        auto *quickWin = qobject_cast<QQuickWindow *>(winObj);
        if (!quickWin) {
            continue;
        }

        QImage shot = quickWin->grabWindow();
        if (shot.isNull()) {
            continue;
        }

        const int gx = map.contains(QStringLiteral("x")) ? map.value(QStringLiteral("x")).toInt() : quickWin->x();
        const int gy = map.contains(QStringLiteral("y")) ? map.value(QStringLiteral("y")).toInt() : quickWin->y();
        const int gw = map.value(QStringLiteral("width")).toInt() > 0
                           ? map.value(QStringLiteral("width")).toInt()
                           : quickWin->width();
        const int gh = map.value(QStringLiteral("height")).toInt() > 0
                           ? map.value(QStringLiteral("height")).toInt()
                           : quickWin->height();

        if (gw <= 0 || gh <= 0) {
            continue;
        }

        const qreal dpr = shot.devicePixelRatio() > 0.0
                              ? shot.devicePixelRatio()
                              : qMax<qreal>(1.0, quickWin->devicePixelRatio());
        maxDpr = std::max(maxDpr, dpr);

        minX = std::min(minX, gx);
        minY = std::min(minY, gy);
        maxX = std::max(maxX, gx + gw);
        maxY = std::max(maxY, gy + gh);

        grabbed.push_back(GrabbedOutput{std::move(shot), gx, gy, gw, gh});
    }

    if (grabbed.empty()) {
        return makeResult(false, QString(), 0, 0, false, QStringLiteral("No valid outputs available to capture"));
    }

    const int logicalW = maxX - minX;
    const int logicalH = maxY - minY;
    const int canvasW = qRound(logicalW * maxDpr);
    const int canvasH = qRound(logicalH * maxDpr);
    if (canvasW <= 0 || canvasH <= 0) {
        return makeResult(false, QString(), 0, 0, false, QStringLiteral("Invalid composite output dimensions"));
    }

    QImage composite(canvasW, canvasH, QImage::Format_ARGB32_Premultiplied);
    composite.fill(QColor(13, 15, 16));

    QPainter painter(&composite);
    painter.setRenderHint(QPainter::SmoothPixmapTransform, true);
    for (const GrabbedOutput &out : grabbed) {
        const QRect targetRect(
            qRound((out.x - minX) * maxDpr),
            qRound((out.y - minY) * maxDpr),
            qRound(out.width * maxDpr),
            qRound(out.height * maxDpr));
        painter.drawImage(targetRect, out.image);
    }
    painter.end();

    composite.setDevicePixelRatio(1.0);
    return finalizeCapture(composite, saveToDisk, copyToClipboard);
}

QString ScreenshotHelper::resolveScreenshotsDir() const
{
    QString picturesDir = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation);
    if (picturesDir.isEmpty()) {
        picturesDir = QDir::homePath() + QStringLiteral("/Pictures");
    }
    return picturesDir + QStringLiteral("/Screenshots");
}

QString ScreenshotHelper::generateUniqueFilePath(const QString &dirPath) const
{
    const QString stamp = QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd_HHmmss"));
    const QString base = dirPath + QStringLiteral("/ascii-de_") + stamp;
    QString candidate = base + QStringLiteral(".png");
    int suffix = 1;
    while (QFileInfo::exists(candidate)) {
        candidate = QStringLiteral("%1_%2.png").arg(base).arg(suffix);
        ++suffix;
    }
    return candidate;
}

bool ScreenshotHelper::copyPngToWaylandClipboard(const QByteArray &pngBytes)
{
    if (pngBytes.isEmpty()) {
        return false;
    }

    const QString wlCopyExe = QStandardPaths::findExecutable(QStringLiteral("wl-copy"));
    if (wlCopyExe.isEmpty()) {
        return false;
    }

    QString socket = m_waylandSocket.trimmed();
    if (socket.isEmpty()) {
        socket = qEnvironmentVariable("WAYLAND_DISPLAY").trimmed();
    }
    if (socket.isEmpty()) {
        return false;
    }

    auto *proc = new QProcess(this);
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert(QStringLiteral("WAYLAND_DISPLAY"), socket);
    env.remove(QStringLiteral("DISPLAY"));
    proc->setProcessEnvironment(env);
    proc->setStandardOutputFile(QProcess::nullDevice());
    proc->setStandardErrorFile(QProcess::nullDevice());

    connect(proc, &QProcess::started, proc, [proc, pngBytes]() {
        proc->write(pngBytes);
        proc->closeWriteChannel();
    });
    connect(proc, &QProcess::finished, proc, [proc](int, QProcess::ExitStatus) {
        proc->deleteLater();
    });
    connect(proc, &QProcess::errorOccurred, proc, [proc](QProcess::ProcessError error) {
        qWarning("ascii-de-compositor: wl-copy failed (%d): %s",
                 static_cast<int>(error),
                 qPrintable(proc->errorString()));
        if (proc->state() == QProcess::NotRunning) {
            proc->deleteLater();
        }
    });

    // Launch asynchronously so the compositor event loop keeps serving the Wayland clipboard handshake.
    proc->start(wlCopyExe, {QStringLiteral("--type"), QStringLiteral("image/png")});
    return true;
}

QVariantMap ScreenshotHelper::finalizeCapture(const QImage &image, bool saveToDisk, bool copyToClipboard)
{
    if (image.isNull()) {
        return makeResult(false, QString(), 0, 0, false, QStringLiteral("Captured image is null"));
    }

    QByteArray pngBytes;
    if (saveToDisk || copyToClipboard) {
        QBuffer buffer(&pngBytes);
        buffer.open(QIODevice::WriteOnly);
        if (!image.save(&buffer, "PNG")) {
            return makeResult(false, QString(), image.width(), image.height(), false,
                              QStringLiteral("Failed to encode PNG image"));
        }
    }

    QString savedPath;
    if (saveToDisk) {
        const QString dirPath = resolveScreenshotsDir();
        if (!QDir().mkpath(dirPath)) {
            return makeResult(false, QString(), image.width(), image.height(), false,
                              QStringLiteral("Failed to create screenshots directory: ") + dirPath);
        }

        savedPath = generateUniqueFilePath(dirPath);
        QSaveFile file(savedPath);
        if (!file.open(QIODevice::WriteOnly)) {
            return makeResult(false, QString(), image.width(), image.height(), false,
                              QStringLiteral("Failed to open screenshot file for writing: ") + file.errorString());
        }
        if (file.write(pngBytes) != pngBytes.size() || !file.commit()) {
            return makeResult(false, QString(), image.width(), image.height(), false,
                              QStringLiteral("Failed to write screenshot file: ") + file.errorString());
        }
    }

    bool clipboardCopied = false;
    if (copyToClipboard) {
        if (QClipboard *cb = QGuiApplication::clipboard()) {
            cb->setImage(image);
            clipboardCopied = true;
        }
        if (copyPngToWaylandClipboard(pngBytes)) {
            clipboardCopied = true;
        }
    }

    return makeResult(true, savedPath, image.width(), image.height(), clipboardCopied, QString());
}
