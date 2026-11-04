import QtQuick
import qs.Commons
import qs.Commons as Commons

// Glass surfaces: recessed track for segmented controls. Put a Row of
// borderless Buttons inside; the selected/active Button's theme fill reads as
// the raised thumb. Height follows the content plus `inset` on each side.
Rectangle {
  id: track
  property color foreground: Commons.Color.foreground
  property real inset: Style.space(3)
  default property alias content: holder.data
  readonly property real innerWidth: width - inset * 2
  readonly property bool lightTheme: Commons.Color.background.hslLightness > 0.5

  implicitHeight: holder.childrenRect.height + inset * 2
  radius: Style.cornerRadius
  // Tide: the track dissolves to a hairline outline; the selected option's
  // own fill still marks the choice.
  color: PanelMotion.tide ? "transparent" : lightTheme ? Qt.rgba(foreground.r, foreground.g, foreground.b, 0.06) : Qt.rgba(0, 0, 0, 0.24)
  border.width: 1
  border.color: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.08)

  Item {
    id: holder
    x: track.inset
    y: track.inset
    width: track.innerWidth
    height: childrenRect.height
  }
}
