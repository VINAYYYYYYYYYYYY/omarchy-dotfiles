import QtQuick
import qs.Commons
import qs.Commons as Commons

// Glass surfaces: drop-in replacement for qs.Ui PanelSectionHeader. A small,
// lightly tracked, muted label (theme foreground at reduced alpha).
//
// Tide (Pebble Shell): a calm sentence-case label instead of tracked capitals.
// Callers pass their labels in capitals, so the sentence case is derived here:
// the label itself goes transparent (keeping its size and baseline) and a
// twin draws "Tokens by day", "DNS provider", "Scanning Wi-Fi…".
Text {
  id: root
  property color foreground: Commons.Color.foreground
  property string fontFamily: Style.font.family
  property real fontSize: Style.font.caption + 1
  readonly property bool tide: PanelMotion.tide
  readonly property color ink: Qt.rgba(foreground.r, foreground.g, foreground.b, tide ? 0.6 : 0.55)

  function sentence(value) {
    var s = String(value || "")
    if (s === "" || s !== s.toUpperCase()) return s   // already mixed case
    var keep = ["DNS", "VPN", "IP", "IPV4", "IPV6", "LAN", "WAN", "USB", "GPU", "CPU", "AI", "MAC", "SSID", "GHZ", "MHZ"]
    var words = s.split(" ")
    for (var i = 0; i < words.length; i++) {
      var w = words[i], bare = w.replace(/[^A-Z0-9-]/g, "")
      if (bare === "WI-FI") words[i] = w.replace("WI-FI", "Wi-Fi")
      else if (bare === "GHZ" || bare === "MHZ") words[i] = w.replace(bare, bare.charAt(0) + "Hz")
      else if (keep.indexOf(bare) >= 0) words[i] = w
      else words[i] = i === 0 ? w.charAt(0) + w.slice(1).toLowerCase() : w.toLowerCase()
    }
    return words.join(" ")
  }

  textFormat: Text.PlainText
  color: tide ? "transparent" : ink
  font.family: fontFamily
  font.pixelSize: tide ? Style.space(13) : fontSize
  font.weight: tide ? Font.Medium : Font.DemiBold
  font.letterSpacing: tide ? 0 : 0.5
  font.capitalization: tide ? Font.MixedCase : Font.AllUppercase
  leftPadding: Style.space(2)
  topPadding: Math.ceil(fontSize * 0.15)

  Text {
    visible: root.tide
    x: 0
    y: 0
    width: root.width
    height: root.height
    leftPadding: root.leftPadding
    topPadding: root.topPadding
    textFormat: Text.PlainText
    text: root.sentence(root.text)
    color: root.ink
    font: root.font
    elide: root.elide
    horizontalAlignment: root.horizontalAlignment
    verticalAlignment: root.verticalAlignment
  }
}
