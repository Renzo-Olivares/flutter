# Flutter Text Testing: Core Pitfalls, Timing & Simulation Patterns

This document is a focused testing reference for the Flutter text subsystem (`packages/flutter/test/widgets/`, `rendering/`, `material/`, `cupertino/`, and `services/`). It details the most common traps, timing invariants, font geometry rules, and platform channel mocking techniques that are critical when writing or fixing text tests in Flutter.

---

## Table of Contents
- [Component & Class Index](#component--class-index)
1. [Test File Location Guide: Where to Add Tests](#1-test-file-location-guide-where-to-add-tests)
2. [Multi-Tap Timing & The Consecutive Tap Reset Trap](#2-multi-tap-timing--the-consecutive-tap-reset-trap)
3. [Caret Blinking & `pumpAndSettle()` Timeout / Leaks](#3-caret-blinking--pumpandsettle-timeout--leaks)
4. [Font Geometry, Hit-Testing & The Drag Slop Trap](#4-font-geometry-hit-testing--the-drag-slop-trap)
5. [Finding & Interacting with Floating Overlays & Toolbars](#5-finding--interacting-with-floating-overlays--toolbars)
6. [Realistic IME Simulation (`TestTextInput` vs. `enterText`)](#6-realistic-ime-simulation-testtextinput-vs-entertext)
7. [BiDi & TextAffinity Assertions](#7-bidi--textaffinity-assertions)
8. [Edge Scrolling & Viewport Drag Simulation](#8-edge-scrolling--viewport-drag-simulation)

---

## Component & Class Index

| Component / Symbol | Source File / Location | Concise Summary |
| :--- | :--- | :--- |
| [`TestTextInput`](file:///Users/roliv/flutter/packages/flutter_test/lib/src/test_text_input.dart) | [`packages/flutter_test/lib/src/test_text_input.dart`](file:///Users/roliv/flutter/packages/flutter_test/lib/src/test_text_input.dart) | Testing stub intercepting `'flutter/textinput'` channel calls to simulate native keyboard interactions. |
| [`TestGesture`](file:///Users/roliv/flutter/packages/flutter_test/lib/src/gesture.dart) | [`packages/flutter_test/lib/src/gesture.dart`](file:///Users/roliv/flutter/packages/flutter_test/lib/src/gesture.dart) | Low-level pointer simulation handle for down, up, move, and multi-tap sequences. |
| `kDoubleTapMinTime` | [`packages/flutter/lib/src/gestures/constants.dart`](file:///Users/roliv/flutter/packages/flutter/lib/src/gestures/constants.dart) | Minimum delay (40ms) required between consecutive taps to register as a double-tap. |
| `kDoubleTapTimeout` | [`packages/flutter/lib/src/gestures/constants.dart`](file:///Users/roliv/flutter/packages/flutter/lib/src/gestures/constants.dart) | Maximum duration (300ms) after which consecutive tap counting resets back to single tap. |
| `kTouchSlop` / `kPanSlop` | [`packages/flutter/lib/src/gestures/constants.dart`](file:///Users/roliv/flutter/packages/flutter/lib/src/gestures/constants.dart) | Physical distance thresholds (18px / 36px) that pointer drag must exceed before claiming the gesture arena. |
| [`AdaptiveTextSelectionToolbar`](file:///Users/roliv/flutter/packages/flutter/lib/src/material/adaptive_text_selection_toolbar.dart) | [`packages/flutter/lib/src/material/adaptive_text_selection_toolbar.dart`](file:///Users/roliv/flutter/packages/flutter/lib/src/material/adaptive_text_selection_toolbar.dart) | Adaptive toolbar widget (frozen here; active in `material_ui` under `flutter/packages`). |
| [`CupertinoAdaptiveTextSelectionToolbar`](file:///Users/roliv/flutter/packages/flutter/lib/src/cupertino/adaptive_text_selection_toolbar.dart) | [`packages/flutter/lib/src/cupertino/adaptive_text_selection_toolbar.dart`](file:///Users/roliv/flutter/packages/flutter/lib/src/cupertino/adaptive_text_selection_toolbar.dart) | Cupertino adaptive toolbar (frozen here; active in `cupertino_ui` under `flutter/packages`). |
| [`TextMagnifier`](file:///Users/roliv/flutter/packages/flutter/lib/src/material/magnifier.dart) | [`packages/flutter/lib/src/material/magnifier.dart`](file:///Users/roliv/flutter/packages/flutter/lib/src/material/magnifier.dart) | Android/Material magnifying glass (frozen here; active in `material_ui` under `flutter/packages`). |
| [`CupertinoTextMagnifier`](file:///Users/roliv/flutter/packages/flutter/lib/src/cupertino/magnifier.dart) | [`packages/flutter/lib/src/cupertino/magnifier.dart`](file:///Users/roliv/flutter/packages/flutter/lib/src/cupertino/magnifier.dart) | iOS magnifying glass (frozen here; active in `cupertino_ui` under `flutter/packages`). |

---

## 1. Test File Location Guide: Where to Add Tests

Always respect Flutter's layer hierarchy when adding or modifying tests. Do not test low-level rendering or services features in Material or Cupertino test suites. Note that active Material and Cupertino component development belongs in `material_ui` and `cupertino_ui` under the `flutter/packages` repository.

| Subsystem / Feature Area | Target Test File | When to Test Here |
| :--- | :--- | :--- |
| **Unified Selection (Core)** | [`packages/flutter/test/widgets/selectable_region_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/widgets/selectable_region_test.dart) | `SelectableRegion` state, registration, multi-child event routing, cross-region drag selection. |
| **Unified Selection (Web Context Menu)** | [`packages/flutter/test/widgets/selectable_region_context_menu_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/widgets/selectable_region_context_menu_test.dart) | **Web-only (`@TestOn('browser')`)**: tests native browser context menus and web DOM text selection overlays. |
| **Unified Selection (Scrolling & Auto-Scroll)** | [`packages/flutter/test/widgets/scrollable_selection_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/widgets/scrollable_selection_test.dart)<br>[`packages/flutter/test/widgets/selectable_region_scroll_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/widgets/selectable_region_scroll_test.dart) | Drag-selection inside/across `Scrollable`s, `EdgeDraggingAutoScroller` autoscrolling, and scroll offsets. |
| **Selection Container & Delegation** | [`packages/flutter/test/widgets/selection_container_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/widgets/selection_container_test.dart) | `SelectionContainer`, `SelectionContainer.disabled`, delegate tree hierarchies, and spatial sorting (`compareOrder`). |
| **Low-Level Selection Protocol** | [`packages/flutter/test/rendering/selection_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/rendering/selection_test.dart) | Low-level `Selectable`, `SelectionHandler`, `SelectionGeometry`, and `SelectionEvent` unit tests. |
| **Editable Text (Core State & Lifecycle)** | [`packages/flutter/test/widgets/editable_text_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/widgets/editable_text_test.dart) | `EditableTextState`, focus attachment, controller synchronization, and method channel setup. |
| **Editable Text (Cursor & Caret)** | [`packages/flutter/test/widgets/editable_text_cursor_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/widgets/editable_text_cursor_test.dart) | Cursor blinking animations, cursor color, opacity, and iOS floating cursor gestures. |
| **Editable Text (Shortcuts & Selectors)** | [`packages/flutter/test/widgets/editable_text_shortcuts_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/widgets/editable_text_shortcuts_test.dart)<br>[`packages/flutter/test/widgets/default_text_editing_shortcuts_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/widgets/default_text_editing_shortcuts_test.dart) | Hardware keyboard shortcuts, `DefaultTextEditingShortcuts`, intent mappings, and macOS selector dispatches. |
| **Editable Text (Auto-Scroll & Show-On-Screen)** | [`packages/flutter/test/widgets/editable_text_show_on_screen_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/widgets/editable_text_show_on_screen_test.dart) | Automatic viewport scrolling when caret navigates or text expands beyond bounds. |
| **Editable Text (Stylus / Scribble & Scribe)** | [`packages/flutter/test/widgets/editable_text_scribble_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/widgets/editable_text_scribble_test.dart)<br>[`packages/flutter/test/widgets/editable_text_scribe_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/widgets/editable_text_scribe_test.dart) | Apple Scribble handwriting and Android Stylus Scribe input protocols. |
| **Editable Text (Span & Composing Styles)** | [`packages/flutter/test/widgets/editable_text_styles_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/widgets/editable_text_styles_test.dart) | Styled `InlineSpan` trees and IME composing range styling within editable fields. |
| **Text Gestures & Arena Resolution** | [`packages/flutter/test/widgets/text_selection_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/widgets/text_selection_test.dart) | `TextSelectionGestureDetector`, `TapAndPanGestureRecognizer`, and tap-and-drag gesture recognizers. |
| **System Context Menu (iOS 16+)** | [`packages/flutter/test/widgets/system_context_menu_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/widgets/system_context_menu_test.dart) | `SystemContextMenu`, `SystemContextMenuController`, and Apple native secure paste integration. |
| **Low-Level Editable Rendering** | [`packages/flutter/test/rendering/editable_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/rendering/editable_test.dart)<br>[`packages/flutter/test/rendering/editable_gesture_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/rendering/editable_gesture_test.dart)<br>[`packages/flutter/test/rendering/editable_intrinsics_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/rendering/editable_intrinsics_test.dart) | `RenderEditable` layout, painting, selection boxes, caret geometry, pointer routing, and intrinsic sizing. |
| **Static Text & Paragraph Rendering** | [`packages/flutter/test/widgets/text_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/widgets/text_test.dart)<br>[`packages/flutter/test/widgets/rich_text_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/widgets/rich_text_test.dart)<br>[`packages/flutter/test/rendering/paragraph_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/rendering/paragraph_test.dart) | `Text`, `RichText`, `RenderParagraph`, `InlineSpan.hitTest`, `WidgetSpan` layout, and intrinsics. |
| **Text Painter & Typography** | [`packages/flutter/test/painting/text_painter_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/painting/text_painter_test.dart) | `TextPainter` layout caching, line metrics calculations, `TextScaler`, and `TextStyle` painting. |
| **Logical Boundaries & Iterators** | [`packages/flutter/test/services/text_boundary_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/services/text_boundary_test.dart) | Character, word, line, paragraph, and document text boundaries. |
| **Platform Channels & Deltas** | [`packages/flutter/test/services/text_input_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/services/text_input_test.dart)<br>[`packages/flutter/test/services/delta_text_input_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/services/delta_text_input_test.dart) | Platform channel codec, `TextInputConnection`, and `TextEditingDelta` diff stream processing. |
| **Material Text (Frozen / Legacy)** | [`packages/flutter/test/material/text_field_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/material/text_field_test.dart)<br>[`packages/flutter/test/material/selection_area_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/material/selection_area_test.dart)<br>[`packages/flutter/test/material/adaptive_text_selection_toolbar_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/material/adaptive_text_selection_toolbar_test.dart) | Legacy tests for frozen Material text components in `flutter/flutter` (active tests belong in `material_ui` under `flutter/packages`). |
| **Cupertino Text (Frozen / Legacy)** | [`packages/flutter/test/cupertino/text_field_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/cupertino/text_field_test.dart)<br>[`packages/flutter/test/cupertino/adaptive_text_selection_toolbar_test.dart`](file:///Users/roliv/flutter/packages/flutter/test/cupertino/adaptive_text_selection_toolbar_test.dart) | Legacy tests for frozen Cupertino text components in `flutter/flutter` (active tests belong in `cupertino_ui` under `flutter/packages`). |

---

## 2. Multi-Tap Timing & The Consecutive Tap Reset Trap

### The `pumpAndSettle()` Anti-Pattern

Flutter's text gesture recognizers ([`BaseTapAndDragGestureRecognizer`](file:///Users/roliv/flutter/packages/flutter/lib/src/gestures/tap_and_drag.dart)) track consecutive tap counts (`consecutiveTapCount = 1, 2, 3`) using an internal timer bounded by `kDoubleTapTimeout` (300ms).

> [!CAUTION]
> **Never call `tester.pumpAndSettle()` between multi-taps!**
> Calling `pumpAndSettle()` advances simulated clock time until no more frames are scheduled, which easily exceeds `kDoubleTapTimeout`. The gesture recognizer will reset `consecutiveTapCount` to 1, causing a double-tap to be processed as two disconnected single taps.

### Correct Pattern for Double-Tap & Triple-Tap

Use [`TestGesture`](file:///Users/roliv/flutter/packages/flutter_test/lib/src/gesture.dart) with `tester.pump(kDoubleTapMinTime)` or `tester.pump()`:

```dart
// Double-tap to select word
final TestGesture gesture = await tester.startGesture(tapLocation);
addTearDown(gesture.removePointer);
await tester.pump();
await gesture.up();
await tester.pump(kDoubleTapMinTime);

await gesture.down(tapLocation);
await tester.pump();
await gesture.up();
await tester.pumpAndSettle();

expect(editable.selection, const TextSelection(baseOffset: 0, extentOffset: 5));
```

```dart
// Triple-tap to select paragraph/line
final TestGesture gesture = await tester.startGesture(tapLocation);
addTearDown(gesture.removePointer);

// Tap 1
await tester.pump();
await gesture.up();
await tester.pump();

// Tap 2
await gesture.down(tapLocation);
await tester.pump();
await gesture.up();
await tester.pump();

// Tap 3
await gesture.down(tapLocation);
await tester.pump();
await gesture.up();
await tester.pumpAndSettle();
```

### Resetting Consecutive Tap State Between Test Steps

When multiple interaction steps occur sequentially in a single test, explicitly drain the double-tap timeout so subsequent taps are not misinterpreted as consecutive taps:

```dart
// Reset consecutive tap count cleanly
await tester.tapAt(tapLocation);
await tester.pumpAndSettle(kDoubleTapTimeout);
```

---

## 3. Caret Blinking & `pumpAndSettle()` Timeout / Leaks

### Why Focused `TextField` Hangs `pumpAndSettle()`

When an [`EditableText`](file:///Users/roliv/flutter/packages/flutter/lib/src/widgets/editable_text.dart) receives focus:
1. It registers an infinite cursor blinking animation loop (`_cursorBlinkOpacityController` / `_cursorTimer`).
2. Calling `await tester.pumpAndSettle()` waits indefinitely for the cursor animation to stop.
3. The test **times out after 10 minutes** or fails with `"pumpAndSettle timed out"`.

### Solution: Discrete Pumps & Teardown

```dart
// ❌ WRONG: Hangs forever on focused EditableText
await tester.tap(find.byType(TextField));
await tester.pumpAndSettle();

// ✅ CORRECT: Pump a discrete duration sufficient for layout & frame build
await tester.tap(find.byType(TextField));
await tester.pump();
await tester.pump(const Duration(milliseconds: 100));
```

### Avoiding Pending Timer Exceptions in `tearDown`

If a test ends while a cursor is focused, `flutter_test` can throw `"A Timer is still pending even after the widget tree was disposed"`. 

To prevent this:
1. Unfocus before completing the test:
   ```dart
   FocusManager.instance.primaryFocus?.unfocus();
   await tester.pump();
   ```
2. Or use `tester.pump(const Duration(seconds: 1))` after removing the widget from the tree.

---

## 4. Font Geometry, Hit-Testing & The Drag Slop Trap

### The Headless Test Font

Headless tests run without platform OS fonts. The test environment uses the test font (`Ahem`) by default:
- Every glyph (letters, numbers, symbols) and whitespace is an exact **1x1 em square box**.
- With `fontSize: 10.0`, each character is exactly **10px wide x 10px high**.
- `ascent = 8.0px`, `descent = 2.0px`, `height = 10.0px`.

### The Drag Slop Trap (`kTouchSlop` / `kPanSlop`)

When testing drag selection (e.g. dragging across characters):
- Touch interactions require the drag distance to exceed `kTouchSlop` (18.0px) before the drag starts.
- Mouse pan interactions require exceeding `kPanSlop` (36.0px).

> [!WARNING]
> If you test drag selection with small text (e.g. `fontSize: 10.0`) and drag across only 1 character (10px), **no selection change will occur** because the movement is within the slop threshold.
> 
> **Rule**: In drag-selection tests, use a large font size (e.g. `fontSize: 48.0` or `30.0`), or drag across multiple characters.

### Precise Position Calculation Helper (`textOffsetToPosition`)

To convert a character offset to global coordinates for `tester.tapAt()` or `gesture.moveTo()`:

```dart
Offset textOffsetToPosition(RenderParagraph paragraph, int offset) {
  const Rect caretPrototype = Rect.fromLTWH(0.0, 0.0, 2.0, 20.0);
  final Offset localOffset =
      paragraph.getOffsetForCaret(TextPosition(offset: offset), caretPrototype) +
      Offset(0.0, paragraph.preferredLineHeight / 2);
  return paragraph.localToGlobal(localOffset);
}
```

For [`RenderEditable`](file:///Users/roliv/flutter/packages/flutter/lib/src/rendering/editable.dart):

```dart
Offset editableOffsetToPosition(RenderEditable editable, int offset) {
  final Offset localOffset = editable.getLocalRectForCaret(
    TextPosition(offset: offset),
  ).center;
  return editable.localToGlobal(localOffset);
}
```

### Why a Single `gesture.moveTo()` May Not Trigger `onDragUpdate`

In [`BaseTapAndDragGestureRecognizer`](file:///Users/roliv/flutter/packages/flutter/lib/src/gestures/tap_and_drag.dart), when a pointer moves after `PointerDownEvent`:
1. The **first** `PointerMoveEvent` exceeding `kTouchSlop` / `kPanSlop` transitions the recognizer into `_DragState.accepted` and fires `onDragStart`. This first move is consumed as the anchor position of the drag.
2. The `onDragUpdate` callback (which drives `SelectionEdgeUpdateEvent` and actually moves the selection extent) is **only dispatched on subsequent move events**.

> [!IMPORTANT]
> **Issue Multiple Move Events in Drag Tests**:
> If you call `await gesture.moveTo(target)` only once after `gesture.down()`, that single move event may only register the drag start without firing `onDragUpdate` or advancing the selection extent.
> 
> When testing drag selection with `TestGesture`, always issue intermediate move calls or multiple sequential `moveTo()` steps:
> ```dart
> // 1. Down: Initial press
> await gesture.down(textOffsetToPosition(paragraph, 0));
> await tester.pump();
> 
> // 2. First move: Exceeds slop, transitions to accepted, fires onDragStart
> await gesture.moveTo(textOffsetToPosition(paragraph, 2));
> await tester.pump();
> 
> // 3. Second move: Fires onDragUpdate, updating selection extent
> await gesture.moveTo(textOffsetToPosition(paragraph, 5));
> await tester.pumpAndSettle();
> 
> expect(paragraph.selections[0], const TextSelection(baseOffset: 0, extentOffset: 5));
> ```

---

## 5. Finding & Interacting with Floating Overlays & Toolbars

### Overlay Hierarchy Isolation

Selection handles, magnifiers, and context menu toolbars are **not child widgets** of `TextField` or `SelectionArea`. They are inserted into the application root [`Overlay`](file:///Users/roliv/flutter/packages/flutter/lib/src/widgets/overlay.dart).

```dart
// ❌ WRONG: Toolbar is not a child of TextField
expect(find.descendant(of: find.byType(TextField), matching: find.text('Copy')), findsOneWidget);

// ✅ CORRECT: Search the global Overlay / Tree
expect(find.text('Copy'), findsOneWidget);
```

### Finding Platform-Specific Toolbars

```dart
// Material adaptive toolbar
expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);

// Cupertino adaptive toolbar
expect(find.byType(CupertinoAdaptiveTextSelectionToolbar), findsOneWidget);

// Tapping a context menu action button
await tester.tap(find.text('Copy'));
await tester.pumpAndSettle();
```

### Finding & Dragging Selection Handles

Selection handles are floating overlay controls attached to the text via [`CompositedTransformFollower`](file:///Users/roliv/flutter/packages/flutter/lib/src/widgets/basic.dart). Because handles are dynamically positioned by leader-layer offsets, Flutter tests interact with handles using two canonical approaches:

#### Method A: Geometric Dragging via Selection Endpoints (Standard Practice)

Instead of searching for handle widgets by generic types (which is fragile), calculate the handle's exact coordinates using the render object's selection endpoints:

**1. For `RenderEditable` (`TextField` / `EditableText`)**:
```dart
final RenderEditable renderEditable = findRenderEditable(tester);
final List<TextSelectionPoint> endpoints = globalize(
  renderEditable.getEndpointsForSelection(controller.selection),
  renderEditable,
);
expect(endpoints.length, 2);

// Start handle (endpoints[0]) & End handle (endpoints[1])
// Note: An offset (e.g. ±1px) targets the handle body attached to the endpoint
final Offset startHandlePos = endpoints[0].point + const Offset(-1.0, 1.0);
final Offset endHandlePos = endpoints[1].point + const Offset(1.0, 1.0);

// Drag the end handle to expand selection
final TestGesture gesture = await tester.startGesture(endHandlePos);
addTearDown(gesture.removePointer);
await tester.pump();
await gesture.moveTo(textOffsetToPosition(tester, 10));
await tester.pump();
await gesture.up();
await tester.pumpAndSettle();
```

**2. For `RenderParagraph` (`SelectableRegion` / `SelectionArea`)**:
```dart
final RenderParagraph paragraph = tester.renderObject(find.byType(RichText));
final List<TextBox> boxes = paragraph.getBoxesForSelection(paragraph.selections.first);
final Offset startHandlePos = globalize(boxes.first.toRect().bottomLeft, paragraph);
final Offset endHandlePos = globalize(boxes.last.toRect().bottomRight, paragraph);

// Drag the start handle backward
final TestGesture gesture = await tester.startGesture(startHandlePos);
addTearDown(gesture.removePointer);
await gesture.moveTo(textOffsetToPosition(paragraph, 0));
await tester.pump();
await gesture.up();
await tester.pumpAndSettle();
```

#### Method B: Asserting Handle Visibility via Overlay Hierarchy

When verifying that handles appear or fade out:

```dart
// Find handle FadeTransitions nested inside CompositedTransformFollower
final Finder handleTransitions = find.descendant(
  of: find.byType(CompositedTransformFollower),
  matching: find.byType(FadeTransition),
);

// 2 handles (start & end) should be visible
expect(handleTransitions, findsNWidgets(2));
final FadeTransition startHandle = tester.widget(handleTransitions.at(0));
expect(startHandle.opacity.value, equals(1.0));
```

```dart
// Check handle touch gesture hit area
final Finder handleGestureDetector = find.descendant(
  of: find.byType(CompositedTransformFollower),
  matching: find.descendant(
    of: find.byType(FadeTransition),
    matching: find.byType(RawGestureDetector),
  ),
);
expect(handleGestureDetector, findsNWidgets(2));
```

---

## 6. Realistic IME Simulation (`TestTextInput` vs. `enterText`)

### Limitations of `tester.enterText()`

`tester.enterText(finder, 'new text')` replaces the field's entire text string at once. It bypasses:
- Active IME composing ranges (marked text).
- Granular deltas.
- Input action buttons (`Done`, `Search`, `Next`).

### Testing Composing Ranges with `TestTextInput`

To test multi-stage IME composition (such as CJK input or autocorrect pre-composition):

```dart
// Focus field
await tester.tap(find.byType(TextField));
await tester.pump();

// 1. Send marked composing text: "ni" (composing range 0..2)
tester.testTextInput.updateEditingValue(
  const TextEditingValue(
    text: 'ni',
    selection: TextSelection.collapsed(offset: 2),
    composing: TextRange(start: 0, end: 2),
  ),
);
await tester.pump();

expect(controller.value.composing, const TextRange(start: 0, end: 2));

// 2. Commit composed Chinese character: "你" (composing cleared)
tester.testTextInput.updateEditingValue(
  const TextEditingValue(
    text: '你',
    selection: TextSelection.collapsed(offset: 1),
    composing: TextRange.empty,
  ),
);
await tester.pump();

expect(controller.text, '你');
expect(controller.value.composing, TextRange.empty);
```

### Simulating Keyboard Action Buttons

```dart
// Simulate user pressing keyboard action (e.g. Done / Search)
await tester.testTextInput.receiveAction(TextInputAction.done);
await tester.pump();
```

---

## 7. BiDi & TextAffinity Assertions

### Asserting Affinity at Soft Line Wraps

When text soft-wraps across lines, character offset $N$ exists at both the end of Line 1 and the start of Line 2:
- `TextPosition(offset: N, affinity: TextAffinity.upstream)` -> trailing edge of Line 1.
- `TextPosition(offset: N, affinity: TextAffinity.downstream)` -> leading edge of Line 2.

```dart
// Always assert TextAffinity when checking cursor position at wrap boundaries
expect(
  editable.selection,
  const TextSelection(
    baseOffset: 10,
    extentOffset: 10,
    affinity: TextAffinity.upstream,
  ),
);
```

### Asserting Mixed LTR/RTL Boundaries

```dart
// String: "abc אבג def"
// Tap between Latin and Hebrew glyphs
final RenderParagraph paragraph = tester.renderObject(find.byType(RichText));
final Offset bidiBoundary = textOffsetToPosition(paragraph, 4);

await tester.tapAt(bidiBoundary);
await tester.pump();

// Verify caret resolved to correct visual writing direction
final TextPosition position = paragraph.getPositionForOffset(
  paragraph.globalToLocal(bidiBoundary),
);
expect(position.offset, 4);
```

---

## 8. Edge Scrolling & Viewport Drag Simulation

### Inside-Edge vs. Outside-Edge Drag Scenarios

When testing selection drag and auto-scrolling in `Scrollable` / `SelectableRegion`, test both geometric entry conditions:

1. **Inside-Edge Drags (Within Viewport Bounds)**:
   - Simulates physical touch screens (full-screen views without `SafeArea` insets) where the pointer cannot physically leave the screen boundaries.
   - Position the pointer within the inner edge band (e.g. $5\text{ px}$ inside the boundary):
   ```dart
   // 5 pixels ABOVE bottom edge (strictly inside the scrollable)
   final Offset insideBottom = tester.getBottomLeft(find.byType(ListView)) + const Offset(10, -5);
   await gesture.moveTo(insideBottom);
   await tester.pump();
   await tester.pump(const Duration(milliseconds: 100));

   expect(controller.offset, greaterThan(0.0));
   ```

2. **Outside-Edge Drags (Past Viewport Bounds)**:
   - Simulates desktop windowed apps or dialogs where the pointer moves past the scrollable into surrounding window margins or parent widgets.
   ```dart
   // 40 pixels PAST bottom edge (strictly outside the scrollable)
   final Offset outsideBottom = tester.getBottomRight(find.byType(ListView)) + const Offset(0, 40);
   await gesture.moveTo(outsideBottom);
   await tester.pump();
   await tester.pump(const Duration(milliseconds: 100));

   expect(controller.offset, greaterThan(0.0));
   ```

### Multi-Axis and Bidirectional Test Verification

Scrollable selection containers are axis-agnostic. Always test both axes and bidirectional movement to prevent coordinate inversion bugs (`dx`/`dy`, `width`/`height`, `top`/`bottom` vs. `left`/`right`):
- **`Axis.vertical`**: Forward (bottom edge) and backward (top edge).
- **`Axis.horizontal`**: Forward (right edge) and backward (left edge).

### Direct Drag vs. Selection Handle Drag Simulation

When testing auto-scrolling inside viewport bounds, verify both drag modalities:

1. **Direct Drag (Mouse / Long-Press Move)**:
   - Tests pointer drag where the coordinate directly tracks the touch point.
2. **Selection Handle Drag Within Bounds**:
   - Long-press to bring up selection handles, then drag the start or end handle to a point strictly within bounds ($5\text{px}$ from the edge).
   - Verifies that the `lineHeight / 2` caret offset does not prevent the selection handle from activating edge scrolling when dragged to the edge on full-screen mobile views.
   - *(Note: Avoid only testing handle dragging by moving 40px outside the viewport, as dragging past the viewport masks the `lineHeight / 2` offset).*

### Gesture Release & Scroll Cessation Invariant

Whenever testing edge auto-scrolling, always assert that releasing the gesture halts scrolling immediately and does not continue scrolling during subsequent pumps:

```dart
// 1. Release the gesture
await gesture.up();
await tester.pump();
await tester.pump(const Duration(seconds: 1));
final double offsetAfterRelease = controller.offset;

// 2. Settle the tree and ensure no phantom overscroll occurred
await tester.pumpAndSettle();
expect(controller.offset, offsetAfterRelease);
```


