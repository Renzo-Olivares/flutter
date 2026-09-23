# Group E_keyboard report

Shared evidence (referenced below as [E1]..[E7]):
- [E1] Helper change (helpers_and_preamble.diff): Keyboard-group `setupWidget` drops `controller = editableTextWidget.controller` and records `selection = newSelection` from `SelectableText.onSelectionChanged`; adds `await tester.pump()` before the tap. The head SelectableText builds that callback from `SelectionListenerNotifier` (material/selectable_text.dart:505-519): `TextSelection(baseOffset: range.startOffset, extentOffset: range.endOffset)`, `cause` always `null`, `collapsed(-1)` when there is no range. `SelectedContentRange` keeps direction (rendering/paragraph.dart:1656-1663 returns `_textSelectionStart/_textSelectionEnd` unsorted), so base = SelectableRegion's *start edge*, extent = *end edge*.
- [E2] Tap sets a collapsed selection in SelectableRegion (it does NOT clear): touch tap-up on Android/iOS/Fuchsia -> `_collapseSelectionAt(offset: details.globalPosition)` (widgets/selectable_region.dart:956), desktop on tap-down (:767); `_collapseSelectionAt` = `_finalizeSelection(); _selectStartTo(); _selectEndTo();` (:1503-1508). So G-NO-CARET's "tap clears" does not apply to these tests; a collapsed selection exists after a tap, it just is not painted as a caret.
- [E3] Edge choice on keyboard extension: `_determineIsAdjustingSelectionEnd(forward)` (selectable_region.dart:1622-1638) — for a collapsed selection `isReversed` is false, so `adjustingEnd = forward != isReversed = forward`: extending BACKWARD moves the START edge (which is reported as `baseOffset`, [E1]). Comment at :1636 "Always move the selection edge that increases the selection range." EditableText instead keeps base fixed and moves extent (`_UpdateTextSelectionAction`, widgets/editable_text.dart ~6595-6660, e.g. :6641). Result: backward shift/ctrl+shift/up extension from a caret yields the same magnitude with the OPPOSITE sign (base/extent swapped).
- [E4] Plain (non-shift) arrow keys are no-ops: `_GranularlyExtendCaretSelectionAction` / `_DirectionallyExtendCaretSelectionAction` `if (intent.collapseSelection) { // Selectable region never collapses selection. return; }` (selectable_region.dart:2059-2062, :2075-2078). EditableText moves the caret.
- [E5] Scratch probe (zz_scratch_E_test.dart, deleted), default platform Android, single variant:
  - 'a big house' center tap -> `(11,11)`; shift+left -> `(10,11)`; again -> `(9,11)`.
  - 'their big house' ctrl+shift+left -> `(10,15)`.
  - 'a big house' shift+up -> `(0,11)`; then shift+down -> `(11,11)`.
  - 3-line text: tapAt(0) -> `(0,49)` then `(0,0)` (two callbacks); 5x arrowRight -> NO callbacks (caret stays at 0); shift+down -> `(0,12)`, `(0,32)`; shift+up -> `(0,12)`, `(0,0)`; shift+up at offset 0 -> no callback.
  - 'a big house\njumped over a mouse': center tap -> `(31,31)` (single callback); tapAt(0) -> `(0,31)` then `(0,0)`; each shift+right -> exactly one callback `(0,1)`..`(0,5)`.
  - Two SelectableTexts: after 5x shift+left in #1 -> `(6,11)`; after reorder (keyed) 5 more -> `(1,11)` (magnitude 10, focus retained). Second SelectableText's callback is never called until it is interacted with (`s2 == null` after tapping #1). Tapping #2 does not clear #1 (lifecycleState is null in tests, so `_handleFocusChanged` clear at selectable_region.dart:533 is skipped — same gating as old impl_base.dart:597).
  - `cause` was `null` on every callback.
- [E6] Original bodies (+Overlay fix +RenderParagraph textOffsetToPosition) all fail first on `Bad state: No element` at `tester.widget(find.byType(EditableText).first)` (failures_base_textoffsetfix_on_head/045..055) — a pure finder/API surface failure; none of the originals reach their assertions.
- [E7] None of the base bodies 045-055 assert `cause` (only 052 declares the parameter, unused). So no `cause` assertion was dropped in this group; G-SELECTION-CAUSE is untested here.

