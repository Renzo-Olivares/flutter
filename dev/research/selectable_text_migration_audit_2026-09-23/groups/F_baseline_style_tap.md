# Group F_baseline_style_tap report

Probe evidence below ("PROBE") comes from a scratch test (zz_scratch_F_test.dart, now deleted) that ran the head test steps on the head implementation and printed `onSelectionChanged` values plus toolbar button counts/labels, instead of asserting.

Key implementation facts cited throughout:
- Head `_SelectableTextState._handleSelectionDetailsChanged` (impl_head / impl.diff) builds `TextSelection(baseOffset: range.startOffset, extentOffset: range.endOffset)`, so affinity is always `downstream` and cause is always null. `SelectedContentRange` has no affinity field.
- SelectableRegion DOES produce a collapsed selection on a single tap. `_collapseSelectionAt` (selectable_region.dart:1503) is called on tap-down on desktop (selectable_region.dart:767) and on tap-up on mobile (selectable_region.dart:956). It lands on the precise tapped offset on every platform, iOS included. With a collapsed range N..N, `onSelectionChanged` reports `collapsed(N)`, so "tap clears" is not what happens. What is missing is iOS word-edge snapping and affinity. No caret is painted.
- Old iOS touch single tap on SelectableText: `renderEditable.selectWordEdge` (widgets/text_selection.dart:2696). Other platforms: `selectPosition` (text_selection.dart:2623/2631, desktop on tap down).
- Old double tap: `onDoubleTapDown` → `selectWord` + `editableText.showToolbar()` on every platform, on tap DOWN (text_selection.dart:2938-2944).
- New double tap: `_selectWordAt` on the 2nd tap-down (selectable_region.dart:770-790). The toolbar is shown only on the 2nd tap-UP, only for Android/iOS with a non-precise pointer, and never on macOS/linux/windows (selectable_region.dart:963-990).
- The new iOS toolbar is `AdaptiveTextSelectionToolbar.selectableRegion` (head `_adaptContextMenuBuilder`). It shows [Copy, Select All]. The old read-only EditableText toolbar showed [Copy, Look Up, Search Web, Share...] (test helper `expectCupertinoSelectionToolbar`, test_head.dart:166-183).

## Test 056 — SelectableText baseline alignment no-strut
- status_at_head: FAILING
- change_status: MODIFIED
- part_a_verdict: COSMETIC
- part_a_details: Adds `await tester.pump(); // Allow nested selection containers to register.` and a TODO comment. It changes no expectation and has no semantic effect on a layout test (the failure is identical with or without it).
- part_a_evidence: 056.diff: only `+ await tester.pump();` and `+ // TODO(Renzo-Olivares): Fails because ... SingleChildScrollView internally, which blocks baseline propagation`. failures_base_overlayfix_on_head/056.txt fails the same way as head.
- part_b_classification: GAP
- part_b_root_cause: `Expected: <310.0> Actual: <299.0>` at the first expect (keyA bottom). `_RenderSingleChildViewport` intentionally does not override `computeDistanceToActualBaseline`/`computeDryBaseline` (widgets/single_child_scroll_view.dart:482-485: "We don't override computeDistanceToActualBaseline(), because we want the default behavior (returning null)"). The SelectableText subtree therefore reports a null baseline, and Row(crossAxisAlignment: baseline) top-aligns it. PROBE dry-baseline chain: `RenderParagraph:9.65 > RenderMouseRegion:9.65 > _RenderSingleChildViewport:null > RenderIgnorePointer:null > ... > RenderSemanticsAnnotations:null`. The old EditableText did not use a viewport render object: RenderEditable applies the scroll offset itself (editable_text.dart:5934 `viewportBuilder` → `_Editable`) and returns `_textPainter.computeDistanceToActualBaseline` (rendering/editable.dart:1978-1981), which proxy boxes propagated (proxy_box.dart:97-99). SelectionArea and the proxies are not the blocker. The viewport is.
- part_b_surface_fix: none. It needs an impl change, e.g. a baseline-forwarding render object around the SingleChildScrollView, or a viewport that reports child baseline minus scroll offset.
- gap_ids: [G-LAYOUT-SIZE]
- gap_notes: G-LAYOUT-SIZE (baseline propagation through scroll view). The failing assertion is `expect(tester.getBottomLeft(find.byKey(keyA)).dy, rowBottomY - 5.0)`. A SelectableText in a baseline-aligned Row no longer baseline-aligns. This is user-visible.
- confidence: HIGH (probe confirmed that the null baseline starts exactly at _RenderSingleChildViewport)

