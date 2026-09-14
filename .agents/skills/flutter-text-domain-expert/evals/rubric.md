# 6-Dimension Evaluation Rubric (100 Points Total)

Score both candidates strictly against the following 100-point rubric:

---

## 1. Subsystem Routing & Architectural Precision (20 pts)
- **Layer Boundaries**: Did it avoid illegal layer imports (e.g. importing Material inside `widgets/`, `rendering/`, or `services/`)?
- **Root Cause & Subsystem Identification**: Did it correctly identify static selection (`SelectableRegion`) vs editable text (`RenderEditable`), and locate relevant classes quickly?
- **Contract Investigation**: Did it inspect comparable handlers, delegates, or recognizers and identify relevant state transitions, coordinate conversions, scrolling, dismissals, platform calls, and notifications?
- **Invariant Ownership**: Did it identify the violated contract and correct the responsible layer, distinguishing invalid values from supported sentinels, unbounded constraints, and legitimate absent or transient state? A necessary lifecycle fix or consumer validation is valid; suppressing an established upstream defect with a downstream guard is not.

---

## 2. Test File Placement & Organization (20 pts)
- **Target File**: Did it place tests in the appropriate existing suites for the affected layers, including `packages/flutter/test/` and affected `material_ui`/`cupertino_ui` suites in `flutter/packages`?
- **Cleanliness & Focus**: Are tests focused, minimal, and regression-resistant, with configuration, action availability, and callback payload checks separated from gesture sequences when interaction is unnecessary for the assertion?
- **Interaction Realism**: When the bug depends on gesture routing, hit testing, visibility, or lifecycle behavior, do tests reproduce the relevant interaction sequence?
- **Consumer Coverage**: For changes spanning core primitives and design-system consumers, do tests verify core behavior and integration through affected public wrappers, including delegating or customizable constructors where forwarding differs?

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
- **Regression Failure Verification**: For bug fixes, did the regression test fail against the unfixed behavior at the bug-specific assertion or exception and pass with the fix? Compilation errors, setup failures, and unrelated assertions do not establish reproduction. Tests must verify intended behavior, not merely the absence of an exception.
- **Composing Range Preservation**: Avoided clobbering active IME composing ranges.
- **Regression Invariants**: Preserved edge-cases for small scrollables, axis directions, and boundary clipping.

---

## 5. Search Precision & Autonomous Discovery (10 pts)
- **Directness of Path**: Navigated directly to relevant files without exploratory wandering across unrelated directories.
- **Autonomous Skill Activation**: Did the agent autonomously trigger/consult the `flutter-text-domain-expert` skill (if available in the environment) upon encountering the text domain task?
- **Hallucinations**: Did not hallucinate non-existent classes, files, or APIs.

---

## 6. Quantitative Resource & Token Efficiency (10 pts)
- **Turn Count**: Minimal planner reasoning turns required to complete the task.
- **Tool Invocations**: Minimal tool calls executed.
- **Token Footprint**: Low estimated total token consumption across the trajectory.
