# Evaluation Report: Look Up, Search Web, and Share on SelectionArea on iOS (#141775)

**Target Issue**: [flutter/flutter#141775](https://github.com/flutter/flutter/issues/141775)  
**Evaluated Model**: Gemini 3.7 Flash (High)  
**Evaluator**: Antigravity A/B Benchmark Orchestrator & Objective Judge  
**Candidate A (Baseline)**: Commit `67710a5db2adcae7e5ad606c7f5001108e037672` (Conversation `567e8974-22d2-43ae-b3f3-a99c9de8069a`)  
**Candidate B (Treatment — With Skill v4)**: Commit `d946e2f4b919ce9ae2d0208c0b3fe93da61c4448` (Conversation `dc96479d-a406-452f-93c0-709f448fc627`)  

---

## 1. Executive Summary & Final Verdict

- **Winner Declaration**: **Candidate B (Treatment — With Skill v4)**
- **High-Level Rationale**: Both candidates resolved Flutter issue [#141775](https://github.com/flutter/flutter/issues/141775) by implementing the missing default iOS context menu buttons (`Look Up`, `Search Web`, `Share`) in `SelectableRegion` and the adaptive toolbar widgets, achieving 0 analyzer errors (`dart analyze --fatal-infos`) and 100% passing tests. However, **Candidate B demonstrated a decisive advantage in search precision, avoidance of Flutter text testing traps, code conciseness, and execution efficiency**:
  1. **Avoidance of iOS Gesture Testing Pitfalls**: Candidate A struggled heavily when writing the iOS `SelectionArea` regression test, hitting **5 consecutive test execution failures** and spending **~70 turns** in trial-and-error exploration of `_handleLongPress` and gesture timing before discovering how to properly trigger selection and toolbar appearance on iOS. In contrast, Candidate B leveraged established text domain interaction patterns (`startGesture` with character offset and 500ms hold) and wrote passing regression tests on the first try.
  2. **Architectural & Implementation Cleanliness**: Candidate B implemented concise, idiomatic platform guards (`canLookUp`, `canSearchWeb`, and merged `TargetPlatform.iOS` in `platformCanShare`) and direct `hideToolbar(false)` dismissal semantics in `SelectableRegionState`. Candidate A generated 76% more lines of framework code in `selectable_region.dart` (83 lines vs 47 lines), including redundant desktop/android switch branches for buttons that are strictly restricted to iOS.
  3. **Comprehensive Invariant & Action Assertions**: In `selection_area_test.dart`, Candidate B created separate regression tests for all three actions (`Look Up`, `Search Web`, `Share...`), asserting that each button tap dispatches the correct platform channel method (`LookUp.invoke`, `SearchWeb.invoke`, `Share.invoke`) with the selected text payload. Candidate A only verified channel invocation for `Look Up`.
  4. **Quantitative Efficiency**: Candidate B achieved a **23.7% reduction in planner turns** (116 vs 152), a **26.2% reduction in tool calls** (110 vs 149), and a **10.1% reduction in total token usage** (104,217 vs 115,931 tokens).

---

## 2. Comparative Scorecard Table

| Dimension | Max Pts | Candidate A (Baseline) | Candidate B (With Skill) | Notes / Observations |
| :--- | :---: | :---: | :---: | :--- |
| **1. Subsystem Routing & Architectural Precision** | 20 | 18 | 20 | Both respected layer boundaries across `widgets/`, `material/`, and `cupertino/`. Candidate B implemented cleaner platform guards and exact iOS dismissal semantics (`hideToolbar(false)`). |
| **2. Test File Placement & Organization** | 20 | 17 | 20 | Both targeted canonical test suites (`selectable_region_test.dart`, `selection_area_test.dart`, `adaptive_text_selection_toolbar_test.dart`). Candidate B tested all three button interactions with channel verification; Candidate A only tapped Look Up. |
| **3. Avoidance of Flutter Text Testing Traps** | 25 | 18 | 24 | Candidate A fell into the iOS text gesture trap in `SelectionArea`, suffering 5 consecutive test failures and ~70 turns of debugging. Candidate B used proper `startGesture` timing immediately. |
| **4. Code Correctness & Cleanliness** | 15 | 14 | 15 | Both passed `dart analyze --fatal-infos` (0 issues) and `dart format`. Candidate B wrote significantly more concise and idiomatic code (47 diff lines vs 83 in `selectable_region.dart`). |
| **5. Search Precision & Autonomous Discovery** | 10 | 7 | 10 | Candidate B autonomously loaded `SKILL.md` at Step 6 and navigated directly to toolbar builders and test suites. Candidate A executed 28 grep searches and 61 file views across unrelated files. |
| **6. Quantitative Resource & Token Efficiency** | 10 | 7 | 10 | Candidate B required 23.7% fewer turns (116 vs 152), 26.2% fewer tool calls (110 vs 149), and 10.1% fewer tokens. |
| **Total Score** | **100** | **81** | **99** | **Candidate B wins decisively (+18 points).** |

---

### Quantitative Metrics Summary

| Metric | Candidate A (Baseline) | Candidate B (With Skill) | Delta (%) |
| :--- | :---: | :---: | :---: |
| **Skill Triggered Automatically** | Attempted (file missing on base commit) | **Yes (Step 6)** | N/A |
| **Total Planner Turns** | 152 | **116** | **-23.7%** |
| **Total Tool Calls** | 149 | **110** | **-26.2%** |
| **Estimated Tokens** | 115,931 | **104,217** | **-10.1%** |
| **Distinct Files Viewed** | 13 | **12** | -7.7% |
| **Distinct Files Modified** | 7 | 7 | 0.0% |
| **Test Failures Encountered During Dev** | 5 test runs failed | **0 test runs failed** | **-100.0%** |

---

## 3. Trajectory & Behavioral Comparison

### Candidate A (Baseline) Investigation & Execution
1. **Initial Exploration**: Checked out baseline commit `67710a5db2adcae7e5ad606c7f5001108e037672` and viewed issue #141775. Attempted to read `.agents/skills/flutter-text-domain-expert/SKILL.md` at Step 6, but because the file did not exist on the baseline commit, Candidate A proceeded purely unassisted.
2. **Exploratory Wandering**: Ran 28 grep queries and inspected 61 file chunks across `editable_text.dart`, `selectable_text.dart`, `text_field_test.dart`, `selectable_region_context_menu_test.dart`, and `selection_area.dart` to discover where context menu items were assembled.
3. **Severe Gesture Testing Trap in `selection_area_test.dart`**:
   - At Step 176, Candidate A wrote a test in `selection_area_test.dart` using `tester.longPressAt()`. The test failed because `SelectionArea` on iOS requires specific gesture handling.
   - Over steps 176 through 245 (~70 turn steps), Candidate A tried multiple combinations, repeatedly failing test runs at steps 176, 192, 204, 212, and 220.
   - It searched `_handleLongPress`, `shouldShowSelectionOverlayOnMobile`, `selectionControls`, and inspected other tests before finally discovering that `startGesture(textOffsetToPosition(paragraph, 6))` with `pump(500ms)` was required.
4. **Fix & Verification**: Implemented changes across `selectable_region.dart` and `adaptive_text_selection_toolbar.dart` (Material and Cupertino), ran `dart analyze --fatal-infos` and `dart format`, and verified that all test suites passed.

### Candidate B (Treatment — With Skill v4) Investigation & Execution
1. **Autonomous Skill Activation**: Immediately upon receiving the task, Candidate B inspected `.agents/skills/flutter-text-domain-expert/SKILL.md` at Step 6.
2. **Targeted Subsystem Navigation**: Guided by the text domain reference architecture, Candidate B identified `SelectableRegion.getSelectableButtonItems`, `SelectableRegionState.contextMenuButtonItems`, and `AdaptiveTextSelectionToolbar.selectable` without blind exploratory searches.
3. **Flawless Regression Test Implementation**:
   - In `selection_area_test.dart`, Candidate B immediately wrote tests using `textOffsetToPosition` and `startGesture` with `pump(500ms)`.
   - Created distinct, modular tests for all three actions: Look Up, Search Web, and Share, asserting button presence and platform channel method calls (`LookUp.invoke`, `SearchWeb.invoke`, `Share.invoke`).
   - In `selectable_region_test.dart`, Candidate B tested clicking each button item and verified that `selectionOverlay?.startHandleLayerLink` and `selectionOverlay?.endHandleLayerLink` remained intact.
4. **Clean Code & Tool Efficiency**: Wrote compact, idiomatic guards and callbacks in `selectable_region.dart`, avoiding redundant platform switches. Completed all formatting and analyzer checks cleanly, requiring 36 fewer turns and 39 fewer tool calls than Candidate A.

---

## 4. Key Strengths & Testing Pitfalls Observed

### Architectural Comparison

#### Candidate B Clean Implementation (`selectable_region.dart`):
```dart
    final canCopy = selectionGeometry.status == SelectionStatus.uncollapsed;
    final bool canSelectAll = selectionGeometry.hasContent;
    final bool canLookUp =
        onLookUp != null &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        selectionGeometry.status == SelectionStatus.uncollapsed;
    final bool canSearchWeb =
        onSearchWeb != null &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        selectionGeometry.status == SelectionStatus.uncollapsed;
    // The share button is not supported on the web.
    final bool platformCanShare =
        !kIsWeb &&
        switch (defaultTargetPlatform) {
          TargetPlatform.android ||
          TargetPlatform.iOS => selectionGeometry.status == SelectionStatus.uncollapsed,
          TargetPlatform.macOS ||
          TargetPlatform.fuchsia ||
          TargetPlatform.linux ||
          TargetPlatform.windows => false,
        };
    final bool canShare = onShare != null && platformCanShare;
```

#### Candidate A Verbose Implementation (`selectable_region.dart`):
Candidate A created separate multi-branch switches for `platformCanLookUp` and `platformCanSearchWeb`, and duplicated platform switch statements inside `SelectableRegionState`:
```dart
      onLookUp: () {
        _lookUp();
        switch (defaultTargetPlatform) {
          case TargetPlatform.iOS:
            hideToolbar(false);
          case TargetPlatform.android:
          case TargetPlatform.fuchsia:
          case TargetPlatform.linux:
          case TargetPlatform.macOS:
          case TargetPlatform.windows:
            hideToolbar();
        }
      },
```
Because `onLookUp` is only exposed on iOS, the fallback switch branches are redundant boilerplate. Candidate B correctly and cleanly invoked `hideToolbar(false)`.

---

### Direct Transcript Evidence: Gesture Testing Trap

#### Candidate A Trapped in iOS Long-Press Debugging Loop (Steps 176–245):
Candidate A experienced 5 failed test runs trying to figure out why long-pressing did not show the toolbar on iOS:
```
[176] run_command: flutter test test/material/selection_area_test.dart --name="SelectionArea shows..." -> FAILED
[178] grep_search: "cupertinoTextSelectionHandleControls"
[186] grep_search: "_handleLongPress"
[192] run_command: flutter test test/material/selection_area_test.dart --name="SelectionArea shows..." -> FAILED
[194] grep_search: "_showToolbar"
[198] grep_search: "shouldShowSelectionOverlayOnMobile"
[204] run_command: flutter test test/material/selection_area_test.dart --name="SelectionArea shows..." -> FAILED
[212] run_command: flutter test test/material/selection_area_test.dart --name="SelectionArea shows..." -> FAILED
[220] run_command: flutter test test/material/selection_area_test.dart --name="SelectionArea shows..." -> FAILED
[237] grep_search: "startGesture"
```

Candidate B avoided this loop entirely by applying standard text gesture timing upfront:
```dart
final TestGesture gesture = await tester.startGesture(
  textOffsetToPosition(paragraph, 6),
);
addTearDown(gesture.removePointer);
await tester.pump(const Duration(milliseconds: 500));
await gesture.up();
await tester.pumpAndSettle();
```

---

## 5. Conclusion

The benchmark clearly highlights the impact of domain-specific agent skills in complex frameworks like Flutter. With the `flutter-text-domain-expert` skill v4, **Candidate B avoided major text gesture testing pitfalls that cost Candidate A 5 failed test iterations and ~70 debugging steps**, while producing cleaner code and delivering a **23.7% turn reduction** and **26.2% tool call reduction**.
