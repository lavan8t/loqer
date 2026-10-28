#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QPointer>
#include <QUrl>
#include <QImage>
#include <QQuickPaintedItem>

#ifdef stdout
#undef stdout
#endif
#ifdef stderr
#undef stderr
#endif
#ifdef stdin
#undef stdin
#endif

class StdioCollectorShim : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString text READ text WRITE setText NOTIFY textChanged)

public:
    explicit StdioCollectorShim(QObject *parent = nullptr);

    QString text() const { return m_text; }
    void setText(const QString &t);
    void deliver(const QString &data);

signals:
    void textChanged();
    void streamFinished();

private:
    QString m_text;
};

class ProcessShim : public QObject {
    Q_OBJECT
    Q_PROPERTY(QStringList command READ command WRITE setCommand NOTIFY commandChanged)
    Q_PROPERTY(bool running READ isRunning WRITE setRunning NOTIFY runningChanged)
    Q_PROPERTY(QObject *stdout READ stdOut WRITE setStdOut NOTIFY stdOutChanged)
    Q_PROPERTY(QObject *stderr READ stdErr WRITE setStdErr NOTIFY stdErrChanged)

public:
    explicit ProcessShim(QObject *parent = nullptr);

    QStringList command() const { return m_command; }
    void setCommand(const QStringList &cmd);

    bool isRunning() const { return m_running; }
    void setRunning(bool r);

    QObject *stdOut() const { return m_stdOut; }
    void setStdOut(QObject *obj);

    QObject *stdErr() const { return m_stdErr; }
    void setStdErr(QObject *obj);

signals:
    void commandChanged();
    void runningChanged();
    void stdOutChanged();
    void stdErrChanged();
    void exited(int exitCode, int exitStatus);

private:
    void execute();

    QStringList m_command;
    bool m_running = false;
    QPointer<StdioCollectorShim> m_stdOut;
    QPointer<QObject> m_stdErr;
};

class FileViewShim : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString path READ path WRITE setPath NOTIFY pathChanged)
    Q_PROPERTY(bool watchChanges READ watchChanges WRITE setWatchChanges NOTIFY watchChangesChanged)

public:
    explicit FileViewShim(QObject *parent = nullptr);

    QString path() const { return m_path; }
    void setPath(const QString &p);

    bool watchChanges() const { return m_watchChanges; }
    void setWatchChanges(bool w);

    Q_INVOKABLE void reload();
    Q_INVOKABLE QString text();

signals:
    void pathChanged();
    void watchChangesChanged();
    void fileChanged();
    void loaded();

private:
    QString m_path;
    bool m_watchChanges = true;
    QString m_cachedContent;
};

class QuickshellShim : public QObject {
    Q_OBJECT

public:
    explicit QuickshellShim(QObject *parent = nullptr);

    Q_INVOKABLE void execDetached(const QStringList &args);
    Q_INVOKABLE QString env(const QString &varName, const QString &fallback = QString());
    Q_INVOKABLE QString shellPath(const QString &subpath);
    Q_INVOKABLE QString iconPath(const QString &name, const QString &fallback = QString());
};

class IconImageShim : public QQuickPaintedItem {
    Q_OBJECT
    Q_PROPERTY(QUrl source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(qreal implicitSize READ implicitSize WRITE setImplicitSize NOTIFY implicitSizeChanged)

public:
    explicit IconImageShim(QQuickItem *parent = nullptr);

    QUrl source() const { return m_source; }
    void setSource(const QUrl &src);

    qreal implicitSize() const { return m_implicitSize; }
    void setImplicitSize(qreal size);

    void paint(QPainter *painter) override;

signals:
    void sourceChanged();
    void implicitSizeChanged();

private:
    QUrl m_source;
    qreal m_implicitSize = 0;
    QImage m_image;
};