## Test 057 — SelectableText baseline alignment
- status_at_head: FAILING
- change_status: MODIFIED
- part_a_verdict: COSMETIC
- part_a_details: Same as 056: an extra `pump()` and a TODO comment. No expectation changed.
- part_a_evidence: 057.diff; failures_base_overlayfix_on_head/057.txt fails the same way.
- part_b_classification: GAP
- part_b_root_cause: `Expected: <310.0> Actual: <295.0>` at the keyA expect (test line 2359). The cause is the same as 056: `_RenderSingleChildViewport` returns a null baseline (single_child_scroll_view.dart:482). The actual value differs from 056 (295 vs 299) only because this variant uses the default strut. The old implementation passed `strutStyle ?? const StrutStyle()`; the head passes `widget.strutStyle` (null) to Text, which changes the box height, but the underlying cause is the same.
- part_b_surface_fix: none
- gap_ids: [G-LAYOUT-SIZE]
- gap_notes: G-LAYOUT-SIZE (baseline through scroll view); same assertion as 056. Secondary note: the head no longer defaults `strutStyle` to `const StrutStyle()` (impl.diff: old `strutStyle: widget.strutStyle ?? const StrutStyle()`, new `strutStyle: widget.strutStyle`). That can change line height and ties into the strut-test gaps owned by another group.
- confidence: HIGH

## Test 066 — SelectableText style is merged with default text style
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: Three `tester.widget<EditableText>(find.byType(EditableText)).style.X` reads become `tester.widget<RichText>(find.descendant(of: SelectableText, matching: RichText)).text.style!.X`, each after an extra `pump()`. All expected values are unchanged: defaultStyle color, background, shadows, decoration, locale and wordSpacing; `setColor`; and `isNull` for inherit:false. The rendered style is still asserted. Caveat: the test is now less able to catch a regression in SelectableText's own merge. `Text.build` re-merges `DefaultTextStyle.of(context)` whenever `style.inherit` is true (widgets/text.dart:718-720), so if SelectableText stopped merging (the #23994 regression), the RichText style would still pick up defaultStyle. The inherit:false branch still discriminates. The user-visible behavior (the style the text paints with) is still verified, so this counts as warranted, not fake.
- part_a_evidence: failures_base_textoffsetfix_on_head/066.txt: `Bad state: No element` at `tester.widget(find.byType(EditableText))`, a pure stale finder. Head merge code: `effectiveTextStyle = defaultTextStyle.style.merge(widget.style ?? widget.textSpan?.style)` (impl.diff) is passed to `Text(style: effectiveTextStyle)`.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: none
- confidence: HIGH

## Test 068 — tap moves cursor to the edge of the word it tapped
- status_at_head: FAILING (variants: iOS)
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: `controller.selection` is replaced by `latestSelection` captured from `onSelectionChanged`; `expect(latestSelection, isNotNull)` and a registration `pump()` are added. The expected value `TextSelection.collapsed(offset: 7, affinity: upstream)` and the "no CupertinoButton" check are kept. This is warranted: `onSelectionChanged` is the public substitute for the controller. The original intent (word-edge snapping) is kept and still fails.
- part_a_evidence: The original failed with `Bad state: No element` at the EditableText finder (failures_base_textoffsetfix_on_head/068_TargetPlatform.iOS.txt).
- part_b_classification: GAP
- part_b_root_cause: `Expected: collapsed(offset: 7, upstream) Actual: collapsed(offset: 4, downstream)`. SelectableRegion's mobile tap-up calls `_collapseSelectionAt(details.globalPosition)` (selectable_region.dart:950-957), which collapses at the precise hit offset on iOS too. The old builder called `renderEditable.selectWordEdge` for iOS touch taps (text_selection.dart:2696), which snaps to the nearest word boundary (7, the end of "Atwater"). Affinity also differs, because the head builds the TextSelection without affinity.
- part_b_surface_fix: none
- gap_ids: [G-TAP-GESTURES, G-NO-AFFINITY]
- gap_notes: G-TAP-GESTURES: the iOS single tap does not snap to the word edge (offset 4 vs 7). G-NO-AFFINITY: `affinity: upstream` cannot be reported, because SelectedContentRange has no affinity and the head `_handleSelectionDetailsChanged` hard-codes the default downstream. Note that a collapsed selection IS reported, so this is not "tap clears" (G-NO-CARET applies only in the sense that nothing is painted).
- confidence: HIGH (PROBE: the iOS tap at +50 gives collapsed(4, downstream))

