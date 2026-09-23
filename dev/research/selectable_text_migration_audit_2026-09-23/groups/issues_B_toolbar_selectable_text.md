# Existing flutter/flutter issues for SelectableText -> SelectionArea POC gaps (toolbar, layout, styling)

Searched 2026-09-23 with `gh issue list/pr list --state all --search` (note: `gh search issues` returned near-empty results for most queries this session, so all searches used `gh issue list --search`, which searches title+body). Bodies of all cited candidates were read.

## Gap 1: "Select all" shown when everything is already selected / shown on macOS
- #141775 [open] [iOS] Add default buttons to SelectionArea context menu — match: partial — body is about iOS Look Up/Search Web/Share, but comment by leocirto (2024-05-09) reports that after pressing "Select all" in SelectionArea's menu the button "does not disappear nor is it disabled"; Renzo-Olivares (2026-02-19) confirmed the repro and said "it should probably have its own dedicated issue" (none filed that I could find).
- #74255 [open] ☂️ Proposal: desktop context menu fidelity — match: related — umbrella that desktop menus only show mobile default buttons instead of native ones; no specific mention of Select all on macOS or SelectionArea.
- #99285 [open] [SelectableText] IOS text selection toolbar options do not match native platform — match: related — opposite direction (asks for Select All on iOS SelectableText); shows platform-button-set divergence for SelectableText.
- #120080 [closed] [SelectionArea] Two weird behaves when clicking Copy or Select All in contextMenu — match: related — handle/menu glitches after Copy/Select All; fixed by PR #120081. Not about visibility of the button.
Searched: `SelectionArea "select all" context menu`; `SelectableRegion "select all" already selected`; `"select all" macOS context menu selection area`; `SelectionArea "Select all" hidden when all selected`; `"Select all" button shown when everything already selected`; `"select all" when all text selected toolbar`; `SelectionArea macOS "Select all"`; `"Select all" macOS text field context menu`; `"Select all" in:title SelectableRegion`; `"Select all" in:title toolbar`; `"select all" in:title macOS`; PRs: `SelectionArea select all`, `"Select all" SelectableRegion`, `SelectableRegion macOS select all`.
Verdict: partial coverage by #141775 (comment only, maintainer said it needs a dedicated issue); no dedicated issue found; macOS aspect has no existing issue (only the #74255 umbrella).

## Gap 2: SelectionArea iOS menu lacks Look Up, Search Web, Share
- #141775 [open] [iOS] Add default buttons to SelectionArea context menu — match: exact — proposes adding Share, Look up and Search Web to SelectionArea's context menu on iOS, noting SelectableText/TextField already have them (PRs #132599, #130532, #131898); labels f: selection, team-text-input, P2.
- #107578 [open] Missing default context menu buttons on each platform — match: related — cross-platform umbrella of missing native buttons (also lists Mac: Look Up, Translate, Search With Google, Share).
- #82907 [closed] Add additional options in edit menu (Look Up/Search Web/Share on iOS, Web Search on Android) — match: related — original request for text fields; closed 2023-08-08 after the EditableText PRs.
Searched: `SelectionArea "look up" iOS`; `SelectionArea "search web"`; `SelectionArea "Look Up" "Share"`; `SelectionArea toolbar iOS native`; `SelectableText context menu`; PR `SelectionArea look up`; `107578`.
Verdict: existing issue #141775 covers it.

## Gap 3: SelectionArea menu on Android shows Share for read-only content
- PR #141447 [merged 2024-01-23] Add Share button to the SelectableRegion toolbar on Android — match: exact (cause) — deliberately added Share to SelectableRegion/SelectionArea on Android; follow-up of #138728. So Share in SelectionArea is intended behavior, not a bug.
- #138728 [closed] [Android] Add 'Share' button to selection controls — match: related — asks for Share "both for Selectable region and TextField", noting native Android TextView (read-only) shows Share; fixed.
- #141775 [open] — match: related — leocirto comment: on Android SelectableText shows Share/Read aloud/Translate while SelectionArea (at the time) showed only Copy/Select all; Renzo-Olivares later said the extra buttons are now present on master.
Searched: `SelectionArea share context menu`; `SelectableText share button android`; `SelectionArea "Share" android read only`; `SelectableText share android`; `SelectionArea context menu Android share`; PR `SelectionArea share`.
Verdict: no existing issue reporting it as a problem; the behavior was intentionally added by PR #141447 (for #138728), matching native Android TextView. The difference is the old SelectableText (EditableText, read-only) not showing Share, which no issue reports.