## Test 045 — Shift test 1
- status_at_head: FAILING (variants: RawKeyEvent, ui.KeyData then RawKeyEvent)
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: Only change is `controller.selection` -> `selection!` from the onSelectionChanged-based helper [E1] (+ reformatting). Expectation `-1` unchanged. The edit itself is WARRANTED; test still fails.
- part_a_evidence: diff 045: `-expect(controller.selection.extentOffset - controller.selection.baseOffset, -1);` / `+expect(selection!.extentOffset - selection!.baseOffset, -1);`. Original failed only on the EditableText finder [E6].
- part_b_classification: GAP
- part_b_root_cause: failures/045_*.txt `Expected: <-1> Actual: <1>` at line 1809. Center tap places a collapsed selection at 11 [E2][E5]; shift+left moves the START edge (reported as base) to 10, giving `(10,11)` [E3][E5]. Old EditableText: base 11 fixed, extent 10. Same span, inverted anchor/focus.
- part_b_surface_fix: none (only a sign-agnostic assertion, which would weaken the test, would pass)
- gap_ids: [G-KEYBOARD-NAV, G-OTHER-KEYBOARD-ANCHOR-INVERTED]
- gap_notes: G-OTHER-KEYBOARD-ANCHOR-INVERTED: `expect(selection!.extentOffset - selection!.baseOffset, -1)`. SelectableRegion's `_determineIsAdjustingSelectionEnd` moves the start edge when extending backward from a collapsed selection (selectable_region.dart:1622-1638), and SelectableText maps start->baseOffset (selectable_text.dart:513-517), so the reported base is the moving edge. The owner's TODO wording elsewhere ("always extends forward") is imprecise: the extension goes backward correctly; base/extent are swapped.
- confidence: HIGH (verified by probe [E5]).

## Test 046 — Shift test 2
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: (1) `controller.selection = const TextSelection.collapsed(offset: 3)` -> `await tester.tapAt(textOffsetToPosition(tester, 3))` — sets the same collapsed selection via the only public route SelectableRegion offers [E2]; (2) `controller.selection` -> `selection!` [E1]. Expected value `1` unchanged, no cause assertion existed [E7]. Passes because forward extension moves the END edge (= extent) [E3], which coincides with EditableText. Weakness inherited from the original (delta-only assertion), not introduced.
- part_a_evidence: diff 046 (4 lines). Original failed only at the EditableText finder [E6]. A tap after the setup center tap is >kDoubleTapSlop away (center x~400 vs offset 3), so it is a fresh single tap -> `_collapseSelectionAt` (selectable_region.dart:956).
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: none (note: the tap produces a transient `(3,9)` callback before `(3,3)` — see test 052 — but this test only reads the final value).
- confidence: HIGH

## Test 047 — Control Shift test
- status_at_head: FAILING (variants: RawKeyEvent, ui.KeyData then RawKeyEvent)
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: `controller.selection` -> `selection!` [E1]; reformat. Expectation `-5` unchanged. Edit WARRANTED.
- part_a_evidence: diff 047; original failed only at finder [E6].
- part_b_classification: GAP
- part_b_root_cause: failures/047_*.txt `Expected: <-5> Actual: <5>` line 1837. ctrl+shift+left -> `ExtendSelectionToNextWordBoundaryIntent` -> `_granularlyExtendSelection(word, forward:false)`, start edge moves 15->10, reported `(10,15)` [E3][E5]. Word-boundary magnitude matches EditableText; anchor is inverted.
- part_b_surface_fix: none
- gap_ids: [G-KEYBOARD-NAV, G-OTHER-KEYBOARD-ANCHOR-INVERTED]
- gap_notes: same as 045; assertion `expect(selection!.extentOffset - selection!.baseOffset, -5)`.
- confidence: HIGH

## Test 048 — Down and up test
- status_at_head: FAILING (variants: RawKeyEvent, ui.KeyData then RawKeyEvent)
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: `controller.selection` -> `selection!` in both asserts [E1]; reformat. Expectations `-11` and `0` unchanged. Edit WARRANTED.
- part_a_evidence: diff 048; original failed only at finder [E6].
- part_b_classification: GAP
- part_b_root_cause: failures/048_*.txt `Expected: <-11> Actual: <11>` line 1851. shift+up on the only line: `_directionallyExtendSelection(false)` moves the START edge to 0 -> `(0,11)` [E3][E5]. The second assertion (shift+down -> `(11,11)`, delta 0) would pass [E5]; only the sign of the first is wrong.
- part_b_surface_fix: none
- gap_ids: [G-KEYBOARD-NAV, G-OTHER-KEYBOARD-ANCHOR-INVERTED]
- gap_notes: same mechanism as 045 applied to `ExtendSelectionVerticallyToAdjacentLineIntent` (selectable_region.dart:391-392, :1659-1680). Assertion `expect(selection!.extentOffset - selection!.baseOffset, -11)`.
- confidence: HIGH

