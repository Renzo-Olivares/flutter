# M: Off-screen selection handle visibility in SelectableRegion / SelectionArea

Repo /Users/roliv/flutter, branch `selectabletext-migration-poc-testing` (HEAD reported as db548142833; the brief said 9ca7895e3ab. No lib/ changes between them). Probe file created, run 5 times, then deleted. `git status` is unchanged.

## TL;DR
The owner is right. SelectableRegion already hides off-screen handles, but it does it in a different way from EditableText. It does **not** fade a `FadeTransition`. It **stops pushing the handle's `LeaderLayer`**, so the handle's `CompositedTransformFollower(showWhenUnlinked: false)` goes unlinked. An unlinked follower is neither painted nor hit-testable. The probe confirms this: in test 092's scenario the start handle has `opacity=1.0` but `leaderLinked=false`. It is **not drawn at all**. It is not drawn at the end point, and it is not an opaque handle drawn somewhere off-screen. The audit's "stays fully opaque and floats over other UI" is **wrong** as a user-visible claim. What is left is that the handle disappears instantly instead of fading over 150 ms, plus test 092's assertion, which checks an implementation detail that no longer applies.

## 1. `_ScrollableSelectionContainerDelegate` (widgets/scrollable.dart)
- Class at scrollable.dart:1171. It extends `MultiSelectableSelectionContainerDelegate` and does **not** null or clip `startSelectionPoint`/`endSelectionPoint` itself. It does not override `getSelectionGeometry`.
- Its relevant contribution is the re-evaluation schedule. The position listener at :1178 calls `_scheduleLayoutChange` (:1208-1220), which runs `layoutDidChange()` in a post-frame callback. That calls `_updateSelectionGeometry()` (selectable_region.dart:2433-2435).
- The comments at :1396-1398 and :1409-1411 ("The selection geometry may not have the accurate offset for the edges that are outside of the viewport whose transform may not be valid") refer to keyboard-extend bookkeeping, not handle visibility.

## 2. The real mechanism: `MultiSelectableSelectionContainerDelegate` (widgets/selectable_region.dart)
- `_updateSelectionGeometry()` :2550-2557 recomputes the value and then **always** calls `_updateHandleLayersAndOwners()`.
- `_updateHandleLayersAndOwners()` :2766-2820:
  ```dart
  final Rect? drawableArea = hasSize
      ? Rect.fromLTWH(0, 0, containerSize.width, containerSize.height)
          .inflate(_kSelectionHandleDrawableAreaPadding)   // 5.0, :2390
      : null;
  final bool hideStartHandle = value.startSelectionPoint == null || drawableArea == null ||
      !drawableArea.contains(value.startSelectionPoint!.localPosition);
  final bool hideEndHandle = ... same for end ...;
  effectiveStartHandle = hideStartHandle ? null : _startHandleLayer;
  effectiveEndHandle = hideEndHandle ? null : _endHandleLayer;
  ...
  _startHandleLayerOwner!.pushHandleLayers(effectiveStartHandle, null);  // etc.
  ```
  Every nested container delegate runs this check against **its own** `containerSize`: the SelectableRegion root, each Scrollable's delegate (= the viewport size), and SelectionArea's inner containers. A handle whose point lies more than 5 px outside **any** enclosing container therefore gets a `null` LayerLink pushed down.
- `getSelectionGeometry()` :2634-2727 keeps off-screen points as **non-null**, with off-viewport coordinates. It nulls them only when the transform is non-finite (`start.isFinite` at :2668, and the same check for end). It also walks inward to find a non-null child point (:2654-2659, :2681-2684). Selection *rects* are clipped to the drawable area (:2705-2718). Handle points are not clipped; they are gated instead.

### What happens to the start handle in SelectableRegionState
- `_hasSelectionOverlayGeometry` :409-411 is true while either point is non-null. The overlay exists whenever either point is non-null.
- `_createSelectionOverlay` :1280-1309 and `_updateSelectionOverlay` :1311-1323 pass `startHandleLayerLink: _startHandleLayerLink` / `endHandleLayerLink`. The fallbacks (`start?.handleType ?? left`, `lineHeightAtStart: start?.lineHeight ?? end!.lineHeight`) only set handle **type and size**.
- `selectionEndpoints` :1788-1806 falls back to `start?.localPosition ?? end!.localPosition`. Those endpoints feed the **toolbar** anchor and the magnifier, **not the handle position**. The handle's position comes only from the LeaderLayer the Selectable paints. So a handle is **never drawn at the other end's position**.
- In test 092 the start point is not null at all. The root reports `start=Offset(-924.1, 20.0)`. The fallback code path does not come into it.

