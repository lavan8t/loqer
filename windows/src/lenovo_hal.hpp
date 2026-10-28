#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonDocument>

class LenovoHal : public QObject {
    Q_OBJECT
public:
    static LenovoHal &instance();

    QString getStatusJson();
    QString getFanCurveJson();
    QString getBootLogoStatusJson();

    int setBootLogo(const QString &imagePath);
    int resetBootLogo();

    void handleCommand(const QStringList &args);
    void updateHardwareState();

signals:
    void statusUpdated();

private:
    LenovoHal();
    void initWmi();
    void writeWmiSetting(const QString &setting, const QString &value);
    void callWmiMethod(const QString &methodName, quint32 param);
    void saveStatusToTemp();
    void syncUefiBootLogoState();

    // Internal state matching lenovo-power-status.json
    QString m_profile;
    bool m_isSaver;
    bool m_acOnline;
    int m_pl1;
    int m_pl2;
    bool m_turbo;
    QString m_epp;
    QString m_gpuStatus;
    int m_displayHz;
    int m_igpuMode;
    int m_fan1Rpm;
    int m_fan2Rpm;
    int m_cpuTemp;
    int m_gpuTemp;
    bool m_fanFullspeed;
    bool m_conservationMode;
    bool m_fnLock;
    bool m_touchpad;
    bool m_winkey;
    bool m_overdrive;
    int m_gpuCtgp;
    int m_gpuPpab;
    bool m_lockFanController;
    int m_kbdBacklight;
    bool m_ioportLight;
    int m_batteryCapacity;
    QString m_batteryStatus;
    double m_batteryHealth;
    int m_batteryCycles;
    double m_batteryWhFull;
    double m_batteryWhDesign;
    bool m_bootlogoEnabled;

    QJsonArray m_fanCurve;
};
