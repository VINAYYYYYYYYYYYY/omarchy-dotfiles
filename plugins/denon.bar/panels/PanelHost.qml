import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

PanelWindow {
  id: host
  property var panel: null
  property var outgoing: null
  property bool shown: false
  property bool ready: false
  property bool focusEnabled: false
  property bool focusPrimed: false
  property real reveal: 0
  property real incomingAlpha: 1
  property real outgoingAlpha: 0
  readonly property bool cardHovered: cardHover.hovered
  readonly property rect cardGeometry: Qt.rect(card.x, card.y, card.width, card.height)
  // Pebble Shell drawers (see PopupPanel.attached): the card is drawn as part
  // of the shell, a flat rail side with concave necks into the rail.
  readonly property bool attached: !!(panel && panel.attached)
  readonly property bool railLeft: !panel || panel.barPos !== "right"
  readonly property bool fan: attached && panel.shape === "fan"
  readonly property color drawerColor: attached && panel.shellBar ? panel.shellBar.shellSurface : "transparent"
  screen: panel ? panel.popupScreen : null
  visible: shown || reveal > 0
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  anchors { top: true; bottom: true; left: true; right: true }
  WlrLayershell.namespace: "denon-bar-panel"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: shown && focusEnabled ? (focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None

  function primeFocus() {
    focusEnabled = true
    focusPrimed = false
    focusTimer.restart()
    Qt.callLater(function() { if (host.shown && host.panel && host.panel.focusTarget) host.panel.focusTarget.forceActiveFocus() })
  }
  function releaseOutgoing() {
    if (outgoing && outgoing !== panel) outgoing.park()
    outgoing = null
  }
  function present(next, hover) {
    var switching = shown && panel && panel !== next && screen === next.popupScreen
    contentFade.stop()
    releaseOutgoing()
    if (panel && panel !== next) {
      if (switching) {
        outgoing = panel
        outgoing.body.parent = oldContent
        outgoing.body.enabled = false
      } else panel.park()
    }
    if (!switching) ready = false
    panel = next
    next.body.parent = newContent
    next.body.visible = true
    next.body.enabled = true
    incomingAlpha = switching ? 0 : 1
    outgoingAlpha = switching ? 1 : 0
    if (switching) contentFade.start()
    shown = true
    reveal = 1
    Qt.callLater(function() { host.ready = true })
    if (!hover) primeFocus()
    else if (!switching) { focusEnabled = false; focusTimer.stop() }
    else if (focusEnabled) Qt.callLater(function() { if (host.panel && host.panel.focusTarget) host.panel.focusTarget.forceActiveFocus() })
  }
  function dismiss() {
    shown = false
    reveal = 0
    focusEnabled = false
    focusTimer.stop()
  }
  function forget(removed) {
    if (outgoing === removed) outgoing = null
    if (panel !== removed) return
    contentFade.stop()
    panel = null
    shown = false
    reveal = 0
  }
  onBackingWindowVisibleChanged: if (backingWindowVisible && shown && focusEnabled) primeFocus()
  // Open eases out and slightly longer; close is quicker and accelerates away.
  Behavior on reveal {
    enabled: !!host.panel
    // Drawers spring out of the rail (overshoot, then settle); cards ease.
    NumberAnimation {
      duration: host.attached ? (host.shown ? 420 : 150) : (host.shown ? 220 : 140)
      easing.type: host.shown ? (host.attached ? Easing.OutBack : Easing.OutQuint) : Easing.InCubic
      easing.overshoot: 1.25
    }
  }
  FrameAnimation {
    running: PanelMotion.profiling
    onTriggered: if (frameTime > 0) PanelMotion.recordFrame(frameTime * 1000)
  }
  Timer { id: focusTimer; interval: 75; onTriggered: host.focusPrimed = true }
  ParallelAnimation {
    id: contentFade
    NumberAnimation { target: host; property: "incomingAlpha"; to: 1; duration: 180; easing.type: Easing.OutCubic }
    NumberAnimation { target: host; property: "outgoingAlpha"; to: 0; duration: 120; easing.type: Easing.OutCubic }
    onFinished: host.releaseOutgoing()
  }

  MouseArea {
    id: overlayPointer
    property bool overTarget: false
    anchors.fill: parent
    enabled: host.shown
    hoverEnabled: true
    acceptedButtons: Qt.AllButtons
    cursorShape: overTarget ? Qt.PointingHandCursor : Qt.ArrowCursor
    function track(px, py) {
      var name = host.screen ? host.screen.name : ""
      var slot = PanelMotion.slotAt(name, px, py)
      PanelMotion.pointerSlot = slot
      overTarget = !!slot || (host.panel && py <= host.panel.barY + host.panel.barH && !!PanelMotion.clickTargetAt(name, px, py))
      if (slot) { PanelMotion.queueHover(slot); return }
      // Tray icons and other in-module targets open their own drawer.
      var target = PanelMotion.hoverTargetAt(name, px, py)
      if (target) { overTarget = true; PanelMotion.cancelHover(); PanelMotion.queueTarget(target); return }
      PanelMotion.cancelTarget()
      PanelMotion.cancelHover()
      // The bridge between the bar and card is deliberately safe to cross.
      if (host.panel && host.panel.barPos === "top" && px >= card.x && px <= card.x + card.width && py >= host.panel.barY && py <= card.y + card.height) PanelMotion.stay()
      else PanelMotion.leave()
    }
    onPositionChanged: function(mouse) { track(mouse.x, mouse.y) }
    // On map Qt can report an initial (0, 0) before the first motion sample.
    // Keep the opening icon selected until actual pointer movement arrives.
    onEntered: PanelMotion.stay()
    onExited: {
      PanelMotion.pointerSlot = null
      overTarget = false
      if (!cardHover.hovered) PanelMotion.leave()
    }
    onClicked: function(mouse) {
      var target = PanelMotion.clickTargetAt(host.screen ? host.screen.name : "", mouse.x, mouse.y)
      // Clicking the icon of a panel that hover opened keeps it open
      // (hover previews, click commits) instead of toggling it shut.
      var slot = PanelMotion.slotAt(host.screen ? host.screen.name : "", mouse.x, mouse.y)
      if (slot && PanelMotion.commitHover(slot.activeItem)) return
      if (target && typeof target.triggerPress === "function") {
        if (!PanelMotion.slotAt(host.screen.name, mouse.x, mouse.y)) PanelMotion.close()
        target.triggerPress(mouse.button)
      }
      else PanelMotion.close()
    }
    onWheel: function(wheel) {
      var target = PanelMotion.clickTargetAt(host.screen ? host.screen.name : "", wheel.x, wheel.y)
      if (target && typeof target.wheelMoved === "function") target.wheelMoved(wheel.angleDelta.y)
    }
  }

  // Glass surfaces: soft analytic drop shadow under the frosted card (cheap,
  // no offscreen layer, so geometry morphs stay smooth). Kept below the
  // Hyprland blur ignore_alpha so only the card itself gets frosted.
  RectangularShadow {
    visible: !host.attached
    x: card.x; y: card.y + 6 - (1 - host.reveal) * 6
    width: card.width; height: card.height
    radius: card.radius
    blur: 28
    spread: -4
    color: Qt.rgba(0, 0, 0, Commons.Color.background.hslLightness > 0.5 ? 0.14 : 0.34)
    opacity: host.reveal
  }

  // One path: neck, card with rounded outer corners, neck. Same fill as the
  // shell, so the drawer reads as the rail growing outward.
  // The control corner: a quarter circle out of the rail's bottom corner,
  // necks into the rail and into the bottom frame. Fans open with a turn.
  Shape {
    id: fanShape
    visible: host.fan
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    opacity: Math.min(1, host.reveal * 1.6)
    readonly property real fx: card.x
    readonly property real fy: card.y
    readonly property real fr: card.width
    readonly property real fn: host.panel ? host.panel.neck + 6 : 24
    transform: [
      Scale { origin.x: card.x; origin.y: card.y + card.height; xScale: 0.6 + 0.4 * host.reveal; yScale: 0.6 + 0.4 * host.reveal },
      Rotation { origin.x: card.x; origin.y: card.y + card.height; angle: -(1 - host.reveal) * 14 }
    ]
    ShapePath {
      fillColor: host.drawerColor
      strokeWidth: -1
      strokeColor: "transparent"
      startX: fanShape.fx; startY: fanShape.fy - fanShape.fn
      PathArc { x: fanShape.fx + fanShape.fn; y: fanShape.fy; radiusX: fanShape.fn; radiusY: fanShape.fn; direction: PathArc.Counterclockwise }
      PathArc { x: fanShape.fx + fanShape.fr; y: fanShape.fy + fanShape.fr - fanShape.fn; radiusX: fanShape.fr; radiusY: fanShape.fr }
      PathArc { x: fanShape.fx + fanShape.fr + fanShape.fn; y: fanShape.fy + fanShape.fr; radiusX: fanShape.fn; radiusY: fanShape.fn; direction: PathArc.Counterclockwise }
      PathLine { x: fanShape.fx; y: fanShape.fy + fanShape.fr }
      PathLine { x: fanShape.fx; y: fanShape.fy - fanShape.fn }
    }
  }

  Shape {
    id: drawerShape
    visible: host.attached && !host.fan
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    opacity: Math.min(1, host.reveal * 1.6)
    readonly property real dx: card.x
    readonly property real dy: card.y
    readonly property real dw: card.width
    readonly property real dh: card.height
    readonly property real dr: Math.min(card.radius, card.width / 2, card.height / 2)
    readonly property real dn: host.panel ? host.panel.neck : 18
    transform: [
      Scale { origin.x: host.railLeft ? card.x : card.x + card.width; origin.y: card.y + card.height / 2; xScale: 0.82 + 0.18 * host.reveal; yScale: 0.94 + 0.06 * host.reveal },
      Scale { origin.x: card.x + card.width / 2; xScale: host.railLeft ? 1 : -1 }
    ]
    ShapePath {
      fillColor: host.drawerColor
      strokeWidth: -1
      strokeColor: "transparent"
      startX: drawerShape.dx; startY: drawerShape.dy - drawerShape.dn
      PathArc { x: drawerShape.dx + drawerShape.dn; y: drawerShape.dy; radiusX: drawerShape.dn; radiusY: drawerShape.dn; direction: PathArc.Counterclockwise }
      PathLine { x: drawerShape.dx + drawerShape.dw - drawerShape.dr; y: drawerShape.dy }
      PathArc { x: drawerShape.dx + drawerShape.dw; y: drawerShape.dy + drawerShape.dr; radiusX: drawerShape.dr; radiusY: drawerShape.dr }
      PathLine { x: drawerShape.dx + drawerShape.dw; y: drawerShape.dy + drawerShape.dh - drawerShape.dr }
      PathArc { x: drawerShape.dx + drawerShape.dw - drawerShape.dr; y: drawerShape.dy + drawerShape.dh; radiusX: drawerShape.dr; radiusY: drawerShape.dr }
      PathLine { x: drawerShape.dx + drawerShape.dn; y: drawerShape.dy + drawerShape.dh }
      PathArc { x: drawerShape.dx; y: drawerShape.dy + drawerShape.dh + drawerShape.dn; radiusX: drawerShape.dn; radiusY: drawerShape.dn; direction: PathArc.Counterclockwise }
      PathLine { x: drawerShape.dx; y: drawerShape.dy - drawerShape.dn }
    }
  }

  BorderSurface {
    id: card
    x: host.panel ? host.panel.cardOrigin.x : 0
    y: host.panel ? host.panel.cardOrigin.y : 0
    width: host.panel ? host.panel.contentWidth : 1
    height: host.panel ? host.panel.contentHeight : 1
    color: host.attached ? "transparent" : Commons.Color.popups.background
    borderSpec: host.attached ? Border.none() : host.panel ? host.panel.borderSpec : Border.surfaceSpec("popups", "border", Commons.Color.popups.border, 2)
    padding: host.panel ? host.panel.padding : 14
    radius: Style.space(18)
    opacity: host.reveal
    clip: true
    // Grow out of the bar: scale from the top edge plus a short drop. As a
    // shell drawer: grow sideways out of the rail, same as drawerShape.
    transform: [
      Rotation { origin.x: 0; origin.y: card.height; angle: host.fan ? -(1 - host.reveal) * 14 : 0 }
      ,
      Scale {
        origin.x: host.attached ? (host.railLeft ? 0 : card.width) : card.width / 2
        origin.y: host.fan ? card.height : host.attached ? card.height / 2 : 0
        xScale: host.fan ? 0.6 + 0.4 * host.reveal : host.attached ? 0.82 + 0.18 * host.reveal : 0.96 + 0.04 * host.reveal
        yScale: host.fan ? 0.6 + 0.4 * host.reveal : host.attached ? 0.94 + 0.06 * host.reveal : 0.96 + 0.04 * host.reveal
      },
      Translate { y: host.attached ? 0 : -(1 - host.reveal) * 6 }
    ]
    Behavior on x { enabled: host.ready; NumberAnimation { duration: 230; easing.type: Easing.OutCubic } }
    Behavior on y { enabled: host.ready; NumberAnimation { duration: 230; easing.type: Easing.OutCubic } }
    Behavior on width { enabled: host.ready; NumberAnimation { duration: 230; easing.type: Easing.OutCubic } }
    Behavior on height { enabled: host.ready; NumberAnimation { duration: 230; easing.type: Easing.OutCubic } }
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: function(mouse) { host.primeFocus(); mouse.accepted = false } }
    HoverHandler {
      id: cardHover
      onHoveredChanged: {
        if (hovered) { PanelMotion.pointerSlot = null; overlayPointer.overTarget = false; PanelMotion.cancelHover(); PanelMotion.stay(); if (!host.focusEnabled) host.primeFocus() }
        else PanelMotion.leave()
      }
    }
    Item {
      id: oldContent
      x: card.contentLeftInset
      y: card.contentTopInset
      width: host.outgoing ? host.outgoing.body.width : 0
      height: host.outgoing ? host.outgoing.body.height : 0
      opacity: host.outgoingAlpha
    }
    Item {
      id: newContent
      x: card.contentLeftInset + (1 - host.incomingAlpha) * 6
      y: card.contentTopInset
      width: host.panel ? host.panel.body.width : 0
      height: host.panel ? host.panel.body.height : 0
      opacity: host.incomingAlpha
    }
  }

  Variants {
    model: host.shown ? Quickshell.screens : []
    delegate: Component {
      PanelWindow {
        required property var modelData
        screen: modelData
        visible: host.shown && !!host.screen && modelData.name !== host.screen.name
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.namespace: "denon-bar-panel-dismiss"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        MouseArea { anchors.fill: parent; onPressed: PanelMotion.close() }
      }
    }
  }
}
