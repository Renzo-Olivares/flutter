# Group G_doubletap_longpress_apple report

Scratch-probe results (zz_scratch_G_test.dart, 1 run, since deleted) are cited as "probe". The probe was the head-test gesture sequences with the failing asserts replaced by prints:
- iOS 077 sequence: tap1=collapsed(11, downstream); double tap=(8,12) with toolbar [Copy, Select All]; tap3=collapsed(7, downstream), no toolbar.
- macOS 078 sequence: tap1=collapsed(11, downstream); double tap=(8,12), no toolbar; tap3=collapsed(7, downstream), no toolbar.
- long press at x=50 selects (0,7) on every platform. Toolbar: iOS=[Copy, Select All], macOS=[Copy, Select All], android=3 TextButtons, fuchsia/linux/windows=2 TextButtons.
- 086 sequence on iOS: selection stays (0,7) after the tap, and the tap brings back the toolbar as [Copy, Select All]. On macOS the tap gives collapsed(4, downstream) and no toolbar.

## Test 077 — tap after a double tap select is not affected (iOS)
- status_at_head: FAILING (variants: TargetPlatform.iOS)
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: (1) The test now reads the selection through `onSelectionChanged` instead of `EditableText.controller`: WARRANTED. (2) The first-tap check `controller.selection == collapsed(offset: 12, affinity: upstream)` became four expects (`isNotNull`, `isCollapsed`, `baseOffset == 12`, `affinity == upstream`). This is just as strong: WARRANTED. (3) A new check that the double tap selects `(8,12)`. This adds coverage: WARRANTED. (4) The final `expect(controller.selection, collapsed(offset: 7))` became `isCollapsed` + `baseOffset == 7`. This quietly drops the downstream-affinity part of the old exact match. The weakening is trivial because the new impl always reports downstream. COSMETIC/negligible. (5) Added `await tester.pump()` after pumpWidget so selectables can register: WARRANTED. The iOS 12 explanatory comment was removed and a TODO added.
- part_a_evidence: Head line 3657 `expect(latestSelection!.baseOffset, 12);` still encodes the old value. Base-on-head (textoffsetfix) fails with `Bad state: No element` at `tester.widget(find.byType(EditableText).first)`, which is the surface issue that was fixed. The head calls the `onSelectionChanged` callback from `_handleSelectionDetailsChanged` (material/selectable_text.dart:505-520).
- part_b_classification: GAP
- part_b_root_cause: The immediate error is `Expected: <12> Actual: <11>` at line 3657. In the old code, iOS touch onSingleTapUp called `renderEditable.selectWordEdge(cause: tap)` (widgets/text_selection.dart:2696), which snaps to the nearest word edge (12, upstream). In the new code, `_handleMouseTapUp` case 1 on iOS calls `_collapseSelectionAt(offset: details.globalPosition)` (widgets/selectable_region.dart:952-957), which places a collapsed selection at the precise position (x=150 → 11). Once that is fixed, `affinity == upstream` fails too, because `_handleSelectionDetailsChanged` builds `TextSelection(baseOffset:, extentOffset:)` with no affinity (selectable_text.dart:513). The probe shows the rest of the test passes on the new impl: the double tap selects (8,12), the tap after the double tap collapses at 7, and no CupertinoButton remains. So the tap-after-double-tap reset is NOT a gap.
- part_b_surface_fix: none
- gap_ids: [G-TAP-GESTURES, G-NO-AFFINITY]
- gap_notes: G-TAP-GESTURES — `expect(latestSelection!.baseOffset, 12)`. A single touch tap on iOS no longer snaps to the word edge. SelectableRegion collapses at the precise hit position (selectable_region.dart:956), while the old builder called selectWordEdge (text_selection.dart:2696). G-NO-AFFINITY — `expect(latestSelection!.affinity, TextAffinity.upstream)`. SelectedContentRange has no affinity, and SelectableText's adapter always reports downstream.
- confidence: HIGH (probe confirmed the actual values of every later step)