## Test 069 — tap moves cursor to the position tapped (Android)
- status_at_head: FAILING (variants: android, fuchsia, linux, macOS, windows)
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: Same warranted adaptation as 068 (controller replaced by `onSelectionChanged`). The expectation `collapsed(offset: 4, affinity: upstream)` and the "no TextButton" check are unchanged.
- part_a_evidence: The original failed on the EditableText finder (failures_base_textoffsetfix_on_head/069_*.txt).
- part_b_classification: GAP
- part_b_root_cause: On every variant: `Expected: collapsed(offset: 4, upstream) Actual: collapsed(offset: 4, downstream)`. The offset is correct. The only mismatch is affinity. The head `_handleSelectionDetailsChanged` constructs `TextSelection(baseOffset:, extentOffset:)` with the default downstream affinity, and SelectedContentRange carries no affinity to forward.
- part_b_surface_fix: none in the test without weakening it. Dropping `affinity: TextAffinity.upstream` would make it pass, but that would be a fake fix that hides G-NO-AFFINITY.
- gap_ids: [G-NO-AFFINITY]
- gap_notes: G-NO-AFFINITY: the assertion is `expect(latestSelection, const TextSelection.collapsed(offset: 4, affinity: TextAffinity.upstream))`. The tap-position behavior itself matches (desktop collapses on tap-down at selectable_region.dart:767, Android on tap-up at :956).
- confidence: HIGH (failure output plus PROBE)

## Test 070 — two slow taps do not trigger a word selection on iOS
- status_at_head: FAILING (variants: iOS)
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: Same warranted controller→`onSelectionChanged` swap. The expectation `collapsed(7, upstream)` and the "no CupertinoButton" check are unchanged.
- part_a_evidence: The original failed on the EditableText finder (failures_base_textoffsetfix_on_head/070_TargetPlatform.iOS.txt).
- part_b_classification: GAP
- part_b_root_cause: `Expected: collapsed(7, upstream) Actual: collapsed(4, downstream)`. The cause is the same as 068: iOS tap-up collapses at the precise offset (selectable_region.dart:956), with no `selectWordEdge`. The test's actual subject, "slow taps don't select a word", does hold: PROBE shows a single collapsed(4) with no word selection and no CupertinoButton. So only the word-edge rule and affinity fail.
- part_b_surface_fix: none
- gap_ids: [G-TAP-GESTURES, G-NO-AFFINITY]
- gap_notes: G-TAP-GESTURES: iOS word-edge snapping is missing (4 vs 7). G-NO-AFFINITY: upstream is not reportable.
- confidence: HIGH

## Test 071 — two slow taps do not trigger a word selection
- status_at_head: FAILING (variants: android, fuchsia, linux, macOS, windows)
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: Warranted controller swap; the expectation `collapsed(4, upstream)` and the "no CupertinoButton" check are unchanged.
- part_a_evidence: The original failed on the EditableText finder.
- part_b_classification: GAP
- part_b_root_cause: On every variant only the affinity differs: `Expected: collapsed(4, upstream) Actual: collapsed(4, downstream)`. No word selection happens (PROBE). On linux the log shows `collapsed(4)`, then `TextSelection.invalid`, then `collapsed(4)`: the desktop tap-down calls `clearSelection()` before `_collapseSelectionAt` (selectable_region.dart:766-767), and the head maps a null range to `collapsed(offset: -1)`. That transient clear notification did not happen with the old controller.
- part_b_surface_fix: none (dropping affinity would be a fake fix)
- gap_ids: [G-NO-AFFINITY, G-SELECTION-CAUSE]
- gap_notes: G-NO-AFFINITY: the failing assertion is the upstream affinity. G-SELECTION-CAUSE (secondary, not asserted): desktop taps emit a spurious `collapsed(-1)`/invalid selection between taps.
- confidence: HIGH

