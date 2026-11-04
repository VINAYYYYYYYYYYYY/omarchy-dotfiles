import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Glass surfaces: drop-in replacement for qs.Ui PanelHero (same properties).
// Icon sits in a soft accent-tinted tile, title is a calm semibold, and the
// meta line is muted sentence case instead of shouty tracked capitals. All
// colors come from the active theme.
Item {
  id: root

  property Component iconComponent: null
  property string title: ""
  property string meta: ""
  property string detail: ""
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property string fontFamily: Style.font.family
  property real iconSize: Style.font.display
  property real iconOpacity: 1.0
  property alias metaOpacity: metaText.opacity
  property bool accentIcon: true
  property Component trailingControl: null

  readonly property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.6)
  readonly property real tileSize: Style.space(36)
  readonly property real trailingInset: trailingLoader.item && trailingLoader.item.visible ? trailingLoader.width + Style.space(12) : 0

  width: parent ? parent.width : implicitWidth
  implicitHeight: Math.max(tileSize, heroLabels.implicitHeight, trailingLoader.implicitHeight)

  Rectangle {
    id: tile
    visible: root.iconComponent !== null
    width: root.tileSize
    height: root.tileSize
    radius: Style.space(10)
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    color: PanelMotion.tide ? "transparent" : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.16)
    opacity: root.iconOpacity

    Loader {
      id: iconLoader
      anchors.centerIn: parent
      sourceComponent: root.iconComponent
      // Packaged hero icons are sized for a bare 24px glyph; fit them to the tile.
      scale: item ? Math.min(1, (root.tileSize * 0.52) / Math.max(1, Math.max(item.implicitWidth, item.implicitHeight))) : 1
      onLoaded: if (root.accentIcon && item && item.color !== undefined) item.color = Qt.binding(function() { return root.accent })
    }
  }

  Column {
    id: heroLabels
    anchors.left: tile.visible ? tile.right : parent.left
    anchors.leftMargin: tile.visible ? Style.space(12) : 0
    anchors.right: parent.right
    anchors.rightMargin: root.trailingInset
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(1)

    Row {
      visible: root.title !== "" || detailText.visible
      width: parent.width
      spacing: Style.space(8)

      Text {
        id: titleText
        textFormat: Text.PlainText
        visible: root.title !== ""
        text: root.title
        width: Math.min(implicitWidth, Math.max(0, parent.width - (detailText.visible ? detailText.implicitWidth + Style.space(8) : 0)))
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: PanelMotion.tide ? Style.space(20) : Style.font.title + 1
        font.weight: PanelMotion.tide ? Font.Light : Font.DemiBold
        elide: Text.ElideRight
      }

      Text {
        id: detailText
        textFormat: Text.PlainText
        visible: root.detail !== ""
        anchors.baseline: titleText.baseline
        text: root.detail
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.weight: Font.Medium
      }
    }

    Text {
      id: metaText
      textFormat: Text.PlainText
      width: parent.width
      text: root.meta.length > 0 ? root.meta.charAt(0).toUpperCase() + root.meta.slice(1).toLowerCase() : ""
      visible: text !== ""
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall + 1
      elide: Text.ElideRight
    }
  }

  Loader {
    id: trailingLoader
    sourceComponent: root.trailingControl
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
  }
}
