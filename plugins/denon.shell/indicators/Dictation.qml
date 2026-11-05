import QtQuick
import Quickshell.Io
import qs.Ui

BarIndicator {
  id: root

  property string state: "idle"
  property string icon: ""

  active: state === "recording"
  activeText: icon
  inactiveText: "󰍬"
  activeTooltipText: state
  inactiveTooltipText: "Dictate"

  function update(raw) {
    var data = extractData(raw)

    state = String(data.alt || data.class || "idle")
    if (state === "recording") icon = "󰍬"
    else if (state === "transcribing") icon = "󰔟"
    else icon = ""
  }

  Process {
    // Omarchy 4.5 deleted omarchy-voxtype-status. Use it while it exists,
    // otherwise run its body: exec keeps voxtype the shell's direct child so
    // it is cleaned up when the shell restarts.
    command: ["bash", "-c",
      "if command -v omarchy-voxtype-status >/dev/null 2>&1; then exec omarchy-voxtype-status; fi; " +
      "if ! command -v voxtype >/dev/null 2>&1; then echo '{\"alt\": \"\", \"class\": \"idle\", \"tooltip\": \"\"}'; exit 0; fi; " +
      "exec setpriv --pdeathsig TERM voxtype status --follow --extended --format json"]
    running: true
    stdout: SplitParser {
      onRead: function(data) { root.update(data) }
    }
  }

  onPressed: function() {
    if (!root.bar) return
    root.bar.run("omarchy-voxtype-config")
  }
}
