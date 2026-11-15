#pragma once

#include <QImage>
#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

class ScreenshotHelper : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString waylandSocket READ waylandSocket WRITE setWaylandSocket NOTIFY waylandSocketChanged)

public:
    explicit ScreenshotHelper(QObject *parent = nullptr);
    ~ScreenshotHelper() override = default;

    [[nodiscard]] QString waylandSocket() const;
    void setWaylandSocket(const QString &socket);

    Q_INVOKABLE QVariantMap captureWindow(
        QObject *windowObj,
        int cropX,
        int cropY,
        int cropW,
        int cropH,
        bool saveToDisk,
        bool copyToClipboard);

    Q_INVOKABLE QVariantMap captureAllOutputs(
        const QVariantList &outputRecords,
        bool saveToDisk,
        bool copyToClipboard);

signals:
    void waylandSocketChanged();

private:
    [[nodiscard]] QVariantMap finalizeCapture(const QImage &image, bool saveToDisk, bool copyToClipboard);
    [[nodiscard]] QString resolveScreenshotsDir() const;
    [[nodiscard]] QString generateUniqueFilePath(const QString &dirPath) const;
    bool copyPngToWaylandClipboard(const QByteArray &pngBytes);

    static QVariantMap makeResult(
        bool ok,
        const QString &path,
        int width,
        int height,
        bool clipboardCopied,
        const QString &error);

    QString m_waylandSocket = QStringLiteral("wayland-ascii-0");
};
