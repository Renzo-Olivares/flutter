# Evaluation Report: Fix Edge Scrolling of SelectionArea on Full-Screen Scrollables (Issue #162856)

**Target Issue**: [flutter/flutter#162856](https://github.com/flutter/flutter/issues/162856)  
**Evaluated Model**: Gemini 3.7 Flash (High)  
**Candidate A (Baseline SHA)**: `418dc62853176a2e64e18e84f362918a95ae8918`  
**Candidate B (Treatment SHA)**: `7bb6d97c23779cb315048c4c4e8d9765f7fc8646`  

---

## 1. Executive Summary & Final Verdict
- **Winner Declaration**: **Candidate B (With Skill / Treatment)**
- **High-Level Rationale**:
  Candidate B demonstrated superior architectural precision, complete test coverage, and higher resource efficiency. Leveraging the updated `flutter-text-domain-expert` skill documentation on `SelectionGeometry` queries and edge-scrolling invariants:
  1. Candidate B applied safe, idiomatically pattern-matched queries for `SelectionPoint` (with explicit `index < selectables.length` bounds checks) and calculated edge-band expansion directly in global coordinates with clean `switch (axisDirectionToAxis(state.axisDirection))` dispatch.
  2. Candidate B authored 5 comprehensive regression tests (covering vertical forward/backward, horizontal forward/backward, and mouse pointer selection within bounds) and verified touch handle release behavior.
  3. Candidate B operated purely reactively without any timer tasks or task management overhead (0 `schedule`, 0 `manage_task`), whereas Candidate A introduced polling timers (`schedule`) and had to kill hanging processes (`manage_task`).
  4. Candidate B achieved a **16.9% reduction in planner steps** (98 vs 118), a **19.0% reduction in tool calls** (94 vs 116), and an **8.1% reduction in total token footprint** (103k vs 112k tokens).

---

## 2. Comparative Scorecard Table

| Dimension | Max Pts | Candidate A (Baseline) | Candidate B (With Skill) | Notes / Observations |
| :--- | :---: | :---: | :---: | :--- |
| **1. Subsystem Routing & Architectural Precision** | 20 | 18 | 20 | Both identified `_ScrollableSelectionContainerDelegate` & `EdgeDraggingAutoScroller`. Candidate B used pattern matching, bounds checks (`< selectables.length`), and clean global transform calculations. |
| **2. Test File Placement & Organization** | 20 | 18 | 20 | Both placed tests in `packages/flutter/test/widgets/scrollable_selection_test.dart`. Candidate B wrote 5 thorough tests (vertical + horizontal + mouse + touch handles) vs Candidate A's 2 tests. |
| **3. Avoidance of Flutter Text Testing Traps** | 25 | 18 | 25 | Candidate B executed fully reactively (0 `schedule`, 0 `manage_task`) and used multi-move drag steps. Candidate A used `schedule` for polling and had to manually kill tasks. |
| **4. Code Correctness & Cleanliness** | 15 | 14 | 15 | Both passed `dart analyze --fatal-infos` (0 issues) and `dart format`. Candidate B introduced `_kSelectToScrollEdgeBand` rather than modifying `_kDefaultDragTargetSize`. |
| **5. Search Precision & Autonomous Discovery** | 10 | 9 | 10 | Both activated the domain expert skill. Candidate B directly navigated the `static_text_pipeline.md` reference and queried 8 distinct files vs Candidate A's 13 files. |
| **6. Quantitative Resource & Token Efficiency** | 10 | 7 | 10 | Candidate B used 98 steps (-16.9%), 94 tool calls (-19.0%), and 103,051 tokens (-8.1%). |
| **Total Score** | **100** | **84** | **100** | **Candidate B wins decisively (+16 pts)** |

### Quantitative Metrics Summary

| Metric | Candidate A (Baseline) | Candidate B (With Skill) | Delta (%) |
| :--- | :---: | :---: | :---: |
| **Skill Triggered Automatically** | Yes | Yes | Tie |
| **Total Planner Turns** | 118 | 98 | **-16.9%** |
| **Total Tool Calls** | 116 | 94 | **-19.0%** |
| **Estimated Tokens** | 112,086 | 103,051 | **-8.1%** |
| **Distinct Files Viewed** | 13 | 8 | **-38.5%** |
| **Distinct Files Modified** | 3 | 3 | 0.0% |
| **Regression Tests Added** | 2 | 5 | **+150.0%** |

---

## 3. Trajectory & Behavioral Comparison

### Candidate A Investigation & Execution
- **Investigation**: Candidate A checked out commit `418dc62853176a2e64e18e84f362918a95ae8918` and viewed the issue description. It activated the `flutter-text-domain-expert` skill and began searching across `packages/flutter/lib/src/widgets/scrollable.dart` and related files.
- **Challenges & Traps**:
  - Ran background git commands that blocked/hung, requiring multiple `manage_task` calls to kill them (`task-47`, `task-55`).
  - Used `schedule` to set an active 20-second timer to poll for task completion on `task-99`, violating the reactive wakeup principle.
  - Performed bidirectional coordinate conversions (global -> local -> local bounding math -> global via `MatrixUtils.transformRect`).
  - Did not guard `currentSelectionEndIndex` with `< selectables.length`.
- **Testing**: Added 2 tests in `scrollable_selection_test.dart` (mouse and touch drag near edge in vertical ListView). Verified pre-fix failure and post-fix success across all 58 tests.

### Candidate B Investigation & Execution
- **Investigation**: Candidate B checked out commit `7bb6d97c23779cb315048c4c4e8d9765f7fc8646` and consulted the updated skill references in `static_text_pipeline.md` (specifically Section: *Querying SelectionGeometry from a SelectionContainerDelegate*) and `testing_text_stack.md`.
- **Execution Precision**:
  - Implemented `_dragTargetFromEvent` using clean pattern matching (`switch (event.type)`) and safe boundary checks (`currentSelectionEndIndex < selectables.length`).
  - Computed the viewport geometry in global coordinates directly with `axisDirectionToAxis(state.axisDirection)`.
  - Defined a dedicated `_kSelectToScrollEdgeBand = 20.0` constant instead of repurposing the point drag target size.
  - Avoided all polling loops and redundant timer tasks (0 calls to `schedule` or `manage_task`).
- **Testing**: Added 5 comprehensive regression tests in `scrollable_selection_test.dart` covering vertical forward/backward, horizontal forward/backward, and mouse pointer interactions. Verified that all 61 tests passed in `scrollable_selection_test.dart` and 309 tests passed across `scrollable_helpers_test.dart` and `selectable_region_test.dart`.

---

## 4. Key Strengths & Testing Pitfalls Observed

### Direct Citations from Transcripts

#### Candidate B Autonomous Skill Utilization
Candidate B immediately consulted the new `SelectionGeometry` section in `static_text_pipeline.md`:
```
Step 33: view_file AbsolutePath: /Users/roliv/flutter/.agents/skills/flutter-text-domain-expert/references/static_text_pipeline.md
Step 36: view_file AbsolutePath: /Users/roliv/flutter/.agents/skills/flutter-text-domain-expert/references/testing_text_stack.md
```

#### Candidate A Task Polling Trap
Candidate A attempted to poll a running test process rather than relying on reactive execution:
```
Candidate A [50] manage_task: {'Action': 'status', 'TaskId': '8894b98f-7e92-4a2e-960d-1993cc30c901/task-99'}
Candidate A [51] schedule: {'DurationSeconds': '20', 'Prompt': 'Check on flutter test task-99', 'TimerCondition': 'task-99'}
```

### Architectural Differences

#### Candidate A Implementation
```dart
  static const double _kDefaultDragTargetSize = 20;

  Rect _dragTargetFromEvent(SelectionEdgeUpdateEvent event) {
    final box = state.context.findRenderObject()! as RenderBox;
    final Offset localPosition = box.globalToLocal(event.globalPosition);

    final double? lineHeight;
    if (event.type == SelectionEventType.endEdgeUpdate) {
      lineHeight = currentSelectionEndIndex != -1
          ? selectables[currentSelectionEndIndex].value.endSelectionPoint?.lineHeight
          : null;
    } else {
      lineHeight = currentSelectionStartIndex != -1
          ? selectables[currentSelectionStartIndex].value.startSelectionPoint?.lineHeight
          : null;
    }
    // Local bounding box calculations ...
    final localRect = Rect.fromLTRB(left, top, right, bottom);
    final Matrix4 transform = box.getTransformTo(null);
    return MatrixUtils.transformRect(transform, localRect);
  }
```

#### Candidate B Implementation (Treatment / Skill-Informed)
```dart
  static const double _kSelectToScrollEdgeBand = 20.0;

  Rect _dragTargetFromEvent(SelectionEdgeUpdateEvent event) {
    final box = state.context.findRenderObject()! as RenderBox;
    final Matrix4 transform = box.getTransformTo(null);
    final Rect globalRect = MatrixUtils.transformRect(
      transform,
      Rect.fromLTWH(0, 0, box.size.width, box.size.height),
    );

    final SelectionPoint? edgePoint = switch (event.type) {
      SelectionEventType.endEdgeUpdate =>
        currentSelectionEndIndex != -1 && currentSelectionEndIndex < selectables.length
            ? selectables[currentSelectionEndIndex].value.endSelectionPoint
            : null,
      SelectionEventType.startEdgeUpdate =>
        currentSelectionStartIndex != -1 && currentSelectionStartIndex < selectables.length
            ? selectables[currentSelectionStartIndex].value.startSelectionPoint
            : null,
      _ => null,
    };
    final double lineHeight = edgePoint?.lineHeight ?? 0.0;

    double left = event.globalPosition.dx;
    double right = event.globalPosition.dx;
    double top = event.globalPosition.dy;
    double bottom = event.globalPosition.dy;

    switch (axisDirectionToAxis(state.axisDirection)) {
      case Axis.vertical:
        final double effectiveEdgeBand = math.min(_kSelectToScrollEdgeBand, globalRect.height / 2);
        final double lineTop = event.globalPosition.dy - lineHeight / 2;
        final double lineBottom = event.globalPosition.dy + lineHeight / 2;

        if (event.globalPosition.dy > globalRect.center.dy) {
          if (event.globalPosition.dy >= globalRect.bottom) {
            bottom = event.globalPosition.dy;
          } else if (lineBottom > globalRect.bottom - effectiveEdgeBand) {
            final double distanceFromEdge = lineBottom - (globalRect.bottom - effectiveEdgeBand);
            bottom = globalRect.bottom + distanceFromEdge;
          }
        } else {
          if (event.globalPosition.dy <= globalRect.top) {
            top = event.globalPosition.dy;
          } else if (lineTop < globalRect.top + effectiveEdgeBand) {
            final double distanceFromEdge = (globalRect.top + effectiveEdgeBand) - lineTop;
            top = globalRect.top - distanceFromEdge;
          }
        }
      case Axis.horizontal:
        final double effectiveEdgeBand = math.min(_kSelectToScrollEdgeBand, globalRect.width / 2);
        if (event.globalPosition.dx > globalRect.center.dx) {
          if (event.globalPosition.dx >= globalRect.right) {
            right = event.globalPosition.dx;
          } else if (event.globalPosition.dx > globalRect.right - effectiveEdgeBand) {
            final double distanceFromEdge =
                event.globalPosition.dx - (globalRect.right - effectiveEdgeBand);
            right = globalRect.right + distanceFromEdge;
          }
        } else {
          if (event.globalPosition.dx <= globalRect.left) {
            left = event.globalPosition.dx;
          } else if (event.globalPosition.dx < globalRect.left + effectiveEdgeBand) {
            final double distanceFromEdge =
                (globalRect.left + effectiveEdgeBand) - event.globalPosition.dx;
            left = globalRect.left - distanceFromEdge;
          }
        }
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }
```
