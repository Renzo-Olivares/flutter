# Flutter Text Debugging Playbooks

This document contains structured diagnostic workflows, coordinate space maps, and debugging playbooks for common architectural failure patterns in the Flutter text and selection subsystem.

---

## 1. Playbook: Coordinate Space & Transformation Triage

Text selection, handle positioning, and auto-scrolling in Flutter operate across **four distinct coordinate spaces**. When selection endpoints drift, handles misalign, or auto-scrolling behaves unexpectedly, map the failure to the transition between these four coordinate systems:

```
[4. Global Screen Space] (Pointer events: event.globalPosition)
       │
       ▼  box.globalToLocal(globalPosition)
[3. Viewport RenderBox Local Space] (Scrollable bounds, padding, insets)
       │
       ▼  localPosition.translate(deltaToOrigin.dx, deltaToOrigin.dy)
[2. Scroll-Origin Relative Space] (_currentDragStartRelatedToOrigin, _dragTargetRelatedToScrollOrigin)
       │
       ▼  child.getTransformTo(box) / paragraph.getPositionForOffset()
[1. Glyph / Fragment Local Space] (TextPosition, SelectionPoint, InlineSpan metrics)
```

---

### The 4 Coordinate Spaces Explained

| Coordinate Space | Key Types & APIs | Purpose & Architectural Role |
| :--- | :--- | :--- |
| **1. Glyph / Fragment Local** | `RenderParagraph`<br>`_SelectableFragment`<br>`TextPosition`<br>`SelectionPoint` | Layout-level metrics of individual text runs and glyph bounding boxes (`TextBox`). Unaware of scrolling or screen viewport boundaries. |
| **2. Scroll-Origin Relative** | `_getDeltaToScrollOrigin()`<br>`_currentDragStartRelatedToOrigin`<br>`_dragTargetRelatedToScrollOrigin` | Canonical document space adjusted by current scroll offset. Ensures selection endpoints stay anchored to document text content as the viewport scrolls beneath them. |
| **3. Viewport RenderBox Local** | `ScrollableState.context.findRenderObject()`<br>`RenderBox.size`<br>`box.globalToLocal()` | The visible boundary of the container/viewport on screen. Determines clipping, hit-testing, and inner proximity thresholds. |
| **4. Global Screen** | `SelectionEdgeUpdateEvent.globalPosition`<br>`PointerEvent.position`<br>`MatrixUtils.transformRect(transform, ...)` | Physical screen coordinates reported by the engine/gestures. Bounded by physical display edges on mobile devices. |

---

### Step-by-Step Diagnostic Workflow

When debugging text selection or scrolling anomalies:

1. **Identify the Failing Coordinate Transition**:
   - *Is the selection endpoint moving relative to document text during scroll?* Coordinates are likely being cached in **Global Space** or **Viewport Local Space** rather than canonical **Scroll-Origin Relative Space** (missing `_getDeltaToScrollOrigin`).
   - *Are handles or carets detached from text?* Check if intermediate layer transforms (e.g. `Transform.scale`, `RotatedBox`, `LeaderLayer`) are being omitted when converting fragment local positions to global overlay space.
   - *Does edge interaction fail on bounded screens?* Check if the algorithm assumes pointer coordinates can physically exceed viewport boundaries rather than evaluating proximity within the viewport local coordinate space.

2. **Verify Coordinate Invariants**:
   - **Boundary Clamping**: Selection originating outside a container (`_selectionStartsInScrollable == false`) must clamp coordinates to `0.0` or `Offset.infinite` to select the entire container. Selection originating inside must not clamp, preserving fine-grained drag coordinates.
   - **Origin Tracking**: As scroll offsets change, relative delta vectors update. Fixed points in scroll-origin space naturally shift relative to the viewport origin, allowing physics-based scrollers to decelerate and halt without manual timer manipulation.

3. **Resolve Geometry at the Geometry Layer**:
   - Fix coordinate calculation and transformation logic directly in layout/event delegates.
   - Avoid introducing cross-widget state or lifecycle listeners to force-terminate animations caused by distorted geometry.


