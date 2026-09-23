# Group H_longpressdrag_edgescroll_forcepress report

Shared evidence used below:
- Every original body (`failures_base_textoffsetfix_on_head/087..099`) fails first with `Bad state: No element` at the `find.byType(EditableText).first` line. That is a surface-only stale finder, so the swap to `onSelectionChanged` is warranted in every test.
- Probe file `zz_scratch_H_test.dart` had one run and has been deleted. It printed the selection, the toolbar button labels, the `ScrollableState.position.pixels` of every Scrollable, the handle `FadeTransition` opacities, and endpoints from both `SelectionOverlay` and `RenderParagraph.getBoxesForSelection`. Results are quoted as "probe".
- Apple toolbar: `expectCupertinoSelectionToolbar` (test_head:166-182) expects iOS = 4 buttons (Copy, Look Up, Search Web, Share...) and macOS = 1 button (Copy). SelectableRegion's `contextMenuButtonItems` (selectable_region.dart:1704, Select All added when `selectionGeometry.hasContent`, :306) gives "Copy, Select All" on both. The probe confirms this every time the toolbar shows. Material toolbar (android: Copy/Share/Select all; desktop: Copy/Select all) matches exactly, which is why the non-Apple variants pass.
- Old SelectableText used a readOnly EditableText. In `TextSelectionGestureDetectorBuilder` the readOnly branch uses word selection on ALL platforms, including iOS and macOS: `onSingleLongTapStart` → `selectWord` (text_selection.dart:2743-2747) and `onSingleLongTapMoveUpdate` → `selectWordsInRange` (text_selection.dart:2808-2818). The new `_handleTouchLongPressStart`/`MoveUpdate` also use word selection (`_selectWordAt`, `_selectEndTo(textGranularity: word)`, selectable_region.dart:1007-1025). So long-press-drag granularity is the SAME in old and new, including macOS.
- Old iOS touch tap uses `renderEditable.selectWordEdge(cause: tap)` (text_selection.dart:2696), which gives offset 12/7 with upstream affinity. The new iOS tap calls `_collapseSelectionAt` (selectable_region.dart:950-956), which gives the raw position (11/4, downstream). The new world DOES report a collapsed range on tap (e.g. `collapsed(offset: 11)`); it is not `-1`.
- No force-press recognizer exists in SelectableRegion (`grep ForcePress selectable_region.dart` → none; recognizers at :654-735). The old code set `forcePressEnabled = true` on iOS only (impl_base.dart:700) → `onForcePressStart` → `selectWordsInRange` (text_selection.dart:2534-2545).
- Edge scrolling: `_ScrollableSelectionContainerDelegate` (scrollable.dart:1171) auto-scrolls only Scrollables that are DESCENDANTS of the SelectionArea. SelectableText's own `SingleChildScrollView` is inside the SelectionArea and does edge-scroll (test 92 probe: overlay endpoints `-924.1, 800.0`). An ANCESTOR Scrollable (tests 90/91) never scrolls. Probe: all `ScrollableState.pixels` stay `0.0` after the drag, even with an extra 1 s pump. The old implementation tracked the ancestor scroll position in the gesture builder (`_dragStartScrollOffset`/`_scrollPosition`, text_selection.dart:2785-2806) and called `bringIntoView` on long-press on iOS/macOS (impl_base.dart:611-625). The extents still reach 134 only because the text is fully laid out at unbounded width inside the ancestor horizontal scroller, so an off-screen global position still maps to offset 134.

## Test 087 — long press drag extends the selection to the word under the drag and shows toolbar on lift on non-Apple platforms
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: `controller.selection` → `currentSelection` captured from `onSelectionChanged`. Added `const` removal and an extra `pump()` so the selectable can register. All five offset expectations (13-23, 13-35, 23-8, 23-0, 23-0), the `TextButton findsNothing` checks and `expectMaterialSelectionToolbar()` are unchanged.
- part_a_evidence: The base fails at `tester.widget(find.byType(EditableText).first)` (textoffsetfix 087_*: `Bad state: No element` at line 3639). New API: `SelectionListenerNotifier` → `_handleSelectionDetailsChanged` (impl.diff +151-214). Same word granularity old and new (text_selection.dart:2836 `selectWordsInRange` vs selectable_region.dart:1022 `TextGranularity.word`). The Material toolbar helper matches SelectableRegion's Android/desktop button sets.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a. Why 087 passes and 088 fails with the same edit: the selection mechanics are identical on all platforms and 088 passes every selection assertion. The only difference is the toolbar helper. `expectMaterialSelectionToolbar` matches SelectableRegion's buttons, while `expectCupertinoSelectionToolbar` wants the iOS 4-button readOnly EditableText menu.
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: none
- confidence: HIGH (the head passes; semantics verified in code).

