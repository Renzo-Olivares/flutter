# Group I_strut_caret_handles report

Shared evidence used below:
- E1 (caret margin): packages/flutter/lib/src/rendering/editable.dart:25 `const double _kCaretGap = 1.0;`, :1279 `double get _caretMargin => _kCaretGap + cursorWidth;`, :2279 `availableMaxWidth = math.max(0.0, maxWidth - _caretMargin)`, :2414 `size width = constraints.constrainWidth(_textPainter.width + _caretMargin)`. SelectableText default `cursorWidth = 2.0` ($S/impl_base.dart:182,241) => old width = text width + 3.0.
- E2 (height viewport): $S/impl.diff, new `ConstrainedBox(minHeight: lineHeight * (minLines ?? maxLines), maxHeight: lineHeight * maxLines)` "mirror RenderEditable._preferredHeight" (cf. editable.dart:2416-2423 clamp(textHeight, plh*(minLines??maxLines), plh*maxLines)). New impl drops cursorWidth/cursorHeight entirely (never forwarded to Text).
- E3 (stale owner comment): test_head.dart preamble before the strut tests says they "fail ... 'something' with maxLines: 6 now renders with a height of 1 line (14.0) instead of 6 lines (84.0) ... kept unskipped and failing". This is false at head: all 7 pass, heights are identical to base (84, 150, 24, 54 ...), and only widths were edited (-3.0). The comment predates the ConstrainedBox viewport.
- E4 (SelectableRegion gating): packages/flutter/lib/src/widgets/selectable_region.dart:1007-1017 `_handleTouchLongPressStart` shows handles on start except Android; :1027-1035 `_handleTouchLongPressEnd` shows handles (Android) + toolbar; :960-986 `_handleMouseTapUp` case 2: Android/Fuchsia `if (!isPointerPrecise) { _showHandles(); _showToolbar(); }`, iOS toolbar only, desktop nothing; case 1 on Android collapses/hides toolbar. SelectionOverlay has no public `handlesAreVisible` (only TextSelectionOverlay, widgets/text_selection.dart:583); SelectionOverlay exposes `toolbarIsVisible` (:1130). So `_SelectionHandleOverlay` widget presence is the only public handle-visibility signal for SelectableRegion.
- E5 (scratch probe, zz_scratch_I_test.dart, 1 run, deleted): real long press on 'lorem ipsum' at offset 2, all platforms. During hold (600ms, before up): Android overlay=null / 0 handle widgets; iOS/macOS/fuchsia/linux/windows 2 handles opacity [1.0,1.0], toolbar not visible. After release: all platforms 2 handles opacity [1.0,1.0], toolbarIsVisible=true, selection 0..5. Global FadeTransition count after release: Android 7, iOS 6, macOS 5 (old 112 asserted exactly 2 globally). Touch double tap 'abc def ghi' at offset 5 (Android): after a single pump() handle widgets=2 but opacity [0.0,0.0] (fade-in), toolbarIsVisible=true, selection 4..7; after settle opacity [1.0,1.0]. Mouse tap (Android): overlay=null, 0 handles, 0 toolbar widgets, onSelectionChanged collapsed(5). Mouse long press 2s: overlay=null, no handles/toolbar, no selection change. Mouse double tap at widget center: selection 8..11 ('ghi'), overlay=null, no handles/toolbar.
- E6 (orig body on new impl): $S/failures_base_textoffsetfix_on_head/{102..108}.txt fail only on width: e.g. 102 `Expected: Size(129.0, 14.0) Actual: Size(126.0, 14.0)`, 104 `Expected: Size(129.0, 84.0) Actual: Size(126.0, 84.0)`, 108 `Expected: Size(93.0, 54.0) Actual: Size(90.0, 54.0)`. 109-117 all fail on `Bad state: No element` at `findRenderEditable` / `tester.state<EditableTextState>(find.byType(EditableText))` — i.e. the originals never reached their assertions.

