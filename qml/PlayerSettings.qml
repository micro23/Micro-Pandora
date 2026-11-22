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
  readonly property color formSurface: Qt.tint(background, Qt.rgba(0, 0, 0, 0.34))
  readonly property string displayFamily: "Adwaita Sans"
  readonly property bool formReady: account && account.ready
  readonly property bool busy: !!(account && account.busy)

  clip: true
  contentWidth: width
  contentHeight: layout.implicitHeight + Style.space(36)
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

        CardHeading {
          Layout.fillWidth: true
          title: "Pandora account"
          symbol: "󰍂"
          tone: root.accent
        }

        Text {
          Layout.fillWidth: true
          textFormat: Text.PlainText
          text: root.account && root.account.hasStations
            ? "Connected. Saving different credentials reconnects playback."
            : "Sign in here to load your stations. Your password is saved in the desktop keyring."
          color: root.muted
          font.family: root.displayFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        AccountField {
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

        AccountField {
          id: passwordField
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(40)
          enabled: root.formReady && !root.busy
          placeholderText: "Pandora password"
          Accessible.name: "Pandora password"
          password: true
          inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
          maximumLength: 4096
          foreground: root.foreground
          accent: root.accent
          onAccepted: root.submit()
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
      }
    }
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
