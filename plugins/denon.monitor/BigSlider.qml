import QtQuick
import qs.Commons
import qs.Commons as Commons

// Glass surfaces (audio direction A): a thick Control-Center style slider.
// Same API as qs.Ui PanelSlider (value, liveValue, dragging, moved, released,
// rightClicked, wheel steps) plus an icon riding inside the fill and an
// optional live level strip along the bottom edge (the mic meter).
Item {
  id: root

  property QtObject bar: null
  property real value: 0
  property real minimum: 0
  property real maximum: 1
  property real step: 0.05
  property bool dragging: false
  property real liveValue: value
  property string glyph: ""
  property real level: -1          // 0..1 live meter, -1 hides it
  property bool muted: false
  property color foreground: bar ? bar.foreground : Commons.Color.foreground
  property bool compact: false     // per-app rows: thinner, no icon

  signal moved(real value)
  signal released(real value)
  signal rightClicked()

  readonly property real range: Math.max(0.0001, maximum - minimum)
  readonly property real progress: Math.max(0, Math.min(1, (liveValue - minimum) / range))
  readonly property bool lightTheme: Commons.Color.background.hslLightness > 0.5

  implicitHeight: compact ? Style.space(5) : Style.space(24)
  onValueChanged: if (!dragging) liveValue = value

  Rectangle {
    id: track
    anchors.fill: parent
    radius: root.compact ? height / 2 : Style.space(8)
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, mouseArea.containsMouse || root.dragging ? 0.1 : 0.065)
    clip: true
    Behavior on color { ColorAnimation { duration: 120 } }

    // Live input level: a faint accent wash inside the track, behind the fill.
    Rectangle {
      visible: root.level >= 0
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      radius: track.radius
      width: parent.width * Math.max(0, Math.min(1, root.level))
      color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, root.muted ? 0.08 : 0.28)
      Behavior on width { NumberAnimation { duration: 80 } }
    }

    Rectangle {
      id: fill
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: root.progress > 0 ? Math.max(track.radius * 2, parent.width * root.progress) : 0
      radius: track.radius
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, root.muted ? 0.3 : 0.78)
      Behavior on width { enabled: !root.dragging; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }

    Text {
      visible: !root.compact && root.glyph !== ""
      x: Style.space(9)
      anchors.verticalCenter: parent.verticalCenter
      text: root.glyph
      // Sits on the fill when there is fill under it, on the track otherwise.
      color: fill.width > x + width + Style.space(4) ? Commons.Color.background : root.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    // Thin per-app bars keep a comfortable grab area.
    anchors.topMargin: root.compact ? -Style.space(6) : 0
    anchors.bottomMargin: root.compact ? -Style.space(6) : 0
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    function valueFromX(x) {
      var clamped = Math.max(0, Math.min(track.width, x))
      return Math.max(root.minimum, Math.min(root.maximum, root.minimum + (clamped / track.width) * root.range))
    }

    onPressed: function(mouse) {
      if (mouse.button !== Qt.LeftButton) return
      root.dragging = true
      var next = valueFromX(mouse.x)
      root.liveValue = next
      root.moved(next)
    }
    onClicked: function(mouse) { if (mouse.button === Qt.RightButton) root.rightClicked() }
    onPositionChanged: function(mouse) {
      if (!root.dragging) return
      var next = valueFromX(mouse.x)
      root.liveValue = next
      root.moved(next)
    }
    onReleased: function(mouse) {
      if (mouse.button !== Qt.LeftButton) return
      root.dragging = false
      root.released(root.liveValue)
      root.liveValue = root.value
    }
    onWheel: function(wheel) {
      var delta = wheel.angleDelta.y > 0 ? root.step : -root.step
      var next = Math.max(root.minimum, Math.min(root.maximum, root.liveValue + delta))
      root.liveValue = next
      root.moved(next)
      root.released(next)
    }
  }
}