## Test 078 — tap after a double tap select is not affected (macOS)
- status_at_head: FAILING (variants: TargetPlatform.macOS)
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: The changes match 077: the controller read became an `onSelectionChanged` read, the collapsed(11, upstream) check was split into four expects with the same strength, a double-tap `(8,12)` check was added, and the final collapsed(7) check lost its implicit downstream affinity (negligible). All edits WARRANTED. The expected values are unchanged (11 upstream, 7).
- part_a_evidence: Head line 3704 `expect(latestSelection!.affinity, TextAffinity.upstream);`. Base-on-head (textoffsetfix) fails with `Bad state: No element` at the EditableText finder.
- part_b_classification: GAP
- part_b_root_cause: The immediate error is `Expected: TextAffinity.upstream Actual: TextAffinity.downstream` at line 3704. The offset (11) already matches. The old macOS tap-down called `selectPosition` (text_selection.dart:2510), and the new macOS tap-down calls `_collapseSelectionAt` (selectable_region.dart:767). Both are precise. The only difference is that affinity is lost in the adapter (selectable_text.dart:513). The probe shows everything after that step passes: the double tap selects (8,12), the tap after it collapses at 7, and there is no toolbar.
- part_b_surface_fix: none
- gap_ids: [G-NO-AFFINITY]
- gap_notes: G-NO-AFFINITY — `expect(latestSelection!.affinity, TextAffinity.upstream)`. The SelectionListener/SelectedContentRange API does not carry TextAffinity, so SelectableText cannot report it.
- confidence: HIGH (probe)

## Test 079 — long press selects word and shows toolbar (iOS)
- status_at_head: FAILING (variants: TargetPlatform.iOS, TargetPlatform.macOS)
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: The only changes are reading the selection through `onSelectionChanged` instead of `controller.selection` (same expected value `(0,7)`) and adding `pump()`. WARRANTED. The `expectCupertinoSelectionToolbar()` helper body is unchanged. Only a TODO comment was added to it.
- part_a_evidence: The helpers diff adds only the TODO line above `expectCupertinoSelectionToolbar`. Base-on-head fails with `Bad state: No element` at the EditableText finder.
- part_b_classification: GAP
- part_b_root_cause: The long press selects (0,7) and shows a toolbar on both platforms. The new `_handleTouchLongPressEnd` calls `_showToolbar()` unconditionally (selectable_region.dart:1027-1035), and the old `onSingleLongTapEnd` shows it when `shouldShowSelectionToolbar`, which is true for touch (text_selection.dart:2856-2860, 2466). So showing the toolbar on a macOS touch long press is NOT a gap. What differs is the button set. The SelectionArea toolbar is `AdaptiveTextSelectionToolbar.selectableRegion` → `SelectableRegion.getSelectableButtonItems` (selectable_region.dart:299-338):
  - `canSelectAll = selectionGeometry.hasContent` (line 306), with no platform or already-selected check.
  - iOS share is hard-coded to `false` (lines 316-320).
  - There are no Look Up or Search Web items at all.
  - Result: iOS gets [Copy, Select All] where the test expects 4 buttons (Copy, Look Up, Search Web, Share...). macOS gets [Copy, Select All] where the test expects 1 button (Copy).
  - The old EditableText rules were: `selectAllEnabled` returns false on macOS and requires a collapsed selection on iOS (editable_text.dart:2684-2688); `lookUpEnabled`/`searchWebEnabled` are true on iOS for a non-empty selection (2700-2718); `shareEnabled` is true on iOS (2721-2727).
  The owner's TODO is verified against code and the probe.
- part_b_surface_fix: none
- gap_ids: [G-TOOLBAR-PLATFORM]
- gap_notes: G-TOOLBAR-PLATFORM — iOS fails at `expect(find.byType(CupertinoButton), findsNWidgets(4))` (2 found) and macOS fails at `findsNWidgets(1)` (2 found). SelectableRegion's button list is not platform-aware the way EditableTextState's is: no Look Up, Search Web or Share on iOS, and Select All is shown even on macOS and even when the selection is non-collapsed on iOS.
- confidence: HIGH (probe printed the exact labels [Copy, Select All] on both platforms)

## Test 080 — long press selects word and shows toolbar (Android)
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: The selection is read through `onSelectionChanged` instead of the controller, the expected value `(0,7)` is unchanged, `pump()` was added, and `expectMaterialSelectionToolbar()` is untouched. It passes and 079 fails because Android's SelectableRegion button set (Copy, Share, Select all: `platformCanShare` is true for Android when the selection is uncollapsed, share goes before select all, selectable_region.dart:311, 325-335) happens to match the old EditableText Android set (Copy, Share, Select all). On Apple platforms the sets differ (see 079). The long-press code path is the same except that Android shows handles on long-press end (selectable_region.dart:1015, 1031).
- part_a_evidence: Base-on-head (textoffsetfix) failed only with `Bad state: No element` at `tester.widget(find.byType(EditableText).first)`, so the only reason it failed was the missing EditableText finder. The probe shows android long press gives (0,7) and 3 TextButtons.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: none
- confidence: HIGH

