# Group J_recognizers_selectall_web_spaces report

Probe method: one scratch file (`zz_scratch_J_test.dart`, now deleted), 5 `flutter test` runs total. It used head's RenderParagraph-based `textOffsetToPosition`. Probe results are quoted as "PROBE".
Key code (head): SelectableRegion touch recognizers `selectable_region.dart:686-735`; `_handleMouseTapUp` collapses on the first touch tap (`:956` `_collapseSelectionAt`); long press `:1007-1035`; `selectAll()` = `clearSelection()` + `SelectAllSelectionEvent` (`:1850-1860`); `getSelectableButtonItems` `canSelectAll = selectionGeometry.hasContent` (`:306`); SelectableText adapter `_handleSelectionDetailsChanged` (`impl_head.dart:505-521`) builds `TextSelection(baseOffset,extentOffset)` with default affinity and reports `collapsed(-1)` when range is null; old `EditableTextState.selectAllEnabled` (`editable_text.dart:2673-2697`); old whitespace rule `RenderEditable.getWordAtOffset` (`editable.dart:2208-2250`); new `_SelectableFragment._handleSelectWord`/`_getWordBoundaryAtPosition` (`paragraph.dart:3183-3198`); span hit entry `paragraph.dart:828-846`, `TextSpan.handleEvent` → `recognizer?.addPointer` (`text_span.dart:272-276`).

## Test 118 — text span with tap gesture recognizer works in selectable rich text
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: (1) Adds an `onSelectionChanged` spy and changes `expect(controller.selection, TextSelection(8,12))` to `expect(selection, TextSelection(8,12))`. The value is the same, it is only read through a different API. (2) Adds `await tester.pump()` after pumpWidget so the selectables register. (3) Adds `pumpAndSettle()` after the first tap. This is harmless: the original `expect(spyTaps, 1)` already passed without it. (4) The comment is reworded. All values stay the same: spyTaps 0→1→1 and selection (8,12).
- part_a_evidence: The original body with the textoffset fix failed only at the `EditableText` finder (`failures_base_textoffsetfix_on_head/118.txt`: "Bad state: No element … WidgetController.widget … :4878"). That finder comes after both `spyTaps` assertions, so the recognizer behavior already matched. The new read path is `SelectionListenerNotifier` → `widget.onSelectionChanged` (`impl_head.dart:505-515`). NOTE: the owner's preamble TODO before this test ("SelectionArea intercepts tap gestures and prevents TextSpan recognizers from receiving them") is STALE. The test passes: the span's TapGestureRecognizer fires, and SelectableRegion's own tap also collapses the selection.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: Only the long-press arena is contested. The span here has only a tap recognizer, so SelectableRegion's LongPressGestureRecognizer wins unopposed and selects the word 8–12 (`selectable_region.dart:1007-1013`), which matches the old behavior.
- confidence: HIGH (the original assertions passed up to the stale finder)

