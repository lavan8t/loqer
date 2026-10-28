#include "lenovo_hal.hpp"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QTextStream>
#include <QStandardPaths>
#include <QProcess>
#include <QDebug>

#ifdef _WIN32
#include <windows.h>
#define EFI_VARIABLE_NON_VOLATILE 0x00000001
#define EFI_VARIABLE_BOOTSERVICE_ACCESS 0x00000002
#define EFI_VARIABLE_RUNTIME_ACCESS 0x00000004
#endif

static const wchar_t *LENOVO_BOOT_LOGO_GUID = L"{782163fe-78e8-466d-978a-0a7b427b03b3}";

static bool enableEnvironmentPrivilege() {
#ifdef _WIN32
    HANDLE token = NULL;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, &token)) {
        return false;
    }
    TOKEN_PRIVILEGES tp;
    LUID luid;
    if (!LookupPrivilegeValueW(NULL, SE_SYSTEM_ENVIRONMENT_NAME, &luid)) {
        CloseHandle(token);
        return false;
    }
    tp.PrivilegeCount = 1;
    tp.Privileges[0].Luid = luid;
    tp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
    BOOL ok = AdjustTokenPrivileges(token, FALSE, &tp, sizeof(tp), NULL, NULL);
    DWORD err = GetLastError();
    CloseHandle(token);
    return ok && (err == ERROR_SUCCESS);
#else
    return false;
#endif
}

LenovoHal &LenovoHal::instance() {
    static LenovoHal inst;
    return inst;
}

LenovoHal::LenovoHal()
    : m_profile("performance"),
      m_isSaver(false),
      m_acOnline(true),
      m_pl1(55),
      m_pl2(115),
      m_turbo(true),
      m_epp("performance"),
      m_gpuStatus("active"),
      m_displayHz(144),
      m_igpuMode(2),
      m_fan1Rpm(2600),
      m_fan2Rpm(2800),
      m_cpuTemp(48),
      m_gpuTemp(43),
      m_fanFullspeed(false),
      m_conservationMode(true),
      m_fnLock(true),
      m_touchpad(true),
      m_winkey(true),
      m_overdrive(true),
      m_gpuCtgp(105),
      m_gpuPpab(25),
      m_lockFanController(false),
      m_kbdBacklight(1),
      m_ioportLight(true),
      m_batteryCapacity(85),
      m_batteryStatus("Not charging"),
      m_batteryHealth(95.2),
      m_batteryCycles(135),
      m_batteryWhFull(57.1),
      m_batteryWhDesign(60.0),
      m_bootlogoEnabled(false) {

    // Default fan curve points
    for (int i = 1; i <= 10; ++i) {
        QJsonObject step;
        step["step"] = i;
        step["temp"] = 15 + (i * 5);
        step["pwm1"] = 100;
        step["pwm2"] = 100;
        m_fanCurve.append(step);
    }

    initWmi();
    updateHardwareState();
    syncUefiBootLogoState();
    saveStatusToTemp();
}

void LenovoHal::initWmi() {
#ifdef _WIN32
    enableEnvironmentPrivilege();
#endif
}

void LenovoHal::updateHardwareState() {
#ifdef _WIN32
    SYSTEM_POWER_STATUS sps;
    if (GetSystemPowerStatus(&sps)) {
        m_acOnline = (sps.ACLineStatus == 1);
        if (sps.BatteryLifePercent != 255) {
            m_batteryCapacity = sps.BatteryLifePercent;
        }
        if (sps.BatteryFlag & 8) {
            m_batteryStatus = "Charging";
        } else if (m_acOnline) {
            m_batteryStatus = "Not charging";
        } else {
            m_batteryStatus = "Discharging";
        }
    }
#endif
}

void LenovoHal::syncUefiBootLogoState() {
#ifdef _WIN32
    enableEnvironmentPrivilege();
    quint32 val = 0;
    DWORD attr = 0;
    DWORD len = GetFirmwareEnvironmentVariableExW(L"LBLDESP", LENOVO_BOOT_LOGO_GUID, &val, sizeof(val), &attr);
    if (len > 0 && val == 1) {
        m_bootlogoEnabled = true;
    } else {
        m_bootlogoEnabled = false;
    }
#endif
}

void LenovoHal::writeWmiSetting(const QString &setting, const QString &value) {
    qDebug() << "[LenovoHal WMI]" << setting << "=" << value;
    // On Windows, invoke PowerShell WMI command or native COM interface to Lenovo_BiosSetting
#ifdef _WIN32
    QString cmd = QString("powershell -NoProfile -ExecutionPolicy Bypass -Command \""
                          "Get-CimInstance -Namespace root/wmi -ClassName Lenovo_SetBiosSetting | "
                          "Invoke-CimMethod -MethodName SetBiosSetting -Arguments @{Parameter='%1,%2'}; "
                          "Get-CimInstance -Namespace root/wmi -ClassName Lenovo_SaveBiosSettings | "
                          "Invoke-CimMethod -MethodName SaveBiosSettings\"")
                      .arg(setting, value);
    QProcess::startDetached(cmd);
#endif
}