## Test 049 — Down and up test 2
- status_at_head: FAILING (variants: RawKeyEvent, ui.KeyData then RawKeyEvent)
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: (1) `controller.selection = collapsed(0)` -> `tapAt(textOffsetToPosition(tester, 0))` — WARRANTED [E2]; (2) `controller.selection` -> `selection!` x5 — WARRANTED [E1]; (3) a comment added before the last expect ("SelectionArea might not support moving to 0 on ArrowUp at top line, or it might collapse") — COSMETIC but its diagnosis is wrong (see Part B). All five expectations (12, 32, 12, 0, -5) unchanged.
- part_a_evidence: diff 049; original failed only at finder [E6].
- part_b_classification: GAP
- part_b_root_cause: failures/049_*.txt `Expected: <-5> Actual: <0>` line 1914. The five plain arrowRight presses are ignored by SelectableRegion (`collapseSelection` early return, selectable_region.dart:2059-2062) [E4][E5], so the caret stays at 0 instead of 5. The first four assertions pass only by coincidence: vertical moves preserve the column, so `(0,12)`/`(0,32)`/`(0,12)`/`(0,0)` have the same deltas as EditableText's `5->17/37/17/5` [E5]. The last shift+up starts from a collapsed selection at 0 and cannot extend, so no callback fires and the delta stays 0 (EditableText: extent 5 -> 0, delta -5). The anchor inversion [E3] is not what trips this assertion.
- part_b_surface_fix: none
- gap_ids: [G-KEYBOARD-NAV]
- gap_notes: G-KEYBOARD-NAV: plain arrow/caret-movement intents are dropped by `_GranularlyExtendCaretSelectionAction` ("Selectable region never collapses selection"), so a collapsed caret cannot be moved; exposed by `expect(selection!.extentOffset - selection!.baseOffset, -5)`. The earlier `12/32/12/0` assertions hide that the caret is at 0, not 5 (it is the delta-only form of the original assertions that makes them pass; the head did not change them).
- confidence: HIGH (probe [E5] shows no callbacks for the 5 arrowRight presses and none for the final shift+up).

## Test 050 — Copy test
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: Removed EditableText/controller lookup; added `await tester.pump()`; `controller.selection = collapsed(0)` -> `tapAt(textOffsetToPosition(tester, 0))`. Clipboard expectation `'a big'` and all key steps unchanged. Selection reaches (0,5) through shift+right (end edge moves forward [E3][E5]); ctrl+C -> `_CopySelectionAction` -> `state._copy()` (selectable_region.dart:2026-2034).
- part_a_evidence: diff 050: `-controller.selection = const TextSelection.collapsed(offset: 0);` `+await tester.tapAt(textOffsetToPosition(tester, 0));`; original failed only at finder [E6].
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: none. (The trailing unasserted arrowRight is a no-op now [E4]; it was never asserted.)
- confidence: HIGH

## Test 051 — Select all test
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: Controller read replaced with an `onSelectionChanged` capture [E1]; `pump()` added; `expect(selection, isNotNull)` added (strengthening/guard). `baseOffset 0` / `extentOffset 31` unchanged. ctrl+A -> `_SelectAllAction` -> `selectAll(SelectionChangedCause.keyboard)` (selectable_region.dart:2015-2023); the keyboard cause is dropped by SelectableText's mapping (always `null`, selectable_text.dart:517) but the base test never asserted cause [E7].
- part_a_evidence: diff 051; original failed only at finder [E6].
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: none
- confidence: HIGH

## Test 052 — keyboard selection should call onSelectionChanged
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: MIXED
- part_a_details:
  - (a) WARRANTED: controller lookup removed; `controller.selection = collapsed(0)` (programmatic, no callback in old impl) -> `tapAt(textOffsetToPosition(tester, 0))` + `expect(selections.last, collapsed(0))`.
  - (b) COSMETIC/equivalent: `tap(find.byType(SelectableText))` -> `tapAt(textOffsetToPosition(tester, 31))`; the center tap still gives exactly `(31,31)` at head [E5], so the swap was unnecessary but harmless; added `expect(selections, isEmpty)` before the tap is a mild strengthening.
  - (c) FAKE FIX (weakening): the original callback body `expect(newSelection, isNull); newSelection = selection;` asserted exactly ONE callback per selection change (every consumer reset `newSelection = null`). Head collects into a list and only checks `selections.last`/`isNotEmpty`. This masks that at head a tap onto an existing selection fires TWO callbacks, a transient uncollapsed `(0,31)` then `(0,0)` [E5] (`_collapseSelectionAt` calls `_selectStartTo` then `_selectEndTo`, each notifying the listener; selectable_region.dart:1503-1508). With the original callback the `tapAt(0)` step would throw. For the keyboard loop itself the weakening masks nothing: each shift+right fires exactly one callback `(0,i+1)` [E5].
  - No `cause` assertion existed in either version [E7] (cause is always null at head: G-SELECTION-CAUSE, untested here).