## Test 119 — text span with long press gesture recognizer works in selectable rich text
- status_at_head: FAILING
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: Same pattern as 118. `controller.selection` becomes an `onSelectionChanged` spy, a registration `pump()` is added, and a TODO is added. The expected value `TextSelection.collapsed(11, upstream)` and `spyLongPress == 1` are unchanged. The edit is WARRANTED but still fails.
- part_a_evidence: base+textoffsetfix failed at the `EditableText` finder (`:4930`, "No element"). At head the only failure is `failures/119.txt`: "Expected: TextSelection.collapsed(offset: 11, affinity: TextAffinity.upstream…) Actual: …collapsed(offset: 11, affinity: TextAffinity.downstream…)" at line 5502.
- part_b_classification: GAP
- part_b_root_cause: The offset matches and the recognizer works. Only the affinity differs. PROBE log: after the tap `collapsed(11, downstream)`. After the long press there is no further callback, and `spy=1`. So: (a) the span's `LongPressGestureRecognizer` WINS the arena. `RenderParagraph.hitTestChildren` adds the span's `HitTestEntry` (`paragraph.dart:842`) ahead of the ancestor RawGestureDetector, so `TextSpan.handleEvent` calls `addPointer` first (`text_span.dart:274`). Both recognizers use the same kLongPressTimeout deadline, the span's timer fires first and accepts, and SelectableRegion's recognizer (`selectable_region.dart:723-733`) is rejected. The selection is therefore not changed by the long press, which matches the old intent. (b) The collapsed(11) comes from SelectableRegion's tap-up `_collapseSelectionAt` (`:956`). (c) The adapter builds `TextSelection(baseOffset: range.startOffset, extentOffset: range.endOffset)` with no affinity (`impl_head.dart:512-515`), because `SelectedContentRange` carries no affinity. The TODO's stated reason ("SelectionArea intercepts long press and/or doesn't support collapsed selection on tap") is WRONG on both counts.
- part_b_surface_fix: none. Dropping `affinity: upstream` would make it pass, but that would be a fake fix.
- gap_ids: [G-NO-AFFINITY]
- gap_notes: G-NO-AFFINITY: `expect(selection, TextSelection(11, 11, affinity: upstream))` fails only on affinity. SelectedContentRange (selectable_region.dart SelectionDetails) has start/end offsets only, and `_handleSelectionDetailsChanged` has no way to recover affinity.
- confidence: HIGH (PROBE confirmed spy=1 and a single collapsed(11, downstream) callback)

## Test 121 — The handles show after pressing Select All
- status_at_head: FAILING (variants: TargetPlatform.android, TargetPlatform.fuchsia — the only variants the test declares)
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: (1) `pump()` after pumpWidget: WARRANTED. The original failed at the first `find.text('Select all'), findsOneWidget` because the selectables were not yet registered. (2) Added `find.byType(AdaptiveTextSelectionToolbar), findsOneWidget`, which stands in for `toolbarIsVisible`: WARRANTED, equal strength. (3) `editableText.selectionOverlay!.handlesAreVisible` becomes `_SelectionHandleOverlay` widgets `findsNWidgets(2)` (twice): WARRANTED. `SelectionOverlay` (`widgets/text_selection.dart:1055`) has no public `handlesAreVisible` (only `TextSelectionOverlay` does, at `:583`). The check is slightly weaker because it ignores the `handlesVisible` flag and fade, and matching on the runtimeType string is brittle. (4) `pump()` becomes `pumpAndSettle()` after tapping Select all: neutral. No expected values changed. `Select all` → `findsNothing` is kept, which is why it fails.
- part_a_evidence: base+textoffsetfix: "Found 0 widgets with text 'Select all'" at `:4976` (the first toolbar check, caused by missing registration). Head: `failures/121_*.txt` "Expected: no matching candidates Actual: Found 1 widget with text 'Select all'" at line 5566.
- part_b_classification: GAP
- part_b_root_cause: After Select All, SelectableRegion still offers "Select all". `getSelectableButtonItems` uses `canSelectAll = selectionGeometry.hasContent` (`selectable_region.dart:306`). The old `selectAllEnabled` returns false on android/fuchsia/linux/windows when `selection.start == 0 && end == text.length`, true on iOS only when collapsed, and always false on macOS (`editable_text.dart:2684-2696`). PROBE after Select all: `copy=1 selectAll=1 toolbar=true handleWidgets=2`. So every other assertion (Copy present, Paste/Cut absent, handles still shown via `selectAll(SelectionChangedCause.toolbar)` → `_showHandles()` at `:1853-1854`) PASSES. The only failure is the Select-all visibility rule. The test fails "only on android/fuchsia" simply because those are its only variants. The rule also differs on linux/windows/iOS/macOS.
- part_b_surface_fix: none
- gap_ids: [G-TOOLBAR-PLATFORM]
- gap_notes: G-TOOLBAR-PLATFORM: `expect(find.text('Select all'), findsNothing)` after Select all. SelectableRegion has no "everything already selected" check. `SelectionGeometry` exposes `hasContent`/`status` but not whether the whole content is selected. The owner's TODO in the preamble is accurate.
- confidence: HIGH (PROBE showed all other post-select-all state matches)

