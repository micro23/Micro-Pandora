import QtQuick
import qs.Commons as Commons

Item {
  id: root

  property string requestedSource: ""
  property bool active: visible
  property int decodeSize: 192
  property int displayIndex: -1
  property bool initialized: false
  readonly property bool hasArtwork: displayIndex >= 0

  function updateSource() {
    var requested = active && first.isLocalFile(requestedSource) ? requestedSource : ""
    if (!requested) {
      displayIndex = -1
      first.requestedSource = ""
      second.requestedSource = ""
      return
    }

    var current = displayIndex === 0 ? first : displayIndex === 1 ? second : null
    if (current && current.requestedSource === requested) return
    var spare = current === first ? second : first
    spare.requestedSource = requested
    checkReady(spare)
  }

  function checkReady(image) {
    if (!active || !image.requestedSource || image.requestedSource !== requestedSource) return
    if (image.status === Image.Ready) {
      displayIndex = image.bufferIndex
    } else if (image.status === Image.Error) {
      displayIndex = -1
    }
  }

  onActiveChanged: if (initialized) updateSource()
  onRequestedSourceChanged: if (initialized) updateSource()
  Component.onCompleted: {
    initialized = true
    updateSource()
  }

  component Buffer: ArtImage {
    id: buffer
    required property int bufferIndex
    anchors.fill: parent
    active: root.active
    sourceSize.width: root.decodeSize
    sourceSize.height: root.decodeSize
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    opacity: root.displayIndex === bufferIndex ? 1 : 0
    z: root.displayIndex === bufferIndex ? 1 : 0
    onStatusChanged: root.checkReady(buffer)

    Behavior on opacity {
      enabled: root.active && root.requestedSource !== ""
      NumberAnimation { duration: Commons.Style.duration(245); easing.type: Easing.OutCubic }
    }
  }

  Buffer { id: first; bufferIndex: 0 }
  Buffer { id: second; bufferIndex: 1 }
}
