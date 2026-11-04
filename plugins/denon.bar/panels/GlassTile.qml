import QtQuick
import qs.Commons
import qs.Commons as Commons

// Glass surfaces: inset tile that groups related stats/rows (theme foreground
// at 5% over the card). Put content inside; padding is applied by the caller.
Rectangle {
  property color foreground: Commons.Color.foreground
  radius: Math.max(6, Style.cornerRadius - Style.space(4))
  // Tide: no boxes inside boxes; the content sits straight on the drawer.
  color: PanelMotion.tide ? "transparent" : Qt.rgba(foreground.r, foreground.g, foreground.b, 0.05)
}
