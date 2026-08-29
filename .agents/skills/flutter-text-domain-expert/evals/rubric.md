# 6-Dimension Evaluation Rubric (100 Points Total)

Score both candidates strictly against the following 100-point rubric:

---

## 1. Subsystem Routing & Architectural Precision (20 pts)
- **Layer Boundaries**: Did it avoid illegal layer imports (e.g. importing Material inside `widgets/`, `rendering/`, or `services/`)?
- **Root Cause & Subsystem Identification**: Did it correctly identify static selection (`SelectableRegion`) vs editable text (`RenderEditable`), and locate relevant classes quickly?
- **Geometric vs Hacky Solutions**: Did it resolve the issue at the geometry/event delegate layer rather than introducing fragile lifecycle hooks or forced animation timers?

---

## 2. Test File Placement & Organization (20 pts)
- **Target File**: Did it place the test in the canonical test file under `packages/flutter/test/` (e.g. `packages/flutter/test/widgets/scrollable_selection_test.dart`) rather than an ad-hoc or misplaced file?
- **Cleanliness & Focus**: Is the test focused, minimal, and regression-resistant?
- **Interaction Realism**: Does the test simulate realistic touch/mouse interactions (e.g., selection handles, long-press gestures)?

---

## 3. Avoidance of Flutter Text Testing Traps (25 pts)
- **Multi-Tap Timing**: Avoided `pumpAndSettle()` between multi-taps; used `TestGesture` + `pump(kDoubleTapMinTime)`.
- **Caret Timer Hangs**: Avoided `pumpAndSettle()` hangs on focused inputs with active blinking cursors.
- **Drag Slop & Multi-Move**: Accounted for `kTouchSlop` / `kPanSlop` (large fonts and issuing multiple move events to fire `onDragUpdate`).
- **Realistic IME**: Used `tester.testTextInput.updateEditingValue()` with `TextRange composing` instead of `tester.enterText()`.
- **Reactive Execution**: Avoided active polling loops and redundant timer tasks.

---

## 4. Code Correctness & Cleanliness (15 pts)
- **Lints & Analyzer**: 0 warnings/errors via `dart analyze --fatal-infos`.
- **Formatting**: Properly formatted via `dart format`.
- **Composing Range Preservation**: Avoided clobbering active IME composing ranges.
- **Regression Invariants**: Preserved edge-cases for small scrollables, axis directions, and boundary clipping.

---

## 5. Search Precision & Autonomous Discovery (10 pts)
- **Directness of Path**: Navigated directly to relevant files without exploratory wandering across unrelated directories.
- **Hallucinations**: Did not hallucinate non-existent classes, files, or APIs.

---

## 6. Quantitative Resource & Token Efficiency (10 pts)
- **Turn Count**: Minimal planner reasoning turns required to complete the task.
- **Tool Invocations**: Minimal tool calls executed.
- **Token Footprint**: Low estimated total token consumption across the trajectory.
