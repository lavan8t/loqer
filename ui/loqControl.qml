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

ApplicationWindow {
    id: root
    property real contentPadding: 8
    visible: true
    onClosing: Qt.quit()
    title: "Loqer"

    Component.onCompleted: {
        root.loadGeneratedTheme();
        loadCurveProc.running = true;
        root.reloadStatus();
    }

    minimumWidth: 840
    minimumHeight: 580
    width: 1040
    height: 720
    color: m3theme.background

    FontLoader {
        id: fontGoogleSans
        source: Qt.resolvedUrl("fonts/GoogleSansFlex.ttf")
    }

    // ══════════════════════════════════════════════════════════════════════
    // MATERIAL DESIGN 3 SELF-CONTAINED THEME (ZERO DOTFILE DEPENDENCIES)
    // ══════════════════════════════════════════════════════════════════════
    QtObject {
        id: m3theme
        property color background: "#101418"
        property color surface: "#101418"
        property color surfaceContainerLowest: "#0b0e12"
        property color surfaceContainerLow: "#181c20"
        property color surfaceContainer: "#1d2024"
        property color surfaceContainerHigh: "#272a2f"
        property color surfaceContainerHighest: "#32353a"
        property color textPrimary: "#e0e2e8"
        property color textSecondary: "#c2c7cf"
        property color outline: "#8c9199"
        property color outlineVariant: "#42474e"
        property color primary: "#9dcbfb"
        property color textOnPrimary: "#003355"
        property color primaryContainer: "#134a73"
        property color textOnPrimaryContainer: "#cfe5ff"
        property color secondary: "#bac8da"
        property color textOnSecondary: "#243240"
        property color subtext: "#8c9199"

        readonly property int roundingSmall: 8
        readonly property int roundingMedium: 16
        readonly property int roundingLarge: 24
        readonly property int roundingFull: 9999
        readonly property int windowRounding: 18

        readonly property string fontFamily: (fontGoogleSans.status === FontLoader.Ready && fontGoogleSans.name) ? fontGoogleSans.name : "Google Sans Flex, system-ui, -apple-system, sans-serif"
        readonly property string iconFontFamily: "Material Symbols Rounded"
    }

    // ══════════════════════════════════════════════════════════════════════
    // SELF-CONTAINED MATERIAL 3 COMPONENTS
    // ══════════════════════════════════════════════════════════════════════
    component M3Text: Text {
        font.family: m3theme.fontFamily
        font.pixelSize: 13
        color: m3theme.textPrimary
        renderType: Text.NativeRendering
    }

    component M3Icon: Text {
        property real iconSize: 20
        font.family: m3theme.iconFontFamily
        font.pixelSize: iconSize
        font.weight: Font.Bold
        color: m3theme.textPrimary
        renderType: Text.NativeRendering
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    component M3Button: Rectangle {
        id: btnRoot
        property alias text: btnLabel.text
        property alias icon: btnIcon.text
        property bool toggled: false
        property color colBg: toggled ? m3theme.primaryContainer : (mouseArea.containsMouse ? m3theme.surfaceContainerHigh : m3theme.surfaceContainer)
        property color colFg: toggled ? m3theme.textOnPrimaryContainer : m3theme.textPrimary
        signal clicked()

        implicitWidth: btnRow.implicitWidth + 24
        implicitHeight: 36
        radius: m3theme.roundingSmall
        color: colBg
        Behavior on color { ColorAnimation { duration: 150 } }

        RowLayout {
            id: btnRow
            anchors.centerIn: parent
            spacing: 8
            M3Icon {
                id: btnIcon
                visible: text !== ""
                iconSize: 18
                color: btnRoot.colFg
            }
            M3Text {
                id: btnLabel
                visible: text !== ""
                text: ""
                font.weight: btnRoot.toggled ? Font.Bold : Font.Medium
                color: btnRoot.colFg
            }
        }
        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btnRoot.clicked()
        }
    }

    component M3SegmentedControl: Rectangle {
        id: segRoot
        property var options: []
        property var currentValue
        signal selected(var val)

        Layout.fillWidth: true
        implicitHeight: 40
        radius: m3theme.roundingSmall
        color: m3theme.surfaceContainerLowest
        clip: true

        RowLayout {
            anchors.fill: parent
            spacing: 2
            anchors.margins: 2

            Repeater {
                model: segRoot.options
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool isSelected: String(segRoot.currentValue) === String(modelData.value)

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: m3theme.roundingSmall - 2
                    color: isSelected ? (modelData.activeBg || m3theme.primaryContainer) : (itemMouse.containsMouse ? m3theme.surfaceContainerHigh : "transparent")
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        M3Icon {
                            visible: !!modelData.icon
                            text: modelData.icon ?? ""
                            iconSize: 16
                            color: isSelected ? (modelData.activeFg || m3theme.textOnPrimaryContainer) : m3theme.textSecondary
                        }
                        M3Text {
                            text: modelData.displayName ?? ""
                            font.weight: isSelected ? Font.Bold : Font.Normal
                            font.pixelSize: 12
                            color: isSelected ? (modelData.activeFg || m3theme.textOnPrimaryContainer) : m3theme.textPrimary
                        }
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: segRoot.selected(modelData.value)
                    }
                }
            }
        }
    }

    component M3Switch: Rectangle {
        id: switchRoot
        property string icon: ""
        property string title: ""
        property string subtitle: ""
        property bool checked: false
        signal toggled(bool newState)

        Layout.fillWidth: true
        implicitHeight: 48
        radius: m3theme.roundingSmall
        color: switchMouse.containsMouse ? m3theme.surfaceContainerHigh : m3theme.surfaceContainer
        Behavior on color { ColorAnimation { duration: 150 } }

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 12
                rightMargin: 12
            }
            spacing: 12

            M3Icon {
                visible: switchRoot.icon !== ""
                text: switchRoot.icon
                iconSize: 20
                color: switchRoot.checked ? m3theme.primary : m3theme.subtext
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                M3Text {
                    text: switchRoot.title
                    font.weight: Font.Medium
                    font.pixelSize: 13
                    color: m3theme.textPrimary
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                M3Text {
                    visible: switchRoot.subtitle !== ""
                    text: switchRoot.subtitle
                    font.pixelSize: 11
                    color: m3theme.subtext
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                width: 44
                height: 24
                radius: 12
                color: switchRoot.checked ? m3theme.primary : m3theme.surfaceContainerHighest
                Behavior on color { ColorAnimation { duration: 150 } }

                Rectangle {
                    x: switchRoot.checked ? 22 : 2
                    y: 2
                    width: 20
                    height: 20
                    radius: 10
                    color: switchRoot.checked ? m3theme.textOnPrimary : m3theme.outline
                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }
            }
        }

        MouseArea {
            id: switchMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                switchRoot.checked = !switchRoot.checked;
                switchRoot.toggled(switchRoot.checked);
            }
        }
    }

    component M3Slider: Item {
        id: sliderRoot
        property real from: 0
        property real to: 100
        property real stepSize: 1
        property real value: 50
        signal moved(real val)

        implicitHeight: 28
        Layout.fillWidth: true

        Rectangle {
            id: track
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            height: 6
            radius: 3
            color: m3theme.surfaceContainerHighest

            Rectangle {
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                }
                width: Math.max(0, Math.min(track.width, (sliderRoot.value - sliderRoot.from) / (sliderRoot.to - sliderRoot.from) * track.width))
                radius: 3
                color: m3theme.primary
            }
        }

        Rectangle {
            id: thumb
            width: 18
            height: 18
            radius: 9
            color: m3theme.primary
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(sliderRoot.width - width, (sliderRoot.value - sliderRoot.from) / (sliderRoot.to - sliderRoot.from) * (sliderRoot.width - width)))

            Rectangle {
                anchors.centerIn: parent
                width: 6
                height: 6
                radius: 3
                color: m3theme.textOnPrimary
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            function updateVal(mouseX) {
                let clamped = Math.max(0, Math.min(width, mouseX));
                let ratio = clamped / width;
                let raw = sliderRoot.from + ratio * (sliderRoot.to - sliderRoot.from);
                let stepped = Math.round(raw / sliderRoot.stepSize) * sliderRoot.stepSize;
                let finalVal = Math.max(sliderRoot.from, Math.min(sliderRoot.to, stepped));
                sliderRoot.value = finalVal;
                sliderRoot.moved(finalVal);
            }

            onPressed: mouse => updateVal(mouse.x)
            onPositionChanged: mouse => {
                if (pressed) updateVal(mouse.x);
            }
        }
    }

    component M3Section: ColumnLayout {
        property string title: ""
        property string icon: ""
        Layout.fillWidth: true
        spacing: 10

        RowLayout {
            spacing: 8
            visible: title !== ""
            M3Icon {
                visible: icon !== ""
                text: icon
                iconSize: 20
                color: m3theme.primary
            }
            M3Text {
                text: title
                font.weight: Font.Bold
                font.pixelSize: 15
                color: m3theme.textPrimary
            }
        }
    }

    component M3Subsection: ColumnLayout {
        property string title: ""
        property string tooltip: ""
        Layout.fillWidth: true
        spacing: 6

        RowLayout {
            spacing: 6
            visible: title !== ""
            M3Text {
                text: title
                font.weight: Font.DemiBold
                font.pixelSize: 13
                color: m3theme.textSecondary
            }
        }
    }

    component M3Notice: Rectangle {
        property alias text: noticeText.text
        property string icon: "info"
        Layout.fillWidth: true
        implicitHeight: noticeRow.implicitHeight + 16
        radius: m3theme.roundingSmall
        color: m3theme.surfaceContainer
        clip: true

        RowLayout {
            id: noticeRow
            anchors {
                fill: parent
                leftMargin: 12
                rightMargin: 12
            }
            spacing: 10
            M3Icon {
                text: icon
                iconSize: 18
                color: m3theme.primary
            }
            M3Text {
                id: noticeText
                Layout.fillWidth: true
                color: m3theme.textPrimary
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }
        }
    }

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
        path: (Quickshell.env("XDG_RUNTIME_DIR") ? Quickshell.env("XDG_RUNTIME_DIR") : "/run/user/1000") + "/lenovo-power-status.json"
        watchChanges: true
        onFileChanged: root.reloadStatus()
    }

    FileView {
        id: themeFile
        path: {
            let stateHome = Quickshell.env("XDG_STATE_HOME");
            if (stateHome) return stateHome + "/quickshell/user/generated/colors.json";
            let home = Quickshell.env("HOME") || "/home/lavan";
            return home + "/.local/state/quickshell/user/generated/colors.json";
        }
        watchChanges: true
        onLoaded: root.loadGeneratedTheme()
        onFileChanged: root.loadGeneratedTheme()
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

    function loadGeneratedTheme() {
        try {
            let txt = themeFile.text();
            if (!txt || !txt.trim().startsWith("{")) return;
            let c = JSON.parse(txt.trim());
            if (c.background) m3theme.background = c.background;
            if (c.surface) m3theme.surface = c.surface;
            if (c.surface_container_lowest) m3theme.surfaceContainerLowest = c.surface_container_lowest;
            if (c.surface_container_low) m3theme.surfaceContainerLow = c.surface_container_low;
            if (c.surface_container) m3theme.surfaceContainer = c.surface_container;
            if (c.surface_container_high) m3theme.surfaceContainerHigh = c.surface_container_high;
            if (c.surface_container_highest) m3theme.surfaceContainerHighest = c.surface_container_highest;
            if (c.on_surface) m3theme.textPrimary = c.on_surface;
            if (c.on_surface_variant) m3theme.textSecondary = c.on_surface_variant;
            if (c.outline) { m3theme.outline = c.outline; m3theme.subtext = c.outline; }
            if (c.outline_variant) m3theme.outlineVariant = c.outline_variant;
            if (c.primary) m3theme.primary = c.primary;
            if (c.on_primary) m3theme.textOnPrimary = c.on_primary;
            if (c.primary_container) m3theme.primaryContainer = c.primary_container;
            if (c.on_primary_container) m3theme.textOnPrimaryContainer = c.on_primary_container;
            if (c.secondary) m3theme.secondary = c.secondary;
            if (c.on_secondary) m3theme.textOnSecondary = c.on_secondary;
        } catch(e) {}
    }

    function reloadStatus() {
        try {
            statusFile.reload();
            let txt = statusFile.text();
            if (!txt || !txt.trim().startsWith("{")) {
                let sysFile = (Quickshell.env("XDG_RUNTIME_DIR") ? Quickshell.env("XDG_RUNTIME_DIR") : "/run/user/1000") + "/lenovo-power-status.json";
                let f = Io.file(sysFile);
                if (f) txt = f.read();
            }
            if (txt && txt.trim().startsWith("{")) {
                let parsed = JSON.parse(txt.trim());
                let oldProfile = root.statusData ? root.statusData.profile : null;
                root.statusData = parsed;
                root.statusDataChanged();
                if (oldProfile && oldProfile !== parsed.profile) {
                    bigLoqRing.triggerSpin();
                }
                if (!root.initializedLimits) {
                    root.sliderPl1 = parsed.pl1_w ?? 55;
                    root.sliderPl2 = parsed.pl2_w ?? 115;
                    root.sliderCtgp = parsed.gpu_ctgp_w ?? 105;
                    root.sliderPpab = parsed.gpu_ppab_w ?? 25;
                    root.initializedLimits = true;
                }
            }
        } catch(e) {}
    }

    function executeCommand(action, val) {
        Quickshell.execDetached(["sudo", "-n", "/usr/local/bin/loq-ctl", action, String(val)]);
        let updated = Object.assign({}, root.statusData);
        if (action === "profile") {
            updated.profile = val;
            bigLoqRing.triggerSpin();
        } else if (action === "mux") {
            updated.igpu_mode = parseInt(val);
        } else if (action === "conservation") {
            updated.conservation_mode = (val === "1");
        } else if (action === "fn_lock") {
            updated.fn_lock = (val === "1");
        } else if (action === "fan_fullspeed") {
            updated.fan_fullspeed = (val === "1");
        } else if (action === "touchpad") {
            updated.touchpad = (val === "1");
        } else if (action === "winkey") {
            updated.winkey = (val === "1");
        } else if (action === "overdrive") {
            updated.overdrive = (val === "1");
        } else if (action === "kbd") {
            updated.kbd_backlight = parseInt(val);
        } else if (action === "ioport") {
            updated.ioport_light = (val === "1");
        } else if (action === "refresh") {
            updated.display_hz = parseInt(val);
        }
        root.statusData = updated;
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
        // TITLEBAR WITH CLOSE BUTTON
        // ══════════════════════════════════════════════════════════════════════
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: false
            implicitHeight: 36

            M3Text {
                id: titleText
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: 12
                }
                text: "Loqer"
                font.weight: Font.Bold
                font.pixelSize: 18
            }

            RowLayout {
                id: windowControlsRow
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                spacing: 8

                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: closeMouse.containsMouse ? m3theme.surfaceContainerHighest : "transparent"

                    M3Icon {
                        anchors.centerIn: parent
                        text: "close"
                        iconSize: 18
                        color: m3theme.textPrimary
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════════════════
        // MAIN BODY: NAVIGATION SIDEBAR + CONTENT CONTAINER
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

                            property real ringThickness: 11.6 // 20% thicker
                            property color ringColor: root.getProfileColor(root.statusData.profile)
                            Behavior on ringColor { ColorAnimation { duration: 250; easing.type: Easing.OutCubic } }

                            Canvas {
                                id: loqRingCanvas
                                anchors.fill: parent
                                renderTarget: Canvas.FramebufferObject
                                antialiasing: true

                                onPaint: {
                                    let ctx = getContext("2d");
                                    ctx.reset();
                                    let cx = width / 2;
                                    let cy = height / 2;
                                    let rOut = 31;
                                    let rIn = 31 - bigLoqRing.ringThickness;
                                    let cutWidth = 6.2; // uniform parallel rectangular slot width

                                    // 1. Draw solid donut ring
                                    ctx.beginPath();
                                    ctx.arc(cx, cy, rOut, 0, 2 * Math.PI, false);
                                    ctx.arc(cx, cy, rIn, 2 * Math.PI, 0, true);
                                    ctx.closePath();
                                    ctx.fillStyle = bigLoqRing.ringColor;
                                    ctx.fill();

                                    // 2. Cut 3 parallel rectangular slots (rectangle cuts, not angular)
                                    ctx.globalCompositeOperation = "destination-out";
                                    let angles = [90 * Math.PI / 180, 210 * Math.PI / 180, 330 * Math.PI / 180];
                                    for (let a of angles) {
                                        ctx.save();
                                        ctx.translate(cx, cy);
                                        ctx.rotate(a);
                                        ctx.fillRect(-cutWidth / 2, 0, cutWidth, rOut + 4);
                                        ctx.restore();
                                    }
                                }

                                Connections {
                                    target: bigLoqRing
                                    function onRingColorChanged() {
                                        loqRingCanvas.requestPaint();
                                    }
                                }
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
                    M3Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "LOQ 15IAX9"
                        font.weight: Font.Bold
                        font.pixelSize: 13
                        color: m3theme.textPrimary
                    }

                    // Status Table below model name (Tabular alignment, Monochrome / uncolored, alternating row tints)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.leftMargin: 2
                        Layout.rightMargin: 2
                        implicitHeight: statusTableCol.implicitHeight
                        radius: m3theme.roundingSmall
                        color: m3theme.surfaceContainer
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
                                    color: (index % 2 === 0) ? m3theme.surfaceContainerHigh : "transparent"

                                    RowLayout {
                                        anchors {
                                            fill: parent
                                            leftMargin: 8
                                            rightMargin: 8
                                        }
                                        M3Text {
                                            text: modelData.label
                                            color: m3theme.subtext
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                            Layout.fillWidth: true
                                        }
                                        M3Text {
                                            text: modelData.value
                                            color: m3theme.textPrimary
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Navigation Destinations
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: root.pages
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                readonly property bool isCurrent: root.currentPage === index

                                Layout.fillWidth: true
                                implicitHeight: 40
                                radius: m3theme.roundingSmall
                                color: isCurrent ? m3theme.primaryContainer : (navMouse.containsMouse ? m3theme.surfaceContainerHigh : "transparent")
                                Behavior on color { ColorAnimation { duration: 120 } }

                                RowLayout {
                                    anchors {
                                        fill: parent
                                        leftMargin: 12
                                        rightMargin: 12
                                    }
                                    spacing: 10

                                    M3Icon {
                                        text: modelData.icon
                                        iconSize: 20
                                        color: isCurrent ? m3theme.textOnPrimaryContainer : m3theme.textSecondary
                                    }

                                    M3Text {
                                        text: modelData.name
                                        font.weight: isCurrent ? Font.Bold : Font.Normal
                                        color: isCurrent ? m3theme.textOnPrimaryContainer : m3theme.textPrimary
                                        Layout.fillWidth: true
                                    }
                                }

                                MouseArea {
                                    id: navMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.currentPage = index
                                }
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
                color: m3theme.surfaceContainerLow
                radius: m3theme.windowRounding - root.contentPadding
                clip: true

                Loader {
                    id: pageLoader
                    anchors.fill: parent
                    opacity: 1.0

                    Component.onCompleted: {
                        sourceComponent = root.pages[0].component;
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
                            easing.type: Easing.OutQuad
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
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                target: pageLoader
                                properties: "anchors.topMargin"
                                to: 0
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // PAGE 0: POWER & GPU
    // ══════════════════════════════════════════════════════════════════════
    Component {
        id: powerPage
        ScrollView {
            contentWidth: -1
            clip: true

            ColumnLayout {
                width: Math.min(parent.width - 32, 640)
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16

                Item { implicitHeight: 8 }

                // Live Telemetry Table (Material 3 Expressive, Alternating Row Tints, Zero Dots)
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: powerTelemetryCol.implicitHeight
                    radius: m3theme.roundingSmall
                    color: m3theme.surfaceContainer
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
                                    "value": `${root.getProfileName(root.statusData.profile)} Profile`,
                                    "valueColor": root.getProfileColor(root.statusData.profile)
                                },
                                {
                                    "icon": "bolt",
                                    "label": "GPU Thermal Envelope",
                                    "value": `${root.statusData.gpu_total_w ?? 130}W Total TGP (${root.statusData.gpu_ctgp_w ?? 105}W cTGP + ${root.statusData.gpu_ppab_w ?? 25}W Boost)`,
                                    "valueColor": m3theme.textPrimary
                                },
                                {
                                    "icon": "memory",
                                    "label": "CPU Thermals & Fan",
                                    "value": `${root.statusData.cpu_temp}°C (${root.statusData.fan1_rpm} RPM)`,
                                    "valueColor": (root.statusData.cpu_temp > 85 ? "#EF4444" : (root.statusData.cpu_temp > 75 ? "#F59E0B" : m3theme.textPrimary))
                                },
                                {
                                    "icon": "videogame_asset",
                                    "label": "RTX 4060 Thermals & Fan",
                                    "value": `${root.statusData.gpu_temp}°C (${root.statusData.fan2_rpm} RPM)`,
                                    "valueColor": (root.statusData.gpu_temp > 80 ? "#EF4444" : (root.statusData.gpu_temp > 70 ? "#F59E0B" : m3theme.textPrimary))
                                }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                implicitHeight: 36
                                color: (index % 2 === 0) ? m3theme.surfaceContainerHigh : "transparent"

                                RowLayout {
                                    anchors {
                                        fill: parent
                                        leftMargin: 12
                                        rightMargin: 12
                                    }
                                    spacing: 10

                                    M3Icon {
                                        text: modelData.icon
                                        iconSize: 18
                                        color: m3theme.subtext
                                    }

                                    M3Text {
                                        text: modelData.label
                                        color: m3theme.subtext
                                        font.pixelSize: 12
                                        Layout.fillWidth: true
                                    }

                                    M3Text {
                                        text: modelData.value
                                        color: modelData.valueColor || m3theme.textPrimary
                                        font.weight: Font.DemiBold
                                        font.pixelSize: 12
                                    }
                                }
                            }
                        }
                    }
                }

                // 1. Operating Profiles
                M3Section {
                    icon: "speed"
                    title: "Power Profiles"

                    M3Subsection {
                        title: "Operating Power Mode"
                        tooltip: "Controls CPU/GPU power envelopes and cooling fan curve via Fn+Q"

                        M3SegmentedControl {
                            currentValue: root.statusData.profile
                            onSelected: newValue => {
                                root.executeCommand("profile", newValue);
                            }
                            options: [
                                { "displayName": "Quiet", "icon": "ac_unit", "value": "quiet", "activeBg": "#082F49", "activeFg": "#7DD3FC" },
                                { "displayName": "Balanced", "icon": "tune", "value": "balanced", "activeBg": "#334155", "activeFg": "#F8FAFC" },
                                { "displayName": "Performance", "icon": "rocket_launch", "value": "performance", "activeBg": "#7F1D1D", "activeFg": "#FECACA" },
                                { "displayName": "Custom", "icon": "local_fire_department", "value": "custom", "activeBg": "#831843", "activeFg": "#FBCFE8" }
                            ]
                        }
                    }
                }

                // 2. GPU MUX Switch
                M3Section {
                    icon: "developer_board"
                    title: "Display & Graphics (MUX)"

                    M3Subsection {
                        title: "GPU Operating Mode"
                        tooltip: "Hardware MUX Switch: Dedicated routing directly wires RTX 4060 to laptop display"

                        M3SegmentedControl {
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
                M3Section {
                    icon: "toggle_on"
                    title: "Quick Controls"

                    M3Switch {
                        icon: "air"
                        title: "Emergency Fullspeed"
                        subtitle: "100% Fans for Extreme Thermal Load"
                        checked: root.statusData.fan_fullspeed
                        onToggled: state => {
                            root.executeCommand("fan_fullspeed", state ? "1" : "0");
                        }
                    }

                    M3Switch {
                        icon: "battery_saver"
                        title: "Conservation Mode"
                        subtitle: "Limits charging to 80% to protect battery longevity"
                        checked: root.statusData.conservation_mode
                        onToggled: state => {
                            root.executeCommand("conservation", state ? "1" : "0");
                        }
                    }
                }

                Item { implicitHeight: 16 }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // PAGE 1: FAN CURVES STUDIO
    // ══════════════════════════════════════════════════════════════════════
    Component {
        id: curvesPage
        ScrollView {
            contentWidth: -1
            clip: true

            ColumnLayout {
                width: Math.min(parent.width - 32, 640)
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16

                Item { implicitHeight: 8 }

                M3Notice {
                    visible: root.curveAppliedFeedback
                    icon: "check_circle"
                    text: "Fan curve successfully written to Lenovo EC hardware!"
                }

                // 1. Presets
                M3Section {
                    icon: "cyclone"
                    title: "Fan Presets"

                    M3Subsection {
                        title: "Active Preset Profile"
                        tooltip: "Choose an automated fan acoustic profile or restore factory EC automatic control"

                        M3SegmentedControl {
                            currentValue: root.activePresetName
                            onSelected: newValue => {
                                root.applyFanPreset(newValue);
                            }
                            options: [
                                { "displayName": "Quiet", "icon": "ac_unit", "value": "quiet", "activeBg": "#082F49", "activeFg": "#7DD3FC" },
                                { "displayName": "Balanced", "icon": "tune", "value": "balanced", "activeBg": "#334155", "activeFg": "#F8FAFC" },
                                { "displayName": "Performance", "icon": "rocket_launch", "value": "performance", "activeBg": "#7F1D1D", "activeFg": "#FECACA" },
                                { "displayName": "100% Max", "icon": "local_fire_department", "value": "max", "activeBg": "#991B1B", "activeFg": "#FEE2E2" },
                                { "displayName": "EC Auto", "icon": "restart_alt", "value": "auto", "activeBg": m3theme.primaryContainer, "activeFg": m3theme.textOnPrimaryContainer }
                            ]
                        }
                    }
                }

                // 2. 10-Step Curve Studio
                M3Section {
                    icon: "linear_scale"
                    title: "Threshold Tuning (10 Steps)"

                    M3Subsection {
                        title: "Select Temperature Step"
                        tooltip: "Each step defines fan RPM response when chip temperature reaches its threshold"

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Repeater {
                                model: root.curvePoints
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    readonly property bool isSelected: root.selectedCurveStep === modelData.step

                                    Layout.fillWidth: true
                                    implicitHeight: 38
                                    radius: m3theme.roundingSmall
                                    color: isSelected ? m3theme.primaryContainer : (stepMouse.containsMouse ? m3theme.surfaceContainerHigh : m3theme.surfaceContainer)
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 1
                                        M3Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: `S${modelData.step}`
                                            font.weight: Font.Bold
                                            font.pixelSize: 11
                                            color: isSelected ? m3theme.textOnPrimaryContainer : m3theme.textPrimary
                                        }
                                        M3Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: `${modelData.temp}°C`
                                            font.pixelSize: 9
                                            color: isSelected ? m3theme.textOnPrimaryContainer : m3theme.subtext
                                        }
                                    }

                                    MouseArea {
                                        id: stepMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.selectedCurveStep = modelData.step
                                    }
                                }
                            }
                        }
                    }

                    // Interactive Sliders for Selected Step
                    M3Subsection {
                        title: `Step ${root.selectedCurveStep} (${root.curvePoints[root.selectedCurveStep - 1]?.temp ?? 50}°C Threshold)`

                        // CPU Slider
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            M3Icon {
                                text: "memory"
                                iconSize: 20
                                color: m3theme.subtext
                            }
                            M3Text {
                                text: "CPU Fan Speed"
                                Layout.preferredWidth: 120
                                color: m3theme.textPrimary
                            }
                            M3Slider {
                                Layout.fillWidth: true
                                from: 0
                                to: 100
                                stepSize: 1
                                value: root.curvePoints[root.selectedCurveStep - 1]?.pwm1 ?? 50
                                onMoved: val => {
                                    if (root.curvePoints[root.selectedCurveStep - 1]) {
                                        root.curvePoints[root.selectedCurveStep - 1].pwm1 = Math.round(val);
                                        root.curvePointsChanged();
                                    }
                                }
                            }
                            M3Text {
                                text: `${root.curvePoints[root.selectedCurveStep - 1]?.pwm1 ?? 50}%`
                                font.weight: Font.Bold
                                Layout.preferredWidth: 42
                                horizontalAlignment: Text.AlignRight
                                color: m3theme.primary
                            }
                        }

                        // GPU Slider
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            M3Icon {
                                text: "sports_esports"
                                iconSize: 20
                                color: m3theme.subtext
                            }
                            M3Text {
                                text: "GPU Fan Speed"
                                Layout.preferredWidth: 120
                                color: m3theme.textPrimary
                            }
                            M3Slider {
                                Layout.fillWidth: true
                                from: 0
                                to: 100
                                stepSize: 1
                                value: root.curvePoints[root.selectedCurveStep - 1]?.pwm2 ?? 50
                                onMoved: val => {
                                    if (root.curvePoints[root.selectedCurveStep - 1]) {
                                        root.curvePoints[root.selectedCurveStep - 1].pwm2 = Math.round(val);
                                        root.curvePointsChanged();
                                    }
                                }
                            }
                            M3Text {
                                text: `${root.curvePoints[root.selectedCurveStep - 1]?.pwm2 ?? 50}%`
                                font.weight: Font.Bold
                                Layout.preferredWidth: 42
                                horizontalAlignment: Text.AlignRight
                                color: "#EF4444"
                            }
                        }

                        // Save Button
                        M3Button {
                            Layout.alignment: Qt.AlignRight
                            Layout.topMargin: 8
                            icon: "save"
                            text: "Save Step to Hardware"
                            onClicked: root.applyCurrentStep()
                        }
                    }
                }

                Item { implicitHeight: 16 }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // PAGE 2: HARDWARE & SETTINGS
    // ══════════════════════════════════════════════════════════════════════
    Component {
        id: hardwarePage
        ScrollView {
            contentWidth: -1
            clip: true

            ColumnLayout {
                width: Math.min(parent.width - 32, 640)
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16

                Item { implicitHeight: 8 }

                // 1. Battery Health & Management
                M3Section {
                    icon: "battery_charging_full"
                    title: "Battery & Health"

                    // Battery Health Table (Material 3 Expressive, Alternating Row Tints, Zero Dots)
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: batteryTableCol.implicitHeight
                        radius: m3theme.roundingSmall
                        color: m3theme.surfaceContainer
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
                                    color: (index % 2 === 0) ? m3theme.surfaceContainerHigh : "transparent"

                                    RowLayout {
                                        anchors {
                                            fill: parent
                                            leftMargin: 12
                                            rightMargin: 12
                                        }
                                        spacing: 10

                                        M3Icon {
                                            text: modelData.icon
                                            iconSize: 18
                                            color: m3theme.subtext
                                        }

                                        M3Text {
                                            text: modelData.label
                                            color: m3theme.subtext
                                            font.pixelSize: 12
                                            Layout.fillWidth: true
                                        }

                                        M3Text {
                                            text: modelData.value
                                            color: m3theme.textPrimary
                                            font.weight: Font.DemiBold
                                            font.pixelSize: 12
                                        }
                                    }
                                }
                            }
                        }
                    }

                    M3Switch {
                        icon: "battery_saver"
                        title: "Conservation Mode"
                        subtitle: "Limits charging to 80% to maximize battery longevity"
                        checked: root.statusData.conservation_mode
                        onToggled: state => {
                            root.executeCommand("conservation", state ? "1" : "0");
                        }
                    }
                }

                // 2. Lighting & Backlight Controls
                M3Section {
                    icon: "light_mode"
                    title: "Lighting & Backlight"

                    M3Subsection {
                        title: "Keyboard Backlight Level"
                        tooltip: "Integrated white keyboard backlight level"

                        M3SegmentedControl {
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

                    M3Switch {
                        icon: "highlight"
                        title: "Rear I/O Ports Light"
                        subtitle: "Illuminates back connector labels"
                        checked: root.statusData.ioport_light
                        onToggled: state => {
                            root.executeCommand("ioport", state ? "1" : "0");
                        }
                    }
                }

                // 3. Display & Refresh Rate
                M3Section {
                    icon: "display_settings"
                    title: "Display & Refresh Rate"

                    M3Subsection {
                        title: "Panel Refresh Rate"
                        tooltip: "Switch internal laptop eDP-1 refresh rate"

                        M3SegmentedControl {
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

                    M3Switch {
                        icon: "speed"
                        title: "Display LCD Overdrive"
                        subtitle: "Lowers pixel response time for competitive gaming"
                        checked: root.statusData.overdrive
                        onToggled: state => {
                            root.executeCommand("overdrive", state ? "1" : "0");
                        }
                    }
                }

                // 4. Hardware Input Locks
                M3Section {
                    icon: "lock"
                    title: "Hardware Input Locks"

                    M3Switch {
                        icon: "touchpad_mouse"
                        title: "Touchpad Enabled"
                        subtitle: "Hardware toggle for built-in trackpad"
                        checked: root.statusData.touchpad
                        onToggled: state => {
                            root.executeCommand("touchpad", state ? "1" : "0");
                        }
                    }

                    M3Switch {
                        icon: "keyboard"
                        title: "Windows / Meta Key"
                        subtitle: "Disable during gaming to prevent accidental window minimization"
                        checked: root.statusData.winkey
                        onToggled: state => {
                            root.executeCommand("winkey", state ? "1" : "0");
                        }
                    }

                    M3Switch {
                        icon: "lock"
                        title: "Fn Lock"
                        subtitle: "F1-F12 act as primary function keys rather than hotkeys"
                        checked: root.statusData.fn_lock
                        onToggled: state => {
                            root.executeCommand("fn_lock", state ? "1" : "0");
                        }
                    }
                }

                // 5. GodMode Power Limits
                M3Section {
                    icon: "bolt"
                    title: "GodMode Power Limits"

                    M3Notice {
                        visible: root.powerLimitsFeedback
                        icon: "check_circle"
                        text: "Custom CPU & GPU power limits applied to hardware!"
                    }

                    // CPU PL1
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        M3Icon {
                            text: "memory"
                            iconSize: 20
                            color: m3theme.subtext
                        }
                        M3Text {
                            text: "CPU Long-Term (PL1)"
                            Layout.preferredWidth: 150
                            color: m3theme.textPrimary
                        }
                        M3Slider {
                            Layout.fillWidth: true
                            from: 15
                            to: 115
                            stepSize: 5
                            value: root.sliderPl1
                            onMoved: val => root.sliderPl1 = Math.round(val)
                        }
                        M3Text {
                            text: `${root.sliderPl1}W`
                            font.weight: Font.Bold
                            Layout.preferredWidth: 42
                            horizontalAlignment: Text.AlignRight
                            color: m3theme.primary
                        }
                    }

                    // CPU PL2
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        M3Icon {
                            text: "memory"
                            iconSize: 20
                            color: m3theme.subtext
                        }
                        M3Text {
                            text: "CPU Short-Term (PL2)"
                            Layout.preferredWidth: 150
                            color: m3theme.textPrimary
                        }
                        M3Slider {
                            Layout.fillWidth: true
                            from: 25
                            to: 135
                            stepSize: 5
                            value: root.sliderPl2
                            onMoved: val => root.sliderPl2 = Math.round(val)
                        }
                        M3Text {
                            text: `${root.sliderPl2}W`
                            font.weight: Font.Bold
                            Layout.preferredWidth: 42
                            horizontalAlignment: Text.AlignRight
                            color: m3theme.primary
                        }
                    }

                    // GPU cTGP
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        M3Icon {
                            text: "sports_esports"
                            iconSize: 20
                            color: m3theme.subtext
                        }
                        M3Text {
                            text: "GPU Base cTGP"
                            Layout.preferredWidth: 150
                            color: m3theme.textPrimary
                        }
                        M3Slider {
                            Layout.fillWidth: true
                            from: 45
                            to: 105
                            stepSize: 5
                            value: root.sliderCtgp
                            onMoved: val => root.sliderCtgp = Math.round(val)
                        }
                        M3Text {
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

                        M3Icon {
                            text: "sports_esports"
                            iconSize: 20
                            color: m3theme.subtext
                        }
                        M3Text {
                            text: "GPU Dynamic Boost (PPAB)"
                            Layout.preferredWidth: 150
                            color: m3theme.textPrimary
                        }
                        M3Slider {
                            Layout.fillWidth: true
                            from: 5
                            to: 25
                            stepSize: 5
                            value: root.sliderPpab
                            onMoved: val => root.sliderPpab = Math.round(val)
                        }
                        M3Text {
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

                        M3Notice {
                            Layout.fillWidth: true
                            icon: "bolt"
                            text: `Combined Total GPU TGP: ${root.sliderCtgp + root.sliderPpab}W`
                        }

                        M3Button {
                            icon: "check"
                            text: "Apply Limits"
                            onClicked: root.applyPowerLimits(root.sliderPl1, root.sliderPl2, root.sliderCtgp, root.sliderPpab)
                        }
                    }
                }

                Item { implicitHeight: 16 }
            }
        }
    }
}
