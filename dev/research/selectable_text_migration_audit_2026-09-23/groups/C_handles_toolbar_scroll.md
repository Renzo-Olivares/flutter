# Group C_handles_toolbar_scroll report

Scratch probes (packages/flutter/test/material/zz_scratch_C_test.dart, 3 runs, now deleted) are referred to as P28/P30/P33/P33b/P34/P39.

## Test 027 — Can drag handles to change selection
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: (1) `controller.selection` reads → `onSelectionChanged` capture + `expect(selection, TextSelection(4,7))`, `(4,11)`, `(0,11)` — all three numeric expectations identical to base (base: base 4/extent 7, 4/11, 0/11). (2) `renderEditable.getEndpointsForSelection(selection)` → `getSelectionEndpoints(tester)` (reads `SelectableRegionState.selectionOverlay.selectionEndpoints`). (3) Added `await tester.pump()` after pumpWidget (selectables register a frame later). (4) `pump(); pump(200ms)` → `pumpAndSettle()`. (5) Left-handle drag re-reads endpoints (`newEndpoints[0]`) instead of reusing the pre-drag `endpoints[0]`; the start handle did not move during the right-handle drag so this is equivalent. Removed comment is cosmetic.
- part_a_evidence: Original (textoffsetfix run) fails `Bad state: No element` at `tester.widget(find.byType(EditableText))`. New endpoint source: selectable_region.dart:434 (`SelectionOverlay? get selectionOverlay`), SelectionOverlay.selectionEndpoints text_selection.dart:1458, populated from SelectableRegion at selectable_region.dart:1306. Old source: RenderEditable.getEndpointsForSelection (text_selection.dart:566). Handle-drag start offsets `+Offset(1,1)` / `(-1,1)` and targets (`textOffsetToPosition(11)`, `(0)`) unchanged.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: none
- confidence: HIGH (values/steps preserved verbatim; only reading API changed)

## Test 028 — Dragging handles calls onSelectionChanged
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: MIXED
- part_a_details: WARRANTED pieces: added registration `pump()`; `findRenderEditable().getEndpointsForSelection` → `getSelectionEndpoints(tester)`; `pump();pump(200ms)` → `pumpAndSettle()`; expectations (4,7) and (4,9) unchanged. UNNECESSARY WEAKENING piece: deleted the in-callback `expect(newSelection, isNull);` which asserted the callback fires exactly once per gesture (no duplicate/intermediate notifications). This masks no gap: P28 (original body + pump, recording every call) showed exactly one call per phase — long-press `[TextSelection(4,7)]`, handle drag `[TextSelection(4,9)]` — so the deleted assertion would still pass on the new implementation and should be restored.
- part_a_evidence: base line 10 `expect(newSelection, isNull);` removed. Original (textoffsetfix run) fails `Null check operator used on a null value` at `newSelection!.baseOffset` — cause is the missing registration pump (callback never fired), not duplicate calls. New callback path: `_handleSelectionDetailsChanged` in impl_head (SelectionListenerNotifier → onSelectionChanged(selection, null)).
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none (recommend restoring `expect(newSelection, isNull)` inside the callback; verified by P28 that it would pass)
- gap_ids: []
- gap_notes: none
- confidence: HIGH (P28 directly recorded the call sequence)

