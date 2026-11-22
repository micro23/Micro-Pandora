import QtQuick
import qs.Commons

NumberAnimation {
  id: root

  required property string trackKey
  property bool shown: true

  property: "opacity"
  from: 0.59
  to: 1
  duration: Style.duration(205)
  easing.type: Easing.OutCubic

  onTrackKeyChanged: if (shown && !Style.reduceMotion) restart()
}