## Test 072 — double tap selects word and first tap of double tap moves cursor
- status_at_head: FAILING (variants: iOS, macOS)
- change_status: MODIFIED
- part_a_verdict: MIXED
- part_a_details: (1) WARRANTED: `controller.selection` is replaced by `latestSelection`, `isNotNull` and a registration `pump()` are added, and the expectations `collapsed(iOS ? 12 : 11, upstream)` and `TextSelection(8, 12)` are unchanged. (2) FAKE FIX: the final `expectCupertinoSelectionToolbar();` becomes `if (iOS) expectCupertinoSelectionToolbar(); else expect(find.byType(CupertinoButton), findsNothing);`. The original required a 1-button Copy toolbar on macOS after a touch double tap; the head now asserts the ABSENCE of a toolbar on macOS. That hides G-TOOLBAR-PLATFORM: SelectableRegion never shows a toolbar on a macOS double tap (selectable_region.dart:983-987, "The selection overlay is not shown on desktop platforms on a double click"), while the old `onDoubleTapDown` always called `showToolbar()` (text_selection.dart:2938-2944). The macOS variant currently fails earlier (affinity), so this change is dormant, but it would make the test pass once affinity is solved.
- part_a_evidence: 072.diff lines `+ if (defaultTargetPlatform == TargetPlatform.iOS) { expectCupertinoSelectionToolbar(); } else { expect(find.byType(CupertinoButton), findsNothing); }`. The original failed on the EditableText finder (failures_base_textoffsetfix_on_head/072_TargetPlatform.macOS.txt `Bad state: No element`). PROBE macOS after double tap: `TextSelection(8,12) Cupertino=0`.
- part_b_classification: GAP
- part_b_root_cause: iOS: `Expected collapsed(12, upstream) Actual collapsed(11, downstream)`, because the first tap is not snapped to the word edge (selectable_region.dart:956 vs text_selection.dart:2696). macOS: `Expected collapsed(11, upstream) Actual collapsed(11, downstream)`, affinity only. Past those assertions (PROBE): the double tap selects (8,12) correctly on both platforms. The iOS toolbar would then fail: 2 CupertinoButtons [Copy, Select All] instead of 4 [Copy, Look Up, Search Web, Share...]. macOS shows no toolbar.
- part_b_surface_fix: none
- gap_ids: [G-TAP-GESTURES, G-NO-AFFINITY, G-TOOLBAR-PLATFORM]
- gap_notes: G-TAP-GESTURES: no iOS word-edge snap on the first tap (11 vs 12). G-NO-AFFINITY: upstream. G-TOOLBAR-PLATFORM: iOS toolbar buttons differ (`expectCupertinoSelectionToolbar` → `findsNWidgets(4)` would see 2; see the helper TODO in helpers_and_preamble.diff), and macOS shows no toolbar on a touch double tap, which the head masks.
- confidence: HIGH (PROBE covers all three stages)

## Test 073 — double tap selects word and first tap of double tap moves cursor and shows toolbar (Android)
- status_at_head: FAILING
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details: Warranted controller swap only. `collapsed(11, upstream)`, `TextSelection(8,12)` and `expectMaterialSelectionToolbar()` are all kept.
- part_a_evidence: The original failed on the EditableText finder (failures_base_textoffsetfix_on_head/073.txt).
- part_b_classification: GAP
- part_b_root_cause: The failure is neither the word selection nor the toolbar. It is the FIRST-tap affinity (test line 3484): `Expected collapsed(11, upstream) Actual collapsed(11, downstream)`. PROBE (Android) past that point: the double tap gives `TextSelection(8,12)` and the toolbar has 3 TextButtons [Copy, Share, Select all]. Both later assertions would therefore pass. The toolbar appears on the 2nd tap-up (selectable_region.dart:969-975) rather than tap-down, which does not matter after `pump()`.
- part_b_surface_fix: none (the only failing piece is affinity, and removing it would be a fake fix)
- gap_ids: [G-NO-AFFINITY]
- gap_notes: G-NO-AFFINITY: `expect(latestSelection, const TextSelection.collapsed(offset: 11, affinity: TextAffinity.upstream))`.
- confidence: HIGH (PROBE)

## Test 074 — double tap on top of cursor also selects word (Android)
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: The "cursor" premise was NOT dropped. The head still asserts `collapsed(offset: 3)` after the first tap and again after the first tap of the double tap, then `TextSelection(0, 7)`, then `expectMaterialSelectionToolbar()`. All values are identical to the base. Changes: controller → `latestSelection`; `textOffsetToPosition(tester, index)` → `textOffsetToPosition(tester, index, ancestor: find.byType(SelectableText))` (the helper is now RenderParagraph-based, helpers_and_preamble.diff); and a registration `pump()`. The test passes because SelectableRegion really does collapse the selection at the tapped offset (selectable_region.dart:956), and the base expectation used default (downstream) affinity, so G-NO-AFFINITY does not bite. Two limits apply. First, "cursor" here means a collapsed selection range, with no painted caret; the test never checked painting, so nothing is lost. Second, the middle assertion "first tap doesn't change the selection" is weak in both versions: `latestSelection` only updates on change, so it cannot tell "unchanged" from "not notified". The base controller check had the same effective strength for an unchanged value, so the weakness is inherited, not introduced.
- part_a_evidence: The original failed only on the finder: failures_base_textoffsetfix_on_head/074.txt `Bad state: No element` at `tester.widget(find.byType(EditableText).first)`. 074.diff shows no expectation value changes.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: none
- confidence: HIGH

