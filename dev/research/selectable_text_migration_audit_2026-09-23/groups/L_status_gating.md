# L — Gating `SelectableText.onSelectionChanged` on `SelectableRegionSelectionStatus`

Worktree: `$S/wt-status` (detached at `ece56299239`, left in place). All runs used the main tool
(`/Users/roliv/flutter/bin/flutter test --no-pub`) from `$S/wt-status/packages/flutter`.
`$S` = `/private/tmp/claude-501/-Users-roliv-flutter/727bb496-578a-49a2-b6c9-df33a85675f3/scratchpad`.

Artifacts
- `$S/status_gating.patch`: the recommended lib change (selectable_text.dart only, no framework change).
- `$S/status_gating_tests.patch`: restored invariants in 052 and 123, plus `pump()` in 125.
- `$S/status_gating_finalized_only_variant.patch`: the owner's literal hypothesis (report only on `finalized`), for comparison.
- `$S/status_gating_ios_finalize_fix.patch`: a one-line framework fix, needed only by the finalized-only variant (see §1 and §6).
- `$S/l_status_probe_test.dart` (also at `wt-status/packages/flutter/test/material/zz_status_probe_test.dart`): a probe that logs callbacks (`CB…[status at callback]`) interleaved with status notifications (`ST:…`) across all paths. Logs: `$S/l_probe_{gate,fin,any,micro,final}.log`.
- Full-suite logs: `$S/l_suite_any.log` (recommended variant) and `$S/l_suite_fin.log` (finalized-only variant). Diff script: `$S/l_diff.py`. Failure-reason comparison: `$S/l_cmp_reasons.py`.

## TL;DR
- **Gating on the current status value at notification time cannot work.** Every noisy intermediate notification fires while the status still holds the *stale* `finalized` from the previous gesture (or the initial default, which is `finalized`). The notifier moves to `changing` only *after* the handler has applied its selection events. So the gate lets all the noise through. It also drops real updates: mid-drag updates fire under `changing`, and no selection notification follows the final `finalized`. Measured: 052/122/123/125 still fail, and 024 newly fails.
- **Reporting on the status transition works, and the best trigger is every status notification (with dedupe), not only `finalized`.** Every SelectableRegion gesture and keyboard handler sets `changing` (or `changing`+`finalized`) synchronously at the end of the step, *after* its edge updates. The latest selection read at that moment is therefore the committed value for the step. Reporting then gives exactly one callback per user step, synchronously, at the same moment the old EditableText fired (tap-down on desktop, long-press start, each drag update).
- **Reporting only on `finalized` (the literal hypothesis) fixes the same four tests but regresses 6 tests and makes 7 already-failing tests fail earlier.** It delays callbacks to gesture end: nothing arrives during drags, long-press holds or double-tap holds. It also never reports the iOS double-tap word selection, because `_handleMouseTapUp`'s iOS "tap on active selection" early return skips `_finalizeSelectableRegionStatus()`, so the status stays `changing` (a framework bug).
- Recommended variant, full suite: **3 newly passing entries (122 android, 122 fuchsia, 125), 0 newly failing.** 052 and 123 pass with their once-per-change assertions restored. No still-failing test changed its failure reason.

## 1. Status transition map (selectable_region.dart at HEAD)

Note: `_finalizeSelection()` (:1568) only stops continuous edge updates and **never touches the status**. The status becomes `finalized` only in `_finalizeSelectableRegionStatus()` (:594-600), which is a no-op unless the value is `changing`. The notifier's setter notifies even when the value does not change (:3499-3508). The initial value is `finalized` (:3481).

Order legend: `E` = selection edge/event dispatch (each dispatch notifies SelectionListener synchronously), `C` = `value = changing`, `F` = `_finalizeSelectableRegionStatus()`. "Stale F" = the value is still `finalized` from the previous gesture when `E` fires.

