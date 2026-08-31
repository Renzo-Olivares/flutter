# Evaluation Report: [iOS] Add default buttons to SelectionArea context menu (#141775)

**Target Issue**: [flutter/flutter#141775](https://github.com/flutter/flutter/issues/141775)  
**Evaluated Model**: Gemini 3.7 Flash (High)  
**Evaluator**: Antigravity Benchmark Orchestrator & Objective Judge  

---

## 1. Executive Summary & Final Verdict

- **Winner Declaration**: **Candidate B (Treatment — With Skill)**
- **High-Level Rationale**: Both candidates successfully understood the root cause, implemented the missing default iOS context menu buttons (`Look Up`, `Search Web`, `Share`) in `SelectableRegion` / `SelectionArea`, wrote regression tests in canonical test suites, and passed `dart analyze --fatal-infos` and `dart format` cleanly. However, **Candidate B** autonomously identified and activated the `flutter-text-domain-expert` skill early in its run (Step 6), allowing it to directly leverage the text subsystem architecture and testing guidelines. As a result, Candidate B operated with significantly higher search precision, cleaner architectural event handling, and executed the task with **13.4% fewer planner turns**, **16.8% fewer tool calls**, and **17.3% fewer tokens** than Candidate A.

---

## 2. Comparative Scorecard Table

| Dimension | Max Pts | Candidate A (Baseline) | Candidate B (With Skill) | Notes / Observations |
| :--- | :---: | :---: | :---: | :--- |
| **1. Subsystem Routing & Architectural Precision** | 20 | 18 | 20 | Candidate B applied exact iOS selection dismissal semantics (`hideToolbar(false)`) cleanly without superfluous fallback branching. Both respected layer boundaries. |
| **2. Test File Placement & Organization** | 20 | 20 | 20 | Both correctly placed tests in canonical test files: `selectable_region_test.dart`, `selection_area_test.dart`, `adaptive_text_selection_toolbar_test.dart` (Material & Cupertino). |
| **3. Avoidance of Flutter Text Testing Traps** | 25 | 24 | 25 | Both avoided `pumpAndSettle` hangs and properly simulated long presses. Candidate B additionally validated handle layer link invariants. |
| **4. Code Correctness & Cleanliness** | 15 | 15 | 15 | Both achieved 0 analyzer errors (`--fatal-infos`), 0 lint warnings, clean formatting, and 100% test pass rates across all modified suites. |
| **5. Search Precision & Autonomous Discovery** | 10 | 7 | 10 | Candidate B autonomously discovered and triggered `flutter-text-domain-expert` immediately on Step 6. Candidate A relied on broader exploratory search queries. |
| **6. Quantitative Resource & Token Efficiency** | 10 | 7 | 9.5 | Candidate B achieved double-digit reductions across turns (-13.4%), tool calls (-16.8%), and tokens (-17.3%). |
| **Total Score** | **100** | **91** | **99.5** | **Candidate B decisively wins on efficiency, autonomous discovery, and architectural precision.** |

### Quantitative Metrics Summary

| Metric | Candidate A (Baseline) | Candidate B (With Skill) | Delta (%) |
| :--- | :---: | :---: | :---: |
| **Skill Triggered Automatically** | No | Yes (Step 6) | N/A |
| **Total Planner Turns** | 142 | 123 | **-13.4%** |
| **Total Tool Calls** | 137 | 114 | **-16.8%** |
| **Estimated Tokens** | 120,648 | 99,827 | **-17.3%** |
| **Distinct Files Viewed** | 11 | 13 (incl. skill references) | +18.2% |
| **Distinct Files Modified** | 7 | 7 | 0.0% |

---

## 3. Trajectory & Behavioral Comparison

### Candidate A Investigation & Execution
1. **Initial Discovery**: Candidate A started by viewing issue #141775 and searched for `SelectionArea`, `SelectableRegion`, and `onShare` across `packages/flutter/lib/src/widgets/selectable_region.dart` and `adaptive_text_selection_toolbar.dart`.
2. **Skill Activation**: The `flutter-text-domain-expert` skill was not activated. Candidate A relied entirely on standard greps and reading multiple framework files to determine how context menu items are built on iOS.
3. **Implementation**: Added `onLookUp` and `onSearchWeb` to `SelectableRegion.getSelectableButtonItems`, enabled them for iOS, implemented `_lookUp` and `_searchWeb` platform channel invocations, and updated `AdaptiveTextSelectionToolbar` and `CupertinoAdaptiveTextSelectionToolbar` (adding a new constructor `CupertinoAdaptiveTextSelectionToolbar.selectableRegion`).
4. **Testing**: Implemented regression tests in `selectable_region_test.dart`, `selection_area_test.dart`, and both adaptive toolbar test suites. Confirmed pre-fix failures and post-fix passes.

### Candidate B Investigation & Execution
1. **Autonomous Skill Discovery**: Immediately upon receiving the prompt in Step 6, Candidate B checked available skills and loaded `/Users/roliv/.gemini/antigravity/brain/d8bf266e-835c-494b-9d8c-9d5f53df4d55/.system_generated/worktrees/subagent-Candidate-B--With-Skill--self-e877774f/.agents/skills/flutter-text-domain-expert/SKILL.md`.
2. **Domain-Guided Routing**: Following the skill's static selection domain roadmap, Candidate B identified `SelectableRegionState.contextMenuButtonItems` and `AdaptiveTextSelectionToolbar.selectable` directly without trial-and-error grepping.
3. **Implementation**: Implemented `platformCanLookUp`, `platformCanSearchWeb`, and updated `platformCanShare` to include iOS. Added `_lookUp` and `_searchWeb` methods dispatching to `LookUp.invoke` and `SearchWeb.invoke`. Cleanly called `hideToolbar(false)` for both actions on iOS. Updated `AdaptiveTextSelectionToolbar.selectable` and `CupertinoAdaptiveTextSelectionToolbar.selectable`.
4. **Testing & Invariant Verification**: Added canonical unit tests verifying button item generation, platform channel method calls, and selection handle persistence on iOS. Verified formatting and analysis cleanly.

---

## 4. Key Strengths & Testing Pitfalls Observed

### Direct Citations from Transcripts

#### Candidate B Autonomous Skill Triggering (Transcript Step 6):
```json
{
  "step_index": 6,
  "source": "MODEL",
  "type": "PLANNER_RESPONSE",
  "tool_calls": [
    {
      "name": "view_file",
      "args": {
        "AbsolutePath": "\"/Users/roliv/.../.agents/skills/flutter-text-domain-expert/SKILL.md\"",
        "StartLine": "1",
        "EndLine": "800"
      }
    }
  ]
}
```

#### Invariant Verification (Candidate B on iOS Toolbar Dismissal):
In `SelectableRegionState.contextMenuButtonItems`:
```dart
onLookUp: () {
  _lookUp();
  hideToolbar(false); // preserves selection handles on iOS as prescribed by the text domain guidelines
},
onSearchWeb: () {
  _searchWeb();
  hideToolbar(false);
},
```

In comparison, Candidate A created a full `switch (defaultTargetPlatform)` containing branches for Android, Linux, Windows, and macOS, despite `platformCanLookUp` and `platformCanSearchWeb` being strictly restricted to iOS in `SelectableRegion.getSelectableButtonItems`.

### Architectural Differences

1. **Cupertino Toolbar Extension**:
   - **Candidate A** introduced an extra constructor `CupertinoAdaptiveTextSelectionToolbar.selectableRegion` alongside the updated `.selectable`.
   - **Candidate B** cleanly extended `CupertinoAdaptiveTextSelectionToolbar.selectable` with optional `onLookUp`, `onSearchWeb`, and `onShare` parameters, keeping the public API footprint minimal and consistent with `AdaptiveTextSelectionToolbar.selectable`.

2. **Handle Link Assertions in Tests**:
   - **Candidate B** explicitly verified that iOS selection handles remain alive and linked after invoking the action:
     ```dart
     expect(regionState.selectionOverlay, isNotNull);
     expect(regionState.selectionOverlay?.startHandleLayerLink, isNotNull);
     expect(regionState.selectionOverlay?.endHandleLayerLink, isNotNull);
     ```
   - **Candidate A** verified toolbar visibility:
     ```dart
     expect(regionState.selectionOverlay, isNotNull);
     expect(regionState.selectionOverlay?.toolbarIsVisible, isFalse);
     ```

---

## 5. Conclusion

Candidate B demonstrated the clear value of domain-specific agent skills in large codebases like Flutter. By reading the `flutter-text-domain-expert` skill early, Candidate B navigated straight to the required architectural components, wrote idiomatic platform-specific text selection handling, and completed the entire task with significantly lower token and tool overhead (-16.8% tool calls, -17.3% tokens).
