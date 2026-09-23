# Group B_tap_longpress_mousedrag report

Common context. SR = packages/flutter/lib/src/widgets/selectable_region.dart. impl_head/impl_base = $S/impl_head.dart / $S/impl_base.dart.
- New selection read-out: `_SelectableTextState._handleSelectionDetailsChanged` (impl_head:505-521) converts `SelectionListenerNotifier.selection.range` to `TextSelection(start,end)` and always passes `cause: null` (517, 519). The `SelectionListener` exists only in the `SelectionArea` branch (impl_head:636-642). With `enableInteractiveSelection: false` the tree is `SelectionContainer.disabled` (644), so `onSelectionChanged` can never fire.
- Tap: `_handleMouseTapUp` (SR:936-962) calls `_collapseSelectionAt` (SR:956, SR:1503-1508) on Android/iOS/Fuchsia for touch as well as mouse. So a tap does produce a collapsed range at the tapped offset, and the collapsed-selection value survives the migration. No caret is painted, but no test in this group asserts that.
- Scratch probe (zz_scratch_B_test.dart, now deleted), 1 run, all probes executed:
  - B1 (disabled + long-press): no Copy, no Select all, no `_SelectionHandleOverlay`, no SelectableRegion. Passed.
  - B2: `hasAnyClients` stays false after a tap and after a long-press. Passed.
  - B3 (Android long-press hold): 0 FadeTransition and 0 handles during the hold; 3 FadeTransition and 2 handles after release.
  - B4: every `onSelectionChanged` callback has `cause == null`. Tap-to-collapse emits an intermediate `TextSelection(9,7)` before `collapsed(9)`. A mouse long-press emits `(5,9)` and then `collapsed(5)`.
  - B5 (`toolbarOptions: ToolbarOptions(selectAll: true)`): the toolbar shows `[Copy, Share, Select all]`.
- None of the base bodies of tests 15-26 asserted a `SelectionChangedCause`, so no cause expectation was dropped in this group. G-SELECTION-CAUSE is latent here (B4), not masked.

## Test 015 — Caret position is updated on tap
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details:
  - `tester.widget(find.byType(EditableText)).controller.selection` is replaced by a `selection` captured via `onSelectionChanged`.
  - The initial `baseOffset/extentOffset == -1` becomes `expect(selection, isNull)`: nothing has been selected yet, so this is equivalent.
  - An extra `pump()` was added so the selectables register.
  - The post-tap expectations are unchanged: `baseOffset == tapIndex` and `extentOffset == tapIndex` (4). `isNotNull` was added.
  - The tap steps are unchanged.
- part_a_evidence:
  - The original failed with `Bad state: No element` at the EditableText lookup (failures_base_textoffsetfix_on_head/015.txt, line 568).
  - A collapsed range at the tap point is produced by SR:956 → SR:1503-1508.
  - The value is identical to base (`expect(selection!.baseOffset, tapIndex); expect(selection!.extentOffset, tapIndex);`).
  - Caveat: the test name says "Caret", but it never asserted caret painting before or after the migration, so G-NO-CARET (no painted caret) is not masked by this edit.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: A collapsed selection at the tapped offset IS produced, which contradicts the taxonomy's "tap clears" wording for G-NO-CARET. Only the painted caret is missing, and this test never covered it.
- confidence: HIGH (the head test passes with the same numeric expectation).

## Test 016 — enableInteractiveSelection = false, tap
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: MIXED
- part_a_details:
  - (a) WARRANTED: the EditableText controller lookup was removed (it is unusable now), and a `pump()` was added.
  - (b) WEAKENED, but no gap is masked: `controller.selection == -1/-1` after the tap became `expect(currentSelection, null)`. That assertion is tautological. `onSelectionChanged` is only wired through the `SelectionListener` inside the `SelectionArea` branch (impl_head:636-642). With `enableInteractiveSelection: false` the child is `SelectionContainer.disabled` (impl_head:644), so the callback can never fire and the expectation cannot fail.
  - The behavior itself (no selection) is genuinely preserved. Scratch B1 shows there is no SelectableRegion, no toolbar and no handles.
- part_a_evidence:
  - Base: `expect(editableText.controller.selection.baseOffset, -1)` after tapping.
  - The original failed with `No element` (failures_base_textoffsetfix_on_head/016.txt).
  - Stronger replacement that passes: `expect(find.byType(SelectableRegion), findsNothing)`, plus no `_SelectionHandleOverlay` and no 'Copy'.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none (suggested hardening: assert `find.byType(SelectableRegion), findsNothing` and no handles/toolbar instead of relying on the callback)
- gap_ids: []
- gap_notes: none
- confidence: HIGH (the vacuity follows directly from the widget tree in impl_head:634-645; B1 was verified).

