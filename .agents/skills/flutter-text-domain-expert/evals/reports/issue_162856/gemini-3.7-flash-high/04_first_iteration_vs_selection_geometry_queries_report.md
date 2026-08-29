# Evaluation Report: Edge scrolling of selection area not working when scroll view not wrapped by SafeArea (#162856)

**Target Issue**: [flutter/flutter#162856](https://github.com/flutter/flutter/issues/162856)  
**Evaluated Model**: Gemini 3.7 Flash (High)  
**Candidate A (Baseline Conversation ID)**: [`971e36a8-9128-4cc8-996a-98ea4e01ebaa`](conversation://971e36a8-9128-4cc8-996a-98ea4e01ebaa)  
**Candidate B (Treatment Conversation ID)**: [`6b492339-a478-460e-909c-048b68ddf472`](conversation://6b492339-a478-460e-909c-048b68ddf472)  

---

## 1. Executive Summary & Final Verdict
- **Winner Declaration**: **Candidate B (With Skill / Treatment)**
- **High-Level Rationale**: 
  Candidate B achieved a perfect **100/100** score, executing the task with **55.1% fewer reasoning turns** (57 vs 127), **57.9% fewer tool calls** (53 vs 126), and **48.1% fewer tokens** (70.5k vs 135.8k).
  Equipped with the updated `flutter-text-domain-expert` skill (featuring Section 8 Edge Scrolling Invariants and SelectionGeometry Query Patterns), Candidate B implemented a clean, mathematically sound, axis-aware directional edge projection in `_ScrollableSelectionContainerDelegate._dragTargetFromEvent` that cleanly queries `lineHeight` from `selectables[currentSelectionEndIndex]` and avoids overscrolling.
  In contrast, Candidate A (Baseline) naively reverted `_kDefaultDragTargetSize` to `200`, creating a 200x200 bounding box that caused continuous auto-scrolling loops, forced Candidate A to add ad-hoc `stopAutoScroll()` hooks inside `onScrollViewScrolled`, touched unrelated files (`selectable_region.dart`), and required 46 bash commands and 127 steps to debug and stabilize.

---

## 2. Comparative Scorecard Table

| Dimension | Max Pts | Candidate A (Baseline) | Candidate B (With Skill) | Notes / Observations |
| :--- | :---: | :---: | :---: | :--- |
| **1. Subsystem Routing & Architectural Precision** | 20 | 12 | 20 | Candidate B implemented directional 1D edge bands with global coordinate transforms and safe `SelectionPoint` `lineHeight` queries. Candidate A used a 200x200 square that triggered 100px prematurely and required an intrusive `onScrollViewScrolled` listener hack. |
| **2. Test File Placement & Organization** | 20 | 17 | 20 | Both placed regression tests in `scrollable_selection_test.dart`. Candidate B wrote 3 focused tests (vertical, horizontal, touch handle) including release cessation verification. Candidate A wrote 4 tests but struggled with auto-scroll runaways. |
| **3. Avoidance of Flutter Text Testing Traps** | 25 | 19 | 25 | Candidate B strictly adhered to Section 8 testing invariants (handling the `lineHeight / 2` touch handle offset and verifying gesture release cessation). Candidate A masked handle offsets with a 200px box and used task management tools. |
| **4. Code Correctness & Cleanliness** | 15 | 9 | 15 | Candidate B modified only 2 files (`scrollable.dart` and the test) with 0 lints. Candidate A modified an unrelated file (`selectable_region.dart`) and re-introduced small-scrollable bounce bugs by expanding target size to 200x200. |
| **5. Search Precision & Autonomous Discovery** | 10 | 6 | 10 | Candidate B went straight to the relevant pipeline reference (`static_text_pipeline.md`) in 22 views / 13 greps. Candidate A performed 56 views, 20 greps, and multiple `git log` searches across 10 files. |
| **6. Quantitative Resource & Token Efficiency** | 10 | 4 | 10 | Candidate B completed the entire benchmark in 57 turns (vs 127) and 70,522 tokens (vs 135,764), saving ~48.1% of tokens and ~57.9% of tool invocations. |
| **Total Score** | **100** | **67** | **100** | **Candidate B wins decisively (+33 pts)** |

### Quantitative Metrics Summary

| Metric | Candidate A (Baseline) | Candidate B (With Skill) | Delta (%) |
| :--- | :---: | :---: | :---: |
| **Skill Triggered Automatically** | Yes | Yes | Tie |
| **Total Planner Turns** | 127 | 57 | **-55.1%** |
| **Total Tool Calls** | 126 | 53 | **-57.9%** |
| **Estimated Tokens** | 135,764 | 70,522 | **-48.1%** |
| **Tool: `view_file`** | 56 | 22 | **-60.7%** |
| **Tool: `run_command`** | 46 | 16 | **-65.2%** |
| **Tool: `grep_search`** | 20 | 13 | **-35.0%** |
| **Distinct Files Viewed** | 10 | 9 | **-10.0%** |
| **Distinct Files Modified** | 3 | 2 | **-33.3%** |

---

## 3. Trajectory & Behavioral Comparison

### Candidate A Investigation & Execution
- **Commit Checked Out**: `19261190bad200063c67b57d550811b0f3f4773a` (Baseline commit without Section 8 edge-scrolling invariants or SelectionGeometry query patterns).
- **Trajectory Overview**:
  1. Candidate A read the issue report, autonomously loaded `flutter-text-domain-expert/SKILL.md`, and investigated `packages/flutter/lib/src/widgets/scrollable.dart`.
  2. Discovered commit history showing that PR #112816 set `_kDefaultDragTargetSize = 0` to fix issue #110917.
  3. Lacking the Section 8 directional edge-band patterns, Candidate A attempted to solve the issue by restoring `_kDefaultDragTargetSize = 200` with `Rect.fromCenter(center: event.globalPosition, width: math.min(200, box.size.width), height: math.min(200, box.size.height))`.
  4. **The Runaway Auto-Scroll Pitfall**: Because a 200x200 centered rectangle extends 100px past the pointer, auto-scrolling was triggered whenever the user dragged within 100px of an edge. Moreover, when the view auto-scrolled, the scroller would never stop because the drag target kept overlapping the edge!
  5. To counter this, Candidate A attempted several hacky fixes: adding `_edgeUpdateReceived = false`, hooking `EdgeDraggingAutoScroller.onScrollViewScrolled: _handleScrollableAutoScrolled` to forcibly stop scrolling, and clearing auto-scroller in `handleClearSelection`.
  6. While investigating, Candidate A also modified `packages/flutter/lib/src/widgets/selectable_region.dart` (changing `_selectionEndPosition = null` to `_selectionStartPosition = null` in `_stopSelectionStartEdgeUpdate()`), which was outside the scope of issue #162856.
  7. Spent 46 command executions and 127 turns iterating on Python rewrite scripts and test runs before finally passing the tests.

### Candidate B Investigation & Execution
- **Commit Checked Out**: `7bb6d97c23779cb315048c4c4e8d9765f7fc8646` (Treatment commit with Section 8 edge-scrolling invariants and SelectionGeometry query patterns).
- **Trajectory Overview**:
  1. Candidate B read the issue report and consulted `references/static_text_pipeline.md` in the `flutter-text-domain-expert` skill.
  2. Navigated directly to the section on **Querying `SelectionGeometry` from a `SelectionContainerDelegate`** and **Scrollable Integration & `_ScrollableSelectionContainerDelegate`**.
  3. Understood immediately:
     - The drag target must be computed as an inner edge band (`_kDefaultDragTargetEdgeBand = 20.0`) projected along the active scrolling axis (`Axis.vertical` or `Axis.horizontal`), bounded by `globalRect.height / 2`.
     - Mobile selection handles have a vertical offset of `lineHeight / 2` to center on the text line, requiring safe inspection of `selectables[currentSelectionEndIndex].value.endSelectionPoint?.lineHeight`.
  4. Implemented the directional projection cleanly in `scrollable.dart` in a single pass without modifying any other framework files.
  5. Added 3 robust regression tests in `packages/flutter/test/widgets/scrollable_selection_test.dart`:
     - Vertical inside-edge pointer dragging.
     - Horizontal inside-edge pointer dragging.
     - Touch selection handle dragging inside viewport bounds with release cessation verification.
  6. Ran `dart analyze --fatal-infos` (0 issues) and `dart format`. All tests passed immediately on the first run.

---

## 4. Key Strengths & Testing Pitfalls Observed

### Direct Citations from Transcripts

#### 1. Candidate A's Struggle with Auto-Scroll Stopping Hacks
In steps 70–85 of Candidate A's transcript, Candidate A realized that the 200x200 box caused the auto-scroller to keep scrolling indefinitely:
```dart
// Candidate A introducing lifecycle listener hack to forcibly halt scrolling:
void _handleScrollableAutoScrolled() {
  _autoScroller.stopAutoScroll();
}
```
This workaround forcibly halts the auto-scroller after each frame unless a continuous stream of new drag events is pumped, leading to choppy scrolling and fragile edge-case behavior.

#### 2. Candidate B's Clean SelectionGeometry Query Pattern & Directional Projection
Candidate B directly applied the SelectionGeometry query pattern and directional edge band described in the treatment skill:
```dart
// Candidate B Implementation:
final double lineHeight;
if (event.type == SelectionEventType.endEdgeUpdate) {
  lineHeight =
      (currentSelectionEndIndex != -1 && currentSelectionEndIndex < selectables.length)
      ? selectables[currentSelectionEndIndex].value.endSelectionPoint?.lineHeight ?? 0.0
      : 0.0;
} else if (event.type == SelectionEventType.startEdgeUpdate) {
  lineHeight =
      (currentSelectionStartIndex != -1 && currentSelectionStartIndex < selectables.length)
      ? selectables[currentSelectionStartIndex].value.startSelectionPoint?.lineHeight ?? 0.0
      : 0.0;
} else {
  lineHeight = 0.0;
}
final double lineTop = position.dy - lineHeight / 2;
final double lineBottom = position.dy + lineHeight / 2;
```

---

### Architectural Differences: Candidate A vs. Candidate B

```diff
--- Candidate A (Baseline)
+++ Candidate B (Treatment / With Skill)
@@ -1,30 +1,60 @@
-  static const double _kDefaultDragTargetSize = 200;
+  static const double _kDefaultDragTargetEdgeBand = 20.0;
 
-  void _handleScrollableAutoScrolled() {
-    _autoScroller.stopAutoScroll();
-  }
-
   Rect _dragTargetFromEvent(SelectionEdgeUpdateEvent event) {
     final box = state.context.findRenderObject()! as RenderBox;
-    return Rect.fromCenter(
-      center: event.globalPosition,
-      width: math.min(_kDefaultDragTargetSize, box.size.width),
-      height: math.min(_kDefaultDragTargetSize, box.size.height),
+    final Matrix4 transform = box.getTransformTo(null);
+    final Rect globalRect = MatrixUtils.transformRect(
+      transform,
+      Rect.fromLTWH(0, 0, box.size.width, box.size.height),
     );
+    final Offset position = event.globalPosition;
+    final Axis axis = axisDirectionToAxis(state.axisDirection);
+
+    switch (axis) {
+      case Axis.vertical:
+        final double verticalEdgeBand = math.min(
+          _kDefaultDragTargetEdgeBand,
+          globalRect.height / 2,
+        );
+        final double lineHeight;
+        if (event.type == SelectionEventType.endEdgeUpdate) {
+          lineHeight =
+              (currentSelectionEndIndex != -1 && currentSelectionEndIndex < selectables.length)
+              ? selectables[currentSelectionEndIndex].value.endSelectionPoint?.lineHeight ?? 0.0
+              : 0.0;
+        } else if (event.type == SelectionEventType.startEdgeUpdate) {
+          lineHeight =
+              (currentSelectionStartIndex != -1 && currentSelectionStartIndex < selectables.length)
+              ? selectables[currentSelectionStartIndex].value.startSelectionPoint?.lineHeight ?? 0.0
+              : 0.0;
+        } else {
+          lineHeight = 0.0;
+        }
+        final double lineTop = position.dy - lineHeight / 2;
+        final double lineBottom = position.dy + lineHeight / 2;
+        double top = position.dy;
+        double bottom = position.dy;
+        if (position.dy < globalRect.top) {
+          top = position.dy;
+        } else if (lineTop < globalRect.top + verticalEdgeBand) {
+          top = lineTop - verticalEdgeBand;
+        }
+        if (position.dy > globalRect.bottom) {
+          bottom = position.dy;
+        } else if (lineBottom > globalRect.bottom - verticalEdgeBand) {
+          bottom = lineBottom + verticalEdgeBand;
+        }
+        return Rect.fromLTRB(position.dx, top, position.dx, bottom);
+      case Axis.horizontal:
+        final double horizontalEdgeBand = math.min(
+          _kDefaultDragTargetEdgeBand,
+          globalRect.width / 2,
+        );
+        double left = position.dx;
+        double right = position.dx;
+        if (position.dx < globalRect.left) {
+          left = position.dx;
+        } else if (position.dx < globalRect.left + horizontalEdgeBand) {
+          left = position.dx - horizontalEdgeBand;
+        }
+        if (position.dx > globalRect.right) {
+          right = position.dx;
+        } else if (position.dx > globalRect.right - horizontalEdgeBand) {
+          right = position.dx + horizontalEdgeBand;
+        }
+        return Rect.fromLTRB(left, position.dy, right, position.dy);
     }
   }
```

---

## 5. Conclusion

The addition of Section 8 (Edge Scrolling Invariants) and the SelectionGeometry query patterns to the `flutter-text-domain-expert` skill delivered an immense performance and quality advantage:
- Candidate B completed the entire triage, regression test authoring, architectural fix, and validation cycle in **57 steps vs 127 steps (-55.1%)** and **70.5k tokens vs 135.8k tokens (-48.1%)**.
- Candidate B produced an architecturally clean, geometrically precise fix that handles handle offsets and boundary clamping without any side-effects, listeners, or extraneous file modifications.
