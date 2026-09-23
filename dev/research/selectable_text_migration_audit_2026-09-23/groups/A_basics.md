# Group A_basics report

Notes: "head impl" = packages/flutter/lib/src/material/selectable_text.dart at HEAD; "base impl" = $S/impl_base.dart. Scratch experiments were run in packages/flutter/test/material/zz_scratch_A_test.dart (now deleted); their results are cited as [scratch].

## Test 001 — throw if no Overlay widget exists above
- status_at_head: FAILING
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: The only edit is the expected message: `contains('EditableText widgets require an Overlay widget ancestor')` → `contains('SelectableRegion widgets require an Overlay widget ancestor')`. Both strings come from the same helper, which interpolates the widget's runtimeType (widgets/debug.dart:515 `'${context.widget.runtimeType} widgets require an Overlay '`), so the string update itself is WARRANTED. The harness, the gesture steps and the final side-effect assertion are unchanged. The test still fails, so it is PARTIAL.
- part_a_evidence: The head failure (failures/001.txt) is `Expected: contains 'SelectableRegion widgets require an Overlay widget ancestor' Actual: 'No MaterialLocalizations found. SelectionArea widgets require MaterialLocalizations...'`. The original body fails the same way (failures_base_textoffsetfix_on_head/001.txt). Old: the Overlay check ran lazily when the gesture built a SelectionOverlay (widgets/text_selection.dart:1100 `assert(debugCheckHasOverlay(context))`), with context = EditableText. New: SelectionAreaState.build asserts MaterialLocalizations first (material/selection_area.dart:125). SelectableRegionState.build then asserts Overlay eagerly at build time (widgets/selectable_region.dart:1957).
- part_b_classification: MIXED
- part_b_root_cause: The immediate error is the new hard MaterialLocalizations requirement from SelectionArea, which fires before the Overlay check. [scratch] I wrapped the harness in `Localizations(WidgetsLocalizationsDelegate, MaterialLocalizationsDelegate)`. The build then throws "No Overlay widget found." and the `error.message` assertion PASSES. The test still fails on the last line, `expect(tester.takeException(), isNotNull); // side effect exception`, because the new implementation fails at build time (the subtree becomes an ErrorWidget). There is no half-built gesture/overlay state, so unmounting throws nothing ([scratch] takeException() after pumpWidget(SizedBox.shrink()) == null). The Overlay error is also raised at pumpWidget, not on the mouse gesture the test performs.
- part_b_surface_fix: Add a Localizations ancestor with Material/Widgets delegates to get past the first error. This alone does NOT make the test pass: the side-effect assertion would have to become `isNull` (a value change that documents the gap), or the assertion would have to be dropped.
- gap_ids: [G-OVERLAY-LOCALIZATION-REQUIREMENT]
- gap_notes: G-OVERLAY-LOCALIZATION-REQUIREMENT: SelectableText now hard-requires MaterialLocalizations at build (selection_area.dart:125) and an Overlay at build (selectable_region.dart:1957). The old widget built with only MediaQuery+Directionality and needed an Overlay only when a gesture created the selection overlay (text_selection.dart:1100). The assertions that expose this are `expect(error.message, contains('...Overlay widget ancestor'))` (the Localizations error comes first) and `expect(tester.takeException(), isNotNull)` (error timing and side effects changed). Tests 004/005 also depend on this gap (see their notes).
- confidence: HIGH (both halves verified with a scratch run)

