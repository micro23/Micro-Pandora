import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Omarchy has no shell property for the window look. The mode is which
// toggle file exists: window-opaque.lua, window-glassy.lua, or neither.
Item {
  id: root

  property string mode: "transparent"
  readonly property bool opaque: mode === "opaque"
  readonly property bool glassy: mode === "glassy"
  readonly property string toggles: Quickshell.env("HOME") + "/.local/state/omarchy/toggles/hypr"

  function recheck() {
    if (!probe.running) probe.running = true
  }

  Process {
    id: probe
    running: true
    command: ["timeout", "3", "bash", "-c", "d=\"$HOME/.local/state/omarchy/toggles/hypr\"; if [[ -f \"$d/window-opaque.lua\" ]]; then echo opaque; elif [[ -f \"$d/window-glassy.lua\" ]]; then echo glassy; else echo transparent; fi"]
    stdout: SplitParser {
      onRead: function (line) {
        var next = String(line).trim()
        if (next === "opaque" || next === "glassy" || next === "transparent")
          root.mode = next
      }
    }
  }

  FileView {
    path: root.toggles
    watchChanges: true
    printErrors: false
    onFileChanged: root.recheck()
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event && String(event.name) === "configreloaded") root.recheck()
    }
  }
}
