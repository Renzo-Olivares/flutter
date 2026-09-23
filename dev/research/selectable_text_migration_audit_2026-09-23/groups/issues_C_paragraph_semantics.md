# Existing issues: paragraph / selection API / semantics gaps (SelectableText -> SelectionArea + Text POC)

Umbrella for the whole migration: **#104547 [open] "[Selection] Reimplement SelectableText with SelectionArea"** (P3, c: tech-debt, f: selection). Its body lists parity blockers (#111370, #111021, #110594 "won't fix", #104703, #104603, #104594, #126652). Cross-referenced from it: #129583 (gesture parity), #140982 (closed, unmerged PR adding selectionHeightStyle/WidthStyle to Text), #123658 (maxLines parity), #110788, #83784.

Note on search: `gh search` gave poor recall for multi-word behavior phrasing. Label-qualified and title-scoped queries often returned nothing. Timeline cross-references (on #110594, #104547, #161010, #164483, #100395, #104557) turned up the most useful links.

## Gap 1: `SelectedContentRange` has no `TextAffinity` / no `TextSelection`
- #110594 [closed, r: fixed, 2024-11-26] Make `onSelectionChanged` of SelectionArea equivalent to that of SelectableText — match: partial. It asked for selection offsets and details, like SelectableText's `TextSelection`, instead of plain text only. PR #154202 "Add `SelectionListener`/`SelectedContentRange`" resolved it with start/end offsets only. There is no affinity and no `TextSelection`. This is the origin of the current API shape. #104547 marks this as "(won't fix)" for the full ask.
- #137362 [closed, duplicate of #110594] Add offset's to SelectionArea callback — match: partial. It asked for a `TextSelection` object on `SelectedContent`. Closed as a duplicate of #110594. Unmerged PRs #138041 and #138654 ("Add ability to return TextSelection from SelectableRegion") were closed.
- #131065 [closed 2026-03-19] Allow onSelectionChanged Callback To Be Aware Of Where Data Came From — match: related. It asked for per-Text source and offsets. No affinity.
- #162697 [closed, r: solved] [flutter_markdown] Selection: expose offset/position — match: related. It asked for offsets, which SelectionListener now provides.
- #179526 [open, P2, team-text-input] SelectionListenerNotifier selection.range incorrect when selecting over WidgetSpans — match: related. It is a correctness bug in `SelectedContentRange` offsets, not affinity.
- #187506 [open, P2] The first WidgetSpans should not be counted in the selection — match: related. It reports the same WidgetSpan offset skew in the range.
- #137371 [open, P3] Make 'Selectable' support getBoxesForSelection(TextSelection) — match: related. It asks for richer geometry from Selectable, not affinity.
- #119684 [open] Extending to word boundary on macOS should default to `downstream` at a word wrap — match: related (TextField only). It shows why affinity matters at soft wraps, but it covers EditableText, not SelectionArea.

Searched: `SelectedContentRange`; `SelectedContentRange affinity`; `SelectionListener`; `SelectionListener affinity`; `SelectionListenerNotifier`; `SelectionArea selection affinity`; `SelectionArea TextSelection offsets`; `SelectionArea onSelectionChanged range`; `SelectionArea get selected text offset`; `affinity --label "f: selection"`; `SelectionArea TextAffinity`; `getSelection SelectionArea`; plus timeline of #110594.

Verdict: partial coverage by #110594 (closed by #154202, which shipped offsets only). No existing issue asks for `TextAffinity` or a `TextSelection` on `SelectedContentRange`.

## Gap 2: Mobile word selection on whitespace selects the space, not the previous word
- #79166 [closed, r: fixed] SelectableText double click on the space before a word to select the previous word throws if there's no word — match: related. It is a crash in the EditableText path. PR #79308 "Makes text selection match the native behavior" fixed it and introduced the iOS/Android previous-word rule in `RenderEditable.getWordAtOffset` that `_SelectableFragment` lacks.
- #129583 [open, P1] `SelectionArea` supported gestures should have feature parity with `TextSelectionGestureDetector` — match: related. It tracks gesture parity (double tap and long press are done). The whitespace-to-previous-word rule is not listed.
- #105723 [closed 2023-08] Selectable Text should select the related characters on double tap — match: related. It is about CJK/pictogram word grouping.
- #123065 [open, P2, team-text-input] CJK word boundaries — match: related. It covers word movement in text input, not SelectionArea.
- #126652 [closed] [SelectionArea] Long press, text in chinese is not selected by default and selected state exception — match: related. It is a CJK long-press bug and is fixed.
- #104603 [closed] `SelectionArea` should expand selection by words on Android — match: related. It is about drag-by-word and is fixed.
- #132818 [closed, r: fixed] SelectionArea can not select a word with long press — match: related (fixed).

Searched: `SelectionArea double tap whitespace`; `SelectionArea long press space previous word`; `double tap whitespace selects previous word`; `long press whitespace selects space`; `double tap space selects in:title`; `whitespace word selection in:title`; `SelectionArea word in:title`; `SelectionArea word boundary`; `SelectableRegion word boundary`; `getWordBoundary selection whitespace`; `SelectionArea CJK word selection`; `"previous word" selection`; `space word --label "f: selection"`; `word boundary --label "f: selection"`; `punctuation --label "f: selection"`; `CJK --label "f: selection"`; `SelectionArea select word Android space`.

Verdict: no existing issue found. No issue reports SelectionArea/Text selecting the whitespace instead of the previous word. Related background: #79166 / PR #79308. Parity tracker: #129583.

## Gap 3: Selection highlight box styles (`BoxHeightStyle` / `BoxWidthStyle`) for Text / SelectionArea
- #161010 [open, P3, f: selection, team-framework] SelectionArea should expose a selectionHeightStyle option — match: exact. Tight highlight boxes leave gaps with a large `TextStyle.height`. It asks for SelectionArea to expose `selectionHeightStyle` the way SelectableText does. Linked PRs:
  - #186802 [open PR] "Add selection highlight styles to SelectionArea" (Fixes #161010). It adds `selectionHeightStyle`/`selectionWidthStyle` to SelectionArea and threads them through `DefaultSelectionStyle` to `RenderParagraph`.
  - #186630 [closed, unmerged PR] "Expose selectionHeightStyle and selectionWidthStyle on SelectionArea". This was an earlier attempt.
- #140982 [closed, unmerged PR, 2024] Add `selectionHeightStyle` and `selectionWidthStyle` to Text Widget — match: exact (abandoned). It was filed against #104547.
- #154231 [open, P2, f: selection] [SelectionArea] The height of highlight is different when mixing english/non-english/emoji characters — match: partial. It is a visible symptom of tight per-glyph boxes in SelectionArea.
- #137817 [closed] IOS Emoji Selection is Higher than English Character — match: partial. It covers both SelectableText and SelectionArea and is cross-referenced from #161010.
- #162197 [closed 2025-07] [Text Selection] Text selection height should be based on the line height — match: related. TextField only. It was fixed by PR #167762 "Update default `selectionHeightStyle` and `selectionWidthStyle` for `EditableText`" (merged 2025-06-16). That PR is why TextField highlights now differ from Text/SelectionArea.
- #104429 [open, P3] Proposal: add selectionHeightStyle and selectionWidthStyle to TextSelectionThemeData — match: related. It asks for a theme-level default and does not mention SelectionArea.
- #21997 [open, P2, team-engine] Text selection vertical extent should be defined per line (not per glyph) — match: related. This is the engine-level root cause.

Searched: `selectionHeightStyle Text`; `BoxHeightStyle SelectionArea`; `SelectionArea selection highlight height`; `SelectionArea highlight line height gap`; `selection highlight gaps between lines Text`; `SelectionArea highlight different from TextField`; plus timelines of #161010 and #104547.

Verdict: existing issue #161010 covers it. It is open, and PR #186802 is open against it.

## Gap 4: Semantics of SelectionArea / selectable Text (label vs value, no text-field flags, no screen-reader selection)
- #182909 [open, P2, a: accessibility, f: selection, team-text-input, 2026-02-25] Screenreader should announce changes in selection for `SelectableRegion` — match: exact for the selection part. TalkBack says "not selectable" and there is no selection mode. The iOS rotor has no "text selection". macOS announces nothing on mouse selection. This covers missing `textSelection` and `setSelection`/cursor-movement actions. It does not mention label-vs-value or the `isTextField`/`isReadOnly`/`isMultiline` flags.
- #185220 [open, P2, team-accessibility, 2026-04-17] [VPAT] Text selection widgets for VPAT — match: partial. It is a tracking issue: SelectionArea, SelectableRegion and SelectableText "need to be able to clearly communicate their selection state to the accessibility system". None of them are checked yet.
- #104557 [closed 2022-05] `SelectionArea` breaks for TalkBack — match: related. TalkBack could not focus individual Text nodes under SelectionArea. PR #104659 "SelectableRegion does not merge child semantics nodes" fixed it.
- #135318 [open, P2, platform-web] SelectionArea pops up incorrect context menu when semantics is on — match: related.
- #126633 [open, P2] SelectableText.rich displays wrong semantics labels — match: related. The current SelectableText is announced as "textedit disabled" rather than its content. This is the inverse of the migration's label-vs-value change.

Searched: `SelectionArea accessibility`; `SelectionArea screen reader`; `SelectionArea TalkBack`; `SelectionArea VoiceOver`; `SelectionArea semantics`; `SelectableRegion semantics`; `SelectableText semantics TalkBack`; `SelectableText VoiceOver`; `SelectableText semantics in:title`; `selectable text screen reader select text`; `TalkBack select text Text widget`; `VoiceOver text selection static text`; `selection --label "a: accessibility" --label "f: selection"`.

Verdict: partial coverage by #182909 (screen-reader selection and announcements), plus tracker #185220. No existing issue covers the label-vs-`value` exposure or the missing `isTextField`/`isReadOnly`/`isMultiline`/`focusable`/`focused` flags for SelectionArea Text.

## Gap 5: Extra `hasImplicitScrolling` node from a wrapping `SingleChildScrollView`
- #187376 [closed as duplicate, 2026-06-02, no target named] Expose `Scrollable.excludeFromSemantics` on `SingleChildScrollView` — match: partial. It asks for exactly the knob the POC lacks, motivated by a "ghost" VoiceOver focus stop from the scroll container. It was closed as a duplicate within a day, apparently of the #164483 family.
- #164483 [closed 2026-04-06] [iOS] Extra silent accessibility focus before first ListView item — match: related. This is an iOS embedder-side ghost node. PR #184155 "Fix invisible accessibility element before scroll view" fixed it (merged 2026-04-06; commit 6e3c87ce633 is in this branch). Duplicates: #164623 (SingleChildScrollView), #175774, and older #99011.
- #187055 [open] [iOS][FKA] Full Keyboard Access does not scroll to offscreen Semantics nodes in SingleChildScrollView — match: related.

Searched: `hasImplicitScrolling SingleChildScrollView semantics`; `SingleChildScrollView excludeFromSemantics`; `SingleChildScrollView semantics in:title`; `SingleChildScrollView VoiceOver focus stop scroll container`; `scrollable excludeFromSemantics`; `SelectableText hasImplicitScrolling`; `SelectableText semantics scroll`; PR search `excludeFromSemantics SingleChildScrollView` (0 hits).

Verdict: partial coverage by #187376, which requests `excludeFromSemantics` on SingleChildScrollView but is closed as a duplicate. The iOS ghost-node symptom was fixed by #184155. The framework-level extra `hasImplicitScrolling` node is not tracked.

## Gap 6: "Select word edge" / collapse-at-word-boundary SelectionEvent; `TextGranularity`-based programmatic selection on Text
- #129583 [open, P1, team-framework] `SelectionArea` supported gestures should have feature parity with `TextSelectionGestureDetector` — match: partial. Its iOS table has an unfilled row, "Select word edge on tap up | (empty) | Both". It tracks the gesture, not the underlying `SelectionEvent` or granularity API.
- #127025 [closed, waiting for response, 2024-10] Add a controller to SelectionArea — match: related. It asked for programmatic selection (select all). It was closed for lack of information.

Searched: `SelectionArea select word edge`; `SelectionArea iOS tap word edge`; `SelectionArea TextGranularity`; `"TextGranularity" selection` (0 hits); `SelectionArea programmatic selection`; `select text programmatically Text widget SelectionArea`.

Verdict: partial coverage by #129583 (the "Select word edge on tap up" row is still open). No issue requests a word-edge `SelectionEvent` or `TextGranularity`-based programmatic selection on Text.

## Gap 7: selection.dart rich-content TODO -> #104206
- #104206 [open, P3, f: selection, team-framework, 2022-05-19] [Selection] SelectableRegion should support rich text clipboard — match: related (not a match). It covers only copying styled/rich data to the clipboard instead of plain text. It does not cover exposing selection offsets, affinity or `TextSelection`. The TODO at `packages/flutter/lib/src/rendering/selection.dart:197-198` points here.
- #104548 [open] Copying text in `SelectionArea` is not like copying text from HTML — match: related (clipboard fidelity).

Searched: direct read of #104206; `SelectedContentRange` (returned #104548).

Verdict: #104206 is still open but covers rich clipboard content only. It is not an existing issue for exposing selection details (see Gap 1).

## Gap 8 (bonus): `semanticsLabel` with selection; inline-span recognizer semantics under SelectionArea
- #100395 [closed, P0, 2022-03] [iOS][A11y] hidden TextSpan with recognizer does not auto scroll — match: related. Offscreen link nodes were not scrolled into view. PR #100494 fixed it. It predates SelectionArea.
- #77219 [closed, P0, 2021] SelectableText.rich() with VoiceOver does not allow user to focus on tappable links — match: related. It is the EditableText-era SelectableText link-focus bug, fixed.
- #126633 [open, P2] SelectableText.rich displays wrong semantics labels — match: partial for the `semanticsLabel` interaction. It is about the old SelectableText, not SelectionArea.
- #159127 [open, P2] [A11y] Second link is inaccessible in RichText — match: related (RichText links, no SelectionArea).
- #166750 [open, P2] Links don't show up in Screenreader rotors on iOS and Android — match: related.

Searched: `SelectionArea link semantics`; `SelectionArea TextSpan recognizer semantics`; `SelectionArea TextSpan recognizer`; `SelectionArea link TalkBack`; `SelectionArea gesture recognizer link`; `SelectionArea semanticsLabel`; `Text semanticsLabel selection`; plus timeline of #100395.

Verdict: no existing issue found for semanticsLabel or recognizer-span semantics specifically under SelectionArea. The adjacent issues are #100395 and #77219 (both fixed), and #126633 (open, old SelectableText).

## Summary

| Gap | Best issue | State | Match level |
|---|---|---|---|
| 1 SelectedContentRange affinity / TextSelection | #110594 (via PR #154202, offsets only); #137362 dup | closed | partial |
| 2 Whitespace -> previous word on mobile | none (background: #79166 / PR #79308; tracker #129583) | n/a | no existing issue |
| 3 Highlight BoxHeightStyle/BoxWidthStyle | #161010 (PR #186802 open; #186630 and #140982 closed unmerged) | open | exact |
| 4 SelectionArea semantics / screen-reader selection | #182909 (+ tracker #185220) | open | partial (selection yes; label/value and text-field flags not covered) |
| 5 Extra hasImplicitScrolling node | #187376 (closed dup); iOS symptom fixed by #184155 for #164483 | closed | partial |
| 6 Word-edge event / TextGranularity programmatic selection | #129583 ("Select word edge on tap up" row open) | open | partial |
| 7 #104206 rich content TODO | #104206 | open | related only (clipboard rich text, not selection details) |
| 8 semanticsLabel / recognizer spans under SelectionArea | #100395, #77219 (fixed), #126633 (open) | mixed | related only |

Umbrella for the migration: #104547 [open].
