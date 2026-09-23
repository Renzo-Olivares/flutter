# Existing flutter/flutter issues for SelectableRegion-layer gaps (SelectableText -> SelectionArea POC)

Searched 2026-09-23 using `gh issue list --search ... --state all` and `gh pr list --search ... --state all`, about 120 queries. `gh search issues` returned nothing for multi-word queries in this environment, so the `--search` form was used. I read the body of every candidate listed below, and the closing comments of every closed candidate.

## 1. iOS single tap does not snap to word edge (`selectWordEdge`)
- #129583 [open] `SelectionArea` supported gestures should have feature parity with `TextSelectionGestureDetector`. **Match: exact** (as a checklist row). This P1 umbrella covers SelectionArea specifically. Its "Platform iOS" table lists "Select word edge on tap up | (blank, not implemented) | Both". The body says these gestures are prerequisites for reimplementing SelectableText (#104547). The single-tap row (PR #132682) is checked, but the iOS word-edge row is not.
- #60148 [closed] Tap on a text field always places the cursor on word boundary. **Match: related.** It is about text fields and shows the behavior that already exists on the EditableText side.
- Searched: `SelectionArea iOS tap word edge`, `SelectionArea tap selects word boundary iOS`, `SelectionArea iOS tap`, `SelectionArea single tap iOS`, `label:"f: selection" iOS tap`, `selectWordEdge`, `"word edge" selection tap iOS`, PR `selectWordEdge SelectableRegion`
- Verdict: **existing issue #129583 covers it** (one unchecked row of the umbrella; there is no standalone issue).

## 2. Keyboard extension has no anchor/focus model (backward extension moves the start edge; base and extent come back swapped)
- #182628 [open, P2, team-text-input] `SelectableRegion` supported keyboard shortcuts should have feature parity with `SelectableText`. **Match: partial.** It lists the intents SelectableRegion has no action for, such as paragraph and page extension and `ExtendSelectionToNextParagraphBoundaryOrCaretLocationIntent`. It does not mention base/extent ordering or the anchor model.
- #104541 [closed, fixed by PR #112584] [Selection] SelectionArea keyboard arrow key shortcut does not work. **Match: related.** The original "arrow keys do nothing" report. PR #112584 added `GranularlyExtendSelectionEvent` and `DirectionallyExtendSelectionEvent`, which are the current extension events that have the start-edge behavior.
- #166462 [closed] Broken text selection when selecting backwards from `TextSpan` into `WidgetSpan` within `SelectionArea`. **Match: related.** It is a backward mouse-drag bug, not keyboard anchor semantics.
- Searched: `SelectionArea shift arrow selection`, `SelectionArea keyboard selection extend`, `SelectionArea keyboard`, `SelectionArea keyboard shortcuts`, `SelectionArea anchor extent`, `SelectionArea base extent`, `SelectionArea selection direction`, `SelectionArea shift up down`, `SelectionArea shift left selection wrong direction`, `SelectionArea selection extend backward`, `label:"f: selection" keyboard`, `label:"f: selection" arrow`, `SelectableRegion` (bare), PR `SelectableRegion keyboard`
- Verdict: **no existing issue found** for the anchor/base-extent swap. #182628 partially covers keyboard parity in general.

## 3. Plain arrow keys do not move a collapsed selection (no caret or caret navigation)
- #104541 [closed, fixed by PR #112584] [Selection] SelectionArea keyboard arrow key shortcut does not work. **Match: partial.** The report ("use arrow key to change the selection ... none of them work") was closed after only the shift-extension support landed. Plain (non-shift) caret movement was never done.
- #182628 [open] `SelectableRegion` keyboard shortcuts parity with `SelectableText`. **Match: partial.** It is the current SelectableRegion-vs-SelectableText keyboard parity tracker, but its list is about missing intent mappings, and caret-movement (non-extending) handling is not called out.
- #192844 [open] SelectionArea wrapping a TextField throws a TypeError on vertical caret movement. **Match: related.** It is a SelectionArea action-override crash that affects a nested TextField, not caret movement in static text.
- Searched: `SelectionArea arrow keys caret`, `SelectionArea cursor keyboard navigation`, `SelectionArea caret browsing`, `SelectionArea collapsed selection`, `SelectionArea cursor arrow keys move`, `SelectableRegion arrow keys`, `"selection area" caret`, `label:"f: selection" arrow`
- Verdict: **partial coverage by #104541 (closed) and #182628**. No open issue specifically asks for caret movement or a caret in SelectionArea.