## Test 081 — long press selects word and shows custom toolbar (Cupertino)
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: Most of the 52 diff lines are dart-format reindentation (the testWidgets signature was collapsed). The substantive changes are an `onSelectionChanged` capture in place of the controller read (same `(0,7)`) and `pump()`. The custom-toolbar asserts are NOT weakened: `findsNWidgets(1)` CupertinoButton + `find.text('Copy')` are identical, and `variant: TargetPlatformVariant.all()` is kept. The custom-controls wiring works: `selectionControls` flows through SelectableText → `SelectionArea(selectionControls:)` (selectable_text diff) → SelectableRegion (selection_area.dart:127-136). Because `cupertinoTextSelectionControls` is not a `TextSelectionHandleControls`, `_showToolbar` takes the legacy `_selectionOverlay!.showToolbar()` path (selectable_region.dart:1383-1386), which uses the controls' `buildToolbar` and bypasses the `_adaptContextMenuBuilder`.
- part_a_evidence: The diff shows only removed/added lines that differ in indentation plus the controller → callback swap. Base-on-head failed on all 6 variants with the EditableText finder `No element`.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: none
- confidence: HIGH

## Test 082 — long press selects word and shows custom toolbar (Material)
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: The changes are the same as in 081: reformatting, the controller read → `onSelectionChanged` (same `(0,7)`), and `pump()`. The asserts `findsNWidgets(2)` TextButton + 'Copy' + 'Select all' are unchanged, and all 6 platform variants are kept. The legacy `materialTextSelectionControls.buildToolbar` path is used, as in 081.
- part_a_evidence: The diff shows identical assert lines, only reindented. Base-on-head failed only on the EditableText finder.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: none
- confidence: HIGH

## Test 083 — textSelectionControls is passed to SelectionArea
- status_at_head: PASSING
- change_status: RENAMED
- part_a_verdict: WARRANTED
- part_a_details: The test was renamed from 'textSelectionControls is passed to EditableText'. `find.byType(EditableText)` → `find.byType(SelectionArea)`, `pump()` was added, and the assertion `widget.selectionControls == materialTextSelectionControls` is unchanged. The replacement is equivalent in intent: both check that the user's controls are forwarded to the widget that consumes them. SelectionArea forwards `widget.selectionControls` verbatim when non-null (selection_area.dart:126-136). It is one layer shallower than the old check, which inspected the consuming widget directly. Asserting on `SelectableRegion.selectionControls` would be strictly equivalent, and with non-null controls that would give the same result. The old test also implicitly checked that `selectionEnabled` gating passes the controls through. The new impl has no such gating (controls are always passed, and SelectionArea is only built when `enableInteractiveSelection`), so nothing is masked.
- part_a_evidence: Base-on-head (textoffsetfix) failed with `Bad state: No element` at `tester.widget(find.byType(EditableText))`. The head passes.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: Optional hardening: `expect(tester.widget<SelectableRegion>(find.byType(SelectableRegion)).selectionControls, materialTextSelectionControls)`.
- gap_ids: []
- gap_notes: none
- confidence: HIGH

## Test 084 — PageView beats SelectableText drag gestures (iOS)
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: Most of the 114 diff lines are dart-format reindentation. The substantive changes are:
  (1) `const` removed from the children list and `onSelectionChanged` added to SelectableText to capture `currentSelection`;
  (2) `await tester.pump()` after pumpWidget;
  (3) `tester.state<EditableTextState>(...).textEditingValue.selection` → `currentSelection`, plus a new `expect(currentSelection, isNotNull)`.
  Unchanged: the expected selection `(indexOf('g'), indexOf('p')+3)`, every gesture step (tap, down, pumpAndSettle, moveTo, up), and both `pageController.page` expectations (0.0, then 1.0 after the horizontal drag).
  `textOffsetToPosition` now uses the RenderParagraph-based helper, which is a helper-level surface change. Nothing was reshaped to mask behavior. The PageView-vs-selection arena behavior is still asserted. The new side comes from `eagerVictoryOnDrag = defaultTargetPlatform != iOS` in SelectableRegion's TapAndHorizontalDrag recognizer (selectable_region.dart:699-712).
- part_a_evidence: Base-on-head (textoffsetfix) failed only with `Bad state: No element` at `tester.state<EditableTextState>` (after the gestures ran), so the original gesture sequence worked on the new impl.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: none
- confidence: HIGH