## Test 102 — strut basic single line
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: FAKE FIX
- part_a_details: Only change: expected `Size(129.0, 14.0)` -> `Size(126.0, 14.0)`. Height unchanged (single line, no viewport). Width reduced by exactly 3.0 = old RenderEditable caret margin (_kCaretGap 1.0 + cursorWidth 2.0). The new number is the correct *new* behavior and the difference is arguably desirable (no caret), so this is low-severity, but it is still an expectation-value edit that silently absorbs a user-visible layout change: SelectableText is now 3px narrower in intrinsic layout, and `cursorWidth` no longer affects size at all. The test no longer documents that difference and the owner's preamble (E3) wrongly says these tests are kept failing.
- part_a_evidence: $S/pertest/102.diff; E1; E6 (orig fails only with Actual 126.0 x 14.0).
- part_b_classification: N/A (passing)
- part_b_root_cause: N/A (passing)
- part_b_surface_fix: none
- gap_ids: [G-LAYOUT-SIZE]
- gap_notes: G-LAYOUT-SIZE: `expect(getSize(SelectableText), Size(129,14))` exposed that RenderParagraph width = text width, whereas RenderEditable width = text width + _caretMargin (editable.dart:2414, :1279). Consequence of G-NO-CARET; cursorWidth is a layout no-op now.
- confidence: HIGH (arithmetic is exact: 9 glyphs x 14 = 126, +3 = 129).

## Test 103 — strut TextStyle increases height
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: FAKE FIX
- part_a_details: Two expectations `Size(183.0, 20.0)` -> `Size(180.0, 20.0)` (with and without strut). Heights (20.0, the actual subject of the test) preserved; width -3.0 caret margin as in 102. Same low-severity masking of the width change.
- part_a_evidence: $S/pertest/103.diff; E1; $S/failures_base_textoffsetfix_on_head/103.txt (Expected 183.0 x 20.0, Actual 180.0 x 20.0).
- part_b_classification: N/A (passing)
- part_b_root_cause: N/A (passing)
- part_b_surface_fix: none
- gap_ids: [G-LAYOUT-SIZE]
- gap_notes: G-LAYOUT-SIZE: width assertion, 3px caret margin no longer reserved (see 102). Strut height behavior itself is equivalent.
- confidence: HIGH

## Test 104 — strut basic multi line
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: FAKE FIX
- part_a_details: `Size(129.0, 84.0)` -> `Size(126.0, 84.0)`. Height 84 (= 6 x 14, maxLines reserved) is preserved by the new ConstrainedBox viewport (E2) — i.e. the maxLines-reserved-height gap that the owner's comment (E3) describes is actually closed at head. Only the width (-3 caret margin) was edited.
- part_a_evidence: $S/pertest/104.diff; E2; E6.
- part_b_classification: N/A (passing)
- part_b_root_cause: N/A (passing)
- part_b_surface_fix: none
- gap_ids: [G-LAYOUT-SIZE]
- gap_notes: G-LAYOUT-SIZE: width only (caret margin). Height parity achieved via ConstrainedBox(minHeight = lineHeight*(minLines??maxLines)).
- confidence: HIGH

## Test 105 — strut no force small strut
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: FAKE FIX
- part_a_details: `Size(129.0, 84.0)` -> `Size(126.0, 84.0)`. Height preserved (strut smaller than style, not forced => style line height x 6 via viewport). Width -3 caret margin.
- part_a_evidence: $S/pertest/105.diff; E1, E2; failures_base_textoffsetfix_on_head/105.txt.
- part_b_classification: N/A (passing)
- part_b_root_cause: N/A (passing)
- part_b_surface_fix: none
- gap_ids: [G-LAYOUT-SIZE]
- gap_notes: G-LAYOUT-SIZE: width only (see 102).
- confidence: HIGH

## Test 106 — strut no force large strut
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: FAKE FIX
- part_a_details: `Size(129.0, 150.0)` -> `Size(126.0, 150.0)`. Height 150 preserved: the viewport's TextPainter(' ') is built with `strutStyle: widget.strutStyle`, so preferredLineHeight honors the larger strut exactly as RenderEditable did. Width -3 caret margin.
- part_a_evidence: $S/pertest/106.diff; E2 (painter built with strutStyle); failures_base_textoffsetfix_on_head/106.txt.
- part_b_classification: N/A (passing)
- part_b_root_cause: N/A (passing)
- part_b_surface_fix: none
- gap_ids: [G-LAYOUT-SIZE]
- gap_notes: G-LAYOUT-SIZE: width only.
- confidence: HIGH

## Test 107 — strut height override
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: FAKE FIX
- part_a_details: `Size(129.0, 24.0)` -> `Size(126.0, 24.0)`. Height preserved (forced small strut x maxLines). Width -3 caret margin.
- part_a_evidence: $S/pertest/107.diff; failures_base_textoffsetfix_on_head/107.txt.
- part_b_classification: N/A (passing)
- part_b_root_cause: N/A (passing)
- part_b_surface_fix: none
- gap_ids: [G-LAYOUT-SIZE]
- gap_notes: G-LAYOUT-SIZE: width only.
- confidence: HIGH

