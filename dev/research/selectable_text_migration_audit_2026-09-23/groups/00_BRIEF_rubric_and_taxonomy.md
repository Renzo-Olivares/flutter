# SelectableText migration POC — test audit briefing (shared by all subagents)

## Background (from the branch owner)
Branch `selectabletext-migration-poc-testing` (repo `/Users/roliv/flutter`) is a POC that migrates the
internals of `SelectableText` (packages/flutter/lib/src/material/selectable_text.dart) from an
`EditableText` base (old architecture: `TextSelectionGestureDetector` / `TextSelectionGestureDetectorBuilder`,
`RenderEditable`, `TextEditingController`) to `SelectionArea` wrapping a `Text` widget (new architecture:
`SelectableRegion`, `RenderParagraph` selectables, `SelectionListener`/`SelectionListenerNotifier`),
plus composable widgets to recover EditableText features: `SingleChildScrollView` for built-in
scrolling, a `ConstrainedBox` viewport for `maxLines`/`minLines`, `ScrollConfiguration`, a
`GestureDetector` for `onTap`, and `SelectionContainer.disabled` when `enableInteractiveSelection`
is false. The base commit is `5c94360655fe8ba6d29427f58479e0bd96d913dd`.

The test suite under audit is `packages/flutter/test/material/selectable_text_test.dart`.
The owner's process: swap the internals, run the suite, fix tests that failed only for surface
reasons (e.g. `find.byType(EditableText)` → `find.byType(Text)`, reading selection through a new API
instead of `TextEditingController`), and add composable widgets when a test exposed a real feature gap.
Some tests were later deliberately reverted to their original form so that they FAIL and expose gaps.

## Scratchpad layout (`/private/tmp/claude-501/-Users-roliv-flutter/727bb496-578a-49a2-b6c9-df33a85675f3/scratchpad`, referred to as `$S`)
- `$S/impl.diff` — diff of selectable_text.dart + selectable_region.dart (base → head). READ THIS FIRST.
- `$S/impl_base.dart`, `$S/impl_head.dart` — full old / new SelectableText implementation.
- `$S/test_base.dart`, `$S/test_head.dart` — full old / new test file (helpers live at the top; group
  `Keyboard Tests` and group `magnifier` exist).
