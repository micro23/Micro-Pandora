import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Api.js" as Api

BarWidget {
  id: root
  moduleName: "io.github.dankestrick.omapandora"

  readonly property var pandora: bar && bar.shell
    ? bar.shell.serviceFor("io.github.dankestrick.omapandora") : null
  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color muted: Commons.Color.muted
  readonly property string displayFamily: "Adwaita Sans"
  readonly property string barText: pandora
    ? Api.barTrackText(pandora.title, pandora.artist,
      pandora.showTrackTitle, pandora.showArtistName, pandora.playing,
      pandora.showPausedTrack) : ""
  readonly property bool miniPlayerEnabled:
    String(root.setting("showMiniPlayer", "On")) !== "Off"
  readonly property bool iconOnly: !pandora || vertical || !pandora.hasMedia
    || barText === ""
  property bool popupOpen: false
  property real volumeBeforeMute: 0.5
  readonly property bool panelOpen: bar && bar.shell
    && typeof bar.shell.isPluginOpen === "function"
    && bar.shell.isPluginOpen(moduleName)
  readonly property bool opened: popupOpen

  function setting(key, fallback) {
    if (settings && settings[key] !== undefined && settings[key] !== null)
      return settings[key]
    return fallback
  }

  function open() {
    if (miniPlayerEnabled) popupOpen = true
    else openFullPanel()
  }
  function close() {
    popupOpen = false
  }
  function toggle() {
    if (!miniPlayerEnabled) {
      openFullPanel()
      return
    }
    popupOpen = !popupOpen
  }
  function closeForPopoutSwitch() { popupOpen = false }

  function thisScreenName() {
    var win = root.QsWindow ? root.QsWindow.window : null
    return win && win.screen ? String(win.screen.name || "") : ""
  }

  function hideFullPanel() {
    var host = bar ? bar.shell : null
    if (host && typeof host.isPluginOpen === "function" && host.isPluginOpen(moduleName)
        && typeof host.hide === "function")
      host.hide(moduleName)
  }

  function stopAndClose() {
    if (pandora) pandora.stopAndQuit()
    popupOpen = false
    hideFullPanel()
  }

  function openMiniPopup() {
    popupOpen = true
  }

  function openFullPanel() {
    if (pandora) {
      pandora.openFullPlayer(thisScreenName())
      return
    }
    var host = bar ? bar.shell : null
    if (!host) return
    if (typeof host.isPluginOpen === "function" && host.isPluginOpen(moduleName))
      return
    if (typeof host.summon === "function") host.summon(moduleName, "{}")
    else if (typeof host.show === "function") host.show(moduleName)
  }

  function setVolumeValue(value) {
    if (!pandora) return
    if (value > 0.001) volumeBeforeMute = value
    pandora.setVolume(value)
  }

  function toggleMute() {
    if (!pandora) return
    if (pandora.volume > 0.001) {
      volumeBeforeMute = pandora.volume
      pandora.setVolume(0)
    } else pandora.setVolume(volumeBeforeMute || 0.5)
  }

  function syncSettings() {
    if (pandora) pandora.applySettings(settings)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onSettingsChanged: syncSettings()
  onPandoraChanged: {
    syncSettings()
    if (pandora) pandora.registerPlayerSurface(root)
  }
  onPopupOpenChanged: if (pandora) pandora.setUiVisible(root, popupOpen)
  onMiniPlayerEnabledChanged: if (!miniPlayerEnabled) popupOpen = false

  Component.onCompleted: {
    syncSettings()
    if (pandora) pandora.registerPlayerSurface(root)
  }
  Component.onDestruction: if (pandora) {
    pandora.unregisterPlayerSurface(root)
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.iconOnly ? "󰝚" : ""
    hasVisualContent: true
    slotSize: Style.bar.iconSlot
    opticalSize: Style.bar.iconCanvas
    fontSize: root.iconOnly ? Math.round(Style.bar.iconFont * 0.9) : Style.font.body
    active: root.pandora && root.pandora.playing
    foreground: root.bar ? root.bar.barForeground : root.foreground
    activeColor: foreground
    tooltipText: ""

    readonly property real fittedWidth: Math.ceil(barGlyph.width
      + barContent.spacing + barLabel.implicitWidth + scaledHorizontalMargin * 2)
    readonly property real barTextCap: root.pandora ? root.pandora.maxBarTextWidth : 240

    fixedWidth: root.vertical ? root.barSize
      : (root.iconOnly ? Style.bar.iconSlot
        : Api.barSlotWidth(false, barTextCap > 0 ? Style.space(barTextCap) : 0,
          fittedWidth, root.barSize))
    fixedHeight: root.vertical && root.iconOnly ? Style.bar.iconSlot : -1
    clip: true

    Row {
      id: barContent
      anchors.centerIn: parent
      spacing: Style.space(6)
      visible: !root.iconOnly
      enabled: false

      OpticalGlyph {
        id: barGlyph
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(16)
        height: Style.space(16)
        text: "󰝚"
        color: button.foreground
        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        fontSize: Style.font.body
      }

      Item {
        id: scrollClip
        width: Math.max(0, button.width - barGlyph.width
          - barContent.spacing - button.scaledHorizontalMargin * 2)
        height: barGlyph.height
        anchors.verticalCenter: parent.verticalCenter
        clip: true

        Text {
          id: barLabel
          textFormat: Text.PlainText
          anchors.verticalCenter: parent.verticalCenter
          text: root.barText
          color: button.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
          renderType: Text.NativeRendering

          XAnimator on x {
            running: root.pandora && root.pandora.scrollBarText
              && implicitWidth > scrollClip.width && !root.popupOpen && !root.vertical
            loops: Animation.Infinite
            duration: Math.round(Math.max(6000, implicitWidth * 25))
            from: scrollClip.width
            to: -implicitWidth
            easing.type: Easing.Linear
            onStopped: barLabel.x = 0
          }
        }
      }
    }

    onPressed: function(mouseButton) {
      if (mouseButton === Qt.MiddleButton) {
        if (root.pandora) root.pandora.togglePlayback()
      } else if (mouseButton === Qt.RightButton) {
        root.openFullPanel()
      } else root.toggle()
    }
    onWheelMoved: function(delta) { root.wheelNext(delta) }
  }

  function wheelNext(delta) {
    if (!root.pandora) return
    if (delta < 0) root.pandora.next()
  }

  KeyboardPanel {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: fittedContentWidth(Style.space(380))
    contentHeight: fittedContentHeight(contentColumn.implicitHeight, Style.space(560))

    // The mini player is a full-screen overlay that forwards bar clicks but
    // not scrolls, so catch wheel over the bar icon here while it is open.
    // Children land inside the card, so move this to the overlay's root.
    Item {
      id: barWheelCatcher
      z: -1
      width: popup.screenW
      height: popup.screenH
      Component.onCompleted: Qt.callLater(function() {
        var p = barWheelCatcher.parent
        while (p && p.parent) p = p.parent
        if (p) barWheelCatcher.parent = p
      })

      WheelHandler {
        id: barWheel
        enabled: root.popupOpen
        onWheel: function(event) {
          if (event.angleDelta.y === 0) return
          var pos = barWheel.point.position
          var x = pos.x, y = pos.y
          if (popup.barPos === "bottom") y -= popup.screenH - popup.barH
          else if (popup.barPos === "right") x -= popup.screenW - popup.barW
          var a = popup.anchorScreenPos
          if (x >= a.x && x <= a.x + popup.anchorW
              && y >= a.y && y <= a.y + popup.anchorH)
            root.wheelNext(event.angleDelta.y)
        }
      }
    }

    readonly property var artPalette: (root.pandora && root.pandora.artPalette) || ({})
    readonly property color foreground: artPalette.foreground || root.foreground
    readonly property color muted: artPalette.muted || root.muted
    readonly property color accent: artPalette.accent || Commons.Color.accent
    readonly property color accentAlt: artPalette.accentAlt || accent

    AlbumBackdrop {
      anchors.fill: contentColumn
      anchors.margins: -(popup.padding - Style.space(2))
      visible: !!popup.artPalette.background
      baseColor: popup.artPalette.background || "transparent"
      secondaryColor: popup.artPalette.backgroundAlt || baseColor
      artSource: root.popupOpen && root.pandora ? root.pandora.artUrl : ""
      radius: Style.cornerRadius
      z: -1
    }

    Column {
      id: contentColumn
      anchors.fill: parent
      spacing: Style.space(12)

      Row {
        width: parent.width
        spacing: Style.space(10)

        Text {
          id: heroIcon
          textFormat: Text.PlainText
          text: "󰝚"
          color: popup.accentAlt
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.display
          anchors.verticalCenter: parent.verticalCenter
        }

        Column {
          id: heroLabels
          width: Math.max(40, parent.width - heroIcon.width - miniClose.width
            - miniSwitch.width - parent.spacing * 3)
          spacing: Style.space(2)
          anchors.verticalCenter: parent.verticalCenter

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: "Micro-Pandora"
            color: popup.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
            elide: Text.ElideRight
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: {
              if (root.pandora && root.pandora.stationName)
                return String(root.pandora.stationName).toUpperCase()
              if (root.pandora && root.pandora.playing) return "PLAYING"
              return "READY"
            }
            color: popup.artPalette.accentAlt || popup.muted
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1.2
            elide: Text.ElideRight
          }
        }

        Button {
          id: miniClose
          iconText: "󰅖"
          foreground: popup.foreground
          accent: popup.accent
          tooltipText: "Close Micro-Pandora"
          anchors.verticalCenter: parent.verticalCenter
          onClicked: root.stopAndClose()
        }

        ToggleSwitch {
          id: miniSwitch
          checked: true
          foreground: popup.foreground
          accent: popup.accent
          anchors.verticalCenter: parent.verticalCenter
          onToggled: root.openFullPanel()

          PanelToolTip {
            visible: miniSwitch.containsMouse
            text: "Open full player"
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          }
        }
      }

      Column {
        width: parent.width
        spacing: Style.space(8)
        visible: !root.pandora || !root.pandora.connected

        Button {
          text: root.pandora && root.pandora.launching ? "Opening Pithos…" : "Open Pithos"
          iconText: "󰍂"
          foreground: popup.foreground
          accent: popup.accent
          enabled: root.pandora && !root.pandora.launching
          onClicked: root.pandora.raisePithos()
        }
      }

      Text {
        width: parent.width
        visible: text !== ""
        textFormat: Text.PlainText
        text: root.pandora ? root.pandora.commandError || root.pandora.statusError : ""
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        color: popup.foreground
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
      }

      Item {
        id: miniNowPlaying
        width: parent.width
        implicitHeight: Math.max(miniArtwork.height, miniMeta.implicitHeight)
        height: implicitHeight
        visible: root.pandora && root.pandora.connected

        AlbumFrame {
          id: miniArtwork
          width: Style.space(78)
          height: width
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          radius: Style.cornerRadius
          color: Style.normalFillFor(popup.foreground, popup.accent)
          foreground: popup.foreground
          accent: popup.accent
          accentAlt: popup.accentAlt
          tinted: !!popup.artPalette.accentAlt

          ArtImage {
            id: miniArt
            anchors.fill: parent
            anchors.margins: Style.space(3)
            requestedSource: root.popupOpen && root.pandora ? root.pandora.artUrl : ""
            sourceSize.width: 156
            sourceSize.height: 156
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: true
            visible: status === Image.Ready
          }

          Text {
            textFormat: Text.PlainText
            anchors.centerIn: parent
            visible: miniArt.status !== Image.Ready
            text: "󰝚"
            color: popup.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.displayLarge
          }
        }

        Column {
          id: miniMeta
          anchors.left: miniArtwork.right
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: Style.space(12)
          spacing: Style.space(4)

          Row {
            width: parent.width
            spacing: Style.space(4)

            Text {
              width: Math.max(20, parent.width - likeButton.width - parent.spacing)
              textFormat: Text.PlainText
              text: root.pandora && root.pandora.title ? root.pandora.title : "Nothing playing"
              color: root.pandora && root.pandora.title ? popup.foreground : popup.muted
              font.family: root.displayFamily
              font.pixelSize: Style.font.title * 1.12
              font.weight: Font.DemiBold
              wrapMode: Text.Wrap
              maximumLineCount: 2
              elide: Text.ElideRight
            }

            Button {
              id: likeButton
              anchors.verticalCenter: parent.verticalCenter
              iconText: root.pandora && root.pandora.loved ? "󰋑" : "󰋕"
              iconSize: Style.font.body
              foreground: Commons.Color.urgent
              accent: Commons.Color.urgent
              enabled: root.pandora && root.pandora.hasMedia
              horizontalPadding: Style.space(4)
              verticalPadding: Style.space(2)
              tooltipText: root.pandora && root.pandora.loved ? "Loved" : "Love this song"
              onClicked: if (root.pandora) root.pandora.toggleLove()
            }
          }

          Text {
            width: parent.width
            visible: root.pandora && root.pandora.artist !== ""
            textFormat: Text.PlainText
            text: root.pandora ? root.pandora.artist : ""
            color: popup.accent
            font.family: root.displayFamily
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            visible: root.pandora && (root.pandora.album !== "" || root.pandora.stationName !== "")
            text: root.pandora
              ? (root.pandora.album || root.pandora.stationName) : ""
            color: popup.artPalette.accentAlt || popup.muted
            font.family: root.displayFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }
        }
      }

      Column {
        width: parent.width
        spacing: Style.space(3)
        visible: root.pandora && root.pandora.connected && root.pandora.lengthSeconds > 0

        PlaybackSlider {
          width: parent.width
          bar: root.bar
          trackColor: popup.artPalette.accent ? Util.alpha(popup.accent, 0.24)
            : (bar ? Style.selectedFillFor(bar.foreground, Commons.Color.accent) : "#333")
          fillColor: popup.artPalette.accent || popup.foreground
          knobColor: fillColor
          minimum: 0
          maximum: Math.max(1, root.pandora ? root.pandora.lengthSeconds : 1)
          sourceValue: root.pandora ? root.pandora.positionSeconds : 0
          enabled: false
          step: 5
        }

        RowLayout {
          width: parent.width
          Text {
            textFormat: Text.PlainText
            text: Api.millisecondsToClock((root.pandora ? root.pandora.positionSeconds : 0) * 1000)
            color: popup.muted
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }
          Item { Layout.fillWidth: true }
          Text {
            textFormat: Text.PlainText
            text: Api.millisecondsToClock((root.pandora ? root.pandora.lengthSeconds : 0) * 1000)
            color: popup.muted
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(5)
        visible: root.pandora && root.pandora.connected

        TransportButton {
          glyphText: "󰥊"
          foreground: popup.foreground
          accent: popup.accent
          tooltipText: "Tired of this song"
          enabled: root.pandora && root.pandora.hasMedia
          onClicked: if (root.pandora) root.pandora.tired()
        }

        TransportButton {
          glyphText: "󰒮"
          foreground: popup.foreground
          accent: popup.accent
          tooltipText: "Previous is not available on Pandora"
          enabled: false
          opacity: 0.35
        }

        TransportButton {
          glyphText: root.pandora && root.pandora.playing ? "󰏤" : "󰐊"
          glyphSize: Style.font.iconLarge
          foreground: popup.artPalette.accent || popup.foreground
          accent: popup.accent
          selected: true
          tooltipText: root.pandora && root.pandora.playing ? "Pause" : "Play"
          onClicked: if (root.pandora) root.pandora.togglePlayback()
        }

        TransportButton {
          glyphText: "󰒭"
          foreground: popup.foreground
          accent: popup.accent
          tooltipText: "Skip"
          enabled: root.pandora && root.pandora.canGoNext
          onClicked: if (root.pandora) root.pandora.next()
        }

        TransportButton {
          glyphText: "󰅙"
          foreground: popup.foreground
          accent: popup.accent
          tooltipText: "Ban this song"
          enabled: root.pandora && root.pandora.hasMedia
          onClicked: if (root.pandora) root.pandora.ban()
        }
      }

      Row {
        width: parent.width
        spacing: Style.space(8)
        visible: root.pandora && root.pandora.connected

        Text {
          textFormat: Text.PlainText
          anchors.verticalCenter: parent.verticalCenter
          text: root.pandora && root.pandora.volume <= 0.001 ? "󰝟" : "󰕾"
          color: root.pandora && root.pandora.volume <= 0.001 ? popup.muted : popup.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.icon
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleMute()
          }
        }

        PlaybackSlider {
          width: parent.width - Style.space(34)
          Accessible.name: "Volume"
          anchors.verticalCenter: parent.verticalCenter
          bar: root.bar
          trackColor: popup.artPalette.accentAlt ? Util.alpha(popup.accentAlt, 0.24)
            : (bar ? Style.selectedFillFor(bar.foreground, Commons.Color.accent) : "#333")
          fillColor: popup.artPalette.accentAlt || popup.foreground
          knobColor: fillColor
          minimum: 0
          maximum: 1
          step: 0.05
          sourceValue: root.pandora ? root.pandora.volume : 0
          enabled: root.pandora && root.pandora.volumeSupported
          liveCommit: true
          onCommitted: function(value) { root.setVolumeValue(value) }
        }
      }

    }
  }
}
