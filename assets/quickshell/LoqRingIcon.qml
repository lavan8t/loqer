import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.modules.common
import qs.services

Item {
    id: root

    property int implicitSize: 20
    property real ringThickness: (implicitSize / 2) * 0.3024 // precision LOQ ring rim thickness
    property real cutAngle: 15 // 15 degrees sector cut
    property real arcSweep: (360 / 3) - cutAngle // 105 degrees sweep per segment

    // Track active LOQ profile discretely so spin animation triggers ONLY when mode changes,
    // not on every animation frame of ringColor's 250ms color transition
    property string activeProfile: {
        let p = (Battery.powerData?.profile ?? Battery.powerProfileName ?? "").toLowerCase();
        if (p.indexOf("quiet") !== -1 || p.indexOf("low-power") !== -1 || p.indexOf("saver") !== -1 || p.indexOf("blue") !== -1) return "quiet";
        if (p.indexOf("perf") !== -1 || p.indexOf("red") !== -1) return "performance";
        if (p.indexOf("custom") !== -1 || p.indexOf("max") !== -1 || p.indexOf("pink") !== -1) return "custom";
        return "balanced";
    }

    onActiveProfileChanged: {
        triggerSpin();
    }

    // Color dynamically matches active LOQ profile
    property color ringColor: {
        if (activeProfile === "quiet") return "#38BDF8";
        if (activeProfile === "performance") return "#EF4444";
        if (activeProfile === "custom") return "#EC4899";
        return "#F8FAFC";
    }

    Behavior on ringColor {
        ColorAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    NumberAnimation {
        id: spinAnim
        target: root
        property: "rotation"
        from: 0
        to: 360
        duration: 550
        easing.type: Easing.OutBack
        easing.overshoot: 1.15
        onFinished: {
            root.rotation = 0;
        }
        onStopped: {
            root.rotation = 0;
        }
    }

    function triggerSpin() {
        if (spinAnim.running) {
            return;
        }
        root.rotation = 0;
        spinAnim.restart();
    }

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    readonly property real centerX: width / 2
    readonly property real centerY: height / 2
    readonly property real arcRadius: (implicitSize / 2) - (ringThickness / 2)

    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true
        preferredRendererType: Shape.CurveRenderer

        // Segment 1: Top-Right to Bottom (337.5° [-22.5°] to 82.5°, sweep 105°)
        ShapePath {
            strokeColor: root.ringColor
            strokeWidth: root.ringThickness
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap

            PathAngleArc {
                moveToStart: true
                centerX: root.centerX
                centerY: root.centerY
                radiusX: root.arcRadius
                radiusY: root.arcRadius
                startAngle: -22.5
                sweepAngle: root.arcSweep
            }
        }

        // Segment 2: Bottom to Top-Left (97.5° to 202.5°, sweep 105°)
        ShapePath {
            strokeColor: root.ringColor
            strokeWidth: root.ringThickness
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap

            PathAngleArc {
                moveToStart: true
                centerX: root.centerX
                centerY: root.centerY
                radiusX: root.arcRadius
                radiusY: root.arcRadius
                startAngle: 97.5
                sweepAngle: root.arcSweep
            }
        }

        // Segment 3: Top-Left to Top-Right (217.5° to 322.5°, sweep 105°)
        ShapePath {
            strokeColor: root.ringColor
            strokeWidth: root.ringThickness
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap

            PathAngleArc {
                moveToStart: true
                centerX: root.centerX
                centerY: root.centerY
                radiusX: root.arcRadius
                radiusY: root.arcRadius
                startAngle: 217.5
                sweepAngle: root.arcSweep
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            mouse.accepted = true;
            root.triggerSpin();
            Quickshell.execDetached(["bash", "-c", "loqer || /usr/local/bin/loqer || /home/lavan/.local/bin/loqer"]);
        }
    }
}