## Test 088 — long press drag extends the selection to the word under the drag and shows toolbar on lift (iOS)
- status_at_head: FAILING (variants: iOS)
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: Identical warranted edit to 087 (finder → `onSelectionChanged`, extra pump). No expectation values changed. It still fails.
- part_a_evidence: The head failure is at line 4157, the final `expectCupertinoSelectionToolbar()`, with `Expected: exactly 4 matching candidates / Found 2 widgets with type "CupertinoButton"`. Every selection assertion before it passed.
- part_b_classification: GAP
- part_b_root_cause: iOS long-press-drag selection behaves exactly like the old one: word granularity, same offsets. The only failure is the toolbar content. SelectableRegion shows "Copy, Select All" (probe), while the old readOnly EditableText on iOS showed "Copy, Look Up, Search Web, Share...".
- part_b_surface_fix: none
- gap_ids: [G-TOOLBAR-PLATFORM]
- gap_notes: G-TOOLBAR-PLATFORM: `expect(find.byType(CupertinoButton), findsNWidgets(4))` (test_head:174). `SelectableRegionState.contextMenuButtonItems` (selectable_region.dart:1704ff) never adds Look Up / Search Web / Share and always adds Select All when there is content (:306).
- confidence: HIGH (the probe printed the actual buttons "Copy,Select All").

## Test 089 — long press drag moves the cursor under the drag and shows toolbar on lift (macOS)
- status_at_head: FAILING (variants: macOS)
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: Warranted finder swap plus a registration pump. The values (0-7, 0-8, 0-12, 0-12) and the toolbar checks are unchanged.
- part_a_evidence: The head fails only at line 4216 `expectCupertinoSelectionToolbar()` (`exactly one matching candidate … Found 2`). All selection assertions passed.
- part_b_classification: GAP
- part_b_root_cause: This is NOT a caret or long-press-drag gap. Despite the title ("moves the cursor"), the old SelectableText is readOnly, so macOS long-press used `selectWord`/`selectWordsInRange` (text_selection.dart:2743, 2808-2818), which is word granularity. The new implementation also selects by word (selectable_region.dart:1022), and the offsets match. The failure is purely the toolbar: macOS old = [Copy], new = [Copy, Select All].
- part_b_surface_fix: none
- gap_ids: [G-TOOLBAR-PLATFORM]
- gap_notes: G-TOOLBAR-PLATFORM: `expect(find.byType(CupertinoButton), findsNWidgets(1))` (test_head:180). SelectableRegion adds Select All whenever `hasContent` (selectable_region.dart:306).
- confidence: HIGH.

## Test 090 — long press drag can edge scroll when inside a scrollable
- status_at_head: FAILING (variants: iOS)
- change_status: MODIFIED
- part_a_verdict: MIXED
- part_a_details:
  - (a) Finder → `onSelectionChanged`, and `findRenderEditable`/`getEndpointsForSelection` → `getSelectionEndpoints()` (SelectableRegionState.selectionOverlay). WARRANTED: the same endpoint assertions are kept.
  - (b) An unused `ScrollController` was added. COSMETIC.
  - (c) `await tester.pump()` after the 1600px move was changed to `pump(const Duration(seconds: 1))`. UNNECESSARY but harmless: the probe shows `13-134` already after a plain `pump()`, and the extra second produced no scroll.
  - (d) Comments were removed. COSMETIC.
  - No expectation values changed. The variant stays iOS-only, as in base.
