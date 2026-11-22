import QtQuick
import qs.Commons
import qs.Ui

BorderSurface {
  id: root

  required property var modes
  required property int current
  required property color foreground
  required property color muted
  required property color accent
  readonly property real inset: Style.space(4)
  readonly property real slotWidth: Style.space(74)
  readonly property real slotHeight: Style.space(29)

  signal chosen(int mode)

  radius: Style.space(12)
  color: Util.alpha("#05070a", 0.62)
  borderSpec: Border.flat(Util.alpha(foreground, 0.15), 1)
  implicitWidth: choices.implicitWidth + inset * 2
  implicitHeight: slotHeight + inset * 2

  Rectangle {
    x: root.inset + (LayoutMirroring.enabled ? root.modes.length - 1 - root.current : root.current)
       * (root.slotWidth + choices.spacing)
    anchors.verticalCenter: parent.verticalCenter
    width: root.slotWidth
    height: root.slotHeight
    radius: Style.space(8)
    border.color: Util.alpha(root.accent, 0.35)
    border.width: 1
    gradient: Gradient {
      GradientStop { position: 0; color: Util.alpha(root.accent, 0.27) }
      GradientStop { position: 1; color: Util.alpha(root.accent, 0.10) }
    }

    Behavior on x {
      NumberAnimation { duration: Style.duration(185); easing.type: Easing.OutCubic }
    }

    Rectangle {
      width: Style.space(20)
      height: 1
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 1
      radius: 1
      color: Util.alpha(root.accent, 0.81)
    }
  }

  Row {
    id: choices
    anchors.centerIn: parent
    spacing: Style.space(2)

    Repeater {
      model: root.modes

      Button {
        required property int index
        required property string modelData

        text: modelData
        active: index === root.current
        Accessible.role: Accessible.RadioButton
        Accessible.name: modelData + " visualizer"
        Accessible.checked: active
        Accessible.onPressAction: root.chosen(index)
        tooltipText: modelData + " visualizer · V to cycle"
        onClicked: root.chosen(index)

        width: root.slotWidth
        height: root.slotHeight
        radius: Style.space(8)
        horizontalPadding: Style.space(8)
        verticalPadding: 0
        foreground: active ? root.foreground : root.muted
        accent: root.accent
        fontFamily: "Adwaita Sans"
        fontSize: Style.font.bodySmall
        color: hot && !active ? Util.alpha(root.accent, 0.11) : "transparent"
        borderSpec: Border.none()
      }
    }
  }
}