## Test 029 — Cannot drag one handle past the other
- status_at_head: FAILING
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: 95 diff lines are mostly re-indentation (testWidgets call reformatted to multi-line). Semantic edits are all WARRANTED: controller reads → `onSelectionChanged` capture; `getEndpointsForSelection` → `getSelectionEndpoints`; registration `pump()`; `pump()` → `pumpAndSettle()`. All expectations preserved: (4,7) after long press, (4,5) after dragging the end handle onto 'e', and (4,5) after dragging it further to 'c' (the clamp assertion and its comment are kept). Handle grab point `endpoints[1].point + Offset(4,0)` unchanged. No weakening — the owner kept the test failing to expose the gap.
- part_a_evidence: head failure: `Expected: TextSelection(baseOffset: 4, extentOffset: 5) Actual: TextSelection(baseOffset: 4, extentOffset: 2)` at selectable_text_test.dart:1126 (the final assertion). The intermediate (4,5) assertion passes.
- part_b_classification: GAP
- part_b_root_cause: Old handle drag (TextSelectionOverlay, text_selection.dart:781-866, Android/Fuchsia/Linux/Windows branch) builds `TextSelection(baseOffset: _selection.baseOffset, extentOffset: position.offset)` and at text_selection.dart:855-856 `if (newSelection.baseOffset >= newSelection.extentOffset) return; // Don't allow order swapping.` (start-handle mirror at :987). SelectableRegion's `_handleSelectionEndHandleDragUpdate` (selectable_region.dart:1247-1262) just moves `_selectionEndPosition` by `details.delta` and calls `_triggerSelectionEndEdgeUpdate()` (selectable_region.dart:1115) with no ordering check, so the end edge crosses the start and the selection becomes (4,2) (reversed). No test-side fix possible; the behavior itself differs.
- part_b_surface_fix: none
- gap_ids: [G-HANDLE-CLAMP]
- gap_notes: G-HANDLE-CLAMP — exposed by the final `expect(selection, TextSelection(baseOffset: 4, extentOffset: 5))`. EditableText/TextSelectionOverlay forbids handle crossing on non-Apple platforms (≥1 char always selected; Apple platforms instead swap base/extent, text_selection.dart:806-833). SelectableRegion's handle drag feeds raw edge updates and permits inverted selections. The default test platform is Android, so the old clamp applies.
- confidence: HIGH (code paths read on both sides; failure value matches unclamped behavior)

## Test 030 — Can use selection toolbar
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: MIXED
- part_a_details: FAKE FIX piece — the entry path changed. Base: single tap at 'e' places a collapsed caret, then the test taps the collapsed caret *handle* (`endpoints[0].point + Offset(1,13)`) to open the "select all" menu (old `_handleSelectionHandleTapped` → `toggleToolbar()` when the selection is collapsed). Head: replaced both steps with `tester.longPressAt(e)` (which selects the word 'def' and shows the toolbar), plus a new `expect(selection, (4,7))`. So the test no longer exercises "tap → caret handle → tap handle → toolbar". WARRANTED pieces: Select all → `(0, testValue.length)` preserved; Copy → `isCollapsed == true` preserved; controller reads → onSelectionChanged; `skipPastScrollingAnimation` / `pump` → `pumpAndSettle`.
- part_a_evidence: base lines: `await tester.tapAt(textOffsetToPosition(tester, testValue.indexOf('e')));` … `await tester.tapAt(endpoints[0].point + const Offset(1.0, 13.0));` → head `await tester.longPressAt(ePos);`. Old toggle: impl_base.dart:637-639 (`if (_controller.selection.isCollapsed) _editableText!.toggleToolbar();`, wired at impl_base.dart:781) → editable_text.dart:5228. P30 (tap at 'e' on the new impl): `selection=TextSelection.collapsed(offset: 5) overlay=null toolbar=0` — the tap does make a collapsed selection (selectable_region.dart:955 `_collapseSelectionAt` on tap-up for mobile) but no SelectionOverlay/handle is created (handles only come from `_showHandles`, selectable_region.dart:1336, not called on single tap), so there is no caret handle to tap and `getSelectionEndpoints` would fail its `isNotNull`. Original (textoffsetfix run) fails at `tester.widget(find.byType(EditableText))`. P30 after long-press: buttons `[Copy, Share, Select all]` (Share is extra vs the old read-only menu, but the test does not assert the button set).
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: [G-NO-CARET, G-TOOLBAR-PLATFORM]
- gap_notes: G-NO-CARET — masked by removing the tap-then-tap-caret-handle steps: no visible caret or collapsed handle after a tap (P30 overlay=null), so tapping the caret handle to toggle the toolbar cannot be done. G-TOOLBAR-PLATFORM — (secondary, not asserted) the long-press toolbar on Android now contains Share in addition to Copy/Select all.
- confidence: HIGH (P30 confirms there is no overlay after a tap; old toggle path cited)