- part_a_evidence: Probe P90 iOS: `m3 (pump only) sel=13..134`, `m3 (+1s) … AxisDirection.right:0.0 AxisDirection.right:0.0`, then `up … Copy,Select All overlay 435.375,2159.5`.
- part_b_classification: GAP
- part_b_root_cause: The immediate failure is the toolbar (line 4279, 2 vs 4 Cupertino buttons). Behind it, `expect(endpoints[0].point.dx, isNegative)` would also fail. The probe shows the start endpoint at +435.4 because the ANCESTOR horizontal `SingleChildScrollView` never scrolls (pixels 0.0). The selection reaches 134 only because the text is fully laid out in the unbounded ancestor. The old implementation scrolled the ancestor: it tracked `_scrollPosition` in the gesture builder and called `bringIntoView` on longPress for iOS (impl_base.dart:611-625). The new SelectionArea auto-scroll exists only for Scrollables inside the SelectionArea (scrollable.dart:1171). Regression test for #129590 is therefore broken.
- part_b_surface_fix: none
- gap_ids: [G-TOOLBAR-PLATFORM, G-LONGPRESS-DRAG, G-ANCESTOR-SCROLLABLE-EDGE-SCROLL]
- gap_notes:
  - G-TOOLBAR-PLATFORM: at line 4279, as in 088.
  - G-ANCESTOR-SCROLLABLE-EDGE-SCROLL (a sub-case of G-LONGPRESS-DRAG): `expect(endpoints[0].point.dx, isNegative)`. The start endpoint is at 435.4 and the ancestor scroll pixels stay 0.0.
- confidence: HIGH (probe printed the endpoints and scroll offsets directly). A run of the head body with the toolbar line removed would make it explicit.

## Test 091 — Desktop mouse drag can edge scroll when inside a horizontal scrollable
- status_at_head: FAILING (variants: linux, macOS, windows)
- change_status: MODIFIED
- part_a_verdict: MIXED
- part_a_details: Most of the 102 diff lines are the dart-format reflow of `testWidgets('…', (tester) async {…}, variant:)`. Semantic changes:
  - (a) `kind: PointerDeviceKind.mouse` was added to `startGesture`. The base used the default touch pointer. This matches the title ("mouse drag"), but it hides a real difference: in the new world a TOUCH drag on desktop does not select. Probe with the base's touch kind: the selection stays `collapsed(14)` and never extends, because `_handleMouseDragStart`/`Update` return for non-precise devices (selectable_region.dart:815-818, 828-831). The old builder selected on touch drag on desktop, since the base passed with a touch pointer. Verdict: MIXED. It is justified by the title but masks G-DESKTOP-TOUCH-DRAG.
  - (b) Added `expect(currentSelection, isNotNull)` and `.isValid`. Additive, WARRANTED.
  - (c) Finder → `onSelectionChanged`. WARRANTED.
  - (d) `findRenderEditable`+`getEndpointsForSelection` → `getSelectionEndpoints()`. The intent is warranted, but the helper cannot work here, see Part B.
  - All offset expectations (14-21, 14-28, 14-134) are unchanged. The owner's TODO (test_head preamble "SelectionArea lacks horizontal edge scrolling when inside a horizontal scrollable") is correct.
- part_a_evidence: Base diff line `-      final TestGesture gesture = await tester.startGesture(selectableTextStart + const Offset(200.0, 0.0),);` → `+ kind: PointerDeviceKind.mouse`. Probe P91 touch on linux/macOS/windows: `m3 sel=TextSelection.collapsed(offset: 14…)`. Probe P91 mouse: `m3 sel=14..134`.
- part_b_classification: MIXED
- part_b_root_cause:
  - Immediate cause (SURFACE): `getSelectionEndpoints` asserts `state.selectionOverlay` is not null (test_head:212). A desktop mouse drag never creates the overlay: "The selection overlay is not shown on desktop platforms after a drag" (selectable_region.dart:926-929). Probe: `overlay=null`.
  - Underlying cause (GAP): after swapping in an overlay-free endpoint source (`RenderParagraph.getBoxesForSelection`), the probe gives `para start=449.625 end=2159.625`, so `expect(endpoints[0].point.dx, isNegative)` still fails. The ancestor `SingleChildScrollView` never scrolls (pixels 0.0 on both Scrollables). The selection offsets pass only because the text is fully laid out in the unbounded ancestor viewport.
