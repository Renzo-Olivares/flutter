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
| **2. Scroll-Origin Relative** | `_getDeltaToScrollOrigin()`<br>`_currentDragStartRelatedToOrigin`<br>`_dragTargetRelatedToScrollOrigin` | Canonical document space adjusted by the current scroll offset. Ensures selection endpoints stay anchored to document text content as the viewport scrolls beneath them. |
| **3. Viewport RenderBox Local** | `ScrollableState.context.findRenderObject()`<br>`RenderBox.size`<br>`box.globalToLocal()` | The visible boundary of the scroll view on screen. Determines clipping, hit-testing, and inner edge-band thresholds. |
| **4. Global Screen** | `SelectionEdgeUpdateEvent.globalPosition`<br>`PointerEvent.position`<br>`MatrixUtils.transformRect(transform, ...)` | Physical screen coordinates reported by the engine/gestures. Bounded by device screen bezels on physical mobile devices. |

---

### Step-by-Step Diagnostic Workflow

When debugging text selection or scrolling anomalies:

1. **Identify the Failing Boundary**:
   - *Is the selection endpoint moving when the view scrolls?* Check if coordinates are being stored in **Global Space** instead of **Scroll-Origin Relative Space** (missing `_getDeltaToScrollOrigin`).
   - *Is edge scrolling failing on full-screen views?* Check if the delegate assumes pointers can move outside the **Viewport Local Space** when calculating overdrag (`proxyEnd > viewportEnd`), instead of projecting directional edge bands from inside the boundary.
   - *Are selection handles detached from text?* Check if `pushHandleLayers` or `LeaderLayer` transforms are accounting for intermediate render transforms (e.g. `Transform.scale`, `RotatedBox`).

2. **Verify Coordinate Invariants**:
   - **Boundary Clamping**: Selection originating outside a scrollable (`_selectionStartsInScrollable == false`) must clamp coordinates to `0.0` or `Offset.infinite` to select the entire container. Selection originating inside must not clamp, preserving fine-grained drag coordinates.
   - **Origin Tracking**: As `ScrollPosition` scrolls, `deltaToScrollOrigin` changes. Fixed points in scroll-origin space naturally shift relative to `viewportOrigin`, allowing `EdgeDraggingAutoScroller` to decelerate and halt without manual timer manipulation.

3. **Resolve Geometry at the Geometry Layer**:
   - Fix coordinate calculation and transformation logic directly in `_dragTargetFromEvent` or layout delegate methods.
   - Avoid introducing cross-widget state or lifecycle listeners (e.g. subscribing to `SelectableRegionSelectionStatusScope`) to force-terminate runaway animations caused by inflated or distorted overdrag math.

---

## 2. Common Failure Patterns & Diagnostic Trees

### Pattern A: Edge Auto-Scroller Does Not Trigger Near Viewport Edge
- **Symptom**: Dragging a selection handle or pointer near the edge of a full-screen scroll view (without `SafeArea` / `AppBar`) does not auto-scroll.
- **Root Cause**: The drag target size is `0` or uses a point comparison that requires the pointer to cross *outside* the viewport. On full-screen devices, pointers cannot leave screen bounds.
- **Fix**: In the selection container delegate, calculate directional edge bands (`math.min(edgeBand, viewportDimension / 2)`). When the pointer is within the inner band, project the drag target outward beyond the viewport boundary proportionally.

---

### Pattern B: Runaway / Distorted Auto-Scroll on Handle Release
- **Symptom**: Releasing a drag handle continues scrolling past the expected position or fails to halt.
- **Root Cause**: Symmetrical bounding boxes (e.g. `Rect.fromCenter(center: pos, width: 100, height: 100)`) add fixed extra offsets ($+50\text{ px}$) to pointers that are already outside the viewport, inflating `overDrag` and overshooting the stopping threshold.
- **Fix**: Use directional edge bands that only extend when coordinates are *inside* the inner threshold, and pass raw displacement when coordinates are already *outside*.

---

### Pattern C: Caret / Handle Jumping at Soft Line Wraps
- **Symptom**: Caret flashes or jumps to the wrong line when clicking the edge of a wrapped line.
- **Root Cause**: Missing or incorrect `TextAffinity` disambiguation.
- **Fix**: Ensure offset comparisons evaluate `TextAffinity.upstream` (trailing edge of current line) vs `TextAffinity.downstream` (leading edge of next line).

