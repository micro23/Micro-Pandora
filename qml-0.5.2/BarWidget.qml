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
            running: !Style.reduceMotion && root.pandora && root.pandora.scrollBarText
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
    contentWidth: fittedContentWidth(Style.space(412))
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
    readonly property bool lightTheme: Commons.Color.background.hslLightness > 0.55
    property color foreground: artPalette.foreground || (lightTheme ? "#f4f4f6" : root.foreground)
    property color muted: artPalette.muted || Qt.tint(foreground, Qt.rgba(0, 0, 0, 0.27))
    property color accent: artPalette.accent
      || (lightTheme ? Qt.tint(Commons.Color.accent, Qt.rgba(1, 1, 1, 0.55)) : Commons.Color.accent)
    property color accentAlt: artPalette.accentAlt || Qt.tint(accent, Util.alpha(foreground, 0.36))
    property color volumeAccent: artPalette.volumeAccent || accentAlt
    property color detailAccent: artPalette.detailAccent || accent
    property color surface: artPalette.background
      ? Qt.tint(artPalette.background, Qt.rgba(0, 0, 0, 0.35))
      : lightTheme ? "#15171d" : Commons.Color.background
    readonly property bool connected: !!(root.pandora && root.pandora.connected)
    readonly property bool playing: !!(root.pandora && root.pandora.playing)

    Behavior on surface { ColorAnimation { duration: Style.duration(240); easing.type: Easing.OutCubic } }
    Behavior on foreground { ColorAnimation { duration: Style.duration(240); easing.type: Easing.OutCubic } }
    Behavior on muted { ColorAnimation { duration: Style.duration(240); easing.type: Easing.OutCubic } }
    Behavior on accent { ColorAnimation { duration: Style.duration(240); easing.type: Easing.OutCubic } }
    Behavior on accentAlt { ColorAnimation { duration: Style.duration(240); easing.type: Easing.OutCubic } }
    Behavior on volumeAccent { ColorAnimation { duration: Style.duration(240); easing.type: Easing.OutCubic } }
    Behavior on detailAccent { ColorAnimation { duration: Style.duration(240); easing.type: Easing.OutCubic } }

    borderSpec: Border.flat(Util.alpha(popup.accentAlt, 0.31), 1)

    AlbumBackdrop {
      anchors.fill: contentColumn
      anchors.margins: -(popup.padding - Style.space(1))
      baseColor: popup.surface
      secondaryColor: Qt.tint(popup.surface, Util.alpha(popup.artPalette.backgroundAlt || popup.accent, 0.28))
      artSource: root.popupOpen && root.pandora ? root.pandora.artUrl : ""
      radius: Style.space(7)
      z: -1
    }

    Column {
      id: contentColumn
      anchors.fill: parent
      spacing: Style.space(11)

      RowLayout {
        width: parent.width
        spacing: Style.space(5)

        Rectangle {
          Layout.preferredWidth: Style.space(31)
          Layout.preferredHeight: Style.space(31)
          radius: Style.space(8)
          color: Util.alpha(popup.accentAlt, 0.14)
          border.color: Util.alpha(popup.accentAlt, 0.28)
          border.width: 1

          OpticalGlyph {
            anchors.centerIn: parent
            width: Style.space(17)
            height: width
            text: "󰝚"
            color: popup.accentAlt
            fontFamily: Style.font.family
            fontSize: Style.font.iconLarge
          }
        }

        Text {
          Layout.fillWidth: true
          Layout.leftMargin: Style.space(3)
          textFormat: Text.PlainText
          text: "Micro-Pandora"
          color: popup.foreground
          font.family: root.displayFamily
          font.pixelSize: Style.font.title * 1.05
          font.weight: Font.DemiBold
          elide: Text.ElideRight
        }

        TransportButton {
          glyphText: "󰒓"
          controlSize: Style.space(27)
          foreground: popup.muted
          accent: popup.accentAlt
          tooltipText: "Pandora settings"
          onClicked: if (root.pandora) root.pandora.openFullPlayer(root.thisScreenName(), "setup")
        }

        TransportButton {
          glyphText: "󰘖"
          controlSize: Style.space(29)
          foreground: popup.accentAlt
          accent: popup.accentAlt
          bordered: true
          tooltipText: "Open full player"
          onClicked: root.openFullPanel()
        }

        TransportButton {
          glyphText: "󰅖"
          controlSize: Style.space(27)
          foreground: popup.muted
          accent: popup.accentAlt
          tooltipText: "Close Micro-Pandora"
          onClicked: root.stopAndClose()
        }
      }

      DeckSurface {
        width: parent.width
        height: setupPrompt.implicitHeight + Style.space(22)
        visible: !popup.connected
        baseColor: popup.surface
        accent: popup.accentAlt
        themed: true

        Button {
          id: setupPrompt
          anchors.centerIn: parent
          text: root.pandora && root.pandora.launching ? "Connecting…" : "Pandora settings"
          iconText: "󰍂"
          foreground: popup.foreground
          accent: popup.accent
          enabled: root.pandora && !root.pandora.launching
          onClicked: root.pandora.openFullPlayer(root.thisScreenName(), "setup")
        }
      }

      Text {
        width: parent.width
        visible: text !== ""
        textFormat: Text.PlainText
        text: root.pandora ? root.pandora.commandError || root.pandora.statusError : ""
        font.family: root.displayFamily
        font.pixelSize: Style.font.body
        color: Commons.Color.urgent
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
      }

      DeckSurface {
        width: parent.width
        height: miniDetails.implicitHeight + Style.space(25)
        visible: popup.connected
        baseColor: Qt.tint(popup.surface, Util.alpha(popup.accentAlt, 0.07))
        accent: popup.accentAlt
        secondaryAccent: popup.accent
        themed: true
        litEdge: true

        RowLayout {
          id: miniDetails
          anchors.fill: parent
          anchors.leftMargin: Style.space(11)
          anchors.rightMargin: Style.space(11)
          spacing: Style.space(12)

          AlbumFrame {
            Layout.preferredWidth: Style.space(98)
            Layout.preferredHeight: Style.space(98)
            radius: Style.space(8)
            color: popup.surface
            foreground: popup.foreground
            accent: popup.accent
            accentAlt: popup.accentAlt
            tinted: true
            glow: miniArt.hasArtwork
            lightLevel: popup.playing ? 0.28 : 0

            CoverTransition {
              id: miniArt
              anchors.fill: parent
              anchors.margins: Style.space(3)
              requestedSource: root.popupOpen && root.pandora ? root.pandora.artUrl : ""
              decodeSize: 320
            }

            FallbackCover {
              anchors.fill: parent
              anchors.margins: Style.space(3)
              visible: !miniArt.hasArtwork
              baseColor: popup.surface
              accent: popup.accent
              accentAlt: popup.accentAlt
            }
          }

          ColumnLayout {
            id: miniMetadata
            Layout.fillWidth: true
            spacing: Style.space(3)

            TrackFade {
              trackKey: miniTitle.text + "\n" + (root.pandora ? root.pandora.artist : "")
              target: miniMetadata
              shown: root.popupOpen
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(4)
              visible: root.pandora && root.pandora.stationName !== ""

              PlaybackIndicator {
                Layout.preferredWidth: Style.space(13)
                Layout.preferredHeight: Style.space(13)
                active: root.popupOpen && visible
                playing: popup.playing
                tone: popup.accentAlt
              }

              Text {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                text: root.pandora ? root.pandora.stationName : ""
                color: popup.accentAlt
                font.family: root.displayFamily
                font.pixelSize: Style.font.caption
                font.weight: Font.DemiBold
                elide: Text.ElideRight
              }
            }

            Text {
              id: miniTitle
              Layout.fillWidth: true
              textFormat: Text.PlainText
              text: root.pandora && root.pandora.title ? root.pandora.title : "Nothing playing"
              color: popup.foreground
              font.family: root.displayFamily
              font.pixelSize: Style.font.title * 1.46
              font.weight: Font.Bold
              font.letterSpacing: -Style.space(0.45)
              wrapMode: Text.Wrap
              maximumLineCount: 2
              elide: Text.ElideRight
            }

            Text {
              Layout.fillWidth: true
              visible: text !== ""
              textFormat: Text.PlainText
              text: root.pandora ? root.pandora.artist : ""
              color: popup.accent
              font.family: root.displayFamily
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
            }

            Text {
              Layout.fillWidth: true
              visible: text !== ""
              textFormat: Text.PlainText
              text: root.pandora ? root.pandora.album : ""
              color: popup.muted
              font.family: root.displayFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }
          }

          TransportButton {
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: Style.space(9)
            controlSize: Style.space(25)
            glyphText: root.pandora && root.pandora.loved ? "󰋑" : "󰋕"
            foreground: root.pandora && root.pandora.loved ? Commons.Color.urgent : popup.muted
            accent: Commons.Color.urgent
            enabled: root.pandora && root.pandora.hasMedia
            tooltipText: root.pandora && root.pandora.loved ? "Loved" : "Love this song"
            onClicked: if (root.pandora) root.pandora.toggleLove()
          }
        }
      }

      DeckSurface {
        width: parent.width
        height: miniControls.implicitHeight + Style.space(20)
        visible: popup.connected
        baseColor: popup.surface
        accent: popup.accentAlt
        secondaryAccent: popup.detailAccent
        themed: true

        ColumnLayout {
          id: miniControls
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.margins: Style.space(11)
          spacing: Style.space(5)

          ProgressTrack {
            Layout.fillWidth: true
            inlineTimes: false
            visible: root.pandora && root.pandora.lengthSeconds > 0
            position: root.pandora ? root.pandora.positionSeconds : 0
            duration: root.pandora ? root.pandora.lengthSeconds : 0
            foreground: popup.foreground
            muted: popup.muted
            accent: popup.accent
            accentAlt: popup.detailAccent
          }

          Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: Style.space(9)

            TransportButton {
              anchors.verticalCenter: parent.verticalCenter
              glyphText: "󰥊"
              foreground: popup.muted
              accent: popup.accentAlt
              tooltipText: "Tired of this song"
              enabled: root.pandora && root.pandora.hasMedia
              onClicked: if (root.pandora) root.pandora.tired()
            }

            TransportButton {
              anchors.verticalCenter: parent.verticalCenter
              glyphText: "󰒮"
              foreground: popup.muted
              tooltipText: "Previous is not available on Pandora"
              enabled: false
              opacity: 0.35
            }

            TransportButton {
              anchors.verticalCenter: parent.verticalCenter
              glyphText: popup.playing ? "󰏤" : "󰐊"
              glyphSize: Style.font.iconLarge * 1.12
              controlSize: Style.space(43)
              foreground: popup.foreground
              accent: popup.accent
              accentAlt: popup.accentAlt
              primary: true
              tooltipText: popup.playing ? "Pause" : "Play"
              onClicked: if (root.pandora) root.pandora.togglePlayback()
            }

            TransportButton {
              anchors.verticalCenter: parent.verticalCenter
              glyphText: "󰒭"
              foreground: popup.foreground
              accent: popup.accent
              tooltipText: "Skip"
              enabled: root.pandora && root.pandora.canGoNext
              onClicked: if (root.pandora) root.pandora.next()
            }

            TransportButton {
              anchors.verticalCenter: parent.verticalCenter
              glyphText: "󰅙"
              foreground: popup.muted
              accent: popup.accentAlt
              tooltipText: "Ban this song"
              enabled: root.pandora && root.pandora.hasMedia
              onClicked: if (root.pandora) root.pandora.ban()
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Util.alpha(popup.foreground, 0.10)
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)

            TransportButton {
              glyphText: miniVolume.value <= 0.001 ? "󰝟" : "󰕾"
              controlSize: Style.space(24)
              glyphSize: Style.font.icon
              foreground: popup.volumeAccent
              accent: popup.volumeAccent
              enabled: popup.connected
              tooltipText: miniVolume.value <= 0.001 ? "Unmute" : "Mute"
              onClicked: root.toggleMute()
            }

            PlaybackSlider {
              id: miniVolume
              Layout.fillWidth: true
              Accessible.name: "Volume"
              bar: root.bar
              trackHeight: Style.space(4)
              knobSize: Style.space(12)
              trackColor: Util.alpha(popup.foreground, 0.16)
              fillColor: popup.volumeAccent
              knobColor: fillColor
              minimum: 0
              maximum: 1
              step: 0.05
              sourceValue: root.pandora ? root.pandora.volume : 0
              enabled: root.pandora && root.pandora.volumeSupported
              liveCommit: true
              onCommitted: function(value) { root.setVolumeValue(value) }
            }

            Text {
              Layout.preferredWidth: Style.space(33)
              textFormat: Text.PlainText
              text: Math.round(Api.clampUnit(miniVolume.value) * 100) + "%"
              color: popup.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignRight
            }
          }
        }
      }
    }

  }
}