- part_b_surface_fix: Replace `getSelectionEndpoints(tester)` with endpoints from the paragraph: `final p = tester.renderObject<RenderParagraph>(find.byType(RichText)); final boxes = p.getBoxesForSelection(currentSelection!);` and globalize the first box's left and the last box's right. This only moves the failure to the real gap assertion.
- gap_ids: [G-MOUSE-DRAG-EDGE-SCROLL, G-ANCESTOR-SCROLLABLE-EDGE-SCROLL, G-DESKTOP-TOUCH-DRAG]
- gap_notes:
  - G-ANCESTOR-SCROLLABLE-EDGE-SCROLL / G-MOUSE-DRAG-EDGE-SCROLL: `expect(endpoints[0].point.dx, isNegative)`. SelectionArea's edge auto-scroll (`_ScrollableSelectionContainerDelegate`, scrollable.dart:1171) covers only Scrollables below the SelectionArea. The ancestor Scrollable is untouched.
  - G-DESKTOP-TOUCH-DRAG: masked by the `kind: mouse` edit. Touch drag on linux/macOS/windows no longer extends the selection (selectable_region.dart:815-818).
- confidence: HIGH (probe ran all three desktop variants for both pointer kinds).

## Test 092 — long press drag can edge scroll
- status_at_head: FAILING (variants: android, iOS)
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: Finder → `onSelectionChanged` (WARRANTED). Added `isNotNull`/`isValid` checks (additive). Added a TODO comment above the handle-opacity asserts. All offsets (13-23/45/66/102/134), the toolbar checks and the `startHandleAfter.opacity == 0.0` / `end == 1.0` assertions are kept.
- part_a_evidence: Head failures: android at line 4443 `Expected: <0.0> Actual: <1.0>` (start handle opacity); iOS at line 4416 (Cupertino toolbar 2 vs 4).
- part_b_classification: GAP
- part_b_root_cause: Edge scrolling of SelectableText's OWN scroll view works. It is inside the SelectionArea, and the probe shows overlay endpoints `-924.1, 800.0` with all offsets matching. What fails:
  - (1) The off-screen start handle is not faded out. SelectableRegion builds `SelectionOverlay` without `startHandlesVisible`/`endHandlesVisible` (no match for `HandlesVisible` in selectable_region.dart; the parameter exists at text_selection.dart:1064/1260). The probe shows `opac=1.0,1.0` on BOTH android and iOS, so iOS would fail here too once past the toolbar.
  - (2) On iOS, the toolbar content.
- part_b_surface_fix: none
- gap_ids: [G-HANDLES-VISIBILITY, G-TOOLBAR-PLATFORM]
- gap_notes:
  - G-HANDLES-VISIBILITY: `expect(startHandleAfter.opacity.value, 0.0)`. Visibility notifiers are not wired, so the FadeTransition stays at 1.0.
  - G-TOOLBAR-PLATFORM: iOS `findsNWidgets(4)`.
- confidence: HIGH.

## Test 093 — long tap still selects after a double tap select (iOS)
- status_at_head: FAILING (variants: iOS)
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: Format reflow, finder swap, and two TODO comments. The explanatory comment "Because the "word" is a whitespace, the selection will shift to the previous word…" was replaced by a TODO. Expectations (`collapsed(12, upstream)`, `0..7`, the Cupertino toolbar) are unchanged. The edit is WARRANTED but the test still fails.
- part_a_evidence: The head fails at line 4479: `Expected collapsed(offset: 12, upstream) Actual collapsed(offset: 11, downstream)`.
- part_b_classification: GAP
- part_b_root_cause: The first tap on iOS used `selectWordEdge` in the old code (text_selection.dart:2696) and `_collapseSelectionAt` in the new (selectable_region.dart:950-956), so the new code gives the raw offset 11 with no upstream affinity. Behind that, the probe shows two more failures after the first:
  - Long press on the whitespace selects `7..8` (the space) instead of the old iOS `0..7`, the previous non-whitespace word.
  - The toolbar is "Copy,Select All" instead of 4 buttons.
- part_b_surface_fix: none
- gap_ids: [G-TAP-GESTURES, G-NO-AFFINITY, G-TOOLBAR-PLATFORM]
- gap_notes:
  - G-TAP-GESTURES: the line 4479 offset 12 vs 11 (no word-edge snapping), and `expect(currentSelection, TextSelection(0, 7))`, where the probe gives 7..8 (no whitespace→previous-word shift on iOS long press).
  - G-NO-AFFINITY: `affinity: upstream` cannot be produced. `_handleSelectionDetailsChanged` builds a downstream `TextSelection` (impl.diff +207-210).
  - G-TOOLBAR-PLATFORM: final toolbar check.
- confidence: HIGH (probe P93).