## 3. SelectionOverlay / `_SelectionHandleOverlay` (widgets/text_selection.dart)
- `startHandlesVisible`/`endHandlesVisible` (:1064/:1070, docs :1256-1260 "If this is null, the start selection handle will always be visible") are passed to `_SelectionHandleOverlay.visibility` (:1783, :1814). This drives an AnimationController: forward if `visibility?.value ?? true` (:2029-2035). With a null listenable the opacity is pinned at 1.0.
- The handle is `CompositedTransformFollower(link: handleLayerLink, showWhenUnlinked: false, child: FadeTransition(...))` (:2096-2100).
  - Unlinked means `FollowerLayer` paints nothing.
  - `RenderFollowerLayer.hitTest` returns false when `link.leader == null && !showWhenUnlinked` (rendering/proxy_box.dart:4672-4677).
- The old `TextSelectionOverlay` (:353-355, :362, :368, :421-432) feeds `_effectiveStart/EndHandleVisibility = _handlesVisible && renderObject.selectionStart/EndInViewport`. It also feeds `_effectiveToolbarVisibility = startInViewport || endInViewport`. For EditableText the LeaderLayers are always pushed by RenderEditable, so the fade is the *only* hiding mechanism there.
- RenderEditable's "in viewport" test is `Offset.zero & size` inflated by 0.5 (rendering/editable.dart:697-728). That is only its **own** box, the same scope as SelectableRegion's per-container check.

## 4. Paragraph / Selection docs
- `SelectionGeometry.startSelectionPoint` docs (rendering/selection.dart:760-761): "Can be null if the selection start is offstage, for example, when the selection is outside of the viewport or is kept alive by a scrollable."
- `SelectionHandler.pushHandleLayers` docs (selection.dart:77-90): the handler pushes LeaderLayers only for the non-null links it is given.
- `_SelectableFragment._getSelectionGeometry` (rendering/paragraph.dart:1525-1570) always returns non-null points in paragraph coordinates. The paragraph does **not** check its own bounds.
- `_SelectableFragment.paintHandles` (:3619-3641) pushes a `LeaderLayer` only if its link is non-null **and** the point is non-null.
- Second, independent culling: sliver lists do not paint children outside the paint extent (sliver_multi_box_adaptor.dart paint, ~:690-730). Their paragraphs push no LeaderLayer, so their handles go unlinked as well. Items outside the cache extent are disposed. Their points drop out, and when both are gone the overlay is disposed (`_updateSelectionStatus` :545-558).

## 5. Probe output (android default; key lines)
### A. Test 092 scenario (`SelectableText`, maxLines 1, long-press at +300, drag +300/+300/+400/+700)
```
after long press:  root start=(185.4,20) end=(327.9,20); overlay=false (android hides handles while dragging)
after drag, before up (1 and 2 pumps): end=(1909.5,20); overlay=false, 0 handle overlays
after up + settle:
  StaticSelectionContainerDelegate (root, 800x20)        start=(-924.1,20) end=(800.0,20)
  _ScrollableSelectionContainerDelegate (viewport 800x20) start=(-924.1,20) end=(800.0,20)
  _SelectableTextContainerDelegate (1909.5x20, globalTL x=-1109.5) start=(185.4,20) end=(1909.5,20)
  _SelectionHandleOverlay count=2
  handle[0] opacity=1.0 leaderLinked=false rect=(0,0,48,48)*  hitTestable=false
  handle[1] opacity=1.0 leaderLinked=true  rect=(787,297,835,345)  (center off right edge)
```
\* An unlinked follower's `getRect` falls back to the identity transform, so (0,0,48,48) is a stale value, not a painted location. The two handles do not overlap or share an x. The start handle is simply not composited.

### B. `SelectionArea` > `ListView.builder` (60 x 40 px `Text`), select items 5..9, scroll
```
no scroll:     root start=(270.9,220) end=(327.9,380); both handles linked, hitTestable=true
jumpTo(260) (1 pump and settled): root start=(270.9,-40) end=(327.9,120)
  handle[0] opacity=1.0 leaderLinked=false hitTestable=false
  handle[1] opacity=1.0 leaderLinked=true  hitTestable=true
jumpTo(1000):  root start=null end=null (status still uncollapsed); overlay disposed, 0 handle overlays
jumpTo(0):     points non-null again, but selectionOverlay=false: handles do NOT come back (side finding)
```
This matches A: the start handle is hidden by unlinking, and its opacity stays 1.0.