## Test 017 — enableInteractiveSelection = false, long-press
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: MIXED
- part_a_details: Same as 016.
  - The three base assertions after the long-press (`isCollapsed == true`, `base == -1`, `extent == -1`) collapsed into `expect(currentSelection, null)`. This is vacuous for the same reason: there is no SelectionListener under `SelectionContainer.disabled`.
  - The long-press steps are unchanged.
  - No behavioral gap is hidden. Scratch B1 ran exactly this gesture (2 s hold, then up) and found no toolbar, no handles and no SelectableRegion.
- part_a_evidence:
  - impl_head:636-645.
  - failures_base_textoffsetfix_on_head/017.txt: `Bad state: No element` at the EditableText lookup (line 604).
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none (same hardening as 016)
- gap_ids: []
- gap_notes: none
- confidence: HIGH

## Test 018 — Can long press to select
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details:
  - Controller reads were replaced by the `onSelectionChanged` capture.
  - The initial `isCollapsed` check became `isNull`.
  - After the long-press, `base 4 / extent 7` became `TextSelection(baseOffset: 4, extentOffset: 7)`: same values, and stronger because it compares the full object.
  - After tapping index 9, `isCollapsed && baseOffset == 9` became `TextSelection.collapsed(offset: 9)`: same, and stronger.
  - `pump()` → `pumpAndSettle()` after the long-press and the tap. This is harmless: selection is set synchronously in `_handleTouchLongPressStart` (SR:1007-1019), and the settle only runs overlay animations.
  - The gesture steps are unchanged.
- part_a_evidence:
  - The original failed with `No element` (failures_base_textoffsetfix_on_head/018.txt, line 623).
  - B4 confirms the sequence `(4,7)` → `(9,7)` → `collapsed(9)`. The intermediate `(9,7)` comes from `_collapseSelectionAt` doing `_selectStartTo` then `_selectEndTo` (SR:1503-1508). The test checks only the final value, which matches base.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: Observation, not asserted by this test: collapsing emits a transient non-collapsed selection to `onSelectionChanged` (B4), which the old controller never did. Cause is null (G-SELECTION-CAUSE latent; the base never asserted `SelectionChangedCause.longPress`).
- confidence: HIGH

## Test 019 — Slight movements in longpress don't hide/show handles
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: MIXED
- part_a_details:
  - (a) WARRANTED: an added `pump()` for registration.
  - (b) FAKE FIX: `variant: TargetPlatformVariant.only(TargetPlatform.iOS)` was added. The base ran on the default platform (Android) and asserted `findsNWidgets(2)` FadeTransitions (handles) with opacity 1.0 WHILE the long-press was still held.
  - The owner's own comment (test_head:700-707) states that Android now shows handles only on long-press end. Switching the platform hides that Android difference; the assertions themselves are unchanged.
- part_a_evidence:
  - The original, with the offset helper fixed, fails on Android with `Expected: exactly 2 matching candidates / Actual: Found 0 widgets with type "FadeTransition"` (failures_base_textoffsetfix_on_head/019.txt, line 655).
  - New behavior: `if (defaultTargetPlatform != TargetPlatform.android) { _showHandles(); }` in `_handleTouchLongPressStart` (SR:1014-1016). Android handles are shown only in `_handleTouchLongPressEnd` (SR:1027-1035).
  - Old behavior: `_shouldShowSelectionHandles` returns true for `SelectionChangedCause.longPress` on every platform (impl_base:643-660). `onSingleLongTapStart` selects the word with that cause on Android (widgets/text_selection.dart:2767-2772), so handles appeared during the hold.
  - Scratch B3 (Android): during the hold, fade=0 and handles=0; after up, fade=3 and handles=2.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: [G-HANDLES-VISIBILITY]
- gap_notes: G-HANDLES-VISIBILITY. On Android, the old SelectableText showed handles as soon as the long-press started. SelectableRegion defers them until long-press end (SR:1014-1016, 1032). The base assertion `expect(fadeFinder, findsNWidgets(2))` during the hold exposes this. Restricting the test to iOS masks it; an Android variant would fail.
- confidence: HIGH (the base-on-head failure and B3 both show 0 handles during the Android hold).

## Test 020 — Mouse long press is just like a tap
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details:
  - Controller reads were replaced by the callback capture.
  - `baseOffset == 5 && extentOffset == 5` became `TextSelection.collapsed(offset: 5)`: same value.
  - A `pump()` was added.
  - The gesture (mouse, 2 s hold, up, `pump`) is unchanged.