## Test 122 — The Select All calls on selection changed
- status_at_head: FAILING (variants: TargetPlatform.android, TargetPlatform.fuchsia)
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: Adds `pump()` after pumpWidget: WARRANTED. The original failed with a `newSelection!` null check because no callback fired before registration. Adds a TODO comment. The in-callback `expect(newSelection, isNull)` and the offsets (4,7), (0,11) are all kept.
- part_a_evidence: base+textoffsetfix: "Null check operator used on a null value" at `:5022`. Head `failures/122_*.txt`: "while dispatching notifications for SelectionListenerNotifier: Expected: null Actual: TextSelection.invalid". Stack: `SelectableRegionState.selectAll (:1852)` → `handleSelectAll` → `_updateSelectionGeometry` → listener.
- part_b_classification: GAP
- part_b_root_cause: Tapping Select all produces TWO callbacks. PROBE android: `…(4,7) | --before selectall | TextSelection.invalid | TextSelection(0,11)`. `selectAll()` first calls `clearSelection()` (`selectable_region.dart:1851`). The adapter reports that cleared geometry as `TextSelection.collapsed(offset: -1)` (== `TextSelection.invalid`, `impl_head.dart:519`), and then the select-all geometry. The old EditableText made a single `userUpdateTextEditingValue` → one callback. The final value (0,11) is correct.
- part_b_surface_fix: none
- gap_ids: [G-OTHER-SELECTION-CALLBACK-NOISE, G-SELECTION-CAUSE]
- gap_notes: G-OTHER-SELECTION-CALLBACK-NOISE: the in-callback `expect(newSelection, isNull)`. The adapter forwards every `SelectionListenerNotifier` change, including the transient clear inside `selectAll()`. G-SELECTION-CAUSE: the transient value is `collapsed(-1)`, and the cause is `null` rather than `SelectionChangedCause.toolbar` (PROBE shows `cause=null`), although the test does not assert cause.
- confidence: HIGH

## Test 123 — The Select All calls on selection changed with a mouse on windows and linux
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: MIXED
- part_a_details: (1) `pump()` after pumpWidget: WARRANTED. The original failed with a null check because of missing registration. (2) The in-callback `expect(newSelection, isNull)` was DELETED: FAKE FIX. This is exactly the assertion that fails in sibling test 122. Removing it hides the double callback (invalid, then (0,11)) that Select all produces on linux/windows too. The right-click collapsed(5) and final (0,11) expectations are unchanged and pass.
- part_a_evidence: diff line `-                expect(newSelection, isNull);`. base+textoffsetfix: "Null check operator used on a null value" at `:5066` (registration, not the callback assertion). PROBE linux: `collapsed(5) | --before selectall | TextSelection.invalid cause=null | TextSelection(0,11) cause=null`. With the assertion restored the test would fail exactly like 122. The linux/windows path is `selectAll(); hideToolbar();` (`selectable_region.dart:1731-1734`) → `clearSelection()` + select all.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: [G-OTHER-SELECTION-CALLBACK-NOISE]
- gap_notes: masked by the deleted `expect(newSelection, isNull)`. Also, the right-click collapsed selection has downstream affinity and a null cause (not asserted).
- confidence: HIGH (PROBE logged the extra `invalid` callback on linux)