## Test 032 — Can drag handles to change selection in multiline
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: MIXED
- part_a_details: WARRANTED pieces: controller → onSelectionChanged capture (plus added `isNotNull`); `getEndpointsForSelection` → `getSelectionEndpoints`; registration pump; manual `startGesture`+`pump(2s)`+`up` → `longPressAt` (same long-press gesture). All selection expectations preserved: (39,44), (39,50), (5,50), then collapsed after Copy. Handle offsets and targets unchanged. VALUE-CHANGE piece (low severity): absolute x positions changed `firstPos/secondPos/thirdPos.dx 24.5 → 26.0` and `middleStringPos.dx 58.5 → 60.0` (+1.5 each). The relative checks (`firstPos.dx == secondPos.dx == thirdPos.dx`, dy ordering) are kept.
- part_a_evidence: The +1.5 is exactly half of RenderEditable's caret margin: `double get _caretMargin => _kCaretGap + cursorWidth;` (rendering/editable.dart:1279, `_kCaretGap = 1.0` at :25, SelectableText cursorWidth 2.0 → 3px) added to the laid-out width (editable.dart:2414/2427). Inside `overlay()`'s `Center`, the old box was 3px wider, so its left edge sat 1.5px further left. RenderParagraph has no caret margin. Both helpers measure the caret x of a collapsed position, so the change reflects a real layout width difference, not a helper artifact (the latest commit ece56299239 "remove legacy RenderEditable caret margin" is this change). Original (textoffsetfix run) fails at `tester.widget(find.byType(EditableText))`.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: [G-LAYOUT-SIZE]
- gap_notes: G-LAYOUT-SIZE — the dx rewrite hides the 3px narrower intrinsic width (no caret margin). Centered SelectableText content shifts 1.5px. This is cosmetic and arguably more correct, but it is a real geometry difference that the new numbers absorb. It does not hide any selection-behavior difference.
- confidence: HIGH (arithmetic matches _caretMargin/2 exactly)

## Test 033 — Can scroll multiline input
- status_at_head: FAILING
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: All edits WARRANTED: controller → onSelectionChanged capture (+`isNotNull`); `controller.text.substring` → `kMoreThanFourLines.substring` (same string); `getEndpointsForSelection` → `getSelectionEndpoints`. The selection expectations (77,82, "won't") and all scroll/hit-test expectations are unchanged. The Scrollable is not found through a stale finder: the test never looks up a Scrollable/ScrollPosition, only positions and `inputBox.hitTest`.
- part_a_evidence: head failure at selectable_text_test.dart:1400 = `expect(newFirstPos.dy, firstPos.dy)`: `Expected: <298.0> Actual: <216.0>`. The earlier asserts pass: the manual drag scroll works (P33: maxScrollExtent 102, pixels 102 after the fling), and long-press selects (77,82).
- part_b_classification: MIXED
- part_b_root_cause: The immediate cause is timing. On the new implementation, dragging a handle above the viewport scrolls through the Scrollable selection delegate's `EdgeDraggingAutoScroller` (scrollable.dart:1171-1185, `startAutoScrollIfNecessary` at :1302; scrollable_helpers.dart:237-318). It animates in steps of at most 20px (`overDragMax`), each step being an `animateTo` of 33ms, and the next step starts only on a later frame. The test does one `pump(Duration(seconds: 1))`, so exactly one 20px step runs (pixels 102→82; 298-216 = 82). P33 frame trace: 102,102,82,62,42,22,2,0. The old implementation scrolled synchronously: the handle drag → `userUpdateTextEditingValue(..., SelectionChangedCause.drag)` (text_selection.dart:1028-1032) → `_bringIntoViewBySelectionState` (editable_text.dart:4780-4804, Android: `bringIntoView(newSelection.base)` when the base moved) → `bringIntoView` → `_scrollController.jumpTo` (editable_text.dart:5171-5175), a single jump. Behind the timing there is a behavioral difference. Edge autoscroll keeps scrolling while the pointer is held, so the selection start overshoots to offset 0 (P33/P33b: selection ends at (0,82)). The old code revealed exactly the dragged-to position (offset 5, just after "First"). The test does not assert the post-drag selection, so this difference is not caught.
- part_b_surface_fix: Replace the `await tester.pump(const Duration(seconds: 1));` right after `gesture.moveTo(newHandlePos + const Offset(0.0, -10.0))` with `await tester.pumpAndSettle();` (or pump enough frames while the pointer is held). P33b verified that the full test then PASSES. Note this fix adapts the test to incremental autoscroll and the selection is then (0,82), not (5,82).
- gap_ids: [G-SCROLLING, G-LONGPRESS-DRAG]
- gap_notes: G-SCROLLING — exposed by `expect(newFirstPos.dy, firstPos.dy)` (line 1400): handle drag uses frame-by-frame edge autoscroll (20px per step, velocityScalar 30) instead of EditableText's immediate `bringIntoView` jump. Scrolling continues while the handle is held past the edge instead of stopping at the revealed caret. G-LONGPRESS-DRAG (handle-drag variant; consider a new id G-HANDLE-DRAG-AUTOSCROLL) — the overshoot changes the resulting selection (start → 0 instead of 5). No current assertion catches it; it would show up if the test asserted the selection after the drag.
- confidence: HIGH (P33 frame trace and P33b pass with pumpAndSettle)