## Test 108 — strut forces field taller
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: FAKE FIX
- part_a_details: `Size(93.0, 54.0)` -> `Size(90.0, 54.0)` (9 glyphs x 10px = 90, +3 = 93). Height 54 (3 x 18 forced strut) preserved. Width -3 caret margin.
- part_a_evidence: $S/pertest/108.diff; failures_base_textoffsetfix_on_head/108.txt (Expected 93.0 x 54.0, Actual 90.0 x 54.0).
- part_b_classification: N/A (passing)
- part_b_root_cause: N/A (passing)
- part_b_surface_fix: none
- gap_ids: [G-LAYOUT-SIZE]
- gap_notes: G-LAYOUT-SIZE: width only.
- confidence: HIGH

## Test 109 — Caret center position
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: MIXED
- part_a_details: (a) WARRANTED piece: `findRenderEditable(tester)` -> RenderParagraph found under SelectableText via RichText; this is the only render object left. (b) FAKE FIX piece: the geometric claim changed. Old: `editable.getLocalRectForCaret(pos).topLeft` = the rect of the caret SelectableText would actually paint (caret prototype + cursorOffset, clamped to scrollableWidth - _caretMargin, pixel-snapped; editable.dart:1817-1862). New: `paragraph.getOffsetForCaret(pos, Rect.zero)` = raw TextPainter glyph-boundary offset; no caret is painted by the new widget (G-NO-CARET), so the test now asserts plain TextPainter/RenderParagraph center-alignment math, not SelectableText caret placement. (c) FAKE FIX piece: all four expected values shifted +1 (427/413/399/385 -> 428/414/400/386). Cause: old RenderEditable in a tight 300px SizedBox laid text out at 300 - _caretMargin = 297 (editable.dart:2279-2282), so centered text started at 250 + (297-56)/2 = 370.5 -> offset1 384.5, snapped to 385 at DPR 1.0 (overlay() MediaQueryData default); new paragraph uses full 300 -> 372 -> 386. So centered (and right-aligned) text is rendered 1.5px to the right of where it used to be — a real, if tiny, visual layout shift absorbed by editing the numbers.
- part_a_evidence: $S/pertest/109.diff; editable.dart:1817-1862, :2275-2285, :2341-2350; failures_base_textoffsetfix_on_head/109.txt (`Bad state: No element` at findRenderEditable — original never reached assertions).
- part_b_classification: N/A (passing)
- part_b_root_cause: N/A (passing)
- part_b_surface_fix: none
- gap_ids: [G-NO-CARET, G-LAYOUT-SIZE]
- gap_notes: G-NO-CARET: `getLocalRectForCaret` has no equivalent because nothing paints a caret; the rewrite substitutes a TextPainter offset, which cannot regress on SelectableText caret logic. G-LAYOUT-SIZE: expected dx values each +1 because the caret margin no longer narrows the text layout width inside a fixed-width parent, shifting center-aligned glyphs by 1.5px.
- confidence: HIGH on the shift mechanism (numbers reproduce exactly); MEDIUM on intent reading (would rise if the original PR for this test confirmed it targeted painted-caret position).

## Test 110 — Caret indexes into trailing whitespace center align
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: MIXED
- part_a_details: Same pattern as 109 for 'abcd    ' with offsets 7,8,4,3,2,1: all six expectations +1 (469/483/427/413/399/385 -> 470/484/428/414/400/386). WARRANTED: RenderEditable -> RenderParagraph lookup. FAKE FIX: (i) values changed to absorb the 1.5px centered-text shift (caret margin removed); (ii) the test's point — that the painted caret can index into trailing whitespace and is clamped by RenderEditable (scrollableWidth - _caretMargin clamp at editable.dart:1822-1828) — is no longer exercised; RenderParagraph.getOffsetForCaret has no clamping and no caret is drawn. It now asserts only that TextPainter reports offsets inside trailing whitespace under center alignment.
- part_a_evidence: $S/pertest/110.diff; editable.dart:1822-1828; failures_base_textoffsetfix_on_head/110.txt (`Bad state: No element` at findRenderEditable).
- part_b_classification: N/A (passing)
- part_b_root_cause: N/A (passing)
- part_b_surface_fix: none
- gap_ids: [G-NO-CARET, G-LAYOUT-SIZE]
- gap_notes: G-NO-CARET: caret rect/clamp semantics gone; assertion now covers TextPainter, not SelectableText. G-LAYOUT-SIZE: +1 dx on every expectation from the removed 3px caret margin.
- confidence: HIGH

