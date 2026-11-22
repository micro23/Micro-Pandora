import QtQuick
import qs.Commons
import qs.Ui

Button {
  id: root

  property string glyphText: ""
  property real glyphSize: Style.font.icon
  property real controlSize: Style.space(32)
  property bool primary: false
  property color accentAlt: accent
  readonly property color primaryInk: Qt.tint("#111318", Util.alpha(accent, 0.12))

  Accessible.role: Accessible.Button
  Accessible.name: root.tooltipText
  Accessible.onPressAction: if (root.enabled) root.clicked()

  implicitWidth: controlSize
  implicitHeight: controlSize
  width: implicitWidth
  height: implicitHeight
  horizontalPadding: 0
  verticalPadding: 0
  radius: root.primary ? width / 2 : Style.space(8)
  gradient: root.primary && enabled ? transportShine : null

  Gradient {
    id: transportShine
    orientation: Gradient.Horizontal
    GradientStop { position: 0; color: Qt.tint(root.accentAlt, Qt.rgba(1, 1, 1, root.hot ? 0.30 : 0.15)) }
    GradientStop { position: 1; color: Qt.tint(root.accent, Qt.rgba(1, 1, 1, root.hot ? 0.38 : 0.21)) }
  }

  readonly property int renderedGlyphSize: Math.max(1, Math.round(glyphSize))
  readonly property real tightGlyphWidth: Math.max(1,
    glyphMetrics.tightBoundingRect.width)
  readonly property real tightGlyphHeight: Math.max(1,
    glyphMetrics.tightBoundingRect.height)

  TextMetrics {
    id: glyphMetrics
    font.family: root.fontFamily
    font.pixelSize: root.renderedGlyphSize
    text: root.glyphText
  }

  Text {
    id: glyph
    textFormat: Text.PlainText
    anchors.centerIn: parent
    anchors.horizontalCenterOffset: implicitWidth / 2
      - (glyphMetrics.tightBoundingRect.x + root.tightGlyphWidth / 2)
    anchors.verticalCenterOffset: implicitHeight / 2
      - (baselineOffset + glyphMetrics.tightBoundingRect.y
        + root.tightGlyphHeight / 2)
    text: root.glyphText
    font.family: root.fontFamily
    font.pixelSize: root.renderedGlyphSize
    renderType: Text.NativeRendering
    color: root.primary && root.enabled ? root.primaryInk : root.foreground
  }
}
