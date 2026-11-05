// User-owned notification surface, shared by live toasts and history replays.
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Commons as Commons
import "../NotificationLogic.js" as NotificationLogic

Item {
  id: root

  property string app: ""
  property string appIcon: ""
  property string summary: ""
  property string body: ""
  property string image: ""
  property string glyph: ""
  property int urgency: 1
  property double timestamp: 0
  property int cornerRadius: 0
  property string fontFamily: ""
  property string uiFontFamily: "Adwaita Sans"
  property real entrance: 0
  // Omarchy 4.5 `--action` button labels, in order (empty on 4.0.6 senders).
  property var actionLabels: []
  // The keyboard-mode selection (`notifications keyboard`): accent edge, and
  // the buttons show their number keys.
  property bool selected: false
  readonly property bool hovered: hoverTracker.hovered
  readonly property bool lightTheme: Commons.Color.background.hslLightness > 0.55
  readonly property color surfaceColor: Commons.Color.notifications.background
  readonly property color titleColor: Commons.Color.notifications.text
  readonly property color edgeColor: Commons.Color.notifications.border
  readonly property color bodyColor: Qt.rgba(titleColor.r, titleColor.g, titleColor.b, 0.84)
  readonly property color captionColor: Qt.rgba(titleColor.r, titleColor.g, titleColor.b, 0.56)
  readonly property color iconTint: urgency === 2 ? Commons.Color.urgent : Commons.Color.accent
  readonly property string sanitizedBody: NotificationLogic.sanitizeBody(body, app, appIcon)
  readonly property string styledBody: NotificationLogic.styledBody(body, app, appIcon)
  readonly property string smallIconSource: image.length > 0 ? image : iconSource(appIcon)
  readonly property bool hasSmallIcon: smallIconSource.length > 0 && iconImage.status !== Image.Error
  readonly property string appLabel: {
    var name = String(app || "").trim()
    if (!name || name === "notify-send" || name === "omarchy-action") return "Omarchy"
    return name.charAt(0).toUpperCase() + name.slice(1)
  }
  readonly property string timeLabel: timestamp > 0 && Date.now() - timestamp > 60000
    ? Qt.formatDateTime(new Date(timestamp), "h:mm AP") : "now"

  signal closeRequested()
  signal cardClicked()
  signal actionClicked(int index)

  function iconSource(icon) {
    var value = String(icon || "")
    if (!value.length) return ""
    if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
    if (value.charAt(0) === "/") return Util.fileUrl(value)
    return Quickshell.iconPath(value, true)
  }

  implicitWidth: Style.space(300)
  implicitHeight: Math.max(Style.space(52), contentRow.implicitHeight + Style.space(20))
  opacity: entrance
  transform: Translate { x: (1 - root.entrance) * Style.space(18) }
  Component.onCompleted: entrance = 1
  Behavior on entrance { NumberAnimation { duration: 230; easing.type: Easing.OutCubic } }

  Rectangle {
    id: material
    anchors.fill: parent
    radius: Style.space(14)
    color: root.surfaceColor
    border.width: 1 / Screen.devicePixelRatio
    border.color: root.selected
      ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.85)
      : Qt.rgba(root.edgeColor.r, root.edgeColor.g, root.edgeColor.b, root.edgeColor.a * (root.hovered ? 0.55 : 0.30))
    layer.enabled: true
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: Qt.rgba(0, 0, 0, root.lightTheme ? 0.16 : 0.32)
      shadowBlur: 0.75
      shadowVerticalOffset: 5
      blurMax: 20
      autoPaddingEnabled: true
    }
    Behavior on border.color { ColorAnimation { duration: 140 } }
  }

  HoverHandler { id: hoverTracker }
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) root.closeRequested()
      else root.cardClicked()
    }
  }

  RowLayout {
    id: contentRow
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.space(10)
    spacing: Style.space(9)

    Rectangle {
      id: iconTile
      Layout.preferredWidth: Style.space(26)
      Layout.preferredHeight: Style.space(26)
      Layout.alignment: Qt.AlignTop
      radius: Style.space(7)
      color: Qt.rgba(root.iconTint.r, root.iconTint.g, root.iconTint.b, root.hasSmallIcon ? 0.06 : 0.15)
      border.width: 1 / Screen.devicePixelRatio
      border.color: Qt.rgba(root.titleColor.r, root.titleColor.g, root.titleColor.b, 0.06)

      Image {
        id: iconImage
        anchors.fill: parent
        anchors.margins: Style.space(4)
        source: root.smallIconSource
        sourceSize.width: width * Screen.devicePixelRatio
        sourceSize.height: height * Screen.devicePixelRatio
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        visible: status === Image.Ready
      }
      Text {
        anchors.centerIn: parent
        visible: iconImage.status !== Image.Ready
        text: root.glyph.length ? root.glyph : "󰂚"
        textFormat: Text.PlainText
        font.family: "Symbols Nerd Font"
        font.pixelSize: Style.space(14)
        color: root.iconTint
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.space(3)

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)
        Text {
          Layout.fillWidth: true
          text: root.summary.length ? root.summary : root.appLabel
          textFormat: Text.PlainText
          font.family: root.uiFontFamily
          font.pixelSize: Style.space(12)
          font.weight: Font.DemiBold
          color: root.titleColor
          elide: Text.ElideRight
          maximumLineCount: 1
        }
        Rectangle {
          visible: root.urgency === 2
          Layout.preferredWidth: Style.space(5)
          Layout.preferredHeight: Style.space(5)
          radius: width / 2
          color: Commons.Color.urgent
        }
        Item {
          Layout.preferredWidth: Math.max(Style.space(18), timeText.implicitWidth)
          Layout.preferredHeight: Style.space(14)
          Text {
            id: timeText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.timeLabel
            textFormat: Text.PlainText
            font.family: root.uiFontFamily
            font.pixelSize: Style.space(10)
            color: root.captionColor
            opacity: root.hovered ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 120 } }
          }
          Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(18)
            height: width
            radius: width / 2
            color: Qt.rgba(root.titleColor.r, root.titleColor.g, root.titleColor.b, dismissMouse.containsMouse ? 0.16 : 0.08)
            opacity: root.hovered ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
            Text {
              anchors.centerIn: parent
              text: "×"
              font.family: root.uiFontFamily
              font.pixelSize: Style.space(14)
              color: root.bodyColor
            }
            MouseArea {
              id: dismissMouse
              anchors.fill: parent
              hoverEnabled: true
              enabled: root.hovered
              cursorShape: Qt.PointingHandCursor
              onClicked: root.closeRequested()
            }
          }
        }
      }

      Text {
        Layout.fillWidth: true
        visible: root.sanitizedBody.length > 0
        text: root.styledBody
        textFormat: Text.StyledText
        font.family: root.uiFontFamily
        font.pixelSize: Style.space(11)
        color: root.bodyColor
        wrapMode: Text.WordWrap
        elide: Text.ElideRight
        maximumLineCount: 2
        lineHeight: 1.15
      }

      // `omarchy-notification-send --action` buttons. Declared after the
      // card-wide MouseArea, so a press here never also clicks the card.
      RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Style.space(4)
        visible: root.actionLabels.length > 0
        spacing: Style.space(6)

        Repeater {
          model: root.actionLabels

          Rectangle {
            id: actionButton
            required property int index
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(24)
            radius: Style.space(8)
            color: Qt.rgba(root.titleColor.r, root.titleColor.g, root.titleColor.b, actionMouse.containsMouse ? 0.16 : 0.08)
            border.width: 1 / Screen.devicePixelRatio
            border.color: Qt.rgba(root.titleColor.r, root.titleColor.g, root.titleColor.b, 0.08)
            Behavior on color { ColorAnimation { duration: 120 } }

            Row {
              anchors.centerIn: parent
              spacing: Style.space(5)

              Text {
                id: actionHint
                visible: root.selected && actionButton.index < 9
                text: String(actionButton.index + 1)
                textFormat: Text.PlainText
                font.family: root.uiFontFamily
                font.pixelSize: Style.space(11)
                font.weight: Font.Bold
                color: Commons.Color.accent
              }
              Text {
                id: actionLabel
                // Measured apart from the label, never its own implicitWidth,
                // which would bind the width to itself.
                readonly property real room: actionButton.width - Style.space(10)
                  - (actionHint.visible ? actionHint.implicitWidth + Style.space(5) : 0)
                width: Math.max(0, Math.min(Math.ceil(actionMetrics.advanceWidth), room))
                text: String(actionButton.modelData || "")
                textFormat: Text.PlainText
                font.family: root.uiFontFamily
                font.pixelSize: Style.space(11)
                font.weight: Font.Medium
                color: actionMouse.containsMouse ? root.titleColor : root.bodyColor
                elide: Text.ElideRight
                maximumLineCount: 1
              }
            }

            TextMetrics { id: actionMetrics; font: actionLabel.font; text: actionLabel.text }

            MouseArea {
              id: actionMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.actionClicked(actionButton.index)
            }
          }
        }
      }
    }
  }
}
