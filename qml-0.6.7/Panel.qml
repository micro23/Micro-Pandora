import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Api.js" as Api

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var service: null
  property bool opened: false
  property bool closingFromHost: false
  property string currentTab: "nowplaying"
  property string stationFilter: ""
  property real volumeBeforeMute: 0.5
  property int stationCursor: 0
  property int pinCursor: -1
  property string browseTarget: "nowplaying"
  property bool shortcutHelpOpen: false
  property bool lyricsOn: false
  property bool localSidebarCollapsed: false
  readonly property bool sidebarCollapsed: service && service.stationSidebarCollapsed !== undefined
    ? service.stationSidebarCollapsed : localSidebarCollapsed
  // True while the window is being moved to another monitor. Quickshell
  // hides and re-shows the window for that; the hide is not a close.
  property bool movingScreen: false

  readonly property string pluginId: manifest && manifest.id
    ? String(manifest.id) : "io.github.micro23.micro-pandora"
  readonly property var artPalette: (service && service.artPalette) || ({})
  readonly property bool lightTheme: Commons.Color.background.hslLightness > 0.55
  property color foreground: artPalette.foreground
    || (lightTheme ? "#f4f4f6" : Commons.Color.foreground)
  property color background: artPalette.background
    || (lightTheme ? Qt.tint("#15171d", Util.alpha(Commons.Color.background, 0.08)) : Commons.Color.background)
  property color alternateSurface: artPalette.backgroundAlt || background
  property color accent: artPalette.accent
    || (lightTheme ? Qt.tint(Commons.Color.accent, Qt.rgba(1, 1, 1, 0.55)) : Commons.Color.accent)
  property color accentAlt: artPalette.accentAlt || Qt.tint(accent, Util.alpha(foreground, 0.36))
  property color volumeAccent: artPalette.volumeAccent || accentAlt
  property color artAccent: artPalette.artAccent || accentAlt
  property color detailAccent: artPalette.detailAccent || accent
  property color muted: artPalette.muted
    || (lightTheme ? "#b1b5c2" : Qt.tint(foreground, Util.alpha(background, 0.30)))
  WindowLook { id: windowLook }
  readonly property color surface: Qt.tint(
    Util.alpha(background, windowLook.opaque ? 1 : 0.8),
    Qt.rgba(0, 0, 0, 0.35)
  )

  Behavior on foreground { ColorAnimation { duration: Style.duration(240); easing.type: Easing.OutCubic } }
  Behavior on background { ColorAnimation { duration: Style.duration(240); easing.type: Easing.OutCubic } }
  Behavior on accent { ColorAnimation { duration: Style.duration(240); easing.type: Easing.OutCubic } }
  Behavior on alternateSurface { ColorAnimation { duration: Style.duration(240); easing.type: Easing.OutCubic } }
  Behavior on volumeAccent { ColorAnimation { duration: Style.duration(240); easing.type: Easing.OutCubic } }
  Behavior on artAccent { ColorAnimation { duration: Style.duration(240); easing.type: Easing.OutCubic } }
  Behavior on detailAccent { ColorAnimation { duration: Style.duration(240); easing.type: Easing.OutCubic } }
  Behavior on accentAlt { ColorAnimation { duration: Style.duration(240); easing.type: Easing.OutCubic } }
  Behavior on muted { ColorAnimation { duration: Style.duration(240); easing.type: Easing.OutCubic } }
  readonly property string fontFamily: Style.font.family
  readonly property string displayFamily: "Adwaita Sans"
  readonly property bool connected: service && service.connected
  readonly property var account: service && service.account ? service.account : null
  readonly property var updater: service ? service.updater : null
  readonly property string playbackError: service ? service.commandError || service.statusError : ""
  readonly property var filteredStations: {
    var all = service && service.stations instanceof Array ? service.stations : []
    var needle = String(stationFilter || "").trim().toLowerCase()
    if (!needle) return all
    var out = []
    for (var i = 0; i < all.length; i++) {
      var name = String(all[i].name || "").toLowerCase()
      if (name.indexOf(needle) !== -1) out.push(all[i])
    }
    return out
  }
  readonly property var pinnedStations: copyStations(service ? service.pinnedStations : null)
  readonly property var unpinnedStations: copyStations(service ? service.unpinnedStations : null)
  readonly property var keyboardStations: currentTab === "stations" ? filteredStations : unpinnedStations

  function applyPreferredScreen() {
    if (!service || typeof service.screenByName !== "function") return
    var name = service.preferredScreenName || service.focusedScreenName()
    var scr = service.screenByName(name)
    if (!scr || (window.screen && window.screen.name === scr.name)) return
    movingScreen = true
    window.screen = scr
    screenMoveSettle.restart()
  }

  function open(payloadJson) {
    closingFromHost = false
    applyPreferredScreen()
    var options = Api.parseStatus(payloadJson)
    opened = true
    browseTarget = sidebarCollapsed ? "player" : "nowplaying"
    if (service && service.visualizerMode !== undefined) visualizer.selectMode(service.visualizerMode)
    currentTab = options && options.page === "setup" ? "setup" : "nowplaying"
    maybeOpenSetup()
    pinCursor = pinnedStations.length ? 0 : -1
    var list = keyboardStations
    var playingAt = service ? stationIndex(list, service.stationPath) : -1
    stationCursor = playingAt >= 0 ? playingAt : 0
    Qt.callLater(function() {
      root.applyPreferredScreen()
      if (root.service && typeof root.service.pinWindowToPreferredScreen === "function")
        root.service.pinWindowToPreferredScreen()
      keyRoot.forceActiveFocus()
    })
  }

  function close() {
    closingFromHost = true
    opened = false
    closingFromHost = false
  }

  function requestClose() {
    if (shell && typeof shell.hide === "function")
      shell.hide(pluginId)
    else close()
  }

  function stopAndClose() {
    if (service) service.stopAndQuit()
    requestClose()
  }

  function pageTitle() {
    if (currentTab === "stations") return "Stations"
    if (currentTab === "setup") return "Settings"
    return "Now playing"
  }

  function chooseTab(id) { currentTab = id }

  function toggleSidebar() {
    var next = !sidebarCollapsed
    if (service && service.stationSidebarCollapsed !== undefined)
      service.stationSidebarCollapsed = next
    else localSidebarCollapsed = next
    if (next && currentTab !== "stations") browseTarget = "player"
    if (!next && currentTab === "nowplaying") browseTarget = "nowplaying"
  }

  function selectVisualizer(index) {
    visualizer.selectMode(index)
    if (service && service.visualizerMode !== undefined)
      service.visualizerMode = visualizer.modeIndex
  }

  function nextVisualizer() {
    selectVisualizer((visualizer.modeIndex + 1) % visualizer.modeNames.length)
  }

  function maybeOpenSetup() {
    if (!opened || connected || currentTab !== "nowplaying" || !account || !account.checked) return
    if (account.missing.length || (account.ready && !account.email)) currentTab = "setup"
  }

  function updateAccountPage() {
    if (account) account.settingsOpen = opened && currentTab === "setup"
  }

  function copyStations(src) {
    var out = []
    if (!src) return out
    for (var i = 0; i < src.length; i++) out.push(src[i])
    return out
  }

  function stationIndex(list, path) {
    var key = String(path || "")
    for (var i = 0; i < list.length; i++)
      if (String(list[i].path) === key) return i
    return -1
  }

  function cursorPath() {
    var list = keyboardStations
    if (!list.length) return ""
    var index = Math.max(0, Math.min(stationCursor, list.length - 1))
    return String(list[index].path || "")
  }

  function isCursor(path) {
    return browseTarget === "stations"
      && String(path || "") !== "" && String(path) === cursorPath()
  }

  function isPinnedCursor(index) {
    return browseTarget === "nowplaying" && Number(pinCursor) === Number(index)
  }

  function pinnedList() {
    var src = service && service.pinnedStations
    var out = []
    if (!src) return out
    for (var i = 0; i < src.length; i++) out.push(src[i])
    return out
  }

  function wrapIndex(index, length, delta) {
    if (length <= 0) return 0
    var pos = Math.round(Number(index) || 0) + delta
    while (pos < 0) pos += length
    while (pos >= length) pos -= length
    return pos
  }

  function moveStation(delta) {
    if (browseTarget === "player") {
      setVolumeValue((service ? service.volume : 0) + (delta > 0 ? -0.05 : 0.05))
      return
    }
    if (browseTarget === "nowplaying") {
      var pins = pinnedList()
      if (!pins.length) return
      pinCursor = wrapIndex(pinCursor, pins.length, delta)
      scrollTileIntoView(pinnedFlick, pinnedRepeater.itemAt(pinCursor))
      Qt.callLater(function() { keyRoot.forceActiveFocus() })
      return
    }
    var list = keyboardStations
    if (!list.length) return
    stationCursor = wrapIndex(stationCursor, list.length, delta)
    if (currentTab === "stations")
      Qt.callLater(function() { searchFlick.positionViewAtIndex(stationCursor, ListView.Contain) })
    else Qt.callLater(scrollSidebarToCursor)
  }

  function scrollSidebarToCursor() {
    if (stationFlick.count) stationFlick.positionViewAtIndex(stationCursor, ListView.Contain)
  }

  function scrollTileIntoView(flick, item) {
    if (!item) return
    var maxY = Math.max(0, flick.contentHeight - flick.height)
    var y = item.y - Math.max(0, (flick.height - item.height) / 2)
    flick.contentY = Math.max(0, Math.min(maxY, y))
  }

  function activateCursorStation() {
    if (!service) return
    if (browseTarget === "player") {
      service.togglePlayback()
      return
    }
    if (browseTarget === "nowplaying") {
      var pins = pinnedList()
      if (pinCursor >= 0 && pinCursor < pins.length)
        service.activateStation(pins[pinCursor].path)
      return
    }
    var list = keyboardStations
    if (!list.length) return
    var index = Math.max(0, Math.min(stationCursor, list.length - 1))
    playStation(list[index].path)
  }

  function playStation(path) {
    if (!service || !path) return
    if (currentTab === "stations") closeSearch()
    service.activateStation(path)
  }

  function focusSearch() {
    browseTarget = "stations"
    currentTab = "stations"
    stationCursor = 0
    Qt.callLater(function() {
      stationSearch.forceActiveFocus()
      stationSearch.selectAll()
    })
  }

  function closeSearch() {
    currentTab = "nowplaying"
    if (sidebarCollapsed) browseTarget = "player"
    stationSearch.focus = false
    Qt.callLater(function() { keyRoot.forceActiveFocus() })
  }

  function cycleRegion() {
    if (sidebarCollapsed) {
      if (currentTab === "stations") closeSearch()
      else if (currentTab === "setup") chooseTab("nowplaying")
      browseTarget = "player"
      keyRoot.forceActiveFocus()
      return
    }
    var order = ["nowplaying", "stations", "player"]
    var at = order.indexOf(browseTarget)
    if (at < 0) at = 0
    browseTarget = order[(at + 1) % order.length]
    if (browseTarget === "nowplaying")
      pinCursor = pinnedStations.length ? 0 : -1
    if (currentTab === "stations" || currentTab === "setup")
      currentTab = "nowplaying"
    Qt.callLater(function() {
      keyRoot.forceActiveFocus()
      if (root.browseTarget === "stations") root.scrollSidebarToCursor()
    })
  }

  function toggleMute() {
    if (!service) return
    if (service.volume > 0.001) {
      volumeBeforeMute = service.volume
      service.setVolume(0)
    } else service.setVolume(volumeBeforeMute || 0.5)
  }

  function pinCursorStation() {
    if (!service) return
    if (browseTarget === "nowplaying" && pinCursor >= 0
        && pinCursor < pinnedStations.length) {
      service.togglePin(pinnedStations[pinCursor])
      pinCursor = Math.min(pinCursor, Math.max(-1, pinnedStations.length - 2))
      return
    }
    if (browseTarget === "stations") {
      var list = keyboardStations
      if (list.length) {
        var index = Math.max(0, Math.min(stationCursor, list.length - 1))
        service.togglePin(list[index])
        return
      }
    }
    if (service.stationPath)
      service.togglePin({ path: service.stationPath, name: service.stationName })
  }

  function setVolumeValue(value) {
    if (!service) return
    if (value > 0.001) volumeBeforeMute = value
    service.setVolume(value)
  }

  onOpenedChanged: {
    if (service) service.setUiVisible(root, opened)
    updateAccountPage()
  }
  onCurrentTabChanged: updateAccountPage()
  Component.onDestruction: {
    if (account) account.settingsOpen = false
    if (service) service.setUiVisible(root, false)
  }
  Connections {
    target: root.account
    function onCheckedChanged() { root.maybeOpenSetup() }
    function onLoadedChanged() { root.maybeOpenSetup() }
  }
  onKeyboardStationsChanged: {
    if (stationCursor >= keyboardStations.length)
      stationCursor = Math.max(0, keyboardStations.length - 1)
  }
  onStationFilterChanged: if (currentTab === "stations") {
    stationCursor = 0
    if (searchFlick) searchFlick.positionViewAtBeginning()
  }

  Timer {
    id: screenMoveSettle
    interval: 400
    onTriggered: {
      root.movingScreen = false
      if (root.opened && !window.visible) window.visible = true
    }
  }

  FloatingWindow {
    id: window
    visible: root.opened
    title: "Micro-Pandora"
    color: root.surface
    implicitWidth: 1440
    implicitHeight: 900
    minimumSize: Qt.size(850, 600)

    onVisibleChanged: {
      if (!visible && root.opened && !root.closingFromHost && !root.movingScreen)
        root.requestClose()
    }

    FocusScope {
      id: keyRoot
      anchors.fill: parent
      focus: true
      LayoutMirroring.enabled: Commons.I18n.rightToLeft
      LayoutMirroring.childrenInherit: true

      AlbumBackdrop {
        id: windowBackdrop
        objectName: "windowAlbumBackdrop"
        anchors.fill: parent
        visible: root.opened
        fullWindow: true
        baseColor: root.surface
        secondaryColor: Qt.tint(root.surface, Util.alpha(root.alternateSurface, 0.52))
        artSource: root.opened && root.service ? String(root.service.artUrl || "") : ""
        // The running shell can retain an older keepLoaded Service after an
        // upgrade. Its status already carries the new helper's backdrop URL.
        backdropSource: root.opened && root.service
          ? String(root.service.backdropUrl || (root.service.status && root.service.status.backdropUrl) || "")
          : ""
      }

      Shortcut {
        sequence: "V"
        context: Qt.WindowShortcut
        autoRepeat: false
        enabled: root.opened && !root.shortcutHelpOpen
          && root.currentTab !== "setup"
          && !(stationSearch.visible && stationSearch.activeFocus)
        onActivated: {
          root.chooseTab("nowplaying")
          root.nextVisualizer()
        }
      }

      Shortcut {
        sequence: "L"
        context: Qt.WindowShortcut
        autoRepeat: false
        enabled: root.opened && !root.shortcutHelpOpen
          && root.currentTab !== "setup"
          && !(stationSearch.visible && stationSearch.activeFocus)
        onActivated: root.lyricsOn = !root.lyricsOn
      }

      Shortcut {
        sequence: "Ctrl+B"
        context: Qt.WindowShortcut
        autoRepeat: false
        enabled: root.opened && !root.shortcutHelpOpen
        onActivated: root.toggleSidebar()
      }

      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        var ctrl = !!(event.modifiers & Qt.ControlModifier)
        var typing = stationSearch.activeFocus

        if (root.shortcutHelpOpen) {
          if (event.key === Qt.Key_Escape || (ctrl && event.key === Qt.Key_Slash)) {
            root.shortcutHelpOpen = false
            event.accepted = true
          }
          return
        }

        if (root.currentTab === "setup") {
          if (event.key === Qt.Key_Escape) {
            root.chooseTab("nowplaying")
            keyRoot.forceActiveFocus()
            event.accepted = true
          }
          return
        }

        if (ctrl && event.key === Qt.Key_Slash) {
          root.shortcutHelpOpen = true
          event.accepted = true
        } else if (ctrl && event.key === Qt.Key_F) {
          root.focusSearch()
          event.accepted = true
        } else if (!typing && event.key === Qt.Key_Slash) {
          root.focusSearch()
          event.accepted = true
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_F6) {
          root.cycleRegion()
          event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
          if (root.currentTab === "stations") root.closeSearch()
          else root.requestClose()
          event.accepted = true
        } else if (!typing && ctrl && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
          if (root.service) root.service.adjustVolume(event.key === Qt.Key_Up ? 0.05 : -0.05)
          event.accepted = true
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
          root.moveStation(event.key === Qt.Key_Down ? 1 : -1)
          event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.activateCursorStation()
          event.accepted = true
        } else if (typing) {
          return
        } else if (event.key === Qt.Key_Space) {
          if (root.service) root.service.togglePlayback()
          event.accepted = true
        } else if (ctrl && event.key === Qt.Key_Right) {
          if (root.service) root.service.next()
          event.accepted = true
        } else if (event.key === Qt.Key_M) {
          root.toggleMute()
          event.accepted = true
        } else if (!ctrl && event.key === Qt.Key_C) {
          root.pinCursorStation()
          event.accepted = true
        }
      }

      Item {
        anchors.fill: parent
        anchors.margins: Style.space(14)

        Row {
          id: workspace
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.bottom: playerFooter.top
          anchors.bottomMargin: Style.space(12)
          readonly property real sidebarWidth: Math.min(Style.space(250),
            Math.max(Style.space(194), width * 0.205))

          Item {
            id: sidebarSlot
            objectName: "stationSidebar"
            width: root.sidebarCollapsed ? 0 : workspace.sidebarWidth + Style.space(12)
            height: parent.height
            clip: true
            Behavior on width {
              NumberAnimation { duration: Style.duration(220); easing.type: Easing.OutCubic }
            }

            DeckSurface {
              id: sidebar
              width: workspace.sidebarWidth
              height: parent.height
              visible: sidebarSlot.width > 0
              enabled: !root.sidebarCollapsed
              baseColor: Qt.tint(root.surface, Util.alpha(root.alternateSurface, 0.52))
              accent: root.accentAlt
              secondaryAccent: root.detailAccent
              themed: true
              litEdge: true
              radius: Style.space(16)

              ColumnLayout {
                anchors.fill: parent
                anchors.margins: Style.space(12)
                spacing: Style.space(10)

                RowLayout {
                  Layout.fillWidth: true
                  Layout.preferredHeight: Style.space(41)
                  spacing: Style.space(9)

                  Rectangle {
                    Layout.preferredWidth: Style.space(33)
                    Layout.preferredHeight: Style.space(33)
                    radius: Style.space(9)
                    color: Util.alpha(root.accentAlt, 0.15)
                    border.color: Util.alpha(root.accentAlt, 0.34)
                    border.width: 1

                    OpticalGlyph {
                      anchors.centerIn: parent
                      width: Style.space(18)
                      height: width
                      text: "󰝚"
                      color: root.accentAlt
                      fontFamily: root.fontFamily
                      fontSize: Style.font.iconLarge
                    }
                  }

                  Text {
                    Layout.fillWidth: true
                    textFormat: Text.PlainText
                    text: "Micro-Pandora"
                    color: root.foreground
                    font.family: root.displayFamily
                    font.pixelSize: Style.font.title * 1.19
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                  }
                }

                StationTile {
                  Layout.fillWidth: true
                  Layout.preferredHeight: Style.space(37)
                  text: "Search stations"
                  iconText: "󰍉"
                  foreground: root.muted
                  accent: root.accentAlt
                  active: root.currentTab === "stations"
                  bordered: true
                  onClicked: root.focusSearch()
                }

                DeckSurface {
                  Layout.fillWidth: true
                  Layout.preferredHeight: Style.space(37)
                    + Math.min(pinnedContents.implicitHeight, Math.max(Style.space(32), sidebar.height * 0.22))
                  baseColor: Qt.tint(root.surface, Util.alpha(root.accentAlt, 0.04))
                  accent: root.accentAlt
                  themed: false
                  emphasized: root.browseTarget === "nowplaying" && root.pinCursor >= 0

                  ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Style.space(7)
                    spacing: Style.space(6)

                    Text {
                      textFormat: Text.PlainText
                      text: "My list"
                      color: root.accentAlt
                      leftPadding: Style.space(5)
                      font.family: root.displayFamily
                      font.pixelSize: Style.font.subtitle
                      font.weight: Font.DemiBold
                    }

                    Flickable {
                      id: pinnedFlick
                      Layout.fillWidth: true
                      Layout.fillHeight: true
                      contentWidth: width
                      contentHeight: pinnedContents.implicitHeight
                      clip: true
                      boundsBehavior: Flickable.StopAtBounds
                      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                      Column {
                        id: pinnedContents
                        width: pinnedFlick.width - Style.space(6)
                        spacing: Style.space(2)

                        Text {
                          textFormat: Text.PlainText
                          width: parent.width
                          leftPadding: Style.space(5)
                          readonly property string pinsError: root.service ? root.service.pinsError : ""
                          visible: root.pinnedStations.length === 0 || pinsError !== ""
                          text: pinsError !== "" ? pinsError : "Pin a station with C"
                          color: pinsError !== "" ? Commons.Color.urgent : root.muted
                          font.family: root.displayFamily
                          font.pixelSize: Style.font.body
                          wrapMode: Text.WordWrap
                        }

                        Repeater {
                          id: pinnedRepeater
                          model: root.pinnedStations.length

                          StationTile {
                            required property int index
                            readonly property var pin: root.pinnedStations[index]
                            width: pinnedContents.width
                            text: pin && pin.name ? pin.name : "Station"
                            iconText: "󰐃"
                            playingStation: currentStation && root.service.playing
                            foreground: currentStation ? root.accentAlt : root.foreground
                            accent: root.accentAlt
                            active: root.isPinnedCursor(index)
                            currentStation: !!(pin && root.service && pin.path === root.service.stationPath)
                            onClicked: {
                              root.browseTarget = "nowplaying"
                              root.pinCursor = index
                              root.chooseTab("nowplaying")
                              if (root.service && pin) root.service.activateStation(pin.path)
                            }
                          }
                        }
                      }
                    }
                  }
                }

                DeckSurface {
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  Layout.minimumHeight: Style.space(94)
                  baseColor: Qt.tint(root.surface, Util.alpha(root.foreground, 0.025))
                  accent: root.accent
                  themed: false
                  emphasized: root.browseTarget === "stations"

                  ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Style.space(7)
                    spacing: Style.space(5)

                    Text {
                      textFormat: Text.PlainText
                      text: "Your stations"
                      color: root.accent
                      leftPadding: Style.space(5)
                      font.family: root.displayFamily
                      font.pixelSize: Style.font.subtitle
                      font.weight: Font.DemiBold
                    }

                    ListView {
                      id: stationFlick
                      Layout.fillWidth: true
                      Layout.fillHeight: true
                      clip: true
                      visible: root.connected
                      boundsBehavior: Flickable.StopAtBounds
                      focus: false
                      Keys.enabled: false
                      spacing: Style.space(2)
                      reuseItems: true
                      model: root.unpinnedStations
                      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                      delegate: StationTile {
                        required property int index
                        required property var modelData
                        width: stationFlick.width - Style.space(6)
                        text: modelData.name || "Station"
                        iconText: "󰐹"
                        playingStation: currentStation && root.service.playing
                        foreground: currentStation ? root.accent : root.foreground
                        accent: root.accent
                        active: root.isCursor(modelData.path)
                        currentStation: !!(root.service && modelData.path === root.service.stationPath)
                        onClicked: {
                          root.chooseTab("nowplaying")
                          root.stationCursor = index
                          root.browseTarget = "stations"
                          root.playStation(modelData.path)
                        }
                      }
                    }
                  }
                }

                StationTile {
                  Layout.fillWidth: true
                  Layout.preferredHeight: Style.space(32)
                  text: root.updater && root.updater.updateAvailable ? "Settings · Update available" : "Settings"
                  iconText: root.updater && root.updater.updateAvailable ? "󰚰" : "󰒓"
                  foreground: root.accentAlt
                  accent: root.accentAlt
                  active: root.currentTab === "setup"
                  onClicked: root.chooseTab("setup")
                }
              }
            }
          }

          Item {
            width: parent.width - sidebarSlot.width
            height: parent.height

            RowLayout {
              id: pageHeader
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              height: Style.space(44)
              spacing: Style.space(8)

              TransportButton {
                id: sidebarToggle
                objectName: "stationSidebarToggle"
                Layout.preferredWidth: stationToggleContent.implicitWidth + Style.space(23)
                controlSize: Style.space(36)
                radius: Style.space(9)
                foreground: root.accentAlt
                accent: root.accentAlt
                bordered: true
                tooltipText: root.sidebarCollapsed ? "Show stations · Ctrl+B" : "Hide stations · Ctrl+B"
                Accessible.checkable: true
                Accessible.checked: !root.sidebarCollapsed
                onClicked: root.toggleSidebar()

                Row {
                  id: stationToggleContent
                  anchors.centerIn: parent
                  spacing: Style.space(6)

                  Rectangle {
                    width: Style.space(16)
                    height: Style.space(13)
                    anchors.verticalCenter: parent.verticalCenter
                    color: "transparent"
                    radius: Style.space(2)
                    border.width: 1
                    border.color: root.accentAlt

                    Rectangle {
                      width: Style.space(5)
                      anchors.left: parent.left
                      anchors.top: parent.top
                      anchors.bottom: parent.bottom
                      anchors.margins: 1
                      color: Util.alpha(root.accentAlt, root.sidebarCollapsed ? 0.14 : 0.59)
                      Behavior on color { ColorAnimation { duration: Style.duration(150) } }
                    }
                  }

                  Text {
                    textFormat: Text.PlainText
                    text: "Stations"
                    color: root.foreground
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: root.displayFamily
                    font.pixelSize: Style.font.bodySmall
                    font.weight: Font.DemiBold
                  }
                }
              }

              Text {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                text: root.pageTitle()
                color: root.foreground
                font.family: root.displayFamily
                font.pixelSize: Style.font.title * 1.18
                font.weight: Font.DemiBold
                leftPadding: Style.space(4)
                elide: Text.ElideRight
              }

              ModePicker {
                visible: root.currentTab === "nowplaying"
                modes: visualizer.modeNames
                current: visualizer.modeIndex
                slotWidth: Style.space(pageHeader.width < Style.space(660) ? 57 : 74)
                foreground: root.foreground
                muted: root.muted
                accent: root.accent
                onChosen: function(mode) { root.selectVisualizer(mode) }
              }

              // Lyrics toggle pill
              Rectangle {
                visible: root.currentTab === "nowplaying"
                Layout.alignment: Qt.AlignVCenter
                width: lyricsLabel.implicitWidth + Style.space(22)
                height: Style.space(26)
                radius: height / 2
                color: root.lyricsOn && (root.service && root.service.lyricState === "ready")
                  ? Util.alpha(root.accent, 0.28)
                  : Util.alpha(root.foreground, 0.09)
                opacity: root.service && root.service.lyricState === "none" && !root.lyricsOn ? 0.4 : 1.0
                Behavior on color { ColorAnimation { duration: 180 } }
                Behavior on opacity { NumberAnimation { duration: 180 } }

                Text {
                  id: lyricsLabel
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: root.service && root.service.lyricState === "loading" ? "♪ …" : "♪ Lyrics"
                  color: root.lyricsOn && (root.service && root.service.lyricState === "ready")
                    ? root.accent : root.foreground
                  font.family: root.displayFamily
                  font.pixelSize: Style.font.caption
                  Behavior on color { ColorAnimation { duration: 180 } }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.lyricsOn = !root.lyricsOn
                }

                PanelToolTip {
                  visible: lyricsPillHover.hovered
                  text: (root.lyricsOn ? "Hide lyrics" : "Show lyrics") + " · L"
                  fontFamily: root.fontFamily
                }
                HoverHandler { id: lyricsPillHover }
              }

              TransportButton {
                glyphText: "󰍉"
                visible: root.sidebarCollapsed
                foreground: root.muted
                accent: root.accentAlt
                tooltipText: "Search stations · Ctrl+F"
                onClicked: root.focusSearch()
              }

              TransportButton {
                glyphText: root.updater && root.updater.updateAvailable ? "󰚰" : "󰒓"
                visible: root.sidebarCollapsed
                foreground: root.muted
                accent: root.accentAlt
                tooltipText: root.updater && root.updater.updateAvailable ? "Settings · Update available" : "Pandora settings"
                onClicked: root.chooseTab(root.currentTab === "setup" ? "nowplaying" : "setup")
              }

              TransportButton {
                glyphText: "󰖲"
                foreground: root.muted
                accent: root.accentAlt
                tooltipText: "Show mini player"
                onClicked: if (root.service) root.service.enterMini(root.service.preferredScreenName)
              }

              TransportButton {
                readonly property bool tiled: !!(root.service && root.service.windowTiled)
                glyphText: tiled ? "󰕴" : "󰕰"
                foreground: root.muted
                accent: root.accentAlt
                tooltipText: tiled ? "Float in the middle" : "Tile with your windows"
                onClicked: if (root.service) root.service.setWindowTiled(!tiled)
              }

              TransportButton {
                glyphText: "󰋗"
                foreground: root.muted
                accent: root.accentAlt
                tooltipText: "Keyboard shortcuts · Ctrl+/"
                onClicked: root.shortcutHelpOpen = !root.shortcutHelpOpen
              }

              TransportButton {
                glyphText: "󰑐"
                foreground: root.muted
                accent: root.accentAlt
                tooltipText: "Refresh"
                onClicked: if (root.service) root.service.refresh()
              }

              TransportButton {
                glyphText: "󰅖"
                foreground: root.foreground
                accent: root.accentAlt
                tooltipText: "Close Micro-Pandora"
                onClicked: root.stopAndClose()
              }
            }

            TextField {
              id: stationSearch
              visible: root.currentTab === "stations"
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: pageHeader.bottom
              anchors.topMargin: visible ? Style.space(8) : 0
              height: visible ? Style.space(44) : 0
              foreground: root.foreground
              accent: root.accentAlt
              font.family: root.displayFamily
              font.pixelSize: Style.font.subtitle
              placeholderText: "Search stations"
              Accessible.name: "Search stations"
              background: BorderSurface {
                radius: Style.space(10)
                color: Qt.tint(root.surface, Util.alpha(root.accentAlt, 0.065))
                borderSpec: Border.flat(Util.alpha(root.accentAlt, stationSearch.activeFocus ? 0.52 : 0.22), 1)
              }
              text: root.stationFilter
              onTextEdited: root.stationFilter = text
            }

            Item {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: stationSearch.visible ? stationSearch.bottom : pageHeader.bottom
              anchors.topMargin: Style.space(10)
              anchors.bottom: parent.bottom

              BorderSurface {
                id: stage
                anchors.fill: parent
                visible: root.currentTab === "nowplaying"
                color: "transparent"
                radius: Style.space(18)
                borderSpec: Border.flat(Util.alpha(root.accentAlt,
                  root.sidebarCollapsed || root.browseTarget !== "player" ? 0.21 : 0.43), 1)

                StageAtmosphere {
                  objectName: "stageAtmosphere"
                  anchors.fill: parent
                  anchors.margins: Style.space(2)
                  baseColor: root.background
                  primary: root.accent
                  secondary: root.accentAlt
                  bounceLight: root.artAccent
                  artworkVisible: windowBackdrop.silhouetteReady
                  horizon: 0.69
                  mode: visualizer.modeIndex
                  cornerRadius: Style.space(16)
                }

                Flickable {
                  id: heroStage
                  readonly property bool compact: height < Style.space(380)
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  anchors.margins: Style.space(28)
                  anchors.topMargin: Style.space(30)
                  anchors.bottomMargin: (visualizer.visualizing ? visualizer.centerHeight : 0)
                    + (lyricsStage.visible ? lyricsStage.height : 0) + Style.space(26)
                  contentWidth: width
                  contentHeight: Math.max(height, nowPlayingHero.implicitHeight)
                  flickableDirection: Flickable.VerticalFlick
                  boundsBehavior: Flickable.StopAtBounds
                  interactive: contentHeight > height
                  clip: interactive
                  z: 1

                  GridLayout {
                    id: nowPlayingHero
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.max(0, (heroStage.height - height) / 2)
                    columns: heroStage.compact ? 2 : 1
                    width: heroStage.compact
                      ? Math.min(heroStage.width, coverSize + columnSpacing
                          + Math.max(textWidth, heroTitle.implicitWidth))
                      : heroStage.width
                    rowSpacing: Style.space(23)
                    columnSpacing: Style.space(34)
                    readonly property real coverSize: heroStage.compact
                      ? Math.max(1, Math.min(Style.space(264), heroStage.height, heroStage.width * 0.36))
                      : Math.min(Style.space(495), heroStage.width * 0.66,
                          Math.max(Style.space(96), heroStage.height - metadataReserve))
                    readonly property real textWidth: Math.min(Style.space(465), heroStage.width * 0.56)
                    readonly property real metadataReserve: nowPlayingMeta.implicitHeight + rowSpacing

                    AlbumFrame {
                      Layout.preferredWidth: nowPlayingHero.coverSize
                      Layout.preferredHeight: nowPlayingHero.coverSize
                      Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                      radius: Style.space(15)
                      color: Qt.darker(root.background, 1.32)
                      foreground: root.foreground
                      accent: root.accent
                      accentAlt: root.artAccent
                      tinted: true
                      glow: heroArt.hasArtwork
                      lightLevel: visualizer.stageEnergy
                      transform: Translate {
                        y: visualizer.modeIndex === 2 ? -Style.space(12) * visualizer.stageEnergy : 0
                      }

                      CoverTransition {
                        id: heroArt
                        anchors.fill: parent
                        anchors.margins: Style.space(4)
                        requestedSource: root.opened && root.service ? root.service.artUrl : ""
                        decodeSize: 1080
                      }

                      FallbackCover {
                        anchors.fill: parent
                        anchors.margins: Style.space(4)
                        visible: !heroArt.hasArtwork
                        baseColor: root.background
                        accent: root.accent
                        accentAlt: root.accentAlt
                      }
                    }

                    Column {
                      id: nowPlayingMeta
                      Layout.preferredWidth: heroStage.compact
                        ? nowPlayingHero.width - nowPlayingHero.coverSize - nowPlayingHero.columnSpacing
                        : nowPlayingHero.width
                      Layout.alignment: heroStage.compact ? Qt.AlignLeft | Qt.AlignVCenter : Qt.AlignHCenter
                      spacing: Style.space(5)

                      TrackFade {
                        trackKey: heroTitle.text + "\n" + (root.service ? root.service.artist : "")
                        target: nowPlayingMeta
                        shown: root.opened && root.currentTab === "nowplaying"
                      }

                      Text {
                        id: heroTitle
                        objectName: "nowPlayingTitle"
                        width: parent.width
                        textFormat: Text.PlainText
                        text: root.service && root.service.title
                          ? root.service.title : "Nothing playing"
                        onTextChanged: heroStage.contentY = 0
                        color: root.foreground
                        style: windowBackdrop.silhouetteReady ? Text.Outline : Text.Normal
                        styleColor: "#cc000000"
                        font.family: root.displayFamily
                        font.pixelSize: Math.round(Math.min(Style.font.displayLarge * 2.52,
                          Math.max(Style.font.displayLarge * 1.10, heroStage.height * 0.112),
                          heroStage.compact ? nowPlayingHero.textWidth * 0.18 : heroStage.width * 0.112))
                        font.weight: Font.Bold
                        font.letterSpacing: -Style.space(1.7)
                        horizontalAlignment: heroStage.compact ? Text.AlignLeft : Text.AlignHCenter
                        wrapMode: Text.Wrap
                      }

                      Button {
                        x: heroStage.compact
                          ? (LayoutMirroring.enabled ? nowPlayingMeta.width - width : 0)
                          : (nowPlayingMeta.width - width) / 2
                        visible: !root.connected && !!root.service
                        enabled: root.service && !root.service.launching
                        text: root.service && root.service.launching ? "Connecting…" : "Pandora settings"
                        foreground: root.accent
                        accent: root.accent
                        bordered: true
                        onClicked: root.chooseTab("setup")
                      }

                      Text {
                        width: parent.width
                        visible: root.service && root.service.artist !== ""
                        textFormat: Text.PlainText
                        text: root.service ? root.service.artist : ""
                        color: root.accent
                        style: windowBackdrop.silhouetteReady ? Text.Outline : Text.Normal
                        styleColor: "#cc000000"
                        font.family: root.displayFamily
                        font.pixelSize: Math.round(Style.font.title * 1.88)
                        font.weight: Font.Bold
                        font.letterSpacing: Style.space(0.6)
                        horizontalAlignment: heroStage.compact ? Text.AlignLeft : Text.AlignHCenter
                        elide: Text.ElideRight
                      }

                      Text {
                        width: parent.width
                        visible: root.service && root.service.album !== ""
                        textFormat: Text.PlainText
                        text: root.service ? root.service.album : ""
                        color: root.accentAlt
                        style: windowBackdrop.silhouetteReady ? Text.Outline : Text.Normal
                        styleColor: "#cc000000"
                        font.family: root.displayFamily
                        font.pixelSize: Math.round(Style.font.title * 1.32)
                        font.italic: true
                        font.weight: Font.Medium
                        font.letterSpacing: Style.space(0.3)
                        horizontalAlignment: heroStage.compact ? Text.AlignLeft : Text.AlignHCenter
                        elide: Text.ElideRight
                      }

                      BorderSurface {
                        id: stationBadge
                        x: heroStage.compact
                          ? (LayoutMirroring.enabled ? nowPlayingMeta.width - width : 0)
                          : (nowPlayingMeta.width - width) / 2
                        width: Math.min(nowPlayingMeta.width, stationBadgeContent.implicitWidth + Style.space(17))
                        height: Style.space(30)
                        visible: root.service && root.service.stationName !== ""
                        radius: height / 2
                        color: Util.alpha(root.accentAlt, 0.10)
                        borderSpec: Border.flat(Util.alpha(root.accentAlt, 0.24), 1)

                        Row {
                          id: stationBadgeContent
                          anchors.centerIn: parent
                          spacing: Style.space(6)

                          PlaybackIndicator {
                            width: Style.space(15)
                            height: Style.space(14)
                            anchors.verticalCenter: parent.verticalCenter
                            playing: !!(root.service && root.service.playing)
                            active: root.opened && stationBadge.visible
                            tone: root.accentAlt
                          }

                          Text {
                            readonly property real availableWidth: Math.max(1, nowPlayingMeta.width
                              - pinCurrent.width - Style.space(44))
                            width: Math.min(implicitWidth, availableWidth)
                            textFormat: Text.PlainText
                            text: root.service ? root.service.stationName : ""
                            color: root.accentAlt
                            style: windowBackdrop.silhouetteReady ? Text.Outline : Text.Normal
                            styleColor: "#cc000000"
                            font.family: root.displayFamily
                            font.pixelSize: Style.font.bodySmall
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                          }

                          TransportButton {
                            id: pinCurrent
                            controlSize: Style.space(23)
                            glyphSize: Style.font.bodySmall
                            anchors.verticalCenter: parent.verticalCenter
                            glyphText: root.service && root.service.isPinned(root.service.stationPath)
                              ? "󰐃" : "󰤱"
                            foreground: root.accentAlt
                            accent: root.accentAlt
                            tooltipText: root.service && root.service.isPinned(root.service.stationPath)
                              ? "Unpin from My list" : "Pin to My list"
                            onClicked: if (root.service)
                              root.service.togglePin({
                                path: root.service.stationPath,
                                name: root.service.stationName
                              })
                          }
                        }
                      }
                    }
                  }
                }

                LyricsStage {
                  id: lyricsStage
                  objectName: "playerLyrics"
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.bottom: parent.bottom
                  anchors.leftMargin: Style.space(15)
                  anchors.rightMargin: Style.space(15)
                  anchors.bottomMargin: 0
                  height: Math.max(Style.space(38), parent.height * 0.09)
                  visible: root.lyricsOn && !!(root.service && root.service.lyricState === "ready")
                  active: root.opened && root.currentTab === "nowplaying" && visible
                  lines: root.service ? root.service.lyricLines : []
                  position: root.service ? root.service.positionSeconds : 0
                  playing: !!(root.service && root.service.playing)
                  foreground: root.foreground
                  accent: root.accent
                  accentAlt: root.accentAlt
                  fontFamily: root.displayFamily
                }

                Visualizer {
                  id: visualizer
                  objectName: "playerVisualizer"
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.bottom: lyricsStage.visible ? lyricsStage.top : parent.bottom
                  anchors.margins: Style.space(15)
                  anchors.bottomMargin: lyricsStage.visible ? 0 : Style.space(15)
                  lyricsBelow: lyricsStage.visible
                  centerHeight: Math.round(parent.height * (lyricsBelow ? 0.18 : 0.23))
                  Behavior on centerHeight { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                  protectedWidth: heroStage.compact ? nowPlayingHero.width + Style.space(28)
                    : Math.max(nowPlayingHero.coverSize + Style.space(56),
                        Math.min(nowPlayingMeta.width, heroTitle.implicitWidth + Style.space(64)))
                  playing: !!(root.service && root.service.playing)
                  active: root.opened && root.currentTab === "nowplaying"
                  barColors: [root.accentAlt, root.detailAccent, root.accent, root.artAccent, root.volumeAccent]
                  dimColor: root.muted
                }
              }

              DeckSurface {
                anchors.fill: parent
                visible: root.currentTab === "stations"
                baseColor: root.surface
                accent: root.accentAlt
                themed: true
                radius: Style.space(16)

                ColumnLayout {
                  anchors.fill: parent
                  anchors.margins: Style.space(14)
                  spacing: Style.space(8)

                  RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Style.space(7)

                    Text {
                      textFormat: Text.PlainText
                      text: root.stationFilter.trim() ? "Search results" : "All stations"
                      color: root.foreground
                      font.family: root.displayFamily
                      font.pixelSize: Style.font.subtitle
                      font.weight: Font.DemiBold
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                      visible: root.connected
                      textFormat: Text.PlainText
                      text: Commons.I18n.formatNumber(root.filteredStations.length)
                      color: root.accentAlt
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }

                  Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Util.alpha(root.foreground, 0.10)
                  }

                  Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                      id: searchFlick
                      anchors.fill: parent
                      clip: true
                      reuseItems: true
                      spacing: Style.space(4)
                      model: root.currentTab === "stations" ? root.filteredStations : []
                      boundsBehavior: Flickable.StopAtBounds
                      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                      delegate: RowLayout {
                        id: searchResult
                        required property int index
                        required property var modelData
                        width: searchFlick.width - Style.space(10)
                        spacing: Style.space(6)

                        StationTile {
                          Layout.fillWidth: true
                          Layout.preferredHeight: Style.space(41)
                          text: searchResult.modelData.name || "Station"
                          iconText: "󰐹"
                          foreground: currentStation ? root.accent : root.foreground
                          accent: root.accent
                          active: searchResult.index === root.stationCursor
                          currentStation: !!(root.service && searchResult.modelData.path === root.service.stationPath)
                          playingStation: currentStation && root.service.playing
                          onClicked: root.playStation(searchResult.modelData.path)
                        }

                        TransportButton {
                          Layout.alignment: Qt.AlignVCenter
                          glyphText: root.service && root.service.isPinned(searchResult.modelData.path)
                            ? "󰐃" : "󰤱"
                          foreground: root.accentAlt
                          accent: root.accentAlt
                          tooltipText: root.service && root.service.isPinned(searchResult.modelData.path)
                            ? "Unpin from My list" : "Pin to My list"
                          onClicked: if (root.service) root.service.togglePin(searchResult.modelData)
                        }
                      }
                    }

                    Text {
                      anchors.centerIn: parent
                      width: Math.min(parent.width - Style.space(24), Style.space(460))
                      visible: !root.filteredStations.length
                      textFormat: Text.PlainText
                      text: !root.connected ? "Sign in through Settings to load your stations."
                        : root.stationFilter.trim() ? "No stations match your search." : "No stations are available."
                      horizontalAlignment: Text.AlignHCenter
                      wrapMode: Text.WordWrap
                      color: root.muted
                      font.family: root.displayFamily
                      font.pixelSize: Style.font.subtitle
                    }
                  }
                }
              }

              Loader {
                anchors.fill: parent
                active: root.opened && root.currentTab === "setup"
                sourceComponent: PlayerSettings {
                  account: root.account
                  updater: root.updater
                  service: root.service
                  foreground: root.foreground
                  muted: root.muted
                  accent: root.accent
                  accentAlt: root.accentAlt
                  background: root.background
                }
              }
            }
          }
        }

        DeckSurface {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: playerFooter.top
          anchors.bottomMargin: Style.space(10)
          width: Math.min(parent.width - Style.space(20), Style.space(510))
          height: playbackMessage.implicitHeight + Style.space(20)
          baseColor: Qt.darker(root.background, 1.5)
          accent: Commons.Color.urgent
          emphasized: true
          visible: root.currentTab !== "setup" && root.playbackError !== ""
          z: 2

          Text {
            id: playbackMessage
            anchors.centerIn: parent
            width: parent.width - Style.space(20)
            text: root.playbackError
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            color: root.foreground
            font.family: root.displayFamily
            font.pixelSize: Style.font.body
          }
        }

        DeckSurface {
          id: playerFooter
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: Style.space(96)
          baseColor: root.surface
          accent: root.accentAlt
          secondaryAccent: root.detailAccent
          themed: true
          litEdge: true
          emphasized: root.browseTarget === "player" && !root.sidebarCollapsed
          radius: Style.space(16)

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(14)
            anchors.rightMargin: Style.space(15)
            anchors.topMargin: Style.space(9)
            anchors.bottomMargin: Style.space(9)
            spacing: Style.space(14)

            RowLayout {
              Layout.fillWidth: false
              Layout.preferredWidth: Math.max(Style.space(185), playerFooter.width * 0.28)
              Layout.minimumWidth: Style.space(170)
              Layout.fillHeight: true
              spacing: Style.space(10)

              AlbumFrame {
                Layout.preferredWidth: Style.space(53)
                Layout.preferredHeight: Style.space(53)
                radius: Style.space(8)
                color: root.surface
                foreground: root.foreground
                accent: root.accent
                accentAlt: root.accentAlt
                tinted: true

                CoverTransition {
                  id: footerArtImage
                  anchors.fill: parent
                  anchors.margins: Style.space(2)
                  requestedSource: root.opened && root.service ? root.service.artUrl : ""
                  decodeSize: 128
                }

                FallbackCover {
                  anchors.fill: parent
                  anchors.margins: Style.space(2)
                  visible: !footerArtImage.hasArtwork
                  baseColor: root.background
                  accent: root.accent
                  accentAlt: root.accentAlt
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.space(3)

                Text {
                  Layout.fillWidth: true
                  textFormat: Text.PlainText
                  text: root.service && root.service.title ? root.service.title : "Nothing playing"
                  color: root.foreground
                  font.family: root.displayFamily
                  font.pixelSize: Style.font.title * 1.06
                  font.weight: Font.DemiBold
                  elide: Text.ElideRight
                }

                Text {
                  Layout.fillWidth: true
                  textFormat: Text.PlainText
                  text: root.service && root.service.artist
                    ? root.service.artist : "Choose a station to play"
                  color: root.muted
                  font.family: root.displayFamily
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideRight
                }
              }

              TransportButton {
                glyphText: root.service && root.service.loved ? "󰋑" : "󰋕"
                foreground: root.service && root.service.loved ? Commons.Color.urgent : root.muted
                accent: Commons.Color.urgent
                enabled: root.connected && root.service && root.service.hasMedia
                tooltipText: root.service && root.service.loved ? "Loved" : "Love this song"
                onClicked: if (root.service) root.service.toggleLove()
              }
            }

            Rectangle {
              Layout.preferredWidth: 1
              Layout.preferredHeight: Style.space(42)
              color: Util.alpha(root.foreground, 0.10)
            }

            ColumnLayout {
              Layout.fillWidth: true
              Layout.minimumWidth: Style.space(200)
              spacing: Style.space(4)

              Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: Style.space(8)

                TransportButton {
                  anchors.verticalCenter: parent.verticalCenter
                  glyphText: "󰥊"
                  foreground: root.muted
                  accent: root.accentAlt
                  tooltipText: "Tired of this song"
                  enabled: root.connected && root.service && root.service.hasMedia
                  onClicked: if (root.service) root.service.tired()
                }

                TransportButton {
                  anchors.verticalCenter: parent.verticalCenter
                  glyphText: "󰒮"
                  foreground: root.muted
                  enabled: false
                  opacity: 0.35
                  tooltipText: "Previous is not available on Pandora"
                }

                TransportButton {
                  anchors.verticalCenter: parent.verticalCenter
                  glyphText: root.service && root.service.playing ? "󰏤" : "󰐊"
                  controlSize: Style.space(44)
                  glyphSize: Style.font.iconLarge * 1.18
                  foreground: root.foreground
                  accent: root.accent
                  accentAlt: root.accentAlt
                  primary: true
                  tooltipText: root.service && root.service.playing ? "Pause" : "Play"
                  onClicked: if (root.service) root.service.togglePlayback()
                }

                TransportButton {
                  anchors.verticalCenter: parent.verticalCenter
                  glyphText: "󰒭"
                  foreground: root.foreground
                  accent: root.accent
                  tooltipText: "Skip"
                  enabled: root.connected && root.service && root.service.canGoNext
                  onClicked: if (root.service) root.service.next()
                }

                TransportButton {
                  anchors.verticalCenter: parent.verticalCenter
                  glyphText: "󰅙"
                  foreground: root.muted
                  accent: root.accentAlt
                  tooltipText: "Ban this song"
                  enabled: root.connected && root.service && root.service.hasMedia
                  onClicked: if (root.service) root.service.ban()
                }
              }

              ProgressTrack {
                Layout.fillWidth: true
                visible: root.service && root.service.lengthSeconds > 0
                position: root.service ? root.service.positionSeconds : 0
                duration: root.service ? root.service.lengthSeconds : 0
                foreground: root.foreground
                muted: root.muted
                accent: root.accent
                accentAlt: root.detailAccent
              }
            }

            Rectangle {
              Layout.preferredWidth: 1
              Layout.preferredHeight: Style.space(42)
              color: Util.alpha(root.foreground, 0.10)
            }

            RowLayout {
              Layout.fillWidth: false
              Layout.preferredWidth: Math.min(Style.space(238), playerFooter.width * 0.24)
              Layout.minimumWidth: Style.space(145)
              spacing: Style.space(6)

              TransportButton {
                controlSize: Style.space(29)
                glyphText: volumeSlider.value <= 0.001 ? "󰝟" : "󰕾"
                foreground: root.volumeAccent
                accent: root.volumeAccent
                tooltipText: volumeSlider.value <= 0.001 ? "Unmute" : "Mute"
                enabled: root.connected
                onClicked: root.toggleMute()
              }

              PlaybackSlider {
                id: volumeSlider
                Layout.fillWidth: true
                Accessible.name: "Volume"
                trackHeight: Style.space(4)
                knobSize: Style.space(12)
                trackColor: Util.alpha(root.foreground, 0.16)
                fillColor: root.volumeAccent
                knobColor: fillColor
                minimum: 0
                maximum: 1
                step: 0.05
                sourceValue: root.service ? root.service.volume : 0
                liveCommit: true
                enabled: root.service && root.service.volumeSupported
                onCommitted: function(value) { root.setVolumeValue(value) }
              }

              Text {
                Layout.preferredWidth: Style.space(33)
                textFormat: Text.PlainText
                text: Math.round(Api.clampUnit(volumeSlider.value) * 100) + "%"
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignRight
              }
            }
          }
        }
      }

      Rectangle {
        anchors.fill: parent
        visible: root.shortcutHelpOpen
        color: Util.alpha(Commons.Color.background, 0.82)
        z: 20

        MouseArea {
          anchors.fill: parent
          onClicked: root.shortcutHelpOpen = false
        }

        DeckSurface {
          anchors.centerIn: parent
          width: Math.min(parent.width - Style.space(80), Style.space(560))
          height: helpColumn.implicitHeight + Style.space(36)
          baseColor: root.surface
          accent: root.accentAlt
          themed: true
          emphasized: true
          radius: Style.space(16)

          ColumnLayout {
            id: helpColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Style.space(18)
            spacing: Style.space(7)

            RowLayout {
              Layout.fillWidth: true

              Text {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                text: "Keyboard shortcuts"
                color: root.foreground
                font.family: root.displayFamily
                font.pixelSize: Style.font.display
                font.weight: Font.DemiBold
              }

              TransportButton {
                glyphText: "󰅖"
                foreground: root.muted
                accent: root.accentAlt
                tooltipText: "Close keyboard shortcuts"
                onClicked: root.shortcutHelpOpen = false
              }
            }

            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: 1
              color: Util.alpha(root.foreground, 0.11)
            }

            Repeater {
              model: [
                ["Ctrl+F or /", "Search stations"],
                ["Ctrl+B", "Hide or show the station sidebar"],
                ["Tab / F6", "Cycle through My list, stations, and the player"],
                ["↑ / ↓", "Move within the current section"],
                ["Enter", "Play the highlighted station"],
                ["C", "Pin or unpin the highlighted station"],
                ["Space", "Play or pause"],
                ["Ctrl+→", "Skip to the next song"],
                ["Ctrl+↑ / Ctrl+↓", "Adjust volume"],
                ["M", "Mute or restore volume"],
                ["V", "Cycle visualizers"],
                ["L", "Toggle lyrics on or off"],
                ["Esc", "Close the active view"]
              ]

              RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: Style.space(12)

                Rectangle {
                  Layout.preferredWidth: Style.space(147)
                  Layout.preferredHeight: Style.space(23)
                  radius: Style.space(5)
                  color: Util.alpha(root.accentAlt, 0.09)
                  border.width: 1
                  border.color: Util.alpha(root.accentAlt, 0.15)

                  Text {
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: modelData[0]
                    color: root.accentAlt
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                Text {
                  Layout.fillWidth: true
                  textFormat: Text.PlainText
                  text: modelData[1]
                  color: root.muted
                  font.family: root.displayFamily
                  font.pixelSize: Style.font.body
                  wrapMode: Text.WordWrap
                }
              }
            }
          }
        }
      }
    }
  }
}