| Path | Handler (line) | Order within the handler | Status seen by the E notifications | When `finalized` arrives |
|---|---|---|---|---|
| Touch tap (android/fuchsia/iOS), 1st tap | `_startNewMouseSelectionGesture` count 1 (:748) does nothing on mobile; `_handleMouseTapUp` (:936) | tap-up: `_collapseSelectionAt` = `_finalizeSelection(); E(start); E(end)` (:1503-1508) → C (:957) → F (:992) | stale F. Emits `(newStart, oldEnd)` then `collapsed` when a selection exists | same call stack (tap-up) |
| iOS tap on active selection | `_handleMouseTapUp` early return (:937-948) | toolbar toggle only, no E, no C/F | n/a | n/a (no change) |
| Desktop click (mac/linux/windows) | tap-down (:752-768) | `clearSelection()` = E(clear) → `_collapseSelectionAt` E,E → C | stale F. Emits `invalid`, then (possibly) `(newStart, oldEnd)`, then `collapsed` | **next pointer event**: tap-up F (:992), or drag-end F (:933) if it becomes a drag |
| Desktop shift+click | tap-down (:759-765) | E(end) → C | stale F | tap-up |
| Double tap/click (count 2) | tap-down (:770-790) | `_selectWordAt` = `_finalizeSelection(); E(word)` → C | stale F (the previous tap already finalized) | 2nd tap-up F, **except iOS touch when the 2nd tap-up lands on the new selection: early return at :937-948 skips F, so the status stays `changing` until the next gesture** |
| Triple click (count 3) | tap-down (:792-807) | E(paragraph) → C | stale F | tap-up |
| Mouse long press | same as desktop click (TapAndPan recognizer; LongPress recognizer excludes mouse) | tap-down E… → C; up after the hold | stale F | tap-up (after the hold) |
| Touch long press start | `_handleTouchLongPressStart` (:1007) | E(word) → C | stale F | `_handleTouchLongPressEnd` F (:1030), at lift |
| Touch long press move | (:1021) | E(end, word) → C | `changing` | at lift |
| Mouse drag start/update | (:812, :825) | start: E(start, continuous) → C; update: E(end, continuous) → C | `changing` (tap-down set it) | drag end F (:933). Continuous edge updates rescheduled post-frame while pending (:1127-1135) also fire under `changing` |
| Handle drag start/update/end | (:1206/:1219, :1235/:1247), `_onAnyDragEnd` (:1142) | start: no E, no C; update: E → C (:1232/:1260); end: F (:1152) | stale F on the first update, then `changing` | drag end |
| Shift+arrow, ctrl+shift+arrow | `_granularlyExtendSelection` (:1640) | E → C → F (:1653-1654). Early return with no E when there is no selection | stale F | same call stack |
| Shift+up/down | `_directionallyExtendSelection` (:1659) | E → C → F (:1682-1683) | stale F | same call stack |
| Select all (keyboard / toolbar / programmatic `selectAll()`) | `selectAll` (:1850), `_SelectAllAction` (:2015) | `clearSelection()` E(clear) → E(selectAll) → C → F (:1858-1859) | stale F. Emits `invalid` then `(0,len)` | same call stack |
| Copy/Share on Android (toolbar) | (:1713-1716, :1744-1747) | clearSelection E → C → F | stale F | same call stack |
| Right-click (android/fuchsia/windows off-selection, linux off-selection) | `_handleRightClickDown` (:1048) | `_collapseSelectionAt` E,E → C → F (:1094-1095) | stale F. Emits `(newStart, oldEnd)` then `collapsed` | same call stack |
| Right-click iOS/macOS | same | `_selectWordAt` E → C → F | stale F | same call stack |
| Right-click on active selection (android/windows) / toolbar hide (mac/linux) | early returns (:1069, :1077, :1083) | no E, no C/F | n/a | n/a |
| Focus loss (lifecycle `resumed`) | `_handleFocusChanged` (:527) | `clearSelection()` E → C → F (:541-543) | stale F | same call stack |
| Focus loss (lifecycle not resumed) | same | no clear (by design) | n/a | n/a |
| Tap outside | TapRegion `onTapOutside` (:1967) unfocuses **only on web**. Elsewhere the selection clears only through focus loss (for example tapping another SelectableText) | as focus loss | as focus loss | as focus loss |
| Programmatic `clearSelection()` | (:1574) | E(clear), **no status notification at all** | stale F | **never** |
| Gesture cancel | `onCancel = clearSelection` (:670, :719) | E(clear), no status notification | whatever the value was (can be `changing` after a desktop tap-down) | **never**; the status can stay `changing` |