- part_a_evidence:
  - The original failed with `No element` (failures_base_textoffsetfix_on_head/020.txt, line 671).
  - A mouse is excluded from `LongPressGestureRecognizer.supportedDevices` (`_kLongPressSelectionDevices` = touch/stylus/invertedStylus, SR:44-48), so the release goes through `_handleMouseTapUp` → `_collapseSelectionAt` (SR:956).
  - B4 shows the final value `collapsed(5)`, preceded by a transient `(5,9)`: `_collapseSelectionAt` moves start to 5 while the end stays at the previous 9, and only `_selectEndTo` then collapses it. The test checks only the final value.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: none (cause is null but was never asserted in the base)
- confidence: HIGH

## Test 021 — selectable text basic
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: MIXED
- part_a_details:
  - (a) WEAKENED: `await tester.showKeyboard(find.byType(SelectableText));` was deleted. `showKeyboard` requires an EditableText descendant (flutter_test widget_tester.dart:1125-1131), so it cannot be kept. But the following `expect(tester.testTextInput.hasAnyClients, false)` is now checked without any attempt to open a keyboard, which makes it near-vacuous at that point. This masks no gap: scratch B2 shows `hasAnyClients` stays false after a real tap and a long-press, so the check could move after the tap.
  - (b) Dropped: the initial `expect(controller.selection.isCollapsed, true)`. This is minor, and the pre-tap state is not otherwise asserted.
  - (c) WARRANTED: `editableText.selectionOverlay!.handlesAreVisible, isFalse` became `find.byWidgetPredicate(runtimeType == '_SelectionHandleOverlay'), findsNothing`. The class exists (widgets/text_selection.dart:1984), and B3 confirms the finder does find handles when they are shown, so it is not vacuous. This has the same intent: no handles for a collapsed selection.
  - (d) STRENGTHENING: added `selection isNotNull && isCollapsed` after the tap.
  - (e) `pump()` → `pumpAndSettle()` after the long-press (toolbar animation), plus the registration pump. The Copy / no Paste / no Cut expectations are unchanged.
- part_a_evidence:
  - The original failed with `No element` at the EditableText lookup (failures_base_textoffsetfix_on_head/021.txt, line 688).
  - Deleted line: `await tester.showKeyboard(find.byType(SelectableText));`
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none (suggested hardening: repeat `expect(tester.testTextInput.hasAnyClients, false)` after the tap and after the long-press; B2 passes)
- gap_ids: []
- gap_notes: none
- confidence: HIGH

## Test 022 — selectable text can disable toolbar options
- status_at_head: FAILING
- change_status: MODIFIED
- part_a_verdict: PARTIAL
- part_a_details:
  - WARRANTED: a registration `pump()` was added, and `pump()` → `pumpAndSettle()` after `longPressAt` so the toolbar actually builds. The original with a single pump found neither Copy nor Select all (failures_base_textoffsetfix_on_head/022.txt: `Found 0 widgets with text "Select all"`, line 729).
  - The expectations are unchanged (no Copy, one Select all). An owner TODO documents the gap (test_head:804-805).
- part_a_evidence: The diff only touches pumps. The expectations are byte-identical to base.
- part_b_classification: GAP
- part_b_root_cause:
  - Immediate error: `Expected: no matching candidates / Actual: Found 1 widget with text "Copy"` at selectable_text_test.dart:823 (failures/022.txt).
  - Behind it: `SelectableText.toolbarOptions` (impl_head:360) is stored but never read.
    - The SelectionArea gets `contextMenuBuilder: _adaptContextMenuBuilder` (impl_head:640), which always returns `AdaptiveTextSelectionToolbar.selectableRegion(...)` with the default SelectableRegion buttons (impl_head:657-666). The user's `contextMenuBuilder` and `toolbarOptions` are both ignored.
    - Old: `toolbarOptions: widget.toolbarOptions` was forwarded to EditableText (impl_base:763), whose `copyEnabled` / `selectAllEnabled` honor it (widgets/editable_text.dart:2657-2675).
  - Scratch B5: the toolbar shows `[Copy, Share, Select all]`.
- part_b_surface_fix: none (no test-side change can make Copy disappear; it needs an implementation change that filters buttonItems by toolbarOptions)
- gap_ids: [G-TOOLBAR-OPTIONS]
- gap_notes: G-TOOLBAR-OPTIONS. The assertion `expect(find.text('Copy'), findsNothing)` exposes that `toolbarOptions(copy: false)` is not honored: `_adaptContextMenuBuilder` (impl_head:657-666) hardcodes the SelectableRegion default toolbar. Secondary: 'Share' appears, which the old toolbar did not show under these options.
- confidence: HIGH (the failure output plus B5).

