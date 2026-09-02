# Evaluation Report: Flutter Issue #141775

**Target Issue**: [flutter/flutter#141775](https://github.com/flutter/flutter/issues/141775)  
**Evaluated Model**: Gemini 3.7 Flash (High)  
**Experiment**: Candidate A (Commit `7bb6d97c23779cb315048c4c4e8d9765f7fc8646`, skill v3 with SelectionGeometry queries) vs Candidate B (Commit `4b9dc786a2beabe684a7d257a4278949e62dbea8`, skill v4 with Code Freeze Rule & Companion Wrapper Audit)

---

## 1. Executive Summary & Final Verdict
- **Winner Declaration**: **Candidate B (Skill v4 with Code Freeze Rule & Companion Wrapper Audit)**
- **High-Level Rationale**:  
  Both candidates successfully diagnosed the root cause in `SelectableRegion` and implemented the required platform actions (`Look Up`, `Search Web`, and `Share`) on iOS. However, **Candidate B** demonstrated superior architectural consistency, testing depth, and rule adherence:
  1. **Architectural & API Consistency**: Candidate B's implementation in `selectable_region.dart` matched existing framework conventions and method structures (`_share()`, `_lookUp()`, `_searchWeb()`) and properly preserved platform switch handling for toolbar dismissal (`hideToolbar(false)` on iOS vs `hideToolbar()` on other platforms). In contrast, Candidate A applied unconditional `hideToolbar(false)` callbacks.
  2. **Companion Design-System Wrapper & Code Freeze Audit**: Candidate B actively audited the companion design-system wrappers (`AdaptiveTextSelectionToolbar`, `CupertinoTextSelectionToolbarButton`, and `AdaptiveTextSelectionToolbarButton`), verified that the core widget layer dynamically accommodated all button types without requiring split PRs in `flutter/packages`, and verified zero diff in frozen Material/Cupertino paths via `git diff -w --ignore-blank-lines`.
  3. **Assertion Rigor & Handle Invariant Verification**: Candidate B's regression test suite used modern idioms (`TargetPlatformVariant.only(TargetPlatform.iOS)`), verified exact button list lengths and types prior to clicking, and verified that selection handles (`startHandleLayerLink`, `endHandleLayerLink`) remained linked after toolbar dismissal on iOS.
  4. **Avoidance of Active Polling**: Candidate B operated entirely reactively without polling. In contrast, Candidate A scheduled a timer and engaged in a 6-step active polling loop using `manage_task status`.

---

## 2. Comparative Scorecard Table

| Dimension | Max Pts | Candidate A (Commit `7bb6d97c23`) | Candidate B (Commit `4b9dc786a2`) | Notes / Observations |
| :--- | :---: | :---: | :---: | :--- |
| **1. Subsystem Routing & Architectural Precision** | 20 | 18 | 20 | Candidate B mirrored platform switch patterns in `SelectableRegionState` and completed a companion design-system wrapper audit. Candidate A used unconditional toolbar dismissal. |
| **2. Test File Placement & Organization** | 20 | 18 | 20 | Candidate B used `TargetPlatformVariant.only(TargetPlatform.iOS)` and asserted button list lengths and selection handle persistence. Candidate A asserted only basic selection. |
| **3. Avoidance of Flutter Text Testing Traps** | 25 | 19 | 25 | Candidate A fell into an active polling trap (6 consecutive `manage_task status` calls). Candidate B maintained 100% reactive execution. |
| **4. Code Correctness & Cleanliness** | 15 | 14 | 15 | Both passed `dart analyze --fatal-infos` (0 issues) and `dart format`. Candidate B's helper methods matched existing codebase conventions exactly. |
| **5. Search Precision & Autonomous Discovery** | 10 | 10 | 10 | Both candidates autonomously activated `SKILL.md` and located the relevant classes directly. Candidate B verified code-freeze invariants. |
| **6. Quantitative Resource & Token Efficiency** | 10 | 9 | 8 | Candidate A used fewer planner turns (75 vs 89) and tool calls (74 vs 83), as Candidate B performed the companion wrapper audit and freeze check. |
| **Total Score** | **100** | **88** | **98** | **Candidate B Wins (+10 pts)** |

### Quantitative Metrics Summary

| Metric | Candidate A | Candidate B | Delta (%) |
| :--- | :---: | :---: | :---: |
| **Skill Triggered Automatically** | Yes (`SKILL.md` loaded) | Yes (`SKILL.md` loaded) | — |
| **Total Planner Turns** | 75 | 89 | +18.7% |
| **Total Tool Calls** | 74 | 83 | +12.2% |
| **Estimated Tokens** | 63,854 | 81,571 | +27.7% |
| **Distinct Files Viewed** | 9 | 11 | +22.2% |
| **Distinct Files Modified** | 3 | 3 | 0.0% |

---

## 3. Trajectory & Behavioral Comparison
- **Candidate A Investigation & Execution**:  
  Candidate A checked out commit `7bb6d97c23` and retrieved issue #141775. It identified `SelectableRegion.getSelectableButtonItems` and `SelectableRegionState` in `packages/flutter/lib/src/widgets/selectable_region.dart`. Candidate A added `onLookUp` and `onSearchWeb` callbacks to `getSelectableButtonItems` and enabled `platformCanShare`, `platformCanLookUp`, and `platformCanSearchWeb` for `TargetPlatform.iOS`. In `SelectableRegionState`, Candidate A added `_lookUp()` and `_searchWeb()` methods with `data.plainText.isEmpty` checks and wired `hideToolbar(false)` unconditionally. During verification, Candidate A launched a background test run and performed an active polling loop using `manage_task status` across 6 turns (Steps 90–101) before updating tests. It added 3 regression tests in `selectable_region_test.dart` and verified `dart analyze` and `dart format`.
- **Candidate B Investigation & Execution**:  
  Candidate B checked out commit `4b9dc786a2` and retrieved issue #141775. At Step 6, it autonomously consulted `material-cupertino-packages/SKILL.md` and `flutter-text-domain-expert/SKILL.md`. Candidate B evaluated whether changes to `SelectableRegion` required companion updates to design-system wrappers in `packages/flutter` or `flutter/packages`. It inspected `AdaptiveTextSelectionToolbar` and verified that button item types are generically adapted to platform buttons without breaking changes. Candidate B updated `SelectableRegion.getSelectableButtonItems` and mirrored the platform switch pattern for `onLookUp` and `onSearchWeb`. In `selectable_region_test.dart`, Candidate B added comprehensive tests checking button lengths, button types, and selection handle persistence. It ran `git diff -w --ignore-blank-lines` across frozen Material/Cupertino paths (Step 145), confirmed 0 diff, verified `dart analyze --fatal-infos` (0 issues), and ensured clean formatting.

---

## 4. Key Strengths & Testing Pitfalls Observed
- **Direct Citations from Transcripts**:
  - *Candidate A Active Polling Loop (Steps 90–101)*:
    ```
    [Step 90] tool=manage_task args={'Action': 'status', 'TaskId': 'c312c246-.../task-89'}
    [Step 92] tool=manage_task args={'Action': 'status', 'TaskId': 'c312c246-.../task-89'}
    [Step 94] tool=manage_task args={'Action': 'status', 'TaskId': 'c312c246-.../task-89'}
    [Step 96] tool=manage_task args={'Action': 'status', 'TaskId': 'c312c246-.../task-89'}
    [Step 98] tool=manage_task args={'Action': 'status', 'TaskId': 'c312c246-.../task-89'}
    [Step 101] tool=manage_task args={'Action': 'status', 'TaskId': 'c312c246-.../task-89'}
    ```
  - *Candidate B Companion Wrapper & Code Freeze Audit (Step 145)*:
    `tool=run_command args={'CommandLine': 'git diff -w --ignore-blank-lines packages/flutter/lib/src/material packages/flutter/lib/src/cupertino'}`

- **Architectural Differences**:
  - *Candidate A Toolbar Dismissal in [`selectable_region.dart`](file:///Users/roliv/flutter/packages/flutter/lib/src/widgets/selectable_region.dart#L1802-L1809)*:
    ```dart
    onLookUp: () {
      _lookUp();
      hideToolbar(false);
    },
    onSearchWeb: () {
      _searchWeb();
      hideToolbar(false);
    },
    ```
  - *Candidate B Platform Switch Toolbar Dismissal in [`selectable_region.dart`](file:///Users/roliv/flutter/packages/flutter/lib/src/widgets/selectable_region.dart#L1802-L1829)*:
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
    onSearchWeb: () {
      _searchWeb();

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

- **Test Assertion Differences**:
  - *Candidate A Test Verification*:
    ```dart
    shareButton.onPressed?.call();
    expect(lastShare, 'are');
    // On iOS, share should hide the toolbar but not clear the selection.
    expect(regionState.selectionOverlay?.toolbarIsVisible, isFalse);
    expect(paragraph.selections[0], const TextSelection(baseOffset: 4, extentOffset: 7));
    ```
  - *Candidate B Invariant Verification (Handles & Length)*:
    ```dart
    expect(buttonItems.length, 5);
    expect(buttonItems[4].type, ContextMenuButtonType.share);
    buttonItems[4].onPressed?.call();
    expect(lastShare, 'are');
    // On iOS, share hides the toolbar but keeps the selection and handles.
    expect(regionState.selectionOverlay?.toolbarIsVisible, isFalse);
    expect(regionState.selectionOverlay, isNotNull);
    expect(regionState.selectionOverlay?.startHandleLayerLink, isNotNull);
    expect(regionState.selectionOverlay?.endHandleLayerLink, isNotNull);
    ```