- part_a_evidence: diff 052: `-expect(newSelection, isNull);` `-newSelection = selection;` `+selections.add(selection);`; `-expect(newSelection!.baseOffset, 0);` `+expect(selections.last.baseOffset, 0);`. Probe [E5]: `[tap 0] S:(0,31) | S:(0,0)`; `[shift+right i] S:(0,i+1)` (single).
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: [G-OTHER-SPURIOUS-SELECTION-CALLBACKS]
- gap_notes: G-OTHER-SPURIOUS-SELECTION-CALLBACKS: masked by switching from "exactly one callback" to `selections.last`. A tap that re-collapses an existing selection reports an intermediate range (new start + old end) before the final collapsed range, because SelectionListenerNotifier notifies on each edge update. The old EditableText fired `onSelectionChanged` once per user change (impl_base.dart:611-619).
- confidence: HIGH for (c)'s mechanism (probe shows the double callback); MEDIUM that the original would have thrown at exactly that step (not run, inferred from the callback body).

## Test 053 — Changing positions of selectable text
- status_at_head: FAILING (variants: RawKeyEvent, ui.KeyData then RawKeyEvent)
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: WARRANTED pieces: controllers `c1` -> `selection1` via `onSelectionChanged` on key1 in both pumps [E1]; `tap(find.byType(EditableText).first)` -> `tapAt(textOffsetToPosition(tester, 11))` (end of 'a big house'; center tap of old gave the same end caret); added `pump()` after each pumpWidget and `pumpAndSettle()` inside the second loop (unnecessary — the probe without inner pumps gives the same values — but harmless); added `expect(selection1, isNotNull)` guards; TODO comments. Expectations `-5` and `-10` unchanged.
- part_a_evidence: diff 053; original failed at `EditableText` finder (line 1952 of zz_base file) [E6].
- part_b_classification: GAP
- part_b_root_cause: failures/053_*.txt `Expected: <-5> Actual: <5>` line 2116: anchor inversion [E3], `(6,11)`. Past that, the widget-reorder part works: state is kept (keyed), focus is retained and extension continues to `(1,11)` (magnitude 10) [E5]; so the only failure is the sign, at both assertions.
- part_b_surface_fix: none
- gap_ids: [G-KEYBOARD-NAV, G-OTHER-KEYBOARD-ANCHOR-INVERTED]
- gap_notes: assertions `expect(selection1!.extentOffset - selection1!.baseOffset, -5)` and `..., -10)`; same mechanism as 045. The TODO text "always extends forward" is imprecise (it extends backward; base/extent are swapped).
- confidence: HIGH (probe [E5] reproduced both phases).

## Test 054 — Changing focus test
- status_at_head: FAILING (variants: RawKeyEvent, ui.KeyData then RawKeyEvent)
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: WARRANTED pieces: controllers `c1`/`c2` -> `selection1`/`selection2` via `onSelectionChanged` [E1]; `tap(find.byType(SelectableText).first/.last)` -> `tapAt(textOffsetToPosition(tester, 11))` / `(17, index: 1)`; `pump()`; `isNotNull` guards; TODOs. Expectations (-5, 0, -5, -5) unchanged. Latent head bug: `expect(selection2!.extentOffset - selection2!.baseOffset, 0)` (head line ~2216) dereferences `selection2`, which is still `null` at that point because the second SelectableText's callback never fired [E5]; the original read `c2.selection` = `(-1,-1)`, delta 0. Once the sign gap is fixed this line throws a null-check error; it should be `expect(selection2, isNull)` (or `selection2 == null || delta == 0`).
- part_a_evidence: diff 054 `+expect(selection2!.extentOffset - selection2!.baseOffset, 0);`; probe `s2 after tap1 = null`.
- part_b_classification: MIXED
- part_b_root_cause: failures/054_*.txt `Expected: <-5> Actual: <5>` line 2215: anchor inversion [E3] (`(6,11)`). Behind it: (surface) `selection2!` null deref on the next line; after tapping #2, #1 keeps `(6,11)` (no clear, same lifecycle gating as old) and #2 goes to `(12,17)` [E5] — both would fail only on the sign again.
- part_b_surface_fix: replace `expect(selection2!.extentOffset - selection2!.baseOffset, 0)` with `expect(selection2, isNull)` (no callback is fired for a SelectableText that has never had a selection; old API exposed `(-1,-1)`). The remaining failures are the gap.
- gap_ids: [G-KEYBOARD-NAV, G-OTHER-KEYBOARD-ANCHOR-INVERTED]
- gap_notes: assertions `expect(selection1!...,-5)` (x2) and `expect(selection2!...,-5)`; same mechanism as 045. Focus change itself behaves like the old impl in tests (no clear because `lifecycleState` is null; selectable_region.dart:533 vs impl_base.dart:597).
- confidence: HIGH (probe values for every checkpoint).

