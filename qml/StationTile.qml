import QtQuick
import qs.Commons
import qs.Ui

Button {
  id: root
  property bool currentStation: false

  Accessible.role: Accessible.Button
  Accessible.name: root.text
  Accessible.description: root.currentStation ? "Current station" : ""
  Accessible.onPressAction: if (root.enabled) root.clicked()

  leftAlign: true
  height: Style.space(32)
  horizontalPadding: Style.space(12)
  verticalPadding: Style.space(4)
  iconSize: Style.font.body
  background: currentStation || selected ? Util.alpha(accent, 0.16) : "transparent"
  color: hot ? Style.hoverFillFor(foreground, accent) : background
  gradient: currentStation || selected ? stationWash : null

  Gradient {
    id: stationWash
    orientation: Gradient.Horizontal
    GradientStop { position: 0; color: Qt.tint(root.color, Util.alpha(root.accent, 0.16)) }
    GradientStop { position: 0.72; color: root.color }
    GradientStop { position: 1; color: Qt.tint(root.color, Util.alpha(root.accent, 0.02)) }
  }

  Rectangle {
    opacity: root.currentStation ? 1 : root.selected ? 0.52 : 0
    visible: opacity > 0
    anchors.left: parent.left
    anchors.leftMargin: Style.space(3)
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(3)
    height: parent.height * 0.57
    radius: width / 2
    color: root.accent
    Behavior on opacity { NumberAnimation { duration: Style.duration(170) } }
  }
}
