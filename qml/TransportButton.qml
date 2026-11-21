import QtQuick
import qs.Commons
import qs.Ui

Button {
  id: root

  property string glyphText: ""
  property real glyphSize: Style.font.icon
  property real controlSize: Style.space(32)

  Accessible.role: Accessible.Button
  Accessible.name: root.tooltipText
  Accessible.onPressAction: if (root.enabled) root.clicked()

  width: controlSize
  height: controlSize
  horizontalPadding: 0
  verticalPadding: 0
  gradient: selected && enabled ? transportShine : null

  Gradient {
    id: transportShine
    GradientStop { position: 0; color: Qt.tint(root.color, Util.alpha(root.accent, root.hot ? 0.25 : 0.15)) }
    GradientStop { position: 0.36; color: Qt.tint(root.color, Util.alpha(root.accent, 0.09)) }
    GradientStop { position: 1; color: root.color }
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
    color: root.selected
      ? Style.selectedStateColor(root.foreground, root.accent)
      : root.foreground
  }
}
