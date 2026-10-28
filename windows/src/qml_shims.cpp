#include "qml_shims.hpp"
#include "lenovo_hal.hpp"
#include <QFileDialog>
#include <QPainter>
#include <QProcess>
#include <QDir>
#include <QFile>
#include <QTimer>
#include <QDebug>

// -----------------------------------------------------------------------------
// StdioCollectorShim
// -----------------------------------------------------------------------------
StdioCollectorShim::StdioCollectorShim(QObject *parent) : QObject(parent) {}

void StdioCollectorShim::setText(const QString &t) {
    if (m_text != t) {
        m_text = t;
        emit textChanged();
    }
}

void StdioCollectorShim::deliver(const QString &data) {
    m_text = data;
    emit textChanged();
    emit streamFinished();
}

// -----------------------------------------------------------------------------
// ProcessShim
// -----------------------------------------------------------------------------
ProcessShim::ProcessShim(QObject *parent) : QObject(parent) {}

void ProcessShim::setCommand(const QStringList &cmd) {
    if (m_command != cmd) {
        m_command = cmd;
        emit commandChanged();
    }
}

void ProcessShim::setRunning(bool r) {
    if (m_running != r) {
        m_running = r;
        emit runningChanged();
        if (m_running) {
            execute();
        }
    }
}

void ProcessShim::setStdOut(QObject *obj) {
    m_stdOut = qobject_cast<StdioCollectorShim *>(obj);
    emit stdOutChanged();
}

void ProcessShim::setStdErr(QObject *obj) {
    m_stdErr = obj;
    emit stdErrChanged();
}

void ProcessShim::execute() {
    qDebug() << "[ProcessShim Execute]" << m_command;

    QString joined = m_command.join(" ");

    // Case 1: Fan curve query
    if (joined.contains("fancurve") && joined.contains("get")) {
        QString json = LenovoHal::instance().getFanCurveJson();
        if (m_stdOut) {
            m_stdOut->deliver(json);
        }
        QTimer::singleShot(10, this, [this]() {
            emit exited(0, 0);
            m_running = false;
            emit runningChanged();
        });
        return;
    }

    // Case 2: Boot logo status query
    if (joined.contains("bootlogo") && joined.contains("status")) {
        QString json = LenovoHal::instance().getBootLogoStatusJson();
        if (m_stdOut) {
            m_stdOut->deliver(json);
        }
        QTimer::singleShot(10, this, [this]() {
            emit exited(0, 0);
            m_running = false;
            emit runningChanged();
        });
        return;
    }

    // Case 3: File selection dialog
    if (joined.contains("zenity") || joined.contains("--file-selection")) {
        QTimer::singleShot(50, this, [this]() {
            QString selected = QFileDialog::getOpenFileName(nullptr,
                                                           "Select Boot Logo Image",
                                                           QString(),
                                                           "Image files (*.png *.jpg *.jpeg *.bmp *.gif)");
            if (!selected.isEmpty() && m_stdOut) {
                m_stdOut->deliver(selected);
            }
            emit exited(0, 0);
            m_running = false;
            emit runningChanged();
        });
        return;
    }

    // Case 4: Boot logo set
    if (joined.contains("bootlogo") && joined.contains("set")) {
        QString path = m_command.last();
        int res = LenovoHal::instance().setBootLogo(path);
        QTimer::singleShot(20, this, [this, res]() {
            emit exited(res, 0);
            m_running = false;
            emit runningChanged();
        });
        return;
    }

    // Case 5: Boot logo reset
    if (joined.contains("bootlogo") && joined.contains("reset")) {
        int res = LenovoHal::instance().resetBootLogo();
        QTimer::singleShot(20, this, [this, res]() {
            emit exited(res, 0);
            m_running = false;
            emit runningChanged();
        });
        return;
    }

    // Case 6: Fallback generic QProcess
    if (m_command.isEmpty()) {
        m_running = false;
        emit runningChanged();
        return;
    }

    QProcess *proc = new QProcess(this);
    QString prog = m_command.first();
    QStringList args = m_command.mid(1);

    connect(proc, &QProcess::finished, this, [this, proc](int exitCode, QProcess::ExitStatus exitStatus) {
        if (m_stdOut) {
            m_stdOut->deliver(QString::fromUtf8(proc->readAllStandardOutput()));
        }
        emit exited(exitCode, exitStatus == QProcess::NormalExit ? 0 : 1);
        m_running = false;
        emit runningChanged();
        proc->deleteLater();
    });

    proc->start(prog, args);
}

// -----------------------------------------------------------------------------
// FileViewShim
// -----------------------------------------------------------------------------
FileViewShim::FileViewShim(QObject *parent) : QObject(parent) {
    connect(&LenovoHal::instance(), &LenovoHal::statusUpdated, this, [this]() {
        if (m_watchChanges) {
            reload();
        }
    });
}

void FileViewShim::setPath(const QString &p) {
    if (m_path != p) {
        m_path = p;
        emit pathChanged();
        reload();
    }
}

void FileViewShim::setWatchChanges(bool w) {
    if (m_watchChanges != w) {
        m_watchChanges = w;
        emit watchChangesChanged();
    }
}

void FileViewShim::reload() {
    if (m_path.contains("lenovo-power-status.json")) {
        m_cachedContent = LenovoHal::instance().getStatusJson();
    } else {
        QFile f(m_path);
        if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            m_cachedContent = QString::fromUtf8(f.readAll());
            f.close();
        }
    }
    emit fileChanged();
    emit loaded();
}

QString FileViewShim::text() {
    if (m_cachedContent.isEmpty()) {
        reload();
    }
    return m_cachedContent;
}

// -----------------------------------------------------------------------------
// QuickshellShim
// -----------------------------------------------------------------------------
QuickshellShim::QuickshellShim(QObject *parent) : QObject(parent) {}

void QuickshellShim::execDetached(const QStringList &args) {
    LenovoHal::instance().handleCommand(args);
}

QString QuickshellShim::env(const QString &varName, const QString &fallback) {
    return qEnvironmentVariable(varName.toUtf8().constData(), fallback);
}

QString QuickshellShim::shellPath(const QString &subpath) {
    return "qrc:/" + subpath;
}

QString QuickshellShim::iconPath(const QString &name, const QString &fallback) {
    Q_UNUSED(name);
    return fallback;
}

// -----------------------------------------------------------------------------
// IconImageShim
// -----------------------------------------------------------------------------
IconImageShim::IconImageShim(QQuickItem *parent) : QQuickPaintedItem(parent) {}

void IconImageShim::setSource(const QUrl &src) {
    if (m_source != src) {
        m_source = src;
        emit sourceChanged();
        QString path = m_source.isLocalFile() ? m_source.toLocalFile() : m_source.toString();
        if (path.startsWith("qrc:")) {
            path = path.mid(3);
        }
        m_image.load(path);
        update();
    }
}

void IconImageShim::setImplicitSize(qreal size) {
    if (m_implicitSize != size) {
        m_implicitSize = size;
        emit implicitSizeChanged();
        setImplicitWidth(size);
        setImplicitHeight(size);
    }
}

void IconImageShim::paint(QPainter *painter) {
    if (!m_image.isNull()) {
        painter->setRenderHint(QPainter::SmoothPixmapTransform, true);
        painter->drawImage(boundingRect(), m_image);
    }
}
