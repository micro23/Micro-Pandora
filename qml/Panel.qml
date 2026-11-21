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
  property string focusRegion: "nowplaying"
  property bool shortcutHelpOpen: false
  // True while the window is being moved to another monitor. Quickshell
  // hides and re-shows the window for that; the hide is not a close.
  property bool movingScreen: false

  readonly property string pluginId: manifest && manifest.id
    ? String(manifest.id) : "io.github.dankestrick.omapandora"
  readonly property var artPalette: (service && service.artPalette) || ({})
  readonly property color foreground: artPalette.foreground || Commons.Color.foreground
  readonly property color background: artPalette.background || Util.alpha(Commons.Color.background, 0.95)
  readonly property color alternateSurface: artPalette.backgroundAlt
    ? Qt.darker(artPalette.backgroundAlt, 1.30) : background
  readonly property color accent: artPalette.accent || Commons.Color.accent
  readonly property color accentAlt: artPalette.accentAlt || accent
  readonly property color muted: artPalette.muted || Commons.Color.muted
  readonly property string fontFamily: Style.font.family
  readonly property string displayFamily: "Adwaita Sans"
  readonly property bool connected: service && service.connected
  readonly property bool miniMode: !!(service && service.displayMode === "mini")
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
  readonly property var keyboardStations: unpinnedStations

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
    opened = true
    if (service) service.setUiVisible("panel", true)
    browseTarget = "nowplaying"
    focusRegion = "nowplaying"
    currentTab = currentTab === "setup" ? "nowplaying" : currentTab
    if (currentTab === "stations") currentTab = "nowplaying"
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
    if (service) service.setUiVisible("panel", false)
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
    var station = service && service.stationName ? String(service.stationName) : ""
    if (station) return "Now Playing - " + station
    return "Now Playing"
  }

  function chooseTab(id) { currentTab = id }

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
    if (currentTab === "stations") currentTab = "nowplaying"
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
    Qt.callLater(scrollSidebarToCursor)
  }

  function scrollSidebarToCursor() {
    if (!unpinnedRepeater || !stationFlick) return
    var item = unpinnedRepeater.itemAt(stationCursor)
    if (!item) {
      if (stationCursor === 0) stationFlick.contentY = 0
      return
    }
    scrollTileIntoView(stationFlick, item)
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
    service.activateStation(list[index].path)
  }

  function focusSearch() {
    browseTarget = "stations"
    focusRegion = "search"
    if (currentTab === "stations") currentTab = "nowplaying"
    Qt.callLater(function() {
      if (stationSearch) stationSearch.forceActiveFocus()
    })
  }

  function frameSpec(active) {
    return Border.controlSpec(active ? "selected" : "normal", foreground, accent)
  }

  function cycleRegion() {
    var order = ["nowplaying", "stations", "player"]
    var at = order.indexOf(browseTarget)
    if (at < 0) at = 0
    browseTarget = order[(at + 1) % order.length]
    focusRegion = browseTarget
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

  onOpenedChanged: if (service) service.setUiVisible("panel", opened)
  onKeyboardStationsChanged: {
    if (stationCursor >= keyboardStations.length)
      stationCursor = Math.max(0, keyboardStations.length - 1)
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
    color: root.background
    implicitWidth: 1440
    implicitHeight: 900
    minimumSize: Qt.size(1100, 700)

    onVisibleChanged: {
      if (!visible && root.opened && !root.closingFromHost && !root.movingScreen)
        root.requestClose()
    }

    AlbumBackdrop {
      anchors.fill: parent
      visible: !!root.artPalette.backgroundAlt
      baseColor: root.background
      secondaryColor: root.artPalette.backgroundAlt || root.background
      artSource: root.opened && root.service ? root.service.artUrl : ""
    }

    FocusScope {
      id: keyRoot
      anchors.fill: parent
      focus: true
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
          root.requestClose()
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
        } else if (ctrl && event.key === Qt.Key_Up) {
          root.setVolumeValue((root.service ? root.service.volume : 0) + 0.05)
          event.accepted = true
        } else if (ctrl && event.key === Qt.Key_Down) {
          root.setVolumeValue((root.service ? root.service.volume : 0) - 0.05)
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
          anchors.bottom: footerSeparator.top
          anchors.bottomMargin: Style.space(10)
          spacing: Style.space(10)

          DeckSurface {
            id: sidebar
            width: Math.min(Style.space(266), Math.max(Style.space(214), workspace.width * 0.23))
            height: parent.height
            baseColor: root.background
            accent: root.accentAlt
            themed: !!root.artPalette.accent

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: Style.space(10)
              spacing: Style.space(8)

              Row {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(38)
                spacing: Style.space(9)

                Rectangle {
                  width: Style.space(34)
                  height: width
                  anchors.verticalCenter: parent.verticalCenter
                  radius: Style.cornerRadius
                  color: Util.alpha(root.accentAlt, 0.17)

                  OpticalGlyph {
                    anchors.centerIn: parent
                    width: Style.space(19)
                    height: width
                    text: "󰝚"
                    color: root.accentAlt
                    fontFamily: root.fontFamily
                    fontSize: Style.font.iconLarge
                  }
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: "Micro-Pandora"
                  color: root.foreground
                  font.family: root.displayFamily
                  font.pixelSize: Style.font.title * 1.18
                  font.weight: Font.DemiBold
                }
              }

              DeckSurface {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(37)
                  + Math.min(pinnedContents.implicitHeight, Math.max(Style.space(32), sidebar.height * 0.22))
                baseColor: root.alternateSurface
                accent: root.accentAlt
                themed: sidebar.themed
                emphasized: root.browseTarget === "nowplaying"

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
                          iconText: currentStation && root.service.playing ? "󰎆" : "󰐃"
                          fontFamily: root.fontFamily
                          foreground: currentStation ? root.accentAlt : root.foreground
                          accent: root.accentAlt
                          selected: root.isPinnedCursor(index)
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
                baseColor: root.background
                accent: root.accent
                themed: sidebar.themed
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

                  Flickable {
                    id: stationFlick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: stationNav.implicitHeight
                    visible: root.connected
                    boundsBehavior: Flickable.StopAtBounds
                    focus: false
                    Keys.enabled: false
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    Column {
                      id: stationNav
                      width: stationFlick.width - Style.space(6)
                      spacing: Style.space(2)

                      Repeater {
                        id: unpinnedRepeater
                        model: root.unpinnedStations

                        StationTile {
                          required property var modelData
                          width: stationNav.width
                          text: modelData.name || "Station"
                          iconText: currentStation && root.service.playing ? "󰎆" : "󰐹"
                          foreground: currentStation ? root.accent : root.foreground
                          accent: root.accent
                          selected: root.isCursor(modelData.path)
                          currentStation: !!(root.service && modelData.path === root.service.stationPath)
                          onClicked: {
                            root.stationCursor = root.stationIndex(root.keyboardStations, modelData.path)
                            root.browseTarget = "stations"
                            root.chooseTab("nowplaying")
                            if (root.service) root.service.activateStation(modelData.path)
                          }
                        }
                      }
                    }
                  }
                }
              }

              StationTile {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(32)
                text: "Settings"
                iconText: "󰒓"
                foreground: root.accentAlt
                accent: root.accentAlt
                selected: root.currentTab === "setup"
                onClicked: root.chooseTab("setup")
              }
            }
          }

          Item {
            width: parent.width - sidebar.width - parent.spacing
            height: parent.height

            Row {
              id: pageHeader
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              height: closeButton.implicitHeight
              spacing: Style.space(5)

              Row {
                width: Math.max(80, parent.width - headerMiniSwitch.width
                  - helpButton.width - refreshButton.width - closeButton.width
                  - parent.spacing * 4)
                spacing: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter

                OpticalGlyph {
                  width: Style.space(22)
                  height: Style.space(22)
                  anchors.verticalCenter: parent.verticalCenter
                  text: "󰝚"
                  color: root.accent
                  fontFamily: root.fontFamily
                  fontSize: Style.font.title
                }

                Text {
                  textFormat: Text.PlainText
                  width: Math.max(40, parent.width - Style.space(30))
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.pageTitle()
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                  elide: Text.ElideRight
                }
              }

              ToggleSwitch {
                id: headerMiniSwitch
                checked: root.miniMode
                foreground: root.foreground
                accent: root.accent
                anchors.verticalCenter: parent.verticalCenter
                onToggled: {
                  if (!root.service) return
                  root.service.enterMini(root.service.preferredScreenName)
                }

                PanelToolTip {
                  visible: headerMiniSwitch.containsMouse
                  text: "Show mini player"
                  fontFamily: root.fontFamily
                }
              }

              Button {
                id: helpButton
                text: "?"
                foreground: root.foreground
                fontSize: Style.font.subtitle
                tooltipText: "Keyboard shortcuts · Ctrl+/"
                onClicked: root.shortcutHelpOpen = !root.shortcutHelpOpen
              }

              Button {
                id: refreshButton
                iconText: "󰑐"
                foreground: root.foreground
                tooltipText: "Refresh"
                onClicked: if (root.service) root.service.refresh()
              }

              Button {
                id: closeButton
                iconText: "󰅖"
                foreground: root.foreground
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
              height: visible ? Style.space(38) : 0
              foreground: root.foreground
              placeholderText: "Search stations"
              onTextEdited: root.stationFilter = text
            }

            Item {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: stationSearch.visible ? stationSearch.bottom : pageHeader.bottom
              anchors.topMargin: Style.space(10)
              anchors.bottom: parent.bottom

              BorderSurface {
                anchors.fill: parent
                visible: root.currentTab === "nowplaying"
                color: "transparent"
                radius: Style.cornerRadius
                borderSpec: root.frameSpec(root.browseTarget === "player")

                Item {
                  id: heroStage
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  anchors.margins: Style.space(16)
                  anchors.bottomMargin: visualizer.centerHeight + Style.space(28)
                  z: 1

                  Column {
                    id: nowPlayingHero
                    anchors.centerIn: parent
                    width: parent.width
                    spacing: Style.space(16)

                    AlbumFrame {
                      width: Math.min(Style.space(360), parent.width,
                        Math.max(1, heroStage.height - nowPlayingMeta.implicitHeight - nowPlayingHero.spacing))
                      height: width
                      anchors.horizontalCenter: parent.horizontalCenter
                      radius: Style.cornerRadius
                      color: Style.selectedFillFor(root.foreground, root.accent)
                      foreground: root.foreground
                      accent: root.accent
                      accentAlt: root.accentAlt
                      tinted: !!root.artPalette.accentAlt
                      glow: heroArt.status === Image.Ready

                      ArtImage {
                        id: heroArt
                        anchors.fill: parent
                        anchors.margins: Style.space(4)
                        requestedSource: root.opened && root.service ? root.service.artUrl : ""
                        sourceSize.width: 720
                        sourceSize.height: 720
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: true
                        visible: status === Image.Ready
                      }

                      Text {
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        visible: heroArt.status !== Image.Ready
                        text: "󰎈"
                        color: root.muted
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.displayLarge
                      }
                    }

                    Column {
                      id: nowPlayingMeta
                      width: Math.min(parent.width, Style.space(680))
                      anchors.horizontalCenter: parent.horizontalCenter
                      spacing: Style.space(4)

                      Text {
                        width: parent.width
                        textFormat: Text.PlainText
                        text: root.service && root.service.title
                          ? root.service.title : "Nothing playing"
                        color: root.foreground
                        font.family: root.displayFamily
                        font.pixelSize: Math.round(Math.min(Style.font.displayLarge * 1.87,
                          Math.max(Style.font.displayLarge * 1.23, heroStage.height * 0.109)))
                        font.weight: Font.ExtraBold
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                      }

                      Text {
                        width: parent.width
                        visible: root.service && root.service.artist !== ""
                        textFormat: Text.PlainText
                        text: root.service ? root.service.artist : ""
                        color: root.accent
                        font.family: root.displayFamily
                        font.pixelSize: Math.round(Style.font.title * 1.57)
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                      }

                      Text {
                        width: parent.width
                        visible: root.service && root.service.album !== ""
                        textFormat: Text.PlainText
                        text: root.service ? root.service.album : ""
                        color: root.artPalette.accentAlt || root.muted
                        font.family: root.displayFamily
                        font.pixelSize: Math.round(Style.font.title * 1.32)
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                      }

                      Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Style.space(8)
                        visible: root.service && root.service.stationName !== ""

                        Text {
                          width: Math.min(implicitWidth,
                            Math.max(1, nowPlayingMeta.width - pinCurrent.width - parent.spacing))
                          textFormat: Text.PlainText
                          text: root.service ? root.service.stationName : ""
                          color: root.artPalette.accentAlt || root.muted
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.body
                          elide: Text.ElideRight
                          anchors.verticalCenter: parent.verticalCenter
                        }

                        Button {
                          id: pinCurrent
                          iconText: root.service && root.service.isPinned(root.service.stationPath)
                            ? "󰐃" : "󰤱"
                          foreground: root.artPalette.accentAlt || root.foreground
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

                Visualizer {
                  id: visualizer
                  anchors.fill: parent
                  anchors.margins: Style.space(12)
                  centerHeight: Math.round(parent.height * 0.33)
                  protectedWidth: nowPlayingMeta.width + Style.space(24)
                  playing: !!(root.service && root.service.playing)
                  active: root.opened && root.currentTab === "nowplaying"
                  barColors: root.artPalette.accent
                    ? [root.accentAlt, root.accent, root.muted] : [root.accent]
                  shadedBars: !!root.artPalette.accent
                  dimColor: root.muted
                }
              }

              Flickable {
                anchors.fill: parent
                visible: root.currentTab === "stations"
                clip: true
                contentWidth: width
                contentHeight: stationList.implicitHeight

                Column {
                  id: stationList
                  width: parent.width
                  spacing: Style.space(2)

                  Text {
                    textFormat: Text.PlainText
                    visible: !root.connected
                    width: parent.width
                    text: "Open Pithos and sign in to load your stations."
                    color: root.muted
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    wrapMode: Text.WordWrap
                  }

                  Repeater {
                    model: root.filteredStations
                    BorderSurface {
                      required property var modelData
                      width: stationList.width
                      height: Style.space(44)
                      radius: Style.spacing.labelGap
                      readonly property bool selected: root.service
                        && String(root.service.stationPath) === String(modelData.path)
                      readonly property bool cursor: {
                        var list = root.keyboardStations
                        var index = root.stationCursor
                        return index >= 0 && index < list.length
                          && String(list[index].path) === String(modelData.path)
                      }
                      color: selected
                        ? Style.selectedFillFor(root.foreground, root.accent)
                        : "transparent"
                      borderSpec: selected || cursor
                        ? Border.controlSpec("selected", root.foreground, root.accent)
                        : Border.none()

                      Row {
                        anchors.fill: parent
                        anchors.leftMargin: Style.space(8)
                        anchors.rightMargin: Style.space(8)
                        spacing: Style.space(10)

                        OpticalGlyph {
                          width: Style.space(18)
                          height: Style.space(18)
                          anchors.verticalCenter: parent.verticalCenter
                          text: "󰐹"
                          color: root.foreground
                          fontFamily: root.fontFamily
                          fontSize: Style.font.body
                        }

                        Text {
                          width: Math.max(40, parent.width - Style.space(110))
                          anchors.verticalCenter: parent.verticalCenter
                          textFormat: Text.PlainText
                          text: modelData.name || "Station"
                          color: root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.body
                          elide: Text.ElideRight
                        }

                        Button {
                          anchors.verticalCenter: parent.verticalCenter
                          iconText: root.service && root.service.isPinned(modelData.path)
                            ? "󰐃" : "󰤱"
                          foreground: root.foreground
                          tooltipText: root.service && root.service.isPinned(modelData.path)
                            ? "Unpin from My list" : "Pin to My list"
                          onClicked: if (root.service) root.service.togglePin(modelData)
                        }

                        Button {
                          anchors.verticalCenter: parent.verticalCenter
                          iconText: "󰐊"
                          foreground: root.foreground
                          tooltipText: "Play station"
                          onClicked: if (root.service)
                            root.service.activateStation(modelData.path)
                        }
                      }

                      MouseArea {
                        anchors.fill: parent
                        z: -1
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          root.stationCursor = root.stationIndex(root.keyboardStations, modelData.path)
                          if (root.service) root.service.activateStation(modelData.path)
                        }
                      }
                    }
                  }
                }
              }

              Column {
                anchors.fill: parent
                spacing: Style.space(12)
                visible: root.currentTab === "setup"

                Button {
                  text: "Open Pithos"
                  iconText: "󰍂"
                  foreground: root.foreground
                  onClicked: if (root.service) root.service.raisePithos()
                }

                Text {
                  width: parent.width
                  visible: root.service && root.service.lastError !== ""
                  textFormat: Text.PlainText
                  text: root.service ? root.service.lastError : ""
                  color: Commons.Color.urgent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WordWrap
                }
              }
            }
          }
        }

        PanelSeparator {
          id: footerSeparator
          visible: true
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: playerFooter.top
          anchors.bottomMargin: Style.space(4)
          foreground: root.artPalette.accentAlt || root.foreground
          gradient: root.artPalette.accent ? playbackRail : null

          Gradient {
            id: playbackRail
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Util.alpha(root.accentAlt, 0.22) }
            GradientStop { position: 0.35; color: Util.alpha(root.accentAlt, 0.72) }
            GradientStop { position: 0.72; color: Util.alpha(root.accent, 0.72) }
            GradientStop { position: 1; color: Util.alpha(root.accent, 0.22) }
          }
        }

        BorderSurface {
          id: playerFooter
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: Style.space(108)
          color: Util.alpha(Qt.darker(root.background, 1.58), 0.94)
          radius: Style.cornerRadius
          borderSpec: root.frameSpec(root.browseTarget === "player")

          Row {
            id: playerRow
            anchors.fill: parent
            anchors.margins: Style.space(7)
            spacing: Style.space(7)
            readonly property real deckWidth: width - 2 * spacing

            DeckSurface {
              width: Math.round(playerRow.deckWidth * 0.29)
              height: parent.height
              baseColor: root.background
              accent: root.accentAlt
              themed: !!root.artPalette.accent

              AlbumFrame {
                id: footerArt
                width: Math.min(parent.height - Style.space(16), Style.space(64))
                height: width
                anchors.left: parent.left
                anchors.leftMargin: Style.space(9)
                anchors.verticalCenter: parent.verticalCenter
                radius: Style.cornerRadius
                color: Style.selectedFillFor(root.foreground, root.accent)
                foreground: root.foreground
                accent: root.accent
                accentAlt: root.accentAlt
                tinted: !!root.artPalette.accentAlt

                ArtImage {
                  id: footerArtImage
                  anchors.fill: parent
                  anchors.margins: Style.space(2)
                  requestedSource: root.service ? root.service.artUrl : ""
                  sourceSize.width: 128
                  sourceSize.height: 128
                  fillMode: Image.PreserveAspectFit
                  asynchronous: true
                  cache: true
                  visible: status === Image.Ready
                }

                Text {
                  textFormat: Text.PlainText
                  anchors.centerIn: parent
                  visible: footerArtImage.status !== Image.Ready
                  text: "󰎈"
                  color: root.muted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.iconLarge
                }
              }

              Column {
                anchors.left: footerArt.right
                anchors.leftMargin: Style.space(10)
                anchors.right: parent.right
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(3)

                Row {
                  width: parent.width
                  spacing: Style.space(3)
                  Text {
                    width: Math.max(20, parent.width - footerLike.width - parent.spacing)
                    textFormat: Text.PlainText
                    text: root.service && root.service.title
                      ? root.service.title : "Nothing playing"
                    color: root.service && root.service.title ? root.foreground : root.muted
                    font.family: root.displayFamily
                    font.pixelSize: Style.font.title * 1.08
                    font.weight: Font.DemiBold
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                  }
                  Button {
                    id: footerLike
                    iconText: root.service && root.service.loved ? "󰋑" : "󰋕"
                    iconSize: Style.font.body
                    foreground: Commons.Color.urgent
                    accent: Commons.Color.urgent
                    enabled: root.connected && root.service && root.service.hasMedia
                    horizontalPadding: Style.space(4)
                    verticalPadding: Style.space(2)
                    tooltipText: root.service && root.service.loved ? "Loved" : "Love this song"
                    onClicked: if (root.service) root.service.toggleLove()
                  }
                }

                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: root.service && root.service.artist
                    ? root.service.artist : "Choose a station to play"
                  color: root.service && root.service.artist ? root.accent : root.muted
                  font.family: root.displayFamily
                  font.pixelSize: Style.font.body
                  elide: Text.ElideRight
                }
              }
            }

            DeckSurface {
              width: Math.round(playerRow.deckWidth * 0.47)
              height: parent.height
              baseColor: root.background
              accent: root.accent
              themed: !!root.artPalette.accent
              emphasized: root.browseTarget === "player"

              Column {
                anchors.centerIn: parent
                width: parent.width - Style.space(26)
                spacing: Style.space(6)

                Row {
                  anchors.horizontalCenter: parent.horizontalCenter
                  spacing: Style.space(8)

                  TransportButton {
                    glyphText: "󰥊"
                    foreground: root.foreground
                    tooltipText: "Tired"
                    enabled: root.connected && root.service && root.service.hasMedia
                    onClicked: if (root.service) root.service.tired()
                  }
                  TransportButton {
                    glyphText: "󰒮"
                    foreground: root.foreground
                    enabled: false
                    opacity: 0.35
                  }
                  TransportButton {
                    glyphText: root.service && root.service.playing ? "󰏤" : "󰐊"
                    controlSize: Style.space(42)
                    glyphSize: Style.font.iconLarge * 1.16
                    radius: controlSize / 2
                    foreground: root.artPalette.accent || root.foreground
                    tooltipText: root.service && root.service.playing ? "Pause" : "Play"
                    accent: root.accent
                    selected: true
                    onClicked: if (root.service) root.service.togglePlayback()
                  }
                  TransportButton {
                    glyphText: "󰒭"
                    foreground: root.foreground
                    tooltipText: "Skip"
                    enabled: root.connected && root.service && root.service.canGoNext
                    onClicked: if (root.service) root.service.next()
                  }
                  TransportButton {
                    glyphText: "󰅙"
                    foreground: root.foreground
                    tooltipText: "Ban"
                    enabled: root.connected && root.service && root.service.hasMedia
                    onClicked: if (root.service) root.service.ban()
                  }
                }

                Row {
                  width: parent.width
                  spacing: Style.space(8)
                  visible: root.service && root.service.lengthSeconds > 0
                  Text {
                    id: elapsedTime
                    textFormat: Text.PlainText
                    text: Api.millisecondsToClock((root.service ? root.service.positionSeconds : 0) * 1000)
                    color: root.muted
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    anchors.verticalCenter: parent.verticalCenter
                  }
                  PlaybackSlider {
                    width: Math.max(1, parent.width - elapsedTime.width - totalTime.width - 2 * parent.spacing)
                    anchors.verticalCenter: parent.verticalCenter
                    trackHeight: Style.space(5)
                    bar: null
                    trackColor: root.artPalette.accent ? Util.alpha(root.accent, 0.24) : "#333"
                    fillColor: root.artPalette.accent || root.foreground
                    knobColor: fillColor
                    minimum: 0
                    maximum: Math.max(1, root.service ? root.service.lengthSeconds : 1)
                    sourceValue: root.service ? root.service.positionSeconds : 0
                    enabled: false
                  }
                  Text {
                    id: totalTime
                    textFormat: Text.PlainText
                    text: Api.millisecondsToClock((root.service ? root.service.lengthSeconds : 0) * 1000)
                    color: root.muted
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
              }
            }

            DeckSurface {
              width: playerRow.deckWidth - Math.round(playerRow.deckWidth * 0.29)
                - Math.round(playerRow.deckWidth * 0.47)
              height: parent.height
              baseColor: root.alternateSurface
              accent: root.accentAlt
              themed: !!root.artPalette.accent

              Column {
                anchors.centerIn: parent
                width: parent.width - Style.space(20)
                spacing: Style.space(4)

                Row {
                  width: parent.width
                  spacing: Style.space(7)

                  TransportButton {
                    id: muteButton
                    glyphText: volumeSlider.value <= 0.001 ? "󰝟" : "󰕾"
                    foreground: root.accentAlt
                    accent: root.accentAlt
                    controlSize: Style.space(28)
                    tooltipText: volumeSlider.value <= 0.001 ? "Unmute" : "Mute"
                    enabled: root.connected
                    onClicked: root.toggleMute()
                  }

                  Text {
                    id: volumeLabel
                    textFormat: Text.PlainText
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Volume"
                    color: root.foreground
                    font.family: root.displayFamily
                    font.pixelSize: Style.font.body
                    font.weight: Font.DemiBold
                  }

                  Item {
                    width: Math.max(0, parent.width - muteButton.width - volumeLabel.width
                      - volumePercent.width - 3 * parent.spacing)
                    height: 1
                  }

                  Text {
                    id: volumePercent
                    textFormat: Text.PlainText
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(Api.clampUnit(volumeSlider.value) * 100) + "%"
                    color: root.accentAlt
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                PlaybackSlider {
                  id: volumeSlider
                  width: parent.width
                  trackHeight: Style.space(5)
                  trackColor: root.artPalette.accentAlt ? Util.alpha(root.accentAlt, 0.24) : "#333"
                  fillColor: root.artPalette.accentAlt || root.foreground
                  knobColor: fillColor
                  minimum: 0
                  maximum: 1
                  step: 0.05
                  sourceValue: root.service ? root.service.volume : 0
                  liveCommit: true
                  enabled: root.connected
                  onCommitted: function(value) { root.setVolumeValue(value) }
                }
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

        BorderSurface {
          anchors.centerIn: parent
          width: Math.min(parent.width - Style.space(80), Style.space(560))
          height: helpColumn.implicitHeight + Style.space(32)
          radius: Style.cornerRadius
          color: Util.alpha(root.background, 0.94)
          borderSpec: Border.controlSpec("normal", root.foreground, root.accent)

          Column {
            id: helpColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Style.space(16)
            spacing: Style.space(8)

            Text {
              textFormat: Text.PlainText
              text: "Keyboard shortcuts"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }

            Repeater {
              model: [
                "Ctrl+F or / — Search stations",
                "Tab / F6 — My list, Your stations, then the big player",
                "Arrow keys — Move inside the Tab group",
                "Enter — Play the highlighted station",
                "C — Pin or unpin the highlighted station",
                "Space — Play or pause",
                "Ctrl+Right — Next song",
                "Ctrl+Up / Ctrl+Down — Volume",
                "M — Mute or restore volume",
                "Ctrl+/ — This list",
                "Esc — Close the player"
              ]
              Text {
                textFormat: Text.PlainText
                required property string modelData
                width: helpColumn.width
                text: modelData
                color: root.muted
                font.family: root.fontFamily
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