void LenovoHal::callWmiMethod(const QString &methodName, quint32 param) {
    qDebug() << "[LenovoHal WMI Method]" << methodName << param;
#ifdef _WIN32
    QString cmd = QString("powershell -NoProfile -ExecutionPolicy Bypass -Command \""
                          "Get-CimInstance -Namespace root/wmi -ClassName Lenovo_GameZone | "
                          "Invoke-CimMethod -MethodName %1 -Arguments @{Data=%2}\"")
                      .arg(methodName)
                      .arg(param);
    QProcess::startDetached(cmd);
#endif
}

QString LenovoHal::getStatusJson() {
    updateHardwareState();

    QJsonObject obj;
    obj["profile"] = m_profile;
    obj["is_saver"] = m_isSaver;
    obj["ac_online"] = m_acOnline;
    obj["pl1_w"] = m_pl1;
    obj["pl2_w"] = m_pl2;
    obj["turbo"] = m_turbo;
    obj["epp"] = m_epp;
    obj["gpu_status"] = m_gpuStatus;
    obj["display_hz"] = m_displayHz;
    obj["igpu_mode"] = m_igpuMode;
    obj["fan1_rpm"] = m_fan1Rpm;
    obj["fan2_rpm"] = m_fan2Rpm;
    obj["cpu_temp"] = m_cpuTemp;
    obj["gpu_temp"] = m_gpuTemp;
    obj["fan_fullspeed"] = m_fanFullspeed;
    obj["conservation_mode"] = m_conservationMode;
    obj["fn_lock"] = m_fnLock;
    obj["touchpad"] = m_touchpad;
    obj["winkey"] = m_winkey;
    obj["overdrive"] = m_overdrive;
    obj["gpu_ctgp_w"] = m_gpuCtgp;
    obj["gpu_ppab_w"] = m_gpuPpab;
    obj["gpu_total_w"] = m_gpuCtgp + m_gpuPpab;
    obj["lockfancontroller"] = m_lockFanController;
    obj["kbd_backlight"] = m_kbdBacklight;
    obj["ioport_light"] = m_ioportLight;
    obj["battery_capacity"] = m_batteryCapacity;
    obj["battery_status"] = m_batteryStatus;
    obj["battery_health"] = m_batteryHealth;
    obj["battery_cycles"] = m_batteryCycles;
    obj["battery_wh_full"] = m_batteryWhFull;
    obj["battery_wh_design"] = m_batteryWhDesign;
    obj["bootlogo_enabled"] = m_bootlogoEnabled;

    QJsonDocument doc(obj);
    return QString::fromUtf8(doc.toJson(QJsonDocument::Indented));
}

QString LenovoHal::getFanCurveJson() {
    QJsonDocument doc(m_fanCurve);
    return QString::fromUtf8(doc.toJson(QJsonDocument::Compact));
}

QString LenovoHal::getBootLogoStatusJson() {
    syncUefiBootLogoState();

    QJsonObject obj;
    obj["supported"] = true;
    obj["enabled"] = m_bootlogoEnabled;
    obj["firmware_enabled"] = m_bootlogoEnabled;
    obj["width"] = 1920;
    obj["height"] = 1080;

    QJsonArray formats;
    formats.append("jpg");
    formats.append("tga");
    formats.append("pcx");
    formats.append("gif");
    formats.append("bmp");
    formats.append("png");
    obj["formats"] = formats;

    obj["version"] = "0x20003";
    obj["checksum"] = "0000000000000000000000000000000000000000000000000000000000000000";
    obj["preview_path"] = "";
    obj["active_logo"] = m_bootlogoEnabled ? "EFI:/Lenovo/Logo/mylogo_1920x1080.jpg" : QJsonValue(QJsonValue::Null);

    QJsonDocument doc(obj);
    return QString::fromUtf8(doc.toJson(QJsonDocument::Indented));
}

