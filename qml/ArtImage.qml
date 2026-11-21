import QtQuick

// Album art. Pithos downloads the cover itself and reports a file:// path
// in its own cache, so only local files are loaded: the shell never fetches
// anything over the network for Micro-Pandora.
Image {
  property string requestedSource: ""
  property bool active: !parent || parent.visible

  function isLocalFile(url) {
    return /^file:\/\/(?:localhost)?\//i.test(String(url || ""))
  }

  source: active && isLocalFile(requestedSource) ? requestedSource : ""
}
