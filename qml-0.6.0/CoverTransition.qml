import QtQuick
import qs.Commons as Commons

Item {
  id: root

  property string requestedSource: ""
  property bool active: visible
  property int decodeSize: 192
  property int fillMode: Image.PreserveAspectFit
  property bool holdUntilReplaced: false
  property real artworkOpacity: 1
  property int displayIndex: -1
  property int previousIndex: -1
  property real blend: 1
  property bool initialized: false
  readonly property bool hasArtwork: displayIndex >= 0
  // Compose the two opaque image buffers at a constant overall opacity.
  // This keeps translucent backdrops from brightening during a crossfade.
  readonly property real incomingOpacity: artworkOpacity * blend
  readonly property real outgoingOpacity: incomingOpacity < 1
    ? (artworkOpacity - incomingOpacity) / (1 - incomingOpacity) : 0

  signal sourceFailed(string source)

  function finishBlend() {
    reveal.stop()
    previousIndex = -1
    blend = 1
  }

  function updateSource() {
    var requested = active && first.isLocalFile(requestedSource) ? requestedSource : ""
    if (!requested) {
      if (active && holdUntilReplaced && hasArtwork) return
      finishBlend()
      displayIndex = -1
      first.requestedSource = ""
      second.requestedSource = ""
      return
    }

    var current = displayIndex === 0 ? first : displayIndex === 1 ? second : null
    if (current && current.requestedSource === requested) return
    var spare = current === first ? second : first
    // Rapid changes may reuse the previous image. Finish its crossfade
    // before starting another decode in that buffer.
    if (previousIndex === spare.bufferIndex && spare.requestedSource !== requested)
      finishBlend()
    spare.requestedSource = requested
    checkReady(spare)
  }

  function checkReady(image) {
    if (!active || !image.requestedSource || image.requestedSource !== requestedSource) return
    if (image.status === Image.Ready) {
      if (displayIndex === image.bufferIndex) return
      reveal.stop()
      previousIndex = displayIndex
      blend = 0
      displayIndex = image.bufferIndex
      if (holdUntilReplaced || Commons.Style.reduceMotion) finishBlend()
      else reveal.start()
    } else if (image.status === Image.Error) {
      var failedSource = image.requestedSource
      sourceFailed(failedSource)
      if (holdUntilReplaced || requestedSource !== failedSource) return
      finishBlend()
      displayIndex = -1
    }
  }

  onActiveChanged: if (initialized) updateSource()
  onRequestedSourceChanged: if (initialized) updateSource()
  Component.onCompleted: {
    initialized = true
    updateSource()
  }

  NumberAnimation {
    id: reveal
    target: root
    property: "blend"
    to: 1
    duration: Commons.Style.duration(265)
    easing.type: Easing.OutCubic
    onFinished: root.previousIndex = -1
  }

  component Buffer: ArtImage {
    id: buffer
    required property int bufferIndex
    anchors.fill: parent
    active: root.active
    sourceSize.width: root.decodeSize
    sourceSize.height: root.decodeSize
    fillMode: root.fillMode
    smooth: true
    asynchronous: true
    opacity: root.displayIndex === bufferIndex ? root.incomingOpacity
      : root.previousIndex === bufferIndex ? root.outgoingOpacity : 0
    z: root.displayIndex === bufferIndex ? 1 : 0
    onStatusChanged: root.checkReady(buffer)

  }

  Buffer { id: first; bufferIndex: 0 }
  Buffer { id: second; bufferIndex: 1 }
}
