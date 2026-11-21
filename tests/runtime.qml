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
        root.check(visualizer.displayLevels === visualizer.levels,
                   "a hidden visualizer applies new levels without animation")
        visualizer.displayLevels = visualizer.blankLevels()
        visualizer.peakLevels = visualizer.blankLevels()
        visualizer.settleLevels(0.016)
        var risingBand = visualizer.displayLevels[55]
        root.check(risingBand > 0.06 && risingBand < 1 && visualizer.peakLevels[55] === 1,
                   "band attack eases upward with a separate peak marker")
        visualizer.parseFrame("0;".repeat(56))
        visualizer.displayLevels = Array(56).fill(risingBand)
        visualizer.peakLevels = Array(56).fill(1)
        visualizer.settleLevels(0.016)
        root.check(visualizer.displayLevels[55] < risingBand
                   && visualizer.peakLevels[55] > visualizer.displayLevels[55],
                   "peak marker falls more slowly than the band")
        for (var frame = 0; frame < 40; frame++) visualizer.settleLevels(0.05)
        root.check(!visualizer.settling && visualizer.displayLevels[55] === 0.03
                   && visualizer.peakLevels[55] === 0.03,
                   "a quiet spectrum settles and stops requesting frames")
        var quietLevels = visualizer.levels
        visualizer.parseFrame("0;".repeat(56))
        root.check(quietLevels === visualizer.levels, "repeated silence leaves the spectrum settled")
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
        var settings = root.component("PlayerSettings").createObject(null, {
          account: service.account, foreground: "#eee", muted: "#ccc",
          accent: "#8cf", accentAlt: "#fba", background: "#203243"
        })
        root.check(settings && !settings.formReady, "sign-in waits for dependency checks")
        settings.destroy()
        service.account.missing = ["pithos"]
        service.account.checked = true
        panel.open("{}")
        root.check(panel.currentTab === "setup", "a fresh install opens directly to setup")
        panel.close()
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