### C. `SelectableText` inside an outer `ListView` under an `AppBar` (SelectionArea is *inside* the outer scrollable)
```
word selected (text y 156..176): both linked
scrolled so text y 26..46 (fully under AppBar, outside list viewport): both leaderLinked=false (list culls paint)
scrolled so text y 51..71 (partially under AppBar): both linked, handles at y 58..106 (hang below the line, below AppBar)
```
The outer scrollable is not in the SelectableRegion's container chain, so no drawable-area check applies. Hiding here comes only from sliver paint culling. EditableText has the same scope limitation (its check is only against its own box). No floating over the AppBar was observed with Android-style handles that hang below the line. (Side observation: a touch long-press on the SelectableText inside the vertical ListView did not select; double-tap did. Not investigated.)

## 6. Conclusions
**(a) Mechanism.** `MultiSelectableSelectionContainerDelegate._updateHandleLayersAndOwners` (selectable_region.dart:2766-2820) withholds the handle `LayerLink` when the edge point lies outside that container's box inflated by 5 px. The handle's `CompositedTransformFollower(showWhenUnlinked: false)` (text_selection.dart:2096-2100) then paints nothing and cannot be hit. `_ScrollableSelectionContainerDelegate` re-runs the check after each scroll (post-frame `layoutDidChange`). The check runs at every nested container level: the SelectableRegion root, every Scrollable inside the SelectionArea (SelectableText's internal SingleChildScrollView, ListView, and so on), and SelectionArea inner containers. Sliver paint culling adds a second layer for list children outside the viewport. It does not cover scrollables *above* the SelectionArea. That is parity with EditableText, whose in-viewport test is also limited to its own box.

**(b) Test 092.** The start handle's `FadeTransition.opacity` is 1.0 because SelectableRegion passes no visibility listenable, so the controller is forwarded and never reversed. The handle is **not** drawn at the end point and **not** drawn opaque somewhere off-screen. It is **unlinked (`leaderLinked=false`), so nothing is painted and it is not hit-testable**. Its `_SelectionHandleOverlay` widget still exists, which is why the test finds 2 FadeTransitions. Test 092 asserts on a mechanism (FadeTransition opacity) that SelectableRegion does not use. The user-visible behavior it guards ("start handle hidden because it is out of view") already holds.

**(c) Audit verdict: partly right, wrong on impact.**
- Correct: SelectableRegion does not pass `startHandlesVisible`/`endHandlesVisible`, so the off-screen handle's FadeTransition opacity stays 1.0.
- Wrong: "stays fully opaque and floats over other UI". The handle is removed from compositing by LayerLink withholding.
- Precise statement: *"SelectableRegion hides a handle whose edge is outside an enclosing selection container (including any Scrollable inside the SelectionArea) by not pushing its LeaderLayer, so the handle disappears immediately instead of fading out over `SelectionOverlay.fadeDuration`. Its `FadeTransition` opacity stays 1.0 because no visibility listenable is supplied. Test 092's opacity assertion is therefore checking an EditableText-specific mechanism."*
- Real residual differences:
  - Pop instead of a 150 ms fade.
  - A 5 px tolerance (vs 0.5) in the check.
  - The toolbar-visibility-when-both-edges-off-screen behavior (`_effectiveToolbarVisibility`, text_selection.dart:430-431) is not verified here.
  - Side finding: after scrolling far enough that the selected items are disposed and then back, handles do not reappear.

**(d) Smallest correct fix.** No framework fix is needed for the "floating handle" claim. The smallest change is in the **test**: in selectable_text_test.dart ("long press drag can edge scroll", ~:4383-4405), assert that the start handle's `CompositedTransformFollower`/`RenderFollowerLayer` is unlinked (`link.leader == null`), or that it is not hit-testable, instead of checking `FadeTransition.opacity == 0.0`. Then recategorize it as an accepted mechanism difference. To get fade parity as well:
- Add `ValueNotifier<bool>` start/end visibility in `SelectableRegionState`.
- Set them in `_updateSelectionStatus` (selectable_region.dart:545-558) from whether the root geometry points lie within the region's box (the same predicate as :2778-2785).
- Pass them as `startHandlesVisible`/`endHandlesVisible` in `_createSelectionOverlay` (:1280).

That alone would not animate: unlinking still hides the handle on the same frame. A true fade would need to keep the leader pushed while fading, which is a larger change to `_updateHandleLayersAndOwners`. It is not worth doing for the migration.
