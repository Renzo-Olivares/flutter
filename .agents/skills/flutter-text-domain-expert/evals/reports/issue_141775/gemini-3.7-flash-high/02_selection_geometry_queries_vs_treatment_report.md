# Evaluation Report: Flutter Issue #141775

**Target Issue**: [flutter/flutter#141775](https://github.com/flutter/flutter/issues/141775)  
**Evaluated Model**: Gemini 3.7 Flash (High)  
**Experiment**: Candidate A (Commit `7bb6d97c23779cb315048c4c4e8d9765f7fc8646`, skill v3 with SelectionGeometry queries) vs Candidate B (Commit `02d486055702c9dfbe37bb25cf0f405c499d5a39`, skill v4 with Code Freeze Rule & Companion Wrapper Audit)

---

## 1. Executive Summary & Final Verdict
- **Winner Declaration**: **Candidate B (Skill v4 with Code Freeze Rule & Companion Wrapper Audit)**
- **High-Level Rationale**:  
  Both candidates successfully diagnosed the root cause in `SelectableRegion` and implemented the required platform actions (`Look Up`, `Search Web`, and `Share`) on iOS. However, **Candidate B** demonstrated superior architectural completeness, testing rigor, and reactive execution:
  1. **Architectural & Platform Pattern Consistency**: In `SelectableRegionState.contextMenuButtonItems`, Candidate B implemented exhaustive platform-switch dispatching for `onLookUp` and `onSearchWeb` matching the established framework pattern of `onShare` and `onCopy` (`hideToolbar(false)` on iOS, `clearSelection()` on Android/Fuchsia, `hideToolbar()` on desktop). In contrast, Candidate A applied hardcoded unconditional `hideToolbar(false)` calls.
  2. **Assertion Rigor & Selection Handle Invariant Verification**: Candidate B's regression tests not only asserted button clicks, platform method channel invocations (`LookUp.invoke`, `SearchWeb.invoke`, `Share.invoke`), and toolbar dismissal, but also verified that the selection handles (`startHandleLayerLink`, `endHandleLayerLink`) and overlay remained active on iOS (ensuring selection is not destroyed when invoking iOS context menu actions).
  3. **Companion Design-System Wrapper & Code Freeze Audit**: Candidate B actively audited companion design-system wrappers (`AdaptiveTextSelectionToolbar`, `SelectionArea`), verified that `SelectableRegion` integrates seamlessly without requiring companion package split PRs in `flutter/packages`, and verified zero diff in frozen Material/Cupertino paths.
  4. **100% Reactive Execution (No Polling Traps)**: Candidate B operated 100% reactively without scheduling timers or polling tasks, completing the task in fewer planner turns (86 vs 91) and fewer tool calls (80 vs 89). Candidate A scheduled timers and performed active polling on a background test task via `manage_task status`.

---

## 2. Comparative Scorecard Table

| Dimension | Max Pts | Candidate A (Commit `7bb6d97c23`) | Candidate B (Commit `02d4860557`) | Notes / Observations |
| :--- | :---: | :---: | :---: | :--- |
| **1. Subsystem Routing & Architectural Precision** | 20 | 18 | 20 | Candidate B implemented exhaustive platform switch handling for toolbar dismissal matching `onShare` and audited companion wrappers. Candidate A used unconditional `hideToolbar(false)`. |
| **2. Test File Placement & Organization** | 20 | 19 | 20 | Both placed tests in `selectable_region_test.dart`. Candidate B verified selection handle persistence invariants on iOS. |
| **3. Avoidance of Flutter Text Testing Traps** | 25 | 20 | 25 | Candidate A used `schedule` and `manage_task status` to poll on background tests. Candidate B executed 100% reactively. |
| **4. Code Correctness & Cleanliness** | 15 | 14 | 15 | Both passed `dart analyze --fatal-infos` (0 issues) and `dart format`. Candidate B's platform switch matched existing codebase conventions exactly. |
| **5. Search Precision & Autonomous Discovery** | 10 | 9 | 10 | Both candidates autonomously activated `flutter-text-domain-expert/SKILL.md` at Step 6. Candidate B verified code-freeze invariants and companion wrappers directly. |
| **6. Quantitative Resource & Token Efficiency** | 10 | 9 | 9.5 | Candidate B achieved task completion in fewer planner turns (86 vs 91, -5.5%) and fewer tool calls (80 vs 89, -10.1%). |
| **Total Score** | **100** | **89** | **99.5** | **Candidate B Wins (+10.5 pts)** |

### Quantitative Metrics Summary

| Metric | Candidate A | Candidate B | Delta (%) |
| :--- | :---: | :---: | :---: |
| **Skill Triggered Automatically** | Yes (`SKILL.md` loaded at Step 6) | Yes (`SKILL.md` loaded at Step 6) | — |
| **Total Planner Turns** | 91 | 86 | -5.5% |
| **Total Tool Calls** | 89 | 80 | -10.1% |
| **Estimated Tokens** | 85,489 | 99,276 | +16.1% |
| **Distinct Files Viewed** | 8 | 9 | +12.5% |
| **Distinct Files Modified** | 2 | 2 | 0.0% |

---

## 3. Trajectory & Behavioral Comparison
- **Candidate A Investigation & Execution**:  
  Candidate A checked out commit `7bb6d97c23` and retrieved issue #141775. At Step 6, it autonomously consulted `flutter-text-domain-expert/SKILL.md` and at Step 8 `material-cupertino-packages/SKILL.md`. It identified `SelectableRegion.getSelectableButtonItems` and `SelectableRegionState` in `packages/flutter/lib/src/widgets/selectable_region.dart`. Candidate A added optional `onLookUp` and `onSearchWeb` callbacks to `getSelectableButtonItems` and enabled `platformCanShare`, `platformCanLookUp`, and `platformCanSearchWeb` for `TargetPlatform.iOS`. In `SelectableRegionState`, Candidate A added `_lookUp()` and `_searchWeb()` methods invoking `LookUp.invoke` and `SearchWeb.invoke` and wired `hideToolbar(false)` unconditionally. During test verification, Candidate A scheduled timers and called `manage_task status` across multiple steps (Steps 106–112) to poll on background tests. It added 3 regression tests in `selectable_region_test.dart` and verified `dart analyze --fatal-infos` and `dart format`.
- **Candidate B Investigation & Execution**:  
  Candidate B checked out commit `02d4860557` and retrieved issue #141775. At Step 6, it autonomously consulted `flutter-text-domain-expert/SKILL.md` and at Step 8 `material-cupertino-packages/SKILL.md`. Candidate B researched historical commits where `lookUpSelection`, `searchWebSelection`, and `shareSelection` were added to `EditableText` (`#130532`, `#131898`, `#132599`) to ensure complete contract parity. Candidate B evaluated whether changes to `SelectableRegion` required companion updates to design-system wrappers in `packages/flutter` or `flutter/packages`, confirming that `AdaptiveTextSelectionToolbar` dynamically adapts `ContextMenuButtonItem` types. Candidate B updated `SelectableRegion.getSelectableButtonItems` and implemented exhaustive platform switch dispatching for `onLookUp` and `onSearchWeb`. In `selectable_region_test.dart`, Candidate B added comprehensive tests checking button types, mock platform channel invocations, and selection handle persistence. It ran `git diff -w --ignore-blank-lines` across frozen Material/Cupertino paths, confirmed 0 diff, verified `dart analyze --fatal-infos` (0 issues), and ensured clean formatting without polling.

---

## 4. Key Strengths & Testing Pitfalls Observed
- **Direct Citations from Transcripts**:
  - *Candidate A Active Polling / Task Scheduling (Steps 106–112)*:
    ```
    [Step 106] tool=schedule args={'DurationSeconds': '15', 'Prompt': 'Check test completion', 'TimerCondition': 'task-107'}
    [Step 108] tool=manage_task args={'Action': 'status', 'TaskId': '6f55ae5d-.../task-107'}
    [Step 110] tool=manage_task args={'Action': 'status', 'TaskId': '6f55ae5d-.../task-107'}
    [Step 112] tool=schedule args={'DurationSeconds': '30', 'Prompt': 'Check test completion', 'TimerCondition': 'task-107'}
    ```
  - *Candidate B Companion Wrapper & Code Freeze Audit (Step 142)*:
    `tool=run_command args={'CommandLine': 'git diff -w --ignore-blank-lines packages/flutter/lib/src/material packages/flutter/lib/src/cupertino'}`

- **Architectural Differences**:
  - *Candidate A Toolbar Dismissal in [`selectable_region.dart`](file:///Users/roliv/flutter/packages/flutter/lib/src/widgets/selectable_region.dart)*:
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
  - *Candidate B Platform Switch Toolbar Dismissal in [`selectable_region.dart`](file:///Users/roliv/flutter/packages/flutter/lib/src/widgets/selectable_region.dart)*:
    ```dart
    onLookUp: () {
      _lookUp();
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
          clearSelection();
          _selectionStatusNotifier.value = SelectableRegionSelectionStatus.changing;
          _finalizeSelectableRegionStatus();
        case TargetPlatform.iOS:
          hideToolbar(false);
        case TargetPlatform.linux:
        case TargetPlatform.macOS:
        case TargetPlatform.windows:
          hideToolbar();
      }
    },
    onSearchWeb: () {
      _searchWeb();
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
          clearSelection();
          _selectionStatusNotifier.value = SelectableRegionSelectionStatus.changing;
          _finalizeSelectableRegionStatus();
        case TargetPlatform.iOS:
          hideToolbar(false);
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
    expect(buttonItems[2].type, ContextMenuButtonType.lookUp);
    buttonItems[2].onPressed?.call();
    expect(lastLookUp, 'are');
    expect(regionState.selectionOverlay?.toolbarIsVisible, isFalse);
    ```
  - *Candidate B Invariant Verification (Handles & Persistence)*:
    ```dart
    expect(buttonItems[2].type, ContextMenuButtonType.lookUp);
    buttonItems[2].onPressed?.call();
    expect(lastLookUp, 'are');
    // On iOS, look up should not clear the selection.
    expect(regionState.selectionOverlay, isNotNull);
    expect(regionState.selectionOverlay?.startHandleLayerLink, isNotNull);
    expect(regionState.selectionOverlay?.endHandleLayerLink, isNotNull);
    ```
