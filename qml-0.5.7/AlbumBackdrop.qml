import QtQuick
import QtQuick.Effects
import qs.Commons as Commons

Rectangle {
  id: root

  required property color baseColor
  required property color secondaryColor
  property string artSource: ""
  property bool fullWindow: false
  readonly property bool silhouetteReady: !!(silhouette.item && silhouette.item.hasArtwork)

  Behavior on baseColor {
    ColorAnimation { duration: Commons.Style.duration(295); easing.type: Easing.OutCubic }
  }
  Behavior on secondaryColor {
    ColorAnimation { duration: Commons.Style.duration(295); easing.type: Easing.OutCubic }
  }

  gradient: Gradient {
    orientation: Gradient.Horizontal
    GradientStop { position: 0; color: root.baseColor }
    GradientStop { position: 0.22; color: root.baseColor }
    GradientStop { position: 0.62; color: Qt.tint(root.baseColor, Commons.Util.alpha(root.secondaryColor, 0.42)) }
    GradientStop { position: 1; color: root.secondaryColor }
  }

  Loader {
    id: silhouette
    anchors.right: parent.right
    anchors.rightMargin: Math.round(parent.width * 0.035)
    anchors.verticalCenter: parent.verticalCenter
    width: Math.round(Math.min(parent.width * 0.54, parent.height * 0.84))
    height: width
    active: root.fullWindow && root.visible
    sourceComponent: CoverTransition {
      objectName: "fullWindowCoverArt"
      decodeSize: 1600
      artworkOpacity: 0.34
      holdUntilReplaced: true
      requestedSource: root.artSource
    }
  }

  Loader {
    anchors.fill: parent
    active: !root.fullWindow && root.visible && root.artSource !== ""

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
        visible: coverTexture.hasArtwork
        source: coverTexture
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 0.86
        blurMax: 20
        blurMultiplier: 1.0
        brightness: -0.36
        saturation: -0.18
        opacity: 0.23
        maskEnabled: root.radius > 0
        maskSource: roundedMask
      }
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: root.radius
    gradient: Gradient {
      GradientStop { position: 0; color: Qt.rgba(0, 0, 0, root.fullWindow ? 0.52 : 0.24) }
      GradientStop { position: 0.36; color: Qt.rgba(0, 0, 0, root.fullWindow ? 0.19 : 0.08) }
      GradientStop { position: 0.73; color: Qt.rgba(0, 0, 0, root.fullWindow ? 0.31 : 0.33) }
      GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.72) }
    }
  }
}
