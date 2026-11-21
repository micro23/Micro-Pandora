import QtQuick
import Quickshell

ShellRoot {
  id: root

  function component(name) {
    var url = "file://" + Quickshell.env("MICRO_PANDORA_TEST_ROOT") + "/qml/" + name + ".qml"
    var result = Qt.createComponent(url)
    check(result.status === Component.Ready, name + ": " + result.errorString())
    return result
  }

  function check(result, message) {
    if (!result) throw new Error(message)
  }

  Timer {
    interval: 80
    running: true
    onTriggered: {
      try {
        var visualizer = root.component("Visualizer").createObject(null, {
          width: 1600, height: 760, centerHeight: 250, protectedWidth: 700, active: false
        })
        root.check(visualizer.modeName === "Spectrum", "initial visualizer")
        for (var name of ["Mirror", "Orbit", "Spectrum"]) {
          visualizer.nextMode()
          root.check(visualizer.modeName === name, "visualizer cycles to " + name)
        }
        root.check(visualizer.heightLimit(12, 24) === 760, "room for high peaks at the edge")
        root.check(visualizer.heightLimit(800, 24) === 250, "protect the artwork at the center")
        visualizer.parseFrame("72;".repeat(55) + "100;")
        root.check(visualizer.levels[0] < 0.9 && visualizer.levels[55] === 1,
                   "loud bands retain headroom")
        visualizer.destroy()

        var service = root.component("Service").createObject(null)
        function snapshot() {
          return { stations: [{ path: "/jazz", name: "Evening Jazz" },
                              { path: "/dance", name: "Dance" }],
                   artPalette: { background: "#24313b" } }
        }
        service.applyStatus(snapshot())
        var stations = service.stations
        var palette = service.artPalette
        service.applyStatus(snapshot())
        root.check(stations === service.stations, "stable station delegate input during polling")
        root.check(palette === service.artPalette, "stable palette during polling")

        var panel = root.component("Panel").createObject(null, { service: service })
        panel.focusSearch()
        panel.stationFilter = "jazz"
        root.check(panel.currentTab === "stations", "search opens its results")
        root.check(panel.keyboardStations.length === 1
                   && panel.keyboardStations[0].path === "/jazz", "keyboard navigation uses filtered results")
        panel.closeSearch()
        root.check(panel.currentTab === "nowplaying", "search returns to now playing")
        panel.destroy()
        service.destroy()
        console.log("MICRO_PANDORA_RUNTIME_OK")
      } catch (error) {
        console.error("MICRO_PANDORA_RUNTIME_FAILURE " + error)
      }
      Qt.quit()
    }
  }
}