## Test 002 — Do not crash when remove SelectableText during handle drag
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: (1) `controller.selection` became the `onSelectionChanged` callback (`currentSelection`). The expectations are unchanged: `baseOffset 4`, `extentOffset 7`. There is a new, harmless `expect(currentSelection, isNotNull)`. WARRANTED. (2) `renderEditable.getEndpointsForSelection` + `globalize` became the `getSelectionEndpoints(tester)` helper. The helper reads `SelectableRegionState.selectionOverlay.selectionEndpoints` (selectable_region.dart:434) and additionally asserts that the overlay is non-null. `expect(endpoints.length, 2)` is kept. WARRANTED, and slightly stronger. (3) Added `await tester.tap(find.byType(SelectableText)); await tester.pump();` with the comment "Focus the SelectableText first". [scratch] The pump is REQUIRED: without it the long press selects nothing (callback null, selectionOverlay null), because SelectionArea registers its selectables a frame after the first build. The tap is NOT required: tap+pump and pump-only both give TextSelection(4,7) with an overlay. The tap lands at the widget center (400,300), about 300px from ePos (71.4,18), so it cannot chain into a double tap. The tap is harmless, but its comment is misleading. The extra pump is WARRANTED. (4) No steps were removed. The left-handle drag start, `moveTo(newHandlePos)`, the unmount via `setter`, `moveTo(newHandlePos1)`, the "Do not crash here" pump and `gesture.up()` are all identical to base.
- part_a_evidence: The original failed with `Bad state: No element` at `tester.widget(find.byType(EditableText))` (failures_base_textoffsetfix_on_head/002.txt). Head impl `_handleSelectionDetailsChanged` builds a `TextSelection(baseOffset: range.startOffset, extentOffset: range.endOffset)` from SelectionListenerNotifier (head selectable_text.dart, the `_handleSelectionDetailsChanged` method). A long press selects the word through `_handleTouchLongPressStart → _selectWordAt` and shows handles on Android at `_handleTouchLongPressEnd` (selectable_region.dart:1007-1034).
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: Suggest dropping the unneeded tap, or renaming its comment to "let SelectionArea register selectables". Not a fidelity issue.
- confidence: HIGH (tap/pump necessity verified with scratch runs)

## Test 004 — Rich selectable text has expected defaults
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: MIXED
- part_a_details: No expectation changed. All six assertions are identical (`showCursor false`, `autofocus false`, `dragStartBehavior start`, `cursorWidth 2.0`, `cursorHeight isNull`, `enableInteractiveSelection true`). WARRANTED for the assertions. The harness went from bare `MediaQuery(MediaQueryData()) + Directionality` to `boilerplate()`, which adds Theme, Localizations(Widgets+Material), Overlay.wrap, Center and Material. The brief treats adding an Overlay as warranted. Adding MaterialLocalizations is not optional here, though: [scratch] bare MediaQuery + Directionality + `Overlay.wrap` still fails with "No MaterialLocalizations found." So the harness swap quietly absorbs G-OVERLAY-LOCALIZATION-REQUIREMENT. The old SelectableText.rich built in this minimal tree, and the new one does not. That is a low-severity mask of a real API-contract change. Test 001 documents the same gap, so the harness piece is minor. Separately, the assertions only read constructor fields of the `SelectableText` widget, so they pass whether or not the cursor params do anything. In the head impl they are inert (`showCursor`/`cursorWidth`/`cursorHeight` are declared at selectable_text.dart:130/302 etc. and never read in build 531-651). The test was vacuous about behavior before too, so this is not a fake fix.
- part_a_evidence: The original body with Overlay + textOffset fixes fails in SelectionAreaState.build → debugCheckHasMaterialLocalizations (material/selection_area.dart:125) (failures_base_textoffsetfix_on_head/004.txt). The base impl built EditableText with no Localizations or Overlay requirement at build.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: [G-OVERLAY-LOCALIZATION-REQUIREMENT] (masked by harness swap, low severity)
- gap_notes: G-OVERLAY-LOCALIZATION-REQUIREMENT: the minimal-tree harness was replaced because SelectionArea requires MaterialLocalizations (selection_area.dart:125) and SelectableRegion requires an Overlay (selectable_region.dart:1957) at build.
- confidence: HIGH

