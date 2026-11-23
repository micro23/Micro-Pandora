import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Flickable {
  id: root

  required property var account
  property var updater: null
  property var service: null
  required property color foreground
  required property color muted
  required property color accent
  required property color accentAlt
  required property color background
  readonly property color formSurface: Qt.tint(background, Qt.rgba(0, 0, 0, 0.34))
  readonly property string displayFamily: "Adwaita Sans"
  readonly property bool formReady: account && account.ready
  readonly property bool busy: !!(account && account.busy)

  property bool playlistEditorOpen: false
  property var selectedPlaylists: ({})
  property int selectedCount: 0
  property bool confirmDelete: false
  property bool deletingPlaylists: false
  property string playlistMessage: ""
  property bool playlistMessageFailed: false
  property string playlistFilter: ""

  clip: true
  contentWidth: width
  contentHeight: layout.implicitHeight + Style.space(36)
  boundsBehavior: Flickable.StopAtBounds
  Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }

  function getStationsList() {
    if (!service || !Array.isArray(service.stations)) return []
    return service.stations
  }

  function filteredStations() {
    var all = getStationsList()
    if (!playlistFilter) return all
    var query = playlistFilter.toLowerCase()
    var out = []
    for (var i = 0; i < all.length; i++) {
      var s = all[i]
      if (s && s.name && s.name.toLowerCase().indexOf(query) !== -1) {
        out.push(s)
      }
    }
    return out
  }

  function isPlaylistSelected(id) {
    return !!selectedPlaylists[String(id)]
  }

  function togglePlaylist(id) {
    var sid = String(id)
    var next = {}
    for (var k in selectedPlaylists) next[k] = true
    if (next[sid]) delete next[sid]
    else next[sid] = true
    selectedPlaylists = next
    updateSelectedCount()
  }

  function selectAllFiltered() {
    var list = filteredStations()
    var next = {}
    for (var k in selectedPlaylists) next[k] = true
    for (var i = 0; i < list.length; i++) {
      var s = list[i]
      if (s && s.name !== "QuickMix") {
        next[String(s.id)] = true
      }
    }
    selectedPlaylists = next
    updateSelectedCount()
  }

  function clearSelection() {
    selectedPlaylists = ({})
    updateSelectedCount()
  }

  function updateSelectedCount() {
    var count = 0
    for (var k in selectedPlaylists) count++
    selectedCount = count
  }

  function executeDelete() {
    var ids = []
    for (var k in selectedPlaylists) ids.push(k)
    if (ids.length === 0 || deletingPlaylists) return
    deletingPlaylists = true
    playlistMessage = "Deleting " + ids.length + " playlist(s) from Pandora…"
    playlistMessageFailed = false
    deleteProcess.targetIds = ids
    var helper = service && service.helper ? service.helper : (account ? account.helper : "")
    deleteProcess.command = [helper, "delete-stations"].concat(ids)
    deleteProcess.running = true
  }

  Process {
    id: deleteProcess
    property var targetIds: []
    stdout: StdioCollector { id: deleteStdout; waitForEnd: true }
    stderr: StdioCollector { id: deleteStderr; waitForEnd: true }
    onExited: function(code) {
      root.deletingPlaylists = false
      root.confirmDelete = false
      if (code === 0) {
        root.playlistMessage = "Successfully removed " + targetIds.length + " playlist(s)."
        root.playlistMessageFailed = false
        root.selectedPlaylists = ({})
        root.updateSelectedCount()
        if (root.service) root.service.refresh()
      } else {
        var err = deleteStderr.text.trim()
        root.playlistMessage = err ? err.split("\n")[0] : "Could not delete playlists. Check connection."
        root.playlistMessageFailed = true
      }
    }
  }

  function submit() {
    if (!formReady || busy || account.changingWindow) return
    var email = emailField.text.trim()
    if (!email) return
    if (passwordField.text) {
      if (account.save(email, passwordField.text)) passwordField.clear()
    } else if (email === account.email) {
      account.connectAccount()
    }
  }

  GridLayout {
    id: layout
    width: Math.min(root.width - Style.space(24), Style.space(850))
    anchors.horizontalCenter: parent.horizontalCenter
    y: Style.space(18)
    columns: width >= Style.space(730) ? 2 : 1
    columnSpacing: Style.space(14)
    rowSpacing: Style.space(12)

    DeckSurface {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignTop
      Layout.preferredWidth: Style.space(450)
      Layout.preferredHeight: signIn.implicitHeight + Style.space(42)
      baseColor: root.formSurface
      accent: root.accent
      themed: true
      emphasized: true
      radius: Style.space(15)

      ColumnLayout {
        id: signIn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(21)
        spacing: Style.space(11)

        RowLayout {
          Layout.fillWidth: true

          CardHeading {
            Layout.fillWidth: true
            title: "Pandora account"
            symbol: "󰍂"
            tone: root.accent
          }

          Rectangle {
            visible: root.account && root.account.hasStations
            Layout.preferredWidth: connectionStatus.implicitWidth + Style.space(19)
            Layout.preferredHeight: Style.space(25)
            radius: height / 2
            color: Util.alpha(root.accentAlt, 0.13)
            border.width: 1
            border.color: Util.alpha(root.accentAlt, 0.23)

            Text {
              id: connectionStatus
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: "Connected"
              color: root.accentAlt
              font.family: root.displayFamily
              font.pixelSize: Style.font.caption
              font.weight: Font.DemiBold
            }
          }
        }

        Text {
          Layout.fillWidth: true
          textFormat: Text.PlainText
          text: root.account && root.account.hasStations
            ? "Saving different credentials reconnects playback."
            : "Sign in to load your stations. Your password is saved in the desktop keyring."
          color: root.muted
          font.family: root.displayFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        FieldLabel {
          text: "Pandora email"
        }

        AccountField {
          id: emailField
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(40)
          enabled: root.formReady && !root.busy
          text: root.account ? root.account.email : ""
          placeholderText: "Email address"
          Accessible.name: "Pandora email"
          maximumLength: 320
          inputMethodHints: Qt.ImhEmailCharactersOnly | Qt.ImhNoPredictiveText
          foreground: root.foreground
          accent: root.accent
          onAccepted: passwordField.forceActiveFocus()
        }

        FieldLabel {
          text: "Pandora password"
        }

        AccountField {
          id: passwordField
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(40)
          enabled: root.formReady && !root.busy
          placeholderText: "Password"
          Accessible.name: "Pandora password"
          password: true
          rightPadding: revealPassword.visible ? revealPassword.width + Style.space(8) : horizontalPadding
          inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
          maximumLength: 4096
          foreground: root.foreground
          accent: root.accent
          onAccepted: {
            revealed = false
            root.submit()
          }
          onTextChanged: if (!text) revealed = false

          TransportButton {
            id: revealPassword
            anchors.right: parent.right
            anchors.rightMargin: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter
            visible: passwordField.length > 0
            controlSize: Style.space(29)
            glyphText: passwordField.revealed ? "󰍶" : "󰈈"
            foreground: root.accentAlt
            accent: root.accentAlt
            tooltipText: passwordField.revealed ? "Hide password" : "Show password"
            Accessible.checkable: true
            Accessible.checked: passwordField.revealed
            onClicked: passwordField.revealed = !passwordField.revealed
          }
        }

        Button {
          text: root.busy ? "Connecting…" : passwordField.length ? "Save and connect"
            : root.account && root.account.hasStations ? "Reconnect" : "Connect"
          enabled: root.formReady && !root.busy && !root.account.changingWindow &&
            emailField.text.trim() !== "" && (passwordField.length > 0 || emailField.text.trim() === root.account.email)
          foreground: root.foreground
          accent: root.accent
          fontFamily: root.displayFamily
          radius: Style.space(8)
          horizontalPadding: Style.space(13)
          background: Util.alpha(root.accent, 0.13)
          bordered: true
          focusable: true
          onClicked: root.submit()
        }

        Text {
          Layout.fillWidth: true
          visible: text !== ""
          textFormat: Text.PlainText
          text: root.account ? root.account.message : ""
          color: root.account && root.account.failed ? Commons.Color.urgent : root.accentAlt
          font.family: root.displayFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }
      }
    }

    DeckSurface {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignTop
      Layout.preferredWidth: Style.space(350)
      Layout.preferredHeight: backend.implicitHeight + Style.space(42)
      baseColor: root.formSurface
      accent: root.accentAlt
      themed: true
      radius: Style.space(15)

      ColumnLayout {
        id: backend
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(21)
        spacing: Style.space(11)

        CardHeading {
          Layout.fillWidth: true
          title: "Playback backend"
          symbol: "󰎇"
          tone: root.accentAlt
        }

        Text {
          Layout.fillWidth: true
          textFormat: Text.PlainText
          text: root.account && root.account.checked && root.account.missing.length
            ? "Setup needs " + root.account.missing.join(", ") + "."
            : "Pithos handles playback in the background. Show its window if you need its native controls."
          color: root.muted
          font.family: root.displayFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)

          Button {
            visible: !!(root.account && root.account.checked && root.account.missing.length)
            text: "Install dependencies"
            foreground: root.accentAlt
            accent: root.accentAlt
            bordered: true
            focusable: true
            onClicked: root.account.installDependencies()
          }

          Button {
            visible: root.formReady
            enabled: !root.busy && !root.account.changingWindow
            text: root.account && root.account.showBackend ? "Hide Pithos window" : "Show Pithos window"
            foreground: root.accentAlt
            accent: root.accentAlt
            focusable: true
            onClicked: root.account.setWindowVisible(!root.account.showBackend)
          }

          Button {
            text: "Check setup"
            enabled: !!root.account && !root.busy
            foreground: root.foreground
            accent: root.accentAlt
            focusable: true
            onClicked: root.account.refresh()
          }
        }

        Button {
          text: "Add to app launcher"
          enabled: !!root.account && !root.account.registeringLauncher
          foreground: root.foreground
          accent: root.accentAlt
          focusable: true
          onClicked: root.account.registerLauncher()
        }
      }
    }

    DeckSurface {
      objectName: "playlistManager"
      Layout.columnSpan: layout.columns
      Layout.fillWidth: true
      Layout.preferredHeight: playlistColumn.implicitHeight + Style.space(42)
      baseColor: root.formSurface
      accent: root.accentAlt
      themed: true
      radius: Style.space(15)

      ColumnLayout {
        id: playlistColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(21)
        spacing: Style.space(12)

        RowLayout {
          Layout.fillWidth: true

          CardHeading {
            Layout.fillWidth: true
            title: root.playlistEditorOpen ? "Edit playlists" : "Playlists & stations"
            symbol: "󰎇"
            tone: root.accentAlt
          }

          Button {
            visible: root.playlistEditorOpen
            text: "Done"
            foreground: root.foreground
            accent: root.accent
            focusable: true
            bordered: true
            radius: Style.space(8)
            onClicked: {
              root.playlistEditorOpen = false
              root.confirmDelete = false
              root.playlistMessage = ""
            }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          visible: !root.playlistEditorOpen
          spacing: Style.space(10)

          Text {
            Layout.fillWidth: true
            textFormat: Text.PlainText
            text: "Remove auto-generated or unwanted stations that clutter your Pandora account."
            color: root.muted
            font.family: root.displayFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(12)

            Button {
              text: "Edit playlists"
              iconText: "󰏫"
              enabled: root.formReady && root.getStationsList().length > 0
              foreground: root.foreground
              accent: root.accent
              focusable: true
              bordered: true
              radius: Style.space(8)
              onClicked: {
                root.playlistEditorOpen = true
                root.confirmDelete = false
                root.playlistMessage = ""
              }
            }

            Text {
              Layout.fillWidth: true
              textFormat: Text.PlainText
              text: root.getStationsList().length + " playlists in library"
              color: root.muted
              font.family: root.displayFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          visible: root.playlistEditorOpen
          spacing: Style.space(10)

          Text {
            Layout.fillWidth: true
            textFormat: Text.PlainText
            text: "Check the playlists you want to remove, then click Delete Selected."
            color: root.muted
            font.family: root.displayFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)

            AccountField {
              id: filterField
              Layout.fillWidth: true
              Layout.preferredHeight: Style.space(38)
              placeholderText: "Search playlists…"
              text: root.playlistFilter
              onTextChanged: root.playlistFilter = text.trim()
            }

            Button {
              text: "Select all"
              foreground: root.foreground
              accent: root.accent
              focusable: true
              bordered: true
              radius: Style.space(8)
              onClicked: root.selectAllFiltered()
            }

            Button {
              text: "Clear"
              visible: root.selectedCount > 0
              foreground: root.muted
              accent: root.accentAlt
              focusable: true
              bordered: true
              radius: Style.space(8)
              onClicked: root.clearSelection()
            }

            Rectangle {
              visible: root.selectedCount > 0
              Layout.preferredHeight: Style.space(32)
              Layout.preferredWidth: selectedText.implicitWidth + Style.space(18)
              radius: height / 2
              color: Util.alpha(root.accent, 0.16)
              border.width: 1
              border.color: Util.alpha(root.accent, 0.35)

              Text {
                id: selectedText
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: root.selectedCount + " selected"
                color: root.accent
                font.family: root.displayFamily
                font.pixelSize: Style.font.caption
                font.weight: Font.DemiBold
              }
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(280)
            radius: Style.space(10)
            color: Qt.rgba(0, 0, 0, 0.25)
            border.width: 1
            border.color: Util.alpha(root.foreground, 0.08)
            clip: true

            Flickable {
              id: listFlick
              anchors.fill: parent
              anchors.margins: Style.space(6)
              contentWidth: width
              contentHeight: itemsCol.implicitHeight
              boundsBehavior: Flickable.StopAtBounds
              Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }

              ColumnLayout {
                id: itemsCol
                width: parent.width
                spacing: Style.space(2)

                Repeater {
                  model: root.filteredStations()
                  delegate: Rectangle {
                    id: rowItem
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(40)
                    radius: Style.space(7)
                    readonly property bool isQuickMix: modelData.name === "QuickMix"
                    readonly property bool isSelected: root.isPlaylistSelected(modelData.id)
                    color: rowMouse.containsMouse
                      ? Util.alpha(root.foreground, 0.07)
                      : isSelected ? Util.alpha(root.accent, 0.12) : "transparent"

                    MouseArea {
                      id: rowMouse
                      anchors.fill: parent
                      hoverEnabled: !rowItem.isQuickMix
                      cursorShape: rowItem.isQuickMix ? Qt.ArrowCursor : Qt.PointingHandCursor
                      enabled: !rowItem.isQuickMix && !root.deletingPlaylists
                      onClicked: root.togglePlaylist(rowItem.modelData.id)
                    }

                    RowLayout {
                      anchors.fill: parent
                      anchors.leftMargin: Style.space(10)
                      anchors.rightMargin: Style.space(10)
                      spacing: Style.space(12)

                      Rectangle {
                        Layout.preferredWidth: Style.space(20)
                        Layout.preferredHeight: Style.space(20)
                        radius: Style.space(5)
                        color: rowItem.isQuickMix
                          ? Util.alpha(root.muted, 0.1)
                          : rowItem.isSelected ? root.accent : "transparent"
                        border.width: 1.5
                        border.color: rowItem.isQuickMix
                          ? Util.alpha(root.muted, 0.25)
                          : rowItem.isSelected ? root.accent : root.muted

                        Text {
                          anchors.centerIn: parent
                          text: rowItem.isQuickMix ? "󰌾" : "󰄬"
                          color: rowItem.isQuickMix ? root.muted : "#000000"
                          font.family: Style.font.family
                          font.pixelSize: Style.space(12)
                          font.weight: Font.Bold
                          visible: rowItem.isQuickMix || rowItem.isSelected
                        }
                      }

                      Text {
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
                        text: rowItem.modelData.name || "Station"
                        color: rowItem.isQuickMix ? root.muted : root.foreground
                        font.family: root.displayFamily
                        font.pixelSize: Style.font.body
                        font.weight: rowItem.isSelected ? Font.DemiBold : Font.Normal
                        elide: Text.ElideRight
                      }

                      Rectangle {
                        visible: rowItem.isQuickMix
                        Layout.preferredHeight: Style.space(22)
                        Layout.preferredWidth: qmLabel.implicitWidth + Style.space(14)
                        radius: height / 2
                        color: Util.alpha(root.muted, 0.12)

                        Text {
                          id: qmLabel
                          anchors.centerIn: parent
                          text: "Default"
                          color: root.muted
                          font.family: root.displayFamily
                          font.pixelSize: Style.font.caption
                        }
                      }
                    }
                  }
                }

                Text {
                  visible: root.filteredStations().length === 0
                  Layout.fillWidth: true
                  Layout.topMargin: Style.space(20)
                  Layout.bottomMargin: Style.space(20)
                  horizontalAlignment: Text.AlignHCenter
                  textFormat: Text.PlainText
                  text: root.playlistFilter ? "No playlists matching \"" + root.playlistFilter + "\"" : "No playlists found."
                  color: root.muted
                  font.family: root.displayFamily
                  font.pixelSize: Style.font.body
                }
              }
            }
          }

          Text {
            Layout.fillWidth: true
            visible: text !== ""
            textFormat: Text.PlainText
            text: root.playlistMessage
            color: root.playlistMessageFailed ? Commons.Color.urgent : root.accentAlt
            font.family: root.displayFamily
            font.pixelSize: Style.font.body
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(10)

            Button {
              visible: !root.confirmDelete
              text: root.deletingPlaylists
                ? "Deleting playlists…"
                : root.selectedCount > 0 ? "Delete selected (" + root.selectedCount + ")" : "Delete selected playlists"
              enabled: root.selectedCount > 0 && !root.deletingPlaylists
              foreground: root.selectedCount > 0 ? Commons.Color.urgent : root.muted
              accent: Commons.Color.urgent
              background: root.selectedCount > 0 ? Util.alpha(Commons.Color.urgent, 0.15) : "transparent"
              bordered: true
              focusable: true
              radius: Style.space(8)
              onClicked: root.confirmDelete = true
            }

            RowLayout {
              visible: root.confirmDelete
              Layout.fillWidth: true
              spacing: Style.space(10)

              Text {
                textFormat: Text.PlainText
                text: "Permanently delete " + root.selectedCount + " playlist" + (root.selectedCount > 1 ? "s" : "") + " from Pandora?"
                color: Commons.Color.urgent
                font.family: root.displayFamily
                font.pixelSize: Style.font.body
                font.weight: Font.DemiBold
              }

              Button {
                text: root.deletingPlaylists ? "Deleting…" : "Yes, delete"
                enabled: !root.deletingPlaylists
                foreground: "#ffffff"
                accent: Commons.Color.urgent
                background: Commons.Color.urgent
                bordered: true
                focusable: true
                radius: Style.space(8)
                onClicked: root.executeDelete()
              }

              Button {
                text: "Cancel"
                enabled: !root.deletingPlaylists
                foreground: root.foreground
                accent: root.accentAlt
                focusable: true
                bordered: true
                radius: Style.space(8)
                onClicked: root.confirmDelete = false
              }
            }
          }
        }
      }
    }

    DeckSurface {
      objectName: "appUpdates"
      visible: !!root.updater
      Layout.columnSpan: layout.columns
      Layout.fillWidth: true
      Layout.preferredHeight: updates.implicitHeight + Style.space(42)
      baseColor: root.formSurface
      accent: root.accent
      themed: true
      emphasized: !!(root.updater && root.updater.updateAvailable)
      radius: Style.space(15)

      ColumnLayout {
        id: updates
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(21)
        spacing: Style.space(10)

        CardHeading {
          Layout.fillWidth: true
          title: "App updates"
          symbol: "󰚰"
          tone: root.accent
        }

        Text {
          Layout.fillWidth: true
          textFormat: Text.PlainText
          text: root.updater && root.updater.currentVersion
            ? "Installed version " + root.updater.currentVersion : ""
          color: root.muted
          font.family: root.displayFamily
          font.pixelSize: Style.font.bodySmall
        }

        Text {
          Layout.fillWidth: true
          visible: text !== ""
          textFormat: Text.PlainText
          text: root.updater ? root.updater.message : ""
          color: root.updater && root.updater.failed ? Commons.Color.urgent : root.foreground
          font.family: root.displayFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)

          Button {
            text: "Check for updates"
            enabled: !!(root.updater && root.updater.currentVersion && !root.updater.busy)
            foreground: root.foreground
            accent: root.accent
            focusable: true
            bordered: true
            onClicked: root.updater.check()
          }

          Button {
            visible: !!(root.updater && root.updater.updateAvailable)
            enabled: visible && !root.updater.busy
            text: "Update"
            foreground: root.foreground
            accent: root.accent
            focusable: true
            bordered: true
            background: Util.alpha(root.accent, 0.17)
            onClicked: root.updater.install()
          }
        }

        Button {
          text: root.updater && root.updater.automaticChecks
            ? "Automatic checks on" : "Automatic checks off"
          enabled: !!root.updater
          foreground: root.muted
          accent: root.accent
          focusable: true
          tooltipText: "Check GitHub for updates in the background"
          Accessible.checkable: true
          Accessible.checked: !!(root.updater && root.updater.automaticChecks)
          onClicked: root.updater.automaticChecks = !root.updater.automaticChecks
        }
      }
    }
  }
  component FieldLabel: Text {
    Layout.fillWidth: true
    textFormat: Text.PlainText
    color: root.foreground
    font.family: root.displayFamily
    font.pixelSize: Style.font.bodySmall
    font.weight: Font.DemiBold
  }

  component AccountField: TextField {
    id: input
    font.family: root.displayFamily
    background: BorderSurface {
      radius: Style.space(8)
      color: Qt.tint(root.formSurface, Util.alpha(root.foreground, input.activeFocus ? 0.055 : 0.028))
      borderSpec: Border.flat(Util.alpha(root.accent, input.activeFocus ? 0.59 : 0.18), 1)
    }
  }

  component CardHeading: RowLayout {
    id: heading
    required property string title
    required property string symbol
    required property color tone
    spacing: Style.space(9)

    Rectangle {
      Layout.preferredWidth: Style.space(34)
      Layout.preferredHeight: Style.space(34)
      radius: Style.space(9)
      color: Util.alpha(heading.tone, 0.13)
      border.width: 1
      border.color: Util.alpha(heading.tone, 0.25)

      OpticalGlyph {
        anchors.centerIn: parent
        width: Style.space(18)
        height: width
        text: heading.symbol
        color: heading.tone
        fontFamily: Style.font.family
        fontSize: Style.font.iconLarge
      }
    }

    Text {
      Layout.fillWidth: true
      textFormat: Text.PlainText
      text: heading.title
      color: root.foreground
      font.family: root.displayFamily
      font.pixelSize: Style.font.display
      font.weight: Font.DemiBold
      elide: Text.ElideRight
    }
  }
}
