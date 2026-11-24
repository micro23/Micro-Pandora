import QtQuick
import Quickshell
import qs.Commons

ShellRoot {
  id: root
  property var testedPanel
  property var testedService
  property var testedBackdrop

  function component(name) {
    var url = "file://" + Quickshell.env("MICRO_PANDORA_TEST_UI") + "/" + name + ".qml"
    var result = Qt.createComponent(url)
    check(result.status === Component.Ready, name + ": " + result.errorString())
    return result
  }

  function check(result, message) {
    if (!result) throw new Error(message)
  }

  function findVisualChild(item, name) {
    if (item.objectName === name) return item
    for (var child of item.children) {
      var match = findVisualChild(child, name)
      if (match) return match
    }
    return null
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
        for (var name of ["Mirror", "Orbit", "Off", "Spectrum"]) {
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

        var orbit = root.component("OrbitBands").createObject(null, {
          width: 980, height: 310, playing: true, motionEnabled: false,
          guideColor: "#acf", tones: Array(56).fill(Qt.rgba(0.5, 0.8, 1, 1)),
          levels: Array(56).fill(0.04)
        })
        var floor = orbit.originY
        var east = orbit.point(0, 1, 0)
        var west = orbit.point(Math.PI, 1, 0)
        root.check(east[1] === west[1] && (east[0] + west[0]) / 2 === orbit.originX,
                   "Orbit is level and centered at rest")
        var lowHit = Array(9).fill(0.98).concat(Array(47).fill(0.17))
        orbit.levels = lowHit
        var peakLift = 0
        for (var hitFrame = 0; hitFrame < 23; hitFrame++) {
          orbit.advance(0.016)
          peakLift = Math.max(peakLift, orbit.lift)
        }
        root.check(orbit.beatStrength > 0.75 && Math.abs(orbit.orbitTilt) > 0.1,
                   "bass hits launch a strong ripple and tilt the rings")
        root.check(orbit.phase > 0.5 && peakLift >= 0.5 && orbit.originY < floor - 13,
                   "Orbit turns and lifts on a bass hit")
        east = orbit.point(0.36, 1.2, -25)
        west = orbit.point(Math.PI - 0.36, 1.2, -25)
        root.check(Math.abs(east[1] - west[1]) < 0.001
                   && Math.abs(east[0] + west[0] - 2 * orbit.originX) < 0.001,
                   "a bass hit lifts the two sides equally")
        orbit.levels = Array(56).fill(0.03)
        for (var releaseFrame = 0; releaseFrame < 60; releaseFrame++) orbit.advance(0.016)
        root.check(orbit.lift < peakLift * 0.18, "Orbit settles after the hit")
        root.check(!orbit.moving && !orbit.settling, "Orbit respects reduced motion")
        orbit.destroy()

        var cover = root.component("CoverTransition").createObject(null, {
          artworkOpacity: 0.43, blend: 0.58
        })
        var combined = cover.incomingOpacity + (1 - cover.incomingOpacity) * cover.outgoingOpacity
        root.check(Math.abs(combined - cover.artworkOpacity) < 0.001,
                   "translucent covers keep the same total opacity during a crossfade")
        cover.destroy()

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

        Style.reduceMotion = true
        var panel = root.component("Panel").createObject(null, { service: service })
        panel.open("{}")
        var content = null
        for (var object of panel.data) {
          if (object.contentItem && object.title === "Micro-Pandora") content = object.contentItem
        }
        root.check(content !== null, "full player window exists")
        var sidebar = root.findVisualChild(content, "stationSidebar")
        root.testedBackdrop = root.findVisualChild(content, "windowAlbumBackdrop")
        root.check(root.testedBackdrop && root.testedBackdrop.fullWindow
                   && root.testedBackdrop.width === content.width, "the album backdrop fills the window")
        var sidebarToggle = root.findVisualChild(content, "stationSidebarToggle")
        root.check(sidebar && sidebarToggle && sidebar.width > 0, "station sidebar starts expanded")
        sidebarToggle.clicked()
        root.check(panel.sidebarCollapsed && service.stationSidebarCollapsed && sidebar.width === 0,
                   "the header control hides the sidebar and frees its complete width")
        root.check(sidebarToggle.visible && sidebarToggle.enabled, "the restore control stays available")
        panel.close()
        panel.open("{}")
        root.check(panel.sidebarCollapsed && sidebar.width === 0, "sidebar choice survives a reopening")
        sidebarToggle.clicked()
        root.check(!panel.sidebarCollapsed && sidebar.width > 0, "the header control restores the sidebar")
        panel.selectVisualizer(2)
        root.check(service.visualizerMode === 2, "the picker records the chosen visualizer")
        panel.nextVisualizer()
        var panelVisualizer = root.findVisualChild(content, "playerVisualizer")
        service.applyStatus(Object.assign(snapshot(), { connected: true, status: "Playing" }))
        root.check(service.visualizerMode === 3 && !panelVisualizer.visualizing
                   && !panelVisualizer.shouldCapture && panelVisualizer.stageEnergy === 0
                   && service.playing && panelVisualizer.playing,
                   "Off stops the visualizer and keeps Pandora playing")
        panel.close()
        panel.open("{}")
        root.check(panelVisualizer.modeName === "Off", "Off survives reopening the player")
        panel.nextVisualizer()
        root.check(service.visualizerMode === 0 && panelVisualizer.shouldCapture,
                   "V cycles from Off to Spectrum and resumes capture")
        service.applyStatus(snapshot())

        panel.focusSearch()
        panel.stationFilter = "jazz"
        root.check(panel.currentTab === "stations", "search opens its results")
        root.check(panel.keyboardStations.length === 1
                   && panel.keyboardStations[0].path === "/jazz", "keyboard navigation uses filtered results")
        panel.closeSearch()
        root.check(panel.currentTab === "nowplaying", "search returns to now playing")
        var settings = root.component("PlayerSettings").createObject(null, {
          account: service.account, updater: service.updater, foreground: "#eee", muted: "#ccc",
          accent: "#8cf", accentAlt: "#fba", background: "#203243"
        })
        root.check(settings && !settings.formReady, "sign-in waits for dependency checks")
        root.check(root.findVisualChild(settings, "appUpdates").visible, "Settings includes app updates")
        root.check(service.updater.isNewer("0.10.0", "0.9.12")
                   && !service.updater.isNewer("0.9.4", "0.9.12")
                   && !service.updater.isNewer("0.10.0-beta", "0.9.12"),
                   "update availability compares stable version numbers")
        settings.destroy()
        service.account.missing = ["pithos"]
        service.account.checked = true
        panel.open("{}")
        root.check(panel.currentTab === "setup", "a fresh install opens directly to setup")
        root.testedPanel = panel
        root.testedService = service
        var coverUrl = "file://" + Quickshell.env("MICRO_PANDORA_TEST_UI") + "/../helpers/micro-pandora.png"
        service.applyStatus({ connected: true, artUrl: coverUrl,
          title: "Kush (Main) (feat. Snoop Dogg & Akon) — "
            + "Live from the studio with the original collaborators — ".repeat(8) })
        panel.chooseTab("nowplaying")
        coverCheck.start()
        return
      } catch (error) {
        console.error("MICRO_PANDORA_RUNTIME_FAILURE " + error)
      }
      Qt.quit()
    }
  }

  Timer {
    id: coverCheck
    interval: 30
    repeat: true
    property int attempts: 0
    onTriggered: {
      try {
        if (!root.testedBackdrop.silhouetteReady && ++attempts < 100) return
        root.check(root.testedBackdrop.silhouetteReady,
                   "the original cover becomes a silhouette")
        var stage = root.findVisualChild(root.testedBackdrop.parent, "stageAtmosphere")
        root.check(stage && stage.artworkVisible && stage.lighting === 0,
                   "the stage does not paint a color wash over the loaded album silhouette")
        var art = root.findVisualChild(root.testedBackdrop, "fullWindowCoverArt")
        root.check(art && art.fillMode === Image.PreserveAspectCrop
                   && art.clip && art.width === root.testedBackdrop.width
                   && art.height === root.testedBackdrop.height,
                   "the album silhouette fills the full player without a visible image edge")
        root.check(art.holdUntilReplaced && art.blend === 1
                   && art.requestedSource === root.testedService.artUrl,
                   "the fallback keeps the original image visible with no fade")
        var title = root.findVisualChild(root.testedBackdrop.parent, "nowPlayingTitle")
        root.check(title && title.text === root.testedService.title
                   && title.lineCount > 2 && !title.truncated,
                   "the full player wraps long song titles without truncating them")
        root.testedPanel.toggleSidebar()
        for (var mode of [0, 1, 2, 3]) {
          root.testedPanel.selectVisualizer(mode)
          root.check(root.testedBackdrop.silhouetteReady, "sidebar and mode changes preserve the backdrop")
        }
        var lyrics = root.findVisualChild(stage.parent, "playerLyrics")
        var visualizer = root.findVisualChild(stage.parent, "playerVisualizer")
        root.testedService.lyricLines = [{ time: 0, text: "First second third" }]
        root.testedService.lyricState = "ready"
        root.check(root.testedPanel.lyricsOn && root.testedService.lyricsKey !== "",
                   "the open full player requests lyrics and shows them by default")
        for (var lyricMode of [0, 1, 2, 3]) {
          root.testedPanel.selectVisualizer(lyricMode)
          root.check(lyrics.visible && visualizer.lyricsBelow && visualizer.clip
                     && Math.abs(lyrics.y - visualizer.y - visualizer.height
                                 - visualizer.anchors.bottomMargin) < 1
                     && lyrics.y + lyrics.height < stage.height,
                     "the lyric row fits directly below the visualizer in every mode")
        }
        var firstWord = root.findVisualChild(lyrics, "lyricWord")
        var lyricRow = firstWord.parent
        lyricRow.forceLayout()
        var secondWord = lyricRow.children.find(child => child.objectName === "lyricWord" && child.index === 1)
        var wordY = firstWord.y
        lyrics.smooth = lyrics.words[1].time
        root.check(!firstWord.singing && secondWord.singing && secondWord.y === wordY
                   && secondWord.y >= 0 && secondWord.y + secondWord.height <= lyrics.height,
                   "the active highlight moves between words on the same visible line")
        root.testedService.lyricsOn = false
        root.check(!visualizer.lyricsBelow && !visualizer.clip, "hiding lyrics restores the visualizer")
        root.testedService.applyStatus({ connected: true, artUrl: "" })
        root.check(root.testedBackdrop.silhouetteReady && art.blend === 1,
                   "missing metadata between tracks leaves the backdrop visible")
        root.testedPanel.close()
        root.check(!root.testedBackdrop.silhouetteReady, "closing releases the backdrop")
        root.testedPanel.destroy()
        root.testedService.destroy()
        console.log("MICRO_PANDORA_RUNTIME_OK")
      } catch (error) {
        console.error("MICRO_PANDORA_RUNTIME_FAILURE " + error)
      }
      stop()
      Qt.quit()
    }
  }
}
