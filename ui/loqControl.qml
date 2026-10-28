//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "./modules/common"
import "./modules/common/widgets"
import "./modules/common/functions" as CF
import "./services"

ApplicationWindow {
    id: root
    property real contentPadding: 8
    visible: true
    onClosing: Qt.quit()
    title: "LOQer"

    FontLoader {
        id: fontGoogleSans
        source: Qt.resolvedUrl("fonts/GoogleSansFlex.ttf")
    }

    Component.onCompleted: {
        console.log("LOQer GoogleSans font loaded:", fontGoogleSans.name, "status:", fontGoogleSans.status);
        MaterialThemeLoader.reapplyTheme();
        loadCurveProc.running = true;
        bootlogoStatusProc.running = true;
        root.reloadStatus();
    }

    minimumWidth: 840
    minimumHeight: 580
    width: 1040
    height: 720
    color: Appearance.m3colors.m3background

    // Navigation Pages definition
    property var pages: [
        {
            name: "Power & GPU",
            icon: "speed",
            component: powerPage
        },
        {
            name: "Fan Curves",
            icon: "air",
            component: curvesPage
        },
        {
            name: "Hardware",
            icon: "tune",
            component: hardwarePage
        }
    ]
    property int currentPage: 0

    // Live status data
    property var statusData: ({
        profile: "balanced",
        is_saver: false,
        ac_online: true,
        pl1_w: 55,
        pl2_w: 115,
        turbo: true,
        epp: "balance_performance",
        gpu_status: "active",
        display_hz: 144,
        igpu_mode: 2,
        fan1_rpm: 0,
        fan2_rpm: 0,
        cpu_temp: 40,
        gpu_temp: 35,
        fan_fullspeed: false,
        conservation_mode: false,
        fn_lock: false,
        touchpad: true,
        winkey: true,
        overdrive: false,
        gpu_ctgp_w: 105,
        gpu_ppab_w: 25,
        gpu_total_w: 130,
        lockfancontroller: false,
        kbd_backlight: 1,
        ioport_light: true,
        battery_capacity: 76,
        battery_status: "Not charging",
        battery_health: 95.2,
        battery_cycles: 135,
        battery_wh_full: 57.1,
        battery_wh_design: 60.0
    })

    // GodMode Power Tuning temporary sliders
    property int sliderPl1: 55
    property int sliderPl2: 115
    property int sliderCtgp: 105
    property int sliderPpab: 25
    property bool powerLimitsFeedback: false
    property bool initializedLimits: false

    // Boot Logo state
    property var bootlogoInfo: ({
        "supported": true,
        "enabled": false,
        "width": 1920,
        "height": 1080,
        "preview_path": "",
        "active_logo": null
    })
    property string selectedBootLogoPath: ""
    property bool bootlogoApplying: false
    property bool bootlogoFeedback: false
    property bool bootlogoFeedbackSuccess: true
    property string bootlogoFeedbackMsg: ""

    // Fan curve interactive state
    property var curvePoints: [
        {"step": 1, "temp": 45, "pwm1": 20, "pwm2": 25},
        {"step": 2, "temp": 52, "pwm1": 30, "pwm2": 35},
        {"step": 3, "temp": 58, "pwm1": 42, "pwm2": 45},
        {"step": 4, "temp": 65, "pwm1": 55, "pwm2": 55},
        {"step": 5, "temp": 72, "pwm1": 65, "pwm2": 65},
        {"step": 6, "temp": 78, "pwm1": 75, "pwm2": 75},
        {"step": 7, "temp": 84, "pwm1": 85, "pwm2": 85},
        {"step": 8, "temp": 90, "pwm1": 90, "pwm2": 90},
        {"step": 9, "temp": 94, "pwm1": 95, "pwm2": 95},
        {"step": 10, "temp": 98, "pwm1": 100, "pwm2": 100}
    ]
    property int selectedCurveStep: 1
    property string activePresetName: "balanced"
    property bool curveAppliedFeedback: false

    FileView {
        id: statusFile
        path: "/run/user/1000/lenovo-power-status.json"
        watchChanges: true
        onFileChanged: root.reloadStatus()
    }

    Timer {
        id: refreshTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.reloadStatus()
    }

    Process {
        id: loadCurveProc
        command: ["/usr/local/bin/loq-ctl", "fancurve", "get"]
        stdout: StdioCollector {
            id: curveOut
            onStreamFinished: {
                try {
                    let parsed = JSON.parse(curveOut.text.trim());
                    if (Array.isArray(parsed) && parsed.length > 0) {
                        root.curvePoints = parsed;
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        id: feedbackTimer
        interval: 2200
        onTriggered: root.curveAppliedFeedback = false
    }

    Timer {
        id: powerFeedbackTimer
        interval: 2200
        onTriggered: root.powerLimitsFeedback = false
    }

    Timer {
        id: bootlogoFeedbackTimer
        interval: 3500
        onTriggered: root.bootlogoFeedback = false
    }

    Process {
        id: bootlogoStatusProc
        command: ["/usr/local/bin/loq-ctl", "bootlogo", "status", "--json"]
        stdout: StdioCollector {
            id: bootlogoOut
            onStreamFinished: {
                try {
                    let parsed = JSON.parse(bootlogoOut.text.trim());
                    if (parsed && typeof parsed === "object") {
                        root.bootlogoInfo = parsed;
                    }
                } catch(e) {}
            }
        }
    }

    Process {
        id: pickImageProc
        command: ["zenity", "--file-selection", "--title=Select Boot Logo Image", "--file-filter=Image files (PNG, JPG, BMP) | *.png *.jpg *.jpeg *.bmp *.gif"]
        stdout: StdioCollector {
            id: pickOut
            onStreamFinished: {
                let chosen = pickOut.text.trim();
                if (chosen) {
                    root.selectedBootLogoPath = chosen;
                }
            }
        }
    }

    Process {
        id: applyLogoProc
        command: ["/usr/local/bin/loq-ctl", "bootlogo", "set", root.selectedBootLogoPath]
        onExited: (exitCode, exitStatus) => {
            root.bootlogoApplying = false;
            if (exitCode === 0) {
                root.bootlogoFeedbackMsg = "Boot logo successfully applied to UEFI!";
                root.bootlogoFeedbackSuccess = true;
            } else {
                root.bootlogoFeedbackMsg = "Failed to apply boot logo. Check image.";
                root.bootlogoFeedbackSuccess = false;
            }
            root.bootlogoFeedback = true;
            bootlogoFeedbackTimer.restart();
            bootlogoStatusProc.running = true;
            root.reloadStatus();
        }
    }

    Process {
        id: resetLogoProc
        command: ["/usr/local/bin/loq-ctl", "bootlogo", "reset"]
        onExited: (exitCode, exitStatus) => {
            root.bootlogoApplying = false;
            if (exitCode === 0) {
                root.bootlogoFeedbackMsg = "OEM stock Lenovo boot logo restored!";
                root.bootlogoFeedbackSuccess = true;
                root.selectedBootLogoPath = "";
            } else {
                root.bootlogoFeedbackMsg = "Failed to restore stock boot logo.";
                root.bootlogoFeedbackSuccess = false;
            }
            root.bootlogoFeedback = true;
            bootlogoFeedbackTimer.restart();
            bootlogoStatusProc.running = true;
            root.reloadStatus();
        }
    }

    function reloadStatus() {
        try {
            statusFile.reload();
            const txt = statusFile.text().trim();
            if (txt && txt.startsWith("{")) {
                let oldProfile = root.statusData.profile;
                root.statusData = JSON.parse(txt);
                root.statusDataChanged();
                if (oldProfile !== root.statusData.profile) {
                    bigLoqRing.triggerSpin();
                }
                if (!root.initializedLimits) {
                    root.sliderPl1 = root.statusData.pl1_w ?? 55;
                    root.sliderPl2 = root.statusData.pl2_w ?? 115;
                    root.sliderCtgp = root.statusData.gpu_ctgp_w ?? 105;
                    root.sliderPpab = root.statusData.gpu_ppab_w ?? 25;
                    root.initializedLimits = true;
                }
            }
        } catch(e) {}
    }

    function executeCommand(action, val) {
        Quickshell.execDetached(["sudo", "-n", "/usr/local/bin/loq-ctl", action, String(val)]);
        let newStatus = Object.assign({}, root.statusData);
        if (action === "profile") {
            newStatus.profile = val;
            bigLoqRing.triggerSpin();
        } else if (action === "mux") {
            newStatus.igpu_mode = parseInt(val);
        } else if (action === "conservation") {
            newStatus.conservation_mode = (val === "1");
        } else if (action === "fn_lock") {
            newStatus.fn_lock = (val === "1");
        } else if (action === "fan_fullspeed") {
            newStatus.fan_fullspeed = (val === "1");
        } else if (action === "touchpad") {
            newStatus.touchpad = (val === "1");
        } else if (action === "winkey") {
            newStatus.winkey = (val === "1");
        } else if (action === "overdrive") {
            newStatus.overdrive = (val === "1");
        } else if (action === "kbd") {
            newStatus.kbd_backlight = parseInt(val);
        } else if (action === "ioport") {
            newStatus.ioport_light = (val === "1");
        } else if (action === "refresh") {
            newStatus.display_hz = parseInt(val);
        }
        root.statusData = newStatus;
        root.statusDataChanged();
    }

    function applyFanPreset(preset) {
        root.activePresetName = preset;
        Quickshell.execDetached(["sudo", "-n", "/usr/local/bin/loq-ctl", "fancurve", "preset", preset]);
        root.curveAppliedFeedback = true;
        feedbackTimer.restart();
        loadCurveProc.running = true;
    }

    function applyCurrentStep() {
        let pt = root.curvePoints[root.selectedCurveStep - 1];
        if (!pt) return;
        Quickshell.execDetached(["sudo", "-n", "/usr/local/bin/loq-ctl", "fancurve", "set", 
            String(pt.step), String(pt.temp), String(pt.pwm1), String(pt.pwm2)]);
        root.curveAppliedFeedback = true;
        feedbackTimer.restart();
    }

    function applyPowerLimits(pl1, pl2, ctgp, ppab) {
        Quickshell.execDetached(["sudo", "-n", "/usr/local/bin/loq-ctl", "powerlimits", 
            String(pl1), String(pl2), String(ctgp), String(ppab)]);
        root.powerLimitsFeedback = true;
        powerFeedbackTimer.restart();
    }

    function getProfileColor(p) {
        p = (p || "").toLowerCase();
        if (p === "custom" || p === "extreme" || p === "pink") return "#EC4899";
        if (p === "performance" || p === "red") return "#EF4444";
        if (p === "quiet" || p === "low-power" || p === "blue") return "#38BDF8";
        return "#F8FAFC";
    }

    function getProfileName(p) {
        p = (p || "").toLowerCase();
        if (p === "custom" || p === "extreme") return "Custom";
        if (p === "performance") return "Performance";
        if (p === "quiet" || p === "low-power") return "Quiet";
        return "Balanced";
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: root.contentPadding
        }
        spacing: root.contentPadding

        // ══════════════════════════════════════════════════════════════════════
        // TITLEBAR WITH CONTROLS (MATCHING ILLOGICAL-IMPULSE SETTINGS)
        // ══════════════════════════════════════════════════════════════════════
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: false
            implicitHeight: Math.max(titleText.implicitHeight, windowControlsRow.implicitHeight)

            StyledText {
                id: titleText
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: 12
                }
                color: Appearance.colors.colOnLayer0
                text: "LOQer"
                font {
                    family: Appearance.font.family.title
                    pixelSize: Appearance.font.pixelSize.title
                    variableAxes: Appearance.font.variableAxes.title
                }
            }

            RowLayout {
                id: windowControlsRow
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                spacing: 8

                // Close Button
                RippleButton {
                    buttonRadius: Appearance.rounding.full
                    implicitWidth: 35
                    implicitHeight: 35
                    onClicked: root.close()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "close"
                        iconSize: 20
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════════════════
        // MAIN BODY: NAVIGATION RAIL + CONTENT CONTAINER
        // ══════════════════════════════════════════════════════════════════════
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.contentPadding

            // 1. LEFT SIDEBAR (MONOCHROME STATUS TABLE, BIG 20% THICKER RING, NO EXPAND TOGGLE)
            Item {
                id: leftSidebar
                Layout.fillHeight: true
                Layout.preferredWidth: 190
                Layout.minimumWidth: 190
                Layout.maximumWidth: 190

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12

                    // Big 20% Thicker Centered LOQ Ring (Top-aligned, No background fill)
                    Item {
                        id: bigLoqRingWrapper
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 4
                        width: 64
                        height: 64

                        Item {
                            id: bigLoqRing
                            anchors.centerIn: parent
                            width: 64
                            height: 64

                            // 20% thicker rim: (64/2) * 0.3629 = 11.6px
                            property real ringThickness: 11.6
                            property real arcRadius: 32 - (ringThickness / 2)
                            property color ringColor: root.getProfileColor(root.statusData.profile)
                            Behavior on ringColor { ColorAnimation { duration: 250; easing.type: Easing.OutCubic } }

                            Canvas {
                                id: ringCanvas
                                anchors.fill: parent
                                renderTarget: Canvas.Image
                                renderStrategy: Canvas.Immediate

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.reset();
                                    var cx = 32, cy = 32;
                                    var R_out = 32;
                                    var thickness = 11.6;
                                    var R_in = R_out - thickness; // 20.4
                                    var slit_w = 5.6; // Equal slit length at both inner and outer edge

                                    var d_out = Math.asin(Math.min(1.0, (slit_w / 2) / R_out));
                                    var d_in = Math.asin(Math.min(1.0, (slit_w / 2) / R_in));

                                    var midAngles = [30 * Math.PI / 180, 150 * Math.PI / 180, 270 * Math.PI / 180];
                                    var arcSpan = (2 * Math.PI / 3);

                                    ctx.fillStyle = bigLoqRing.ringColor;

                                    for (var i = 0; i < 3; i++) {
                                        var mid = midAngles[i];
                                        var out_s = (mid - arcSpan / 2) + d_out;
                                        var out_e = (mid + arcSpan / 2) - d_out;
                                        var in_s  = (mid - arcSpan / 2) + d_in;
                                        var in_e  = (mid + arcSpan / 2) - d_in;

                                        ctx.beginPath();
                                        ctx.arc(cx, cy, R_out, out_s, out_e, false);
                                        ctx.lineTo(cx + R_in * Math.cos(in_e), cy + R_in * Math.sin(in_e));
                                        ctx.arc(cx, cy, R_in, in_e, in_s, true);
                                        ctx.closePath();
                                        ctx.fill();
                                    }
                                }

                                Connections {
                                    target: bigLoqRing
                                    function onRingColorChanged() { ringCanvas.requestPaint(); }
                                }
                                Component.onCompleted: requestPaint()
                            }

                            RotationAnimation on rotation {
                                id: bigSpinAnim
                                duration: 550
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.15
                                alwaysRunToEnd: true
                            }

                            function triggerSpin() {
                                bigSpinAnim.from = bigLoqRing.rotation;
                                bigSpinAnim.to = bigLoqRing.rotation + 360;
                                bigSpinAnim.restart();
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: bigLoqRing.triggerSpin()
                            }
                        }
                    }

                    // PC Model Name below ring (Centered, No background fill)
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: "LOQ 15IAX9"
                        font {
                            family: Appearance.font.family.title
                            pixelSize: Appearance.font.pixelSize.normal
                            weight: Font.Bold
                        }
                        color: Appearance.colors.colOnSurface
                    }

                    // Status Table below model name (Tabular alignment, Monochrome / uncolored, alternating row tints)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.leftMargin: 2
                        Layout.rightMargin: 2
                        implicitHeight: statusTableCol.implicitHeight
                        radius: Appearance.rounding.small
                        color: Appearance.m3colors.m3surfaceContainer
                        clip: true

                        ColumnLayout {
                            id: statusTableCol
                            anchors.fill: parent
                            spacing: 0

                            Repeater {
                                model: [
                                    { "label": "TGP", "value": `${root.statusData.gpu_total_w ?? 130}W` },
                                    { "label": "PANEL", "value": `${root.statusData.display_hz ?? 144}Hz` },
                                    { "label": "POWER", "value": root.statusData.ac_online ? "AC 230W" : "BATTERY" },
                                    { "label": "PROFILE", "value": root.getProfileName(root.statusData.profile).toUpperCase() },
                                    { "label": "CHARGE", "value": `${root.statusData.battery_capacity ?? 85}%` }
                                ]
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    implicitHeight: 26
                                    color: (index % 2 === 0) ? Appearance.m3colors.m3surfaceContainerHigh : "transparent"

                                    RowLayout {
                                        anchors {
                                            fill: parent
                                            leftMargin: 8
                                            rightMargin: 8
                                        }
                                        StyledText {
                                            text: modelData.label
                                            color: Appearance.colors.colSubtext
                                            font.pixelSize: Appearance.font.pixelSize.smallie
                                            font.weight: Font.DemiBold
                                            Layout.fillWidth: true
                                        }
                                        StyledText {
                                            text: modelData.value
                                            color: Appearance.colors.colOnSurface
                                            font.pixelSize: Appearance.font.pixelSize.smallie
                                            font.weight: Font.Bold
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Navigation Destinations
                    NavigationRailTabArray {
                        Layout.fillWidth: true
                        currentIndex: root.currentPage
                        expanded: true
                        Repeater {
                            model: root.pages
                            NavigationRailButton {
                                required property var index
                                required property var modelData
                                toggled: root.currentPage === index
                                onPressed: root.currentPage = index;
                                expanded: true
                                buttonIcon: modelData.icon
                                buttonText: modelData.name
                                showToggledHighlight: false
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // 2. RIGHT CONTENT CONTAINER (BORDERLESS WITH TONAL SURFACE)
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Appearance.m3colors.m3surfaceContainerLow
                radius: Appearance.rounding.windowRounding - root.contentPadding
                clip: true

                Loader {
                    id: pageLoader
                    anchors.fill: parent
                    opacity: 1.0

                    Component.onCompleted: {
                        sourceComponent = root.pages[root.currentPage].component;
                    }

                    Connections {
                        target: root
                        function onCurrentPageChanged() {
                            switchAnim.complete();
                            switchAnim.start();
                        }
                    }

                    SequentialAnimation {
                        id: switchAnim

                        NumberAnimation {
                            target: pageLoader
                            properties: "opacity"
                            from: 1
                            to: 0
                            duration: 100
                            easing.type: Appearance.animation.elementMoveExit.type
                            easing.bezierCurve: Appearance.animationCurves.emphasizedFirstHalf
                        }
                        ParallelAnimation {
                            PropertyAction {
                                target: pageLoader
                                property: "sourceComponent"
                                value: root.pages[root.currentPage].component
                            }
                            PropertyAction {
                                target: pageLoader
                                property: "anchors.topMargin"
                                value: 20
                            }
                        }
                        ParallelAnimation {
                            NumberAnimation {
                                target: pageLoader
                                properties: "opacity"
                                from: 0
                                to: 1
                                duration: 200
                                easing.type: Appearance.animation.elementMoveEnter.type
                                easing.bezierCurve: Appearance.animationCurves.emphasizedLastHalf
                            }
                            NumberAnimation {
                                target: pageLoader
                                properties: "anchors.topMargin"
                                to: 0
                                duration: 200
                                easing.type: Appearance.animation.elementMoveEnter.type
                                easing.bezierCurve: Appearance.animationCurves.emphasizedLastHalf
                            }
                        }
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // PAGE 0: POWER & GPU (CONTENTPAGE WITH CONTENTSECTION)
    // ══════════════════════════════════════════════════════════════════════
    Component {
        id: powerPage
        ContentPage {
            contentY: 650
            baseWidth: 640
            forceWidth: true

            // Live Telemetry Table (Material 3 Expressive, Alternating Row Tints, Zero Dots)
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: powerTelemetryCol.implicitHeight
                radius: Appearance.rounding.normal
                color: Appearance.m3colors.m3surfaceContainer
                clip: true

                ColumnLayout {
                    id: powerTelemetryCol
                    anchors.fill: parent
                    spacing: 0

                    Repeater {
                        model: [
                            {
                                "icon": "speed",
                                "label": "Active Profile",
                                "value": `${root.getProfileName(root.statusData.profile)} Profile`
                            },
                            {
                                "icon": "bolt",
                                "label": "GPU Thermal Envelope",
                                "value": `${root.statusData.gpu_total_w ?? 130}W Total TGP (${root.statusData.gpu_ctgp_w ?? 105}W cTGP + ${root.statusData.gpu_ppab_w ?? 25}W Boost)`
                            },
                            {
                                "icon": "memory",
                                "label": "CPU Thermals & Fan",
                                "value": `${root.statusData.cpu_temp}°C (${root.statusData.fan1_rpm} RPM)`
                            },
                            {
                                "icon": "videogame_asset",
                                "label": "RTX 4060 Thermals & Fan",
                                "value": `${root.statusData.gpu_temp}°C (${root.statusData.fan2_rpm} RPM)`
                            }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            implicitHeight: 36
                            color: (index % 2 === 0) ? Appearance.m3colors.m3surfaceContainerHigh : "transparent"

                            RowLayout {
                                anchors {
                                    fill: parent
                                    leftMargin: 12
                                    rightMargin: 12
                                }
                                spacing: 10

                                MaterialSymbol {
                                    text: modelData.icon
                                    iconSize: 18
                                    color: Appearance.colors.colSubtext
                                }

                                StyledText {
                                    text: modelData.label
                                    color: Appearance.colors.colSubtext
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    Layout.fillWidth: true
                                }

                                StyledText {
                                    text: modelData.value
                                    color: Appearance.colors.colOnSurface
                                    font.weight: Font.DemiBold
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                }
                            }
                        }
                    }
                }
            }

            // 1. Operating Profiles
            ContentSection {
                icon: "speed"
                title: "Power Profiles"

                ContentSubsection {
                    title: "Operating Power Mode"
                    tooltip: "Controls CPU/GPU power envelopes and cooling fan curve via Fn+Q"

                    ConfigSelectionArray {
                        currentValue: root.statusData.profile
                        onSelected: newValue => {
                            root.executeCommand("profile", newValue);
                        }
                        options: [
                            { "displayName": "Quiet", "icon": "ac_unit", "value": "quiet" },
                            { "displayName": "Balanced", "icon": "tune", "value": "balanced" },
                            { "displayName": "Performance", "icon": "rocket_launch", "value": "performance" },
                            { "displayName": "Custom", "icon": "local_fire_department", "value": "custom" }
                        ]
                    }
                }
            }

            // 2. GPU MUX Switch
            ContentSection {
                icon: "developer_board"
                title: "Display & Graphics (MUX)"

                ContentSubsection {
                    title: "GPU Operating Mode"
                    tooltip: "Hardware MUX Switch: Dedicated routing directly wires RTX 4060 to laptop display"

                    ConfigSelectionArray {
                        currentValue: root.statusData.igpu_mode
                        onSelected: newValue => {
                            root.executeCommand("mux", String(newValue));
                        }
                        options: [
                            { "displayName": "iGPU Only", "icon": "energy_savings_leaf", "value": 1 },
                            { "displayName": "Hybrid Dynamic", "icon": "sync_alt", "value": 2 },
                            { "displayName": "dGPU RTX Only", "icon": "videogame_asset", "value": 0 }
                        ]
                    }
                }
            }

            // 3. Quick Protection Controls
            ContentSection {
                icon: "toggle_on"
                title: "Quick Controls"

                ConfigSwitch {
                    buttonIcon: "air"
                    text: "Emergency Fullspeed (100% Fans for Extreme Thermal Load)"
                    checked: root.statusData.fan_fullspeed
                    onCheckedChanged: {
                        if (checked !== root.statusData.fan_fullspeed) {
                            root.executeCommand("fan_fullspeed", checked ? "1" : "0");
                        }
                    }
                }

                ConfigSwitch {
                    buttonIcon: "battery_saver"
                    text: "Conservation Mode (Limits charge to 80% to protect battery)"
                    checked: root.statusData.conservation_mode
                    onCheckedChanged: {
                        if (checked !== root.statusData.conservation_mode) {
                            root.executeCommand("conservation", checked ? "1" : "0");
                        }
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // PAGE 1: FAN CURVES STUDIO (CONTENTPAGE WITH CONTENTSECTION)
    // ══════════════════════════════════════════════════════════════════════
    Component {
        id: curvesPage
        ContentPage {
            contentY: 650
            baseWidth: 640
            forceWidth: true

            NoticeBox {
                visible: root.curveAppliedFeedback
                Layout.fillWidth: true
                materialIcon: "check_circle"
                text: "Fan curve successfully written to Lenovo EC hardware!"
            }

            // 1. Presets
            ContentSection {
                icon: "cyclone"
                title: "Fan Presets"

                ContentSubsection {
                    title: "Active Preset Profile"
                    tooltip: "Choose an automated fan acoustic profile or restore factory EC automatic control"

                    ConfigSelectionArray {
                        currentValue: root.activePresetName
                        onSelected: newValue => {
                            root.applyFanPreset(newValue);
                        }
                        options: [
                            { "displayName": "Quiet", "icon": "ac_unit", "value": "quiet" },
                            { "displayName": "Balanced", "icon": "tune", "value": "balanced" },
                            { "displayName": "Performance", "icon": "rocket_launch", "value": "performance" },
                            { "displayName": "100% Max", "icon": "local_fire_department", "value": "max" },
                            { "displayName": "EC Auto", "icon": "restart_alt", "value": "auto" }
                        ]
                    }
                }
            }

            // 2. 10-Step Curve Studio
            ContentSection {
                icon: "linear_scale"
                title: "Threshold Tuning (10 Steps)"

                ContentSubsection {
                    title: "Select Temperature Step"
                    tooltip: "Each step defines fan RPM response when chip temperature reaches its threshold"

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: root.curvePoints
                            delegate: RippleButton {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                implicitHeight: 38
                                buttonRadius: Appearance.rounding.small
                                toggled: root.selectedCurveStep === modelData.step
                                colBackground: toggled ? Appearance.colors.colPrimary : Appearance.colors.colLayer2
                                onClicked: root.selectedCurveStep = modelData.step

                                contentItem: ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 1
                                    StyledText {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: `S${modelData.step}`
                                        font.weight: Font.Bold
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: parent.parent.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
                                    }
                                    StyledText {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: `${modelData.temp}°C`
                                        font.pixelSize: Appearance.font.pixelSize.smallie
                                        color: parent.parent.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                                    }
                                }
                            }
                        }
                    }
                }

                // Interactive Sliders for Selected Step
                ContentSubsection {
                    title: `Step ${root.selectedCurveStep} (${root.curvePoints[root.selectedCurveStep - 1]?.temp ?? 50}°C Threshold)`

                    // CPU Slider
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        OptionalMaterialSymbol {
                            icon: "memory"
                            iconSize: Appearance.font.pixelSize.larger
                        }
                        StyledText {
                            text: "CPU Fan Speed"
                            Layout.preferredWidth: 120
                            color: Appearance.colors.colOnSecondaryContainer
                        }
                        StyledSlider {
                            Layout.fillWidth: true
                            configuration: StyledSlider.Configuration.XS
                            usePercentTooltip: true
                            from: 0
                            to: 100
                            stepSize: 1
                            value: root.curvePoints[root.selectedCurveStep - 1]?.pwm1 ?? 50
                            onMoved: {
                                if (root.curvePoints[root.selectedCurveStep - 1]) {
                                    root.curvePoints[root.selectedCurveStep - 1].pwm1 = Math.round(value);
                                    root.curvePointsChanged();
                                }
                            }
                        }
                        StyledText {
                            text: `${root.curvePoints[root.selectedCurveStep - 1]?.pwm1 ?? 50}%`
                            font.weight: Font.Bold
                            Layout.preferredWidth: 42
                            horizontalAlignment: Text.AlignRight
                            color: Appearance.colors.colPrimary
                        }
                    }

                    // GPU Slider
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        OptionalMaterialSymbol {
                            icon: "sports_esports"
                            iconSize: Appearance.font.pixelSize.larger
                        }
                        StyledText {
                            text: "GPU Fan Speed"
                            Layout.preferredWidth: 120
                            color: Appearance.colors.colOnSecondaryContainer
                        }
                        StyledSlider {
                            Layout.fillWidth: true
                            configuration: StyledSlider.Configuration.XS
                            usePercentTooltip: true
                            from: 0
                            to: 100
                            stepSize: 1
                            value: root.curvePoints[root.selectedCurveStep - 1]?.pwm2 ?? 50
                            onMoved: {
                                if (root.curvePoints[root.selectedCurveStep - 1]) {
                                    root.curvePoints[root.selectedCurveStep - 1].pwm2 = Math.round(value);
                                    root.curvePointsChanged();
                                }
                            }
                        }
                        StyledText {
                            text: `${root.curvePoints[root.selectedCurveStep - 1]?.pwm2 ?? 50}%`
                            font.weight: Font.Bold
                            Layout.preferredWidth: 42
                            horizontalAlignment: Text.AlignRight
                            color: "#EF4444"
                        }
                    }

                    // Save Button
                    RippleButtonWithIcon {
                        Layout.alignment: Qt.AlignRight
                        Layout.topMargin: 8
                        materialIcon: "save"
                        mainText: "Save Step to Hardware"
                        onClicked: root.applyCurrentStep()
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // PAGE 2: HARDWARE & SETTINGS (LENOVO LEGION TOOLKIT SUITE)
    // ══════════════════════════════════════════════════════════════════════
    Component {
        id: hardwarePage
        ContentPage {
            baseWidth: 640
            forceWidth: true

            // 1. Battery Health & Management
            ContentSection {
                icon: "battery_charging_full"
                title: "Battery & Health"

                // Battery Health Table (Material 3 Expressive, Alternating Row Tints, Zero Dots)
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: batteryTableCol.implicitHeight
                    radius: Appearance.rounding.normal
                    color: Appearance.m3colors.m3surfaceContainer
                    clip: true

                    ColumnLayout {
                        id: batteryTableCol
                        anchors.fill: parent
                        spacing: 0

                        Repeater {
                            model: [
                                {
                                    "icon": "health_and_safety",
                                    "label": "Battery Health",
                                    "value": `${root.statusData.battery_health ?? 95.2}%`
                                },
                                {
                                    "icon": "battery_charging_full",
                                    "label": "Current Charge Status",
                                    "value": `${root.statusData.battery_capacity ?? 85}% (${root.statusData.battery_status ?? 'Not charging'})`
                                },
                                {
                                    "icon": "bolt",
                                    "label": "Full Energy Capacity",
                                    "value": `${root.statusData.battery_wh_full ?? 57.1} / ${root.statusData.battery_wh_design ?? 60.0} Wh`
                                },
                                {
                                    "icon": "cycle",
                                    "label": "Discharge Cycles",
                                    "value": `${root.statusData.battery_cycles ?? 135} Cycles`
                                }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                implicitHeight: 36
                                color: (index % 2 === 0) ? Appearance.m3colors.m3surfaceContainerHigh : "transparent"

                                RowLayout {
                                    anchors {
                                        fill: parent
                                        leftMargin: 12
                                        rightMargin: 12
                                    }
                                    spacing: 10

                                    MaterialSymbol {
                                        text: modelData.icon
                                        iconSize: 18
                                        color: Appearance.colors.colSubtext
                                    }

                                    StyledText {
                                        text: modelData.label
                                        color: Appearance.colors.colSubtext
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        Layout.fillWidth: true
                                    }

                                    StyledText {
                                        text: modelData.value
                                        color: Appearance.colors.colOnSurface
                                        font.weight: Font.DemiBold
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                    }
                                }
                            }
                        }
                    }
                }

                ConfigSwitch {
                    buttonIcon: "battery_saver"
                    text: "Conservation Mode (Limits charging to 80% to maximize battery longevity)"
                    checked: root.statusData.conservation_mode
                    onCheckedChanged: {
                        if (checked !== root.statusData.conservation_mode) {
                            root.executeCommand("conservation", checked ? "1" : "0");
                        }
                    }
                }
            }

            // 2. Lighting & Backlight Controls
            ContentSection {
                icon: "light_mode"
                title: "Lighting & Backlight"

                ContentSubsection {
                    title: "Keyboard Backlight Level"
                    tooltip: "Integrated white keyboard backlight level"

                    ConfigSelectionArray {
                        currentValue: root.statusData.kbd_backlight
                        onSelected: newValue => {
                            root.executeCommand("kbd", String(newValue));
                        }
                        options: [
                            { "displayName": "Off", "icon": "flash_off", "value": 0 },
                            { "displayName": "Low", "icon": "brightness_low", "value": 1 },
                            { "displayName": "High", "icon": "brightness_high", "value": 2 }
                        ]
                    }
                }

                ConfigSwitch {
                    buttonIcon: "highlight"
                    text: "Rear I/O Ports Light (Illuminates back connector labels)"
                    checked: root.statusData.ioport_light
                    onCheckedChanged: {
                        if (checked !== root.statusData.ioport_light) {
                            root.executeCommand("ioport", checked ? "1" : "0");
                        }
                    }
                }
            }

            // 3. Display & Refresh Rate
            ContentSection {
                icon: "display_settings"
                title: "Display & Refresh Rate"

                ContentSubsection {
                    title: "Panel Refresh Rate"
                    tooltip: "Switch internal laptop eDP-1 refresh rate via Hyprland"

                    ConfigSelectionArray {
                        currentValue: root.statusData.display_hz
                        onSelected: newValue => {
                            root.executeCommand("refresh", String(newValue));
                        }
                        options: [
                            { "displayName": "60Hz (Power Saver)", "icon": "speed", "value": 60 },
                            { "displayName": "144Hz (Smooth Gaming)", "icon": "bolt", "value": 144 }
                        ]
                    }
                }

                ConfigSwitch {
                    buttonIcon: "speed"
                    text: "Display LCD Overdrive (Lowers pixel response time for competitive gaming)"
                    checked: root.statusData.overdrive
                    onCheckedChanged: {
                        if (checked !== root.statusData.overdrive) {
                            root.executeCommand("overdrive", checked ? "1" : "0");
                        }
                    }
                }
            }

            // 4. Hardware Input Locks
            ContentSection {
                icon: "lock"
                title: "Hardware Input Locks"

                ConfigSwitch {
                    buttonIcon: "touchpad_mouse"
                    text: "Touchpad Enabled"
                    checked: root.statusData.touchpad
                    onCheckedChanged: {
                        if (checked !== root.statusData.touchpad) {
                            root.executeCommand("touchpad", checked ? "1" : "0");
                        }
                    }
                }

                ConfigSwitch {
                    buttonIcon: "keyboard"
                    text: "Windows / Meta Key Enabled (Disable to prevent accidental minimization)"
                    checked: root.statusData.winkey
                    onCheckedChanged: {
                        if (checked !== root.statusData.winkey) {
                            root.executeCommand("winkey", checked ? "1" : "0");
                        }
                    }
                }

                ConfigSwitch {
                    buttonIcon: "lock"
                    text: "Fn Lock (F1-F12 act as primary function keys rather than hotkeys)"
                    checked: root.statusData.fn_lock
                    onCheckedChanged: {
                        if (checked !== root.statusData.fn_lock) {
                            root.executeCommand("fn_lock", checked ? "1" : "0");
                        }
                    }
                }
            }

            // 5. GodMode Power Limits
            ContentSection {
                icon: "bolt"
                title: "GodMode Power Limits"

                NoticeBox {
                    visible: root.powerLimitsFeedback
                    Layout.fillWidth: true
                    materialIcon: "check_circle"
                    text: "Custom CPU & GPU power limits applied to hardware!"
                }

                // CPU PL1
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    OptionalMaterialSymbol {
                        icon: "memory"
                        iconSize: Appearance.font.pixelSize.larger
                    }
                    StyledText {
                        text: "CPU Long-Term (PL1)"
                        Layout.preferredWidth: 150
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                    StyledSlider {
                        Layout.fillWidth: true
                        configuration: StyledSlider.Configuration.XS
                        usePercentTooltip: false
                        from: 15
                        to: 115
                        stepSize: 5
                        value: root.sliderPl1
                        onMoved: root.sliderPl1 = Math.round(value)
                    }
                    StyledText {
                        text: `${root.sliderPl1}W`
                        font.weight: Font.Bold
                        Layout.preferredWidth: 42
                        horizontalAlignment: Text.AlignRight
                        color: Appearance.colors.colPrimary
                    }
                }

                // CPU PL2
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    OptionalMaterialSymbol {
                        icon: "memory"
                        iconSize: Appearance.font.pixelSize.larger
                    }
                    StyledText {
                        text: "CPU Short-Term (PL2)"
                        Layout.preferredWidth: 150
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                    StyledSlider {
                        Layout.fillWidth: true
                        configuration: StyledSlider.Configuration.XS
                        usePercentTooltip: false
                        from: 25
                        to: 135
                        stepSize: 5
                        value: root.sliderPl2
                        onMoved: root.sliderPl2 = Math.round(value)
                    }
                    StyledText {
                        text: `${root.sliderPl2}W`
                        font.weight: Font.Bold
                        Layout.preferredWidth: 42
                        horizontalAlignment: Text.AlignRight
                        color: Appearance.colors.colPrimary
                    }
                }

                // GPU cTGP
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    OptionalMaterialSymbol {
                        icon: "sports_esports"
                        iconSize: Appearance.font.pixelSize.larger
                    }
                    StyledText {
                        text: "GPU Base cTGP"
                        Layout.preferredWidth: 150
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                    StyledSlider {
                        Layout.fillWidth: true
                        configuration: StyledSlider.Configuration.XS
                        usePercentTooltip: false
                        from: 45
                        to: 105
                        stepSize: 5
                        value: root.sliderCtgp
                        onMoved: root.sliderCtgp = Math.round(value)
                    }
                    StyledText {
                        text: `${root.sliderCtgp}W`
                        font.weight: Font.Bold
                        Layout.preferredWidth: 42
                        horizontalAlignment: Text.AlignRight
                        color: "#EF4444"
                    }
                }

                // GPU PPAB
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    OptionalMaterialSymbol {
                        icon: "sports_esports"
                        iconSize: Appearance.font.pixelSize.larger
                    }
                    StyledText {
                        text: "GPU Dynamic Boost (PPAB)"
                        Layout.preferredWidth: 150
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                    StyledSlider {
                        Layout.fillWidth: true
                        configuration: StyledSlider.Configuration.XS
                        usePercentTooltip: false
                        from: 5
                        to: 25
                        stepSize: 5
                        value: root.sliderPpab
                        onMoved: root.sliderPpab = Math.round(value)
                    }
                    StyledText {
                        text: `${root.sliderPpab}W`
                        font.weight: Font.Bold
                        Layout.preferredWidth: 42
                        horizontalAlignment: Text.AlignRight
                        color: "#EF4444"
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 6

                    NoticeBox {
                        Layout.fillWidth: true
                        materialIcon: "bolt"
                        text: `Combined Total GPU TGP: ${root.sliderCtgp + root.sliderPpab}W`
                    }

                    RippleButtonWithIcon {
                        materialIcon: "check"
                        mainText: "Apply Limits"
                        onClicked: root.applyPowerLimits(root.sliderPl1, root.sliderPl2, root.sliderCtgp, root.sliderPpab)
                    }
                }
            }

            // 6. UEFI Boot Logo Changer (Lenovo Legion / LOQ Firmware DIY Logo)
            ContentSection {
                icon: "image"
                title: "UEFI Boot Logo"

                NoticeBox {
                    visible: root.bootlogoFeedback
                    Layout.fillWidth: true
                    materialIcon: root.bootlogoFeedbackSuccess ? "check_circle" : "error"
                    text: root.bootlogoFeedbackMsg
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: bootlogoCardCol.implicitHeight + 24
                    radius: Appearance.rounding.normal
                    color: Appearance.m3colors.m3surfaceContainer
                    clip: true

                    ColumnLayout {
                        id: bootlogoCardCol
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: 12
                        }
                        spacing: 12

                        // Image Preview (ONLY visible when a custom logo is active or a new image is selected)
                        Rectangle {
                            id: logoPreviewRect
                            visible: (root.selectedBootLogoPath.length > 0) || (root.bootlogoInfo.enabled && root.bootlogoInfo.preview_path.length > 0)
                            Layout.fillWidth: true
                            implicitHeight: 120
                            radius: Appearance.rounding.small
                            color: "#050505"
                            border.width: 1
                            border.color: Appearance.colors.colOutlineVariant
                            clip: true

                            Image {
                                anchors.fill: parent
                                anchors.margins: 4
                                fillMode: Image.PreserveAspectFit
                                source: (root.selectedBootLogoPath.length > 0)
                                    ? ("file://" + root.selectedBootLogoPath)
                                    : (root.bootlogoInfo.enabled && root.bootlogoInfo.preview_path.length > 0 ? ("file://" + root.bootlogoInfo.preview_path) : "")
                                cache: false
                            }
                        }

                        // Status Info
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                text: root.bootlogoInfo.enabled
                                    ? ("Custom Boot Logo Active" + (root.bootlogoInfo.active_logo ? ` (${root.bootlogoInfo.active_logo.filename})` : ""))
                                    : "Factory OEM Boot Logo Active"
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.variableAxes: Appearance.font.variableAxes.title
                                color: root.bootlogoInfo.enabled ? Appearance.colors.colPrimary : Appearance.colors.colOnSurface
                            }

                            StyledText {
                                visible: root.selectedBootLogoPath.length > 0
                                text: `Selected: ${root.selectedBootLogoPath.split('/').pop()}`
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.variableAxes: Appearance.font.variableAxes.numbers
                                color: Appearance.colors.colPrimary
                            }
                        }

                        // Action Buttons
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            RippleButtonWithIcon {
                                materialIcon: "folder_open"
                                mainText: "Browse Image..."
                                onClicked: {
                                    if (!pickImageProc.running) pickImageProc.running = true;
                                }
                            }

                            RippleButtonWithIcon {
                                enabled: root.selectedBootLogoPath.length > 0 && !root.bootlogoApplying
                                materialIcon: "upload"
                                mainText: root.bootlogoApplying ? "Applying..." : "Apply Boot Logo"
                                onClicked: {
                                    root.bootlogoApplying = true;
                                    applyLogoProc.running = true;
                                }
                            }

                            RippleButtonWithIcon {
                                enabled: root.bootlogoInfo.enabled && !root.bootlogoApplying
                                materialIcon: "restore"
                                mainText: "Restore Factory OEM"
                                onClicked: {
                                    root.bootlogoApplying = true;
                                    resetLogoProc.running = true;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