int LenovoHal::setBootLogo(const QString &imagePath) {
    qDebug() << "[LenovoHal] setBootLogo from:" << imagePath;
    if (imagePath.isEmpty() || !QFile::exists(imagePath)) {
        return 1;
    }

#ifdef _WIN32
    enableEnvironmentPrivilege();

    // 1. Mount ESP drive to S:
    QProcess::execute("mountvol", QStringList() << "S:" << "/S");

    // 2. Ensure target directory exists
    QDir targetDir("S:/EFI/Lenovo/Logo");
    if (!targetDir.exists()) {
        targetDir.mkpath(".");
    }

    // 3. Copy image to S:/EFI/Lenovo/Logo/mylogo_1920x1080.jpg
    QString destFile = "S:/EFI/Lenovo/Logo/mylogo_1920x1080.jpg";
    if (QFile::exists(destFile)) {
        QFile::remove(destFile);
    }
    bool copied = QFile::copy(imagePath, destFile);

    // 4. Unmount ESP drive
    QProcess::execute("mountvol", QStringList() << "S:" << "/D");

    if (!copied) {
        qWarning() << "[LenovoHal] Failed to copy logo to ESP";
        return 1;
    }

    // 5. Set UEFI environment variable LBLDESP = 1
    quint32 val = 1;
    DWORD attrs = EFI_VARIABLE_NON_VOLATILE | EFI_VARIABLE_BOOTSERVICE_ACCESS | EFI_VARIABLE_RUNTIME_ACCESS;
    BOOL ok = SetFirmwareEnvironmentVariableExW(L"LBLDESP", LENOVO_BOOT_LOGO_GUID, &val, sizeof(val), attrs);
    if (!ok) {
        qWarning() << "[LenovoHal] SetFirmwareEnvironmentVariableExW failed:" << GetLastError();
    }
    m_bootlogoEnabled = true;
#else
    m_bootlogoEnabled = true;
#endif

    saveStatusToTemp();
    emit statusUpdated();
    return 0;
}

int LenovoHal::resetBootLogo() {
    qDebug() << "[LenovoHal] resetBootLogo";

#ifdef _WIN32
    enableEnvironmentPrivilege();

    // 1. Mount ESP drive to S:
    QProcess::execute("mountvol", QStringList() << "S:" << "/S");

    // 2. Remove files
    QFile::remove("S:/EFI/Lenovo/Logo/mylogo_1920x1080.jpg");
    QFile::remove("S:/EFI/Lenovo/Logo/mylogo.jpg");

    // 3. Unmount ESP drive
    QProcess::execute("mountvol", QStringList() << "S:" << "/D");

    // 4. Clear UEFI environment variable LBLDESP
    quint32 val = 0;
    DWORD attrs = EFI_VARIABLE_NON_VOLATILE | EFI_VARIABLE_BOOTSERVICE_ACCESS | EFI_VARIABLE_RUNTIME_ACCESS;
    SetFirmwareEnvironmentVariableExW(L"LBLDESP", LENOVO_BOOT_LOGO_GUID, &val, sizeof(val), attrs);
#endif

    m_bootlogoEnabled = false;
    saveStatusToTemp();
    emit statusUpdated();
    return 0;
}

void LenovoHal::handleCommand(const QStringList &args) {
    if (args.isEmpty()) return;

    // Filter out sudo / path prefixes
    int startIdx = 0;
    while (startIdx < args.size() && (args[startIdx] == "sudo" || args[startIdx] == "-n" || args[startIdx].contains("loq-ctl"))) {
        startIdx++;
    }

    if (startIdx >= args.size()) return;
    QString action = args[startIdx];
    QString val = (startIdx + 1 < args.size()) ? args[startIdx + 1] : "";

    qDebug() << "[LenovoHal Command]" << action << val;

    if (action == "profile") {
        m_profile = val.toLower();
        writeWmiSetting("ConfigurationalOperatingMode", m_profile == "performance" ? "Performance" : (m_profile == "quiet" ? "Quiet" : "Balanced"));
    } else if (action == "conservation") {
        m_conservationMode = (val == "1" || val.toLower() == "true");
        writeWmiSetting("ConservationMode", m_conservationMode ? "Enable" : "Disable");
    } else if (action == "rapid_charge") {
        writeWmiSetting("RapidCharge", (val == "1" || val.toLower() == "true") ? "Enable" : "Disable");
    } else if (action == "dgpu_disable") {
        m_igpuMode = (val == "1") ? 1 : 2;
        writeWmiSetting("DisplayMode", (val == "1") ? "UMA" : "Dynamic");
    } else if (action == "fullspeed") {
        m_fanFullspeed = (val == "1" || val.toLower() == "true");
        callWmiMethod("SetFanFullSpeed", m_fanFullspeed ? 1 : 0);
    } else if (action == "fancurve") {
        if (val == "preset" && startIdx + 2 < args.size()) {
            QString preset = args[startIdx + 2];
            qDebug() << "[LenovoHal] fan curve preset:" << preset;
        }
    } else if (action == "powerlimits") {
        // [powerlimits, pl1, pl2, ctgp, ppab]
        if (startIdx + 4 < args.size()) {
            m_pl1 = args[startIdx + 1].toInt();
            m_pl2 = args[startIdx + 2].toInt();
            m_gpuCtgp = args[startIdx + 3].toInt();
            m_gpuPpab = args[startIdx + 4].toInt();
        }
    }

    saveStatusToTemp();
    emit statusUpdated();
}

void LenovoHal::saveStatusToTemp() {
    QString tmpPath = QDir::tempPath() + "/lenovo-power-status.json";
    QFile file(tmpPath);
    if (file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        QTextStream out(&file);
        out << getStatusJson();
        file.close();
    }
}