## Test 034 — ScrollBehavior can be overridden
- status_at_head: FAILING
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: Removed the two `tester.widget<EditableText>(...).scrollBehavior` expectations (null / equals(behavior)). This is WARRANTED: EditableText no longer exists, and the kept `Scrollable.scrollBehavior` expectations were meant to carry the same intent. The kept Scrollable expectations are now wrong for the new architecture, so the test fails.
- part_a_evidence: head failure at selectable_text_test.dart:1422: `expect(tester.widget<Scrollable>(find.byType(Scrollable)).scrollBehavior, isNotNull)` → `Actual: <null>`. Old: EditableText passed `scrollBehavior: widget.scrollBehavior ?? ScrollConfiguration.of(context).copyWith(scrollbars: _isMultiline, overscroll: false)` directly to its Scrollable (editable_text.dart:5929-5933). New: selectable_text.dart:593-598 wraps the same behavior in a `ScrollConfiguration` around `SingleChildScrollView`, whose internal `Scrollable(...)` (single_child_scroll_view.dart:261-268) has no `scrollBehavior` argument, so `Scrollable.scrollBehavior` is null and the behavior is inherited through `ScrollConfiguration.of`.
- part_b_classification: SURFACE
- part_b_root_cause: The test inspects an implementation detail (the `Scrollable.scrollBehavior` constructor field). The effective behavior is correctly configured through the inherited ScrollConfiguration. The same object identity is delivered, and the defaults (scrollbars only when multiline, no overscroll) are identical to the old ones.
- part_b_surface_fix: Replace both Scrollable assertions with `ScrollConfiguration.of(tester.element(find.byType(Scrollable)))`, i.e. `expect(ScrollConfiguration.of(tester.element(find.byType(Scrollable))), isNotNull)` and `expect(ScrollConfiguration.of(tester.element(find.byType(Scrollable))), same(behavior))` (or `equals`). P34 verified that this passes (the default case returns `_WrappedScrollBehavior`; the override case is `same(behavior)`). Alternative impl-side fix: SingleChildScrollView does not expose `scrollBehavior`, so matching the old field exactly would need a custom Scrollable.
- gap_ids: []
- gap_notes: none. Side note (not tested here): the old EditableText used `_NeverUserScrollableScrollPhysics` for single-line iOS (editable_text.dart:5920-5923), and the new SingleChildScrollView just uses `widget.scrollPhysics` — a possible G-SCROLLING item for another test.
- confidence: HIGH (P34 passes with the surface fix)

## Test 037 — Can align to center
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: MIXED
- part_a_details: WARRANTED: `findRenderEditable` → `findRenderParagraph`; `editable.getLocalRectForCaret(TextPosition(offset: 2)).topLeft` → `paragraph.getOffsetForCaret(TextPosition(offset: 2), Rect.zero)` (RenderParagraph has no caret-rect API; getOffsetForCaret is the correct equivalent). VALUE CHANGE: `expect(topLeft.dx, equals(399.0))` → `equals(400.0)`.
- part_a_evidence: For 'abcd' centered in 800px, the true midpoint (offset 2) is x=400. The new value is geometrically exact. The old 399 came from RenderEditable being `_caretMargin` (3px, editable.dart:1279) wider than the text, which shifts the centered box left by 1.5px, plus RenderEditable's caret-rect adjustment and pixel snapping in `getLocalRectForCaret`. This is the same caret-margin effect as test 032. Original (textoffsetfix run) fails `Bad state: No element` in `findRenderEditable`.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: [G-LAYOUT-SIZE]
- gap_notes: G-LAYOUT-SIZE — the 399→400 change absorbs the removal of the caret margin from the laid-out width. The intent (text is centered) is preserved and even tightened, so severity is low. It is still a numeric expectation rewrite caused by a real geometry difference.
- confidence: MEDIUM (the exact decomposition of the old 1px — 1.5px margin shift vs caret-rect snapping — was not re-measured; the direction and cause are clear)