## Test 055 — Caret works when maxLines is null
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: `controller.selection.baseOffset == -1` (initially no selection) -> `expect(selection, isNull)` (no callback yet = no selection; equivalent under [E1]); `controller.selection.baseOffset == 0` after tap -> `selection!.baseOffset == 0` (+ `isNotNull` guard) captured from `onSelectionChanged`; `pump()` added. The tap creates a collapsed selection at 0 via `_collapseSelectionAt` [E2], so the test still asserts that a tap with `maxLines: null` positions the selection at the tapped offset. Both then and now it never asserted that a caret is painted, so no caret assertion was dropped. Caveat for the reader: at head the "caret" is an unpainted collapsed selection (cursor params are no-ops, G-NO-CARET), but this test never covered painting.
- part_a_evidence: diff 055 `-expect(controller.selection.baseOffset, -1);` `+expect(selection, isNull);` / `-expect(controller.selection.baseOffset, 0);` `+expect(selection!.baseOffset, 0);`; original failed only at finder (failures_base_textoffsetfix_on_head/055.txt line 2063) [E6].
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: none (test name implies a caret; the gap G-NO-CARET exists but is not exercised by this assertion).
- confidence: HIGH

## Group summary
- Part A verdicts: WARRANTED 4 (046, 050, 051, 055); MIXED 1 (052: finder/API swaps warranted + removal of the one-callback-per-change invariant = FAKE FIX); PARTIAL (still failing, edits warranted) 6 (045, 047, 048, 049, 053, 054). No expectation values changed in any test of this group, and no `cause` assertion existed to drop.
- Part B (6 failing): GAP 5 (045, 047, 048, 049, 053); MIXED 1 (054: `selection2!` null deref is surface, sign failures are gap).
- Root causes: 045/047/048/053/054 all fail on the same thing: keyboard extension from a collapsed selection works with the right magnitude, but SelectableRegion moves the start edge when extending backward, which SelectableText reports as `baseOffset`, so the sign is inverted. 049 fails because plain arrow keys cannot move the collapsed caret (SelectableRegion ignores `collapseSelection` intents); its first four assertions pass by coincidence.
- The tap in SelectableRegion DOES set a collapsed selection on every platform (touch: tap-up; desktop: tap-down), so an initial selection via `tapAt` is a legitimate replacement for `controller.selection = collapsed(n)`.
- NEW gap ids:
  - G-OTHER-KEYBOARD-ANCHOR-INVERTED: when extending a collapsed or forward selection backward by keyboard (shift+left, ctrl+shift+left, shift+up), SelectableRegion moves the start edge (`_determineIsAdjustingSelectionEnd`, selectable_region.dart:1622-1638) and SelectableText maps start->baseOffset/end->extentOffset (selectable_text.dart:513-517), so the reported base is the moving edge. EditableText keeps base fixed and moves extent. Could be fixed in the adapter by tracking which edge moved, or in SelectableRegion by reporting anchor/focus. (Arguably a sub-case of G-KEYBOARD-NAV; kept separate because it is not the "no caret" issue and has a different fix.)
  - G-OTHER-SPURIOUS-SELECTION-CALLBACKS: `onSelectionChanged` fires more than once per user action; a tap that re-collapses an existing selection reports a transient `(newStart, oldEnd)` range before the collapsed one, because SelectionListenerNotifier notifies on each edge event of `_collapseSelectionAt`. Hidden by test 052's switch to `selections.last`.
- Correction to the owner's TODOs in 053/054: "SelectionArea always extends forward" is inaccurate; the extension goes backward, but base/extent are swapped. The 049 comment ("might not support moving to 0 on ArrowUp at top line") is also wrong: the root cause is that the five plain arrowRight presses are ignored.
