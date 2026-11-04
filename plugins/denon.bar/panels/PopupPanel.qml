import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons

// User-owned adapter for the KeyboardPanel API. All adapters share one host.
Item {
  id: root
  required property Item anchorItem
  required property QtObject bar
  property var owner: null
  property int margin: 16
  property int gap: 16
  property int padding: Style.spacing.popupPadding
  property int contentWidth: Style.space(280)
  property int contentHeight: Style.space(200)
  property var borderSpec: Border.surfaceSpec("popups", "border", Commons.Color.popups.border, Math.max(1, Style.space(2)))
  property bool centerOnBar: false
  property bool open: false
  property Item focusTarget: null
  property bool popoutSwitching: false
  property bool popoutSwitchClosing: false
  readonly property var coordinatorKey: owner || root
  readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null
  readonly property var popupScreen: anchorWindow ? anchorWindow.screen : null
  readonly property string barPos: bar ? bar.position : "top"
  // Pebble Shell (denon.shell): panels become drawers attached to the rail,
  // flush against it, joined by concave necks. Off for every other bar.
  readonly property var shellBar: PanelMotion.bar && PanelMotion.bar.shellMode === true ? PanelMotion.bar : null
  readonly property bool attached: !!shellBar && (barPos === "left" || barPos === "right")
  readonly property int neck: 18
  // "card": a drawer at its icon. "fan": a quarter circle grown out of the
  // rail's bottom corner (the control corner), contentWidth = its radius.
  property string shape: "card"
  readonly property int frameInset: attached ? shellBar.frameThickness : 0
  readonly property real screenW: popupScreen ? popupScreen.width : 0
  readonly property real screenH: popupScreen ? popupScreen.height : 0
  readonly property real barW: anchorWindow ? anchorWindow.width : 0
  readonly property real barH: anchorWindow ? anchorWindow.height : 0
  readonly property real barX: anchorWindow ? anchorWindow.margins.left : 0
  readonly property real barY: anchorWindow ? anchorWindow.margins.top : 0
  readonly property real availableCardWidth: Math.max(120, screenW - ((barPos === "left" || barPos === "right") ? barW + barX + gap + margin : margin * 2))
  readonly property real availableCardHeight: Math.max(120, screenH - ((barPos === "top" || barPos === "bottom") ? barH + (barPos === "top" ? barY : anchorWindow ? anchorWindow.margins.bottom : 0) + gap + margin : margin * 2))
  readonly property real verticalContentInset: padding * 2 + Border.top(borderSpec) + Border.bottom(borderSpec)
  readonly property Item body: bodyItem
  default property alias contentItem: bodyItem.data

  function fittedContentWidth(width, cap) {
    return Math.round(Math.min(Math.max(1, Number(width) || 1), availableCardWidth, Number(cap) > 0 ? Number(cap) : Infinity))
  }
  function fittedContentHeight(height, cap) {
    return Math.round(Math.min(Math.max(verticalContentInset, (Number(height) || 0) + verticalContentInset), availableCardHeight, Number(cap) > 0 ? Number(cap) : Infinity))
  }
  function cappedContentHeight(height) { return Math.round(Math.min(Math.max(padding * 2, Number(height) || padding * 2), availableCardHeight)) }
  function close() {
    if (owner && typeof owner.close === "function") owner.close()
    else root.open = false
  }
  function park() { bodyItem.parent = parking; bodyItem.enabled = false }

  TransformWatcher {
    id: watcher
    a: root.anchorWindow ? root.anchorWindow.contentItem : null
    b: root.anchorItem
  }
  readonly property point cardOrigin: {
    watcher.transform
    if (!anchorItem || !anchorWindow) return Qt.point(margin, margin)
    var p = anchorItem.mapToItem(anchorWindow.contentItem, 0, 0)
    if (attached && shape === "fan")
      return Qt.point(Math.round(barPos === "left" ? barW : screenW - barW - contentWidth), Math.round(screenH - frameInset - contentHeight))
    if (attached) {
      // Flush to the rail; centred on the icon but kept clear of the frame
      // so both necks land in the open screen area.
      var ax = barPos === "left" ? barW : screenW - barW - contentWidth
      var ay = p.y + anchorItem.height / 2 - contentHeight / 2
      var lo = frameInset + neck, hi = screenH - frameInset - neck - contentHeight
      return Qt.point(Math.round(ax), Math.round(Math.max(lo, Math.min(ay, hi))))
    }
    var x = barX + p.x + anchorItem.width / 2 - contentWidth / 2
    var y = barY + barH + gap
    if (barPos === "bottom") y = screenH - anchorWindow.margins.bottom - barH - contentHeight - gap
    if (barPos === "left" || barPos === "right") {
      x = barPos === "left" ? barX + barW + gap : screenW - anchorWindow.margins.right - barW - contentWidth - gap
      y = barY + p.y + anchorItem.height / 2 - contentHeight / 2
    }
    if (centerOnBar) {
      if (barPos === "top" || barPos === "bottom") x = screenW / 2 - contentWidth / 2
      else y = screenH / 2 - contentHeight / 2
    }
    return Qt.point(Math.round(Math.max(margin, Math.min(x, screenW - contentWidth - margin))), Math.round(Math.max(margin, Math.min(y, screenH - contentHeight - margin))))
  }
  onOpenChanged: {
    if (open) {
      PanelMotion.show(root)
      if (bar) bar.requestPopout(coordinatorKey)
    } else {
      PanelMotion.hide(root)
      if (bar && bar.activePopout === coordinatorKey) bar.releasePopout(coordinatorKey)
    }
  }
  Component.onDestruction: {
    PanelMotion.hide(root)
    if (PanelMotion.host) PanelMotion.host.forget(root)
  }
  Item {
    id: parking
    // Preserve layout while parked: inherited visible=false makes Texts
    // whose height depends on visibility collapse and reflow on every switch.
    opacity: 0
    enabled: false
    // ...and park it far off-screen. Qt Quick still delivers hover to
    // invisible and disabled items, so a closed drawer's buttons, parked at
    // the icon's origin, silently ate the pointer over the rail (the tray's
    // arrow and Snip were dead until their drawer had opened once).
    x: -100000
    y: -100000
    Item {
      id: bodyItem
      width: Math.max(1, root.contentWidth - root.padding * 2 - Border.left(root.borderSpec) - Border.right(root.borderSpec))
      height: Math.max(1, root.contentHeight - root.verticalContentInset)
    }
  }
}
