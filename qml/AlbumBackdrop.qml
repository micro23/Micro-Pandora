import QtQuick
import QtQuick.Effects
import qs.Commons as Commons

Rectangle {
  id: root

  required property color baseColor
  required property color secondaryColor
  property string artSource: ""

  Behavior on baseColor {
    ColorAnimation { duration: Commons.Style.duration(260); easing.type: Easing.OutCubic }
  }
  Behavior on secondaryColor {
    ColorAnimation { duration: Commons.Style.duration(260); easing.type: Easing.OutCubic }
  }

  gradient: Gradient {
    orientation: Gradient.Horizontal
    GradientStop { position: 0; color: root.baseColor }
    GradientStop { position: 0.25; color: root.baseColor }
    GradientStop { position: 1; color: root.secondaryColor }
  }

  Loader {
    anchors.fill: parent
    active: root.visible && root.artSource !== ""

    sourceComponent: Item {
      readonly property real effectScale: 4

      ArtImage {
        id: coverTexture
        active: true
        requestedSource: root.artSource
        width: parent.width / parent.effectScale
        height: parent.height / parent.effectScale
        sourceSize.width: 160
        sourceSize.height: 160
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        clip: true
        visible: false
      }

      Rectangle {
        id: roundedMask
        width: coverTexture.width
        height: coverTexture.height
        radius: root.radius / parent.effectScale
        layer.enabled: root.radius > 0
        visible: false
      }

      MultiEffect {
        anchors.centerIn: parent
        width: coverTexture.width
        height: coverTexture.height
        scale: parent.effectScale
        visible: coverTexture.status === Image.Ready
        source: coverTexture
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 0.78
        blurMax: 20
        blurMultiplier: 1.0
        brightness: -0.36
        saturation: -0.10
        opacity: 0.27
        maskEnabled: root.radius > 0
        maskSource: roundedMask
      }
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: root.radius
    gradient: Gradient {
      GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.18) }
      GradientStop { position: 0.32; color: Qt.rgba(0, 0, 0, 0.12) }
      GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.57) }
    }
  }
}
