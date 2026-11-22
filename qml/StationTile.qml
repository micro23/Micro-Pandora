import QtQuick
import qs.Commons
import qs.Ui

Button {
  id: root

  property bool currentStation: false
  property bool playingStation: false

  Accessible.role: Accessible.Button
  Accessible.name: root.text
  Accessible.description: root.currentStation ? "Current station" : ""
  Accessible.onPressAction: if (root.enabled) root.clicked()

  leftAlign: true
  height: Style.space(33)
  radius: Style.space(8)
  horizontalPadding: Style.space(11)
  verticalPadding: Style.space(4)
  iconSize: Style.font.body
  fontFamily: "Adwaita Sans"
  background: currentStation ? Util.alpha(accent, 0.16)
    : selected ? Util.alpha(accent, 0.10) : "transparent"
  color: hot ? Util.alpha(accent, 0.20) : background
  borderSpec: Border.flat(Util.alpha(accent, currentStation ? 0.25 : selected || bordered ? 0.18 : 0), 1)
  rightPadding: playingStation ? Style.space(24) : horizontalPadding

  PlaybackIndicator {
    anchors.verticalCenter: parent.verticalCenter
    anchors.right: parent.right
    anchors.rightMargin: Style.space(8)
    width: Style.space(12)
    height: width
    visible: root.playingStation
    playing: root.playingStation
    tone: root.accent
  }
}
