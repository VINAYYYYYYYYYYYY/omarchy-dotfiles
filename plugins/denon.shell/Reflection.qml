pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

Rectangle {
  id: reflection
  required property var display
  required property string sampler
  required property color tint
  required property color foreground
  property bool sampling: true
  property int barBottom: 46
  property int sideGap: 16
  property var colors: []
  property string sampleStatus: "starting"
  color: "transparent"
  radius: Math.min(width, height) / 2
  antialiasing: true

  Component.onCompleted: console.log("Bar reflection loaded for", display ? display.name : "pending display")
  onSampleStatusChanged: console.log("Bar reflection:", display ? display.name : "pending display", sampleStatus)

  function luminance(c) {
    function linear(v) { return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
    return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
  }

  function reflectedColor(index) {
    if (colors.length !== 12) return Qt.rgba(tint.r, tint.g, tint.b, 0.46)
    var sample = colors[index]
    var c = Qt.rgba(sample[0] / 255 * 0.65 + tint.r * 0.35,
                    sample[1] / 255 * 0.65 + tint.g * 0.35,
                    sample[2] / 255 * 0.65 + tint.b * 0.35, 0.86)
    var fg = luminance(foreground)
    // Pull bright/dark reflections toward the theme when needed for legibility.
    for (var step = 0; step < 12; step++) {
      var bg = luminance(c)
      if ((Math.max(fg, bg) + 0.05) / (Math.min(fg, bg) + 0.05) >= 5) break
      c = Qt.rgba(c.r * 0.8 + tint.r * 0.2,
                  c.g * 0.8 + tint.g * 0.2,
                  c.b * 0.8 + tint.b * 0.2, 0.86)
    }
    return c
  }

  Timer {
    interval: 750
    repeat: true
    triggeredOnStart: true
    running: reflection.sampling && reflection.display !== null
    onTriggered: if (!sampleProcess.running) sampleProcess.running = true
  }

  Process {
    id: sampleProcess
    command: reflection.display ? ["python3", reflection.sampler,
      String(reflection.display.x), String(reflection.display.y),
      String(reflection.display.width), String(reflection.display.height),
      String(reflection.barBottom), String(reflection.sideGap)] : []
    stdout: SplitParser {
      onRead: function(line) {
        try {
          var next = JSON.parse(line)
          if (next && next.error) {
            reflection.sampleStatus = "capture unavailable: " + next.error
            reflection.colors = []
            return
          }
          if (Array.isArray(next) && (next.length === 0 || next.length === 12))
            reflection.colors = next
          reflection.sampleStatus = next.length === 12 ? "sampling live (12 regions)" : "no sample"
        } catch (error) {
          reflection.colors = []
          reflection.sampleStatus = "invalid sampler response"
        }
      }
    }
  }

  component ReflectionStop: GradientStop {
    required property int zone
    position: (zone + 0.5) / 12
    color: reflection.reflectedColor(zone)
    Behavior on color { ColorAnimation { duration: 650; easing.type: Easing.InOutSine } }
  }

  gradient: Gradient {
    orientation: Gradient.Horizontal
    ReflectionStop { zone: 0 }
    ReflectionStop { zone: 1 }
    ReflectionStop { zone: 2 }
    ReflectionStop { zone: 3 }
    ReflectionStop { zone: 4 }
    ReflectionStop { zone: 5 }
    ReflectionStop { zone: 6 }
    ReflectionStop { zone: 7 }
    ReflectionStop { zone: 8 }
    ReflectionStop { zone: 9 }
    ReflectionStop { zone: 10 }
    ReflectionStop { zone: 11 }
  }
}
