# Evaluation Report: [iOS] Add default buttons to SelectionArea context menu (#141775)

**Target Issue**: [flutter/flutter#141775](https://github.com/flutter/flutter/issues/141775)  
**Evaluated Model**: Gemini 3.7 Flash (High)

---

## 1. Executive Summary & Final Verdict
- **Winner Declaration**: **Candidate B (Treatment — With Skill v4)**
- **High-Level Rationale**: Candidate B autonomously activated the `flutter-text-domain-expert` skill and utilized the updated context menu matrix and platform channel reference guides to resolve the missing iOS toolbar items (`Look Up`, `Search Web`, `Share...`) with superior test coverage and architectural robustness. Candidate B verified all 5 iOS buttons (`Copy`, `Select All`, `Look Up`, `Search Web`, `Share...`) and tested all 3 platform channels sequentially in `SelectionArea` as well as multi-platform tests for `AdaptiveTextSelectionToolbar.selectableRegion` and `CupertinoAdaptiveTextSelectionToolbar.selectableRegion`. Candidate B also implemented defensive whitespace trimming (`data.plainText.trim().isEmpty`) on platform channel invocations. Both candidates achieved 100% clean static analysis (`dart analyze --fatal-infos`) and proper formatting (`dart format`). Candidate B scored **98/100** vs Candidate A's **93/100**.

---

## 2. Comparative Scorecard Table

| Dimension | Max Pts | Candidate A (Baseline) | Candidate B (With Skill v4) | Notes / Observations |
| :--- | :---: | :---: | :---: | :--- |
| **1. Subsystem Routing & Architectural Precision** | 20 | 20 | 20 | Both correctly identified `SelectableRegion` vs `RenderEditable`, updated `SelectableRegion.getSelectableButtonItems`, `SelectableRegionState._lookUp/_searchWeb/_share`, and adaptive toolbar constructors without illegal layer imports. Candidate B added `trim().isEmpty` guards before invoking platform channels. |
| **2. Test File Placement & Organization** | 20 | 18 | 20 | Both placed regression tests across canonical test suites (`selectable_region_test.dart`, `selection_area_test.dart`, `adaptive_text_selection_toolbar_test.dart` in both Material and Cupertino). Candidate B's tests are significantly more exhaustive, asserting all 5 iOS toolbar buttons, verifying all 3 channel invocations, and adding full cross-platform assertions for `selectableRegion`. |
| **3. Avoidance of Flutter Text Testing Traps** | 25 | 24 | 25 | Both candidates properly avoided caret timer hangs, used `startGesture` + `addTearDown(gesture.removePointer)` with appropriate long-press timeouts. Candidate A initially encountered a `PlatformException` in its mock channel handler before refining it, whereas Candidate B structured mock channels and gesture offsets cleanly from the start. |
| **4. Code Correctness & Cleanliness** | 15 | 15 | 15 | Both candidates passed `dart analyze --fatal-infos` with 0 issues and `dart format` with 0 diffs. Both preserved backward compatibility on all public constructors. |
| **5. Search Precision & Autonomous Discovery** | 10 | 7 | 10 | Candidate A did not trigger or consult the text domain skill (Skill Triggered: **No**). Candidate B autonomously discovered and activated `flutter-text-domain-expert` (Skill Triggered: **Yes**), consulting the context menu matrix and text pipeline reference files. |
| **6. Quantitative Resource & Token Efficiency** | 10 | 9 | 8 | Candidate A completed in fewer planner turns (116 vs 146) and tool calls (113 vs 139), but token footprint was virtually identical (106,636 vs 107,687 tokens, a ~1% difference) while Candidate B delivered broader multi-file test coverage and plan documentation. |
| **Total Score** | **100** | **93** | **98** | **Candidate B wins decisively (+5 pts)** |

### Quantitative Metrics Summary

| Metric | Candidate A (Baseline) | Candidate B (With Skill v4) | Delta (%) |
| :--- | :---: | :---: | :---: |
| **Skill Triggered Automatically** | No | Yes | — |
| **Total Planner Turns** | 116 | 146 | +25.9% |
| **Total Tool Calls** | 113 | 139 | +23.0% |
| **Estimated Tokens** | 106,636 | 107,687 | +1.0% |
| **Distinct Files Viewed** | 11 | 14 | +27.3% |
| **Distinct Files Modified** | 7 | 7 | 0.0% |

---

## 3. Trajectory & Behavioral Comparison

- **Candidate A Investigation & Execution**:
  - Started by checking out baseline commit `7bb6d97c23779cb315048c4c4e8d9765f7fc8646`.
  - Did not trigger or read the `flutter-text-domain-expert` skill.
  - Investigated issue #141775 via `gh issue view` and located relevant files using ripgrep searches for `getSelectableButtonItems` and `LookUp.invoke`.
  - Added regression tests in `selection_area_test.dart` and `selectable_region_test.dart`. Encountered an unhandled `PlatformException` in the mock binary messenger handler on the first run due to unconditioned argument casting on system channels, which was promptly resolved.
  - Implemented the fix in `selectable_region.dart`, `material/adaptive_text_selection_toolbar.dart`, and `cupertino/adaptive_text_selection_toolbar.dart`.
  - Verified all modified files with `dart analyze --fatal-infos` and `dart format`. Ran all 4 test suites to completion.

- **Candidate B Investigation & Execution**:
  - Started by checking out treatment commit `fd18dd04e40945ac80898e378e766b8602a6c3cd`.
  - Autonomously triggered and read `flutter-text-domain-expert` (`SKILL.md`), adopting framework conventions for static selection pipeline, gesture coordination, and context menu construction.
  - Formulated a comprehensive implementation plan (`implementation_plan.md`) outlining exact changes across `SelectableRegion`, `AdaptiveTextSelectionToolbar`, and `CupertinoAdaptiveTextSelectionToolbar`.
  - Added thorough regression tests in `selection_area_test.dart`, capturing the exact failure signature (`Expected: exactly 5 matching candidates`, `Actual: Found 2 widgets with type "CupertinoTextSelectionToolbarButton"`).
  - Added extensive test coverage for `AdaptiveTextSelectionToolbar.selectableRegion` and `CupertinoAdaptiveTextSelectionToolbar.selectableRegion` across all supported platforms (Android, iOS, macOS, Linux, Windows, Fuchsia).
  - Applied defensive string trimming (`data.plainText.trim().isEmpty`) in platform invocations.
  - Verified clean static analysis (`dart analyze --fatal-infos`) and formatting (`dart format`), followed by a detailed `walkthrough.md`.

---

## 4. Key Strengths & Testing Pitfalls Observed

### Direct Citations from Transcripts

- **Candidate A Traps Encountered**:
  - *Mock Channel Type Collision*: During the initial regression test run in `selection_area_test.dart` (Step 154), Candidate A's mock channel handler threw:
    ```
    PlatformException(error, type '_Map<String, dynamic>' is not a subtype of type 'String?' in type cast, null, null)
    ```
    because the mock handler did not filter by method name before casting `methodCall.arguments as String?`, intercepting system calls like `SystemChrome.setApplicationSwitcherDescription`.

- **Candidate B Best Practices**:
  - *Autonomous Skill Activation*: Candidate B consulted `flutter-text-domain-expert` at the start of the task, ensuring alignment with text selection architecture and avoiding common test traps.
  - *Clean Failure Verification*: In Step 186, Candidate B verified the exact failure signature without crash side-effects:
    ```
    The following TestFailure was thrown running a test:
    Expected: exactly 5 matching candidates
      Actual: _TypeWidgetFinder:<Found 2 widgets with type "CupertinoTextSelectionToolbarButton": [
                CupertinoTextSelectionToolbarButton(...),
                CupertinoTextSelectionToolbarButton(...)
              ]>
    ```
  - *Sequential Platform Method Verification*: Candidate B tested all three platform methods (`LookUp.invoke`, `SearchWeb.invoke`, and `Share.invoke`) in `SelectionArea` with proper gesture re-triggering and teardowns.

---

### Architectural Differences

#### 1. Platform Invocation Guards in `SelectableRegionState`

**Candidate A (`isEmpty` only)**:
```dart
Future<void> _lookUp() async {
  final SelectedContent? data = _selectable?.getSelectedContent();
  if (data == null || data.plainText.isEmpty) {
    return;
  }
  await SystemChannels.platform.invokeMethod('LookUp.invoke', data.plainText);
}
```

**Candidate B (`trim().isEmpty` defensive guard)**:
```dart
Future<void> _lookUp() async {
  final SelectedContent? data = _selectable?.getSelectedContent();
  if (data == null || data.plainText.trim().isEmpty) {
    return;
  }
  await SystemChannels.platform.invokeMethod('LookUp.invoke', data.plainText);
}
```

#### 2. Test Suite Depth in `adaptive_text_selection_toolbar_test.dart`

**Candidate A**:
Added `CupertinoAdaptiveTextSelectionToolbar.selectableRegion` test with basic tap verification.

**Candidate B**:
Added parameterized cross-platform tests for both `AdaptiveTextSelectionToolbar.selectableRegion` and `CupertinoAdaptiveTextSelectionToolbar.selectableRegion` verifying exact button counts and button types on all 6 target platforms (`Android`, `iOS`, `Fuchsia`, `macOS`, `Linux`, `Windows`).