## Test 005 — Rich selectable text supports WidgetSpan
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: MIXED
- part_a_details: This is the same pure harness swap as 004 (bare MediaQuery+Directionality → `boilerplate()`). The span tree and the single assertion `expect(tester.takeException(), isNull)` are unchanged. For the WidgetSpan intent (Text.rich accepts a WidgetSpan with no assertion) this is WARRANTED. Because the only assertion is "no exception while building", the harness is effectively part of what is asserted. The original tree now throws the MaterialLocalizations error, and the swap hides that (G-OVERLAY-LOCALIZATION-REQUIREMENT, low severity, documented by 001). No finder or expectation value was changed.
- part_a_evidence: failures_base_textoffsetfix_on_head/005.txt: `Expected: null Actual: FlutterError:<No MaterialLocalizations found. SelectionArea widgets require MaterialLocalizations...>`. The head impl builds `Text.rich(widget.textSpan!, ...)` (head selectable_text.dart:553), and RenderParagraph supports WidgetSpan natively.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: [G-OVERLAY-LOCALIZATION-REQUIREMENT] (masked by harness swap, low severity)
- gap_notes: See 004.
- confidence: HIGH

## Test 007 — uses DefaultSelectionStyle for selection colors if provided
- status_at_head: PASSING
- change_status: RENAMED (from 'uses DefaultSelectionStyle for selection and cursor colors if provided'; summary.json lists it as ADDED)
- part_a_verdict: MIXED
- part_a_details: (1) Selection color: `tester.state<EditableTextState>(...).widget.selectionColor` became `tester.widget<Text>(find.byType(Text)).selectionColor`, with the same expected value `Colors.orange`. WARRANTED. [scratch] The color really reaches the render layer: `findRenderParagraph(tester).selectionColor` is orange. (2) Cursor color: `const Color cursorColor = Colors.red;` and `expect(state.widget.cursorColor, cursorColor);` were DELETED, and "and cursor" was dropped from the test name. `cursorColor: Colors.red` is still passed to DefaultSelectionStyle, but nothing asserts it, so it is dead config. This is a FAKE FIX: it removes the assertion for a feature the new implementation lacks, and nothing else fails or documents it. The old impl resolved `cursorColor = widget.cursorColor ?? selectionStyle.cursorColor ?? <platform primary>` (impl_base.dart:704/717/730/740) and passed it to EditableText. The head impl never reads `widget.cursorColor` or `DefaultSelectionStyle.cursorColor`; the field exists only at selectable_text.dart:142/321/442 (declaration and diagnostics).
- part_a_evidence: The original failed with `Bad state: No element` at `tester.state<EditableTextState>` (failures_base_textoffsetfix_on_head/007.txt). Head impl: `selectionColor: widget.selectionColor ?? selectionStyle.selectionColor` (selectable_text.dart:563/578). RenderParagraph getter: rendering/paragraph.dart:744.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: [G-NO-CARET]
- gap_notes: G-NO-CARET: the deleted `expect(state.widget.cursorColor, cursorColor)` is the assertion that exposed it. There is no caret in the SelectionArea/Text architecture, so `cursorColor`/`DefaultSelectionStyle.cursorColor` are no-ops. To document the gap honestly, keep a second failing test for the cursor-color half (like 013) instead of silently dropping it. Also note: the old per-platform fallback selection color (`theme.colorScheme.primary.withOpacity(0.40)` / `cupertinoTheme.primaryColor.withOpacity(0.40)`, impl_base.dart:706-741) is gone. Head falls back to Text's `DefaultSelectionStyle.of(context).selectionColor ?? DefaultSelectionStyle.defaultColor` (widgets/text.dart:772-774). This test cannot catch that because it supplies a color, but it is a related G-SELECTION-STYLE difference when no DefaultSelectionStyle color is set.
- confidence: HIGH

## Test 008 — Selectable Text can have custom selection color
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: `tester.state<EditableTextState>(find.byType(EditableText)).widget.selectionColor` → `tester.widget<Text>(find.byType(Text)).selectionColor`, with the same expected value. The strength is equivalent: both check the configuration handed to the inner text widget. There is exactly one `Text` in the tree, and head passes `widget.selectionColor` first (selectable_text.dart:563/578). Text forwards it to RichText → RenderParagraph.selectionColor (widgets/text.dart:772, paragraph.dart:744).
- part_a_evidence: The original failed with `Bad state: No element` at `tester.state<EditableTextState>` (failures_base_textoffsetfix_on_head/008.txt). [scratch] With the analogous DefaultSelectionStyle setup, RenderParagraph.selectionColor holds the configured color.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: none
- confidence: HIGH