## 4. Handles can be dragged past each other (inverted selection)
- #106705 [closed, completed 2022-08-09] SelectionArea handles swap order on Android. **Match: exact.** It reports exactly this: EditableText stops the drag, but SelectionArea lets the handles cross. It was closed as working-as-intended. justinmc and chunhtai concluded that native Android allows handle swapping on non-editable text (and on Android 11 generally), so SelectionArea's behavior was judged to match native.
- Searched: `SelectionArea handles cross inverted`, `SelectionArea selection handles swap`, `SelectionArea handles swapped`, `SelectionArea drag handle past`, `SelectionArea start handle end handle`, `label:"f: selection" handle`
- Verdict: **existing issue #106705 covers it**, but it is closed as intended behavior. Cite it if the POC accepts the behavior change.

## 5. Handles do not hide or fade when scrolled off-screen (visibility notifiers not wired)
- #13182 [open, P2, team-text-input] Text selection handles overlap UI elements (e.g. AppBars) when selection anchor is scrolled away. **Match: partial.** This is the general "handles still paint after the anchor scrolls out of the viewport" issue, originally filed for text fields. #181260 (SelectableText/TextField) and #89570 were closed as duplicates of it. PR #186491 ("Clip text-selection handles and toolbar to the enclosing viewport", fixes #13182) was closed unmerged on 2026-08-05.
- #120892 [closed, fixed] Inconsistency of `SelectionArea` when scrolling. **Match: partial.** Case 2 reports that SelectionArea handles "display outside the scroll viewport when scrolled", and the reporter expected them to be hidden or clipped. The fix only addressed the selection being cleared on long-press cancel, and the handle-visibility part was not resolved in that thread.
- #181260 [closed, duplicate of #13182] Text selection handles remain visible above parent widgets when it should be hidden. **Match: related.** Filed against TextField/SelectableText.
- Searched: `SelectionArea handle scrolled off screen visible`, `SelectionArea handles remain visible scroll`, `SelectionArea handles out of view`, `SelectionArea handles visible after scrolling`, `SelectionArea handle over app bar`, `SelectionArea handles fade`, `SelectionArea handle clipped viewport`, `SelectionArea handle`, PR `SelectableRegion handle`
- Verdict: **partial coverage by #13182** (open umbrella) and #120892 (closed; SelectionArea-specific mention of handles outside the viewport). No issue specifically asks for SelectionArea to hide handles through the SelectionOverlay visibility notifiers.

## 6. Handle drag past a scrollable edge auto-scrolls incrementally and keeps scrolling (overshoot)
- #110788 [open, P2] Long SelectableText is not actually selectable in ListView. **Match: related.** It is about poor handle drag and scroll interaction for the old SelectableText inside a ListView, not SelectionArea overshoot.
- #64059 [open, P2, team-text-input] Horizontal edge scrolling is broken. **Match: related.** It covers TextField/SelectableText handle edge-scroll not working, the opposite symptom, on the EditableText side.
- #162856 [open, P2] Edge scrolling of selection area not working when scroll view not wrapped by SafeArea. **Match: related.** It is SelectionArea edge-scroll, but the symptom is that the thresholds fall inside the system insets, not overshoot.
- #190737 [open] CarouselView with SelectionArea edge-scrolls (snaps items) during mouse text selection; #149426 [closed, PR #189544 merged]. **Match: related.** These are about unwanted edge-scroll in paged scrollables during mouse selection.
- Searched: `SelectionArea handle drag auto scroll`, `SelectionArea scroll handle drag`, `SelectionArea edge scroll`, `SelectionArea scroll`, `SelectionArea ListView handle scroll fast`, `SelectionArea auto scroll too fast`, `SelectionArea scrolls too far`, `SelectionArea scroll overshoot`, `"SelectionArea" "auto scroll"`, `text selection handle drag scroll continues`, `label:"f: selection" scroll`, PR `SelectableRegion autoscroll`
- Verdict: **no existing issue found**

## 7. Selection drag does not auto-scroll an ancestor scrollable (only Scrollables inside the SelectionArea)
- #129590 [closed, fixed] `SelectableText` does not maintain start position when scrolled out of view. **Match: related.** This is the known old-SelectableText issue: the parent scrollable scrolled, but the start position was lost. The regression test comes from it.
- #162856 [open] Edge scrolling of selection area not working when scroll view not wrapped by SafeArea. **Match: related.** Its Scrollable is inside the SelectionArea, not an ancestor.
- Searched: `SelectionArea autoscroll ancestor scrollable`, `SelectionArea drag scroll parent`, `SelectionArea parent scroll view auto scroll`, `SelectionArea nested scrollable selection`, `SelectionArea selection autoscroll outer scrollable`, `SelectionArea inside SingleChildScrollView drag not scroll`, `SelectionArea whole page scroll when selecting`, `SelectionArea CustomScrollView drag selection scroll`, `SelectionArea wrapping ListView edge scroll`, `"SelectionArea" autoscroll`
- Verdict: **no existing issue found**