## Test 023 — Can select text by dragging with a mouse
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details:
  - `const MaterialApp` → non-const, to allow the callback.
  - The controller was replaced by the callback capture.
  - A registration `pump()` was added.
  - `base 5 / extent 8` became `TextSelection(baseOffset: 5, extentOffset: 8)`: same offsets.
  - Drag positions (5 → 8), the pointer kind (mouse) and the pump/move/up sequence are unchanged.
- part_a_evidence:
  - The original failed with `No element` (failures_base_textoffsetfix_on_head/023.txt, line 740).
  - The mouse drag is handled by `TapAndPanGestureRecognizer` `onDragStart/onDragUpdate/onDragEnd` (SR:715-719).
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: none
- confidence: HIGH

## Test 024 — Continuous dragging does not cause flickering
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details:
  - The change counter moved from `controller.addListener` to an increment inside `onSelectionChanged`.
  - The count expectations are unchanged: `isNonZero` after the first drag, `0` after the 4 px move, `1` after moving to 'h' and releasing.
  - The offsets are unchanged: `(2,8)` then `(2,9)`, now compared as full `TextSelection`s.
  - The steps and pumps are unchanged, apart from the registration pump.
  - The counter's source is arguably equivalent. The old controller listener fired on any TextEditingValue change; the new one fires once per SelectionListenerNotifier change. The "no flicker" `0` and exact `1` checks keep their strength and still pass.
- part_a_evidence:
  - The original failed with `No element` (failures_base_textoffsetfix_on_head/024.txt, line 769).
  - impl_head:505-521 forwards every notifier change.
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: none
- confidence: HIGH

## Test 025 — Dragging in opposite direction also works
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details: Same pattern as 023. The expected `base 8 / extent 5` became `TextSelection(baseOffset: 8, extentOffset: 5)`: the same values and the same direction. `SelectedContentRange` start/end preserve directionality, as mapped at impl_head:512-515. The steps are unchanged.
- part_a_evidence: The original failed with `No element` (failures_base_textoffsetfix_on_head/025.txt, line 817).
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: none
- confidence: HIGH

## Test 026 — Slow mouse dragging also selects text
- status_at_head: PASSING
- change_status: MODIFIED
- part_a_verdict: WARRANTED
- part_a_details:
  - Same pattern as 023; the expected `(5,8)` is unchanged.
  - Also added: `await tester.pumpAndSettle()` after `gesture.up()`. The base read the controller synchronously without a pump. This is harmless: selection is updated during `onDragUpdate`, and the extra settle neither changes the gesture nor weakens the assertion.
  - The 2 s hold with a mouse is kept. It still does not trigger a long-press because mouse is not in `_kLongPressSelectionDevices` (SR:44-48), which matches the old behavior.
- part_a_evidence: The original failed with `No element` (failures_base_textoffsetfix_on_head/026.txt, line 842).
- part_b_classification: N/A (passing)
- part_b_root_cause: n/a
- part_b_surface_fix: none
- gap_ids: []
- gap_notes: none
- confidence: HIGH

## Group summary
- WARRANTED: 7 (015, 018, 020, 023, 024, 025, 026)
- MIXED: 4
  - 016, 017: finder swap warranted, but the new `currentSelection == null` assertion is vacuous. No gap is masked.
  - 019: the pump is warranted, but the iOS-only variant is a FAKE FIX masking G-HANDLES-VISIBILITY on Android.
  - 021: the `showKeyboard` removal leaves the `hasAnyClients` check near-vacuous (no gap masked); the handle-finder swap is warranted and new assertions were added.
- PARTIAL (still failing): 1 (022). Pump edits are warranted; Part B = GAP [G-TOOLBAR-OPTIONS].
- FAKE FIX (pure): 0
- Gaps found: G-HANDLES-VISIBILITY (019, masked); G-TOOLBAR-OPTIONS (022, exposed).
- Gap latent but not asserted in this group: G-SELECTION-CAUSE (cause is always null, B4; no base test here asserted a cause).
- No expected offsets, gesture steps or cause expectations were changed in the mouse-drag tests (023-026) or in the tap/long-press value tests (015, 018, 020).
- NEW gap id proposed: G-OTHER-TRANSIENT-SELECTION-NOTIFICATIONS. Collapsing a selection via tap or mouse release calls `_selectStartTo` then `_selectEndTo` (SR:1503-1508). `onSelectionChanged` therefore receives an intermediate non-collapsed selection (e.g. `(9,7)` before `collapsed(9)`, and `(5,9)` before `collapsed(5)`), where the old controller emitted a single collapsed value. No test in this group asserts it.
- Taxonomy note: G-NO-CARET's "a tap does not place a collapsed selection" is inaccurate for Android/iOS touch taps. `_handleMouseTapUp` (SR:956) collapses at the tapped offset and `onSelectionChanged` reports `collapsed(offset)`. Only the painted caret is absent.