## Test 009 — Selectable Text has adaptive size
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: FAKE FIX
- part_a_details: Size expectations changed: `Size(17.0, 14.0)` → `Size(14.0, 14.0)` and `Size(199.0, 14.0)` → `Size(196.0, 14.0)`. Both widths shrink by exactly 3px, which is RenderEditable's caret margin `_kCaretGap (1.0) + cursorWidth (2.0)`. RenderEditable adds that margin to its laid-out width; RenderParagraph does not. The branch's own commit ece56299239 ("Update SelectableText tests to remove legacy RenderEditable caret margin") confirms the edit was made to match the new layout. Arguably the new width is reasonable for a caret-less widget, but by the rubric this is a changed size value that hides a user-visible layout difference: every SelectableText is now (1 + cursorWidth) px narrower, and `cursorWidth` no longer affects size at all.
- part_a_evidence: rendering/editable.dart:25 `const double _kCaretGap = 1.0;`, :1279 `double get _caretMargin => _kCaretGap + cursorWidth;`, and :2414/:2427 (`constraints.constrainWidth(_textPainter.width + _caretMargin)`, `Size(_textPainter.width + _caretMargin, ...)`). failures_base_textoffsetfix_on_head/009.txt: `Expected: Size(17.0, 14.0) Actual: Size(14.0, 14.0)`.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: [G-LAYOUT-SIZE]
- gap_notes: G-LAYOUT-SIZE: the original `expect(textBox.size, const Size(17.0, 14.0))` exposes that RenderParagraph intrinsic width lacks RenderEditable's `_caretMargin` (editable.dart:1279). Intentional-looking, but it is a behavior change the owner should call out rather than silently re-baseline.
- confidence: HIGH (the 3px delta equals _kCaretGap + default cursorWidth 2.0)

## Test 011 — can switch between textWidthBasis
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: FAKE FIX
- part_a_details: `Size(633.0, 28.0)` → `Size(630.0, 28.0)` for `TextWidthBasis.longestLine`. The `TextWidthBasis.parent` expectation (800x28) is unchanged. It is the same 3px caret-margin re-baseline as 009. The test's intent (switching basis changes the width) is still exercised, but the absolute value was edited to match the new layout.
- part_a_evidence: failures_base_textoffsetfix_on_head/011.txt: `Expected: Size(633.0, 28.0) Actual: Size(630.0, 28.0)`. editable.dart:1279/2414/2427 as in 009.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: [G-LAYOUT-SIZE]
- gap_notes: G-LAYOUT-SIZE: exposed by `expect(textBox.size, const Size(633.0, 28.0))`, which is the caret margin missing in RenderParagraph. Low severity; arguably correct for a caret-less widget.
- confidence: HIGH

## Test 012 — can switch between textHeightBehavior
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: `findRenderEditable(tester).textHeightBehavior` → `findRenderParagraph(tester).textHeightBehavior` (the helper was rewritten to walk to the first RenderParagraph under SelectableText; see helpers_and_preamble.diff). Both expectations are unchanged (`isNull`, then `textHeightBehavior`). This is a straight render-object swap.
- part_a_evidence: The original failed with `Bad state: No element` in `findRenderEditable` (failures_base_textoffsetfix_on_head/012.txt). rendering/paragraph.dart:730 `TextHeightBehavior? get textHeightBehavior`. Head impl passes `textHeightBehavior: widget.textHeightBehavior ?? defaultTextStyle.textHeightBehavior` to Text (selectable_text.dart:553-580).
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: none
- confidence: HIGH

