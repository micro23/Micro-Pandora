import QtQuick
import qs.Commons

Item {
  id: root

  required property bool playing
  required property color tone
  property bool active: visible
  readonly property bool animate: active && playing && !Style.reduceMotion

  implicitWidth: Style.space(16)
  implicitHeight: Style.space(16)

  Row {
    anchors.centerIn: parent
    spacing: Style.space(2)

    Repeater {
      model: [0.49, 0.84, 0.64, 0.39]

      Item {
        required property int index
        required property real modelData
        width: Style.space(2)
        height: root.height

        Rectangle {
          id: stem
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width
          height: Math.max(2, parent.height * (root.playing ? parent.modelData : 0.19))
          radius: width / 2
          color: root.tone
          opacity: root.playing ? 1 : 0.65

          SequentialAnimation on scale {
            running: root.animate
            loops: Animation.Infinite
            PauseAnimation { duration: Style.duration(105 * stem.parent.index) }
            NumberAnimation { from: 1; to: 0.42; duration: Style.duration(235); easing.type: Easing.OutCubic }
            NumberAnimation { from: 0.42; to: 1; duration: Style.duration(215); easing.type: Easing.OutCubic }
            onStopped: stem.scale = 1
          }
        }
      }
    }
  }
}