Answers to (a) and (b):
- (a) Not every path ends in `finalized`. Taps, keyboard, select-all, right-click and focus loss finalize in the same call stack. Desktop tap-down and drag/long-press/handle gestures finalize at the next pointer event (tap-up, drag end, long-press end). Programmatic `clearSelection()` and gesture cancel never notify the status. The iOS touch double tap whose 2nd tap-up lands on the new word leaves the status at `changing` (framework bug; probe + test "double tap selects word with semantics label (iOS)").
- (b) In `_collapseSelectionAt`, `_finalizeSelection()` does not touch the status. Both intermediate notifications (`(newStart, oldEnd)`, then `collapsed`) therefore fire while the value is the **stale `finalized`** from the previous gesture. The tap handler then sets `changing` (:957) and, in the same stack, `finalized` (:992). So a gate on the value at notification time sees `finalized` for the noise. The adapter must instead listen to the status notifier and read the selection when the status notifies. SelectableRegion needs no change for that, as long as the adapter reports on every status notification, not only on `finalized`.

Probe evidence (baseline, android touch; `[x]` = status value at callback time):
```
tap1-onto-selection: CB(1,7)[finalized] CBc(1)[finalized] ST:changing ST:finalized
toolbar-selectall:   CBc(-1)[finalized] CB(0,11)[finalized] ST:changing ST:finalized
longpress-drag:      CB(0,3)[finalized] ST:changing (pump) CB(0,11)[changing] ST:changing (pump) ST:finalized
handle-drag:         (pump) CB(0,10)[finalized] ST:changing (pump) ST:finalized
```
linux mouse:
```
click5:       CBc(-1)[finalized] CBc(5)[finalized] ST:changing (down) (pump) ST:finalized   <- F only at tap-up
drag 2->8->9: CBc(-1)[finalized] CBc(2)[finalized] ST:changing (pump) ST:changing CB(2,8)[changing] ST:changing (settle) CB(2,9)[changing] ST:changing (pump) ST:finalized
ctrl+A:       CBc(-1)[finalized] CB(0,11)[finalized] ST:changing ST:finalized
programmatic clearSelection: CBc(-1)[finalized] (pump)                                    <- no ST at all
```

## 2. Design implemented (recommended; `$S/status_gating.patch`)

`_SelectableTextState` no longer owns the `SelectionListenerNotifier`. A private `_SelectionChangedDispatcher` sits as `SelectionArea`'s child, in the slot the `SelectionListener` used to occupy. It builds the `SelectionListener` itself, so tests that do `tester.widget<SelectionListener>(…).selectionNotifier` still work. Parent wiring:

```dart
void _handleSelectionChanged(TextSelection selection) {
  widget.onSelectionChanged?.call(selection, null);
}
...
result = SelectionArea(
  ...,
  child: _SelectionChangedDispatcher(
    onSelectionChanged: _handleSelectionChanged,
    child: scrollableChild,
  ),
);
```

Dispatcher (full code in the patch; adds `import 'dart:async';`):