## Test 085 — long press tap cannot initiate a double tap on macOS
- status_at_head: FAILING (variants: TargetPlatform.macOS)
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: `EditableTextState.hideToolbar()` → `SelectableRegionState.hideToolbar()`, the controller read → `onSelectionChanged`, and `pump()` was added: WARRANTED. The original expectation `collapsed(offset: 4, affinity: upstream)` is kept verbatim on purpose ("KEEP original assertion to signal the affinity gap"). The CupertinoButton `findsNothing` check is kept.
- part_a_evidence: Head line 3979. Base-on-head (textoffsetfix) failed with `No element` at `tester.state<EditableTextState>`.
- part_b_classification: GAP
- part_b_root_cause: The failure is `Expected collapsed(4, upstream) Actual collapsed(4, downstream)`. The offset is right, so the actual behavior under test works: a long press followed by a tap does NOT count as a double tap. The tap collapses at the tap position instead of selecting the word, and no toolbar is shown (probe). The only difference is that the SelectableText adapter drops affinity (selectable_text.dart:513).
- part_b_surface_fix: none (splitting the expectation into offset/isCollapsed would make it pass, but that would be a fake fix that hides G-NO-AFFINITY)
- gap_ids: [G-NO-AFFINITY]
- gap_notes: G-NO-AFFINITY — `expect(currentSelection, TextSelection.collapsed(offset: 4, affinity: TextAffinity.upstream))`. The old macOS tap-down `selectPosition` produced upstream affinity at the hit point (text_selection.dart:2510). SelectedContentRange exposes offsets only.
- confidence: HIGH

## Test 086 — long press tap cannot initiate a double tap on iOS
- status_at_head: FAILING (variants: TargetPlatform.iOS)
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: Reformatting; `EditableTextState.hideToolbar()` → `SelectableRegionState.hideToolbar()`; the controller read → `onSelectionChanged` (same `(0,7)`); `pump()` added. `findsNWidgets(4)` is kept verbatim. All WARRANTED.
- part_a_evidence: Head line 4026 fails with `exactly 4 ... Found 2 CupertinoButton`. The selection assertion (line above) passes. Base-on-head (textoffsetfix) failed with `No element` at `tester.state<EditableTextState>`.
- part_b_classification: GAP
- part_b_root_cause: The selection behavior matches. After the long press, the tap on the selected word hits `_positionIsOnActiveSelection` in `_handleMouseTapUp` on iOS, which toggles (shows) the toolbar and keeps (0,7) (selectable_region.dart:936-947). This mirrors the old toggle-on-selection logic. Double-tap suppression after a long press itself holds (085 proves it more directly, because on iOS a double tap would also yield (0,7)). The failure is purely the button set: the toolbar shows [Copy, Select All] instead of Copy/Look Up/Search Web/Share (probe). The root cause is the same as in 079: `getSelectableButtonItems` (selectable_region.dart:299-338) vs the EditableTextState iOS rules (editable_text.dart:2687-2727).
- part_b_surface_fix: none
- gap_ids: [G-TOOLBAR-PLATFORM]
- gap_notes: G-TOOLBAR-PLATFORM — `expect(find.byType(CupertinoButton), findsNWidgets(4))`. The iOS SelectableRegion toolbar has no Look Up, Search Web or Share, and it includes Select All for a non-collapsed selection.
- confidence: HIGH (probe)

## Group summary
- Part A: WARRANTED 5 (080, 081, 082, 083, 084); PARTIAL (still failing, edits warranted) 5 (077, 078, 079, 085, 086); FAKE FIX 0; MIXED 0; COSMETIC 0 (077/078 drop an implicit downstream-affinity check on the final collapsed(7). This is negligible and noted inline).
- Part B (failing tests): GAP 5, SURFACE 0, MIXED 0.
  - G-TOOLBAR-PLATFORM: 079, 086. Button set only. The toolbar DOES appear on a macOS touch long press in both old and new.
  - G-NO-AFFINITY: 077, 078, 085.
  - G-TAP-GESTURES: 077 (iOS touch single tap does not snap to word edge: 11 vs 12).
- Hypothesized gaps that turned out NOT to exist (probe-verified): tap-after-double-tap selection reset (works, collapses at 7 with the toolbar hidden on iOS/macOS); long-press-then-tap double-tap suppression (works); custom selectionControls toolbar wiring (works through the legacy `buildToolbar` path, selectable_region.dart:1383-1386); toolbar on a macOS touch long press (shown).
- New gap ids introduced: none.
