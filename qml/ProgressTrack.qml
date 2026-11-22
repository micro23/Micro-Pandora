import QtQuick
import qs.Commons
import "Api.js" as Api

Item {
  id: root

  required property real position
  required property real duration
  required property color foreground
  required property color muted
  required property color accent
  required property color accentAlt
  property bool inlineTimes: true
  readonly property real fraction: duration > 0 ? Api.clampUnit(position / duration) : 0

  implicitHeight: inlineTimes ? Style.space(17) : times.implicitHeight + Style.space(10)
  Accessible.role: Accessible.ProgressBar
  Accessible.name: "Track progress"
  Accessible.description: elapsed.text + " / " + total.text

  Rectangle {
    id: line
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: root.inlineTimes ? Style.space(42) : 0
    anchors.rightMargin: root.inlineTimes ? Style.space(42) : 0
    anchors.verticalCenter: root.inlineTimes ? parent.verticalCenter : undefined
    anchors.top: root.inlineTimes ? undefined : parent.top
    height: Style.space(4)
    radius: height / 2
    color: Util.alpha(root.foreground, 0.15)

    Rectangle {
      width: parent.width * root.fraction
      height: parent.height
      radius: height / 2
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: root.accentAlt }
        GradientStop { position: 1; color: root.accent }
      }

      Behavior on width {
        enabled: root.visible && width > 0
        NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic }
      }

      Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(7)
        height: width
        radius: width / 2
        visible: parent.width >= width
        color: Qt.tint(root.accent, Util.alpha(root.foreground, 0.30))
      }
    }
  }

  Item {
    id: times
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: root.inlineTimes ? undefined : line.bottom
    anchors.topMargin: Style.space(6)
    anchors.verticalCenter: root.inlineTimes ? parent.verticalCenter : undefined
    implicitHeight: elapsed.implicitHeight

    Text {
      id: elapsed
      anchors.left: parent.left
      textFormat: Text.PlainText
      text: Api.millisecondsToClock(root.position * 1000)
      color: root.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }

    Text {
      id: total
      anchors.right: parent.right
      textFormat: Text.PlainText
      text: Api.millisecondsToClock(root.duration * 1000)
      color: root.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
  }
}
