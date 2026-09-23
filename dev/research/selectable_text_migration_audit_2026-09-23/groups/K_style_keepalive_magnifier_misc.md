# Group K_style_keepalive_magnifier_misc report

Line refs: lib paths are relative to `packages/flutter/lib/src/`; `$S` = scratchpad. Scratch verification file `zz_scratch_K_test.dart` was run once and then deleted.

## Test 129 — text selection style 1
- status_at_head: FAILING
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: (1) `controller.selection = TextSelection(0, 46)` became `SelectableRegionState.selectAll()`, so the test reads selection through a different API. The text is 'Atwater Peel ' (13) + 'Sherbrooke Bonaventure ' (23) + 'hi wassup!' (10) = 46 characters, so select-all is the same selection. `selectAll()` with no cause shows no handles or toolbar (selectable_region.dart:1850-1860). The old code set a selection without focus, which showed no overlay either, so the golden content is equivalent. WARRANTED. (2) An extra `pump()` lets the selectables register. WARRANTED. The golden file name and expectation are unchanged. The test still fails.
- part_a_evidence: Diff lines `-controller.selection = const TextSelection(baseOffset: 0, extentOffset: 46);` and `+state.selectAll(); await tester.pumpAndSettle();`. The original body plus the Overlay fix failed on `find.byType(EditableText)` (No element) before reaching the golden ($S/failures_base_textoffsetfix_on_head/129.txt).
- part_b_classification: GAP
- part_b_root_cause: The immediate failure is a golden mismatch: "Pixel test failed, 1.31%, 56785px" ($S/failures/129.txt). Two causes sit behind it. (a) `selectionHeightStyle`/`selectionWidthStyle` have no path to painting. impl_head.dart does not pass them anywhere. `Text`/`RichText` have no such parameter. `_SelectableFragment.paintSelection` (rendering/paragraph.dart:3601-3616) calls `paragraph.getBoxesForSelection(selection)` with the defaults (`tight`/`tight`). `RenderParagraph.getBoxesForSelection` does accept `boxHeightStyle`/`boxWidthStyle` (paragraph.dart:1106-1118), but no property feeds them from the widget layer. That makes this an API gap, not a missing plumb-through. The old path was EditableText → RenderEditable `_selectionPainter.selectionHeightStyle` (editable.dart:388-389, 601-611). Even with no argument set, old SelectableText defaulted to `includeLineSpacingMiddle` (editable_text.dart:2085-2090), while the new one always paints `tight`. So every SelectableText highlight looks different, not only when these parameters are set. The failure images confirm this ($HOME/flutter/bin/cache/pkg/skia_goldens/packages/flutter/test/material/failures/...TextSelectionStyle.1_{master,test}Image.png): the master fills the full line height behind the 15px and 10px runs, and the test image has tight per-run boxes. (b) There is also a layout difference. The old code passed `strutStyle: widget.strutStyle ?? const StrutStyle()` and the new one passes `widget.strutStyle` (null). In the master image the wrapped second line ('hi wassup!', 10px) is taller and its glyphs sit about 3 logical px lower.
- part_b_surface_fix: none. (b) could be removed by restoring the `const StrutStyle()` default in SelectableText, but that is a lib change and (a) would still fail.
- gap_ids: [G-SELECTION-STYLE, G-LAYOUT-SIZE]
- gap_notes: G-SELECTION-STYLE: the golden assertion `matchesGoldenFile('selectable_text_golden.TextSelectionStyle.1.png')` exposes it. There is no BoxHeightStyle/BoxWidthStyle API in the Text/RenderParagraph selection-paint path (paragraph.dart:3613), so the SelectableText parameters are silently ignored, and the default highlight changed from includeLineSpacingMiddle to tight. A fix needs new API, e.g. selection box styles on DefaultSelectionStyle/RenderParagraph (the direction of PR #186802). G-LAYOUT-SIZE: the dropped default `StrutStyle()` changes line metrics for mixed font sizes, visible as the second-line offset in the same golden.
- confidence: HIGH for (a), from code plus images. MEDIUM for (b). Re-rendering with `strutStyle: StrutStyle()` would isolate how much of the pixel diff each cause accounts for.

## Test 130 — text selection style 2
- status_at_head: FAILING
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: Same edit as 129: selection (0,46) → `selectAll()`, plus a pump. WARRANTED, but the test still fails.
- part_a_evidence: Identical diff hunk to 129 ($S/pertest/130.diff). The original body failed on the EditableText finder.
- part_b_classification: GAP
- part_b_root_cause: Same as 129. `selectionHeightStyle: includeLineSpacingBottom` is never used, and RenderParagraph paints `tight` boxes (paragraph.dart:3613). Supporting evidence: the master images for style 1 and style 2 are byte-identical (md5 4584bbae…), and so are the head test images (md5 277f7b7f…), with the same 56785px diff. With no TextStyle.height, includeLineSpacingTop and includeLineSpacingBottom resolve to the same boxes and `max` width has no visible effect, so both goldens show the "line-height highlight" and head shows tight highlights for both. The dropped default StrutStyle also contributes (see 129).
- part_b_surface_fix: none
- gap_ids: [G-SELECTION-STYLE, G-LAYOUT-SIZE]
- gap_notes: Same as 129. The exposing assertion is `matchesGoldenFile('selectable_text_golden.TextSelectionStyle.2.png')`.
- confidence: HIGH

## Test 131 — keeps alive when has focus
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: (1) `onSelectionChanged` now captures `selection`, replacing `editableText.controller.selection`. WARRANTED. (2) `expect(controller.selection.isValid, isFalse)` became `expect(selection, isNull)`: no callback has fired, which is the equivalent "no selection" check. WARRANTED. (3) After the double tap, the expectations are the same: valid, base 0, extent 'Selectable'.length. WARRANTED. (4) The tap position is computed once with `ancestor: find.byType(SelectableText)`, plus a registration `pump()`. WARRANTED. (5) The key keep-alive assertions are untouched: after switching back to tab 1, `find.byType(SelectableText, skipOffstage: false)` is `findsOneWidget`, and the initial `findsNothing` checks remain. The test passes because of a lib change, not a test weakening. Commit b73a681e605 "Add AutomaticKeepAliveClientMixin to SelectableRegionState" added `wantKeepAlive => _focusNode.hasFocus` (selectable_region.dart:350), `updateKeepAlive()` calls (519, 528), and `super.build` (1956). That mirrors EditableText's `wantKeepAlive => widget.focusNode.hasFocus` (editable_text.dart:2638).
- part_a_evidence: The original body plus fixes failed with `Bad state: No element` at `tester.widget(find.byType(EditableText))` ($S/failures_base_textoffsetfix_on_head/131.txt). The preamble TODO `// TODO(Renzo-Olivares): This test fails because SelectionArea/SelectableText does not yet implement KeepAlive support when focused/selected.` (just above `group('magnifier')`, i.e. attached to this test) came from commit a1f0985bdf7, which is older than b73a681e605 in `git log 5c94360..HEAD`. The TODO is stale. The feature was implemented afterwards and the test now passes legitimately.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none. Housekeeping: delete the stale TODO.
- gap_ids: []
- gap_notes: G-KEEP-ALIVE is closed by the selectable_region.dart change. Caveat for the POC: the change applies to every SelectableRegion/SelectionArea, which is a framework-wide behavior change (a focused SelectionArea in any lazy list is now kept alive). Like EditableText, it keys on focus, not on having a selection.
- confidence: HIGH

## Test 132 — Can drag handles to show, unshow, and update magnifier
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: (1) `onSelectionChanged` is added and a new assertion `expect(currentSelection, TextSelection(4, 7))` checks the double-tap word selection. This strengthens the test, since the old test never asserted the selection. (2) Endpoints came from `renderEditable.getEndpointsForSelection(TextSelection(indexOf('d'), indexOf('f')))`, a hand-built (4,6) range. They now come from the live overlay via `getSelectionEndpoints` → `SelectableRegionState.selectionOverlay.selectionEndpoints` (helper in helpers_and_preamble.diff). This is more faithful: the right handle is at the real selection end (7), not at 6. WARRANTED. (3) `pump(30ms)` became `pumpAndSettle()` after the second tap. This is harmless, since it only lets the double-tap and handle show settle. (4) The magnifier assertions are unchanged: shown during drag (`findsOneWidget`), `globalGesturePosition` changes between moves, hidden after `up()`. The plumbing is equivalent. SelectableText forwards `magnifierConfiguration` → SelectionArea (selection_area.dart:139-140) → SelectionOverlay (selectable_region.dart:1313). Handle drag start calls `showMagnifier` (1213/1241), drag update calls `updateMagnifier` (1228/1256), and SelectionOverlay's handle drag end calls `hideMagnifier` (text_selection.dart:1013/1021). That is the same SelectionOverlay API EditableText's TextSelectionOverlay uses (text_selection.dart:497-525).
- part_a_evidence: The original failed in `findRenderEditable` at `find.byType(EditableText)` (No element, $S/failures_base_textoffsetfix_on_head/132.txt).
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: none
- confidence: HIGH

## Test 133 — SelectableText text span style is merged with default text style
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: `EditableText.style.fontSize` became `RichText` (descendant of SelectableText) `.text.style!.fontSize`, and a pump was added. Both read the effective root style after the regression-#71389 merge. The head impl still computes `defaultTextStyle.style.merge(widget.style ?? widget.textSpan?.style)` and passes it as `Text.rich(style:)`, which becomes the root span style in Text.build (widgets/text.dart:731-740). Same expected value (12.0).
- part_a_evidence: The original failed with `No element` at `find.byType(EditableText)` ($S/failures_base_textoffsetfix_on_head/133.txt, first block). Note: that file also contains a second failure (`Expected: TextSelection.collapsed(offset: 7) Actual: <null>`). That failure is from the base file's duplicate test of the same name (see 134).
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: none
- confidence: HIGH

## Test 134 — SelectableText selection update on tap
- status_at_head: PASSING
- change_status: RENAMED
- part_a_verdict: WARRANTED
- part_a_details: This is not a new stand-in. In the base file this exact body (test_base.dart:5563-5596) was a duplicate `testWidgets('SelectableText text span style is merged with default text style', …)`, a copy-paste name bug, so the splitter saw it as ADDED. Head renames it to a correct name and changes the body only by adding `await tester.pump();` after `pumpWidget`. All assertions are verbatim: null/0 initially, `TextSelection.collapsed(offset: 7)` and count 1 after a tap, and no extra callback on a same-spot re-tap. It is not weaker than 15 or 125. It passes because SelectableRegion really collapses the selection at the tap on mobile (`_handleMouseTapUp` → `_collapseSelectionAt`, selectable_region.dart:951-957), which SelectableText reports as `TextSelection(7,7)`. There is no visible caret (G-NO-CARET), but the test only asserts the reported selection. Test 125 (unchanged, still failing: count 0 after a long press) and test 15 cover different behavior and were not replaced by this one.
- part_a_evidence: Without the pump, the original body fails with `Expected: TextSelection.collapsed(offset: 7) Actual: <null>` ($S/failures_base_textoffsetfix_on_head/133.txt, second block). The scratch run confirms it: a tap in the first frame yields `selection == null`, and a later tap yields collapsed(7). The cause is two-level registration. SelectionArea → SelectionListener → Text registers through `_scheduleSelectableUpdate` (selectable_region.dart:2444-2467): the nested container runs in a microtask, and the parent then needs another post-frame callback. Until then `_selectionNotifier.registered` is false and impl_head's `_handleSelectionDetailsChanged` silently drops the change. This is a test-only timing artifact, so the pump is warranted.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: This test does not mask G-NO-CARET. It never asserted caret painting, even at base.
- confidence: HIGH

## Test 135 — Off-screen selected text doesn't throw exception
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: The only change is an added `await tester.pump(); // Allow nested selection containers to register.`. Long-press, `expect(selection, isNotNull)`, scrolling it off-screen, Pop, and `takeException() isNull` are all unchanged.
- part_a_evidence: The original body failed at `expect(selection, isNotNull)` with `Actual: <null>` ($S/failures_base_textoffsetfix_on_head/135.txt). This is the same first-frame registration artifact as 134 (selectable_region.dart:2444-2467), not a behavioral difference.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: none
- confidence: HIGH

## Test 136 — SelectableText respects MediaQueryData.lineHeightScaleFactorOverride, MediaQueryData.letterSpacingOverride, and MediaQueryData.wordSpacingOverride
- status_at_head: FAILING
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: `findRenderEditable` → `renderEditable.text?.style` / `.strutStyle` became RenderParagraph (the RichText under SelectableText) `.text.style` / `.strutStyle`, plus a pump. The four expectations are unchanged (height, letterSpacing, wordSpacing, and strut height all 2.0). WARRANTED as an edit, but the harness was left as a bare `Directionality` + `MediaQuery`, so the test still fails before reaching any assertion.
- part_a_evidence: Diff lines `-final RenderEditable renderEditable = findRenderEditable(tester);` and `+final RenderParagraph renderParagraph = tester.renderObject(find.descendant(of: find.byType(SelectableText), matching: find.byType(RichText)));`.
- part_b_classification: MIXED
- part_b_root_cause: The immediate error is `No MaterialLocalizations found. SelectionArea widgets require MaterialLocalizations` while building SelectionArea, followed by `Bad state: No element` from the finder ($S/failures/136.txt). The harness also lacks an Overlay, which `SelectableRegionState.build` asserts (selectable_region.dart:1957). This is a real new requirement: the old EditableText-based widget built fine under this harness. Behind it, the override behavior itself works. Text.build applies `_OverridingTextStyleTextSpanUtils.applyTextSpacingOverrides` to the root span (text.dart:728-740) and merges `StrutStyle(height: lineHeightScaleFactor)` into strutStyle (text.dart:742-744). EditableText does the equivalent (editable_text.dart:4679-4686, 5029-5043). Verified with a scratch test: the same body wrapped in `MaterialApp(home: MediaQuery(data: …, child: SelectableText(... strutStyle: StrutStyle(height: 0.9))))` passes all four expectations. Minor unexposed divergence: the old code always passed `strutStyle ?? const StrutStyle()`, so the override also set a strut when the user gave none. The new code leaves strut null in that case (the scratch run printed `STRUT_NO_ARG: null`), although text style height is still 2.0.
- part_b_surface_fix: Wrap the harness in `MaterialApp(home: MediaQuery(data: MediaQueryData(lineHeightScaleFactorOverride: 2.0, letterSpacingOverride: 2.0, wordSpacingOverride: 2.0), child: SelectableText('hello world', strutStyle: StrutStyle(height: 0.9))))`. Alternatively, add `Localizations` (DefaultMaterialLocalizations + DefaultWidgetsLocalizations) and `Overlay.wrap`. Verified passing.
- gap_ids: [G-OVERLAY-LOCALIZATION-REQUIREMENT]
- gap_notes: G-OVERLAY-LOCALIZATION-REQUIREMENT: the pumpWidget of a bare Directionality/MediaQuery harness exposes it. SelectionArea requires MaterialLocalizations (and SelectableRegion requires an Overlay), which old SelectableText did not. G-MEDIAQUERY-TEXT-OVERRIDES is not a real gap for this test's assertions. The only residual difference is the null-strut case above (low severity, untested).
- confidence: HIGH (verified by scratch run)

## Test 137 — iOS does not use the system context menu by default even when supported
- status_at_head: PASSING
- change_status: UNCHANGED
- part_a_verdict: N/A (unchanged)
- part_a_details: The body is unchanged. The overlay-fix run failed with `RangeError (index): Index out of range` ($S/failures_base_overlayfix_on_head/137_TargetPlatform.iOS.txt). That came from the old RenderEditable-based `textOffsetToPosition` helper, and it disappears with head's RenderParagraph helper (no entry in failures_base_textoffsetfix_on_head). This is a helper-level surface issue only.
- part_a_evidence: The head impl always passes `contextMenuBuilder: _adaptContextMenuBuilder` → `AdaptiveTextSelectionToolbar.selectableRegion` (impl_head `_adaptContextMenuBuilder`), so SystemContextMenu is never used. That matches the old default. Caveat: the test passes partly by construction, because the head impl ignores `widget.contextMenuBuilder` entirely (G-TOOLBAR-OPTIONS, covered elsewhere). A user who opts into SystemContextMenu through contextMenuBuilder would be ignored, and this test does not cover that.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: none
- confidence: HIGH

## Test 138 — SelectableText does not crash at zero area
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: `EditableTextState.updateEditingValue(TextEditingValue(text: 'XYZ', selection: (0,3)))` became `SelectableRegionState.selectAll()` followed by `pump()`. Both select the full 'XYZ' (0..3) with no focus or overlay, then pump. The `Size.zero` assertion is unchanged. The crash the original test guarded against lived in the RenderEditable/EditableText path, which no longer exists. The new test exercises the equivalent code path in the new architecture: selection geometry and paint in RenderParagraph at zero size.
- part_a_evidence: The original failed with `No element` at `tester.state(find.byType(EditableText))` ($S/failures_base_textoffsetfix_on_head/138.txt).
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: none
- confidence: MEDIUM. It would be HIGH if the original regression's crash site were confirmed to have no RenderParagraph analogue (the test comment doesn't cite the issue).

## Group summary
- WARRANTED: 6 (131, 132, 133, 134, 135, 138)
- PARTIAL (still failing): 3 (129, 130, 136)
- FAKE FIX: 0; MIXED: 0; COSMETIC: 0; N/A (unchanged): 1 (137)
- Part B: 129 GAP [G-SELECTION-STYLE, G-LAYOUT-SIZE]; 130 GAP [G-SELECTION-STYLE, G-LAYOUT-SIZE]; 136 MIXED [G-OVERLAY-LOCALIZATION-REQUIREMENT]. The assertions pass once MaterialApp is added (verified).
- No new gap ids introduced.
- Housekeeping: the preamble TODO for "keeps alive when has focus" is stale. The keep-alive support was added later in b73a681e605, and the test passes legitimately. Test 134 is the base file's duplicate-named test, renamed, not a new weaker test.
