import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Flickable {
  id: root

  required property var account
  required property color foreground
  required property color muted
  required property color accent
  required property color accentAlt
  required property color background
  property bool themed: false
  readonly property bool editing: emailField.activeFocus || passwordField.activeFocus
  readonly property bool formReady: account && account.ready
  readonly property bool busy: !!(account && account.busy)

  clip: true
  contentWidth: width
  contentHeight: layout.implicitHeight + Style.space(24)
  boundsBehavior: Flickable.StopAtBounds

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

  Column {
    id: layout
    width: Math.min(parent.width - Style.space(24), Style.space(570))
    anchors.horizontalCenter: parent.horizontalCenter
    y: Style.space(12)
    spacing: Style.space(12)

    DeckSurface {
      width: parent.width
      height: signIn.implicitHeight + Style.space(30)
      baseColor: root.background
      accent: root.accent
      themed: root.themed
      emphasized: true

      ColumnLayout {
        id: signIn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(15)
        spacing: Style.space(8)

        Text {
          Layout.fillWidth: true
          text: "Pandora account"
          textFormat: Text.PlainText
          color: root.foreground
          font.family: "Adwaita Sans"
          font.pixelSize: Math.round(Style.font.display * 1.12)
          font.weight: Font.DemiBold
        }

        Text {
          Layout.fillWidth: true
          textFormat: Text.PlainText
          text: root.account && root.account.hasStations
            ? "Connected. Saving different credentials reconnects playback."
            : "Sign in here to load your stations. Your password is saved in the desktop keyring."
          color: root.muted
          font.family: "Adwaita Sans"
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        TextField {
          id: emailField
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(40)
          enabled: root.formReady && !root.busy
          text: root.account ? root.account.email : ""
          placeholderText: "Pandora email"
          Accessible.name: "Pandora email"
          maximumLength: 320
          inputMethodHints: Qt.ImhEmailCharactersOnly | Qt.ImhNoPredictiveText
          foreground: root.foreground
          accent: root.accent
          onAccepted: passwordField.forceActiveFocus()
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(6)

          TextField {
            id: passwordField
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(40)
            enabled: root.formReady && !root.busy
            placeholderText: root.account && root.account.email ? "New password" : "Pandora password"
            Accessible.name: "Pandora password"
            password: true
            inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
            maximumLength: 4096
            foreground: root.foreground
            accent: root.accent
            onAccepted: root.submit()
          }
        }

        Button {
          text: root.busy ? "Connecting…" : passwordField.length ? "Save and connect"
            : root.account && root.account.hasStations ? "Reconnect" : "Connect"
          enabled: root.formReady && !root.busy && !root.account.changingWindow &&
            emailField.text.trim() !== "" && (passwordField.length > 0 || emailField.text.trim() === root.account.email)
          foreground: root.accent
          accent: root.accent
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
          font.family: "Adwaita Sans"
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }
      }
    }

    DeckSurface {
      width: parent.width
      height: backend.implicitHeight + Style.space(30)
      baseColor: root.background
      accent: root.accentAlt
      themed: root.themed

      ColumnLayout {
        id: backend
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(15)
        spacing: Style.space(8)

        Text {
          Layout.fillWidth: true
          text: "Playback backend"
          textFormat: Text.PlainText
          color: root.foreground
          font.family: "Adwaita Sans"
          font.pixelSize: Style.font.title * 1.18
          font.weight: Font.DemiBold
        }

        Text {
          Layout.fillWidth: true
          textFormat: Text.PlainText
          text: root.account && root.account.checked && root.account.missing.length
            ? "Setup needs " + root.account.missing.join(", ") + "."
            : "Pithos handles playback in the background. Show its window if you need its native controls."
          color: root.muted
          font.family: "Adwaita Sans"
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
      }
    }
  }
}
