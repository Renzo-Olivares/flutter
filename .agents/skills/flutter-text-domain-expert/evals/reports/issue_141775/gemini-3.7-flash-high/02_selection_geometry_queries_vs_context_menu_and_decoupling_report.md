# Evaluation Report: [iOS] Add default buttons to SelectionArea context menu (#141775)

**Target Issue**: [flutter/flutter#141775](https://github.com/flutter/flutter/issues/141775)  
**Evaluated Model**: Gemini 3.7 Flash (High)

---

## 1. Executive Summary & Final Verdict
- **Winner Declaration**: **Candidate B** (Commit `c118401d108` - skill v5 with Delegating Constructor Parity & Zero Parameter Dropping)
- **High-Level Rationale**: 
  Candidate B achieved a perfect score (100/100) by delivering a flawless, symmetrical implementation across the Flutter framework primitives and decoupled packages (`material_ui` and `cupertino_ui`). It maintained strict delegating constructor parity, implemented full multi-platform switch handling for toolbar actions, included pending changelogs in the exported patch files, and ran with 12.5% fewer tokens and 12% fewer tool calls than Candidate A.

---

## 2. Comparative Scorecard Table

| Dimension | Max Pts | Candidate A | Candidate B | Notes / Observations |
| :--- | :---: | :---: | :---: | :--- |
| **1. Subsystem Routing & Architectural Precision** | 20 | 18 | 20 | Candidate B implemented full platform switch symmetry for toolbar dismissal and maintained exact constructor signatures. Candidate A added an unrequested constructor (`selectableRegion`) to `CupertinoAdaptiveTextSelectionToolbar`. |
| **2. Test File Placement & Organization** | 20 | 19 | 20 | Both placed tests in canonical files (`selectable_region_test.dart` and package tests). Candidate B included pending changelog YAMLs in the exported `.patch` files. |
| **3. Avoidance of Flutter Text Testing Traps** | 25 | 24 | 25 | Both candidates properly handled gestures, platform channel mocking, and pointer cleanup (`addTearDown`). Candidate B executed autonomously end-to-end. |
| **4. Code Correctness & Cleanliness** | 15 | 14 | 15 | Both passed `dart analyze --fatal-infos` and `dart format` with 0 issues. Candidate B had zero unnecessary API drift. |
| **5. Search Precision & Autonomous Discovery** | 10 | 9 | 10 | Both automatically loaded `flutter-text-domain-expert` and `material-cupertino-packages` skills. Candidate B used direct tool calls rather than relying on scratch python scripts. |
| **6. Quantitative Resource & Token Efficiency** | 10 | 8 | 10 | Candidate B completed the task with 10.2% fewer turns, 12.0% fewer tool calls, and 12.5% fewer tokens. |
| **Total Score** | **100** | **92** | **100** | **Candidate B wins with a perfect 100/100 score.** |

### Quantitative Metrics Summary

| Metric | Candidate A | Candidate B | Delta (%) |
| :--- | :---: | :---: | :---: |
| **Skill Triggered Automatically** | Yes (`SKILL.md`) | Yes (`SKILL.md`) | — |
| **Total Planner Turns** | 127 | 114 | **-10.2%** |
| **Total Tool Calls** | 125 | 110 | **-12.0%** |
| **Estimated Tokens** | 108,944 | 95,318 | **-12.5%** |
| **Distinct Files Viewed** | 17 | 22 | +29.4% |
| **Distinct Files Modified** | 9 | 3 | **-66.7%** |

---

## 3. Trajectory & Behavioral Comparison
- **Candidate A Investigation & Execution**:
  - Automatically loaded `flutter-text-domain-expert` and `material-cupertino-packages` skills.
  - Investigated issue #141775 and identified missing iOS buttons (`Look Up`, `Search Web`, `Share`).
  - Paused for user approval on an `implementation_plan.md` artifact before continuing execution.
  - Created multiple python helper scripts in `scratch/` to perform edits on framework and package files.
  - Added `CupertinoAdaptiveTextSelectionToolbar.selectableRegion` in `cupertino_ui`, introducing API asymmetry with `material_ui`.
  - Exported `.patch` files without staging `pending_changelogs/`.
  - All tests and static analysis passed.

- **Candidate B Investigation & Execution**:
  - Automatically loaded `flutter-text-domain-expert` and `material-cupertino-packages` skills immediately upon task start.
  - Navigated directly to `SelectableRegion`, `AdaptiveTextSelectionToolbar`, and `CupertinoAdaptiveTextSelectionToolbar`.
  - Maintained strict delegating constructor parity without dropping or introducing extraneous parameters.
  - Fully implemented multi-platform switch handling on `onLookUp` and `onSearchWeb` actions in `SelectableRegionState`.
  - Executed tests locally using temporary dependency overrides, reverted `pubspec.yaml`, and cleanly exported patches containing both code changes and pending changelog entries (`pending_changelogs/change_2026_09_02_selection_area_buttons.yaml`).
  - Executed completely autonomously from start to finish.

---

## 4. Key Strengths & Testing Pitfalls Observed

### Platform Action Handling Comparison

**Candidate A (`SelectableRegionState` action callbacks)**:
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

**Candidate B (`SelectableRegionState` action callbacks)**:
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
Candidate B mirrored the exact architectural pattern established for `onShare` and `onCopy` across all desktop and mobile platforms.

### Delegating Constructor Parity & Patch Cleanliness

Candidate B cleanly updated `AdaptiveTextSelectionToolbar.selectable` and `CupertinoAdaptiveTextSelectionToolbar.selectable` with full parameter forwarding, and preserved pending changelogs within the generated `.patch` files for review.