```dart
class _SelectionChangedDispatcherState extends State<_SelectionChangedDispatcher> {
  final SelectionListenerNotifier _selectionNotifier = SelectionListenerNotifier();
  ValueListenable<SelectableRegionSelectionStatus>? _selectionStatus;
  TextSelection _lastReportedSelection = const TextSelection.collapsed(offset: -1);
  bool _flushScheduled = false;

  // initState: _selectionNotifier.addListener(_handleSelectionDetailsChanged);
  // didChangeDependencies: (re)subscribe _reportSelection to
  //   SelectableRegionSelectionStatusScope.maybeOf(context);
  // dispose: remove both listeners, dispose the notifier.

  void _reportSelection() {
    if (!_selectionNotifier.registered) return;
    final SelectedContentRange? range = _selectionNotifier.selection.range;
    final selection = range == null
        ? const TextSelection.collapsed(offset: -1)
        : TextSelection(baseOffset: range.startOffset, extentOffset: range.endOffset);
    if (selection == _lastReportedSelection) return;
    _lastReportedSelection = selection;
    widget.onSelectionChanged(selection);
  }

  void _handleSelectionDetailsChanged() {
    if (_selectionStatus == null) { _reportSelection(); return; }
    // Changes not followed by a status notification in the same call stack
    // (direct clearSelection, canceled gesture, post-frame continuous edge
    // update) are reported in a microtask.
    if (_flushScheduled) return;
    _flushScheduled = true;
    scheduleMicrotask(() {
      _flushScheduled = false;
      if (mounted) _reportSelection();
    });
  }

  @override
  Widget build(BuildContext context) =>
      SelectionListener(selectionNotifier: _selectionNotifier, child: widget.child);
}
```

- Trigger: every status notification (`changing` or `finalized`) reports the latest selection, deduplicated. Intermediate states are never observed, because they occur *before* the handler's `C`.
- Fallback: a microtask flush covers changes that no status notification follows. In the gesture paths the microtask runs after the synchronous status report and is deduplicated away.
- No-selection value stays `TextSelection.collapsed(offset: -1)`, and `cause` stays `null`. Deriving a cause is **not** trivial: the status carries no gesture kind. The only in-reach signal is `SelectableRegionState.selectAll(cause)`, whose `cause` is not stored, so a cause would need a framework change.
- Variants measured (knob during experiments, removed from the final code): `gateOnValue`, `onFinalized` (the hypothesis; kept as `$S/status_gating_finalized_only_variant.patch`, where the microtask fallback also skips while `changing`), `onAnyStatus` (final), and `microtaskOnly` (no status at all; see §6).

## 3. Before/after callback sequences

Test-level (restored once-per-change assertions):

| Test | Step | Before (HEAD adapter) | Gate-on-value | Finalized-only | Recommended (any status) |
|---|---|---|---|---|---|
| 052 keyboard selection should call onSelectionChanged (both variants) | tap at 0 while `(0,31)`… | `(0,31)`, `c(0)` → FAIL `Expected: null Actual: (0,31)` | same FAIL | `c(0)` PASS | `c(0)` PASS |
| 122 The Select All calls on selection changed (android, fuchsia) | tap Select all | `invalid`, `(0,11)` → FAIL `Expected: null Actual: TextSelection.invalid` | same FAIL | `(0,11)` PASS | `(0,11)` PASS |
| 123 … with a mouse on windows and linux (both) | right-click at 5, then Select all | `c(5)`; `invalid`, `(0,11)` → FAIL | same FAIL | `c(5)`; `(0,11)` PASS | `c(5)`; `(0,11)` PASS |
| 125 onSelectionChanged is called when selection changes (with added pump) | lp 'abc', lp 'def', Select all | counts 1, 2, **4** → FAIL `Expected <3> Actual <4>` | FAIL | 1, 2, 3 PASS | 1, 2, 3 PASS |
| 024 Continuous dragging does not cause flickering | mouse drag c→g (held), tiny move, →h, up | nonzero, 0, 1 PASS | FAIL (0 during drag) | **FAIL** `Expected: a value not equal to <0> Actual: <0>` | nonzero, 0, 1 PASS |

Probe (`l_probe_*.log`), recommended variant vs HEAD:

