import QtQuick
import qs.Commons as Commons

// Album art. Pithos downloads the cover itself and reports a file:// path
// in its own cache, so only local files are loaded: the shell never fetches
// anything over the network for Micro-Pandora.
Image {
  id: root

  property string requestedSource: ""
  property bool active: !parent || parent.visible
  property bool fadeIn: false
  property bool hasLoadedCover: false
  readonly property bool hasArtwork: status === Image.Ready
    || (status === Image.Loading && hasLoadedCover)

  retainWhileLoading: true
  autoTransform: true

  onStatusChanged: {
    if (status === Image.Ready) {
      if (fadeIn && !hasLoadedCover && !Commons.Style.reduceMotion) entrance.restart()
      hasLoadedCover = true
    } else if (status !== Image.Loading) {
      entrance.stop()
      opacity = 1
      hasLoadedCover = false
    }
  }

  NumberAnimation on opacity {
    id: entrance
    running: false
    from: 0
    to: 1
    duration: Commons.Style.duration(180)
    easing.type: Easing.OutCubic
  }

  function isLocalFile(url) {
    return /^file:\/\/(?:localhost)?\//i.test(String(url || ""))
  }

  source: active && isLocalFile(requestedSource) ? requestedSource : ""
}
