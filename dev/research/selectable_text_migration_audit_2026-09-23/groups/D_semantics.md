# Group D_semantics report

Shared evidence used below (cited as E1-E6):
- E1 old text-field semantics: RenderEditable.describeSemanticsConfiguration (packages/flutter/lib/src/rendering/editable.dart:1330-1406) sets `attributedValue`, `isTextField`, `isReadOnly`, `isFocusable`, `isFocused`, `isMultiline`, `inputType=text`; `onSetSelection` when focused (1386-1388); `textSelection` + `onMoveCursor{Backward,Forward}By{Character,Word}` when selection valid (1394-1405). With recognizer spans (non-macOS) it instead becomes a boundary with explicit child nodes (1337-1345). EditableText adds `Semantics(inputType, onCopy, onCut, onPaste)` (widgets/editable_text.dart:5937-5941; copy gated by focus+selection at 5397-5405) and builds its Scrollable with `excludeFromSemantics: true` (editable_text.dart:5914).
- E2 new text semantics: RenderParagraph.describeSemanticsConfiguration (rendering/paragraph.dart:1195-1240) emits only `attributedLabel` + `textDirection` (or boundary+explicit children for recognizer spans, 1208-1210). No value, flags, textSelection, or selection/cursor/copy actions.
- E3 SelectableRegion contributes no semantics: its gesture detector is `excludeFromSemantics: true` and its Focus is `includeSemantics: false` (widgets/selectable_region.dart:1983,1987). SelectionArea/SelectionContainer add no semantics nodes.
- E4 head SelectableText (impl_head.dart): `SingleChildScrollView` (598) creates a Scrollable whose `_ScrollSemantics` produces an extra `hasImplicitScrolling` node (not excluded as EditableText's was); outer `Semantics(label: semanticsLabel, excludeSemantics: semanticsLabel != null, onLongPress: focusNode.requestFocus)` retained (647-653).
- E5 head tree for plain `SelectableText('Guten Tag')` (failures/058.txt): `node(actions: longPress) > node(flags: hasImplicitScrolling, scrollExtent 0) > node(label: 'Guten Tag')` vs. old single merged node `{value, longPress, inputType:text, isTextField,isFocusable,isReadOnly,isMultiline}`.
- E6 scratch probes (zz_scratch_D_test.dart, deleted): (P1) test-62 scenario on head: offscreen link node exists with `isHidden`, id=9 (id 8 is now the onscreen label node); `performAction(9, showOnScreen)` scrolls outer controller to 3592.0 -> PASS. (P4) semantic longPress on the longPress node moves primary focus to SelectableRegion's FocusNode, but NO node gets `isFocused`/`isFocusable`; after a long-press selection NO node has `textSelection`, `copy`, or `setSelection`.

Gap sub-ids introduced (all children of G-SEMANTICS-TEXTFIELD):
- G-SEMANTICS-TEXTFIELD-IDENTITY: no node with isTextField/isReadOnly/isMultiline/inputType=text; text exposed as `label` instead of `value` (E1 vs E2).
- G-SEMANTICS-FOCUS: no isFocusable/isFocused flags; semantic focus not reflected (E3, E6-P4).
- G-SEMANTICS-SELECTION-STATE: no `textSelection` on any node (E2, E6-P4).
- G-SEMANTICS-SELECTION-ACTIONS: no setSelection / moveCursor{Forward,Backward}By{Character,Word} actions (E1 1386-1405 have no counterpart).
- G-SEMANTICS-COPY-ACTION: no `SemanticsAction.copy` on the text node when a selection exists (E1 editable_text.dart:5939; only the visual toolbar Copy button node exists).
- G-SEMANTICS-SCROLL-NODE: extra `hasImplicitScrolling` node from the POC's SingleChildScrollView (E4); EditableText excluded its Scrollable from semantics. This is a POC construction choice (fixable in selectable_text.dart), not a SelectionArea limitation.

## Test 041 — Selectable text identifies as text field in semantics
- status_at_head: FAILING
- change_status: UNCHANGED
- part_a_verdict: N/A (unchanged)
- part_a_details: n/a
- part_a_evidence: n/a
- part_b_classification: GAP
- part_b_root_cause: `includesNodeWith(flags: [isTextField,isFocusable,isReadOnly,isMultiline])` finds no node (failures/041.txt, line 1633). Text is exposed via RenderParagraph label only (E2); SelectableRegion adds no focus semantics (E3).
- part_b_surface_fix: none
- gap_ids: [G-SEMANTICS-TEXTFIELD-IDENTITY, G-SEMANTICS-FOCUS]
- gap_notes: IDENTITY: no RenderEditable-equivalent config (editable.dart:1379-1384) exists in the Text/SelectionArea stack. FOCUS: isFocusable is missing because SelectableRegion's Focus uses includeSemantics:false (selectable_region.dart:1987).
- confidence: HIGH (failure message is unambiguous; tree in E5).

## Test 042 — Selectable text rich text with spell out in semantics
- status_at_head: FAILING
- change_status: UNCHANGED
- part_a_verdict: N/A (unchanged)
- part_a_details: n/a
- part_a_evidence: n/a
- part_b_classification: GAP
- part_b_root_cause: No node with text-field flags (failures/042.txt line 1659). The spellOut attribute itself survives: RenderParagraph copies span StringAttributes into `attributedLabel` (paragraph.dart:1214-1238), but the test requires `attributedValue` + text-field flags on the same node.
- part_b_surface_fix: none (switching `attributedValue:` to `attributedLabel:` and dropping flags would pass but would discard the test's text-field intent)
- gap_ids: [G-SEMANTICS-TEXTFIELD-IDENTITY, G-SEMANTICS-FOCUS]
- gap_notes: Attribute propagation is NOT a gap (label carries SpellOutStringAttribute); the gap is value-vs-label and missing text-field/focusable flags (editable.dart:1350-1381 vs paragraph.dart:1238).
- confidence: HIGH for flags; MEDIUM that attributedLabel carries the range exactly (not run; derived from code).

## Test 043 — Selectable text rich text with locale in semantics
- status_at_head: FAILING
- change_status: UNCHANGED
- part_a_verdict: N/A (unchanged)
- part_a_details: n/a
- part_a_evidence: n/a
- part_b_classification: GAP
- part_b_root_cause: Same as 042 with LocaleStringAttribute (failures/043.txt line 1693). Locale attribute is carried in attributedLabel by RenderParagraph; value/text-field flags missing.
- part_b_surface_fix: none
- gap_ids: [G-SEMANTICS-TEXTFIELD-IDENTITY, G-SEMANTICS-FOCUS]
- gap_notes: as 042.
- confidence: HIGH (same mechanism as 042).

## Test 044 — Selectable rich text with gesture recognizer has correct semantics
- status_at_head: FAILING
- change_status: UNCHANGED
- part_a_verdict: N/A (unchanged)
- part_a_details: n/a
- part_a_evidence: n/a
- part_b_classification: MIXED
- part_b_root_cause: Fails on `expected node ... input type SemanticsInputType.text but found none` (failures/044.txt line 1737). Comparing trees: expected `longPress+inputType:text > node > [label 'text', link(isLink, tap, 'link')]`; actual `longPress > hasImplicitScrolling > node > [label 'text', link(isLink, tap, 'link')]`. The per-fragment inline-span semantics with recognizers is fully preserved by RenderParagraph (paragraph.dart:1208-1210 mirrors editable.dart:1337-1345); the only differences are (1) missing inputType=text (EditableText's `Semantics(inputType:)` merged into the longPress node, editable_text.dart:5938) and (2) the extra scroll node.
- part_b_surface_fix: none that preserves intent without impl change; removing the scroll node requires building the scrollable with excludeFromSemantics (impl change). Updating the expectation to add the scroll node and drop inputType would pass (the "would have matched" config in failures/044.txt) but accepts both differences.
- gap_ids: [G-SEMANTICS-TEXTFIELD-IDENTITY, G-SEMANTICS-SCROLL-NODE]
- gap_notes: Not G-SPAN-RECOGNIZERS: link node with isLink+tap is present. IDENTITY: inputType is gone because no EditableText Semantics wrapper. SCROLL-NODE: impl_head.dart:598 SingleChildScrollView adds node#3 `hasImplicitScrolling`.
- confidence: HIGH (full actual tree in failure output).

## Test 058 — SelectableText semantics
- status_at_head: FAILING
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: (1) removed `controller = editableTextWidget.controller`, added `await tester.pump()` for selectable registration — WARRANTED (G-NO-CONTROLLER). (2) three `controller.selection = TextSelection.collapsed(offset: 9|4|0)` replaced by `tester.tapAt(textOffsetToPosition(tester, 9|4|0))` — WARRANTED as a driver substitution (no expectation values changed), but it silently depends on tap-to-place-caret, which SelectionArea lacks (G-NO-CARET); even with full text-field semantics, the collapsed textSelection expectations could not be met by this driver. All semantics expectations (value, flags, inputType, textSelection, moveCursor*/setSelection) unchanged.
- part_a_evidence: 058.diff hunks at `-controller.selection = const TextSelection.collapsed(offset: 9);` / `+await tester.tapAt(textOffsetToPosition(tester, 9));`. Original+fix failed earlier with `Bad state: No element` at find.byType(EditableText) (failures_base_textoffsetfix_on_head/058.txt).
- part_b_classification: GAP
- part_b_root_cause: First expectation (line 2371) fails: `expected ... flags [isTextField,isFocusable,isReadOnly,isMultiline] but found flags 0`; actual tree E5 (3 nodes, label not value). Later steps would additionally require isFocused, textSelection collapsed, moveCursor*/setSelection, and a caret from tap.
- part_b_surface_fix: none
- gap_ids: [G-SEMANTICS-TEXTFIELD-IDENTITY, G-SEMANTICS-FOCUS, G-SEMANTICS-SELECTION-STATE, G-SEMANTICS-SELECTION-ACTIONS, G-SEMANTICS-SCROLL-NODE, G-NO-CARET]
- gap_notes: IDENTITY/SCROLL-NODE: first expectation (E5). FOCUS: second expectation's isFocused (E6-P4 shows no isFocused anywhere after focus). SELECTION-STATE/ACTIONS: `textSelection: collapsed(9)` + moveCursorBackwardBy*/setSelection (editable.dart:1386-1405, no RenderParagraph equivalent). NO-CARET: the new tapAt driver cannot produce collapsed selections.
- confidence: HIGH.

## Test 060 — SelectableText semantics, enableInteractiveSelection = false
- status_at_head: FAILING
- change_status: UNCHANGED
- part_a_verdict: N/A (unchanged)
- part_a_details: n/a
- part_a_evidence: n/a
- part_b_classification: GAP
- part_b_root_cause: `expected ... flags [isReadOnly,isTextField,isFocusable,isMultiline] but found flags 0` (failures/060.txt). Actual tree identical to E5 (SelectionContainer.disabled, impl_head.dart:644, adds nothing). The test correctly expects NO selection actions/isFocused here, and the new impl matches that part; what's missing is text-field identity/value/inputType, plus the extra scroll node.
- part_b_surface_fix: none
- gap_ids: [G-SEMANTICS-TEXTFIELD-IDENTITY, G-SEMANTICS-FOCUS, G-SEMANTICS-SCROLL-NODE]
- gap_notes: FOCUS here = missing isFocusable (old RenderEditable always set isFocusable=true, editable.dart:1379). Note an intentional design question: with enableInteractiveSelection=false the new widget arguably *should* look like plain Text; old one still claimed isTextField.
- confidence: HIGH.

## Test 061 — SelectableText semantics for selections
- status_at_head: FAILING
- change_status: MODIFIED
- part_a_verdict: MIXED
- part_a_details: (a) controller → `onSelectionChanged` capture + `expect(currentSelection, TextSelection(0,5))` — WARRANTED (G-NO-CONTROLLER). (b) Initial expectation: removed `value:'Hello'`, `inputType: text`, flags isReadOnly/isTextField/isFocusable/isMultiline; replaced with `longPress > hasImplicitScrolling > label 'Hello'` — FAKE FIX (masks G-SEMANTICS-TEXTFIELD-IDENTITY, G-SEMANTICS-FOCUS, G-SEMANTICS-SCROLL-NODE). (c) Step "focus + controller.selection = collapsed(5)" deleted and replaced with `longPressAt(offset 2)` selecting the whole word — FAKE FIX (caret scenario dropped: G-NO-CARET; the collapsed-selection semantics with only backward move actions is no longer tested). (d) Second/third expectations: removed isFocused, moveCursor{Backward,Forward}By{Character,Word}, setSelection, and `copy` actions; added Copy/Share/Select all toolbar button nodes — removals are FAKE FIX (mask G-SEMANTICS-SELECTION-ACTIONS, G-SEMANTICS-COPY-ACTION, G-SEMANTICS-FOCUS); toolbar nodes are a WARRANTED consequence of the long-press driver. (e) `textSelection` kept on the label node (0,5 and 5,3), and `controller.selection=(5,3)` replaced by `performAction(id, setSelection, {base:5, extent:3})` + `expect(currentSelection,(5,3))` — WARRANTED/strengthening: this is what still fails and documents the gap. Net effect: the test now guards only "textSelection on a node + setSelection works"; if those were added to RenderParagraph's node the test would pass with no text-field identity, focus, moveCursor or copy semantics.
- part_a_evidence: 061.diff: `-value: 'Hello', -inputType: ui.SemanticsInputType.text, -SemanticsFlag.isTextField ...`, `+TestSemantics(flags: [SemanticsFlag.hasImplicitScrolling] ...)`, `-controller.selection = const TextSelection.collapsed(offset: 5);` → `+await tester.longPressAt(middleOfTextPos);`, `-SemanticsAction.copy,`. Head failure: line 2671 `expected node id null to have textSelection [0, 5] but found: [null, null]` — every other node/flag/action in the rewritten expectation matched (failures/061.txt tree). Original+fix failed at `find.byType(EditableText)` (failures_base_textoffsetfix_on_head/061.txt).
- part_b_classification: GAP
- part_b_root_cause: RenderParagraph never sets `config.textSelection` (paragraph.dart:1195-1240) and SelectableRegion adds no semantics (E3), so the selected range is invisible to a11y (E6-P4). The subsequent `performAction(setSelection)` would be a no-op (no handler registered on the label node), so `currentSelection` would stay (0,5).
- part_b_surface_fix: none
- gap_ids: [G-SEMANTICS-SELECTION-STATE, G-SEMANTICS-SELECTION-ACTIONS, G-SEMANTICS-TEXTFIELD-IDENTITY, G-SEMANTICS-FOCUS, G-SEMANTICS-COPY-ACTION, G-SEMANTICS-SCROLL-NODE, G-NO-CARET]
- gap_notes: SELECTION-STATE: failing assertion `textSelection: TextSelection(0,5)` at line 2671. SELECTION-ACTIONS: `performAction(..., setSelection, {base:5,extent:3})` then `expect(currentSelection, (5,3))`. The remaining ids are masked by edits (b)-(d) rather than exposed by an assertion. Latent inconsistency: final expectation (after setSelection 5,3) lists Copy/Share but omits 'Select all' although SelectableRegion always offers Select all when content exists (see head TODO at test_head.dart:5532) — unreachable today but would be a wrong expectation once setSelection exists.
- confidence: HIGH (failure isolates textSelection; P4 confirms no setSelection/copy anywhere).

## Test 062 — semantic nodes of offscreen recognizers are marked hidden
- status_at_head: FAILING
- change_status: UNCHANGED
- part_a_verdict: N/A (unchanged)
- part_a_details: n/a
- part_a_evidence: n/a
- part_b_classification: MIXED
- part_b_root_cause: Fails at the tree expectation (`input type text but found none`, failures/062.txt). Actual vs expected: identical except (1) the longPress node lacks inputType=text, (2) an extra inner `hasImplicitScrolling` node (id 6, scrollExtentMax 0) sits between longPress node and the paragraph node. The regression under test (#100395: offscreen recognizer node gets `isHidden` and showOnScreen scrolls to it) is PRESERVED: link node has `flags: isHidden, isLink` (failures/062.txt node#9) and E6-P1 showed `performAction(9, showOnScreen)` scrolls to 3592.0. The hardcoded `performAction(8, ...)` is a SURFACE issue: id 8 is now the onscreen label node because of the extra scroll node.
- part_b_surface_fix: replace hardcoded id 8 with a lookup of the node labelled 'off screen' (or rely on ids after an impl fix removing the scroll node); expectation tree needs inputType removed and the scroll node inserted unless the impl changes.
- gap_ids: [G-SEMANTICS-TEXTFIELD-IDENTITY, G-SEMANTICS-SCROLL-NODE]
- gap_notes: IDENTITY: inputType lost (editable_text.dart:5938 has no counterpart). SCROLL-NODE: node#6 from impl_head.dart:598 shifts ids (8→9) and adds a nested implicit-scrolling container inside the user's scroll view; fixing it (excludeFromSemantics like editable_text.dart:5914) would also restore the hardcoded id. Not G-SPAN-RECOGNIZERS: recognizer semantics (isLink/tap/isHidden) work.
- confidence: HIGH (probe P1 ran on head).

## Test 063 — SelectableText change selection with semantics
- status_at_head: FAILING
- change_status: MODIFIED
- part_a_verdict: MIXED
- part_a_details: (a) controller → onSelectionChanged; hardcoded `inputFieldId = 2` → `tester.getSemantics(find.text('Hello')).id`, `ignoreId: true`, `pump` → `pumpAndSettle` — WARRANTED. (b) Initial state changed from programmatic `collapsed(5)` to long-press selecting (0,5) — FAKE FIX for the first expectation (collapsed caret state at end with backward-only move actions no longer asserted; G-NO-CARET). (c) Both tree expectations: removed value, inputType, flags isReadOnly/isTextField/isFocusable/isMultiline/isFocused, actions moveCursorBackwardByCharacter/ByWord, setSelection, copy; replaced with label node under longPress>hasImplicitScrolling; added toolbar button nodes — removals FAKE FIX (mask IDENTITY, FOCUS, SELECTION-ACTIONS, COPY-ACTION, SCROLL-NODE), toolbar nodes warranted by the driver change. (d) Kept: `textSelection` on the label node, and all three `performAction(setSelection, {4,4} / {0,0} / {0,5})` steps with `expect(currentSelection, ...)` asserting collapsed(4), collapsed(0), (0,5) — preserved intent (these still expose SELECTION-STATE, SELECTION-ACTIONS and NO-CARET).
- part_a_evidence: 063.diff/063.head.dart: `-controller.selection = const TextSelection(baseOffset: 5, extentOffset: 5);` → `+await tester.longPressAt(middleOfTextPos);`; removed `SemanticsAction.setSelection, SemanticsAction.copy` and `SemanticsFlag.isTextField ...` from both hasSemantics blocks. Head failure line 2922: `expected node id null to have textSelection [0, 5] but found: [null, null]`. Original+fix failed at find.byType(EditableText).
- part_b_classification: GAP
- part_b_root_cause: Same as 061: no textSelection on any node (E2/E3). Beyond that, the label node has no setSelection handler, so the three performAction calls are no-ops and `currentSelection` would stay (0,5); even with a handler, collapsed(4)/(0) requires a caret concept SelectableRegion lacks.
- part_b_surface_fix: none
- gap_ids: [G-SEMANTICS-SELECTION-STATE, G-SEMANTICS-SELECTION-ACTIONS, G-NO-CARET, G-SEMANTICS-TEXTFIELD-IDENTITY, G-SEMANTICS-FOCUS, G-SEMANTICS-COPY-ACTION, G-SEMANTICS-SCROLL-NODE]
- gap_notes: SELECTION-STATE: line 2922 textSelection. SELECTION-ACTIONS + NO-CARET: `expect(currentSelection, const TextSelection.collapsed(offset: 4))` after setSelection {4,4}. Others masked by edit (c). Same latent inconsistency as 061: final expectation omits 'Select all' after selecting everything, contradicting SelectableRegion's always-show-Select-all behavior.
- confidence: HIGH.

## Test 064 — Can activate SelectableText with explicit controller via semantics
- status_at_head: FAILING
- change_status: UNCHANGED
- part_a_verdict: N/A (unchanged)
- part_a_details: n/a
- part_a_evidence: n/a
- part_b_classification: GAP
- part_b_root_cause: First expectation fails: `expected node id 2 to have flags [isReadOnly,isTextField,isFocusable,isMultiline]` (failures/064.txt). Node id 2 happens to still be the longPress node (so the id itself is fine), but it carries no text-field data (E5). After `performAction(2, longPress)`, the handler (`focusNode.requestFocus()`, impl_head.dart:650-652) does focus SelectableRegion (E6-P4 primaryFocus set) but no node reports isFocused, no caret is placed at end (old EditableText set collapsed(5) on focus), and no moveCursor*/setSelection/textSelection appear.
- part_b_surface_fix: none
- gap_ids: [G-SEMANTICS-TEXTFIELD-IDENTITY, G-SEMANTICS-FOCUS, G-SEMANTICS-SELECTION-STATE, G-SEMANTICS-SELECTION-ACTIONS, G-NO-CARET, G-SEMANTICS-SCROLL-NODE]
- gap_notes: FOCUS: activation-by-semantics works functionally (focus moves) but is invisible to a11y (isFocused missing; selectable_region.dart:1987 includeSemantics:false). NO-CARET + SELECTION-STATE: expected `textSelection: collapsed(5)` after activation. SCROLL-NODE: node 2 has a hasImplicitScrolling child instead of being a single merged leaf.
- confidence: HIGH (probe P4 confirms focus moves but no semantic reflection).

## Test 076 — double tap selects word with semantics label
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: `controller.selection` read replaced with `onSelectionChanged` capture (WARRANTED, G-NO-CONTROLLER); added `await tester.pump()` for selectable registration and `pump()` → `pumpAndSettle()` after second tap (WARRANTED timing; no expectation affected); `const MaterialApp` → non-const because of the closure (COSMETIC). The expected value `TextSelection(baseOffset: 13, extentOffset: 23)` and the iOS/macOS variant are unchanged; the span still has `semanticsLabel: ''`, so the test still verifies that a span semantics label does not skew word offsets. The comparison ignores affinity/cause, but the original also compared only a TextSelection with default affinity, so nothing is weakened.
- part_a_evidence: 076.diff (`-expect(controller.selection, const TextSelection(baseOffset: 13, extentOffset: 23));` → `+expect(currentSelection, const TextSelection(baseOffset: 13, extentOffset: 23));`). Original+fix failed only at `find.byType(EditableText)` (failures_base_textoffsetfix_on_head/076_*.txt, frame at `WidgetController.widget`). No head failure file → passes on both variants. Head `onSelectionChanged` is built from SelectedContentRange (impl_head.dart `_handleSelectionDetailsChanged`).
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a. NOTE: the TODO directly above it (test_head.dart:3594, "Fails because SelectionArea/Semantics does not correctly handle double tap selection on spans with semantics labels") is STALE — the test passes; remove the TODO.
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: none
- confidence: HIGH (diff is small; expectation value identical).

## Group summary
- Tests: 11 (7 UNCHANGED, 4 MODIFIED). Passing at head: 1 (076). Failing: 10.
- Part A verdicts: WARRANTED 1 (076); PARTIAL 1 (058, warranted driver swap but relies on tap-caret); MIXED 2 (061, 063: warranted controller→onSelectionChanged swaps, but FAKE FIX removal of text-field value/flags/inputType, isFocused, moveCursor*/setSelection/copy actions, dropped collapsed-caret initial state; retained textSelection + setSelection asserts keep them failing); N/A 7.
- Part B: GAP 8 (041, 042, 043, 058, 060, 061, 063, 064); MIXED 2 (044, 062: inline-span recognizer semantics incl. isLink/tap/isHidden/showOnScreen are preserved; failures are inputType + extra scroll node; 062 also has a hardcoded-id surface issue 8→9); N/A 1 (076).
- NOT gaps (verified): recognizer span semantics (isLink, tap, isHidden, showOnScreen scrolling) and StringAttribute (spellOut/locale) propagation both survive via RenderParagraph; the outer `Semantics(label, excludeSemantics, onLongPress)` wrapper is retained; semantic longPress still moves focus.
- NEW gap ids (sub-items of G-SEMANTICS-TEXTFIELD), with exposing tests:
  - G-SEMANTICS-TEXTFIELD-IDENTITY — no isTextField/isReadOnly/isMultiline/inputType=text; text as label not value. [041,042,043,044,058,060,062,064; masked in 061,063]
  - G-SEMANTICS-FOCUS — no isFocusable/isFocused; focus changes invisible to a11y. [041,042,043,058,060,064; masked in 061,063]
  - G-SEMANTICS-SELECTION-STATE — no textSelection on any node. [061,063 (current failure point), 058,064]
  - G-SEMANTICS-SELECTION-ACTIONS — no setSelection / moveCursor*By{Character,Word}. [063 (setSelection→currentSelection asserts), 061, 058, 064]
  - G-SEMANTICS-COPY-ACTION — no SemanticsAction.copy on the text node when selected (only visual toolbar button). [masked in 061, 063]
  - G-SEMANTICS-SCROLL-NODE — extra hasImplicitScrolling node from the POC's SingleChildScrollView (EditableText excluded its Scrollable from semantics); shifts node ids. POC-fixable. [044,058,060,062,064; accepted in 061,063]
- Stale TODO: test_head.dart:3594 on test 076 claims it fails; it passes.