## 8. Force press (3D Touch) does not select a word on iOS
- #129583 [open] SelectionArea gesture parity umbrella. **Match: related.** Force press is not among its rows, and its iOS section covers only word-edge tap, cursor drag and long-press cursor.
- #67172 [closed] Support keyboard 3d touch text selection on iOS. **Match: related.** It is about keyboard trackpad for text fields, which is a different feature.
- Searched: `SelectionArea force press`, `"selection area" force touch`, `3D touch selection`, `SelectableRegion force press`, `forcePress selection`, `label:"f: selection" iOS force`, PR `SelectableRegion force press`
- Verdict: **no existing issue found**

## 9. No `SelectionChangedCause` or gesture kind given to listeners / `onSelectionChanged`
- #110594 [closed, r: fixed, 2024-11-26] Make `onSelectionChanged` of SelectionArea equivalent to that of SelectableText. **Match: partial.** It asks for SelectionArea's callback to match SelectableText's `(TextSelection, SelectionChangedCause?)`, but the discussion is only about offsets. It was closed as fixed after `SelectionListener`/`SelectedContentRange` (PR #154202). The cause argument was never addressed.
- #131065 [closed, 2026-03-19] Allow onSelectionChanged Callback To Be Aware Of Where Data Came From In a SelectableRegion. **Match: related.** It is about which Selectable the selection came from. It was closed by Renzo-Olivares, pointing to `SelectionListener`.
- #137362 [closed, duplicate] Add offset's to SelectionArea callback. **Match: related.** It asks for offsets, not a cause.
- Searched: `SelectionArea onSelectionChanged cause`, `SelectableRegion SelectionChangedCause`, `SelectionArea SelectionChangedCause`, `SelectionArea onSelectionChanged`, `SelectionArea selection changed callback`, `SelectionArea selection listener`, `SelectableRegion onSelectionChanged called during drag`, `SelectionArea "select all"`
- Verdict: **partial coverage by #110594** (closed, fixed for offsets only). Nothing tracks passing a cause.

## 10. After an iOS touch double tap, `SelectableRegionSelectionStatus` stays `changing`
- #163509 [closed, stale] Option to trigger selection toolbar on onSelectionEnd or on Left Click in SelectionArea widget. **Match: related.** It asks for a selection-end signal, which the finalized status now provides. It does not report a status stuck at `changing`.
- Searched: `SelectableRegionSelectionStatus double tap`, `SelectionArea selection status`, `SelectionArea finalized`, `SelectionListener status`, `SelectionArea selection status changing`, `SelectionArea selection finished event`, `SelectionArea selection end callback`, PR `SelectionListener status`, PR `SelectableRegion selection status`
- Verdict: **no existing issue found**

## 11. Context menu items are not platform-aware (iOS Look Up / Search Web / Share; Select all rules; Share on Android)
- #141775 [open, P2, team-text-input] [iOS] Add default buttons to SelectionArea context menu. **Match: exact** (iOS part). It reports that SelectionArea on iOS lacks the Share, Look Up and Search Web buttons that TextField/SelectableText show. The body lists the EditableText PRs #132599, #130532 and #131898.
- PR #141447 [merged 2024-01-23] Add Share button to the SelectableRegion toolbar on Android. **Match: related.** Share on Android in SelectableRegion was added on purpose, for parity with EditableText's Android Share (PR #139479). If the audit flags "Share shown on Android" as a gap, this PR is evidence that the behavior is intended.
- #171732 [open] SystemContextMenu support outside of editable text?. **Match: related.** It is about the native iOS menu for non-editable selection.
- #83700 [closed] SelectableText doesn't show `selectAll` on popup menu on iOS. **Match: related.** It is historical Select-all visibility behavior for the old SelectableText.
- Searched: `SelectionArea context menu Look Up Search Web Share`, `SelectionArea context menu select all macOS`, `SelectionArea context menu`, `label:"f: selection" context menu`, `SelectionArea toolbar share`, `SelectionArea Look up`, `SelectionArea Share Android`, `SelectionArea SystemContextMenu`, `SelectionArea iOS toolbar Look Up`, `SelectionArea iOS context menu missing`, `SelectionArea macOS context menu select all`, `SelectionArea select all already selected`, PR `SelectionArea Share Look Up Search Web`, PR `SelectableRegion iOS`, PR `SelectableRegion select all toolbar`
- Verdict: **existing issue #141775 covers the iOS buttons**. There is no issue for the Select-all rules (hide when everything is selected, macOS). Android Share is intended (PR #141447).

