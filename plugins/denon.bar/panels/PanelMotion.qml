pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
  id: motion
  property var bar: null
  // Pebble Shell's "Tide" card language (light numbers, hairline tracks, no
  // boxes inside boxes). On only while denon.shell is the bar.
  readonly property bool tide: !!(bar && bar.shellMode === true)
  property var host: null
  property var active: null
  property var hoverSlot: null
  // Icon under the pointer while the overlay covers the bar (it steals hover).
  property var pointerSlot: null
  property bool hoverOpening: false
  property bool hoverSession: false
  // Panel just closed from its own icon: don't hover-reopen it until the pointer leaves.
  property var suppressOwner: null
  property Component hostComponent: Component { PanelHost {} }
  // Build the (still hidden) host window soon after the bar loads, so the
  // first hover after login doesn't pay for window creation mid-animation.
  onBarChanged: if (bar && !host) prewarm.restart()
  property Timer prewarm: Timer {
    interval: 1200
    onTriggered: if (!motion.host) motion.host = motion.hostComponent.createObject(null)
  }

  function isPanel(slot) {
    var item = slot ? slot.activeItem : null
    return item && item.visible && typeof item.open === "function" && typeof item.close === "function" && item.opened !== undefined
  }
  // Hover targets: things inside one bar module that open their own drawer
  // (tray icons, the tray's arrow). They register here so the open drawer's
  // overlay, which covers the bar, can still hand them the pointer.
  // A target needs `hoverReady` (bool) and `openHover()`.
  property var hoverTargets: []
  property var pendingTarget: null
  function registerHoverTarget(t) { if (t && hoverTargets.indexOf(t) < 0) hoverTargets = hoverTargets.concat([t]) }
  function unregisterHoverTarget(t) {
    hoverTargets = hoverTargets.filter(function(x) { return x !== t })
    if (pendingTarget === t) { pendingTarget = null; targetTimer.stop() }
  }
  function hoverTargetAt(screenName, px, py) {
    if (!bar || bar.barHidden || bar.barDragSource) return null
    for (var i = hoverTargets.length - 1; i >= 0; --i) {
      var t = hoverTargets[i]
      if (!t || !t.visible || !t.hoverReady || t.width <= 0 || t.height <= 0) continue
      var win = t.QsWindow.window
      if (!win || !win.screen || win.screen.name !== screenName) continue
      var p = win.contentItem.mapFromItem(t, 0, 0)
      var x = p.x + win.margins.left, y = p.y + win.margins.top
      if (px >= x && px <= x + t.width && py >= y && py <= y + t.height) return t
    }
    return null
  }
  function queueTarget(t) {
    closeTimer.stop()
    // Already queued and still counting down: nothing to do. (A pending entry
    // whose timer is no longer running is stale and must not block.)
    if (pendingTarget === t && targetTimer.running) return
    hoverSlot = null
    hoverTimer.stop()
    pendingTarget = t
    targetTimer.interval = active ? 65 : 170
    targetTimer.restart()
  }
  function cancelTarget(t) {
    if (t && pendingTarget !== t) return
    pendingTarget = null
    targetTimer.stop()
  }
  property Timer targetTimer: Timer {
    onTriggered: {
      var t = motion.pendingTarget
      motion.pendingTarget = null
      if (!t || !t.hoverReady || !motion.bar || motion.bar.barDragSource) return
      motion.hoverOpening = true
      t.openHover()
      motion.hoverOpening = false
    }
  }

  function queueHover(slot) {
    cancelTarget()
    closeTimer.stop()
    if (!isPanel(slot)) { cancelHover(); return }
    if (suppressOwner && slot.activeItem === suppressOwner) return
    suppressOwner = null
    if (hoverSlot === slot && (hoverTimer.running || slot.activeItem.opened)) return
    hoverSlot = slot
    if (slot.activeItem.opened) { hoverTimer.stop(); return }
    hoverTimer.interval = active ? 65 : 170
    hoverTimer.restart()
  }
  function cancelHover(slot) {
    if (slot && hoverSlot !== slot) return
    hoverSlot = null
    hoverTimer.stop()
  }
  function leave() {
    cancelHover()
    if (hoverSession) closeTimer.restart()
  }
  function stay() { closeTimer.stop() }
  // The bar saw the pointer really leave this icon.
  function pointerLeft(slot) { if (suppressOwner && slot && slot.activeItem === suppressOwner) suppressOwner = null }
  // A deliberate in-panel action that moves the card away from the pointer
  // (e.g. a layout change) keeps it open like a clicked-open panel.
  function pin() { hoverSession = false; closeTimer.stop() }
  // Icon pressed: a panel that hover opened stays open (hover previews, click
  // commits). Returns true when handled, so the caller skips its toggle.
  function commitHover(owner) {
    if (active && active.owner === owner && !hoverSession) { suppressOwner = owner; return false }  // about to close
    if (!hoverSession || !active || active.owner !== owner) return false
    pin()
    return true
  }
  function show(panel) {
    closeTimer.stop()
    if (!host) host = hostComponent.createObject(null)
    active = panel
    hoverSession = hoverOpening
    host.present(panel, hoverOpening)
  }
  function hide(panel) {
    if (active !== panel) return
    active = null
    pointerSlot = null
    hoverSlot = null  // not cancelHover(): keep an icon-close suppression alive
    hoverTimer.stop()
    closeTimer.stop()
    if (host) host.dismiss()
  }
  function close() { if (active) active.close() }

  function slotAt(screenName, px, py) {
    if (!bar || bar.barHidden || bar.barDragSource) return null
    for (var i = 0; i < bar.moduleSlots.length; ++i) {
      var slot = bar.moduleSlots[i]
      if (!isPanel(slot) || slot.width <= 0 || slot.height <= 0) continue
      var win = bar.slotWindow(slot)
      if (!win || !win.screen || win.screen.name !== screenName) continue
      var p = win.contentItem.mapFromItem(slot, 0, 0)
      var x = p.x + win.margins.left, y = p.y + win.margins.top
      if (px >= x && px <= x + slot.width && py >= y && py <= y + slot.height) return slot
    }
    return null
  }

  function clickTargetAt(screenName, px, py) {
    if (!bar) return null
    for (var i = bar.clickTargets.length - 1; i >= 0; --i) {
      var target = bar.clickTargets[i]
      if (!target || !target.visible || target.opacity === 0 || target.interactive === false) continue
      var win = target.QsWindow.window
      if (!win || !win.screen || win.screen.name !== screenName) continue
      var p = win.contentItem.mapFromItem(target, 0, 0)
      var x = p.x + win.margins.left, y = p.y + win.margins.top
      if (px >= x && px <= x + target.width && py >= y && py <= y + target.height) return target
    }
    return null
  }

  // Frame-time probe for tuning; idle unless enabled via `profile true` IPC.
  property bool profiling: false
  property var frameStats: ({frames: 0, over20: 0, over34: 0, max: 0, hist: []})
  function recordFrame(ms) {
    var s = frameStats
    s.frames++
    if (ms > 20) s.over20++
    if (ms > 34) { s.over34++; s.hist.push(Math.round(ms) + "@" + (active && active.owner ? active.owner.moduleName : "-")) }
    if (ms > s.max) s.max = ms
  }

  property IpcHandler diagnostics: IpcHandler {
    target: "denon.panels"
    function profile(on: bool): string {
      motion.frameStats = {frames: 0, over20: 0, over34: 0, max: 0, hist: []}
      motion.profiling = on
      return "ok"
    }
    function frames(): string { return JSON.stringify(motion.frameStats) }
    function targets(): string {
      var result = []
      if (motion.bar) for (var i = 0; i < motion.bar.moduleSlots.length; ++i) {
        var slot = motion.bar.moduleSlots[i]
        if (!motion.isPanel(slot)) continue
        var win = motion.bar.slotWindow(slot)
        if (!win || !win.screen) continue
        var p = win.contentItem.mapFromItem(slot, 0, 0)
        result.push({id: slot.moduleName, screen: win.screen.name, x: p.x + win.margins.left + slot.width / 2,
          y: p.y + win.margins.top + slot.height / 2, hovered: slot.hovered})
      }
      return JSON.stringify(result)
    }
    function state(): string {
      var h = motion.host
      var rect = h ? h.cardGeometry : Qt.rect(0, 0, 0, 0)
      return JSON.stringify({active: motion.active && motion.active.owner ? motion.active.owner.moduleName : "", shown: h ? h.shown : false,
        hover: motion.hoverSession, incoming: h ? h.incomingAlpha : 0, outgoing: h ? h.outgoingAlpha : 0,
        x: rect.x, y: rect.y, width: rect.width, height: rect.height,
        focus: h ? h.focusEnabled : false, pending: motion.hoverSlot ? motion.hoverSlot.moduleName : "", waiting: motion.hoverTimer.running})
    }
  }

  property Timer hoverTimer: Timer {
    onTriggered: {
      var slot = motion.hoverSlot
      if (!motion.isPanel(slot) || slot.activeItem.opened || !motion.bar || motion.bar.barDragSource) return
      motion.hoverOpening = true
      slot.activeItem.open()
      // Clock/weather instantiate their panel with a synchronous Loader.
      motion.hoverOpening = false
    }
  }
  property Timer closeTimer: Timer {
    interval: 320
    onTriggered: if (motion.hoverSession && motion.host && !motion.host.cardHovered) motion.close()
  }
}