## Test 075 — double tap hold selects word
- status_at_head: FAILING (variants: iOS)
- change_status: MODIFIED
- part_a_verdict: MIXED
- part_a_details: (1) WARRANTED: controller → `latestSelection`, plus a `pump()`; `TextSelection(8,12)` is kept both during the hold and after release. (2) FAKE FIX (assertion deleted): the `expectCupertinoSelectionToolbar();` DURING the hold (before `gesture.up()`) was removed. PROBE shows that no toolbar exists during the hold on iOS or macOS (`during hold: Cupertino=0`). SelectableRegion shows the toolbar only on the 2nd tap-UP (selectable_region.dart:976-982), whereas the old builder showed it on double-tap DOWN (text_selection.dart:2938-2944). The deletion therefore hides a toolbar-timing gap. (3) FAKE FIX (platform expectation flipped): the post-release toolbar check becomes `findsNothing` on macOS instead of a 1-button Copy toolbar. This hides that macOS never shows a toolbar on a touch double tap (selectable_region.dart:983-987). This is why the packet shows macOS FAILING in the orig+overlay run but PASSING at head.
- part_a_evidence: 075.diff `- expect(controller.selection, ...8,12); - expectCupertinoSelectionToolbar();` (mid-hold) and `+ if (defaultTargetPlatform == TargetPlatform.iOS) {...} else { expect(find.byType(CupertinoButton), findsNothing); }`. The original on the new impl failed first on the EditableText finder for both variants (failures_base_textoffsetfix_on_head/075_*.txt).
- part_b_classification: GAP
- part_b_root_cause: iOS fails at the post-release `expectCupertinoSelectionToolbar()` (test line 3583, helper line 174): `Expected: exactly 4 matching candidates Actual: Found 2 widgets with type "CupertinoButton"`. PROBE labels are [Copy, Select All]. The head `_adaptContextMenuBuilder` always returns `AdaptiveTextSelectionToolbar.selectableRegion`, whose buttons come from SelectableRegionState (Copy, Select All; no Look Up / Search Web / Share). The old read-only EditableText toolbar had Copy, Look Up, Search Web, Share. The platform split exists because the head deliberately replaced the macOS toolbar assertion with `findsNothing`, which passes because macOS shows no toolbar. The selection (8,12) is correct on both platforms.
- part_b_surface_fix: none
- gap_ids: [G-TOOLBAR-PLATFORM]
- gap_notes: G-TOOLBAR-PLATFORM: (a) the iOS toolbar button set differs (4 → 2; exposed by `findsNWidgets(4)` in `expectCupertinoSelectionToolbar`); (b) macOS shows no toolbar after a touch double tap (masked by the head's `findsNothing`); (c) the toolbar is not shown during the double-tap hold on iOS or macOS (masked by deleting the mid-hold assertion). Consider a sub-id G-TOOLBAR-PLATFORM/timing for (c).
- confidence: HIGH (PROBE during-hold and after-up counts on both platforms)

## Group summary
- Part A verdicts: COSMETIC 2 (056, 057); WARRANTED 2 (066, 074); PARTIAL 5 (068, 069, 070, 071, 073; edits warranted, still failing on real gaps); MIXED 2 (072: macOS toolbar flipped to findsNothing, currently dormant; 075: mid-hold toolbar assertion deleted and macOS toolbar flipped to findsNothing). FAKE FIX pieces all mask G-TOOLBAR-PLATFORM.
- Part B (9 failing): GAP 9, SURFACE 0.
- Headline: 4 of the 7 failing tap tests (069, 071, 073, and the macOS variant of 072) fail ONLY on `affinity: TextAffinity.upstream` (G-NO-AFFINITY). The offsets, word selection and (Android) toolbar all match. SelectableRegion does produce a collapsed selection at the tapped offset, so G-NO-CARET ("tap clears") is not the mechanism in these tests. The real tap difference is that iOS does not snap to the word edge (068, 070, 072-iOS).
- Correction/refinement to the taxonomy: G-LAYOUT-SIZE's baseline sub-issue comes specifically from `_RenderSingleChildViewport` returning a null baseline (single_child_scroll_view.dart:482), not from SelectionArea or ConstrainedBox. Every render object above RenderParagraph up to the viewport's child forwards the baseline.
- No new gap ids introduced. A suggested refinement is G-TOOLBAR-PLATFORM (timing): the toolbar is shown on double-tap-up instead of double-tap-down, so none is visible during a double-tap hold.