## 12. No public API to set or move the selection programmatically by offset
- #127025 [closed, stale bot-closed 2024-10-17] Add a controller to SelectionArea. **Match: partial.** It asks for a controller to drive selection programmatically (for example `selectAll`), and a commenter asks for `selectWord`. It was closed for lack of response, not fixed.
- #126980 [closed, r: fixed] SelectableRegionState public _selectable and _clearSelection. **Match: related.** It asked to make `clearSelection` and similar public (done). It does not cover setting a range.
- #163509 [closed, stale] Option to trigger selection toolbar on onSelectionEnd... **Match: related.** It notes that the selection and toolbar APIs are private.
- PR #138654 [closed unmerged] Add ability to return TextSelection from SelectableRegion. **Match: related.** It reads offsets and does not set them.
- Searched: `SelectionArea programmatically select`, `SelectableRegion select range programmatically`, `SelectionArea set selection`, `SelectionArea selectWord`, `SelectionArea programmatic selection`, `SelectableRegion selectRange`, `SelectableRegion selectAll controller`, `SelectableRegionState public API`, `SelectionArea select programmatically text range`, `label:"f: selection" controller`
- Verdict: **partial coverage by #127025** (closed as stale). There is no open issue.

## 13. Bonus: migration and parity tracking
- #104547 [open, P3, c: tech-debt] [Selection] Reimplement SelectableText with SelectionArea. **Match: exact.** This is the migration tracking issue: "reimplement SelectableText with SelectionArea + text, but we should make sure they are feature on par". It lists sub-issues #111370, #111021, #110594, #104703, #104603, #104594 and #126652, and most of them are now fixed.
- #129583 [open, P1] SelectionArea gesture parity with TextSelectionGestureDetector. **Match: exact** for gesture parity. It is explicitly described as a prerequisite for #104547.
- #182628 [open, P2] SelectableRegion keyboard shortcut parity with SelectableText. **Match: exact** for keyboard parity.
- #181682 [open, P3] Add a Cupertino version of SelectableText. **Match: related.** It comes from the test cross-import work (#177415).
- #111213 [open] Remove TextSelectionDelegate from SelectableRegionState. **Match: related.** SelectableRegion API cleanup.
- Searched: `SelectableText SelectionArea migrate`, `SelectableText rewrite SelectionArea`, `SelectionArea SelectableText parity`, `SelectableText feature parity`, `SelectableText cupertino`, `label:"f: selection" SelectableText`, `"SelectableText" SelectionArea regression`, `SelectableText migrate SelectionArea`, PR `SelectableText SelectionArea`
- Verdict: **existing issue #104547 covers it**, with #129583 (gestures) and #182628 (keyboard) as the parity sub-trackers.

## Summary

| Gap | Best issue | Match | State |
|---|---|---|---|
| 1 iOS tap word edge | #129583 (iOS row "Select word edge on tap up") | exact (row in umbrella) | open |
| 2 Keyboard anchor/extent swap | #182628 | partial | open |
| 3 Arrow keys / caret | #104541 (closed via #112584), #182628 | partial | closed / open |
| 4 Handles cross | #106705 | exact | closed as intended (native non-editable allows swap) |
| 5 Handles visible off-screen | #13182; #120892 | partial | open / closed |
| 6 Handle-drag scroll overshoot | none | none | - |
| 7 Ancestor scrollable auto-scroll | none (#129590 old SelectableText only) | related | - |
| 8 Force press | none | none | - |
| 9 SelectionChangedCause | #110594 | partial (offsets only) | closed fixed |
| 10 Status stuck `changing` after double tap | none | none | - |
| 11 Platform context menu items | #141775 (iOS Share/Look Up/Search Web) | exact for iOS; none for Select-all rules; Android Share intended per PR #141447 | open |
| 12 Programmatic selection API | #127025 | partial | closed (stale) |
| 13 Migration / parity tracker | #104547 (+ #129583, #182628) | exact | open |