| Path | HEAD | Recommended |
|---|---|---|
| touch tap onto `(4,7)` at 1 | `(1,7)`, `c(1)` | `c(1)` |
| toolbar Select all (android) | `invalid`, `(0,11)` | `(0,11)` |
| double tap at 9 (android) | `(9,11)`, `c(9)` / `(8,11)` | `c(9)` / `(8,11)` |
| desktop click at 5 with prior selection | `invalid`, `c(5)` at tap-down | `c(5)` at tap-down |
| desktop double click at 5 | `invalid`, `c(5)` / `(4,7)` | `c(5)` / `(4,7)` |
| mouse long press at 5 (prior selection) | `invalid`, `c(5)` | `c(5)` |
| mouse drag 2→8→9 | `invalid`, `c(2)`, `(2,8)`, `(2,9)` | `c(2)`, `(2,8)`, `(2,9)` (same timing) |
| touch long-press drag 1→9 | `(0,3)`, `(0,11)` | `(0,3)`, `(0,11)` (same timing) |
| handle drag | `(0,10)` on update | `(0,10)` on update |
| ctrl+A (linux/windows) | `invalid`, `(0,11)` | `(0,11)` |
| right-click at 5 inside `(2,11)` (linux) | `(5,11)`, `c(5)` | `c(5)` |
| shift+arrow, ctrl+shift+arrow, shift+down | one each | one each (unchanged) |
| focus loss (lifecycle resumed) | `c(-1)` | `c(-1)` |
| programmatic `clearSelection()` | `c(-1)` synchronous | `c(-1)` in a microtask (before the next `pump` returns) |

Finalized-only variant, same probe: every callback moves to gesture end. Desktop click reports at tap-up. The mouse drag reports only `(2,9)` at up, and the long-press drag only `(0,11)` at lift. Programmatic `clearSelection()` and cancel report only if the status is not `changing`.

071 "two slow taps do not trigger a word selection" (all variants) still fails on affinity only, with the same message as baseline (`collapsed(4, upstream)` vs `collapsed(4, downstream)`). The transient `invalid` between the two desktop taps is gone (probe `click5`: `c(5)` only).

## 4. Suite diff vs `$S/failures/failures.json` (84 json entries + 001 = 85 entries at HEAD)

**Recommended variant** (`l_suite_any.log`: `+105 -82`):
- Newly passing: `The Select All calls on selection changed (variant: TargetPlatform.android)`, `… (variant: TargetPlatform.fuchsia)`, `onSelectionChanged is called when selection changes`.
- Also passing with the restored invariants (passing at HEAD only because the assertions were deleted): `Keyboard Tests keyboard selection should call onSelectionChanged` (RawKeyEvent, ui.KeyData then RawKeyEvent) and `The Select All calls on selection changed with a mouse on windows and linux` (windows, linux).
- Newly failing: **none**. `throw if no Overlay widget exists above` shows in the diff only because it is missing from failures.json. It fails at HEAD too, with the identical message (`No MaterialLocalizations found.`, `$S/failures/001.txt`).
- Failure reasons of still-failing tests: unchanged (`l_cmp_reasons.py`; the only difference is a `SelectionAreaState#hash`).
- Targeted re-run of the final code (`l_targets_final.log`): 015, 018, 020, 024, 028, 039, 052×2, 122×2, 123×2, 125, 134 pass. 054×2, 070 (iOS) and 071×5 fail exactly as at HEAD.

**Finalized-only variant** (`l_suite_fin.log`: `+98 -89`): the same 3 newly passing, plus these newly failing:
- `Continuous dragging does not cause flickering` (024): count 0 during the drag.
- `double tap hold selects word (variant: TargetPlatform.macOS)`: reads during the hold, gets `c(11)`.
- `double tap selects word with semantics label (variant: TargetPlatform.iOS)`: gets `c(15)` after a complete double tap. This is the iOS stuck-`changing` bug. With the 1-line framework fix (`$S/status_gating_ios_finalize_fix.patch`: call `_finalizeSelectableRegionStatus()` before the early `return` at :947) this test passes again.
- `long press drag extends the selection to the word under the drag and shows toolbar on lift on non-Apple platforms` (android, fuchsia, linux, windows): reads during the hold, gets `null`.
- It also changes the failure point (earlier, callback-related) of 7 already-failing tests: 029 `Cannot drag one handle past the other` (now `(4,7)` instead of `(4,2)`, read mid-drag), 075 iOS, 088 iOS, 089 macOS, 090 iOS, 092 iOS, and 092 android (`Expected: not null Actual: null`).

