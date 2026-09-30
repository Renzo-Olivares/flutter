# SelectableText → SelectionArea migration POC: test-suite audit

Branch `selectabletext-migration-poc-testing`, base commit `5c94360655fe8ba6d29427f58479e0bd96d913dd`. Audited 2026-09-23 at head ece56299239; review verdicts applied the same day, new head 9ca7895e3ab (23 commits: 2 implementation, 21 test-file). Numbers are given for both heads where they differ.
Suite: `packages/flutter/test/material/selectable_text_test.dart` (138 tests in both versions).

Method. Both versions of the suite were split into per-test blocks and diffed test-by-test. Four
runs were made against the NEW implementation: (1) the head test file, (2) the unmodified base
test file, (3) base + only the `Overlay.wrap` helper fix, (4) base + Overlay fix + the head's
RenderParagraph-based `textOffsetToPosition`. Run (4) is the cleanest signal of what each original
test actually tripped on before it was edited. Eleven Opus subagents then audited one thematic group
each, reading the framework source and running scratch probes; their full per-test reports (with
file:line evidence and probe output) are in `groups/`. This document is the synthesis.

Test numbers below (e.g. #029) are the test's ordinal in the HEAD file. Names are given on first use.

---

## 1. Headline numbers

| | audit head ece56299239 | after review 9ca7895e3ab |
|---|---|---|
| Tests in suite | 138 | 138 |
| Unchanged vs base | 23 (14 passing, 9 failing) | 20 (14 passing, 6 failing) |
| Modified / added / renamed vs base | 115 | 118 |
| Passing | 81 | 85 |
| Skipped | 0 | 1 (#124, obsolete) |
| Failing | 57 tests (85 entries counting platform variants) | 52 tests (76 entries) |
| Newly failing after the review | | none |
| Newly passing after the review | | #034, #122 (android, fuchsia), #125, #127 (4 variants), #136 |
| Base tests still failing on new impl with only the two helper fixes | 122 of 138 | |

The Part A verdict counts below describe the audit head. Every fake-fix row received an author verdict
(§7) and the agreed edits landed as commits c603eebeedc..bd48ac246d6 plus 9ca7895e3ab; 37 tests were
edited in that pass. Section 3's per-gap lists are annotated where a test's status changed.

Part A verdicts over the 115 edited tests:

| verdict | count | meaning |
|---|---|---|
| WARRANTED | 41 | API/finder swap, expectations preserved |
| PARTIAL | 36 | edit was warranted but the test still fails (kept failing to expose a gap) |
| MIXED | 26 | warranted pieces plus at least one weakened/changed expectation |
| FAKE FIX (pure) | 9 | expectation value changed to match new behavior |
| COSMETIC | 3 | reformat / TODO only |

Part B over the 57 failing tests: GAP 45, MIXED (surface issue in front of a gap) 10, SURFACE 2.

---

## 2. Part A: which test edits were warranted, which were fake fixes

### 2.1 Pure fake fixes (9 tests, all one mechanism, low severity)

#009 "Selectable Text has adaptive size", #011 "can switch between textWidthBasis", #102–#108 (all seven
`strut ...` tests). In every one, the only edit is a width literal lowered by exactly 3.0
(17→14, 199→196, 633→630, 129→126, 183→180, 93→90). That 3.0 is `RenderEditable`'s caret margin,
`_kCaretGap (1.0) + cursorWidth (2.0)` (`rendering/editable.dart:25, :1279, :2414`), which RenderParagraph
does not reserve. Commit ece56299239 "remove legacy RenderEditable caret margin" is this change.
Heights are untouched and genuinely match thanks to the new ConstrainedBox viewport. Verdict: the new
numbers are the correct new geometry for a caret-less widget, but they silently absorb a user-visible
layout change (every SelectableText is `cursorWidth + 1` px narrower; `cursorWidth` no longer affects
layout). Gap: **G-LAYOUT-SIZE (caret margin)**. Note the strut preamble comment in the head file (before
#102) is stale: it says heights are wrong and the tests are kept failing; at head all seven pass.

### 2.2 Mixed tests whose fake-fix piece masks a real behavioral gap (ordered by severity)

| test | fake-fix piece | gap masked | evidence |
|---|---|---|---|
| #061 "SelectableText semantics for selections", #063 "SelectableText change selection with semantics" | Deleted `value`, `inputType`, flags `isTextField/isReadOnly/isFocusable/isMultiline/isFocused`, actions `moveCursor*`, `setSelection`, `copy`; replaced the programmatic collapsed-caret start state with a long-press word selection; accepted the extra `hasImplicitScrolling` node | G-SEMANTICS (identity, focus, selection-actions, copy-action, scroll-node); collapsed-caret semantics state | Kept `textSelection` + `setSelection`→`onSelectionChanged` asserts are the only reason they still fail. If those two were implemented the tests would pass with no text-field identity, focus, cursor-move or copy semantics. `groups/D_semantics.md` |
| #072 "double tap selects word and first tap of double tap moves cursor", #075 "double tap hold selects word", #095 "double tap after a long tap is not affected", #096 "double tap chains work" | macOS `expectCupertinoSelectionToolbar()` (expects a 1-button Copy toolbar) flipped to `expect(find.byType(CupertinoButton), findsNothing)` (#096: three times); #075 also deleted the mid-hold toolbar check | G-TOOLBAR-PLATFORM: SelectableRegion never shows a toolbar on a macOS touch double tap (`selectable_region.dart:983-989`), and shows it on the 2nd tap-UP not tap-DOWN so nothing is visible during a double-tap hold | Probe: macOS after double tap `(8,12)`, 0 CupertinoButtons; iOS/macOS during hold 0 buttons. These flips are currently dormant because the tests fail earlier on affinity/word-edge, but they will make macOS pass once those are fixed. `groups/F_*.md`, `groups/H_*.md` |
| #094 "long tap still selects after a double tap select (macOS)", #096 (3rd tap) | `TextSelection.collapsed(offset: 11, affinity: upstream)` → `collapsed(offset: 11)` | G-NO-AFFINITY | Sibling #095 keeps the same expectation and fails on exactly the affinity. Inconsistent with #077/#078/#085 which deliberately keep affinity to expose the gap |
| #007 renamed "uses DefaultSelectionStyle for selection **and cursor** colors if provided" → "... selection colors ..." | `expect(state.widget.cursorColor, cursorColor)` deleted and "and cursor" dropped from the name; `cursorColor: Colors.red` still passed but never asserted | G-NO-CARET | Head impl never reads `widget.cursorColor` or `DefaultSelectionStyle.cursorColor` (declared at `selectable_text.dart:142/321/442`, unused in build). Old impl resolved it at `impl_base:704/717/730/740` |
| #019 "Slight movements in longpress don't hide/show handles" | `variant: TargetPlatformVariant.only(TargetPlatform.iOS)` added; base ran on Android | G-HANDLES-VISIBILITY: Android shows handles only on long-press END (`selectable_region.dart:1014-1016, :1032`); old showed them on any long-press cause (`impl_base:643-660`) | Base body on new impl (Android): `Found 0 widgets with type FadeTransition` during the hold; probe: 0 handles during hold, 2 after release |
| #030 "Can use selection toolbar" | Entry path "tap → tap the collapsed caret handle → toolbar" replaced by `longPressAt` | G-NO-CARET (no caret handle exists after a tap: probe `collapsed(5)`, overlay null) | Old path: `_handleSelectionHandleTapped` → `toggleToolbar` (`impl_base:637-639`). Select all / Copy value expectations preserved |
| #091 "Desktop mouse drag can edge scroll when inside a horizontal scrollable" | `kind: PointerDeviceKind.mouse` added to a gesture that was touch in base | G-DESKTOP-TOUCH-DRAG: touch drag on linux/macOS/windows no longer extends the selection (`_handleMouseDragStart/Update` return for non-precise devices, `selectable_region.dart:815-818, 828-831`) | Probe with touch: selection stays `collapsed(14)`; with mouse: `14..134`. Justified by the test title, but the base passed with touch |
| #052 "keyboard selection should call onSelectionChanged", #123 "The Select All calls on selection changed with a mouse on windows and linux" | In-callback `expect(newSelection, isNull)` (exactly one callback per change) dropped; #052 now checks `selections.last` | G-SELECTION-CALLBACK-NOISE: a tap onto an existing selection fires `(0,31)` then `(0,0)`; Select all fires `TextSelection.invalid` then `(0,11)` | Sibling #122 keeps the assertion and fails on exactly this |
| #109 "Caret center position", #110 "Caret indexes into trailing whitespace center align" | `RenderEditable.getLocalRectForCaret` (painted caret rect: clamped, pixel-snapped, `editable.dart:1817-1862`) → `RenderParagraph.getOffsetForCaret(pos, Rect.zero)` (raw TextPainter offset); every expected x shifted +1 | G-NO-CARET (nothing paints a caret; the test now checks TextPainter math, not SelectableText caret placement) + G-LAYOUT-SIZE (+1.5px centering shift from the removed 3px margin, rounds to +1 at DPR 1) | Numbers reproduce exactly: 250 + (297−56)/2 = 370.5 → 385 (old) vs 250 + (300−56)/2 = 372 → 386 (new) |
| #032 "Can drag handles to change selection in multiline", #037/#038 "Can align to center (within center)" | Absolute x expectations moved +1.5 (24.5→26.0, 58.5→60.0) / +1 (399→400) | G-LAYOUT-SIZE (same caret-margin centering shift) | Relative/selection expectations preserved; the new values are geometrically exact |
| #004 "Rich selectable text has expected defaults", #005 "Rich selectable text supports WidgetSpan" | Bare `MediaQuery + Directionality` harness → `boilerplate()` (adds Theme, Localizations, Overlay, Material) | G-OVERLAY-LOCALIZATION-REQUIREMENT (low severity; #001 documents it) | Base body on new impl: `No MaterialLocalizations found. SelectionArea widgets require MaterialLocalizations` (`material/selection_area.dart:125`). Bare harness + `Overlay.wrap` alone still fails |
| #124 "Does not show handles when updated from the web engine" | `kIsWeb` branch mechanically translated to `selectionNotifier.selection.range == SelectedContentRange(2,7)` | G-WEB-ENGINE-UPDATE: SelectableRegion registers no TextInputClient, so the update is dropped (probe: range stays (0,0), `hasClient=false`) | Vacuous in base too: the file is `@TestOn('!chrome')`. Not a value change, but the translated branch claims coverage the architecture cannot provide |

### 2.3 Mixed tests whose weakening masks NO gap (worth restoring anyway)

- #016/#017 "enableInteractiveSelection = false, tap / long-press": `expect(currentSelection, null)` is tautological (the `SelectionListener` only exists in the `SelectionArea` branch, `impl_head:636-644`; with `SelectionContainer.disabled` the callback can never fire). Probe confirms no SelectableRegion, handles or toolbar. Stronger check: `expect(find.byType(SelectableRegion), findsNothing)` plus no `_SelectionHandleOverlay`.
- #021 "selectable text basic": `tester.showKeyboard(...)` deleted (needs EditableText) leaving `hasAnyClients == false` near-vacuous. Probe: `hasAnyClients` stays false after a real tap and long press, so move the check after those gestures.
- #028 "Dragging handles calls onSelectionChanged": in-callback `expect(newSelection, isNull)` deleted. Probe: exactly one callback per gesture, so it can be restored.
- #090 "long press drag can edge scroll when inside a scrollable": `pump()` → `pump(1s)` is unnecessary (no scroll happens either way); unused ScrollController added.

### 2.4 Warranted edits (41 passing + 36 still-failing PARTIAL), by pattern

All of these preserve the assertion values and only change how the state is read or driven. The
original body of every one of them fails on the new implementation at `Bad state: No element` for
`find.byType(EditableText)` / `tester.state<EditableTextState>` / `findRenderEditable` (run 4), i.e. a
pure stale-finder failure, and the head test keeps the same expectation.

- **`TextEditingController.selection` → `onSelectionChanged` capture** (the public substitute; head adapter `_handleSelectionDetailsChanged`, `selectable_text.dart:505-521`): #002, #015, #018, #020, #023–#028, #032, #033, #039, #045–#055, #058, #066, #068–#071, #073, #074, #076–#082, #084–#090, #092, #093, #097–#099, #118, #119, #131, #132. Values such as `(4,7)`, `(5,8)`, `(8,5)` (direction preserved: `SelectedContentRange` keeps start/end edges, `paragraph.dart:1656-1663`), `(13,23)`, `collapsed(4, upstream)` are byte-identical to base.
- **`controller.selection = collapsed(n)` → `tester.tapAt(textOffsetToPosition(n))`**: #046, #049, #050, #052, #058. Legitimate because SelectableRegion does place a collapsed selection at the tapped offset (touch tap-up: `_handleMouseTapUp` → `_collapseSelectionAt`, `selectable_region.dart:956, :1503-1508`; desktop tap-down: `:767`). Verified by probes in four groups.
- **`RenderEditable.getEndpointsForSelection` → `SelectableRegionState.selectionOverlay.selectionEndpoints`** (new `getSelectionEndpoints` helper; `selectable_region.dart:434`, populated at `:1306`): #002, #027–#029, #032, #033, #090, #132. #132 is actually stronger (handles at the real selection end 7, not a hand-built 6).
- **`RenderEditable` → `RenderParagraph`** (`findRenderParagraph`, `getOffsetForCaret`, `textHeightBehavior`, `text.style`): #012, #037, #038, #066, #133, #136.
- **`EditableTextState.selectionOverlay.handlesAreVisible / toolbarIsVisible` → widget presence** (`_SelectionHandleOverlay` count, `AdaptiveTextSelectionToolbar`): #021, #111–#117, #121, #124. `SelectionOverlay` has no public `handlesAreVisible` (only `TextSelectionOverlay` at `text_selection.dart:583`), so widget presence is the public equivalent; opacity == 1.0 checks are kept.
- **Programmatic `renderEditable.selectWord(...)` / `showToolbar()` / `updateEditingValue` → real gestures or `SelectableRegionState.selectAll()/hideToolbar()`**: #014, #085, #086, #095, #096, #111, #112, #129, #130, #138.
- **Registration `pump()` after `pumpWidget`**: nearly every test. Required, not cosmetic: SelectionArea → SelectionListener → Text registers over two frames (`_scheduleSelectableUpdate`, `selectable_region.dart:2444-2467`); a gesture in the first frame is silently dropped (#134/#135 originals fail with `selection == null` for exactly this reason).
- **Renamed tests**: #083 "textSelectionControls is passed to SelectionArea" (was "... to EditableText"; `SelectionArea` forwards controls verbatim, `selection_area.dart:126-136`; asserting on `SelectableRegion` would be one layer stronger). #134 "SelectableText selection update on tap" is NOT a new weaker stand-in: in base it was a duplicate-named copy of #133 (`test_base.dart:5563-5596`); head only renames it and adds the registration pump.
- **#131 "keeps alive when has focus"** passes legitimately because commit b73a681e605 added `AutomaticKeepAliveClientMixin` to `SelectableRegionState` (`wantKeepAlive => _focusNode.hasFocus`, mirroring EditableText). The TODO above it (line 6018) is stale. Caveat: that change applies to every SelectionArea framework-wide.
- **#097 "force press does not select a word on (android)"**: `collapsed(-1)` → `null || !isValid`, same meaning. Passes by construction (no force-press recognizer anywhere), but it was always a negative test; #098 carries the gap.
- **#001 "throw if no Overlay widget exists above"**: expected message `EditableText widgets require...` → `SelectableRegion widgets require...` is warranted (the string interpolates runtimeType, `widgets/debug.dart:515`); still fails, see Part B.
- Unnecessary but harmless edits (original form passes, verified): #002 extra tap; #039 second-tap location; #052 center tap → `tapAt(31)`; #053 inner `pumpAndSettle`; #114 `pumpAndSettle`; #126's added `Material(child: Center(...))` wrapper is actually harmful (see Part B).

### 2.5 Cosmetic (3)

#013 "Cursor blinks when showCursor is true", #056/#057 "SelectableText baseline alignment (no-strut)": reformat, a pump, and a TODO. All three still fail on real gaps.

---

## 3. Part B: why each still-failing test fails

**Status after the review was applied (head 9ca7895e3ab).** 52 tests still fail (76 entries), none new.
Changes to the lists below: GAP 7 (callback noise) is closed by the dispatcher (e9f17a5b296): #122 and
#125 pass, and #052/#123 pass with their once-per-action assertions restored. The surface issues in
3.1 and 3.2 were fixed where the review agreed: #034, #127 and #136 now pass; #054, #062, #091, #126 and
#128 now fail directly on their gap assertion; #001, #033 and #044 are unchanged. Keep-alive moved into
SelectableText (881f512d507). The failure-output snapshots for the new head are in
`scripts/baseline_failures_9ca7895e3ab.json`.

### 3.1 Surface-only (2 tests): a test-side change makes them pass (verified by probe; both applied, both pass at 9ca7895e3ab)

- **#034 "ScrollBehavior can be overridden"**: asserts `Scrollable.scrollBehavior` (the constructor field). `SingleChildScrollView` never passes `scrollBehavior` to its inner `Scrollable` (`single_child_scroll_view.dart:261-268`); the behavior is delivered through the wrapping `ScrollConfiguration` (`selectable_text.dart:593-598`). Fix: `expect(ScrollConfiguration.of(tester.element(find.byType(Scrollable))), same(behavior))` (and `isNotNull` for the default). Passes.
- **#127 "selecting a space selects the space on non-mobile platforms"** (unchanged): (a) missing registration `pump()`; (b) `textOffsetToPosition(tester, 10)` is exactly the paragraph's right edge and, without the old 3px caret margin, misses the region. Fix: add the pump and tap at `- Offset(1,0)` for the two end-of-text taps. Passes on all four variants; RenderParagraph's raw word boundary already selects the single space. The owner TODO at line 5802 is wrong.

### 3.2 Surface issue in front of a real gap (10 tests at the audit head)

At 9ca7895e3ab: #125 and #136 pass (surface fixed, no gap behind them for these assertions); #054, #062, #091, #126, #128 had their surface part fixed and now fail on the gap named in the last column; #001, #033, #044 are unchanged.

| test | surface part (fix) | gap behind it |
|---|---|---|
| #001 "throw if no Overlay widget exists above" | Add a `Localizations` ancestor; the Overlay message then matches | Final `expect(tester.takeException(), isNotNull)` fails: Overlay is now asserted at BUILD (`selectable_region.dart:1957`), not lazily on the gesture, so there is no half-built overlay to throw on unmount. G-OVERLAY-LOCALIZATION-REQUIREMENT |
| #033 "Can scroll multiline input" | `pump(1s)` after the handle drag → `pumpAndSettle()`; whole test then passes | Handle drag past the edge scrolls via `EdgeDraggingAutoScroller` (≤20px per frame, `scrollable_helpers.dart:237-318`) instead of an immediate `bringIntoView → jumpTo` (`editable_text.dart:5171-5175`), and keeps scrolling while held so the selection overshoots to `(0,82)` instead of `(5,82)` (not asserted). G-HANDLE-DRAG-AUTOSCROLL |
| #054 "Changing focus test" | `expect(selection2!.extentOffset - ..., 0)` dereferences a null (second widget never notified); should be `expect(selection2, isNull)` | Sign inversion, see G-KEYBOARD-ANCHOR-INVERTED |
| #062 "semantic nodes of offscreen recognizers are marked hidden" (unchanged) | Hard-coded `performAction(8, ...)` now hits the onscreen label; the link is id 9 | Missing `inputType: text`; extra `hasImplicitScrolling` node shifts ids. The #100395 regression intent (isHidden + showOnScreen scrolls to 3592) is preserved. G-SEMANTICS |
| #091 "Desktop mouse drag can edge scroll when inside a horizontal scrollable" | `getSelectionEndpoints` asserts a non-null overlay, but a desktop mouse drag never creates one (`selectable_region.dart:926-929`); read endpoints from `RenderParagraph.getBoxesForSelection` instead | Start endpoint is +449.6 and the ANCESTOR scrollable's pixels stay 0.0. G-ANCESTOR-SCROLLABLE-EDGE-SCROLL |
| #125 "onSelectionChanged is called when selection changes" (unchanged) | Missing registration `pump()` | With the pump: 4 callbacks instead of 3 (Select all fires `invalid` then `(0,11)`). G-SELECTION-CALLBACK-NOISE |
| #126 "selecting a space selects the previous word on mobile" | Missing `pump()`; the head's added `Center` shrink-wraps the region so the end-of-text tap misses | Long press on the space at 5 gives `(5,6)` not `(1,5)`. G-TAP-GESTURES (whitespace rule) |
| #128 "double tapping a space selects the previous word on mobile" | Missing `pump()` | Double tap at 5 → `(5,6)` not `(1,5)`; at 14 → `(13,15)` not `(6,14)`. G-TAP-GESTURES (whitespace rule) |
| #136 "SelectableText respects MediaQueryData.lineHeightScaleFactorOverride, ..." | Bare `Directionality + MediaQuery` harness; wrap in `MaterialApp` (or Localizations + Overlay.wrap) and all four expectations pass | Only the harness requirement. `Text` applies all three overrides the same way (`text.dart:728-744`). Residual: when no `strutStyle` is given the new code leaves strut null (old always passed `const StrutStyle()`). G-OVERLAY-LOCALIZATION-REQUIREMENT |
| #044 "Selectable rich text with gesture recognizer has correct semantics" (unchanged) | Expectation could drop `inputType` and add the scroll node, but that accepts both differences | G-SEMANTICS (identity, scroll-node). Recognizer link semantics (isLink, tap) are preserved |

### 3.3 Real gaps (45 tests), grouped

Each group: mechanism with code citations, the tests it currently breaks, and the tests where an edit hides it.

**GAP 1: Toolbar button set and toolbar-visibility rules (G-TOOLBAR-PLATFORM).** `SelectableRegion.getSelectableButtonItems` (`selectable_region.dart:299-338`) is not platform-aware the way `EditableTextState` is: `canSelectAll = selectionGeometry.hasContent` (:306) with no "already all selected" or platform check (old `selectAllEnabled`, `editable_text.dart:2684-2696`: hidden when everything is selected on Android/Fuchsia/Linux/Windows, only for a collapsed selection on iOS, never on macOS); iOS Share hard-coded false (:316-320); no Look Up / Search Web at all (old `lookUpEnabled/searchWebEnabled/shareEnabled`, `editable_text.dart:2700-2727`); Android read-only toolbar now also shows Share. Visibility: no toolbar on a macOS touch double tap (:983-989); toolbar shown on 2nd tap-UP (:969-982) not tap-DOWN (`text_selection.dart:2938-2944`), so nothing shows during a double-tap hold. Probe: iOS and macOS both show `[Copy, Select All]`.
- Exposed (currently the failing assertion): #079 "long press selects word and shows toolbar (iOS)" [iOS 2≠4 buttons, macOS 2≠1], #086 "long press tap cannot initiate a double tap on iOS", #088 "long press drag extends ... (iOS)", #089 "long press drag moves the cursor ... (macOS)", #090 (iOS), #092 "long press drag can edge scroll" (iOS), #094 (macOS), #121 "The handles show after pressing Select All" [`Select all` still present after selecting all; handles and Copy are fine], #075 (iOS). Latent behind an earlier failure: #072, #093, #095, #096, #098.
- Masked by edits: #072/#075/#095/#096 (macOS flipped to `findsNothing`; #075 mid-hold check deleted), #030 (Share unasserted).
- Note: the toolbar DOES appear after a macOS touch long press in both old and new; the commit message "SelectableRegion does not wire up toolbar to be shown on touch interaction for macOS" is only true for double tap.

**GAP 2: TextAffinity is not representable (G-NO-AFFINITY).** `SelectedContentRange` carries only `startOffset/endOffset` (`rendering/selection.dart:125-168`); the adapter builds `TextSelection(baseOffset:, extentOffset:)` with default downstream (`selectable_text.dart:513-517`). Old taps produced `upstream` at word/line ends (`selectPosition`/`selectWordEdge`).
- Exposed as the ONLY failing assertion: #069 "tap moves cursor to the position tapped (Android)" (all 5 variants), #071 "two slow taps do not trigger a word selection" (all 5), #073 "double tap selects word ... and shows toolbar (Android)", #078 "tap after a double tap select is not affected (macOS)", #085 "long press tap cannot initiate a double tap on macOS", #119 "text span with long press gesture recognizer works in selectable rich text", #072 (macOS). In each, offset, word selection and (Android) toolbar all match.
- Co-failing with GAP 3: #068, #070, #077, #093, #095, #096, #099.
- Masked: #094, #096 (3rd tap).

**GAP 3: iOS single-tap word-edge snapping is missing (G-TAP-GESTURES / word-edge).** Old iOS touch tap-up: `renderEditable.selectWordEdge` (`widgets/text_selection.dart:2696`) → nearest word boundary (12 for x=150, 7 for +50). New: `_collapseSelectionAt(details.globalPosition)` (`selectable_region.dart:950-957`) → raw hit offset (11 / 4).
- Exposed: #068 "tap moves cursor to the edge of the word it tapped" [4≠7], #070 "two slow taps ... on iOS", #072 (iOS), #077 "tap after a double tap select is not affected (iOS)", #093 (iOS), #095 (iOS), #096 (iOS), #099 "tap on non-force-press-supported devices work". Everything after the first tap in these tests (double-tap word select, tap-after-double-tap reset, long-press-then-tap suppression) works.

**GAP 4: Mobile "whitespace selects the previous word" rule is missing (G-TAP-GESTURES / whitespace).** `RenderEditable.getWordAtOffset` (`editable.dart:2238-2250`) extends a whitespace hit to the previous word on iOS (and on read-only Android). `_SelectableFragment._getWordBoundaryAtPosition` (`paragraph.dart:3190-3197`) uses the raw `getWordBoundary`.
- Exposed (directly at 9ca7895e3ab after the pump/harness fixes): #126 [`(5,6)` vs `(1,5)`], #128 [`(5,6)` vs `(1,5)`; `(13,15)` vs `(6,14)`], and #093's long-press-on-space step [`(7,8)` vs `(0,7)`].

**GAP 5: Keyboard extension reports base/extent swapped (G-KEYBOARD-ANCHOR-INVERTED).** Extending backward from a collapsed selection, `_determineIsAdjustingSelectionEnd` (`selectable_region.dart:1622-1638`, "always move the edge that increases the range") moves the START edge, and the adapter maps start→`baseOffset`. EditableText keeps base fixed and moves extent. Magnitude is correct; sign is inverted (`(10,11)` vs `(11,10)`). The owner TODOs "always extends forward" (lines 2115-2234) are imprecise: the extension does go backward.
- Exposed: #045 "Shift test 1", #047 "Control Shift test", #048 "Down and up test", #053 "Changing positions of selectable text", #054 "Changing focus test" (both variants each). Forward extension (#046, #050, #052) matches because the end edge is the extent.

**GAP 6: Plain arrow keys cannot move a collapsed selection (G-KEYBOARD-NAV).** `_GranularlyExtendCaretSelectionAction`/`_DirectionallyExtendCaretSelectionAction` return on `collapseSelection` intents ("Selectable region never collapses selection", `selectable_region.dart:2059-2062, :2075-2078`).
- Exposed: #049 "Down and up test 2": five `arrowRight` presses are ignored (caret stays at 0); the first four assertions pass by coincidence (vertical moves keep the column), the final shift+up from offset 0 does nothing (−5 expected, 0 actual). The head comment blames ArrowUp; the real cause is arrowRight.

**GAP 7 (CLOSED at 9ca7895e3ab for the noise part by e9f17a5b296; `cause` is still null): onSelectionChanged fires more than once per user action, cause is always null, transient `invalid` values (G-SELECTION-CALLBACK-NOISE + G-SELECTION-CAUSE).** The adapter forwards every `SelectionListenerNotifier` change (`selectable_text.dart:505-521`). `selectAll()` = `clearSelection()` + select-all event (`selectable_region.dart:1850-1852`) → `TextSelection.invalid` then `(0,11)`; `_collapseSelectionAt` = `_selectStartTo` + `_selectEndTo` (:1503-1508) → `(newStart, oldEnd)` then collapsed; desktop tap-down clears first (:766-767). `cause` is hard-coded `null` (:517/519); old code passed `SelectionChangedCause.tap/longPress/keyboard/toolbar`.
- Exposed at the audit head: #122 "The Select All calls on selection changed" (in-callback `isNull`), #125 (4≠3 calls). Both pass at 9ca7895e3ab; #052 and #123 pass with the assertion restored.
- Masked: #052, #123 (assertion deleted); #028 deleted the same assertion but there it would pass. No base test in the suite asserts `cause`, so G-SELECTION-CAUSE is latent everywhere.

**GAP 8: No text-field semantics (G-SEMANTICS, six work items).** `RenderParagraph.describeSemanticsConfiguration` (`paragraph.dart:1195-1240`) emits only `attributedLabel` + `textDirection`; SelectableRegion contributes nothing (gesture detector `excludeFromSemantics: true`, Focus `includeSemantics: false`, `selectable_region.dart:1983, :1987`). `RenderEditable` (`editable.dart:1330-1406`) plus EditableText's `Semantics(inputType, onCopy...)` (`editable_text.dart:5937-5941`) provided all of the below.
- 8a IDENTITY: no `isTextField/isReadOnly/isMultiline`, no `inputType: text`, text exposed as `label` not `value`. Exposed: #041 "Selectable text identifies as text field in semantics", #042 "... spell out ...", #043 "... locale ..." (attributes DO survive, but on `attributedLabel`), #044, #058 "SelectableText semantics", #060 "... enableInteractiveSelection = false", #062, #064 "Can activate SelectableText with explicit controller via semantics". Masked: #061, #063.
- 8b FOCUS: no `isFocusable/isFocused`; semantic long press does move focus (probe) but nothing reports it. Exposed: #041–#043, #058, #060, #064. Masked: #061, #063.
- 8c SELECTION-STATE: no `textSelection` on any node. Exposed: #061, #063 (current failure point), #058, #064.
- 8d SELECTION-ACTIONS: no `setSelection`, `moveCursor{Forward,Backward}By{Character,Word}`. Exposed: #063 (`performAction(setSelection)` no-ops), #061, #058, #064. Collapsed-caret semantics states in #058/#063/#064 also depend on GAP 9.
- 8e COPY-ACTION: no `SemanticsAction.copy` on the text node when selected (only the toolbar button). Masked: #061, #063.
- 8f SCROLL-NODE: the POC's `SingleChildScrollView` adds a `hasImplicitScrolling` node that EditableText excluded (`excludeFromSemantics: true`, `editable_text.dart:5914`); shifts node ids. Fixable inside `selectable_text.dart`. Exposed: #044, #058, #060, #062, #064; accepted in #061/#063.

**GAP 9: No caret (G-NO-CARET).** `showCursor`, `cursorWidth/Height/Radius/Color` are declared (`selectable_text.dart:130-145, :302-321`) and never read in build. SelectableRegion has no caret painting or blink timer; RenderParagraph paints only highlights; a collapsed selection paints nothing and creates no overlay/handle. Important correction to the initial assumption: a tap DOES place a collapsed selection at the tapped offset (see 2.4), so "tap clears" is not the gap; only painting and the caret-handle interaction are.
- Exposed: #013 "Cursor blinks when showCursor is true" (no surface fix exists; `EditableTextState.cursorCurrentlyVisible` has no counterpart).
- Masked: #007 (cursorColor assert deleted), #030 (caret-handle → toolbar path replaced), #109/#110 (painted caret rect → TextPainter offset). Related: #058/#061/#063/#064 collapsed-caret semantics states.

**GAP 10: Layout geometry (G-LAYOUT-SIZE), three sub-items.**
- 10a Caret margin removed: widget is `cursorWidth + 1` (3) px narrower, `cursorWidth` no longer affects layout, aligned text inside a fixed-width parent shifts by 1.5px (`editable.dart:1279, :2279-2282, :2414`). Masked: #009, #011, #102–#108, #032, #037, #038, #109, #110. Side effect: end-of-text taps now miss the region (#126, #127).
- 10b Baseline lost through the scroll view: `_RenderSingleChildViewport` deliberately returns a null baseline (`single_child_scroll_view.dart:482-485`); probe dry-baseline chain `RenderParagraph 9.65 → RenderMouseRegion 9.65 → _RenderSingleChildViewport null → ...`. Old `RenderEditable` scrolled itself and reported the text baseline (`editable.dart:1978-1981`). SelectionArea and the proxy boxes are not the blocker. Exposed: #056, #057 "SelectableText baseline alignment (no-strut)" [310 vs 299/295]. User-visible: a SelectableText in a baseline-aligned Row no longer aligns.
- 10c Default strut dropped: old passed `strutStyle ?? const StrutStyle()`, new passes `widget.strutStyle` (null). Contributes to the #129/#130 goldens (second, mixed-size line sits ~3px lower) and to #057's value; residual in #136.

**GAP 11: Selection highlight box styles (G-SELECTION-STYLE).** `selectionHeightStyle/selectionWidthStyle` are accepted (`selectable_text.dart:144-145, :335-340`) but `Text/RichText` have no such parameter and `_SelectableFragment.paintSelection` calls `getBoxesForSelection` with `tight/tight` (`paragraph.dart:3601-3616`); `RenderParagraph.getBoxesForSelection` does accept the styles (:1106-1118) but nothing at the widget layer feeds them. Old default was `includeLineSpacingMiddle` (`editable_text.dart:2085-2090`), so EVERY SelectableText highlight now renders differently, not only when the params are set. Also the per-platform default selection color (`theme.colorScheme.primary.withOpacity(0.40)` / Cupertino primary, `impl_base:706-741`) is gone in favor of `DefaultSelectionStyle.defaultColor` (#007 note; unasserted).
- Exposed: #129/#130 "text selection style 1/2" (golden, 1.31%, 56785px; master images for 1 and 2 are byte-identical, and so are the two head images). Needs new API (direction of PR #186802).

**GAP 12: Handles.**
- 12a Handles can cross (G-HANDLE-CLAMP): `_handleSelectionEndHandleDragUpdate` (`selectable_region.dart:1247-1262`) feeds raw edge updates; old `TextSelectionOverlay` refused order swapping (`text_selection.dart:855-856`, start-handle mirror :987; Apple platforms swap base/extent instead, :806-833). Exposed: #029 "Cannot drag one handle past the other" [`(4,2)` vs `(4,5)`].
- 12b Handle visibility (G-HANDLES-VISIBILITY): Android shows handles only on long-press END (:1014-1016, :1032; old: any long-press cause, `impl_base:643-660`). Masked: #019 (iOS-only variant; accepted, §7). **Corrected 2026-09-23 (groups/M_handle_visibility.md):** the off-screen-handle part is NOT a user-visible gap. SelectableRegion hides an edge's handle by unlinking its `LayerLink` when the point leaves the container's drawable area (`_updateHandleLayersAndOwners`, `selectable_region.dart:2766-2820`, 5px margin); RenderParagraph then pushes no `LeaderLayer` (`paragraph.dart:3623`) and the `CompositedTransformFollower(showWhenUnlinked: false)` handle is neither painted nor hit-testable. The check re-runs after every scroll and at every nested container (region root, SelectableText's own scroll view, a ListView under a SelectionArea). What differs from EditableText is only the mechanism: an instant unlink instead of a 150 ms fade, and a 5px margin instead of 0.5px. #092's `opacity == 0.0` assertion reads the fade that is never driven; the correct assertion is that the start handle's follower is unlinked (`RenderFollowerLayer.link.leader == null`) or not hit-testable. Recommended: accepted difference; update #092's assertion.
- 12c Handle-drag autoscroll (G-HANDLE-DRAG-AUTOSCROLL): see #033 in 3.2.

**GAP 13: Selection drag does not edge-scroll an ANCESTOR Scrollable (G-ANCESTOR-SCROLLABLE-EDGE-SCROLL).** `_ScrollableSelectionContainerDelegate` (`scrollable.dart:1171`) auto-scrolls only Scrollables that are descendants of the SelectionArea; SelectableText's own scroll view does edge-scroll (#092 probe endpoints `-924.1, 800.0`). Old builder tracked the ancestor scroll position (`text_selection.dart:2785-2806`) and called `bringIntoView` on iOS/macOS long press (`impl_base:611-625`). Probe: ancestor pixels stay 0.0; start endpoint +435/+449. Regression coverage for #129590 is broken.
- Exposed: #091 (linux/macOS/windows) fails directly on `isNegative` at 9ca7895e3ab (endpoints now read from the paragraph); #090 "long press drag can edge scroll when inside a scrollable" (iOS) still fails first on the toolbar.

**GAP 14: Touch drag on desktop does not select (G-DESKTOP-TOUCH-DRAG).** `_handleMouseDragStart/Update` return for non-precise devices (`selectable_region.dart:815-818, 828-831`); the old builder drag-selected with touch on desktop (base #091 passed with a touch pointer). Masked: #091 (`kind: mouse`).

**GAP 15: Force press unsupported (G-FORCE-PRESS).** No `ForcePressGestureRecognizer` in SelectableRegion (recognizers at :654-735); old iOS set `forcePressEnabled = true` (`impl_base:700`) → `selectWordsInRange` + toolbar (`text_selection.dart:2534-2545`). Exposed: #098 "force press selects word" [null vs `(8,12)`]. #097 passes by construction.

**GAP 16: `toolbarOptions` and the user's `contextMenuBuilder` are ignored (G-TOOLBAR-OPTIONS).** `toolbarOptions` (:360) is stored, never read; `_adaptContextMenuBuilder` (:657-666) always returns `AdaptiveTextSelectionToolbar.selectableRegion` and discards `widget.contextMenuBuilder` (an `EditableTextContextMenuBuilder`, which takes an `EditableTextState` and cannot be adapted 1:1). Old forwarded both (`impl_base:763`; `editable_text.dart:2657-2675`). Exposed: #022 "selectable text can disable toolbar options" [Copy present with `copy: false`; Share also present]. #137 passes partly by construction (SystemContextMenu can never be opted into).

**GAP 17: Overlay and MaterialLocalizations are hard requirements at build (G-OVERLAY-LOCALIZATION-REQUIREMENT).** `SelectionAreaState.build` asserts MaterialLocalizations (`material/selection_area.dart:125`), `SelectableRegionState.build` asserts Overlay eagerly (`selectable_region.dart:1957`); old SelectableText built under bare `MediaQuery + Directionality` and needed an Overlay only when a gesture created the overlay (`text_selection.dart:1100`). This is an API-contract change for minimal harnesses and embedders. Exposed: #001 (plus the build-time vs gesture-time error timing); #136 exposed it at the audit head and passes at 9ca7895e3ab with a MaterialApp harness. Masked: #004, #005, and the `boilerplate()` helper change that every `boilerplate`-based test now depends on.

**GAP 18: Selection updates from the web engine are dropped (G-WEB-ENGINE-UPDATE).** No `TextInput.attach` anywhere in SelectableRegion; `TestTextInput.updateEditingValue` goes to client −1. #124 is vacuous (branch compiled out by `@TestOn('!chrome')`, in base too; the base literal also has a latent `TextEditingValue` range assertion bug).

### 3.4 Suspected gaps that turned out NOT to be gaps (probe-verified)

- TextSpan gesture recognizers are not blocked: #118 "text span with tap gesture recognizer ..." passes; in #119 the span's `LongPressGestureRecognizer` wins the arena (its pointer is added first via `RenderParagraph.hitTestChildren`, `paragraph.dart:842`; same timeout) and only affinity fails. The TODOs at lines 5381, 5443, 5501 are wrong.
- Tap-after-double-tap reset, long-press-then-tap double-tap suppression, tap-on-active-selection toolbar toggle (iOS), custom `selectionControls` toolbars (#081/#082, via the legacy `buildToolbar` path, `selectable_region.dart:1383-1386`), long-press-drag word granularity on every platform including iOS/macOS (old SelectableText was read-only so it already used word granularity), toolbar after a macOS touch long press, keep-alive (#131), MediaQuery text overrides (#136 body), inline-span link semantics incl. `isHidden`/`showOnScreen` (#044/#062), Android long-press/double-tap toolbar button set (#080, #087, #073).

---

## 4. Owner TODO comments that are stale or misattributed (head test file line numbers)

| line | comment says | reality |
|---|---|---|
| strut preamble (before #102) | heights not reserved, tests kept failing | All seven pass; heights match; only widths were edited (−3) |
| 556 | "#014 might not show Select all" | #014 passes |
| 2115, 2153, 2214, 2231, 2234 | "always extends forward" | Extends backward correctly; base/extent are swapped |
| #049 inline comment | ArrowUp at top line unsupported | The five plain arrowRight presses are ignored; shift+up from 0 then has nothing to extend |
| 3594 | #076 fails (span semanticsLabel) | #076 passes |
| 5381, 5443, 5501 | SelectionArea intercepts span tap / long-press recognizers | Recognizers fire; #118 passes, #119 fails only on affinity |
| 5802 | #127 space selection unsupported on non-mobile | Surface only (pump + 1px edge tap); passes with those |
| 6018 | keep-alive not implemented | Implemented in b73a681e605; #131 passes |
| 699-707 (Android handles on long-press end) | attached to #019 | Accurate, but the iOS-only variant it justifies is what masks the Android gap |
| 165, 246, 804, 4295, 5532, 5592, 5745/5795/5869/5936 | toolbar buttons, Localizations, toolbarOptions, ancestor edge scroll, Select-all rule, callback noise, whitespace rule | Accurate (for 5745–5936 the current failure point is the missing pump/harness, the gap sits behind it) |

## 5. Suggested test-side housekeeping (no behavior masked, verified to pass)

Restore `expect(newSelection, isNull)` in #028; harden #016/#017 with `find.byType(SelectableRegion), findsNothing`; move #021's `hasAnyClients` check after the gestures; drop the extra tap in #002 and the `pump(1s)` in #090; remove the `Material/Center` wrapper from #126; fix #034 via `ScrollConfiguration.of`; add the registration pump to #125/#126/#127/#128 and nudge #127's edge taps; change #054's `selection2!` line to `expect(selection2, isNull)`; #062's hard-coded node id 8 → lookup by label; #136 harness → MaterialApp. Decide explicitly whether to keep the 3px-narrower width (10a) and, if so, note it in the migration notes rather than silently re-baselining.

## 6. Per-test index

See `per_test_index.md` (now carries both heads: status at ece56299239 and at 9ca7895e3ab, plus whether the test was edited by the review) (generated from the group reports: status, change status, verdict, classification, gap ids, one-line root cause per test) and `groups/*.md` for full evidence.

---

## 7. Human review: intentional change or oversight, per fake-fix edit

**Applied 2026-09-23.** Every row below carries the author's verdict, and the agreed actions landed as
21 test-file commits (c603eebeedc..bd48ac246d6, plus 9ca7895e3ab for an analyzer info on the restored
#052). The two implementation changes from §8 landed as e9f17a5b296 (dispatcher) and 881f512d507
(keep-alive relocation). Head after applying: 9ca7895e3ab. Each commit body records the observed
outcome of the tests it touched.

Method: every fake-fix edit from sections 2.1 and 2.2 was traced across the 26 branch commits to
find the commit that introduced it, whether it was ever reverted and re-applied, and whether a
commit message or inline comment explains it. "Claude inference" is a reading of that history, not
a statement of the author's intent; the **Author verdict** column is for the branch owner.

Two branch events explain most of the pattern:

- **Reasoned reversal.** `6b5b22707ff` ("final migration/revert bad fixes that were legitimate behavioral
  gaps") restored the original widths in #009/#011, i.e. the author first judged the 3px change to be
  a masked gap. The final commit `ece56299239` re-applied it with a detailed rationale (caret margin is
  legacy, RenderParagraph reports exact width; 3.0 / 1.5 / 1.0px deltas derived). That is a deliberate
  decision, documented in the commit body.
- **Lost batch revert.** `df9a2fb3bfd` ("more test reverts-need verification") restored a set of original
  expectations (affinity in #094 and #096 with a TODO "SelectableRegion does not expose selection
  affinity", unconditional macOS toolbar checks in #072/#095/#096, removal of the `Center` wrapper in
  #126 and the `pump(1s)` in #090, the original #013 body). `396c7cb7856` then reverted that whole commit.
  `13e660c9de7` afterwards re-applied only the macOS toolbar flips, on purpose. Everything else that
  `df9a2fb3bfd` had restored was lost as collateral and never redone.

| # | edit | introduced by | history | Claude inference | decision for the author | Author verdict |
|---|---|---|---|---|---|---|
| 009, 011 | widths −3.0 | `b130367b2ba` initial refactor | reverted in `6b5b22707ff`; re-applied in `ece56299239` with rationale | **Intentional** (reasoned reversal) | Accept the 3px-narrower widget as the new contract and record it in migration notes, or treat "cursorWidth affects layout" as a gap | **Accepted** (2026-09-23): the 3px-narrower widget (no `_caretMargin`, `cursorWidth` no longer affects layout) is the new contract. Action: add a comment; none of #009, #011, #102–#108, #032 has one today (the rationale lives only in commit ece56299239), and #037/#038/#109/#110 mention "caret" only in code, not in a comment. A single shared comment above the strut group plus one-liners on the others is enough; also delete the stale strut preamble |
| 102–108 | widths −3.0 | `ece56299239` | single commit, explicit rationale | **Intentional** | Same as above; also delete the stale strut preamble comment that says these tests are kept failing | **Accepted** (2026-09-23), see the #009/#011 row |
| 032, 037, 038 | +1.5 / +1 px | `ece56299239` (037/038 API swap earlier in `613bfeac1c7` kept 399) | explicit rationale (§2, §3 of the commit body) | **Intentional** | Same as above | **Accepted** (2026-09-23), see the #009/#011 row |
| 109, 110 | +1 px and `getLocalRectForCaret` → `getOffsetForCaret` | numbers `ece56299239`; API swap `b130367b2ba` | rationale covers the numbers, not the downgrade from painted caret rect (clamped, snapped) to TextPainter offset | **Intentional for the numbers; likely oversight for the assertion downgrade** | Decide whether caret-placement/clamping behavior is out of scope (no caret) and rename the tests accordingly, or keep them failing under G-NO-CARET | **Accepted for the numbers** (2026-09-23), see the #009/#011 row. The caret-rect → TextPainter-offset downgrade follows the #007 decision (no caret by design): note it in the same comment |
| 072, 075, 095, 096 | macOS toolbar check flipped to `findsNothing` (#096 ×3) | `b130367b2ba` (072/075), `13e660c9de7` (095/096) | 072/075 reverted in `e691619b70e` and `df9a2fb3bfd`, re-applied in `13e660c9de7` "SelectableRegion does not wire up toolbar to be shown on touch interaction for macOS" | **Intentional**, but the commit message overstates it: a macOS touch long press does show the toolbar; only the touch double tap does not (`selectable_region.dart:983-989`) | Is "no toolbar on macOS touch double tap" accepted SelectableRegion behavior (then keep the flips and reword the comments) or a gap (then restore the original checks so the tests fail once affinity is fixed)? | **Accepted, low/no severity** (2026-09-23): macOS has no touch input, so touch double-tap on macOS is never exercised on a physical device. Action: add a comment at each flipped assertion (none of the four has one today) and correct the 13e660c9de7 wording (long press does show the toolbar). Note: this rationale does not cover the deleted mid-hold check in #075, which also applies to iOS |
| 075 | mid-hold `expectCupertinoSelectionToolbar()` deleted | `b130367b2ba` | never restored by any revert commit | **Oversight** (the toolbar-on-tap-up vs tap-down timing difference was never called out) | Restore the mid-hold check (it will fail: toolbar appears on 2nd tap-up) or document the timing change | **Accepted** (2026-09-23): the toolbar appearing on the second tap-up (SelectableRegion convention) rather than on tap-down is acceptable on iOS. The post-release `expectCupertinoSelectionToolbar()` already exists in the head test, so only the duplicate mid-hold check was dropped. Action: add a comment at the hold explaining the timing. Reclassified from oversight to intentional |
| 094 | `affinity: upstream` dropped | `b130367b2ba` | restored in `df9a2fb3bfd` with a TODO; lost in the wholesale revert `396c7cb7856` | **Oversight** (collateral of the lost batch revert; inconsistent with #077/#078/#085 "KEEP original assertion") | Restore the affinity expectation | **Restore** (2026-09-23): put `affinity: TextAffinity.upstream` back and add a note that the test also fails on the macOS toolbar button count (G-TOOLBAR-PLATFORM) and on the whitespace long-press rule where applicable |
| 096 | 3rd-tap `collapsed(1, affinity: upstream)` dropped | `b130367b2ba` | same as #094 | **Oversight** (same) | Restore | **Restore** (2026-09-23): same as #094; note the iOS word-edge snap, affinity, and toolbar button-set gaps in a comment |
| 061, 063 | text-field flags, `inputType`, `moveCursor*`, `setSelection`, `copy` removed; collapsed-caret start state replaced | `90306e697b3` "Refactor Group 3 and skip semantics" | skips removed in `a1f0985bdf7` but expectations never restored; `e691619b70e` message says "semantics test still need to be reverted" | **Acknowledged, pending work** (not an oversight, not finished) | Restore the original expectations so all six semantics work items are exposed, not only `textSelection`/`setSelection` | **Restore** (2026-09-23): revert everything except the surface-level API/finder swaps (controller → onSelectionChanged, `pump()`, node-id lookup) |
| 007 | `cursorColor` assertion deleted, "and cursor" dropped from the name | `b130367b2ba` | never revisited | **Oversight** (inconsistent with #013, which was deliberately left failing for G-NO-CARET) | Restore as a failing assertion or split into a second documented-gap test | **Intentional** (2026-09-23): static text should not show a cursor; the old `cursorColor` behavior was a side effect of EditableText. Assertion removed on purpose. Follow-up: apply the same reasoning to #013 (currently kept failing) and to the #109/#110 caret-rect downgrade, i.e. treat the cursor API as removed-by-design and document it, rather than as an open gap |
| 019 | `variant: only(iOS)` | `fae7162b7f2` "Reapply manual reverts, remove obsolete TODO, and clean up" | the explanatory comment (lines 699-707) was written in the same commit | **Intentional**, but it masks the Android difference instead of exposing it | Is "Android shows handles only on long-press end" accepted or a gap? If a gap, add an Android variant that fails | **Accepted** (2026-09-23): SelectableRegion's Android convention (handles on long-press end) matches native Android more closely than the old EditableText behavior; the iOS-only variant is the correct adaptation and the existing comment (test file lines 699-707) documents it. Reclassified from fake fix to intentional |
| 030 | tap → tap-caret-handle path replaced by `longPressAt` | `b130367b2ba` | never revisited | **Oversight** (no comment; the Select all / Copy values were preserved, so it reads as a driver swap) | Decide whether the caret-handle toolbar toggle is out of scope (no caret) and note it, or keep a failing test | **Intentional** (2026-09-23): static text has no collapsed caret, so the caret-handle toolbar toggle was a side effect of the EditableText implementation; changing the entry path to a long press is the right expectation. Action: add a comment saying so |
| 091 | `kind: PointerDeviceKind.mouse` added | `b130367b2ba` (test renamed later, which confused blame) | never revisited | **Probably intentional** given the test title, but the masked touch-on-desktop difference is undocumented | Is "touch drag on desktop does not select" accepted SelectableRegion behavior? If not, add a touch variant | **Accepted by design** (2026-09-23): `kind: mouse` is correct; SelectionArea-wide, a touch drag pans and touch selection uses long-press drag (available on desktop too). Add a comment. Keep the test failing for G-ANCESTOR-SCROLLABLE-EDGE-SCROLL: autoscroll is driven by `_ScrollableSelectionContainerDelegate`, which only a Scrollable *inside* the SelectionArea installs; there is no bridge to an ancestor Scrollable yet (old path used `bringIntoView` → `showOnScreen`, which propagates through ancestor viewports). First switch the endpoint source from `selectionOverlay` (never created on desktop drag) to `RenderParagraph.getBoxesForSelection` so it fails on the `isNegative` assertion |
| 052 | in-callback `expect(newSelection, isNull)` dropped | `b130367b2ba` | never revisited; sibling #122 keeps it and carries a "noisy callback" TODO | **Oversight** | Restore; see §8 (prototype dispatcher makes it pass with the assertion restored) | **Restore** (2026-09-23): bring back the once-per-change `expect(newSelection, isNull)` so the test matches its siblings 122/125; keep only the surface-level API/finder changes; add a comment. Expected to pass once the §8 dispatcher lands |
| 123 | same as #052 | `33455443f32` "test part 2" | never revisited | **Oversight** | Restore; see §8 (prototype dispatcher makes it pass with the assertion restored) | **Restore** (2026-09-23): same as #052 |
| 004, 005 | bare harness → `boilerplate()` | `b130367b2ba` | `boilerplate()`'s Overlay is documented in `5384770697f`; the Localizations requirement is noted in the #001 TODO | **Intentional**, low severity | Nothing beyond #001; optionally note the new build-time requirements in migration notes | **Intentional** (2026-09-23). Action: document what the switch surfaces; see §7.1 |
| 124 | `kIsWeb` branch translated to `SelectedContentRange(2,7)` | `33455443f32` | never revisited; branch is dead under `@TestOn('!chrome')` in base and head | **Oversight** (vacuous translation) | Origin: PR #65127 (2020-09-09) "[web] Don't show handles when selection change is caused by keyboard". Old read-only EditableText opened a TextInputConnection on web and macOS (`editable_text.dart:2614-2615`), so browser-side keyboard selection came back through `updateEditingValue`; the test guarded "no handles for that path". SelectableRegion opens no input connection (web integration is only `PlatformSelectableRegionContextMenu`, `selectable_region.dart:531/547/1963`) and handles keyboard selection itself without showing handles. Decide: obsolete-by-design (delete the branch with a comment) or keep as documented gap | **Obsolete** (2026-09-23): the engine-pushed selection path no longer exists (no TextInputConnection). Action: mark the test `skip:` with a comment explaining why, rather than keep the vacuous translation |

Weakened-but-harmless edits (section 2.3), for completeness: #016/#017 vacuous `null` assertion
(`90306e697b3`), #021 `showKeyboard` removal and #028 dropped `isNull` (`b130367b2ba`), #090 `pump(1s)` and an added, never-read `ScrollController` on the outer scroll view (`b130367b2ba`; the base test had no controller; the pump was removed by `df9a2fb3bfd` and lost in the wholesale revert), #126 `Material(child: Center(...))` wrapper (same history as #090; verified 2026-09-23: neither `SelectionArea` nor `SelectableRegion` asserts a `Material` ancestor, only `MaterialLocalizations` (`selection_area.dart:125`) and an `Overlay` (`selectable_region.dart:1957`), both of which `MaterialApp` provides, so the base `MaterialApp(home: SelectableText(...))` harness is sufficient; the `Center` is what shrink-wraps the region and makes the end-of-text tap miss today; `Material` is harmless but unnecessary), #002 extra tap (`b130367b2ba`),
#039 second-tap location (`fae7162b7f2`). All are oversight-class and safe to restore.

Author verdicts (2026-09-23): #126 drop both the `Material` and the `Center` wrapper (back to the base `MaterialApp(home: SelectableText(...))` harness) and add the registration `pump()`, so the test fails on the whitespace rule it exists for. #090 remove the unused `ScrollController` and revert `pump(1s)` to the original `pump()`. #039 revert the second-tap location to the original `tester.getTopLeft(find.byType(SelectableText).last)` (verified to pass). #016/#017 keep as is. #021 remove the "cannot open keyboard" contract entirely, including the `hasAnyClients` check (the text-input connection no longer exists in the new architecture; the tap/handles and long-press/toolbar contracts stay). #028 restore the in-callback `expect(newSelection, isNull)` (verified to pass). #002 delete the added `tap` and reword the comment on the remaining `pump()` to say it lets the selectables register.

### 7.1 What the `boilerplate()` switch surfaces (#004, #005)

Scope. Eight tests use `boilerplate()` at head: six already did at base (#003, #009, #010, #011, #012,
#034) and two were switched to it (#004 "Rich selectable text has expected defaults", #005 "Rich
selectable text supports WidgetSpan"). The helper itself changed in one way: `Overlay.wrap` was added
around `Center(child: Material(...))`. It already carried `Localizations` with the Widgets and Material
delegates at base.

What the change absorbs, in order of how early it fires:

1. **MaterialLocalizations is now required at build.** `SelectionAreaState.build` asserts
   `debugCheckHasMaterialLocalizations` (`material/selection_area.dart:125`). Old SelectableText built
   an `EditableText` with no localizations dependency. This is the first error a bare
   `MediaQuery + Directionality` harness hits (#001, #004, #005, #136 originals). Only #004/#005
   needed the switch for this reason; the six pre-existing users already had the delegates.
2. **An Overlay is now required at build, not at first gesture.** `SelectableRegionState.build` asserts
   `debugCheckHasOverlay` (`selectable_region.dart:1957`). Old SelectableText only needed an Overlay when
   a gesture created the selection overlay (`widgets/text_selection.dart:1100`). This is why the helper
   gained `Overlay.wrap` for all eight users, including layout-only tests such as the strut and
   textWidthBasis tests that never touch selection.
3. **Error timing and side effects changed.** Because both checks fire during build, a missing
   ancestor turns the subtree into an ErrorWidget immediately; there is no half-constructed overlay
   state, so unmounting throws nothing. #001's final `expect(tester.takeException(), isNotNull)` depends
   on the old lazy behavior and cannot be satisfied by any harness change.
4. **Not surfaced by the switch, but worth knowing:** MaterialApp/Material remain optional for the
   widget itself (Material only affects ink/theme), and `Theme(useMaterial3: false)` in the helper is
   inherited unchanged from base.

Consequence for embedders and minimal harnesses: any widget tree that mounts a SelectableText without
a MaterialApp (or an explicit `Localizations` with `DefaultMaterialLocalizations` plus an `Overlay`)
now fails at build. This is gap G-OVERLAY-LOCALIZATION-REQUIREMENT, and it is a public API-contract
change that should be called out in the migration notes independently of the tests.

---

## 8. Investigation: gating `onSelectionChanged` on `SelectableRegionSelectionStatus` (2026-09-23)

**Landed as e9f17a5b296** (the recommended `status_gating.patch`).

Question from the branch owner: would dispatching `onSelectionChanged` only when the enclosing
SelectableRegion's status is `finalized` remove the callback noise (GAP 7)? Prototyped in an isolated
worktree (`$S/wt-status`, left in place); full write-up in `groups/L_status_gating.md`, patches in `patches/`.

**Short answer: the idea is right, the literal trigger is wrong.** Reporting on the status notifier
fixes the noise, but it has to fire on every status notification (`changing` and `finalized`), not on
the `finalized` value.

- **Gating on the current status value cannot work.** Every noisy intermediate notification fires while
  the status still holds the stale `finalized` from the previous gesture (initial value is `finalized`).
  Handlers set `changing` only after they have applied all their selection events: for a touch tap the
  order is `_collapseSelectionAt` (two edge notifications) → `value = changing` (`:957`) → finalized (`:992`).
  `_finalizeSelection()` (`:1568`) never touches the status; only `_finalizeSelectableRegionStatus()`
  (`:594-600`) does. Measured: 052/122/123/125 still fail, and 024 newly fails because mid-drag updates
  arrive under `changing`.
- **Reporting only on the transition to `finalized`** fixes 122 and 125 but moves every callback to
  gesture end. Newly failing: 024 "Continuous dragging does not cause flickering", 075 (macOS), 076
  "double tap selects word with semantics label" (iOS), 087 (android, fuchsia, linux, windows); seven
  already-failing tests fail earlier (029, 075 iOS, 088, 089, 090, 092 iOS and android). It also exposes a
  framework bug: an iOS touch double tap whose second tap-up lands on the new word takes the
  "tap on active selection" early return in `_handleMouseTapUp` (`:937-948`) and never calls
  `_finalizeSelectableRegionStatus()`, leaving the region stuck at `changing` (one-line fix in
  `patches/status_gating_ios_finalize_fix.patch`; worth landing independently).
- **Recommended design (`patches/status_gating.patch`, `selectable_text.dart` only):** a private
  `_SelectionChangedDispatcher` inside the `SelectionArea` child owns the `SelectionListener`, subscribes
  to `SelectableRegionSelectionStatusScope.maybeOf(context)`, and on every status notification reads the
  latest `SelectedContentRange` and reports it if it differs from the last reported value. Because every
  gesture and keyboard handler notifies the status synchronously after its last edge update, this yields
  exactly one callback per user step at the same moment the old EditableText fired (desktop tap-down,
  long-press start, each drag/handle update, each key). Changes that no status notification follows
  (programmatic `clearSelection()`, gesture cancel, post-frame continuous edge updates) are flushed in a
  microtask.
- **Result on the suite:** newly passing 122 (android, fuchsia) and 125; 052 and 123 pass with their
  original once-per-change assertions restored (`patches/status_gating_tests.patch`); newly failing:
  none; no still-failing test changed its failure message. Sequences before → after: tap onto a selection
  `(1,7), c(1)` → `c(1)`; Select all `invalid, (0,11)` → `(0,11)`; desktop click with a selection
  `invalid, c(5)` → `c(5)`; right-click inside a selection `(5,11), c(5)` → `c(5)`. Mouse drag,
  long-press drag, handle drag and keyboard extension are unchanged in timing.
- **Costs:** an action that reproduces the identical selection (long press on the already-selected word)
  no longer fires (old EditableText re-fired for longPress/keyboard causes; no test covers it; drop the
  equality check if parity matters). Programmatic/cancel clears arrive in a microtask. `cause` stays
  `null` because the status carries no gesture kind (G-SELECTION-CAUSE unchanged).
- **Simpler alternative:** microtask-only coalescing with no status dependency gave identical sequences
  on the targeted tests and probe (not run on the full suite); it is always asynchronous and relies on
  the implicit "one user step = one synchronous handler" contract. Post-frame coalescing breaks 125.
  Filtering on `SelectionDetails.status` cannot distinguish `(newStart, oldEnd)` from a real range.

Effect on this audit if adopted: GAP 7 (callback noise) closes; rows 052 and 123 in §7 should be
resolved as "restore the assertion, fixed by the dispatcher"; 122 and 125 leave the failing set.

### 8.1 Keep-alive relocated from SelectableRegion to SelectableText (2026-09-23)

**Landed as 881f512d507** (SelectableRegion restored to its base form; mixin in `_SelectableTextState`).

Question: can the focus-keyed keep-alive that commit b73a681e605 added to `SelectableRegionState`
(framework-wide, every focused SelectionArea in a lazy list) live in `_SelectableTextState` instead?

Background. The existing `_SelectionKeepAlive` that sliver delegates wrap around every lazy-list item
(`scroll_delegate.dart:570/784/1125/1210`) keeps an item alive only while a selectable that registered
through it has a selection. It does not cover a SelectableText item: a `SelectableRegion` is a
selection root and never registers upward, so nothing registers through the item's wrapper, and the
old SelectableText kept itself alive on focus (EditableText's `wantKeepAlive => focusNode.hasFocus`),
not on selection.

Experiment (worktree `$S/wt-status`, on top of the §8 dispatcher): `selectable_region.dart` restored to
the base commit (keep-alive removed), and `_SelectableTextState` given
`with AutomaticKeepAliveClientMixin<SelectableText>`, `wantKeepAlive => _effectiveFocusNode.hasFocus`,
a focus listener calling `updateKeepAlive()` (added in `initState`, swapped in `didUpdateWidget` when
`focusNode` changes, removed in `dispose`), and `super.build(context)` at the top of `build`.
Patch: `patches/keepalive_moved_to_selectable_text_plus_dispatcher.patch` (includes the §8 dispatcher).

Results:
- #131 "keeps alive when has focus" passes.
- Negative control: forcing `wantKeepAlive => false` makes #131 fail (`Found 0 widgets with type
  "SelectableText"`), so the test is sensitive and the SelectableText-side mixin is what satisfies it.
- Full suite: 82 failing entries vs the 85-entry baseline; newly failing none; newly passing only the
  three the dispatcher already accounts for (122 android/fuchsia, 125).

Conclusion: yes. SelectableText owns its focus node, so keying keep-alive on it inside SelectableText
restores exact parity with the old EditableText-based behavior without changing SelectionArea for
anyone else. Recommend reverting the `selectable_region.dart` part of b73a681e605 and carrying the
mixin in `selectable_text.dart`; decide separately, on its own merits, whether SelectionArea should
keep focused regions alive.

Why leaving the keep-alive in SelectableRegion is a concern (recorded 2026-09-23):
- **Unrequested behavior change for every SelectionArea user.** The mixin applies to all
  `SelectableRegion`/`SelectionArea` instances, not only the ones SelectableText builds. Apps that
  place a SelectionArea per lazy-list item (chat bubbles, feed cards, search results) get new
  keep-alive behavior without opting in, and there is no flag to opt out.
- **Focus is a very broad trigger for a region.** SelectableRegion requests focus on nearly every
  interaction (`_focusNode.requestFocus()` in tap, long-press and drag handlers), so a single tap on
  an item pins it alive when scrolled off-screen until something else takes focus, even when nothing
  is selected. A kept-alive item stays mounted with its whole subtree: state objects, listeners,
  streams, tickers and images keep running; only layout and paint stop.
- **SelectionArea wraps large subtrees by design.** The typical SelectionArea child is a page or a
  rich content block, so the cost of keeping one alive is much higher than for an EditableText,
  which wraps a single text field.
- **It duplicates a narrower mechanism that already exists.** Sliver delegates already wrap every
  lazy-list item in `_SelectionKeepAlive`, which keeps an item alive only while it holds part of a
  selection. That is the right criterion for selection state. A focus-based rule at the region level
  keeps alive focused-but-unselected regions for no user-visible benefit.
- **The EditableText precedent does not transfer.** EditableText keeps itself alive because it owns
  editing state that cannot be reconstructed (text input connection, composing region, IME state).
  A SelectableRegion owns only a selection, which is cheap to lose and is already preserved by
  `_SelectionKeepAlive` when it matters.
- **Scoping it to SelectableText restores exact parity at zero cost to others.** SelectableText owns
  its focus node, so a focus-keyed mixin in `_SelectableTextState` reproduces the old behavior for
  the one widget that had it (§8.1 experiment). If SelectionArea should ever keep focused regions
  alive, that deserves its own design (for example `hasFocus && hasSelection`, or an opt-in flag)
  rather than arriving as a side effect of this migration.

---

## 9. API-availability triage of the open gaps (2026-09-23)

Which open gaps can be closed inside `selectable_text.dart` with APIs that already exist in this
checkout, versus which need framework work. APIs were verified in the tree.

**A. API exists, not wired in SelectableText.**
- GAP 1 toolbar button set / Select-all rule and GAP 16a `toolbarOptions`: build the item list in
  `_adaptContextMenuBuilder` from `SelectableRegionState.contextMenuButtonItems` (public, `:1704`),
  `ContextMenuButtonItem` with `ContextMenuButtonType.{lookUp, searchWeb, share, selectAll}` and
  `AdaptiveTextSelectionToolbar.buttonItems`; hide `selectAll` when the listener range covers the whole
  text; add the iOS items using the same `SystemChannels.platform` calls EditableText uses
  (`LookUp.invoke` / `SearchWeb.invoke` / `Share.invoke`, `editable_text.dart:2951-2988`); filter by
  type for `toolbarOptions`.
- GAP 8e copy action: `Semantics(onCopy:)` → public `SelectableRegionState.copySelection`.
- GAP 8a/8b flags and focus (`textField`, `readOnly`, `multiline`, `inputType`, `focusable`,
  `focused`): `Semantics` wrapper; SelectableText owns the focus node. (`value` vs `label`: see C.)
- GAP 10c default strut: restore `widget.strutStyle ?? const StrutStyle()`.
- GAP 17 MaterialLocalizations: use `SelectableRegion` directly instead of `SelectionArea` (SelectableText
  already supplies controls, magnifier and context menu). The Overlay assertion stays by design.
- GAP 13 ancestor edge scroll: `RenderObject.showOnScreen` on the moving edge's caret rect from the
  status-driven dispatcher's `changing` notifications (`SelectableRegionState.bringIntoView` is an empty
  stub, `:1886`). Medium risk of interaction with the internal `EdgeDraggingAutoScroller`.
- GAP 5 keyboard sign, mitigation only: in the dispatcher, report the edge that changed as
  `extentOffset`. Fixes 045/047/048/053/054; sequences where the region grows the range rather than
  moving the anchor still differ, so the real fix stays in SelectableRegion.

**A2. No new framework API, but a small custom render object in SelectableText.**
- GAP 10b baseline: a private single-child viewport driven by `Scrollable` that returns the child's
  baseline minus the scroll offset (`SingleChildScrollView`'s viewport returns null by design).
- GAP 8f scroll semantics node: the same viewport built with `Scrollable(excludeFromSemantics: true)`
  (`SingleChildScrollView` does not expose the flag).

**B. API exists, wiring belongs in SelectableRegion.**
- GAP 12b off-screen handle fade: withdrawn (see §3.3 12b correction). Handles are already hidden by
  layer unlinking; only the fade animation differs. Test-side change to #092, no framework work.
- iOS stuck-`changing` after a double tap: `patches/status_gating_ios_finalize_fix.patch`.

**C. Needs new API or a behavior change in SelectableRegion / RenderParagraph.**
- GAP 2 affinity: `SelectedContentRange` has offsets only.
- GAP 3 iOS word-edge snap, GAP 6 arrow keys, GAP 15 force press, GAP 8d `setSelection`/`moveCursor*`:
  no public way to place or move a selection by offset/position (`_collapseSelectionAt`, `_selectWordAt`
  private; the region's `userUpdateTextEditingValue` is a delegate stub).
- GAP 4 whitespace-selects-previous-word: `_SelectableFragment` word boundary.
- GAP 5 keyboard anchor model (real fix): `_determineIsAdjustingSelectionEnd`.
- GAP 8a `value` instead of `label`: RenderParagraph emits a label; `ExcludeSemantics` would drop the
  link children guarded by 044/062.
- GAP 11 selection box styles / default highlight: `DefaultSelectionStyle` in this tree has only
  `cursorColor`, `selectionColor`, `mouseCursor`; PR #186802 adds the box styles (not landed here).
- GAP 12a handle clamping, GAP 12c handle-drag autoscroll overshoot: region drag logic and
  `EdgeDraggingAutoScroller`.
- GAP 16b `contextMenuBuilder`: typed `EditableTextContextMenuBuilder` (takes `EditableTextState`);
  needs a new builder type.

---

## 10. Open gaps by fix location, for filing issues (2026-09-23, head 9ca7895e3ab)

Excludes gaps accepted or closed during the review (no caret, caret margin, macOS touch double-tap
toolbar, Android handles on long-press end, desktop touch drag pans, web-engine updates, callback
noise, keep-alive). Cross-layer items are listed under the primary layer with the secondary piece named.

**Fix in SelectionArea / SelectableRegion** (benefits every SelectionArea user)
- iOS single-tap word-edge snapping (`_handleMouseTapUp` vs `selectWordEdge`); needs a word-edge
  selection event handled by RenderParagraph. Tests 068, 070, 077, 099; iOS variants of 072, 093, 095, 096.
- Keyboard extension moves the wrong edge (`_determineIsAdjustingSelectionEnd` grows the range instead
  of keeping an anchor). Tests 045, 047, 048, 053, 054.
- Plain arrow keys cannot move a collapsed selection (collapse intents dropped). Test 049.
- Handles can cross (`_handleSelectionEndHandleDragUpdate`; `TextSelectionOverlay` clamps/swaps). Test 029.
- (withdrawn) Off-screen handles: already hidden by layer unlinking; mechanism differs (instant vs fade). Test 092 assertion to change.
- Handle drag past the edge overshoots (scrollable selection delegate + `EdgeDraggingAutoScroller`). Test 033.
- No edge scroll of an ancestor Scrollable (no bridge to parent scroll views; old path `showOnScreen`).
  Tests 090, 091. SelectableText workaround possible via `showOnScreen`.
- Force press does not select (no `ForcePressGestureRecognizer`). Test 098.
- No `SelectionChangedCause` exposed to listeners. Latent.
- Status stuck at `changing` after an iOS double tap (`patches/status_gating_ios_finalize_fix.patch`).
- Toolbar items not platform-aware (`getSelectableButtonItems`: no Look Up / Search Web / Share on iOS,
  Select all always offered). Tests 079, 086, 088, 089, 090, 092, 094, 121; behind 072/075/093/095/096/098.
  SelectableText can also fix its own menu (next list).
- Programmatic selection API (set/move a selection by offset); prerequisite for semantics actions and
  arrow keys. Tests 058, 061, 063, 064.

**Fix in SelectableText**
- Toolbar menu contents via `_adaptContextMenuBuilder` (hide Select all when all selected, iOS items
  through the platform channels, honor `toolbarOptions`). Toolbar tests above; 022.
- `contextMenuBuilder` ignored: typed `EditableTextContextMenuBuilder`; needs a SelectableText builder
  type or documented replacement. Test 022; 137 passes by construction.
- Baseline lost through `_RenderSingleChildViewport`: custom viewport forwarding the paragraph baseline.
  Tests 056, 057.
- Extra `hasImplicitScrolling` node: same viewport built with `excludeFromSemantics: true`.
  Tests 044, 058, 060, 062, 064.
- Semantics flags, focus and copy action via a `Semantics` wrapper on the owned focus node.
  Tests 041–044, 058, 060, 061, 063, 064.
- Default `StrutStyle()` no longer applied. Contributes to 057, 129, 130.
- Platform-default selection color (primary at 40%) lost. Untested; noted at 007.
- MaterialLocalizations required at build: use `SelectableRegion` directly. Test 001.
- `selectionHeightStyle`/`selectionWidthStyle` plumbing once the API below exists. Tests 129, 130.

**Fix in Text / RichText / RenderParagraph (or the selection API beneath)**
- No `TextAffinity` in `SelectedContentRange` (`_SelectableFragment` drops it, `paragraph.dart:1656-1663`;
  field needed in `rendering/selection.dart`). Tests 069, 071, 073, 078, 085, 119, macOS 072; co-failing
  068/070/077/093/095/096/099.
- Whitespace selects the previous word on mobile (`_getWordBoundaryAtPosition` vs
  `RenderEditable.getWordAtOffset`). Tests 126, 128, a step of 093.
- Selection highlight box styles and default highlight (always tight; old default
  `includeLineSpacingMiddle`); direction of PR #186802. Tests 129, 130.
- Text exposed as semantics `label` instead of `value` while keeping inline-span child nodes.
  Tests 041–044, 058, 060–064.
- `textSelection` and `setSelection`/`moveCursor*` on the paragraph node; depends on the programmatic
  selection API. Tests 058, 061, 063, 064.
- Word-edge selection event (secondary piece of the iOS snapping item).

Filing order suggestion: affinity, programmatic selection API, and value-semantics first (they are
prerequisites); toolbar and edge-scroll items next (most tests); the rest as parity items. Several
SelectableRegion items are policy questions ("should SelectionArea behave like a read-only text
field"): arrow keys, force press, iOS toolbar items. State that explicitly in the issue.

---

## 11. Existing flutter/flutter issues for the open gaps (searched 2026-09-23)

Three searches (one per fix layer) over open and closed issues and PRs, reading bodies and closing
comments; details and queries in `groups/issues_{A,B,C}_*.md`. States verified against GitHub the same day.
Match levels: **exact** = the same behavior on SelectionArea/SelectableRegion (or SelectableText after
migration); **partial** = covered as a row, comment or subset; **related** = context only.

Anchors: **#104547** [open, P3] "[Selection] Reimplement SelectableText with SelectionArea" is the
migration tracker (a 2024 comment says its listed blockers are fixed or won't-fix). **#129583**
[open, P1] is the SelectionArea gesture-parity tracker (its iOS table still has an empty "Select word
edge on tap up" row). **#182628** [open, P2] is the SelectableRegion keyboard-shortcut parity tracker.

| gap (§10) | existing issue | match | action |
|---|---|---|---|
| iOS tap word-edge snapping | #129583 row "Select word edge on tap up" (iOS) | partial (row only) | Link there; consider a dedicated issue that also names the RenderParagraph word-edge event |
| Keyboard base/extent swapped | #182628 lists missing intents, not edge ordering; #104541 closed by PR #112584 (shift-extension only) | partial | File new, reference #182628 |
| Arrow keys cannot move a collapsed selection | #104541 (closed), #182628 | partial | File new as a policy question ("caret navigation in SelectionArea"), reference both |
| Handles can cross | #106705 "SelectionArea handles swap order on Android" | exact, **closed as intended** (matches native Android on non-editable text) | **Reclassify as accepted**; decide whether SelectableText follows SelectionArea or the old clamp |
| Off-screen handles not faded (withdrawn) | #13182 [open umbrella] is the TextField-side issue; SelectionArea already unlinks off-screen handles (groups/M_handle_visibility.md) | not a gap | Update #092 to assert the handle is unlinked; no issue |
| Handle-drag autoscroll overshoot | none (related: #110788, #64059, #162856, #190737) | none | File new |
| Ancestor scrollable edge scroll | #129590 (closed) covered the old SelectableText only | related | File new against SelectionArea, cite #129590 as the regression test |
| Force press | none; not a row in #129583 | none | File new (policy: should SelectionArea support force-press word selection) |
| No `SelectionChangedCause` | #110594 closed as fixed by PR #154202 (`SelectionListener`, offsets only) | partial | File new, reference #110594/#154202 |
| Status stuck `changing` after iOS double tap | none (related #163509) | none | File new, attach `patches/status_gating_ios_finalize_fix.patch` |
| iOS menu: Look Up / Search Web / Share | #141775 "[iOS] Add default buttons to SelectionArea context menu" | exact | Link |
| Select all offered when everything is selected / on macOS | only a comment thread on #141775 (reproduced 2026-02-19, "should have its own issue"); macOS: umbrella #74255 | partial | File new |
| Share on Android read-only menu | PR #141447 added it on purpose for #138728 (native Android parity) | intended | **Not a gap** |
| Programmatic selection API | #127025 "Add a controller to SelectionArea" (closed stale); #126980 fixed; PR #138654 unmerged | partial | File new (prerequisite for semantics actions and arrow keys) |
| `contextMenuBuilder` type mismatch | none specific (#142806, #125375 loosely related) | none | File new (SelectableText API) |
| `toolbarOptions` not honored | none (2019 fixed #42593 only) | none | Fix in SelectableText without an issue, or fold into the contextMenuBuilder issue |
| Baseline through scroll view | none | none | File new (SelectableText) |
| Overlay / MaterialLocalizations at build | none (#139744 unrelated Overlay issue) | none | Document as contract change; issue optional |
| Default selection color | #104703 closed by PR #128375 (paint order, not color) | partial | Fix in SelectableText; note on #104547 |
| Default StrutStyle | #131581 closed as duplicate of #104547, no mention of strut | related | Fix in SelectableText; note on #104547 |
| Selection box styles | #161010 [open, P3], fixed by open PR #186802; #104429 [open] theme variant; #140982 and #186630 closed unmerged | exact | Link; wire params once #186802 lands |
| Affinity in `SelectedContentRange` | #110594 (closed) / PR #154202 created the offsets-only API; #137362 dup; #179526, #187506 WidgetSpan offset bugs | partial | File new on the selection API |
| Whitespace selects previous word | none (rule came from PR #79308 for #79166 on RenderEditable) | none | File new on RenderParagraph |
| Semantics: screen-reader selection | #182909 [open, P2] screen readers cannot select; tracker #185220 (VPAT) | partial | Link; file new for text-field identity (`value`, flags) |
| Extra scroll semantics node | #187376 closed as duplicate (original not named; likely #164483 family, iOS side fixed by PR #184155) | partial | Fix in SelectableText (custom viewport); no issue needed |
| Keep-alive | none (nearby: #124787 closed, #124078 open crash with open fix PR #192468) | none | Solved in-branch; no issue |

New issues to file (suggested, in priority order): (1) affinity in `SelectedContentRange`; (2)
programmatic selection API on SelectableRegionState; (3) text-field semantics identity for
SelectionArea/Text (`value`, flags, `textSelection`, actions), linked to #182909; (4) ancestor
scrollable edge scroll for SelectionArea; (5) Select-all visibility rules in SelectableRegion's menu;
(6) keyboard anchor/extent model; (7) whitespace word rule in RenderParagraph; (8) handle-drag
autoscroll overshoot; (9) status stuck `changing` (bug, with patch); (10) caret navigation and force
press as policy questions; (11) `SelectableText.contextMenuBuilder` type; (12) baseline through the
SelectableText viewport. Reclassified by the search: handles crossing (accepted per #106705) and Share
on Android (intended per PR #141447).

### 11.1 Gap → GitHub history → affected failing tests (canonical table)

Test numbers refer to `per_test_index.md` at head 9ca7895e3ab; "behind" = the test currently fails on an earlier assertion.

| gap (fix layer) | GitHub history / issue | affected failing tests |
|---|---|---|
| Migration tracker | [#104547](https://github.com/flutter/flutter/issues/104547) open P3; gesture parity [#129583](https://github.com/flutter/flutter/issues/129583) open P1; keyboard parity [#182628](https://github.com/flutter/flutter/issues/182628) open P2 | all |
| Affinity missing from `SelectedContentRange` (selection API / RenderParagraph) | Partial: [#110594](https://github.com/flutter/flutter/issues/110594) closed by [PR #154202](https://github.com/flutter/flutter/pull/154202) (offsets-only API); [#137362](https://github.com/flutter/flutter/issues/137362) dup; unmerged [PR #138041](https://github.com/flutter/flutter/pull/138041), [PR #138654](https://github.com/flutter/flutter/pull/138654). File new | 069, 071, 073, 078, 085, 119, 072 (macOS); behind 068, 070, 077, 093, 095, 096, 099 |
| iOS tap snaps to word edge (SelectableRegion + RenderParagraph event) | Partial: unchecked row in [#129583](https://github.com/flutter/flutter/issues/129583). File new or claim the row | 068, 070, 077, 099; iOS 072, 093, 095, 096 |
| Whitespace selects previous word on mobile (RenderParagraph) | None; rule from [PR #79308](https://github.com/flutter/flutter/pull/79308) for [#79166](https://github.com/flutter/flutter/issues/79166) on RenderEditable. File new | 126, 128; step of 093 |
| Keyboard base/extent swapped (SelectableRegion) | Partial: [#182628](https://github.com/flutter/flutter/issues/182628); [#104541](https://github.com/flutter/flutter/issues/104541) closed by [PR #112584](https://github.com/flutter/flutter/pull/112584). File new | 045, 047, 048, 053, 054 |
| Arrow keys cannot move a collapsed selection (SelectableRegion, policy) | Partial: [#104541](https://github.com/flutter/flutter/issues/104541), [#182628](https://github.com/flutter/flutter/issues/182628). File new | 049 |
| Toolbar: iOS Look Up / Search Web / Share | Exact: [#141775](https://github.com/flutter/flutter/issues/141775) open P2 | 079, 086, 088, 090 (iOS), 092 (iOS), 093, 095, 096, 098, 075 (iOS); macOS count 089, 094 |
| Toolbar: Select all when all selected / on macOS | Partial: comments on [#141775](https://github.com/flutter/flutter/issues/141775); macOS umbrella [#74255](https://github.com/flutter/flutter/issues/74255). File new | 121; macOS count in 079, 089, 094 |
| Toolbar: Share on Android (was listed as a gap) | Not a difference: the old read-only SelectableText already showed Copy / Share / Select all on Android (`expectMaterialSelectionToolbar` expects 3 buttons; `EditableTextState.shareEnabled` does not check `readOnly`), and SelectableRegion added Share on purpose in [PR #141447](https://github.com/flutter/flutter/pull/141447) for [#138728](https://github.com/flutter/flutter/issues/138728). Share only disappeared under the deprecated `toolbarOptions` path, which used the legacy `TextSelectionControls.buildToolbar` menu (copy/cut/paste/selectAll only); that is part of the `toolbarOptions` row | none |
| `toolbarOptions` ignored / `contextMenuBuilder` type (SelectableText) | None specific ([#42593](https://github.com/flutter/flutter/issues/42593) fixed 2019; [#142806](https://github.com/flutter/flutter/issues/142806), [#125375](https://github.com/flutter/flutter/issues/125375) loose). Fix in SelectableText; file the builder-type question | 022; 137 passes by construction |
| Programmatic selection API on `SelectableRegionState` | Partial: [#127025](https://github.com/flutter/flutter/issues/127025) closed stale; [#126980](https://github.com/flutter/flutter/issues/126980) fixed; [PR #138654](https://github.com/flutter/flutter/pull/138654) unmerged. File new (prerequisite) | 058, 061, 063, 064 |
| Semantics: `value`, text-field flags, `textSelection`, actions (Text/RenderParagraph + SelectableText) | Partial: [#182909](https://github.com/flutter/flutter/issues/182909) open P2; tracker [#185220](https://github.com/flutter/flutter/issues/185220). File new for identity/value, link #182909 | 041, 042, 043, 044, 058, 060, 061, 062, 063, 064 |
| Extra `hasImplicitScrolling` node (SelectableText viewport) | Partial: [#187376](https://github.com/flutter/flutter/issues/187376) closed as dup (likely [#164483](https://github.com/flutter/flutter/issues/164483) family; iOS side [PR #184155](https://github.com/flutter/flutter/pull/184155)). Fix in SelectableText | 044, 058, 060, 062, 064 |
| Baseline through the scroll viewport (SelectableText) | None. File new | 056, 057 |
| Selection highlight box styles (Text/RenderParagraph + DefaultSelectionStyle) | Exact: [#161010](https://github.com/flutter/flutter/issues/161010) open P3, fix [PR #186802](https://github.com/flutter/flutter/pull/186802) open; theme variant [#104429](https://github.com/flutter/flutter/issues/104429); closed unmerged [PR #140982](https://github.com/flutter/flutter/pull/140982), [PR #186630](https://github.com/flutter/flutter/pull/186630); EditableText default changed by [PR #167762](https://github.com/flutter/flutter/pull/167762) for [#162197](https://github.com/flutter/flutter/issues/162197) | 129, 130 |
| Default `StrutStyle()` / default selection color (SelectableText) | Related: [#131581](https://github.com/flutter/flutter/issues/131581) closed as dup of #104547; [#104703](https://github.com/flutter/flutter/issues/104703) closed by [PR #128375](https://github.com/flutter/flutter/pull/128375) (paint order). Fix in SelectableText | contributes to 057, 129, 130 |
| Handles can cross (SelectableRegion) | Exact: [#106705](https://github.com/flutter/flutter/issues/106705) closed as intended (native Android). Reclassify as accepted unless SelectableText keeps the old clamp | 029 |
| Off-screen handles not faded (withdrawn 2026-09-23) | Not a gap: SelectableRegion unlinks an off-screen handle's layer so it is not painted or hit-testable; only the fade animation differs from EditableText ([#13182](https://github.com/flutter/flutter/issues/13182) is the TextField-side umbrella). Action: change #092's assertion from `opacity == 0.0` to "follower unlinked" | 092 (android; iOS behind toolbar) |
| Handle-drag autoscroll overshoot (Scrollable selection delegate) | None (related [#110788](https://github.com/flutter/flutter/issues/110788), [#64059](https://github.com/flutter/flutter/issues/64059), [#162856](https://github.com/flutter/flutter/issues/162856), [#190737](https://github.com/flutter/flutter/issues/190737)). File new | 033 |
| Ancestor scrollable edge scroll (SelectableRegion) | Related: [#129590](https://github.com/flutter/flutter/issues/129590) closed (old SelectableText). File new, cite it | 091; 090 behind toolbar |
| Force press (SelectableRegion, policy) | None. File new | 098 |
| `SelectionChangedCause` not exposed (SelectableRegion) | Partial: [#110594](https://github.com/flutter/flutter/issues/110594) / [PR #154202](https://github.com/flutter/flutter/pull/154202). File new | none asserted |
| Status stuck `changing` after iOS double tap (bug) | None (related [#163509](https://github.com/flutter/flutter/issues/163509)). File new with `patches/status_gating_ios_finalize_fix.patch` | probe; 076 under a finalized-only consumer |
| Overlay / MaterialLocalizations at build (SelectableText) | None ([#139744](https://github.com/flutter/flutter/issues/139744) unrelated). Document as contract change | 001 |
| Keep-alive in lazy lists | None (nearby [#124787](https://github.com/flutter/flutter/issues/124787) closed, [#124078](https://github.com/flutter/flutter/issues/124078) open, fix [PR #192468](https://github.com/flutter/flutter/pull/192468)). Solved in-branch 881f512d507 | none |
| Callback noise | Solved in-branch e9f17a5b296 | none |

### 11.2 Coverage check: the 52 failing tests at 9ca7895e3ab against the table

Mechanically verified: 51 of the 52 currently failing tests appear in the §11.1 "affected failing
tests" column. By their Part 1 verdict at the audit head:

| Part 1 verdict | failing tests | examples |
|---|---|---|
| PARTIAL (edit warranted, deliberately left failing) | 33 | 069/071/073 affinity; 079/086/088 toolbar; 045–054 keyboard; 029 handles; 129/130 box styles; 098 force press; 121 Select all; 126/128 whitespace rule; 022 `toolbarOptions` |
| MIXED (fake-fix piece restored by the review; now fails on the gap) | 9 | 094, 096 affinity; 061, 063 semantics; 072, 075, 095 toolbar |
| Unchanged from base | 7 | 041–044, 060, 064 semantics; 001 Overlay |
| COSMETIC | 3 | 056, 057 baseline; 013 |

The one failing test not in the table is #013 "Cursor blinks when showCursor is true". It fails on
G-NO-CARET, accepted as by-design in the #007 verdict, so it is excluded from the filing list on
purpose. Follow-up (not applied): under that verdict it should become a documented removal, skipped
with a comment like #124, rather than remain a red test.

### 11.3 Correction to the audit, and two observations not investigated (2026-09-23)

The group H finding that off-screen selection handles stay visible in the SelectionArea-based
SelectableText was wrong on impact; see the 12b correction in §3.3 and `groups/M_handle_visibility.md`.
While probing, the agent observed two SelectionArea behaviors it did not investigate: (1) with a
SelectionArea over a ListView, scrolling far enough that the selected items are disposed (both edge
points null, overlay disposed) and scrolling back does not bring the handles back; (2) a touch long
press on a SelectableText placed inside a vertical ListView did not select, while a double tap did.
Both are outside this audit's test suite and may deserve their own reproduction before filing.