## Test 094 — long tap still selects after a double tap select (macOS)
- status_at_head: FAILING (variants: macOS)
- change_status: MODIFIED
- part_a_verdict: MIXED
- part_a_details:
  - (a) Finder swap. WARRANTED.
  - (b) `TextSelection.collapsed(offset: 11, affinity: TextAffinity.upstream)` → `TextSelection.collapsed(offset: 11)`. FAKE FIX: the affinity value was dropped to match the downstream-only report. This masks G-NO-AFFINITY. It is also inconsistent with 095/096, where the macOS upstream expectations were kept and those tests fail on them.
  - (c) `7..8` and the toolbar check are unchanged.
- part_a_evidence: Base `const TextSelection.collapsed(offset: 11, affinity: TextAffinity.upstream)` vs head `const TextSelection.collapsed(offset: 11)`. Test 095 macOS head failure: `Expected collapsed(11, upstream) Actual collapsed(11, downstream)`, which proves the dropped affinity would otherwise fail here too.
- part_b_classification: GAP
- part_b_root_cause: The selection now passes (tap-down collapse at 11 on macOS, selectable_region.dart:752-767; long press 7..8). The failure is at line 4533, toolbar 2 vs 1 Cupertino buttons ("Copy, Select All").
- part_b_surface_fix: none
- gap_ids: [G-TOOLBAR-PLATFORM, G-NO-AFFINITY]
- gap_notes:
  - G-TOOLBAR-PLATFORM: `findsNWidgets(1)` (test_head:180).
  - G-NO-AFFINITY: masked by the edit above.
- confidence: HIGH.

## Test 095 — double tap after a long tap is not affected
- status_at_head: FAILING (variants: iOS, macOS)
- change_status: MODIFIED
- part_a_verdict: MIXED
- part_a_details:
  - (a) Finder swap, and `EditableTextState.hideToolbar()` → `SelectableRegionState.hideToolbar()`. WARRANTED (selectable_region.dart public `hideToolbar`).
  - (b) The final unconditional `expectCupertinoSelectionToolbar()` became iOS-only, with macOS now asserting `expect(find.byType(CupertinoButton), findsNothing)` ("SelectableRegion is not wired up to show the toolbar on touch interaction"). FAKE FIX: it inverts an expectation to match new behavior and masks G-TOOLBAR-PLATFORM, since macOS touch double-tap no longer shows the toolbar: `_handleMouseTapUp` case 2 macOS → `break` (selectable_region.dart:983-989).
  - (c) TODO comment. COSMETIC.
- part_a_evidence: Probe P95 macOS `t2 sel=8..12 0 cup`; iOS `t2 … 2 cup Copy,Select All`. Head failures: iOS line 4573 `12 upstream vs 11 downstream`; macOS line 4573 `11 upstream vs 11 downstream`.
- part_b_classification: GAP
- part_b_root_cause: The first tap after the long press fails. iOS: no word-edge snap (11 vs 12) and no affinity. macOS: the offset matches but upstream affinity cannot be reported. The double-tap selection itself (8..12) is correct on both (probe). Behind that: the iOS toolbar would fail (2 vs 4), and on macOS the old toolbar expectation would fail. The latter is now masked by the (b) edit.
- part_b_surface_fix: none
- gap_ids: [G-TAP-GESTURES, G-NO-AFFINITY, G-TOOLBAR-PLATFORM]
- gap_notes:
  - G-TAP-GESTURES: iOS offset 12 vs 11 (text_selection.dart:2696 vs selectable_region.dart:956).
  - G-NO-AFFINITY: upstream on both platforms.
  - G-TOOLBAR-PLATFORM: iOS button set, plus the macOS touch double-tap showing no toolbar (masked).
- confidence: HIGH (probe P95).