## 5. Regressions and costs of the recommended variant
- No test regressions. Callback timing matches the old EditableText: tap-down on desktop, long-press start, each drag or handle update, each key.
- Dedupe: a user action that re-produces the identical selection (for example a long press on the already-selected word, or a click at the current caret) no longer fires. The old EditableText re-fired for `longPress`/`keyboard` causes even without a change. No test in the suite covers this. Drop the equality check if that parity matters; the noise fix does not depend on it.
- Changes that no status notification follows (programmatic `clearSelection()`, gesture cancel, post-frame continuous edge updates while autoscrolling) arrive in a microtask instead of synchronously.
- `cause` is still `null` (G-SELECTION-CAUSE unchanged).

## 6. Answers
- **Does the gating fix the transient `invalid` from `selectAll()` and from desktop tap-down `clearSelection()`, and the `(newStart, oldEnd)` from `_collapseSelectionAt`?** Gating on the current value fixes none of them, because all three fire under a stale `finalized`. Reporting on status notifications (finalized-only or any) fixes all three, because the report happens after the handler's last edge update.
- **User actions where the selection changes without ever reaching `finalized`:**
  1. Programmatic `SelectableRegionState.clearSelection()`: no status notification at all.
  2. Gesture cancel (`onCancel: clearSelection` on both tap recognizers): no notification, and the status can stay `changing` after a desktop tap-down.
  3. iOS touch double tap whose 2nd tap-up lands on the new selection: `_handleMouseTapUp` early return (:937-948) skips `_finalizeSelectableRegionStatus()`, so the status stays `changing` until the next gesture. This is a framework bug that affects any status consumer. Fix: `$S/status_gating_ios_finalize_fix.patch`.
  4. Any finalized-only consumer also gets nothing *during* a gesture (drag, long-press hold, double-tap hold).
  5. Selection changes from content or registration changes (text replaced) do not notify the status.

  The recommended variant covers 1, 2 and 5 through the microtask fallback, and 3 and 4 through the `changing` notifications. It needs no framework change.
- **Simpler alternatives:**
  - Microtask coalescing with no status at all (`microtaskOnly`): report the latest selection once per microtask. On the targeted tests and the probe it gives the same sequences as the recommended variant (`l_probe_micro.log`, `l_targets_micro.log`; not run on the full suite because of the two-run budget). It is simpler: no private widget and no SelectionArea-internal context needed, so it could live in `_SelectableTextState`. It is always asynchronous, though, and relies on "one user step = one synchronous handler", which is an implicit contract. The status-driven version uses the explicit API and reports synchronously.
  - Post-frame coalescing: callbacks move to the next frame. That breaks 125 (`tap('Select all')` then `expect(count, 3)` with no pump), and mid-gesture reads get a stale value until the next frame. Not recommended.
  - Filtering on `SelectionDetails.status` (none/collapsed/uncollapsed): cannot distinguish `(newStart, oldEnd)` (uncollapsed) from a real range, and it suppresses the legitimate clear. It does not fix the problem.

## 7. Recommendation
Adopt the status-driven dispatcher that reports on **every** status notification with dedupe, plus the microtask fallback (`$S/status_gating.patch`). It fixes 052, 122, 123 and 125 with their once-per-change assertions intact, adds no regressions, and needs no framework change. Do **not** gate on the `finalized` value: it is proven not to work. Do not report only on the transition to `finalized` either: it delays callbacks to gesture end, regresses 024 and five other tests, and exposes the iOS stuck-`changing` bug. Separately, consider landing the one-line iOS `_finalizeSelectableRegionStatus()` fix in SelectableRegion (`$S/status_gating_ios_finalize_fix.patch`), because other status consumers (SelectionArea's own `onSelectionChanged`-style listeners) would see the region stuck at `changing` after an iOS double tap.
