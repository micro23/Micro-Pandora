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

  signal chosen(int mode)

  radius: Style.space(10)
  color: Util.alpha("#05070a", 0.46)
  borderSpec: Border.flat(Util.alpha(foreground, 0.12), 1)
  implicitWidth: choices.implicitWidth + Style.space(8)
  implicitHeight: choices.implicitHeight + Style.space(8)

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
        selected: index === root.current
        Accessible.role: Accessible.RadioButton
        Accessible.name: modelData + " visualizer"
        Accessible.checked: selected
        Accessible.onPressAction: root.chosen(index)
        tooltipText: modelData + " visualizer · V to cycle"
        onClicked: root.chosen(index)

        height: Style.space(27)
        radius: Style.space(7)
        horizontalPadding: Style.space(11)
        verticalPadding: 0
        foreground: selected ? root.foreground : root.muted
        accent: root.accent
        fontFamily: "Adwaita Sans"
        fontSize: Style.font.bodySmall
        background: selected ? Util.alpha(root.accent, 0.16) : "transparent"
        color: hot ? Util.alpha(root.accent, 0.24) : background
        borderSpec: Border.flat(Util.alpha(root.accent, selected ? 0.30 : 0), 1)
      }
    }
  }
}
