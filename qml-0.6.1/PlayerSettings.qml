import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Flickable {
  id: root

  required property var account
  property var updater: null
  required property color foreground
  required property color muted
  required property color accent
  required property color accentAlt
  required property color background
  readonly property color formSurface: Qt.tint(background, Qt.rgba(0, 0, 0, 0.34))
  readonly property string displayFamily: "Adwaita Sans"
  readonly property bool formReady: account && account.ready
  readonly property bool busy: !!(account && account.busy)

  clip: true
  contentWidth: width
  contentHeight: layout.implicitHeight + Style.space(36)
  boundsBehavior: Flickable.StopAtBounds
  Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }

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