## Gap 4: SelectableText.contextMenuBuilder typed EditableTextContextMenuBuilder vs SelectionArea's SelectableRegionContextMenuBuilder
- #142806 [closed] SelectionArea's contextMenuBuilder should be dynamically updatable — match: related — wants SelectionArea menu buttons to change with selection; closed (waiting for response) 2024-04-25.
- #125375 [closed] SelectionArea contextMenuBuilder not running with selectionControls materialTextSelectionControls — match: related — user code adds custom button to SelectionArea menu (param named `editableTextState` though it's a SelectableRegionState); closed r: fixed.
- #111001 [closed] [SelectionArea] with custom actions and actions widget overlay builder — match: related — early request for custom SelectionArea actions; closed after context menu API landed.
- #155514 [closed] SelectableText crashes the app if custom contextMenuBuilder is used — match: related — crash with SelectableText custom builder; closed 2026-05-09 (PR #184990 "Fix SelectableText crash with inline lambda contextMenuBuilder" merged; a revert PR #186291 was opened and closed).
Searched: `SelectableText contextMenuBuilder EditableTextState`; `SelectionArea contextMenuBuilder custom button`; `SelectableRegionContextMenuBuilder`; `SelectableRegion contextMenuBuilder EditableTextState`; `SelectableText contextMenuBuilder SelectableRegionState`; `EditableTextContextMenuBuilder SelectableText`; `SelectableText in:title contextMenu`; `SelectionArea custom context menu`; PRs `SelectableText contextMenuBuilder`, `SelectableRegion contextMenuButtonItems`.
Verdict: no existing issue found about the type mismatch / migration path; customization of SelectionArea's menu is already supported (related closed issues only).

## Gap 5: toolbarOptions no longer honored / disabling copy or select-all
- #42593 [closed] ToolbarOptions with SelectableText is not working as expected — match: related — 2019 bug that selectAll:false was ignored on SelectableText; fixed 2019.
- #119820 [closed] The 'Cut' button won't appear in text fields when toolbarOptions are passed — match: related — toolbarOptions (deprecated) bug in text fields; fixed 2023.
- #148045 [open] Option to disable right click select on selectable text, but keep it selectable with left click — match: related — SelectableText context-menu/right-click control, not copy/select-all.
- #79796 [closed] Add the ability to disable ContextMenu in TextFields — match: related — closed 2022 after contextMenuBuilder.
- #132191 [closed] Enable/Disable Copy/Paste Functionality in TextField — match: related — closed r: invalid, TextField-only.
Searched: `SelectableText toolbarOptions`; `SelectionArea disable copy`; `SelectionArea "toolbarOptions"`; `SelectionArea toolbarOptions`; `SelectionArea remove copy button`; `SelectionArea disable select all`; `SelectableText disable copy`; `toolbarOptions in:title`; `ToolbarOptions deprecated contextMenuBuilder`; `SelectionArea in:title disable`.
Verdict: no existing issue found (no request to disable copy/select-all on SelectionArea, nothing about toolbarOptions on SelectableText after deprecation).

## Gap 6: Baseline alignment through scroll views / SelectableText or SelectionArea baseline
- #119043 [open] Flutter align text to the bottom and on the same textBaseline doesn't work — match: related — Row baseline + IntrinsicHeight limitation; no scroll view involved.
- #144502 [closed] Cannot align Text and TextField vertically in a Row — match: related — Text vs TextField off by pixels while SelectableText aligned with TextField; closed r: fixed. Suggests SelectableText (EditableText) and Text metrics differ, relevant to baseline parity but not to the scroll-view baseline.
- #12455 [closed] Row CrossAxisAlignment.baseline does not work with TextField — match: related — 2017, TextField baseline; fixed.
Searched: `SingleChildScrollView baseline`; `scroll view baseline alignment Row`; `SelectableText baseline`; `SelectionArea baseline`; `baseline in:title scroll|ListView|SingleChildScrollView|SelectableText|Scrollable|viewport`; `"computeDistanceToActualBaseline" viewport`; `baseline in:title TextField Row`; `baseline ListView Row`; `baseline scrollable`; `CrossAxisAlignment.baseline SingleChildScrollView`; `baseline label:"a: layout"`; `Row baseline alignment scrollable child`; PRs `SingleChildScrollView baseline`, `Row baseline scroll view`.
Verdict: no existing issue found.

