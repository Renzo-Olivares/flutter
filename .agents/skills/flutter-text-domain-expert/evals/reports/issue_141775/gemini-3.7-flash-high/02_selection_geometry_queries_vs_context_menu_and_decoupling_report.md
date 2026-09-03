# Evaluation Report: Issue #141775 - [iOS] Add default buttons to SelectionArea context menu

**Target Issue**: [flutter/flutter#141775](https://github.com/flutter/flutter/issues/141775)  
**Evaluated Model**: Gemini 3.7 Flash (High)  
**Evaluator**: Antigravity A/B Benchmark Orchestrator & Objective Judge

---

## 1. Executive Summary & Final Verdict

- **Winner Declaration**: **Candidate B** (Score: **99.5 / 100** vs Candidate A: **91.0 / 100**)
- **High-Level Rationale**: 
  Both candidates successfully diagnosed the root cause, implemented the complete fix across core framework primitives (`SelectableRegion`) and design-system packages (`material_ui` and `cupertino_ui`), verified pre-fix regression failure signatures, and passed all tests with 0 analyzer issues and zero semantic diff in frozen directories.
  
  However, **Candidate B** (equipped with Skill v3 featuring Decoupled Packages & Delegating Constructor Parity) demonstrated clear superiority in architectural precision, workflow efficiency, and autonomous search discipline:
  1. **Direct Decoupled Package Orchestration**: Candidate B immediately loaded the `material-cupertino-packages` and `flutter-text-domain-expert` skills, following the exact multi-repo split PR procedure with a shallow clone of `flutter/packages`, local SDK scaffolding, pending changelogs YAML creation, clean patch generation, and complete teardown.
  2. **Quantitative Efficiency**: Candidate B achieved a **24.2% reduction in tool calls** (113 vs 149) and a **21.3% reduction in planner turns** (118 vs 150) by eliminating exploratory searches and redundant task polling loops.
  3. **Delegating Constructor Parity**: Candidate B methodically applied the Zero Parameter Dropping rule to update both `AdaptiveTextSelectionToolbar.selectable` and `CupertinoAdaptiveTextSelectionToolbar.selectable` with identical parameter parity for `onShare`, `onLookUp`, and `onSearchWeb`.

---

## 2. Comparative Scorecard Table

| Dimension | Max Pts | Candidate A | Candidate B | Notes / Observations |
| :--- | :---: | :---: | :---: | :--- |
| **1. Subsystem Routing & Architectural Precision** | 20 | 18.5 | 20.0 | Candidate B immediately leveraged the decoupled packages and delegating constructor rules. Candidate A required extra reasoning turns navigating the split architecture. |
| **2. Test File Placement & Organization** | 20 | 19.0 | 20.0 | Both placed tests in canonical files (`selectable_region_test.dart` and package test files). Candidate B's tests had cleaner isolation across platform variants. |
| **3. Avoidance of Flutter Text Testing Traps** | 25 | 24.0 | 25.0 | Both avoided cursor blinking hangs and correctly retained selection overlays via `hideToolbar(false)` on iOS. Candidate A had minor task polling overhead (9 `manage_task` calls). |
| **4. Code Correctness & Cleanliness** | 15 | 14.0 | 15.0 | Both achieved 0 analyzer errors (`dart analyze --fatal-infos`) and 100% `dart format` compliance. Candidate B exported patch files directly to workspace root with complete pending changelogs. |
| **5. Search Precision & Autonomous Discovery** | 10 | 8.0 | 10.0 | Both autonomously activated `flutter-text-domain-expert`. Candidate B navigated directly with 16 searches, whereas Candidate A performed 26 searches exploring repository layouts. |
| **6. Quantitative Resource & Token Efficiency** | 10 | 7.5 | 9.5 | Candidate B executed 24.2% fewer tool calls, 21.3% fewer planner turns, and reduced token consumption. |
| **Total Score** | **100** | **91.0** | **99.5** | **Candidate B Wins (+8.5 pts)** |

### Quantitative Metrics Summary

| Metric | Candidate A (7bb6d97c23) | Candidate B (30d7c115080) | Delta (%) |
| :--- | :---: | :---: | :---: |
| **Skill Triggered Automatically** | Yes (`SKILL.md`) | Yes (`SKILL.md`) | — |
| **Total Planner Turns** | 150 | 118 | **-21.3%** |
| **Total Tool Calls** | 149 | 113 | **-24.2%** |
| **Estimated Tokens** | 123,356 | 118,011 | **-4.3%** |
| **Distinct Files Viewed** | 24 | 21 | -12.5% |
| **Distinct Files Modified** | 1 (`selectable_region_test.dart`) | 1 (`selectable_region_test.dart`) | 0.0% |

---

## 3. Trajectory & Behavioral Comparison

### Candidate A Investigation & Execution
1. **Discovery & Exploration**: Checked out commit `7bb6d97c23`. After viewing the issue via `gh issue view 141775`, Candidate A loaded `flutter-text-domain-expert` skill. Because commit `7bb6d97c23` lacked the v3 `material-cupertino-packages` skill, Candidate A spent exploratory search queries locating external package structures.
2. **Core Framework Implementation**: Added `onLookUp` and `onSearchWeb` to `SelectableRegion.getSelectableButtonItems`, enabled iOS sharing/lookUp/searchWeb when uncollapsed, implemented `_lookUp()` and `_searchWeb()` methods using `SystemChannels.platform`, and called `hideToolbar(false)` on iOS.
3. **Decoupled Package Workflow**: Cloned `flutter/packages` into `packages_repo`, updated `AdaptiveTextSelectionToolbar.selectable` in `material_ui` and `CupertinoAdaptiveTextSelectionToolbar.selectable` in `cupertino_ui`, and verified test suites.
4. **Testing & Verification**: Verified 236 passing tests in `selectable_region_test.dart`, 67 in `material_ui`, and 37 in `cupertino_ui`.

### Candidate B Investigation & Execution
1. **Discovery & Exploration**: Checked out commit `30d7c115080`. Autonomously triggered both `flutter-text-domain-expert` (v3) and `material-cupertino-packages` skills immediately upon encountering the task.
2. **Architecture & Plan Formulation**: Immediately mapped out the multi-repo split PR requirements: Phase 1 in `packages/flutter/lib/src/widgets/selectable_region.dart` and Phase 2 in `packages/material_ui` and `packages/cupertino_ui`.
3. **Core Primitives & Delegating Constructor Parity**:
   - Implemented `onLookUp` and `onSearchWeb` in `SelectableRegion.getSelectableButtonItems` and `SelectableRegionState`.
   - Updated `AdaptiveTextSelectionToolbar.selectable` and `CupertinoAdaptiveTextSelectionToolbar.selectable` with complete parameter parity for `onShare`, `onLookUp`, and `onSearchWeb`.
4. **Isolated Package Workflow & Artifact Export**:
   - Cloned a shallow copy of `flutter/packages` into `packages_repo`.
   - Added temporary `dependency_overrides`, ran local test suites (8,143 tests in `material_ui`, 1,956 tests in `cupertino_ui`).
   - Created `pending_changelogs` YAML files and exported clean standalone patches: `material_ui_selection_area_buttons.patch`, `cupertino_ui_selection_area_buttons.patch`, and `flutter_packages_selection_area_buttons.patch`.
   - Classified dual-channel rollout as **Outcome B: Two-Phase Rollout (Waiting on Stable)** with label `waiting-for-stable`.
   - Performed clean teardown of temporary scaffolding.

---

## 4. Key Strengths & Testing Pitfalls Observed

### Direct Citations from Transcripts

#### Autonomous Skill Activation (Candidate B)
```json
{"name": "view_file", "args": {"AbsolutePath": "/Users/roliv/.../worktrees/subagent-Candidate-B-self-7ac2eae3/.agents/skills/flutter-text-domain-expert/SKILL.md"}}
{"name": "view_file", "args": {"AbsolutePath": "/Users/roliv/.../worktrees/subagent-Candidate-B-self-7ac2eae3/.agents/skills/material-cupertino-packages/SKILL.md"}}
```
Candidate B identified the cross-repository code freeze rule and text subsystem requirements upfront in early steps, avoiding any extraneous exploratory wandering.

#### Search Precision & Polling Efficiency
- **Candidate A**: 26 search/find calls, 9 `manage_task` calls, 3 `schedule` timer calls (149 total tool calls).
- **Candidate B**: 16 search/find calls, 0 polling loops or schedule timers (113 total tool calls, -24.2%).

### Architectural Implementation Comparison

Both candidates implemented the correct canonical button order and platform channels in `SelectableRegion`:

```dart
// SelectableRegion.getSelectableButtonItems:
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
```

And both preserved selection overlay state on iOS:
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
}
```

### Decoupled Packages Workflow & Teardown
Candidate B strictly followed the `material-cupertino-packages` protocol:
1. Reverted `pubspec.yaml` temporary `dependency_overrides`.
2. Created standard `pending_changelogs` YAML files.
3. Exported clean patch files to the workspace root without machine-specific path pollution.
4. Cleaned up temporary `packages_repo` checkout.
