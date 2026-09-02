# Evaluation Report: Add default buttons to SelectionArea context menu on iOS (Issue #141775)

**Target Issue**: [flutter/flutter#141775](https://github.com/flutter/flutter/issues/141775)  
**Evaluated Model**: Gemini 3.7 Flash (High)  
**Candidate A**: Commit `7bb6d97c23` (skill v3 with SelectionGeometry queries)  
**Candidate B**: Commit `06ee13d97df` (skill v5 with Adjacent Customizable API Audit & Self-Contained Packages Workflow)  

---

## 1. Executive Summary & Final Verdict
- **Winner Declaration**: **Candidate B**
- **Score**: **98.5 / 100** (Candidate B) vs **90.5 / 100** (Candidate A)
- **High-Level Rationale**: Both candidates successfully reproduced the issue, identified the root cause in `SelectableRegion`, implemented the missing iOS context menu actions (`Look Up`, `Search Web`, `Share`), and passed static analysis and unit tests. However, **Candidate B** achieved superior architectural completeness and test rigor:
  1. **Autonomous Skill Activation**: Candidate B autonomously discovered and loaded `flutter-text-domain-expert`, while Candidate A did not trigger the domain skill.
  2. **Architectural Parity**: Candidate B implemented full cross-platform dispatch in `SelectableRegionState.contextMenuButtonItems` (handling selection clearing on Android/Fuchsia, preserving handle overlay on iOS via `hideToolbar(false)`, and hiding toolbar on desktop), matching the exact architectural pattern established for `onCopy` and `onShare`. In contrast, Candidate A hardcoded `hideToolbar(false)` unconditionally.
  3. **Comprehensive Geometry Test Matrix**: In addition to end-to-end tap and channel invocation tests, Candidate B added a comprehensive unit test suite covering uncollapsed, collapsed, and empty `SelectionGeometry` permutations across all target platforms (`TargetPlatformVariant.all()`).

---

## 2. Comparative Scorecard Table

| Dimension | Max Pts | Candidate A | Candidate B | Notes / Observations |
| :--- | :---: | :---: | :---: | :--- |
| **1. Subsystem Routing & Architectural Precision** | 20 | 18.0 | 20.0 | Candidate B implemented full platform-switch behavior in `onLookUp` and `onSearchWeb` identical to `onCopy`/`onShare`. Candidate A hardcoded `hideToolbar(false)`. |
| **2. Test File Placement & Organization** | 20 | 18.0 | 20.0 | Both placed tests in `selectable_region_test.dart`. Candidate B added a dedicated unit test covering `SelectionGeometry` states across all platforms. |
| **3. Avoidance of Flutter Text Testing Traps** | 25 | 24.0 | 25.0 | Both correctly used `TestDefaultBinaryMessengerBinding` with `addTearDown`, avoided timer hangs, and simulated gestures cleanly. |
| **4. Code Correctness & Cleanliness** | 15 | 14.0 | 15.0 | Both achieved 0 analyzer errors/lints and 0 formatting diffs. Candidate B proactively fixed subtle lints (`omit_obvious_local_variable_types`). |
| **5. Search Precision & Autonomous Discovery** | 10 | 7.0 | 10.0 | Candidate B autonomously triggered and read `flutter-text-domain-expert/SKILL.md`. Candidate A did not trigger the text domain skill. |
| **6. Quantitative Resource & Token Efficiency** | 10 | 9.5 | 8.5 | Candidate A was slightly leaner (85 steps / 72.7k tokens vs 96 steps / 81.0k tokens), but Candidate B's extra turns were high-value (lint fixes + matrix tests). |
| **Total Score** | **100** | **90.5** | **98.5** | **Candidate B Wins (+8.0 pts)** |

### Quantitative Metrics Summary

| Metric | Candidate A | Candidate B | Delta (%) |
| :--- | :---: | :---: | :---: |
| **Skill Triggered Automatically** | No | Yes (`SKILL.md`) | — |
| **Total Planner Turns** | 85 | 96 | +12.9% |
| **Total Tool Calls** | 82 | 93 | +13.4% |
| **Estimated Tokens** | 72,767 | 80,994 | +11.3% |
| **Distinct Files Viewed** | 10 | 8 | -20.0% |
| **Distinct Files Modified** | 2 | 2 | 0.0% |
| **Analyzer Compliance** | Clean (0 issues) | Clean (0 issues) | — |
| **Test Suite Results** | 230 / 230 passed | 236 / 236 passed | +6 tests |

---

## 3. Trajectory & Behavioral Comparison

### Candidate A Investigation & Execution:
- **Skill Triggering**: Candidate A checked rules and read `material-cupertino-packages/SKILL.md`, but never loaded `flutter-text-domain-expert/SKILL.md`.
- **Search & Root Cause Discovery**: Candidate A used grep searches on test files for `LookUp.invoke`, `Share.invoke`, and `ContextMenuButtonType.lookUp`. It inspected `selectable_region.dart` and `editable_text.dart` to understand how context menu items and platform channels were wired.
- **Implementation**: Candidate A added `onLookUp` and `onSearchWeb` to `SelectableRegion.getSelectableButtonItems`, enabled `platformCanShare`, `platformCanLookUp`, and `platformCanSearchWeb` on iOS, and added `_lookUp()` and `_searchWeb()` methods in `SelectableRegionState`. However, in `contextMenuButtonItems`, it directly passed `hideToolbar(false)` without platform-specific switching.
- **Verification**: Candidate A updated `builds the correct button items` and added 3 widget tests for clicking Share, Look Up, and Search Web on iOS. Verified with `dart analyze --fatal-infos` and `flutter test`.

### Candidate B Investigation & Execution:
- **Skill Triggering**: Candidate B immediately recognized the text selection context and autonomously triggered and loaded `flutter-text-domain-expert/SKILL.md` along with `code-freeze.md` and `dart-editing.md`.
- **Search & Root Cause Discovery**: Candidate B followed the domain guidance, inspecting `packages/flutter/lib/src/widgets/selectable_region.dart` and comparing with `editable_text.dart`. It verified that the issue resided in framework core `widgets/` rather than design-system libraries, respecting the code freeze boundaries.
- **Implementation**: Candidate B added `onLookUp` and `onSearchWeb` to `SelectableRegion.getSelectableButtonItems` and fully implemented platform-aware lifecycle handling in `contextMenuButtonItems` (preserving selection overlay on iOS via `hideToolbar(false)`, clearing selection on Android/Fuchsia, and dismissing toolbar on desktop).
- **Verification**: Candidate B added 3 widget interaction tests, updated `builds the correct button items`, and authored a dedicated `SelectableRegion.getSelectableButtonItems returns the correct button items for platform` test covering collapsed/uncollapsed/empty geometries across all platform variants. It resolved all lints (`omit_obvious_local_variable_types`, `avoid_redundant_argument_values`) and ran full analyzer passes.

---

## 4. Key Strengths & Testing Pitfalls Observed

### Direct Citations from Transcripts:
1. **Candidate B Skill Discovery**:
   Candidate B identified domain relevance and loaded `.agents/skills/flutter-text-domain-expert/SKILL.md`, allowing it to align its implementation with framework design rules and selection geometry patterns.
2. **Proper Channel Teardown in Tests**:
   Both candidates correctly avoided binary messenger handler leaks across test runs by wrapping teardown:
   ```dart
   addTearDown(
     () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
       SystemChannels.platform,
       null,
     ),
   );
   ```

### Architectural Differences:

#### Candidate A: `SelectableRegionState.contextMenuButtonItems`
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
*Note: Unconditionally executes `hideToolbar(false)` on all platforms rather than adapting behavior to target platform conventions.*

#### Candidate B: `SelectableRegionState.contextMenuButtonItems`
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
```
*Note: Correctly follows the existing architectural convention established for `onCopy` and `onShare`, ensuring uniform behavior if `onLookUp` is ever enabled or triggered on other platforms.*