## Test 124 — Does not show handles when updated from the web engine
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: MIXED
- part_a_details: Executed (VM) part: `pump()` added; `getTopLeft(EditableText)` → `getTopLeft(SelectableText)`; `handlesAreVisible isFalse` → `_SelectionHandleOverlay findsNothing`; `currentTextEditingValue.selection == collapsed(0)` → `SelectionListener.selectionNotifier.selection.range == SelectedContentRange(0,0)`. All WARRANTED, equal strength, and a mouse click at offset 0 still yields collapsed 0 with no handles. `kIsWeb` branch: a mechanical translation to `selectionNotifier.range == (2,7)` that never runs. The file is `@TestOn('!chrome')` (base and head, line 8), so the branch was dead in base too. If it did run, it would FAIL (see below). The test title's feature is therefore not exercised at all (vacuous pass). Not a value change, but the translation claims coverage the architecture cannot provide.
- part_a_evidence: base+textoffsetfix failed at `getTopLeft(EditableText)` (`:5089`). PROBE (VM, calling `testTextInput.updateEditingValue(TextEditingValue(text:'abc def ghi', selection:(2,7)))` unconditionally): `before=(0,0) after=(0,0) hasClient=false`. SelectableRegion registers no TextInputClient (no `TextInput.attach` in selectable_region.dart), so `TestTextInput` sends to client id -1 (`flutter_test/lib/src/test_text_input.dart:214`) and the message is dropped. Separately, the test's literal `TextEditingValue(selection: TextSelection(2,7))` has empty text and asserts in `toJSON` ("Range start 2 is out of text of length 0", services/text_input.dart:1178). That is a latent bug in the ORIGINAL web branch too.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: [G-WEB-ENGINE-UPDATE]
- gap_notes: G-WEB-ENGINE-UPDATE: the `kIsWeb` expectation `range == SelectedContentRange(2,7)` could never be met. SelectableRegion has no text-input connection, so web-engine selection updates are ignored. The test only "passes" because the branch is compiled out. Recommend it be marked as a documented gap rather than counted as passing coverage.
- confidence: HIGH

## Test 125 — onSelectionChanged is called when selection changes
- status_at_head: FAILING
- change_status: UNCHANGED
- part_a_verdict: N/A (unchanged)
- part_a_details: n/a
- part_a_evidence: n/a
- part_b_classification: MIXED
- part_b_root_cause: Immediate: `failures/125.txt` "Expected: <1> Actual: <0>" at line 5735 (after the first long press). There is no `pump()` after pumpWidget, so the SelectionListener/selectables are not registered and no callback fires (surface; the same cause as base+textoffsetfix `:5136`). Deeper: with the pump added, PROBE shows lp1 → 1 callback (0,3) and lp2 → 1 callback (4,7), both matching. But `tap('Select all')` fires TWO callbacks (`TextSelection.invalid`, then (0,11)), so `expect(n, 3)` fails with "Expected: <3> Actual: <4>". Cause: `selectAll()` = `clearSelection()` + select-all event (`selectable_region.dart:1850-1852`), and the adapter forwards both (`impl_head.dart:505-521`).
- part_b_surface_fix: add `await tester.pump();` after `pumpWidget` (fixes the first two counts only; the test still fails on the third).
- gap_ids: [G-OTHER-SELECTION-CALLBACK-NOISE]
- gap_notes: G-OTHER-SELECTION-CALLBACK-NOISE: `expect(onSelectionChangedCallCount, equals(3))`. The old EditableText called `onSelectionChanged` once per user selection change. The adapter fires once per SelectionGeometry notification, including transient clears (reported as `collapsed(-1)`, which also relates to G-SELECTION-CAUSE).
- confidence: HIGH (PROBE reproduced 4 vs 3)