- `$S/pertest/helpers_and_preamble.diff` — diff of everything OUTSIDE testWidgets blocks (helper
  functions, `boilerplate()`, `textOffsetToPosition`, `findRenderParagraph`, `getSelectionEndpoints`,
  Keyboard-group `setupWidget`, and the owner's TODO comments). READ THIS SECOND — helper changes
  affect many tests.
- `$S/pertest/NNN.diff`, `$S/pertest/NNN.base.dart`, `$S/pertest/NNN.head.dart` — per-test unified
  diff and full old/new test bodies. NNN = the test's ordinal in the HEAD file (001..138). Tests 007
  and 083 are renamed tests (old name → new name), 134 is newly added (no base version).
- `$S/pertest/summary.json` — every test: idx, name, status (UNCHANGED/MODIFIED/ADDED), line ranges.
- `$S/failures/NNN[_variant].txt` — failure output of the HEAD test file run against the HEAD
  implementation (i.e. tests that are STILL FAILING right now). If no file exists for a test, it
  currently passes.
- `$S/failures_base_on_head/NNN[_variant].txt` — failure output of the ORIGINAL (base-commit) test
  body run, unmodified, against the NEW implementation. Use this to see what the test was failing on
  BEFORE it was edited. NOTE: the base `boilerplate()` helper had no Overlay, so many of these fail
  with the Overlay assertion first; that is a known surface issue.
- `$S/failures_base_overlayfix_on_head/NNN[_variant].txt` — same as above but with ONLY the
  `Overlay.wrap` fix applied to `boilerplate()`. This is the cleanest "what did the original test
  really trip on" signal. If a test has no file here, the original test body PASSES on the new
  implementation with just the Overlay fix — which means any further edits to it were unnecessary.
- `$S/packets/<group>.md` — your assigned tests with the above statuses summarized.

Key framework sources you may need (read, do not edit):
- packages/flutter/lib/src/widgets/selectable_region.dart (SelectableRegion/SelectableRegionState:
  gestures, keyboard actions, toolbar/handles, selectionOverlay, onSelectionChanged, keep-alive)
- packages/flutter/lib/src/material/selection_area.dart (SelectionArea)
- packages/flutter/lib/src/widgets/selection_container.dart, selectable_region.dart's
  SelectionListener / SelectionListenerNotifier / SelectionDetails / SelectedContentRange
- packages/flutter/lib/src/rendering/paragraph.dart (RenderParagraph, _SelectableFragment: word
  selection, getSelectedContentRange, selection painting)
- packages/flutter/lib/src/rendering/selection.dart (SelectionEvent kinds, SelectionGeometry)
- packages/flutter/lib/src/widgets/text.dart (Text) and widgets/editable_text.dart,
  rendering/editable.dart, widgets/text_selection.dart (TextSelectionGestureDetectorBuilder — old
  gesture semantics), material/text_selection.dart, material/selectable_text.dart (head).

## Running tests (allowed, please be economical)
- One test by name:  `cd /Users/roliv/flutter && bin/flutter test --no-pub packages/flutter/test/material/selectable_text_test.dart --plain-name "<exact test name>"`
  (group tests need the group prefix, e.g. `--plain-name "Keyboard Tests Shift test 1"`).
- Experiments: you MAY create a scratch test file named
  `packages/flutter/test/material/zz_scratch_<yourgroup>_test.dart` (copy the head file's helper
  preamble as needed, put only the test(s) you are probing in it, edit freely), run it with
  `bin/flutter test --no-pub <that file>`, and you MUST delete it before you finish.
  Use this to answer questions such as "if I fix the stale finder, does the assertion then pass?"
- NEVER edit `packages/flutter/test/material/selectable_text_test.dart` or anything under
  `packages/flutter/lib/`. NEVER run the whole suite. Do not run `git checkout`/`git stash`/etc.
- Do not run more than one `flutter test` at a time; other agents are running tests concurrently.

## Part A — for every MODIFIED / ADDED / RENAMED test in your packet: warranted or fake fix?
Classify the test-body change (compare NNN.base.dart vs NNN.head.dart, and account for helper changes
in helpers_and_preamble.diff that the test relies on):

- **WARRANTED** — the change adapts the test to the new architecture WITHOUT weakening what it asserts
  about user-visible behavior. Typical: finder swaps (`EditableText`→`Text`/`SelectableRegion`/`RichText`),
  reading the selection via `onSelectionChanged`/`SelectionListenerNotifier`/`RenderParagraph`
  instead of `TextEditingController`, reading endpoints via `SelectableRegionState.selectionOverlay`
  instead of `EditableTextState`, `RenderEditable`→`RenderParagraph`, extra `pump()` needed because
  SelectionArea registers selectables a frame later, adding `Overlay`. The assertion's intent and
  strength are preserved. Cite the new API that replaced the old one (file:line).
- **FAKE FIX** — an expectation VALUE was changed (offsets, affinity, counts, sizes, colors, whether a
  toolbar/handle/button is present, selection range, `cause` value…), an assertion was deleted or
  weakened (e.g. `expect(x, 5)` → `expect(x, isNotNull)`), steps were removed, a platform variant was
  dropped/switched, or the test was otherwise reshaped so it passes on the new behavior — thereby
  masking a behavioral/architectural difference between old and new SelectableText. Say exactly what
  behavior it masks and name the gap (see taxonomy). Deleting the assertion of a feature the new
  implementation simply lacks (e.g. cursor) is a FAKE FIX, not a warranted one, unless the test also
  now fails / documents it.
- **MIXED** — both kinds in one test: list each piece separately.
- **COSMETIC** — formatting, renames, comments, or reordering with no semantic effect.
- **PARTIAL (still failing)** — the test was edited (perhaps warranted) but still fails; classify the
  edit AND do Part B.
For added tests (007, 083, 134): judge whether it is a legitimate replacement/addition or a weaker
stand-in for a removed/stronger test.

Evidence standard: Every verdict needs concrete evidence — quote the specific changed line(s), cite
implementation code (file:line) showing the old/new API or behavior, and where useful cite the
`failures_base_overlayfix_on_head` output showing what the original test tripped on. Example of a
strong warranted argument: "original failed with `No element` at `tester.state<EditableTextState>`;
the head test reads the same endpoints from `SelectableRegionState.selectionOverlay.selectionEndpoints`
(selectable_region.dart:NNN) and keeps the same numeric expectations". Example of a strong fake-fix
argument: "expectation changed from `TextSelection(baseOffset: 4, extentOffset: 5)` to
`(4, 2)`; the original expectation encodes the old handle-clamping rule in
TextSelectionGestureDetectorBuilder (text_selection.dart:NNN); SelectableRegion lets handles cross
(selectable_region.dart:NNN) so this hides a behavioral gap".

## Part B — for every test in your packet that is STILL FAILING at head
1. Determine the ROOT reason. Read `$S/failures/NNN*.txt`, the test body, and the implementation.
   If the immediate error is a stale finder / missing API call but the test's real assertion would
   ALSO fail after that surface fix, say so and classify by the deeper reason (verify with a scratch
   test if you are not sure). Conversely, if a surface fix makes the whole test pass, say exactly what
   the fix is.
2. Classify as **SURFACE** (stale finder, alternative API/method exists and would make it pass,
   missing pump, needs Overlay/MaterialApp, needs `--plain-name` group prefix, etc.) or **GAP**
   (a real architectural/behavioral difference: the API/behavior does not exist in the
   SelectionArea/Text world, or exists but behaves differently). Some tests may be **MIXED**
   (surface issue + a gap behind it) — say which parts.
3. For each GAP give a `gap_id` from the taxonomy below (add a new one with a clear name if none
   fits), a one-paragraph description of the gap grounded in code, and the specific assertion that
   exposes it.

## Gap taxonomy (use these ids; extend if needed, keep names descriptive)
- G-NO-CARET: no cursor/caret; `showCursor`/cursor* params are no-ops; a tap does not place a
  collapsed selection at the tapped offset (SelectionArea has no collapsed-caret concept; tap clears).
- G-SELECTION-CAUSE: `onSelectionChanged` never receives a `SelectionChangedCause` (always null) and
  collapsed/empty selection is reported as `collapsed(-1)`.
- G-NO-AFFINITY: `TextSelection.affinity` is not exposed via SelectedContentRange.
- G-NO-CONTROLLER: no `TextEditingController` / `EditableTextState` / `RenderEditable`; tests that
  inspect `controller.selection`, `renderEditable.getEndpointsForSelection`, etc. have no direct
  equivalent (only a gap if NO alternative API yields the same information).
- G-KEYBOARD-NAV: keyboard selection (shift+arrow, ctrl+shift, up/down) differs — SelectableRegion
  only extends an EXISTING selection and has no caret to start from.
- G-SEMANTICS-TEXTFIELD: semantics differ — no text-field node, no `textSelection`, no
  moveCursor*/setSelection actions, different flags/labels/structure; `semanticsLabel` handling.
- G-HANDLE-CLAMP: dragging handles past each other / handle-drag rules differ.
- G-TOOLBAR-PLATFORM: toolbar shown/hidden under different conditions or with different buttons per
  platform (e.g. macOS touch long-press, Android 'Select all' always present, iOS-specific buttons,
  toolbar on select-all, mouse interactions).
- G-TOOLBAR-OPTIONS: `toolbarOptions` / `contextMenuBuilder` (EditableTextContextMenuBuilder) not
  honored by the SelectionArea-based implementation.
- G-HANDLES-VISIBILITY: handle visibility/fade/timing differs (e.g. Android shows handles only on
  long-press end; visibility notifiers not wired).
- G-TAP-GESTURES: single/double/triple tap, tap-after-double-tap, slow-tap, tap-on-space, mouse
  long press, etc. select differently (word selection rules, tap resets, chains).
- G-LONGPRESS-DRAG: long-press-drag selection/extension semantics and edge-scrolling differ.
- G-MOUSE-DRAG-EDGE-SCROLL: mouse drag near edge does not auto-scroll the internal scrollable.
- G-SCROLLING: built-in scrolling behavior (bringIntoView, scroll on selection, ScrollBehavior
  override, scrollbars, scroll position/controller access) differs.
- G-LAYOUT-SIZE: intrinsic size/height/width differs (maxLines reserved height, strut, caret
  margin, RenderParagraph vs RenderEditable width), baseline propagation through scroll view.
- G-SELECTION-STYLE: `selectionHeightStyle`/`selectionWidthStyle`/selection colors not honored.
- G-FORCE-PRESS: force-press word selection unsupported.
- G-SPAN-RECOGNIZERS: TextSpan gesture recognizers (tap/long-press) blocked by SelectionArea gestures.
- G-KEEP-ALIVE: keep-alive when focused/selected in a scrollable.
- G-MEDIAQUERY-TEXT-OVERRIDES: lineHeightScaleFactorOverride / letterSpacingOverride /
  wordSpacingOverride handling.
- G-WEB-ENGINE-UPDATE: selection updated from the web engine / platform channel not supported.
- G-OVERLAY-LOCALIZATION-REQUIREMENT: SelectionArea requires Overlay and/or Localizations that the
  old widget did not (affects error messages / minimal harnesses).
- G-OTHER-<name>: anything else (describe).

## Output — write `$S/reports/<group>.md` (and nothing else in the repo)
Use EXACTLY this structure so results can be merged mechanically:

```
# Group <name> report

## Test NNN — <exact test name>
- status_at_head: PASSING | FAILING (variants: ...)
- change_status: UNCHANGED | MODIFIED | ADDED | RENAMED
- part_a_verdict: WARRANTED | FAKE FIX | MIXED | COSMETIC | PARTIAL | N/A (unchanged)
- part_a_details: <what changed, line by line where it matters; for MIXED list each piece with its own verdict>
- part_a_evidence: <cited files:lines, quoted lines, base-on-head failure excerpt>
- part_b_classification: SURFACE | GAP | MIXED | N/A (passing)
- part_b_root_cause: <root reason, including what the immediate error is and what lies behind it>
- part_b_surface_fix: <exact fix if SURFACE/MIXED, else "none">
- gap_ids: [G-...] (empty if none)
- gap_notes: <per gap id: the assertion that exposes it + code-grounded explanation>
- confidence: HIGH | MEDIUM | LOW (+ one line on what would raise it)
```
Finish with a `## Group summary` listing counts per verdict and any NEW gap ids you introduced with
their definitions. Keep prose tight; evidence over opinion. Do NOT report back a long narrative in
your final message — just say the report path and 3-5 headline findings.
