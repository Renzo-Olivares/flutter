# Evaluation Report: [iOS] Add default buttons to SelectionArea context menu (#141775)

**Target Issue**: [flutter/flutter#141775](https://github.com/flutter/flutter/issues/141775)  
**Evaluated Model**: Gemini 3.7 Flash (High)  
**Candidate A**: Commit `7bb6d97c23` (Skill v3 with SelectionGeometry queries)  
**Candidate B**: Commit `467bac7063` (Skill v4 with Code Freeze Rule & Material/Cupertino Decoupling Skill)  

---

## 1. Executive Summary & Final Verdict
- **Winner Declaration**: **Candidate B**
- **High-Level Rationale**:
  - **Test Robustness & Semantic Querying**: Candidate B utilized semantic item lookup (`buttonItems.firstWhere((item) => item.type == ContextMenuButtonType.share)`) in its action-triggering regression tests rather than hardcoded index access (`buttonItems[4]`), while still strictly verifying the exact 5-button order in `builds the correct button items`.
  - **Investigation Precision**: Candidate B directly used git history queries on platform channels (`git log -n 5 -p --grep="LookUp.invoke"`) to discover platform integration patterns without exploratory wandering.
  - **Autonomous Planning & Compliance**: Candidate B created a thorough implementation plan and walkthrough artifact, following all rules and verifying static analysis (`dart analyze --fatal-infos`) and formatting (`dart format`).
  - **Quantitative Resource & Token Efficiency**: Candidate B achieved lower resource consumption across the board: **3.9% fewer planner steps** (73 vs 76), **2.8% fewer tool calls** (70 vs 72), and **7.3% fewer tokens** (58,423 vs 63,001).

---

## 2. Comparative Scorecard Table

| Dimension | Max Pts | Candidate A | Candidate B | Notes / Observations |
| :--- | :---: | :---: | :---: | :--- |
| **1. Subsystem Routing & Architectural Precision** | 20 | 20 | 20 | Both correctly identified [`SelectableRegion`](file:///Users/roliv/flutter/packages/flutter/lib/src/widgets/selectable_region.dart), added `onLookUp` and `onSearchWeb` callbacks, and implemented `_lookUp()` and `_searchWeb()` on `SelectableRegionState` using `SystemChannels.platform`. |
| **2. Test File Placement & Organization** | 20 | 19 | 20 | Both placed tests in [`packages/flutter/test/widgets/selectable_region_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/widgets/selectable_region_test.dart). Candidate B used robust semantic lookup (`firstWhere`) for action execution tests. |
| **3. Avoidance of Flutter Text Testing Traps** | 25 | 25 | 25 | Both correctly used `pump(kLongPressTimeout)`, registered `addTearDown` channel cleanup, and asserted selection overlay retention (`regionState.selectionOverlay != null`). |
| **4. Code Correctness & Cleanliness** | 15 | 15 | 15 | Both passed `dart analyze --fatal-infos` with 0 warnings/errors and formatted all files with `dart format`. |
| **5. Search Precision & Autonomous Discovery** | 10 | 9 | 10 | Both autonomously loaded `SKILL.md` early in their trajectories. Candidate B navigated faster via git log searches for platform channel invocations. |
| **6. Quantitative Resource & Token Efficiency** | 10 | 9 | 10 | Candidate B was more efficient across steps (73 vs 76, -3.9%), tool calls (70 vs 72, -2.8%), and tokens (58,423 vs 63,001, -7.3%). |
| **Total Score** | **100** | **92** | **100** | **Winner: Candidate B** |

### Quantitative Metrics Summary

| Metric | Candidate A (`7bb6d97c23`) | Candidate B (`467bac7063`) | Delta (%) |
| :--- | :---: | :---: | :---: |
| **Skill Triggered Automatically** | Yes (Loaded: `SKILL.md`) | Yes (Loaded: `SKILL.md`) | Identical |
| **Total Planner Turns** | 76 | 73 | **-3.9%** (Candidate B) |
| **Total Tool Calls** | 72 | 70 | **-2.8%** (Candidate B) |
| **Estimated Tokens** | 63,001 | 58,423 | **-7.3%** (Candidate B) |
| **Distinct Files Viewed** | 10 | 10 | Identical |
| **Distinct Files Modified** | 2 | 2 (+2 artifacts) | Identical |

---

## 3. Trajectory & Behavioral Comparison

### Candidate A Investigation & Execution
- **Investigation**: Inspected issue #141775, read `.agents/skills/flutter-text-domain-expert/SKILL.md` at turn 8, and explored `selectable_region.dart` and `editable_text.dart`.
- **Root Cause Analysis**: Identified that `SelectableRegion.getSelectableButtonItems` disabled `platformCanShare` on iOS (`TargetPlatform.iOS => false`) and lacked `onLookUp` / `onSearchWeb` callbacks.
- **Implementation**:
  - Added optional `onLookUp` and `onSearchWeb` parameters to `SelectableRegion.getSelectableButtonItems`.
  - Enabled `platformCanShare`, `platformCanLookUp`, and `platformCanSearchWeb` for `TargetPlatform.iOS` when selection is uncollapsed.
  - Added `_lookUp()` and `_searchWeb()` methods invoking `SystemChannels.platform.invokeMethod` on `SelectableRegionState`.
  - Wired `onLookUp` and `onSearchWeb` into `SelectableRegionState.contextMenuButtonItems` calling `hideToolbar(false)`.
- **Testing**:
  - Updated `builds the correct button items` on iOS to check 5 button items.
  - Added 3 regression tests for Share, Look Up, and Search Web in `packages/flutter/test/widgets/selectable_region_test.dart`.
  - Used index-based lookups (`buttonItems[4]`, `buttonItems[2]`, `buttonItems[3]`) in the action tests.
- **Quality & Validation**: Passed `dart analyze --fatal-infos` and `dart format`.

### Candidate B Investigation & Execution
- **Investigation**: Read issue #141775, loaded `.agents/skills/flutter-text-domain-expert/SKILL.md` at turn 6, searched for `LookUp.invoke` and `SearchWeb.invoke` using `git log`, and inspected `selectable_region.dart`.
- **Planning**: Generated a structured `implementation_plan.md` artifact outlining the exact edits and regression testing strategy before executing.
- **Implementation**:
  - Updated `SelectableRegion.getSelectableButtonItems` with `onLookUp`, `onSearchWeb`, and enabled iOS for Share, Look Up, and Search Web.
  - Implemented `_lookUp()` and `_searchWeb()` on `SelectableRegionState` communicating via `SystemChannels.platform`.
  - Configured `SelectableRegionState.contextMenuButtonItems` to invoke `_lookUp()` and `_searchWeb()` with `hideToolbar(false)`.
- **Testing**:
  - Updated `builds the correct button items` on iOS to verify full 5-item order `[copy, selectAll, lookUp, searchWeb, share]`.
  - Added 3 regression tests for Share, Look Up, and Search Web using `buttonItems.firstWhere((item) => item.type == ContextMenuButtonType...)`.
  - Verified exact failure signatures before implementing the fix (`Bad state: No element` and `Expected: <5>, Actual: <2>`).
- **Quality & Validation**: Ran full test suite in `selectable_region_test.dart` (230 passed), passed `dart analyze --fatal-infos` with zero errors, and verified formatting with `dart format`.

---

## 4. Key Strengths & Testing Pitfalls Observed

### Test Robustness & Decoupled Invariant Verification
- **Candidate B** used semantic type matching with `firstWhere` when testing action triggers:
```dart
// Candidate B: Semantic lookup prevents coupling action tests to index positions
final ContextMenuButtonItem shareButton = buttonItems.firstWhere(
  (ContextMenuButtonItem item) => item.type == ContextMenuButtonType.share,
);
shareButton.onPressed?.call();
expect(lastShare, 'are');
```
- In contrast, **Candidate A** relied on fixed list indexing:
```dart
// Candidate A: Fixed index access
expect(buttonItems[4].type, ContextMenuButtonType.share);
buttonItems[4].onPressed?.call();
```

### Platform Selection Overlay Retention
Both candidates correctly ensured that invoking iOS system actions (`Share`, `Look Up`, `Search Web`) does not collapse or destroy active selection handles:
```dart
expect(regionState.selectionOverlay, isNotNull);
expect(regionState.selectionOverlay?.startHandleLayerLink, isNotNull);
expect(regionState.selectionOverlay?.endHandleLayerLink, isNotNull);
```

### Clean Mock Channel Teardown
Both candidates registered proper teardown callbacks to avoid test pollution across the widget test suite:
```dart
addTearDown(
  () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    null,
  ),
);
```