## Test 126 — selecting a space selects the previous word on mobile
- status_at_head: FAILING (variants: TargetPlatform.android, TargetPlatform.iOS)
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: The only change is wrapping `SelectableText` in `Material(child: Center(...))` (base: `home: SelectableText(...)` directly), plus a TODO. The expectations are unchanged, so it is not a fake fix. The wrap is not needed (MaterialApp already supplies Overlay/Localizations) and is counterproductive. `Center` shrink-wraps the SelectableRegion to the text width, so `tapAt(textOffsetToPosition(tester, 10))` (x == right edge of the paragraph) now misses the region entirely. PROBE: `rect=…471.3… p10=Offset(471.3, 308.0)`, and no callback on the tap. Without Center (base harness + pump) the same tap yields `collapsed(10)` (PROBE J126c). Verdict for the edit: COSMETIC/harness with a harmful side effect.
- part_a_evidence: head failure `failures/126_*.txt` "Expected: not null Actual: <null>" at 5770 (first `isNotNull` after tap at 10). base+textoffsetfix fails at the same point (`:5166`), there from missing registration only.
- part_b_classification: MIXED
- part_b_root_cause: Surface: (a) no `pump()` after pumpWidget (registration); (b) the added `Center` makes the end-of-text tap land exactly on the region's right edge (outside the hit area). Gap: after both surface fixes, long press on the space at 5 selects `(5,6)` (the space) instead of `(1,5)` (the previous word) on BOTH iOS and Android (PROBE J126c). Old `RenderEditable.getWordAtOffset` (`editable.dart:2238-2250`): if the pressed char is whitespace and offset > 0, iOS selects previousWord.start..offset, and Android readOnly selects previousWord.start..offset, or the single whitespace when there is no previous word. New `_SelectableFragment._handleSelectWord` → `_getWordBoundaryAtPosition` uses raw `paragraph.getWordBoundary` (`paragraph.dart:3190-3197`) with no whitespace/previous-word rule. The last step (long press at 0 → (0,1)) matches.
- part_b_surface_fix: add `await tester.pump()` after pumpWidget and remove the `Center` (or tap `textOffsetToPosition(tester,10) - Offset(1,0)`). The test will still fail on `baseOffset 1` vs 5.
- gap_ids: [G-TAP-GESTURES]
- gap_notes: G-TAP-GESTURES (whitespace word rule): `expect(selection!.baseOffset, 1); expect(selection!.extentOffset, 5)` after `longPressAt(offset 5)`. SelectableRegion's SelectWordSelectionEvent has no platform-specific "space selects previous word" logic. Owner TODO is accurate for the gap, but the current failure point is the surface issues above.
- confidence: HIGH (PROBE on both variants)

## Test 127 — selecting a space selects the space on non-mobile platforms
- status_at_head: FAILING (variants: TargetPlatform.fuchsia, TargetPlatform.linux, TargetPlatform.macOS, TargetPlatform.windows)
- change_status: UNCHANGED
- part_a_verdict: N/A (unchanged)
- part_a_details: n/a
- part_a_evidence: n/a
- part_b_classification: SURFACE
- part_b_root_cause: Failure: `failures/127_*.txt` "Expected: not null Actual: <null>" at 5827 (first tap at offset 10). Two surface causes: (a) no registration `pump()`; (b) the harness uses `Center`, and head's `textOffsetToPosition(…,10)` returns x == the paragraph's right edge. The new widget has no RenderEditable caret margin (the old EditableText was wider by the cursor width), so the tap falls outside SelectableRegion. PROBE J127b is the head body with the pump added and both end-of-text taps nudged 1px left. It PASSES on all 4 variants: collapsed(10), double-tap on space → (5,6), collapsed(10), double-tap at 0 → (0,1). RenderParagraph's raw word boundary already selects the single space, which is the desktop/fuchsia expectation. The owner TODO ("does not support selecting space on non-mobile platforms") is WRONG.
- part_b_surface_fix: add `await tester.pump();` after pumpWidget, and tap at `textOffsetToPosition(tester, 10) - const Offset(1.0, 0.0)` (both occurrences), or make the helper stay inside the paragraph at text end.
- gap_ids: []
- gap_notes: none behavioral. Minor note: the edge miss is a consequence of G-LAYOUT-SIZE (no caret margin), which affects only taps exactly at the text's trailing edge. Also noted (not asserted): the tap at 0 right after the double tap counts as a triple tap on macOS/linux/windows and selects the paragraph (0,10), and callbacks include transient `TextSelection.invalid` (G-OTHER-SELECTION-CALLBACK-NOISE).
- confidence: HIGH (PROBE passed with exactly those two fixes)

