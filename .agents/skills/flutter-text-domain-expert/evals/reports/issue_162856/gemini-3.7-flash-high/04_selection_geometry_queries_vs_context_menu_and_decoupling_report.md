# Evaluation Report: Edge scrolling of selection area not working when scroll view not wrapped by SafeArea (#162856)

**Target Issue**: [flutter/flutter#162856](https://github.com/flutter/flutter/issues/162856)  
**Evaluated Model**: Gemini 3.7 Flash (High)  
**Candidate A (Conversation ID)**: [`f68a330b-84b3-4853-9290-97bc94b29bf0`](conversation://f68a330b-84b3-4853-9290-97bc94b29bf0) (Commit `7bb6d97c23` - Skill v2 with SelectionGeometry queries and Section 8 edge-scrolling invariants)  
**Candidate B (Conversation ID)**: [`504604cd-8fbf-47fb-94a8-104a4b458df4`](conversation://504604cd-8fbf-47fb-94a8-104a4b458df4) (Commit `8808bf80fb` - Skill v3 with Decoupled Packages, Delegating Constructor Parity & Lifecycle Isolation)  

---

## 1. Executive Summary & Final Verdict
- **Winner Declaration**: **Candidate A (Commit `7bb6d97c23` - SelectionGeometry Queries & Section 8 Edge-Scrolling Invariants)**
- **High-Level Rationale**: 
  Candidate A achieved a score of **99/100** vs. Candidate B's **91/100**, executing the task with **35.4% fewer planner turns** (73 vs 113), **38.4% fewer tool calls** (69 vs 112), and **21.5% fewer tokens** (82.8k vs 105.5k).
  Candidate A leveraged the specialized static text pipeline reference (`references/static_text_pipeline.md`) to apply the exact `SelectionGeometry` query pattern: safely extracting `lineHeight` from the active selectable's `SelectionPoint` to calculate `lineTop` and `lineBottom` for selection handle drag events. This geometric precision allowed Candidate A to implement an axis-aware directional edge projection with a compact 20px edge band without any overscroll side-effects.
  Candidate B successfully implemented a working local-coordinate bounding box approach with a 200px target size and wrote an extensive set of 7 regression tests, but required significantly more exploratory steps and tool invocations (+54.8% steps, +62.3% tool calls) and omitted `lineHeight` compensation.

---

## 2. Comparative Scorecard Table

| Dimension | Max Pts | Candidate A (`7bb6d97c23`) | Candidate B (`8808bf80fb`) | Notes / Observations |
| :--- | :---: | :---: | :---: | :--- |
| **1. Subsystem Routing & Architectural Precision** | 20 | **20** | **17** | Candidate A queried `SelectionPoint.lineHeight` from the active `Selectable` to accurately account for the `lineHeight / 2` touch handle drag offset and projected 1D edge bands along the active axis. Candidate B used a 200px local target size with a 100px proximity radius without line-height awareness. |
| **2. Test File Placement & Organization** | 20 | **19** | **20** | Both placed tests in canonical `scrollable_selection_test.dart`. Candidate B wrote 7 comprehensive tests (forward/backward vertical & horizontal, start/end handles, small scrollable). Candidate A wrote 3 focused tests (vertical handle, vertical mouse, horizontal mouse). |
| **3. Avoidance of Flutter Text Testing Traps** | 25 | **25** | **25** | Both candidates flawlessly avoided testing traps: using `TestGesture` + `pump(Duration)` instead of hanging `pumpAndSettle()` loops, adding proper `addTearDown` handlers, and using `getBoxesForSelection` and `globalize()`. |
| **4. Code Correctness & Cleanliness** | 15 | **15** | **15** | Both candidates passed `dart analyze --fatal-infos` with 0 issues and formatted cleanly with `dart format`. Both preserved boundary safety for small scrollables. |
| **5. Search Precision & Autonomous Discovery** | 10 | **10** | **8** | Candidate A autonomously consulted `SKILL.md`, `static_text_pipeline.md`, and `testing_text_stack.md`, navigating directly to the solution. Candidate B consulted `SKILL.md` and required 25 greps and 44 bash commands. |
| **6. Quantitative Resource & Token Efficiency** | 10 | **10** | **6** | Candidate A completed the task in 73 turns (vs 113) and 82,766 tokens (vs 105,460), saving ~21.5% tokens, ~35.4% turns, and ~38.4% tool calls. |
| **Total Score** | **100** | **99** | **91** | **Candidate A wins (+8 pts)** |

### Quantitative Metrics Summary

| Metric | Candidate A (`7bb6d97c23`) | Candidate B (`8808bf80fb`) | Delta (%) |
| :--- | :---: | :---: | :---: |
| **Skill Triggered Automatically** | Yes (SKILL.md, static_text_pipeline.md, testing_text_stack.md) | Yes (SKILL.md) | — |
| **Total Planner Turns** | 73 | 113 | **+54.8%** |
| **Total Tool Calls** | 69 | 112 | **+62.3%** |
| **Estimated Tokens** | 82,766 | 105,460 | **+27.4%** |
| **Tool: `run_command`** | 21 | 44 | **+109.5%** |
| **Tool: `view_file`** | 21 | 37 | **+76.2%** |
| **Tool: `grep_search`** | 17 | 25 | **+47.1%** |
| **Distinct Files Viewed** | 8 | 7 | **-12.5%** |
| **Distinct Files Modified** | 2 (`scrollable.dart`, `scrollable_selection_test.dart`) | 2 (`scrollable.dart`, `scrollable_selection_test.dart`) | **0%** |

---

## 3. Trajectory & Behavioral Comparison

### Candidate A Investigation & Execution
- **Commit Checked Out**: `7bb6d97c23779cb315048c4c4e8d9765f7fc8646`
- **Trajectory Overview**:
  1. Candidate A read issue #162856 using `gh issue view` and loaded the `flutter-text-domain-expert` skill along with `references/static_text_pipeline.md` and `references/testing_text_stack.md`.
  2. Identified the core defect in `_ScrollableSelectionContainerDelegate._dragTargetFromEvent` where `_kDefaultDragTargetSize = 0` produced a 0x0 `Rect` at the pointer position, preventing `EdgeDraggingAutoScroller` from triggering when scrollables are not inset by `SafeArea`.
  3. Formulated a design utilizing the Section 8 invariants:
     - Set `_kDefaultDragTargetSize = 20`.
     - Computed an axis-aware edge band (`math.min(_kDefaultDragTargetSize, globalRect.height / 2)`).
     - Queried `SelectionPoint.lineHeight` from the active child `Selectable` to compute `lineTop` and `lineBottom` so that selection handles (which center coordinates on the text line) trigger edge scrolling accurately.
     - Outward projections bounded by scrollable dimensions to avoid runaway scrolling.
  4. Authored 3 focused regression tests in `packages/flutter/test/widgets/scrollable_selection_test.dart`.
  5. Verified the tests failed prior to the fix on the expected assertion and passed after applying the fix.
  6. Completed all analyzer and formatting checks in 73 steps and 69 tool calls.

### Candidate B Investigation & Execution
- **Commit Checked Out**: `8808bf80fbc5870fec0dce9de459bda4b8cceea7`
- **Trajectory Overview**:
  1. Candidate B inspected issue #162856 and loaded `flutter-text-domain-expert/SKILL.md`.
  2. Analyzed `_ScrollableSelectionContainerDelegate` and previous commit history.
  3. Formulated a geometry fix based on local coordinates:
     - Set `_kDefaultDragTargetSize = 200`.
     - Converted global pointer position to local coordinates via `box.globalToLocal()`.
     - Clamped `targetWidth` / `targetHeight` to `box.size` to prevent small-scrollable assertion failures.
     - Created a local rect with `horizontalRadius` / `verticalRadius` (100px proximity zone) and converted back using `MatrixUtils.transformRect()`.
  4. Authored 7 thorough regression tests covering forward/backward directions for vertical and horizontal axes, start/end handles, and small scrollables.
  5. Ran multiple cycles of test executions and analyzer verification, completing in 113 turns and 112 tool calls.

---

## 4. Key Strengths & Testing Pitfalls Observed

### Direct Citations from Transcripts

#### 1. Candidate A's Section 8 SelectionGeometry Query Implementation
Candidate A queried `SelectionPoint.lineHeight` directly from the active `Selectable`:
```dart
// Candidate A in packages/flutter/lib/src/widgets/scrollable.dart
final double lineHeight;
if (event.type == SelectionEventType.endEdgeUpdate) {
  lineHeight =
      (currentSelectionEndIndex != -1 && currentSelectionEndIndex < selectables.length)
      ? selectables[currentSelectionEndIndex].value.endSelectionPoint?.lineHeight ?? 0.0
      : 0.0;
} else {
  lineHeight =
      (currentSelectionStartIndex != -1 && currentSelectionStartIndex < selectables.length)
      ? selectables[currentSelectionStartIndex].value.startSelectionPoint?.lineHeight ?? 0.0
      : 0.0;
}
final double lineTop = position.dy - lineHeight / 2;
final double lineBottom = position.dy + lineHeight / 2;
```

#### 2. Candidate B's Local-Coordinate Proximity Zone
Candidate B used local coordinate transforms with a 200px target size clamped to the box size:
```dart
// Candidate B in packages/flutter/lib/src/widgets/scrollable.dart
final Offset local = box.globalToLocal(event.globalPosition);
final Size size = box.size;
final double targetWidth = math.min(size.width, _kDefaultDragTargetSize);
final double targetHeight = math.min(size.height, _kDefaultDragTargetSize);
final double horizontalRadius = targetWidth / 2;
final double verticalRadius = targetHeight / 2;
```

---

### Architectural Differences: Candidate A vs. Candidate B

```diff
--- Candidate B (Local-Coordinate 200px Proximity Box)
+++ Candidate A (Axis-Aware SelectionGeometry Line-Height Projection)
@@ -1,45 +1,65 @@
-  static const double _kDefaultDragTargetSize = 200;
+  static const double _kDefaultDragTargetSize = 20;
 
   Rect _dragTargetFromEvent(SelectionEdgeUpdateEvent event) {
-    final box = state.context.findRenderObject() as RenderBox?;
-    if (box == null || !box.hasSize) {
-      return Rect.fromCenter(center: event.globalPosition, width: 0, height: 0);
-    }
-    final Offset local = box.globalToLocal(event.globalPosition);
-    final Size size = box.size;
-    final double targetWidth = math.min(size.width, _kDefaultDragTargetSize);
-    final double targetHeight = math.min(size.height, _kDefaultDragTargetSize);
-    final double horizontalRadius = targetWidth / 2;
-    final double verticalRadius = targetHeight / 2;
-
-    final double left;
-    final double right;
-    if (local.dx < 0) {
-      left = local.dx;
-      right = math.min(0.0, local.dx + horizontalRadius);
-    } else if (local.dx > size.width) {
-      left = math.max(size.width, local.dx - horizontalRadius);
-      right = local.dx;
-    } else {
-      left = local.dx - horizontalRadius;
-      right = local.dx + horizontalRadius;
-    }
-
-    final double top;
-    final double bottom;
-    if (local.dy < 0) {
-      top = local.dy;
-      bottom = math.min(0.0, local.dy + verticalRadius);
-    } else if (local.dy > size.height) {
-      top = math.max(size.height, local.dy - verticalRadius);
-      bottom = local.dy;
-    } else {
-      top = local.dy - verticalRadius;
-      bottom = local.dy + verticalRadius;
-    }
-
-    final localRect = Rect.fromLTRB(left, top, right, bottom);
-    final Matrix4 transform = box.getTransformTo(null);
-    return MatrixUtils.transformRect(transform, localRect);
+    final box = state.context.findRenderObject()! as RenderBox;
+    final Matrix4 transform = box.getTransformTo(null);
+    final Rect globalRect = MatrixUtils.transformRect(
+      transform,
+      Rect.fromLTWH(0, 0, box.size.width, box.size.height),
+    );
+    final Offset position = event.globalPosition;
+    final Axis axis = axisDirectionToAxis(state.axisDirection);
+    switch (axis) {
+      case Axis.vertical:
+        final double verticalEdgeBand = math.min(_kDefaultDragTargetSize, globalRect.height / 2);
+        final double lineHeight;
+        if (event.type == SelectionEventType.endEdgeUpdate) {
+          lineHeight =
+              (currentSelectionEndIndex != -1 && currentSelectionEndIndex < selectables.length)
+              ? selectables[currentSelectionEndIndex].value.endSelectionPoint?.lineHeight ?? 0.0
+              : 0.0;
+        } else {
+          lineHeight =
+              (currentSelectionStartIndex != -1 && currentSelectionStartIndex < selectables.length)
+              ? selectables[currentSelectionStartIndex].value.startSelectionPoint?.lineHeight ?? 0.0
+              : 0.0;
+        }
+        final double lineTop = position.dy - lineHeight / 2;
+        final double lineBottom = position.dy + lineHeight / 2;
+        double top = position.dy;
+        double bottom = position.dy;
+        if (position.dy < globalRect.center.dy) {
+          if (position.dy < globalRect.top) {
+            top = position.dy;
+          } else if (lineTop < globalRect.top + verticalEdgeBand) {
+            top = math.max(lineTop - verticalEdgeBand, position.dy - globalRect.height);
+          }
+        } else {
+          if (position.dy > globalRect.bottom) {
+            bottom = position.dy;
+          } else if (lineBottom > globalRect.bottom - verticalEdgeBand) {
+            bottom = math.min(lineBottom + verticalEdgeBand, position.dy + globalRect.height);
+          }
+        }
+        return Rect.fromLTRB(position.dx, top, position.dx, bottom);
+      case Axis.horizontal:
+        final double horizontalEdgeBand = math.min(_kDefaultDragTargetSize, globalRect.width / 2);
+        double left = position.dx;
+        double right = position.dx;
+        if (position.dx < globalRect.center.dx) {
+          if (position.dx < globalRect.left) {
+            left = position.dx;
+          } else if (position.dx < globalRect.left + horizontalEdgeBand) {
+            left = math.max(position.dx - horizontalEdgeBand, position.dx - globalRect.width);
+          }
+        } else {
+          if (position.dx > globalRect.right) {
+            right = position.dx;
+          } else if (position.dx > globalRect.right - horizontalEdgeBand) {
+            right = math.min(position.dx + horizontalEdgeBand, position.dx + globalRect.width);
+          }
+        }
+        return Rect.fromLTRB(left, position.dy, right, position.dy);
+    }
   }
```

---

## 5. Conclusion

- **Candidate A** demonstrated superior architectural precision by reading `references/static_text_pipeline.md` and applying the Section 8 invariants for selection geometry querying and axis-aware edge-band calculation.
- **Candidate A** resolved the issue with significantly greater resource efficiency: **35.4% fewer planner turns** (73 vs 113), **38.4% fewer tool calls** (69 vs 112), and **21.5% fewer tokens** (82.8k vs 105.5k).
- **Final Verdict**: **Candidate A Wins (99 vs 91)**.