## Gap 7: Overlay ancestor required / MaterialLocalizations required by SelectionArea
- #139744 [open] Selection context menu position incorrect if Overlay is not "fullscreen" — match: related — SelectionArea with a non-fullscreen MaterialApp Overlay; about positioning, not the assert.
- #6537 [open] Some of our controls can't handle being built in 0x0 environments — match: related — PR #177876 (merged 2025-11-03) made SelectionArea not crash at 0x0; not about Overlay/localizations.
- #181682 [open] Add a Cupertino version of SelectableText — match: related — SelectableText is Material-only; relevant to the Material dependency (localizations) but not a report of the assert.
Searched: `"No Overlay widget found" SelectableText` / `SelectionArea` (plain and `in:body`); `"No Overlay widget found"` (only generic Overlay reports: #178600, #148314, #150878, etc., none about SelectableText/SelectionArea); `"No MaterialLocalizations found" SelectionArea` / `SelectableText` (plain and `in:body`); `"No MaterialLocalizations found"`; `SelectionArea overlay required`; `SelectionArea without MaterialApp`; `SelectionArea MaterialLocalizations`; `SelectionArea WidgetsApp`; `SelectionArea test Overlay`; `SelectableText Overlay`; `"debugCheckHasOverlay" SelectableText`; `SelectableText in:title overlay|localizations`; `SelectionArea in:title assert|without`; PR `SelectionArea Overlay`.
Verdict: no existing issue found.

## Gap 8: Default selection color (primary @ 40% vs DefaultSelectionStyle) / theming SelectionArea color
- #104703 [closed] SelectionArea text selection color with the TextSelectionTheme not look like before with SelectableText — match: partial — user migrated SelectableText -> SelectionArea and the selection looked different under the same TextSelectionTheme; triage confirmed "Text color inside SelectionArea does not look similar to SelectableText". Closed 2023-06-09 by PR #128375 "Paint SelectableFragments before text" (highlight was painted over the text), i.e. a paint-order fix, not a default-color change.
- #162165 [closed] SelectableText should have a selectionColor property — match: related — parity request in the other direction (Text has selectionColor, SelectableText did not); r: fixed 2025-02-21.
- #99231 [open] [SelectableText] Add support for Changing style of selected text — match: related — selected-text foreground style, not the highlight color.
- #68675 [closed] [SelectableText] inconsistent selection background color between different character encoding — match: related — overlapping-box color inconsistency.
Searched: `SelectionArea selection color`; `SelectableText selection color`; `DefaultSelectionStyle selectionColor SelectionArea theme`; `SelectionArea highlight color TextField`; `SelectionArea default selection color`; `SelectableText cursorColor selection color primary opacity`; `DefaultSelectionStyle` (plain and `in:title`); `SelectionArea Theme selection color not applied`; `SelectionArea in:title color`; `selectionColor in:title`; `SelectableText in:title color`.
Verdict: partial coverage by #104703 (closed; same migration symptom but fixed as a paint-order bug); no open issue about the default-color difference.

## Gap 9: SelectableText strutStyle default vs Text
- #131581 [closed] Different height in SelectableText and Text on different platform and style height — match: partial — same TextStyle(height: 1.5/2) gives different box heights for SelectableText vs Text; closed as r: duplicate pointing at #104547 (no strut discussion).
- #144502 [closed] Cannot align Text and TextField vertically in a Row — match: related — Text vs TextField/SelectableText vertical metrics differ; closed r: fixed.
- #146860 [open] TextHeightBehaviour should allow more tightly-wrapped text — match: related — line-metrics feature request, not SelectableText-specific.
Searched: `SelectableText strutStyle`; `SelectableText strut`; `SelectableText StrutStyle default`; `strutStyle in:title SelectableText`; `strutStyle in:title`; `SelectableText line height different Text`; `SelectableText text height taller than Text`; `SelectableText in:title height`.
Verdict: partial coverage by #131581 (closed as dup of #104547); no issue names the StrutStyle default.

## Gap 10: selectionHeightStyle / selectionWidthStyle for Text / SelectionArea
- #161010 [open] SelectionArea should expose a selectionHeightStyle option — match: exact — Text with large `height` inside SelectionArea shows gaps; asks for selectionHeightStyle like TextField/SelectableText; P3, f: selection. This is the issue PR #186802 (open, "Add selection highlight styles to SelectionArea", adds selectionHeightStyle/selectionWidthStyle to SelectionArea -> DefaultSelectionStyle -> RenderParagraph) says it fixes. An earlier PR #186630 for the same issue was closed unmerged; PR #140982 (add the styles to Text, referencing #104547) was closed unmerged.
- #104429 [open] Proposal: add selectionHeightStyle and selectionWidthStyle to TextSelectionThemeData — match: partial — asks for theme-level defaults for TextField/SelectableText/TextFormField; a theme default would also cover SelectionArea.
- #154231 [open] [SelectionArea] The height of highlight is different when mixing english/non-english/or emoji characters — match: partial — the symptom BoxHeightStyle.max/strut would fix under SelectionArea.
- #130781 [open] Text Selection height doesn't match Text widget's height — match: partial — SelectionArea highlight smaller than the Text box (c: regression).
- #162197 [closed] Text selection height should be based on the line height, not the character height — match: related — TextField/iOS; closed 2025-07-08.
Searched: `selectionHeightStyle SelectionArea`; `selectionHeightStyle Text widget`; `SelectionArea selection highlight height`; `BoxHeightStyle SelectableRegion`; `SelectionArea selectionWidthStyle`; PR `selectionHeightStyle SelectionArea`; `gh pr view 186802`.
Verdict: existing issue #161010 covers it (height exact; width only via PR #186802, and theme-level via #104429).

## Gap 11: Tracking issue for migrating SelectableText onto SelectionArea / parity
- #104547 [open] [Selection] Reimplement SelectableText with SelectionArea — match: exact — "reimplement SelectableText with SelectionArea + text, but we should make sure they are feature on par"; P3, c: tech-debt, f: selection, team-framework. Listed blockers are all fixed/won't-fix per a 2024-04-16 comment. goderbauer (2022) preferred reimplementing over deprecating.
- #129583 [open] SelectionArea supported gestures should have feature parity with TextSelectionGestureDetector — match: partial — gesture-parity table; states some gestures are needed for #104547; P1.
- #119911 [closed] Documentation on SelectableText should mention SelectionArea — match: related — fixed by PR #143784 (docs nudge toward SelectionArea; PR body notes SelectableText stays until SelectableRegion can fully replace it).
- #181682 [open] Add a Cupertino version of SelectableText — match: related — would interact with a SelectionArea-based rewrite.
Searched: `SelectableText deprecate SelectionArea`; `SelectableText SelectionArea migrate`; `SelectableText SelectionArea parity`; `SelectableText SelectionArea`; PR `SelectableText SelectionArea`.
Verdict: existing issue #104547 covers it.

## Gap 12: Keep-alive in lazy lists (selection/focus lost when scrolled off-screen)
- #124078 [open] [SelectionArea] Select all in ListView returns "Null check operator used on a null value" — match: related — crash when selected content in a lazy ListView scrolls away / is disposed; #153478 (Ctrl+A selects only built items in ListView, crash) closed as dup of it; fix PR #192468 open.
- #124787 [closed] Selection disappears if widget rebuilds in the ListView — match: partial — SelectionArea selection lost on rebuild inside ListView; closed 2026-02-04 for no response after maintainer could not reproduce. #152428 (selection lost when an item is inserted into a ListView) was closed as dup of it.
- #110788 [open] Long SelectableText is not actually selectable in ListView — match: related — scrolling/handle problems with SelectableText in ListView; not about keep-alive.
- #129590 [closed] SelectableText does not maintain start position when scrolled out of view — match: related — about SelectableText's own internal scroll; r: fixed.
Searched: `SelectableText ListView scroll selection lost`; `SelectableText keepAlive`; `SelectableText keep alive`; `"wantKeepAlive" SelectableText`; `keepAlive in:title TextField`; `SelectionArea ListView selection lost scroll`; `SelectionArea lazy list selection`; `SelectableText lazy list`; `SelectableText scrolled off screen`; `SelectionArea selection lost scrolled`; `SelectableText ListView focus lost`; `SelectableText selection cleared scroll ListView`; `SelectionArea ListView.builder selection disappears`; `SelectionArea selection preserved scroll offscreen`; `SelectableText in:title ListView|scroll|selection lost`; `SelectionArea in:title ListView|scroll`.
Verdict: no existing issue found for the keep-alive behavior itself; partial adjacent coverage by #124787 (closed) and #124078 (open, crash when selection leaves a lazy list).

## Summary

| Gap | Best issue | Match |
|---|---|---|
| 1 Select all shown when fully selected / on macOS | #141775 (comment only; maintainer asked for a dedicated issue); #74255 umbrella for macOS | partial / none dedicated |
| 2 iOS Look Up / Search Web / Share missing | #141775 (open) | exact |
| 3 Android Share on read-only content | PR #141447 (intentional, for #138728) | no issue (by design) |
| 4 contextMenuBuilder type mismatch / migration | none (#142806, #125375 related) | none |
| 5 toolbarOptions / disable copy or select-all | none (#42593 old, fixed) | none |
| 6 Baseline through scroll views / SelectableText baseline | none (#119043, #144502 related) | none |
| 7 Overlay / MaterialLocalizations asserts | none (#139744 related) | none |
| 8 Default selection color | #104703 (closed, fixed by #128375 as paint order) | partial |
| 9 strutStyle default / height vs Text | #131581 (closed dup of #104547) | partial |
| 10 selectionHeightStyle / WidthStyle | #161010 (open; PR #186802 fixes); #104429 theme-level | exact (height), partial (width/theme) |
| 11 Migration / parity tracking | #104547 (open); #129583 gestures | exact |
| 12 Keep-alive in lazy lists | none (#124787 closed, #124078 open adjacent) | none / related |