## Test 013 — Cursor blinks when showCursor is true
- status_at_head: FAILING
- change_status: MODIFIED
- part_a_verdict: COSMETIC
- part_a_details: The body is byte-for-byte the same test logic. It was reformatted into the multi-arg `testWidgets(name, body, /* TODO */)` form with the comment `// TODO(Renzo-Olivares): Cursor not supported by SelectionArea`. No skip was added, and no assertion or step was changed. It is deliberately left failing to document the gap.
- part_a_evidence: pertest/013.diff shows only indentation plus the TODO line. failures/013.txt: `Bad state: No element` at `tester.state(find.byType(EditableText))`.
- part_b_classification: GAP
- part_b_root_cause: The immediate error is the stale `EditableTextState` finder, but no surface fix exists. There is no caret anywhere in the new tree. `SelectableText.showCursor` (head selectable_text.dart:130/302) is never read in build (531-651). None of the cursor params (`cursorWidth`/`cursorHeight`/`cursorRadius`/`cursorColor`) are forwarded anywhere. SelectableRegion has no caret painting or blink timer: its only "caret" is a `caretRect` computed for the magnifier (selectable_region.dart:1271). RenderParagraph paints only selection highlights. A mobile tap only collapses the selection at the tapped point (`_collapseSelectionAt`, selectable_region.dart:955), and a collapsed selection paints nothing. The asserted API (`EditableTextState.cursorCurrentlyVisible`/`cursorBlinkInterval`, editable_text.dart:4827/4833) has no counterpart. A cursor is not possible in SelectionArea without new framework work: caret painting in RenderParagraph/_SelectableFragment, a blink controller tied to SelectableRegion focus, and caret placement on tap.
- part_b_surface_fix: none
- gap_ids: [G-NO-CARET]
- gap_notes: G-NO-CARET: exposed by `tester.state(find.byType(EditableText))` and then `expect(editableText.cursorCurrentlyVisible, equals(!initialShowCursor))`. `showCursor: true` is a silent no-op in the new SelectableText.
- confidence: HIGH (code-grounded; no API to probe)

## Test 014 — selectable text selection toolbar renders correctly inside opacity
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: Old: a programmatic `state.renderEditable.selectWordsInRange(from: Offset.zero, cause: SelectionChangedCause.tap)` plus `expect(state.showToolbar(), true)` (editable_text.dart:5184). New: `await tester.pump()` (selectable registration) followed by a real `tester.longPressAt(center)` + `pumpAndSettle()`. On touch this goes through `_handleTouchLongPressStart` (selects the word) and `_handleTouchLongPressEnd` → `_showToolbar()` (selectable_region.dart:1007-1034). The final assertion `expect(find.text('Select all'), findsOneWidget)`, the Opacity(0.5) wrapper and the 1-second AnimatedOpacity pump are unchanged. The explicit `expect(showToolbar(), true)` is gone, but the `findsOneWidget` on a toolbar button already implies the toolbar was shown, and the test's intent (a toolbar under an Opacity ancestor renders) is kept. The new path is a real user gesture rather than a private-API shortcut. Minor caveat: 'Select all' passes for a different reason in each world. Old: only one word was selected. New: SelectableRegion always offers Select all when content exists (see the TODO in helpers_and_preamble.diff). For this test the outcome is identical.
- part_a_evidence: The original failed with `Bad state: No element` at `tester.state<EditableTextState>` (failures_base_textoffsetfix_on_head/014.txt). pertest/014.diff.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: none
- confidence: HIGH

## Group summary
- Tests: 11 (2 failing at head: 001, 013; 9 passing).
- Part A verdict counts: WARRANTED 4 (002, 008, 012, 014); FAKE FIX 2 (009, 011: 3px caret-margin re-baselines); MIXED 3 (004, 005: harness swap absorbs the Localizations requirement; 007: selection-color swap warranted, cursorColor assertion deleted = fake); COSMETIC 1 (013); PARTIAL 1 (001).
- Part B: 001 MIXED (Localizations is surface-fixable and the message then matches; the side-effect-exception assertion is a real behavioral difference); 013 GAP (G-NO-CARET, no surface fix possible).
- Gap ids used: G-NO-CARET (007 masked, 013 exposed), G-LAYOUT-SIZE (009, 011 masked), G-OVERLAY-LOCALIZATION-REQUIREMENT (001 exposed; 004, 005 masked by harness). Related observation: G-SELECTION-STYLE, because the platform-default selection color fallback is lost (see 007 notes).
- No new gap ids introduced.