## Test 128 — double tapping a space selects the previous word on mobile
- status_at_head: FAILING (variants: TargetPlatform.android, TargetPlatform.iOS)
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: The only change is a TODO comment inside the testWidgets call (COSMETIC). The body is identical and still fails.
- part_a_evidence: diff is `+    // TODO(Renzo-Olivares): SelectionArea does not support selecting previous word on double-tapping whitespace on mobile.` only.
- part_b_classification: MIXED
- part_b_root_cause: Immediate: `failures/128_*.txt` "Expected: not null Actual: <null>" at 5895 (after the first tap at 19), caused by the missing registration `pump()` (surface). The tap at 19 is on the shorter second line, so it is not an edge miss. With the pump, PROBE: tap19 → collapsed(19) ✓. Double-tap at 5 → `(5,6)` (expected (1,5)) ✗. Double-tap at 0 → (0,1) ✓. Double-tap at 14 → `(13,15)` (expected (6,14): previous word plus all contiguous spaces across the newline) ✗. Old: `TextSelectionGestureDetectorBuilder.onDoubleTapDown` → `RenderEditable.selectWord` → `selectWordsInRange` → `getWordAtOffset`, which applies the whitespace previous-word rule (`editable.dart:2238-2250`). New: `_startNewMouseSelectionGesture` case 2 → `_selectWordAt` → `SelectWordSelectionEvent` → `paragraph.getWordBoundary` (`selectable_region.dart:764-767`, `paragraph.dart:3190-3197`).
- part_b_surface_fix: add `await tester.pump();` after pumpWidget. The test still fails at `baseOffset 1` vs 5.
- gap_ids: [G-TAP-GESTURES]
- gap_notes: G-TAP-GESTURES (whitespace word rule): `expect(selection!.baseOffset, 1)` / `extentOffset 5`, and `baseOffset 6` / `extentOffset 14`. PROBE also shows noisy intermediate callbacks during each double tap (e.g. `(5,19)`, `collapsed(5)`, then `(5,6)`), which is G-OTHER-SELECTION-CALLBACK-NOISE. Not asserted by this test.
- confidence: HIGH (PROBE on both variants)

## Group summary
- Part A verdicts: WARRANTED 1 (118); MIXED 2 (123: pump warranted + deleted single-call assertion = FAKE FIX; 124: executed part warranted + vacuous web-branch translation); PARTIAL 5 (119, 121, 122, 126, 128); N/A unchanged 2 (125, 127).
- Part B (still failing, 7 tests): GAP 3 (119 G-NO-AFFINITY; 121 G-TOOLBAR-PLATFORM; 122 G-OTHER-SELECTION-CALLBACK-NOISE/G-SELECTION-CAUSE); MIXED 3 (125 pump + CALLBACK-NOISE; 126, 128 pump/harness + G-TAP-GESTURES whitespace rule); SURFACE 1 (127: pump + end-of-text tap edge; PROBE passes with both fixes).
- Owner TODOs that are inaccurate: 118 preamble TODO (tap recognizers blocked). The test passes. 119 TODO (long press intercepted). The span's long-press recognizer wins, and only affinity differs. 127 TODO (space selection unsupported). Purely surface.
- NEW gap id: **G-OTHER-SELECTION-CALLBACK-NOISE** — the SelectableText adapter (`impl_head.dart:505-521`) forwards every `SelectionListenerNotifier` change to `onSelectionChanged`, including transient states inside one user action. Example: toolbar/menu Select all = `clearSelection()` (reported as `TextSelection.invalid`) followed by the select-all range. Double taps also emit intermediate ranges. The old EditableText fired once per committed selection change. Exposed by 122, 125 (and masked in 123).
- Taxonomy refinement: G-TAP-GESTURES here specifically means the mobile "whitespace selects previous word" rule (`RenderEditable.getWordAtOffset`), which RenderParagraph's word selection lacks. It applies to both long-press (126) and double-tap (128).
