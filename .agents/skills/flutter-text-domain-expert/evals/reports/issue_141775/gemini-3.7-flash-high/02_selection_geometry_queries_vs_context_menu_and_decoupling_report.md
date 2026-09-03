# Evaluation Report: Flutter Issue #141775 (iOS Look Up, Search Web, Share in SelectionArea)

**Target Issue**: [flutter/flutter#141775](https://github.com/flutter/flutter/issues/141775)  
**Evaluated Model**: Gemini 3.7 Flash (High)  
**Evaluated Candidates**:
- **Candidate A**: Commit `7bb6d97c23` (Skill v2 with SelectionGeometry queries)
- **Candidate B**: Commit `30d7c115080` (Skill v3 with Decoupled Packages & Delegating Constructor Parity)

---

## 1. Executive Summary & Final Verdict
- **Winner Declaration**: **Candidate B**
- **High-Level Rationale**:
  - **Candidate B** achieved near-perfect architectural precision (Score: **98/100**). It correctly adhered to the Material and Cupertino Code Freeze Rule in `flutter/flutter`, applying core primitive changes strictly in `packages/flutter/lib/src/widgets/selectable_region.dart` and `packages/flutter/test/widgets/selectable_region_test.dart`. It properly transitioned design-system changes (`AdaptiveTextSelectionToolbar` and `CupertinoAdaptiveTextSelectionToolbar`) to `flutter/packages` (`material_ui` and `cupertino_ui`), introduced the delegating `.selectableRegion` constructor, updated CHANGELOGs, bumped versions, and exported a clean `.patch` file.
  - **Candidate A** (Score: **81/100**) produced a functionally sound fix for the core primitives but violated the `flutter/flutter` Code Freeze Rule by directly editing frozen files under `packages/flutter/lib/src/material/`, `packages/flutter/lib/src/cupertino/`, and their corresponding test suites instead of decoupling the changes to `flutter/packages`.

---

## 2. Comparative Scorecard Table

| Dimension | Max Pts | Candidate A | Candidate B | Notes / Observations |
| :--- | :---: | :---: | :---: | :--- |
| **1. Subsystem Routing & Architectural Precision** | 20 | 12 | 20 | Candidate B respected multi-repo split PR architecture and added `.selectableRegion` delegating constructors. Candidate A modified frozen Material/Cupertino paths in `flutter/flutter`. |
| **2. Test File Placement & Organization** | 20 | 14 | 20 | Candidate B isolated widget primitive tests in `selectable_region_test.dart` and design system tests in `cupertino_ui`/`material_ui`. Candidate A modified frozen test files in `flutter/flutter`. |
| **3. Avoidance of Flutter Text Testing Traps** | 25 | 25 | 25 | Both candidates demonstrated excellent grasp of text testing: realistic gesture sequences, platform channel mocking with teardowns, and avoiding pumpAndSettle cursor hangs. |
| **4. Code Correctness & Cleanliness** | 15 | 14 | 15 | Both passed `dart analyze --fatal-infos` and `dart format` cleanly. Candidate B included extra defensive null/empty string guards on selected content. |
| **5. Search Precision & Autonomous Discovery** | 10 | 7 | 10 | Candidate B discovered and fully followed the `material-cupertino-packages` decoupled workflow and verified zero-diff frozen invariants. Candidate A missed the freeze requirement. |
| **6. Quantitative Resource & Token Efficiency** | 10 | 9 | 8 | Candidate A was faster and used fewer tokens solely because it skipped cloning `flutter/packages` and executing multi-repo split PR workflows. Candidate B's usage was well-justified. |
| **Total Score** | **100** | **81** | **98** | **Candidate B decisively wins on architecture, adherence to repository rules, and split PR decoupling.** |

### Quantitative Metrics Summary

| Metric | Candidate A | Candidate B | Delta (%) |
| :--- | :---: | :---: | :---: |
| **Skill Triggered Automatically** | Yes (`flutter-text-domain-expert`) | Yes (`flutter-text-domain-expert`) | 0.0% |
| **Total Planner Turns** | 115 | 142 | +23.5% |
| **Total Tool Calls** | 107 | 139 | +29.9% |
| **Estimated Tokens** | 91,242 | 163,057 | +78.7% |
| **Distinct Files Viewed** | 12 | 21 | +75.0% |
| **Distinct Files Modified** | 3 (in worktree) | 1 (in worktree) + patch | -66.7% |

---

## 3. Trajectory & Behavioral Comparison

### Candidate A Investigation & Execution
1. **Initial Exploration**: Ran `gh issue view 141775 --repo flutter/flutter` and read `flutter-text-domain-expert/SKILL.md` and `material-cupertino-packages/SKILL.md`.
2. **Implementation**:
   - Extended `SelectableRegion.getSelectableButtonItems` with `onLookUp` and `onSearchWeb` callbacks, and updated `_lookUp` / `_searchWeb` methods via `SystemChannels.platform`.
   - Modified `packages/flutter/lib/src/material/adaptive_text_selection_toolbar.dart` and `packages/flutter/lib/src/cupertino/adaptive_text_selection_toolbar.dart` directly inside the `flutter/flutter` repository.
3. **Testing**:
   - Added regression tests in `packages/flutter/test/widgets/selectable_region_test.dart`.
   - Added tests in `packages/flutter/test/cupertino/adaptive_text_selection_toolbar_test.dart`, `packages/flutter/test/material/adaptive_text_selection_toolbar_test.dart`, and `packages/flutter/test/material/selection_area_test.dart`.
4. **Pitfall / Violation**:
   - Candidate A failed to adhere to the Material and Cupertino Code Freeze rule in `flutter/flutter`, directly modifying 5 frozen files in the main repository.

### Candidate B Investigation & Execution
1. **Initial Exploration**:
   - Inspected `gh issue view 141775 --repo flutter/flutter`.
   - Read `material-cupertino-packages/SKILL.md` and `flutter-text-domain-expert/SKILL.md`.
   - Investigated git commit history for previous button additions (`132599`, `130532`, `131898`) to inspect the historical pattern of context menu items.
2. **Implementation**:
   - **`flutter/flutter`**: Modified only `packages/flutter/lib/src/widgets/selectable_region.dart` and `packages/flutter/test/widgets/selectable_region_test.dart`.
   - **`flutter/packages`**: Cloned `flutter/packages`, modified `cupertino_ui` and `material_ui`, added the new delegating `.selectableRegion` constructor to `CupertinoAdaptiveTextSelectionToolbar`, updated version numbers (`1.0.2` and `1.1.1`), and added `CHANGELOG.md` entries.
   - **Artifact**: Exported `flutter_packages_selection_area_ios_buttons.patch` for the split PR.
3. **Testing & Invariant Verification**:
   - Ran all tests in `selectable_region_test.dart` (234 tests passed).
   - Ran all tests in `cupertino_ui` (1,962 tests passed) and `material_ui` (8,147 tests passed).
   - Explicitly ran `git diff -w --ignore-blank-lines packages/flutter/lib/src/material packages/flutter/lib/src/cupertino ...` to confirm zero diff in frozen folders.

---

## 4. Key Strengths & Testing Pitfalls Observed

### Direct Citations from Transcripts

#### 1. Zero-Diff Frozen Folder Verification (Candidate B)
Candidate B verified the invariant explicitly before completing its work:
```bash
git diff -w --ignore-blank-lines packages/flutter/lib/src/material packages/flutter/lib/src/cupertino packages/flutter/test/material packages/flutter/test/cupertino
```
*Result: Empty diff, confirming zero changes to frozen directories in `flutter/flutter`.*

#### 2. Realistic Gesture Lifecycle Isolation (Both Candidates)
Both candidates correctly implemented gesture simulations using `startGesture`, `pump(kLongPressTimeout)` / `pump(const Duration(milliseconds: 500))`, and `addTearDown(gesture.removePointer)` rather than relying on brittle taps:
```dart
final TestGesture gesture = await tester.startGesture(textOffsetToPosition(paragraph, 6));
addTearDown(gesture.removePointer);
await tester.pump(const Duration(milliseconds: 500));
expect(paragraph.selections[0], const TextSelection(baseOffset: 4, extentOffset: 7));
await gesture.up();
await tester.pumpAndSettle();
```

#### 3. Delegating Constructor Parity (`CupertinoAdaptiveTextSelectionToolbar.selectableRegion`)
Candidate B recognized that while `AdaptiveTextSelectionToolbar.selectableRegion` existed, `CupertinoAdaptiveTextSelectionToolbar` lacked a `.selectableRegion` constructor taking `selectableRegionState`:
```dart
CupertinoAdaptiveTextSelectionToolbar.selectableRegion({
  super.key,
  required SelectableRegionState selectableRegionState,
}) : children = null,
     buttonItems = selectableRegionState.contextMenuButtonItems,
     anchors = selectableRegionState.contextMenuAnchors;
```

---

## 5. Conclusion
Candidate B's skill update (Decoupled Packages & Delegating Constructor Parity) successfully guided the agent to complete the entire multi-repo contribution lifecycle without violating repository code freeze rules. Candidate B is declared the decisive winner.
