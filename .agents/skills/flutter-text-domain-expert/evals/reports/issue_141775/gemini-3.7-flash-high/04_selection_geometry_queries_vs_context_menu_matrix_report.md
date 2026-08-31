# Evaluation Report: Context Menu Default Buttons on iOS for SelectionArea (#141775)

**Target Issue**: [flutter/flutter#141775](https://github.com/flutter/flutter/issues/141775)  
**Evaluated Model**: Gemini 3.7 Flash (High)  
**Experiment Configuration**:
- **Candidate A (Baseline)**: Commit `7bb6d97c237` (v3 with SelectionGeometry queries)
- **Candidate B (Treatment)**: Commit `d946e2f4b91` (v4 with Context Menu Matrix & SystemChannels Map)

---

## 1. Executive Summary & Final Verdict
- **Winner Declaration**: **Candidate B (With Skill / Treatment)**
- **High-Level Rationale**:
  - Both candidates correctly solved the issue by extending `SelectableRegion.getSelectableButtonItems` to support `onLookUp`, `onSearchWeb`, and iOS `onShare`, wiring up the `_lookUp()` and `_searchWeb()` methods to invoke `LookUp.invoke` and `SearchWeb.invoke` on `SystemChannels.platform`, and updating both `AdaptiveTextSelectionToolbar.selectable` and `CupertinoAdaptiveTextSelectionToolbar.selectable`.
  - **Candidate B** achieved higher search directness and token efficiency (-13.4% tokens, -9.7% turns, -6.7% tool calls) by utilizing the v4 **Context Menu Ordering Matrix** and **SystemChannels Reference Map** in `references/static_text_pipeline.md`. Candidate B immediately knew the platform button ordering (`Copy` $\to$ `Select all` $\to$ `Look Up` $\to$ `Search Web` $\to$ `Share...`), the channel method names (`LookUp.invoke`, `SearchWeb.invoke`, `Share.invoke`), and the iOS selection handle non-clearing semantics without needing exploratory codebase searches across `EditableText` or `SelectableText`.
  - Candidate B consolidated its regression tests cleanly into `selectable_region_test.dart` and `adaptive_text_selection_toolbar_test.dart` with zero test bloat.

---

## 2. Comparative Scorecard Table

| Dimension | Max Pts | Candidate A (Baseline) | Candidate B (With Skill) | Notes / Observations |
| :--- | :---: | :---: | :---: | :--- |
| **1. Subsystem Routing & Architectural Precision** | 20 | 20 | 20 | Both candidates preserved strict layer boundaries (`widgets/` independent of `material/` or `cupertino/`), identified `SelectableRegion` vs `EditableText`, and properly used `SelectionGeometry.status == SelectionStatus.uncollapsed`. |
| **2. Test File Placement & Organization** | 20 | 20 | 20 | Both candidates placed tests in canonical test files under `packages/flutter/test/widgets/`, `packages/flutter/test/cupertino/`, and `packages/flutter/test/material/`. |
| **3. Avoidance of Flutter Text Testing Traps** | 25 | 24 | 25 | Both candidates properly mocked `SystemChannels.platform` and registered `addTearDown`. Candidate B had cleaner test consolidation. |
| **4. Code Correctness & Cleanliness** | 15 | 15 | 15 | Both candidates achieved 0 analyzer errors/warnings (`dart analyze --fatal-infos`) and passed `dart format`. |
| **5. Search Precision & Autonomous Discovery** | 10 | 8 | 10 | Candidate B leveraged `references/static_text_pipeline.md` (Context Menu Matrix & SystemChannels Map) to directly formulate the solution. Candidate A had to explore `EditableText` to deduce the channel names and button ordering. |
| **6. Quantitative Resource & Token Efficiency** | 10 | 8 | 10 | Candidate B required fewer planner turns (102 vs 113), fewer tool calls (98 vs 105), and significantly fewer tokens (107,448 vs 124,055, a 13.4% reduction). |
| **Total Score** | **100** | **95** | **100** | **Candidate B wins by +5 points** |

### Quantitative Metrics Summary

| Metric | Candidate A (Baseline) | Candidate B (With Skill) | Delta (%) |
| :--- | :---: | :---: | :---: |
| **Skill Triggered Automatically** | Yes (v3) | Yes (v4) | — |
| **Total Planner Turns** | 113 | 102 | -9.7% |
| **Total Tool Calls** | 105 | 98 | -6.7% |
| **Estimated Tokens** | 124,055 | 107,448 | -13.4% |
| **Distinct Files Viewed** | 13 | 13 | 0.0% |
| **Distinct Files Modified** | 7 | 6 | -14.3% |
| **Analyzer Errors / Warnings** | 0 | 0 | 0.0% |
| **Test Pass Rate** | 100% (317/317) | 100% (311/311) | 0.0% |

---

## 3. Trajectory & Behavioral Comparison

### Candidate A Investigation & Execution
1. **Initial Search**: Triggered `flutter-text-domain-expert` v3 (`SKILL.md`).
2. **Subsystem Discovery**: Investigated `SelectableText` and `EditableText` via multiple `grep_search` and `view_file` queries to discover how `Look Up`, `Search Web`, and `Share` are implemented and dispatched to platform channels.
3. **Plumbing & Tests**:
   - Modified `packages/flutter/lib/src/widgets/selectable_region.dart` using switch patterns for platform availability.
   - Added `CupertinoAdaptiveTextSelectionToolbar.selectableRegion` and updated `AdaptiveTextSelectionToolbar.selectable`.
   - Added 3 separate test cases in `selectable_region_test.dart` and an integration test in `selection_area_test.dart`.
4. **Verification**: Executed `dart analyze --fatal-infos` and `dart format`, followed by test suite verification.

### Candidate B Investigation & Execution
1. **Initial Search**: Triggered `flutter-text-domain-expert` v4 and directly read `references/static_text_pipeline.md`.
2. **Direct Subsystem Navigation**: The **Context Menu Matrix** and **SystemChannels Reference Map** in the v4 skill provided the exact button order for iOS (`Copy` $\to$ `Select all` $\to$ `Look Up` $\to$ `Search Web` $\to$ `Share...`), the channel method names (`LookUp.invoke`, `SearchWeb.invoke`, `Share.invoke`), and the iOS selection persistence requirement.
3. **Implementation & Tests**:
   - Implemented `_lookUp()` and `_searchWeb()` and updated `SelectableRegion.getSelectableButtonItems` with concise boolean conditions.
   - Updated `AdaptiveTextSelectionToolbar.selectable` and `CupertinoAdaptiveTextSelectionToolbar.selectable`.
   - Implemented a unified, concise test in `selectable_region_test.dart` verifying all three platform actions and selection handle persistence.
4. **Verification**: Executed `dart analyze --fatal-infos` and `dart format`, verifying clean passes across all test suites.

---

## 4. Key Strengths & Testing Pitfalls Observed

### Direct Citations from Transcripts

#### Candidate B Autonomous Skill Reference (`static_text_pipeline.md`)
Candidate B navigated directly to `references/static_text_pipeline.md` at step 16, referencing the platform context menu ordering matrix:
> *"The code defines a selectable text selection toolbar, specifying required callbacks for copy and select all... Looking at the context menu matrix in static_text_pipeline.md, iOS requires: Copy -> Select all -> Look Up -> Search Web -> Share..."*

#### Candidate A Exploratory Grep Across `EditableText`
Candidate A had to perform multiple grep searches across `EditableText` to deduce the platform channel names:
```dart
// Step 78-80: grep_search for LookUp.invoke and SearchWeb.invoke in packages/flutter/lib/src/widgets/editable_text.dart
```

### Architectural Differences

#### Platform Capability Check in `SelectableRegion.getSelectableButtonItems`
- **Candidate A (Switch expression per item)**:
  ```dart
  final bool platformCanLookUp =
      !kIsWeb &&
      switch (defaultTargetPlatform) {
        TargetPlatform.iOS => selectionGeometry.status == SelectionStatus.uncollapsed,
        TargetPlatform.android ||
        TargetPlatform.fuchsia ||
        TargetPlatform.linux ||
        TargetPlatform.macOS ||
        TargetPlatform.windows => false,
      };
  ```
- **Candidate B (Direct boolean condition)**:
  ```dart
  final bool platformCanLookUp =
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.iOS &&
      selectionGeometry.status == SelectionStatus.uncollapsed;
  ```

#### Platform Channel Interception in Tests
Both candidates accurately mocked `SystemChannels.platform`:
```dart
TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
  SystemChannels.platform,
  (MethodCall methodCall) async {
    if (methodCall.method == 'LookUp.invoke') {
      expect(methodCall.arguments, isA<String>());
      lastLookUp = methodCall.arguments as String;
    }
    // ...
    return null;
  },
);
addTearDown(
  () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    null,
  ),
);
```

---

## 5. Conclusion
The addition of the **Context Menu Button Ordering Matrix** and **SystemChannels Reference Map** in v4 of the `flutter-text-domain-expert` skill delivered measurable improvements in agent efficiency:
- **-13.4% Token Consumption**
- **-9.7% Planner Turns**
- **-6.7% Tool Invocations**
- Direct navigation without speculative search over unrelated widgets (`EditableText` / `SelectableText`).
