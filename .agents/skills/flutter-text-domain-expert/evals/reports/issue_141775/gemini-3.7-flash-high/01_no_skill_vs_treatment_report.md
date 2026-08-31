# Evaluation Report: [iOS] Add default buttons to SelectionArea context menu (#141775)

**Target Issue**: [flutter/flutter#141775](https://github.com/flutter/flutter/issues/141775)  
**Evaluated Model**: Gemini 3.7 Flash (High)

---

## 1. Executive Summary & Final Verdict
- **Winner Declaration**: **Candidate B (Treatment — With Skill)**
- **High-Level Rationale**: Candidate B leveraged the domain skill and reference guides (`static_text_pipeline.md`, `testing_text_stack.md`) to resolve the issue with high architectural precision and efficiency. It reduced planner turns by **26.6%** (91 vs 124) and tool calls by **28.3%** (86 vs 120). Candidate B avoided exploratory grep loops, avoided hung background tasks / polling timers, and wrote idiomatic switch expressions consistent with existing framework conventions. Both candidates successfully produced passing implementations, comprehensive tests, and clean static analysis.

---

## 2. Comparative Scorecard Table

| Dimension | Max Pts | Candidate A (Baseline) | Candidate B (With Skill) | Notes / Observations |
| :--- | :---: | :---: | :---: | :--- |
| **1. Subsystem Routing & Architectural Precision** | 20 | 18 | 20 | Both correctly modified `SelectableRegion`, `AdaptiveTextSelectionToolbar`, and `CupertinoAdaptiveTextSelectionToolbar`. Candidate B used the context menu matrix to pinpoint channel names (`LookUp.invoke`, `SearchWeb.invoke`, `Share.invoke`) directly. |
| **2. Test File Placement & Organization** | 20 | 20 | 20 | Both placed tests in canonical test suites (`selectable_region_test.dart`, `adaptive_text_selection_toolbar_test.dart`, `selection_area_test.dart`) with realistic long-press gestures. |
| **3. Avoidance of Flutter Text Testing Traps** | 25 | 18 | 25 | Candidate A fell into polling traps (spawning `schedule` timer to poll background `flutter test` tasks and launching hung `git log` tasks). Candidate B executed tests cleanly and reactively without polling timers. |
| **4. Code Correctness & Cleanliness** | 15 | 15 | 15 | Both achieved 0 errors/warnings on `dart analyze --fatal-infos` and 0 diffs on `dart format`. Candidate B used switch expressions matching existing platform pattern. |
| **5. Search Precision & Autonomous Discovery** | 10 | 7 | 10 | Candidate A required 22 grep searches and 46 file views across editable text and widget trees before isolating the root cause. Candidate B navigated directly via skill references. |
| **6. Quantitative Resource & Token Efficiency** | 10 | 7 | 9 | Candidate B achieved a 26.6% turn reduction and 28.3% tool call reduction over Candidate A. |
| **Total Score** | **100** | **85** | **99** | **Candidate B wins decisively (+14 pts)** |

### Quantitative Metrics Summary

| Metric | Candidate A (Baseline) | Candidate B (With Skill) | Delta (%) |
| :--- | :---: | :---: | :---: |
| **Skill Triggered Automatically** | Yes (Initial SKILL.md) | Yes (v4 with References) | — |
| **Total Planner Turns** | 124 | 91 | -26.6% |
| **Total Tool Calls** | 120 | 86 | -28.3% |
| **Estimated Tokens** | 95,588 | 105,155 | +10.0% |
| **Distinct Files Viewed** | 11 | 11 | 0.0% |
| **Distinct Files Modified** | 7 | 7 | 0.0% |

---

## 3. Trajectory & Behavioral Comparison

- **Candidate A Investigation & Execution**:
  - Started by checking out baseline commit `67710a5db2adcae7e5ad606c7f5001108e037672`.
  - Viewed `SKILL.md` but did not have the context menu matrix reference documentation available in the workspace.
  - Performed extensive exploratory search across multiple subsystems (`SelectableText`, `TextField`, `EditableText`, `SelectionArea`, `AdaptiveTextSelectionToolbar`), running 22 `grep_search` invocations.
  - Ran `git log -S "LookUp.invoke"` which hung in the background and required explicit `manage_task: kill`.
  - Spawned background `flutter test` tasks and used the `schedule` tool with a 60s timer to poll for test completion instead of awaiting synchronous execution.
  - Eventually identified all four locations (`selectable_region.dart`, `adaptive_text_selection_toolbar.dart`, `CupertinoAdaptiveTextSelectionToolbar`, and test files), implemented the fix, and verified formatting and analysis.

- **Candidate B Investigation & Execution**:
  - Checked out treatment commit `fd18dd04e40945ac80898e378e766b8602a6c3cd`.
  - Consulted the `flutter-text-domain-expert` skill documentation (`static_text_pipeline.md` and `testing_text_stack.md`).
  - Directly identified the context menu pipeline: `SelectableRegion.getSelectableButtonItems`, `SelectableRegionState.contextMenuButtonItems`, and the toolbar wrappers.
  - Followed platform channel specifications (`LookUp.invoke`, `SearchWeb.invoke`, `Share.invoke`) and handle layer link persistence (`hideToolbar(false)` on iOS).
  - Executed tests directly with zero hung tasks, zero timer polling, and minimal tool overhead.

---

## 4. Key Strengths & Testing Pitfalls Observed

### Direct Citations from Transcripts

- **Candidate A Traps Encountered**:
  - *Hung Background Task*: Candidate A ran `git log -S "LookUp.invoke" --oneline` which went to the background (`task-65`) and had to be killed via `manage_task`.
  - *Polling via Timer*: Candidate A ran `schedule` with `DurationSeconds: 60` and `Prompt: "Check if the flutter test task finished"` (`task-126`) while waiting on `task-122`, violating reactive execution guidelines.
  - *Exploratory Grepping*: Step 7-42 included redundant searches for `lookUpEnabled`, `lookUpSelection`, `class SelectableText`, etc.

- **Candidate B Best Practices**:
  - *Direct Skill Consultation*: Step 6-12 read `SKILL.md`, `static_text_pipeline.md`, and `testing_text_stack.md` to establish the precise channel contracts and button item list (`[Copy, Select All, Look Up, Search Web, Share]`).
  - *Clean Execution*: All test commands executed synchronously and cleanly without task polling.

### Architectural Differences

#### 1. Platform Filtering in `SelectableRegion.getSelectableButtonItems`

**Candidate A (Boolean condition)**:
```dart
// The look up and search web buttons are only supported on iOS and not on web.
final bool platformCanLookUpOrSearchWeb =
    !kIsWeb &&
    defaultTargetPlatform == TargetPlatform.iOS &&
    selectionGeometry.status == SelectionStatus.uncollapsed;
final bool canLookUp = onLookUp != null && platformCanLookUpOrSearchWeb;
final bool canSearchWeb = onSearchWeb != null && platformCanLookUpOrSearchWeb;
```

**Candidate B (Idiomatic switch expression)**:
```dart
final bool platformCanLookUp =
    !kIsWeb &&
    switch (defaultTargetPlatform) {
      TargetPlatform.iOS => selectionGeometry.status == SelectionStatus.uncollapsed,
      TargetPlatform.android ||
      TargetPlatform.macOS ||
      TargetPlatform.fuchsia ||
      TargetPlatform.linux ||
      TargetPlatform.windows => false,
    };
final bool canLookUp = onLookUp != null && platformCanLookUp;

final bool platformCanSearchWeb =
    !kIsWeb &&
    switch (defaultTargetPlatform) {
      TargetPlatform.iOS => selectionGeometry.status == SelectionStatus.uncollapsed,
      TargetPlatform.android ||
      TargetPlatform.macOS ||
      TargetPlatform.fuchsia ||
      TargetPlatform.linux ||
      TargetPlatform.windows => false,
    };
final bool canSearchWeb = onSearchWeb != null && platformCanSearchWeb;
```

#### 2. Toolbar Parity
Candidate A added an extra `CupertinoAdaptiveTextSelectionToolbar.selectableRegion` constructor, whereas Candidate B focused strictly on forwarding parameters through the existing `.selectable` constructor on both Cupertino and Material toolbars.