## Test 038 — Can align to center within center
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: MIXED
- part_a_details: Identical edit to 037: the RenderEditable→RenderParagraph and getLocalRectForCaret→getOffsetForCaret(…, Rect.zero) swaps are WARRANTED; `399.0 → 400.0` is a value change. The tree is `SizedBox(width: 300) > Center > SelectableText`, all centered on the 800px screen, so the exact midpoint of 'abcd' is again x=400.
- part_a_evidence: same as 037 (caret margin editable.dart:1279/2414; new RenderParagraph measurement has no margin). Original fails in `findRenderEditable`.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: [G-LAYOUT-SIZE]
- gap_notes: G-LAYOUT-SIZE — same as 037 (low severity; the intent is preserved).
- confidence: MEDIUM (same as 037)

## Test 039 — Tapping outside SelectableText clears the selection
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: (1) Two `TextEditingController`s → two `onSelectionChanged` captures (`selectionA`/`selectionB`). (2) Registration `pump()`. (3) First tap: `textOffsetToPosition(tester, 5)` → the same with `ancestor: find.text('first selectable text')` (equivalent; both pick the first text). (4) `expect(controllerB.selection, TextRange.empty)` → `expect(selectionB, null)`. This is slightly weaker in form (it checks that B never notified rather than B's selection value), but it is the natural equivalent when there is no controller. (5) Second tap location: `tester.getTopLeft(find.byType(SelectableText).last)` → `textOffsetToPosition(tester, 0, ancestor: second)`. This change was unnecessary: P39 (head body with the original getTopLeft tap) PASSES. (6) All value expectations preserved: A collapsed(5); then A empty and B collapsed(0); after lifecycle inactive, unchanged.
- part_a_evidence: The new implementation genuinely produces collapsed selections on tap: selectable_region.dart:950-956 (mobile tap-up → `hideToolbar(); _collapseSelectionAt(...)`, :1503). The notifier reports `TextSelection(start,end)` → collapsed(5), and clearing gives `collapsed(-1)`, which equals `TextRange.empty` under TextRange.== (start/end compare). Original (textoffsetfix run) fails `Bad state: No element` at `find.byType(EditableText).first`.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none (optional: revert the second-tap location to `getTopLeft`, verified by P39)
- gap_ids: []
- gap_notes: none asserted. Caveat: the collapsed(5)/(0) selections exist logically but no caret is painted (G-NO-CARET is not covered by this test either before or after).
- confidence: HIGH (P39 confirms the original tap location also passes)

## Group summary
- Verdict counts (Part A): WARRANTED 2 (027, 039); MIXED 5 (028 unnecessary weakening, no gap; 030 fake-fix entry path; 032/037/038 numeric rewrites absorbing caret-margin width); PARTIAL (still failing) 3 (029, 033, 034); FAKE FIX 0 (pure).
- Part B for still-failing tests: 029 GAP [G-HANDLE-CLAMP]; 033 MIXED (surface: pumpAndSettle makes it pass; gap: G-SCROLLING incremental edge-autoscroll vs immediate bringIntoView, plus selection overshoot); 034 SURFACE (use `ScrollConfiguration.of(scrollableElement)`; verified).
- Gaps masked by passing-test edits: 030 → G-NO-CARET (no caret handle after tap, so there is no "tap caret handle → toolbar" path) and G-TOOLBAR-PLATFORM (extra Share); 032/037/038 → G-LAYOUT-SIZE (3px RenderEditable caret margin removed → 1.5px centering shift).
- Unnecessary edits (the original form would pass): 028 in-callback `expect(newSelection, isNull)` (P28); 039 second-tap location (P39).
- Proposed new gap id: G-HANDLE-DRAG-AUTOSCROLL — dragging a selection handle past the scrollable edge scrolls through EdgeDraggingAutoScroller, which moves at most 20px per step and keeps scrolling while the handle is held. The selection extends past the dragged-to position (to 0 in test 033). EditableText instead jumps once to reveal the dragged caret position (`bringIntoView` → `jumpTo`).
