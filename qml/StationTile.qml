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

  Rectangle {
    visible: root.currentStation || root.selected
    anchors.left: parent.left
    anchors.leftMargin: Style.space(3)
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(3)
    height: parent.height * 0.57
    radius: width / 2
    color: Util.alpha(root.accent, root.currentStation ? 1 : 0.48)
  }
}