## Test 111 — selection handles are rendered and not faded away
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: Default (Android) non-variant copy. Removed `EditableTextState`/`renderEditable.selectWord(cause: longPress)` after `tapAt(20,10)` and replaced with a real `tester.longPressAt(textOffsetToPosition(tester, 2))` + extra `pump()` for selectable registration. Assertions (exactly 2 FadeTransitions under `_SelectionHandleOverlay`, both opacity 1.0) are byte-identical. A real long press is a stronger stimulus than the old programmatic selectWord. It does NOT mask the Android long-press hold gap: `longPressAt` releases before pumpAndSettle, and the old test never tested the hold phase either (it injected the selection programmatically). Probe E5 confirms Android: 2 handles, opacity [1.0,1.0], selection 0..5 after release.
- part_a_evidence: $S/pertest/111.diff; E4 (:1027-1035 Android shows handles on LongPressEnd); E5. Note: the packet's "orig+overlay-fix PASSING" for 111 is an artifact of the duplicate test name — the non-variant failure `failures_base_textoffsetfix_on_head/112.txt` (no variant suffix) is actually 111's original body failing with `Bad state: No element` on `find.byType(EditableText)`.
- part_b_classification: N/A (passing)
- part_b_root_cause: N/A (passing)
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: (Related but not masked here: G-HANDLES-VISIBILITY — Android shows no handles during an active long-press hold, E5 "hold" probe: overlay=null, 0 handle widgets; old SelectableText showed them via _shouldShowSelectionHandles(longPress). That gap is exposed by the separate "Slight movements in longpress don't hide/show handles" test, which is where the owner's Android->iOS comment actually sits — test_head.dart:699-707, not this test.)
- confidence: HIGH

## Test 112 — selection handles are rendered and not faded away
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: This is the iOS/macOS variant copy. The `TargetPlatformVariant({iOS, macOS})` was ALREADY present at base (test_base.dart:4688-4719); the per-test diff looks like a platform switch only because the extractor mapped both same-named tests to base lines 4661-4687. No platform variant was added/dropped. Real changes: (1) programmatic `renderEditable.selectWord(longPress)` -> real `longPressAt` (+pump) — warranted/stronger; (2) finder narrowed from global `find.byType(FadeTransition)` (asserted exactly 2 in the whole tree) to FadeTransitions under `_SelectionHandleOverlay`. The narrowing is necessary, not weakening: the real long press now also shows the toolbar (old programmatic selectWord did not), and probe E5 shows 6 (iOS) / 5 (macOS) global FadeTransitions after release, 2 of which are the handles at opacity 1.0. Handle-count and opacity==1.0 assertions are retained.
- part_a_evidence: test_base.dart:4688-4719 (variant at base); $S/pertest/112.diff; E5; failures_base_textoffsetfix_on_head/112_TargetPlatform.{iOS,macOS}.txt (`Bad state: No element`).
- part_b_classification: N/A (passing)
- part_b_root_cause: N/A (passing)
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: No gap masked. Answer to the brief's question: not a platform switch masking G-HANDLES-VISIBILITY.
- confidence: HIGH

## Test 113 — Long press shows handles and toolbar
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: `editableText.selectionOverlay!.handlesAreVisible isTrue` -> `_SelectionHandleOverlay findsNWidgets(2)`; `toolbarIsVisible isTrue` -> `find.byType(AdaptiveTextSelectionToolbar) findsOneWidget`; + `pump()` for registration. SelectionOverlay has no public handlesAreVisible (E4), and handle widget presence is what TextSelectionOverlay.handlesAreVisible tests (`_handles != null`), so this is the public equivalent. Toolbar check is equivalent (probe: toolbarIsVisible=true). Slightly less direct than `tester.state<SelectableRegionState>(...).selectionOverlay!.toolbarIsVisible`, but not weaker in substance. Long press on Android shows both at LongPressEnd (E4 :1027-1035), same as old end state.
- part_a_evidence: $S/pertest/113.diff; E4; E5 (Android released: 2 handles, toolbarIsVisible=true).
- part_b_classification: N/A (passing)
- part_b_root_cause: N/A (passing)
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: none
- confidence: HIGH

## Test 114 — Double tap shows handles and toolbar
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: Same assertion translation as 113, plus final `pump()` -> `pumpAndSettle()`. Probe E5 shows the settle is unnecessary for what is asserted: after the old single `pump()` the new impl already has 2 handle widgets and toolbarIsVisible=true (handles at opacity 0.0 mid-fade — the old test also didn't check opacity, and old EditableText handles fade in too). Selection 4..7 ('def') as before. So the timing relaxation hides nothing; the double-tap-shows-overlay behavior is equivalent on Android (E4 :960-968).
- part_a_evidence: $S/pertest/114.diff; E4; E5 ("dbl-1pump android ... handleWidgets=2 opacities=[0.0,0.0] toolbarVisible=true").
- part_b_classification: N/A (passing)
- part_b_root_cause: N/A (passing)
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: none (off-scope observation: touch double tap on linux/macOS/windows shows no handles/toolbar in SelectableRegion; this test is Android-only so it's not masked here).
- confidence: HIGH

## Test 115 — Mouse tap does not show handles nor toolbar
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: `selectionOverlay!.toolbarIsVisible isFalse` / `handlesAreVisible isFalse` -> `_SelectionHandleOverlay findsNothing` and no widget whose type name contains 'TextSelectionToolbar' (covers Adaptive/Material/Cupertino/Desktop toolbars); `pump()` -> `pumpAndSettle()` (makes the negative check stronger — delayed shows would be caught). The only thing lost is the implicit `selectionOverlay!` non-null (old EditableText created an overlay because a mouse tap placed a collapsed caret); that is not a user-visible property and ties to G-NO-CARET, not this test's intent. Non-vacuity: probe shows the tap does reach the widget (onSelectionChanged collapsed(5)), overlay null, no handles/toolbar.
- part_a_evidence: $S/pertest/115.diff; E4 (:948-957 case 1 Android collapses + hideToolbar); E5 mouse-tap.
- part_b_classification: N/A (passing)
- part_b_root_cause: N/A (passing)
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: none
- confidence: HIGH

## Test 116 — Mouse long press does not show handles nor toolbar
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: Same translation as 115 (+pump, pumpAndSettle, string-predicate toolbar finder). Behavior matches: mouse long press shows neither (touch-only long-press recognizer in SelectableRegion, selectable_region.dart:~733). Caveat: the new assertion is a pure negative and the test does not verify the gesture had any effect; probe shows no selection change at all on mouse long press, so it passes partly because nothing happens. Old test had the same shape (only checked visibility flags), so no weakening.
- part_a_evidence: $S/pertest/116.diff; E5 mouse-long (overlay=null, sel unchanged).
- part_b_classification: N/A (passing)
- part_b_root_cause: N/A (passing)
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: none (any mouse-long-press selection difference is G-TAP-GESTURES territory and not asserted by this test before or after).
- confidence: MEDIUM (would rise by comparing old mouse-long-press selection result, which the test never asserted).

## Test 117 — Mouse double tap does not show handles nor toolbar
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: Same translation as 115. Non-vacuous: probe shows the mouse double tap selects the word at the widget center (8..11, 'ghi') while overlay stays null and no handles/toolbar appear — matches E4 :960-968 (`if (!isPointerPrecise)` gate on Android). pumpAndSettle strengthens the negative.
- part_a_evidence: $S/pertest/117.diff; E4; E5 mouse-dbl.
- part_b_classification: N/A (passing)
- part_b_root_cause: N/A (passing)
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: none
- confidence: HIGH

## Group summary
- WARRANTED: 7 (111, 112, 113, 114, 115, 116, 117)
- FAKE FIX: 7 (102-108) — all low severity: single width literal -3.0 per assertion (RenderEditable caret margin = _kCaretGap 1.0 + cursorWidth 2.0); every height is unchanged and genuinely matches via the new ConstrainedBox viewport.
- MIXED: 2 (109, 110) — RenderEditable->RenderParagraph swap is warranted, but values were shifted +1 to absorb the caret-margin layout shift of centered text, and the assertion was downgraded from "painted caret rect (clamped, snapped)" to "TextPainter glyph offset" (G-NO-CARET).
- Owner-comment accuracy: the strut preamble comment (test_head.dart, before "strut basic single line") is stale — it claims maxLines height is not reserved and the tests are kept failing; at head heights match and the tests pass with edited widths. The Android-long-press-END/iOS comment (test_head.dart:699-707) belongs to "Slight movements in longpress don't hide/show handles", not to 111/112; 112's iOS/macOS variant pre-exists at base.
- New gap ids: none. G-LAYOUT-SIZE here specifically = "no caret margin: widget is cursorWidth+1 px narrower, cursorWidth no longer affects layout, and aligned text inside a fixed-width parent shifts by (cursorWidth+1)/2 px".
