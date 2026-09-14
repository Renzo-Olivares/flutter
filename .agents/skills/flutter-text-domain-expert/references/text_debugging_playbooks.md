# Flutter Text Debugging Playbooks

This document maps coordinate conversions and diagnostic checks for text selection, handle positioning, and auto-scrolling in the current implementation.

---

## 1. Playbook: Coordinate Space & Transformation Triage

Identify the coordinate type carried by each value before changing its arithmetic. Global and local positions use logical pixels. A `TextPosition` is a text offset with affinity, not a two-dimensional position; obtaining it requires a paragraph layout query.

### Coordinate Values and Their Owners

| Value / Space | Key Types & APIs | Meaning |
| :--- | :--- | :--- |
| **Global logical position** | `PointerEvent.position`, gesture details' `globalPosition`, `SelectionEdgeUpdateEvent.globalPosition` | Position in the framework's global coordinate system. `PointerEvent` itself uses `position`, not a `globalPosition` property. |
| **Viewport local position** | `box.globalToLocal(globalPosition)`, `RenderBox.size` | Position relative to the scrollable's render box. Used for viewport containment and boundary checks. |
| **Selectable / paragraph local geometry** | `SelectionPoint.localPosition`, `TextBox`, `RenderParagraph.getPositionForOffset` | A selection point is local to its owning selectable. Paragraph boxes and layout queries use paragraph-local coordinates; transform global input into the appropriate owner's space. |
| **Cached origin-adjusted coordinates** | `_currentDragStartRelatedToOrigin`, `_currentDragEndRelatedToOrigin`, `_dragTargetRelatedToScrollOrigin` | Values adjusted for scroll offset. Their concrete conversion paths differ; they are not all plain viewport-local offsets. |

The framework pointer contract is documented in [`events.dart`](../../../../packages/flutter/lib/src/gestures/events.dart). Selection conversions are implemented in [`scrollable.dart`](../../../../packages/flutter/lib/src/widgets/scrollable.dart) and [`paragraph.dart`](../../../../packages/flutter/lib/src/rendering/paragraph.dart).

### Trace the Actual Conversion Path

**Incoming edge event and delegate cache.** Let `box` be the scrollable's render box and `deltaToOrigin` be `_getDeltaToScrollOrigin(state)`. For an event that takes the ordinary, unclamped path, `_inferPositionRelatedToOrigin` performs:

```text
event.globalPosition
    → box.globalToLocal(globalPosition)
    → localPosition.translate(deltaToOrigin.dx, deltaToOrigin.dy)
    → box.localToGlobal(translatedLocalPosition)
    → _currentDragStartRelatedToOrigin / _currentDragEndRelatedToOrigin
```

`handleSelectionEdgeUpdate` then subtracts `deltaToOrigin` from that cached value and dispatches the result as another `SelectionEdgeUpdateEvent.globalPosition`. Preserve the `localToGlobal` step when tracing this implementation; removing it changes the space represented by the cache. With scaling or rotation, trace the full transforms rather than simplifying this sequence to scalar scroll-offset arithmetic.

`_getDeltaToScrollOrigin` uses the signed scroll position:

| Axis direction | Delta |
| :--- | :--- |
| `AxisDirection.down` | `Offset(0, position.pixels)` |
| `AxisDirection.up` | `Offset(0, -position.pixels)` |
| `AxisDirection.right` | `Offset(position.pixels, 0)` |
| `AxisDirection.left` | `Offset(-position.pixels, 0)` |

**Reconstructing the delegate cache from selection geometry.** After operations such as selecting a word, `_updateDragLocationsFromGeometries` starts from a child's `SelectionPoint.localPosition`. It subtracts half the line height vertically, applies `child.getTransformTo(box)` to obtain viewport-local coordinates, adds `deltaToOrigin`, and applies `box.getTransformTo(null)` to obtain the cached coordinate. `child.getTransformTo(box)` maps child coordinates toward the viewport; it is not a viewport-to-child conversion.

**Leaf text lookup.** Paragraph selection handlers invert `paragraph.getTransformTo(null)` to convert an incoming global point to paragraph-local coordinates, apply the handler's selection-rectangle adjustment, then query `paragraph.getPositionForOffset`. Check that particular handler for clamping, granularity, and affinity behavior rather than treating every text lookup as the same operation.

**Auto-scroller target cache.** `EdgeDraggingAutoScroller.startAutoScrollIfNecessary` separately caches `dragTarget.translate(deltaToOrigin.dx, deltaToOrigin.dy)`. The selection delegate passes a zero-size rect centered at the edge event's global position. In `_scroll`, the viewport is transformed to a global rect, its origin is translated by the current scroll delta, and its axis extents are compared with `_dragTargetRelatedToScrollOrigin`. See [`scrollable_helpers.dart`](../../../../packages/flutter/lib/src/widgets/scrollable_helpers.dart). Do not substitute the delegate cache's local/global recipe for this separate calculation.

---

### Step-by-Step Diagnostic Workflow

1. **Identify the failing transition.**
   - For a selection endpoint moving relative to its text during scrolling, inspect when its coordinates were captured, which origin adjustment was applied, and how the current scroll delta is removed before redispatch. Check layout-change rescheduling as well as the arithmetic.
   - For detached handles or carets, trace all transforms between the paragraph, scrollable, and overlay, including scaling, rotation, and the linked leader/follower layers.
   - For a drag that does not scroll, inspect the dispatched edge coordinate, remaining scroll extent, resolved scroll physics, and whether the selection started inside this scrollable. The current selection drag target is a point: strictly inside the viewport it does not activate auto-scroll. There is no inner proximity band.

2. **Check conditional clamping and handle offsets.**
   - `_selectionStartsInScrollable == false` enables boundary checks in `_inferPositionRelatedToOrigin`; it does not unconditionally clamp the point.
   - If the current local point has `dx < 0` or `dy < 0`, the leading result is `box.localToGlobal(Offset.zero)`.
   - Otherwise, if `dx > box.size.width` or `dy > box.size.height`, the trailing result is `Offset.infinite`.
   - If neither condition holds, use the ordinary origin-adjusted conversion, even when the selection began outside. When the selection began inside, these outside-origin clamps are skipped.
   - For handle drags, inspect the accumulated handle paint-origin position and the vertical subtraction of `lineHeight / 2` in `SelectableRegion` before comparing the event with the viewport boundary. The pointer location alone is insufficient.

3. **Trace scrolling and gesture completion separately.**
   - `SelectableRegion` repeats pending edge updates while a drag is active and finalizes that scheduling when the gesture ends.
   - `EdgeDraggingAutoScroller` advances through discrete linear `animateTo` steps. Each step uses the target/viewport geometry and remaining extent; this is not a decelerating physics simulation.
   - `stopAutoScroll` sets `_scrolling = false`; it does not cancel an already running `animateTo`. A scheduled step may complete after release. Check eventual stability and, when diagnosing a timing issue, record the offsets from release through settlement.
   - Nested scrollables can return `SelectionResult.pending`, causing the parent to stop its own auto-scroller while the child handles the event.

4. **Fix the demonstrated cause at its owner.**
   - Correct a proven coordinate-space or geometry error in the corresponding calculation or event delegate.
   - For stale scheduling, uncancelled work, or disposal problems, inspect the responsible state and lifecycle path. A geometry preference is not a reason to exclude a lifecycle fix supported by the failure.
   - Add a focused regression test for the observed behavior. The current inside/outside scrolling contract and release-settlement pattern are described in [testing_text_stack.md](testing_text_stack.md).
