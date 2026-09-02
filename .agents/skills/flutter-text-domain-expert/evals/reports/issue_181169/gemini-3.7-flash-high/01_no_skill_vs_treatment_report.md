# Evaluation Report: Flutter Issue #181169

**Target Issue**: [flutter/flutter#181169](https://github.com/flutter/flutter/issues/181169)  
**Evaluated Model**: Gemini 3.7 Flash (High)  
**Experiment**: Baseline (No Skill, commit `67710a5db2adcae7e5ad606c7f5001108e037672`) vs Treatment (Skill v4 with Producer Invariants vs Consumer Band-Aids rule, commit `7c45588fc9bf095ef6cbd750717bf37ac254ef2a`)

---

## 1. Executive Summary & Final Verdict
- **Winner Declaration**: **Candidate B (With Skill v4)**
- **High-Level Rationale**:  
  This benchmark serves as a textbook demonstration of the **"Producer Invariants vs Consumer Band-Aids"** architectural principle.
  - **Candidate A (Baseline, No Skill)** applied a defensive **consumer band-aid** in [`EdgeDraggingAutoScroller.startAutoScrollIfNecessary`](file:///Users/roliv/flutter/packages/flutter/lib/src/widgets/scrollable_helpers.dart) (`if (!dragTarget.isFinite) return;`). While this prevented the crash when non-finite coordinates reached the scroller, it failed to address why non-finite coordinates were generated in the first place, leaving the underlying child delegate state (`_selectionStartsInScrollable = true`) corrupted across nested scrollables. In addition, Candidate A introduced `MaterialApp` and `Scaffold` dependencies in a `widgets` unit test suite and spent exploratory turns wandering into unrelated matrix utility code.
  - **Candidate B (Treatment, Skill v4)** autonomously activated the `flutter-text-domain-expert` skill and diagnosed the true root cause at the **producer layer**: [`_ScrollableSelectionContainerDelegate._inferPositionRelatedToOrigin`](file:///Users/roliv/flutter/packages/flutter/lib/src/widgets/scrollable.dart) was clamping positions before the scrollable to `box.localToGlobal(Offset.zero)`, which lies inside the `[0, width] x [0, height]` bounds of child scrollables, causing nested delegates to falsely claim ownership (`_selectionStartsInScrollable = true`). Candidate B fixed the producer invariant by returning `box.localToGlobal(const Offset(-1, -1))`, completely preventing false selection initialization and invalid auto-scrolling requests. Candidate B also placed a clean, minimal test in the canonical [`selectable_region_scroll_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/widgets/selectable_region_scroll_test.dart) file adhering strictly to layer boundaries with `TestWidgetsApp`.

---

## 2. Comparative Scorecard Table

| Dimension | Max Pts | Candidate A (Baseline) | Candidate B (With Skill v4) | Notes / Observations |
| :--- | :---: | :---: | :---: | :--- |
| **1. Subsystem Routing & Architectural Precision** | 20 | 12 | 20 | Candidate B fixed the producer root cause in `_ScrollableSelectionContainerDelegate` maintaining geometric invariants. Candidate A applied a defensive consumer band-aid in `EdgeDraggingAutoScroller`. |
| **2. Test File Placement & Organization** | 20 | 14 | 20 | Candidate B authored a focused test in `selectable_region_scroll_test.dart` using `TestWidgetsApp`. Candidate A split tests across two files and used Material widgets in a `widgets` test. |
| **3. Avoidance of Flutter Text Testing Traps** | 25 | 24 | 25 | Both correctly simulated mouse drag gestures without hanging on `pumpAndSettle()`. Candidate B added proper lifecycle teardown. |
| **4. Code Correctness & Cleanliness** | 15 | 11 | 15 | Both passed `dart analyze --fatal-infos` (0 issues) and `dart format`. Candidate B preserved the core `_selectionStartsInScrollable` invariant. |
| **5. Search Precision & Autonomous Discovery** | 10 | 6 | 10 | Candidate B autonomously consulted `SKILL.md`, `static_text_pipeline.md`, and `text_debugging_playbooks.md`. Candidate A wandered through `matrix_utils.dart` (6 views) and `reorderable_list.dart`. |
| **6. Quantitative Resource & Token Efficiency** | 10 | 8 | 9 | Candidate B completed the task in 7.7% fewer turns and 8.7% fewer tool calls. |
| **Total Score** | **100** | **75** | **99** | **Candidate B Wins (+24 pts)** |

### Quantitative Metrics Summary

| Metric | Candidate A (Baseline) | Candidate B (With Skill v4) | Delta (%) |
| :--- | :---: | :---: | :---: |
| **Skill Triggered Automatically** | No | Yes (Step 16: `SKILL.md`, `static_text_pipeline.md`, `text_debugging_playbooks.md`) | N/A |
| **Total Planner Turns** | 104 | 96 | -7.7% |
| **Total Tool Calls** | 103 | 94 | -8.7% |
| **Estimated Tokens** | 87,513 | 91,804 | +4.9% |
| **Distinct Files Viewed** | 8 | 6 | -25.0% |
| **Distinct Files Modified** | 3 | 2 | -33.3% |

---

## 3. Trajectory & Behavioral Comparison
- **Candidate A Investigation & Execution**:  
  Candidate A checked out commit `67710a5db2` and retrieved issue #181169. Upon seeing the assertion in `EdgeDraggingAutoScroller._scroll()` (`'(globalRect.size.width + precisionErrorTolerance) >= transformedDragTarget.size.width'`), Candidate A focused narrowly on the consumer stack trace. It inspected `scrollable_helpers.dart`, `scrollable.dart`, and then repeatedly examined `matrix_utils.dart` (Steps 89–103) attempting to understand why coordinate transformations resulted in `NaN` bounds. Candidate A decided to treat the symptom by adding a guard `if (!dragTarget.isFinite) { stopAutoScroll(); return; }` in `EdgeDraggingAutoScroller.startAutoScrollIfNecessary`. It added a unit test in `scrollable_helpers_test.dart` and a widget test in `scrollable_selection_test.dart` using `MaterialApp` and `Scaffold`.
- **Candidate B Investigation & Execution**:  
  Candidate B checked out commit `7c45588fc9` and inspected issue #181169. At Step 16, Candidate B autonomously recognized the domain context and loaded `SKILL.md`, subsequently referencing `static_text_pipeline.md` and `text_debugging_playbooks.md`. Guided by the text selection and edge-scrolling architectural guidelines, Candidate B investigated why `EdgeDraggingAutoScroller` received `Offset.infinite` in the first place. It traced the coordinate propagation in `_ScrollableSelectionContainerDelegate._inferPositionRelatedToOrigin`, observing that returning `Offset.zero` for drag points before the scrollable caused child scrollables to evaluate `_globalPositionInScrollable` as `true` and falsely set `_selectionStartsInScrollable = true`. Candidate B fixed the producer bug by returning `box.localToGlobal(const Offset(-1, -1))` and authored a clean regression test in `selectable_region_scroll_test.dart` using `TestWidgetsApp` and `SimpleBuilderTableView`.

---

## 4. Key Strengths & Testing Pitfalls Observed
- **Direct Citations from Transcripts**:
  - *Candidate B Autonomous Skill Discovery (Step 16)*:
    `tool=view_file args={'AbsolutePath': '.../.agents/skills/flutter-text-domain-expert/SKILL.md'}`
  - *Candidate B Root Cause Plan (Step 129)*:
    ```markdown
    ### Root Cause
    In `_ScrollableSelectionContainerDelegate`:
    1. When selection starts outside a scrollable (`_selectionStartsInScrollable == false`), `_inferPositionRelatedToOrigin` clamped positions before the scrollable (`localPosition.dy < 0 || localPosition.dx < 0`) to `box.localToGlobal(Offset.zero)`.
    2. `Offset.zero` (local (0,0)) is contained inside `Rect.fromLTWH(0, 0, width, height)`. When dispatched down to a nested child `_ScrollableSelectionContainerDelegate` (e.g., the inner dimension of a `TwoDimensionalScrollView` or nested `Scrollable`), the child delegate checked `_globalPositionInScrollable(box.localToGlobal(Offset.zero))` and falsely concluded that `_selectionStartsInScrollable = true`.
    3. Later, when the drag moved past the scrollable and `Offset.infinite` was dispatched for the end edge update, the child scrollable (which mistakenly had `_selectionStartsInScrollable == true`) attempted to auto-scroll to `Offset.infinite` using `_autoScroller.startAutoScrollIfNecessary(_dragTargetFromEvent(event))`.
    ```
- **Architectural Differences**:
  - *Candidate A Consumer Band-Aid ([`scrollable_helpers.dart`](file:///Users/roliv/flutter/packages/flutter/lib/src/widgets/scrollable_helpers.dart#L217-L221))*:
    ```dart
    void startAutoScrollIfNecessary(Rect dragTarget) {
      if (!dragTarget.isFinite) {
        stopAutoScroll();
        return;
      }
      final ScrollPhysics? physics = scrollable.resolvedPhysics;
    ```
  - *Candidate B Producer Invariant Fix ([`scrollable.dart`](file:///Users/roliv/flutter/packages/flutter/lib/src/widgets/scrollable.dart#L1318-L1322))*:
    ```dart
    if (!_selectionStartsInScrollable) {
      // If the selection starts outside of the scrollable, selecting across the
      // scrollable boundary will act as selecting the entire content in the
      // scrollable. This logic move the offset to the -1.0 or infinity to cover
      // the entire content if the input position is outside of the scrollable.
      if (localPosition.dy < 0 || localPosition.dx < 0) {
        return box.localToGlobal(const Offset(-1, -1));
      }
    ```
