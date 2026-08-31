# Evaluation Report: Look Up, Search Web, and Share on SelectionArea on iOS (#141775)

**Target Issue**: [flutter/flutter#141775](https://github.com/flutter/flutter/issues/141775)  
**Evaluated Model**: Gemini 3.7 Flash (High)

---

## 1. Executive Summary & Final Verdict
- **Winner Declaration**: **Candidate B (Treatment — With Skill)**
- **High-Level Rationale**: Both candidates successfully identified the root cause in `SelectableRegion` and `AdaptiveTextSelectionToolbar` and implemented correct fixes that passed analysis and all regression tests. However, **Candidate B** demonstrated superior architectural rigor and test layer discipline:
  1. **Autonomous Skill Activation**: Candidate B autonomously recognized the text domain challenge and activated `flutter-text-domain-expert` at Turn 3.
  2. **Canonical Widget Test Placement**: Candidate B placed its core regression tests directly in the canonical widget test suite (`packages/flutter/test/widgets/selectable_region_test.dart`) using `TestWidgetsApp`, avoiding improper layer coupling to Material, and asserting that selection handles/overlay remain intact post-interaction (`regionState.selectionOverlay, isNotNull`). In contrast, Candidate A placed its primary tests inside `packages/flutter/test/material/selection_area_test.dart`.
  3. **Token & Resource Efficiency**: Candidate B completed the entire workflow with **7.9% lower token consumption** (101,766 vs 110,442 estimated tokens) while maintaining 0 analyzer warnings and complete test pass rates.

---

## 2. Comparative Scorecard Table

| Dimension | Max Pts | Candidate A (Baseline) | Candidate B (With Skill) | Notes / Observations |
| :--- | :---: | :---: | :---: | :--- |
| **1. Subsystem Routing & Architectural Precision** | 20 | 20 | 20 | Both candidates cleanly routed between `SelectableRegion`, `AdaptiveTextSelectionToolbar`, and platform channels (`LookUp.invoke`, `SearchWeb.invoke`, `Share.invoke`) with proper `hideToolbar(false)` behavior. |
| **2. Test File Placement & Organization** | 20 | 18 | 20 | Candidate B placed core regression tests in the canonical widget test file (`test/widgets/selectable_region_test.dart`) using `TestWidgetsApp`. Candidate A placed tests in Material's `test/material/selection_area_test.dart`. |
| **3. Avoidance of Flutter Text Testing Traps** | 25 | 24 | 25 | Both avoided timer hangs and gesture traps. Candidate B specifically verified selection overlay handle preservation post-click. |
| **4. Code Correctness & Cleanliness** | 15 | 15 | 15 | Both achieved 0 analyzer errors (`dart analyze --fatal-infos`) and passed `dart format`. |
| **5. Search Precision & Autonomous Discovery** | 10 | 8 | 10 | Candidate B immediately activated `flutter-text-domain-expert` on Step 3; Candidate A relied on broader exploratory search queries. |
| **6. Quantitative Resource & Token Efficiency** | 10 | 8.5 | 9.5 | Candidate B achieved a 7.9% reduction in token usage over Candidate A. |
| **Total Score** | **100** | **88.5** | **99.5** | **Candidate B wins by +11.0 points.** |

### Quantitative Metrics Summary

| Metric | Candidate A (Baseline) | Candidate B (With Skill) | Delta (%) |
| :--- | :---: | :---: | :---: |
| **Skill Triggered Automatically** | No | Yes (Turn 3) | N/A |
| **Total Planner Turns** | 121 | 128 | +5.8% |
| **Total Tool Calls** | 117 | 123 | +5.1% |
| **Estimated Tokens** | 110,442 | 101,766 | -7.9% |
| **Distinct Files Viewed** | 12 | 14 | +16.7% |
| **Distinct Files Modified** | 7 | 6 | -14.3% |

---

## 3. Trajectory & Behavioral Comparison
- **Candidate A Investigation & Execution**:
  - Started by checking out base commit `67710a5db2adcae7e5ad606c7f5001108e037672` and viewing issue #141775.
  - Performed multiple text searches across `packages/flutter` for `lookUp`, `getAdaptiveButtons`, and `contextMenuButtonItems`.
  - Implemented the fix across `selectable_region.dart`, `adaptive_text_selection_toolbar.dart` (Material and Cupertino).
  - Wrote regression tests in `packages/flutter/test/material/selection_area_test.dart` and `packages/flutter/test/cupertino/adaptive_text_selection_toolbar_test.dart`.
  - Encountered an unexpected failure during broader testing in `packages/flutter/test/widgets/selectable_region_test.dart` due to hardcoded button count assertions (changed from 2 to 5 on iOS), which required a follow-up fix turn.
- **Candidate B Investigation & Execution**:
  - Started by checking out base commit `19261190bad200063c67b57d550811b0f3f4773a` and viewing issue #141775.
  - At Turn 3, autonomously inspected `.agents/skills/flutter-text-domain-expert/SKILL.md` to reference text subsystem patterns and testing guidelines.
  - Directly identified `packages/flutter/test/widgets/selectable_region_test.dart` as the primary widget test suite and wrote 3 regression tests covering Look Up, Search Web, and Share button behavior on iOS.
  - Added toolbar button test coverage in `packages/flutter/test/cupertino/adaptive_text_selection_toolbar_test.dart` and `packages/flutter/test/material/adaptive_text_selection_toolbar_test.dart`.
  - Verified analyzer and format compliance (`dart analyze --fatal-infos`, `dart format`) and verified that all test suites passed cleanly.

---

## 4. Key Strengths & Testing Pitfalls Observed

### Architectural Comparison

Both candidates correctly recognized that `SelectableRegion` on iOS was omitting `lookUp`, `searchWeb`, and disabling `share`.

#### Candidate B Implementation (`selectable_region.dart`):
```dart
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
        !kIsWeb &&
        onLookUp != null &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        selectionGeometry.status == SelectionStatus.uncollapsed;
    final bool canSearchWeb =
        !kIsWeb &&
        onSearchWeb != null &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        selectionGeometry.status == SelectionStatus.uncollapsed;
```

### Direct Citations from Transcripts & Test Quality

#### Candidate B's Canonical Widget Test (`test/widgets/selectable_region_test.dart`):
Candidate B wrote targeted tests that mock `SystemChannels.platform` and verify that the selection overlay handles remain intact after invoking Look Up / Search Web / Share:
```dart
      // Press the `Look Up` button.
      expect(buttonItems[2].type, ContextMenuButtonType.lookUp);
      buttonItems[2].onPressed?.call();
      expect(lastLookUp, 'are');
      // On iOS, Look Up should not clear the selection.
      expect(regionState.selectionOverlay, isNotNull);
      expect(regionState.selectionOverlay?.startHandleLayerLink, isNotNull);
      expect(regionState.selectionOverlay?.endHandleLayerLink, isNotNull);
```

#### Layer Discipline:
Candidate B refrained from modifying `packages/flutter/test/material/selection_area_test.dart` unnecessarily because `SelectionArea` simply wraps `SelectableRegion`. Testing `SelectableRegion` directly in `selectable_region_test.dart` with `TestWidgetsApp` avoids unnecessary Material dependencies and provides faster, cleaner unit testing.