## Test 096 — double tap chains work
- status_at_head: FAILING (variants: iOS, macOS)
- change_status: MODIFIED
- part_a_verdict: MIXED
- part_a_details: What the 158 lines contain: the dart-format reflow of the whole body (most lines), the finder swap, and `SelectableRegionState.hideToolbar()` (all WARRANTED). The six-tap chain steps and all selection offsets are preserved, including the iOS/macOS ternaries. The weakening:
  - (1) All three `expectCupertinoSelectionToolbar()` calls (after double-tap #1, #2 and #3) became `if iOS … else expect(find.byType(CupertinoButton), findsNothing)`. FAKE FIX: the macOS expectation is inverted three times (G-TOOLBAR-PLATFORM, macOS touch double-tap shows no toolbar, selectable_region.dart:983-989).
  - (2) The macOS third tap `TextSelection.collapsed(offset: 1, affinity: TextAffinity.upstream)` → `collapsed(offset: 1)`. FAKE FIX (G-NO-AFFINITY).
  - The first-tap and fifth-tap expectations kept `affinity: upstream` and the iOS 7/12 offsets, so the test still fails at its first assertion. The macOS toolbar and affinity weakenings are therefore currently hidden behind that failure.
- part_a_evidence: Probe P96 iOS sequence: `collapsed(4)` → `0..7 [Copy,Select All]` → `0..7 no toolbar` → `0..7 [Copy,Select All]` → `collapsed(11)` → `8..12 [Copy,Select All]`. macOS sequence: `collapsed(4)` → `0..7 (0 buttons)` → `collapsed(1)` → `0..7 (0)` → `collapsed(11)` → `8..12 (0)`. The base expected the macOS toolbar after each double-tap.
- part_b_classification: GAP
- part_b_root_cause: The head fails at line 4623, the first tap. iOS gives 4 vs 7 (no word-edge snap); macOS gives an affinity mismatch. The chain mechanics themselves (double-tap word select, tap-on-selection toggles the toolbar on iOS, macOS tap re-collapses then the double-tap reselects) all match the old values. The remaining differences are word-edge snapping, affinity, and toolbar content and presence.
- part_b_surface_fix: none
- gap_ids: [G-TAP-GESTURES, G-NO-AFFINITY, G-TOOLBAR-PLATFORM]
- gap_notes:
  - G-TAP-GESTURES: line 4623 iOS 7 vs 4, and later 12 vs 11.
  - G-NO-AFFINITY: upstream at lines 4623 and ~4680 (macOS), and masked at the third tap.
  - G-TOOLBAR-PLATFORM: iOS 2 vs 4 buttons, and macOS no toolbar on touch double-tap (masked by the inversion).
- confidence: HIGH (probe ran the full chain on both platforms).

## Test 097 — force press does not select a word on (android)
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: `expect(controller.selection, const TextSelection.collapsed(offset: -1))` → `expect(currentSelection == null || !currentSelection!.isValid, isTrue)`. In the old world, collapsed(-1) was the untouched-controller sentinel ("nothing selected"). The new wrapper either never fires or reports `collapsed(-1)` for no range (impl.diff +213), so the assertion has the same meaning. The toolbar check is unchanged.
- part_a_evidence: Probe P97 android: `after force sel=null`, `up sel=null 0 cup / 0 mat`. The base failed only on the EditableText finder (textoffsetfix 097.txt line 4258).
- part_b_classification: N/A (passing)
- part_b_root_cause: Vacuity question: the test now passes by construction. SelectableRegion has no force-press recognizer on any platform, so force press never selects anywhere. The probe shows iOS also gives `sel=null`; desktop gives only a tap-down `collapsed(11)`. This is not new vacuity, though. The old Android variant also had `forcePressEnabled = false` (impl_base.dart:713-736), so it was always a negative test. What was lost is the contrast with iOS, and 098 documents that by failing. The assertion is still meaningful as a guard against a future force-press implementation leaking to Android.
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: none (G-FORCE-PRESS is exposed by 098).
- confidence: HIGH.

## Test 098 — force press selects word
- status_at_head: FAILING (variants: iOS)
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: Format reflow plus the finder swap. The expectations (`8..12`, Cupertino toolbar) are unchanged. The edit is WARRANTED; the test still fails.
- part_a_evidence: The head fails at line 4790: `Expected TextSelection(8, 12) Actual <null>`.
- part_b_classification: GAP
- part_b_root_cause: The old iOS set `forcePressEnabled = true` (impl_base.dart:700), so `TextSelectionGestureDetector` added a ForcePressGestureRecognizer that went to `onForcePressStart` → `selectWordsInRange` + `showToolbar` (text_selection.dart:2534-2545). SelectableRegion registers only TapAndPan, TapAndHorizontalDrag and LongPress recognizers (selectable_region.dart:654-735), with no force press. Behind it, the toolbar would also fail (2 vs 4 buttons).
- part_b_surface_fix: none
- gap_ids: [G-FORCE-PRESS, G-TOOLBAR-PLATFORM]
- gap_notes:
  - G-FORCE-PRESS: `expect(currentSelection, TextSelection(baseOffset: 8, extentOffset: 12))` gets null.
  - G-TOOLBAR-PLATFORM: latent, after that.
- confidence: HIGH.

## Test 099 — tap on non-force-press-supported devices work
- status_at_head: FAILING (variants: iOS)
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: 102 lines, but they are almost entirely the dart-format reflow. Semantically: the finder swap (WARRANTED) plus a TODO. `collapsed(12, upstream)`, the pump, and `CupertinoButton findsNothing` are all unchanged, and the variant stays iOS-only. No weakening. It still fails.
- part_a_evidence: The head fails at line 4843: `Expected collapsed(12, upstream) Actual collapsed(11, downstream)`.
- part_b_classification: GAP
- part_b_root_cause: The force-press fallback itself works. A zero-pressure device falls back to a normal tap, and SelectableRegion produces a collapsed selection. The failure is the iOS tap semantics: the old `selectWordEdge` (text_selection.dart:2696) gave 12/upstream, while the new `_collapseSelectionAt` (selectable_region.dart:956) gives 11/downstream. The following `findsNothing` toolbar check would pass (the probe shows 0 buttons after a single tap).
- part_b_surface_fix: none
- gap_ids: [G-TAP-GESTURES, G-NO-AFFINITY]
- gap_notes:
  - G-TAP-GESTURES: no iOS word-edge snapping on tap (12 vs 11).
  - G-NO-AFFINITY: upstream affinity is not representable.
- confidence: HIGH.

## Group summary
- Part A verdicts:
  - WARRANTED (passing): 2 (087, 097).
  - PARTIAL, with a warranted edit and still failing: 6 (088, 089, 092, 093, 098, 099).
  - MIXED: 5.
    - 090: warranted, plus an unnecessary `pump(1s)`.
    - 091: `kind: mouse` masks the touch-drag difference.
    - 094: affinity dropped.
    - 095: macOS toolbar expectation inverted.
    - 096: macOS toolbar expectation inverted 3 times, and affinity dropped once.
  - FAKE FIX pieces are in 094, 095, 096 and 091(a). All of them except 094 are currently hidden behind still-failing earlier assertions.
- Part B (11 failing):
  - GAP: 10 (088, 089, 090, 092, 093, 094, 095, 096, 098, 099).
  - MIXED: 1 (091). The overlay-null helper failure is surface, and the real gap is behind it.
- Key findings:
  - Long-press-drag granularity is identical old and new on every platform, including iOS and macOS, because old SelectableText was readOnly. 088 and 089 fail only on the Apple toolbar content, not on selection.
  - Edge scrolling works for SelectableText's own scroll view (092), but does not scroll an ANCESTOR Scrollable (090, 091). The probe shows pixels stuck at 0.0, and the endpoint assertions would fail even after the toolbar and helper issues are fixed.
- Gap counts: G-TOOLBAR-PLATFORM 9, G-NO-AFFINITY 5, G-TAP-GESTURES 4, G-ANCESTOR-SCROLLABLE-EDGE-SCROLL 2, G-LONGPRESS-DRAG 1, G-MOUSE-DRAG-EDGE-SCROLL 1, G-HANDLES-VISIBILITY 1, G-FORCE-PRESS 1, G-DESKTOP-TOUCH-DRAG 1.
- NEW gap ids:
  - G-ANCESTOR-SCROLLABLE-EDGE-SCROLL: a long-press or mouse selection drag inside SelectableText does not auto-scroll an ancestor Scrollable. SelectionArea's `_ScrollableSelectionContainerDelegate` (scrollable.dart:1171) only drives Scrollables below the SelectionArea. The old builder tracked the ancestor scroll position and used `bringIntoView`/`showOnScreen`. This refines G-LONGPRESS-DRAG and G-MOUSE-DRAG-EDGE-SCROLL: the INTERNAL scroll view does edge-scroll.
  - G-DESKTOP-TOUCH-DRAG: a touch (non-precise) drag on linux/macOS/windows no longer extends the selection. `_handleMouseDragStart`/`Update` return early for non-precise devices (selectable_region.dart:815-818, 828-831), whereas the old `TextSelectionGestureDetectorBuilder` drag-selected with touch on desktop.
