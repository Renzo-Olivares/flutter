# Evaluation Report: Fix EdgeDraggingAutoScroller Assertion Error During Text Selection Across Nested Scrollables

**Target Issue**: [flutter/flutter#181169](https://github.com/flutter/flutter/issues/181169)  
**Evaluated Model**: Gemini 3.7 Flash (High)  
**Candidate A (Baseline)**: `d54f7151-ac0f-46d1-89fc-bba66ce62d66`  
**Candidate B (With Skill)**: `cafbe628-f0df-4f43-b964-b4c3607a12a0`  

---

## 1. Executive Summary & Final Verdict
- **Winner Declaration**: **Candidate B (With Skill)**
- **High-Level Rationale**: 
  - **Autonomous Skill Discovery**: Candidate B automatically discovered and activated the `flutter-text-domain-expert` skill, adopting the recommended domain architecture and test placement idioms.
  - **Architectural & Geometric Precision**: While Candidate A patched the symptom at `scrollable.dart` by constraining `_selectionStartsInScrollable` to `startEdgeUpdate` alongside a non-finite guard, Candidate B identified both the non-finite coordinate edge case AND the deeper coordinate transformation bug in `EdgeDraggingAutoScroller._scroll` (which was applying a local-to-global transform to already global coordinates) as well as updating `SliverReorderableList` coordinate calculations.
  - **Canonical Test Placement**: Candidate B placed the regression test in the canonical text selection test suite (`packages/flutter/test/widgets/scrollable_selection_test.dart`), whereas Candidate A placed its main test in `two_dimensional_scroll_view_test.dart`.
  - **Resource Efficiency**: Candidate B achieved lower token consumption (-8.6%), fewer total planner steps (-3.6%), and fewer tool calls (-3.6%) while delivering a cleaner fix.

---

## 2. Comparative Scorecard Table

| Dimension | Max Pts | Candidate A (Baseline) | Candidate B (With Skill) | Notes / Observations |
| :--- | :---: | :---: | :---: | :--- |
| **1. Subsystem Routing & Architectural Precision** | 20 | 18 | 20 | Candidate B addressed both the non-finite guard and the redundant coordinate transform in `EdgeDraggingAutoScroller`. |
| **2. Test File Placement & Organization** | 20 | 16 | 20 | Candidate B placed the test in canonical `scrollable_selection_test.dart` using text positioning helpers; Candidate A placed it in `two_dimensional_scroll_view_test.dart`. |
| **3. Avoidance of Flutter Text Testing Traps** | 25 | 23 | 25 | Candidate B avoided unnecessary settle loops and leveraged domain test helpers; Candidate A relied on `pumpAndSettle()`. |
| **4. Code Correctness & Cleanliness** | 15 | 15 | 15 | Both candidates achieved 0 analyzer errors (`--fatal-infos`) and passed `dart format`. |
| **5. Search Precision & Autonomous Discovery** | 10 | 7 | 10 | Candidate B autonomously triggered `flutter-text-domain-expert` and used direct file navigation with fewer grep searches. |
| **6. Quantitative Resource & Token Efficiency** | 10 | 8 | 10 | Candidate B used 8.6% fewer tokens (106,989 vs 117,049) and fewer steps (108 vs 112). |
| **Total Score** | **100** | **87** | **100** | **Candidate B wins by +13 points.** |

### Quantitative Metrics Summary

| Metric | Candidate A (Baseline) | Candidate B (With Skill) | Delta (%) |
| :--- | :---: | :---: | :---: |
| **Skill Triggered Automatically** | No | Yes | N/A |
| **Total Planner Turns** | 112 | 108 | -3.6% |
| **Total Tool Calls** | 111 | 107 | -3.6% |
| **Estimated Tokens** | 117,049 | 106,989 | -8.6% |
| **Distinct Files Viewed** | 35 | 47 | +34.3% |
| **Distinct Files Modified** | 4 | 4 | 0.0% |

---

## 3. Trajectory & Behavioral Comparison
- **Candidate A Investigation & Execution**:
  - Candidate A investigated the issue report via `gh issue view` and identified the crash stack trace in `EdgeDraggingAutoScroller._scroll`.
  - It modified `_ScrollableSelectionContainerDelegate.handleSelectionEdgeUpdate` in `scrollable.dart` to require `event.type == SelectionEventType.startEdgeUpdate` before setting `_selectionStartsInScrollable = true`, and added a `!dragTarget.isFinite` guard in `scrollable_helpers.dart`.
  - It wrote the regression test under `packages/flutter/test/widgets/two_dimensional_scroll_view_test.dart` and added a unit test in `scrollable_helpers_test.dart`.
  - Did not activate the domain skill. Executed 51 `run_command` calls and 17 `grep_search` calls.
- **Candidate B Investigation & Execution**:
  - Candidate B inspected the issue and immediately consulted the `flutter-text-domain-expert` skill.
  - Guided by text selection and auto-scrolling subsystem expertise, Candidate B analyzed the coordinate space lifecycle between `SelectableRegion`, `_ScrollableSelectionContainerDelegate`, and `EdgeDraggingAutoScroller`.
  - Identified that `_dragTargetRelatedToScrollOrigin` was already in global coordinates, making the subsequent `MatrixUtils.transformRect(transform, _dragTargetRelatedToScrollOrigin)` call double-transform coordinates. It removed this redundant transform, fixed `SliverReorderableList` coordinate calculation, and added the non-finite guard.
  - Placed the regression test in the canonical test suite `packages/flutter/test/widgets/scrollable_selection_test.dart` using standard helper methods (`textOffsetToPosition`, `SimpleBuilderTableView`).
  - Executed cleanly with zero analyzer issues, lower token consumption, and comprehensive multi-suite test validation (`scrollable_selection_test.dart`, `scrollable_helpers_test.dart`, `reorderable_list_test.dart`, `two_dimensional_scroll_view_test.dart`).

---

## 4. Key Strengths & Testing Pitfalls Observed
- **Direct Citations from Transcripts**:
  - *Candidate B Skill Consultation*: Read `.agents/skills/flutter-text-domain-expert/SKILL.md` to guide its understanding of the text selection hierarchy, edge-scrolling geometry, and test conventions.
  - *Candidate A Test Placement*: Added test to `two_dimensional_scroll_view_test.dart` rather than canonical selection test suites.
- **Architectural Differences**:
  - **Candidate A (`scrollable.dart`)**:
    ```dart
    _selectionStartsInScrollable =
        event.type == SelectionEventType.startEdgeUpdate &&
        _globalPositionInScrollable(event.globalPosition);
    ```
  - **Candidate B (`scrollable_helpers.dart` & `reorderable_list.dart`)**:
    ```dart
    // In EdgeDraggingAutoScroller:
    if (!dragTarget.isFinite) {
      stopAutoScroll();
      return;
    }
    ...
    assert(
      (globalRect.size.width + precisionErrorTolerance) >=
              _dragTargetRelatedToScrollOrigin.size.width &&
          (globalRect.size.height + precisionErrorTolerance) >=
              _dragTargetRelatedToScrollOrigin.size.height,
      'Drag target size is larger than scrollable size, which may cause bouncing',
    );
    ```
