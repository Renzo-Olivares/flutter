# Flutter Text Testing: Core Pitfalls, Timing & Simulation Patterns

This document is a focused testing reference for the Flutter text subsystem (`packages/flutter/test/widgets/`, `rendering/`, `material/`, `cupertino/`, and `services/`). It details the most common traps, timing invariants, font geometry rules, and platform channel mocking techniques that are critical when writing or fixing text tests in Flutter.

---

## Table of Contents
- [Component & Class Index](#component--class-index)
1. [Test File Location Guide: Where to Add Tests](#1-test-file-location-guide-where-to-add-tests)
2. [Multi-Tap Timing & The Consecutive Tap Reset Trap](#2-multi-tap-timing--the-consecutive-tap-reset-trap)
3. [Caret Blinking, Frame Settlement & Disposal](#3-caret-blinking-frame-settlement--disposal)
4. [Font Geometry, Hit-Testing & The Drag Slop Trap](#4-font-geometry-hit-testing--the-drag-slop-trap)
5. [Finding & Interacting with Floating Overlays & Toolbars](#5-finding--interacting-with-floating-overlays--toolbars)
6. [Realistic IME Simulation (`TestTextInput` vs. `enterText`)](#6-realistic-ime-simulation-testtextinput-vs-entertext)
7. [BiDi & TextAffinity Assertions](#7-bidi--textaffinity-assertions)
8. [Edge Scrolling & Viewport Drag Simulation](#8-edge-scrolling--viewport-drag-simulation)

---

## Component & Class Index

| Component / Symbol | Source File / Location | Concise Summary |
| :--- | :--- | :--- |
| [`TestTextInput`](../../../../packages/flutter_test/lib/src/test_text_input.dart) | [`packages/flutter_test/lib/src/test_text_input.dart`](../../../../packages/flutter_test/lib/src/test_text_input.dart) | Testing stub intercepting `'flutter/textinput'` channel calls to simulate native keyboard interactions. |
| [`TestGesture`](../../../../packages/flutter_test/lib/src/test_pointer.dart) | [`packages/flutter_test/lib/src/test_pointer.dart`](../../../../packages/flutter_test/lib/src/test_pointer.dart) | Low-level pointer simulation handle for down, up, move, and multi-tap sequences. |
| `kDoubleTapMinTime` | [`packages/flutter/lib/src/gestures/constants.dart`](../../../../packages/flutter/lib/src/gestures/constants.dart) | 40ms minimum used by the general double-tap recognizer; the text tap-and-drag recognizers do not enforce this minimum. |
| `kDoubleTapTimeout` | [`packages/flutter/lib/src/gestures/constants.dart`](../../../../packages/flutter/lib/src/gestures/constants.dart) | 300ms timeout between taps; an expired tap series starts again on the next pointer down. |
| `kTouchSlop` / `kPanSlop` | [`packages/flutter/lib/src/gestures/constants.dart`](../../../../packages/flutter/lib/src/gestures/constants.dart) | Default non-mouse hit/pan thresholds (18 / 36 logical pixels), subject to device gesture settings; mouse uses 1 / 2 logical pixels. |
| [`AdaptiveTextSelectionToolbar`](../../../../packages/flutter/lib/src/material/adaptive_text_selection_toolbar.dart) | [`packages/flutter/lib/src/material/adaptive_text_selection_toolbar.dart`](../../../../packages/flutter/lib/src/material/adaptive_text_selection_toolbar.dart) | Adaptive toolbar widget (frozen here; active in `material_ui` under `flutter/packages`). |
| [`CupertinoAdaptiveTextSelectionToolbar`](../../../../packages/flutter/lib/src/cupertino/adaptive_text_selection_toolbar.dart) | [`packages/flutter/lib/src/cupertino/adaptive_text_selection_toolbar.dart`](../../../../packages/flutter/lib/src/cupertino/adaptive_text_selection_toolbar.dart) | Cupertino adaptive toolbar (frozen here; active in `cupertino_ui` under `flutter/packages`). |
| [`TextMagnifier`](../../../../packages/flutter/lib/src/material/magnifier.dart) | [`packages/flutter/lib/src/material/magnifier.dart`](../../../../packages/flutter/lib/src/material/magnifier.dart) | Android/Material magnifying glass (frozen here; active in `material_ui` under `flutter/packages`). |
| [`CupertinoTextMagnifier`](../../../../packages/flutter/lib/src/cupertino/magnifier.dart) | [`packages/flutter/lib/src/cupertino/magnifier.dart`](../../../../packages/flutter/lib/src/cupertino/magnifier.dart) | iOS magnifying glass (frozen here; active in `cupertino_ui` under `flutter/packages`). |

---

## 1. Test File Location Guide: Where to Add Tests

Place focused tests in the layer that owns the behavior; use component tests for interactions that depend on Material or Cupertino UI. Active Material and Cupertino component development belongs in `material_ui` and `cupertino_ui` under the `flutter/packages` repository, while existing framework suites remain useful references for legacy behavior.

| Subsystem / Feature Area | Target Test File | When to Test Here |
| :--- | :--- | :--- |
| **Unified Selection (Core)** | [`packages/flutter/test/widgets/selectable_region_test.dart`](../../../../packages/flutter/test/widgets/selectable_region_test.dart) | `SelectableRegion` state, registration, multi-child event routing, cross-region drag selection. |
| **Unified Selection (Web Context Menu)** | [`packages/flutter/test/widgets/selectable_region_context_menu_test.dart`](../../../../packages/flutter/test/widgets/selectable_region_context_menu_test.dart) | **Web-only (`@TestOn('browser')`)**: tests browser context-menu element setup, event routing, and client/registry lifecycle. |
| **Unified Selection (Scrolling & Auto-Scroll)** | [`packages/flutter/test/widgets/scrollable_selection_test.dart`](../../../../packages/flutter/test/widgets/scrollable_selection_test.dart)<br>[`packages/flutter/test/widgets/selectable_region_scroll_test.dart`](../../../../packages/flutter/test/widgets/selectable_region_scroll_test.dart) | Drag-selection inside/across `Scrollable`s, `EdgeDraggingAutoScroller` autoscrolling, and scroll offsets. |
| **Selection Container & Delegation** | [`packages/flutter/test/widgets/selection_container_test.dart`](../../../../packages/flutter/test/widgets/selection_container_test.dart) | `SelectionContainer`, `SelectionContainer.disabled`, delegate tree hierarchies, and spatial sorting (`compareOrder`). |
| **Low-Level Selection Protocol** | [`packages/flutter/test/rendering/selection_test.dart`](../../../../packages/flutter/test/rendering/selection_test.dart) | Low-level `Selectable`, `SelectionHandler`, `SelectionGeometry`, and `SelectionEvent` unit tests. |
| **Editable Text (Core State & Lifecycle)** | [`packages/flutter/test/widgets/editable_text_test.dart`](../../../../packages/flutter/test/widgets/editable_text_test.dart) | `EditableTextState`, focus attachment, controller synchronization, and method channel setup. |
| **Editable Text (Cursor & Caret)** | [`packages/flutter/test/widgets/editable_text_cursor_test.dart`](../../../../packages/flutter/test/widgets/editable_text_cursor_test.dart) | Cursor blinking animations, cursor color, opacity, and iOS floating cursor gestures. |
| **Editable Text (Shortcuts & Selectors)** | [`packages/flutter/test/widgets/editable_text_shortcuts_test.dart`](../../../../packages/flutter/test/widgets/editable_text_shortcuts_test.dart)<br>[`packages/flutter/test/widgets/default_text_editing_shortcuts_test.dart`](../../../../packages/flutter/test/widgets/default_text_editing_shortcuts_test.dart) | Hardware keyboard shortcuts, `DefaultTextEditingShortcuts`, intent mappings, and macOS selector dispatches. |
| **Editable Text (Auto-Scroll & Show-On-Screen)** | [`packages/flutter/test/widgets/editable_text_show_on_screen_test.dart`](../../../../packages/flutter/test/widgets/editable_text_show_on_screen_test.dart) | Automatic viewport scrolling when caret navigates or text expands beyond bounds. |
| **Editable Text (Stylus / Scribble & Scribe)** | [`packages/flutter/test/widgets/editable_text_scribble_test.dart`](../../../../packages/flutter/test/widgets/editable_text_scribble_test.dart)<br>[`packages/flutter/test/widgets/editable_text_scribe_test.dart`](../../../../packages/flutter/test/widgets/editable_text_scribe_test.dart) | Apple Scribble handwriting and Android Stylus Scribe input protocols. |
| **Editable Text (Span & Composing Styles)** | [`packages/flutter/test/widgets/editable_text_styles_test.dart`](../../../../packages/flutter/test/widgets/editable_text_styles_test.dart) | Styled `InlineSpan` trees and IME composing range styling within editable fields. |
| **Text Gestures & Arena Resolution** | [`packages/flutter/test/widgets/text_selection_test.dart`](../../../../packages/flutter/test/widgets/text_selection_test.dart) | `TextSelectionGestureDetector`, `TapAndPanGestureRecognizer`, and tap-and-drag gesture recognizers. |
| **System Context Menu (iOS 16+)** | [`packages/flutter/test/widgets/system_context_menu_test.dart`](../../../../packages/flutter/test/widgets/system_context_menu_test.dart) | `SystemContextMenu`, `SystemContextMenuController`, and Apple native secure paste integration. |
| **Low-Level Editable Rendering** | [`packages/flutter/test/rendering/editable_test.dart`](../../../../packages/flutter/test/rendering/editable_test.dart)<br>[`packages/flutter/test/rendering/editable_gesture_test.dart`](../../../../packages/flutter/test/rendering/editable_gesture_test.dart)<br>[`packages/flutter/test/rendering/editable_intrinsics_test.dart`](../../../../packages/flutter/test/rendering/editable_intrinsics_test.dart) | `RenderEditable` layout, painting, selection boxes, caret geometry, pointer routing, and intrinsic sizing. |
| **Static Text & Paragraph Rendering** | [`packages/flutter/test/widgets/text_test.dart`](../../../../packages/flutter/test/widgets/text_test.dart)<br>[`packages/flutter/test/widgets/rich_text_test.dart`](../../../../packages/flutter/test/widgets/rich_text_test.dart)<br>[`packages/flutter/test/rendering/paragraph_test.dart`](../../../../packages/flutter/test/rendering/paragraph_test.dart) | `Text`, `RichText`, `RenderParagraph`, span hit testing through `RenderParagraph`, `WidgetSpan` layout, and intrinsics. |
| **Text Painter & Typography** | [`packages/flutter/test/painting/text_painter_test.dart`](../../../../packages/flutter/test/painting/text_painter_test.dart) | `TextPainter` layout caching, line metrics calculations, `TextScaler`, and `TextStyle` painting. |
| **Logical Boundaries & Iterators** | [`packages/flutter/test/services/text_boundary_test.dart`](../../../../packages/flutter/test/services/text_boundary_test.dart) | Character, word, line, paragraph, and document text boundaries. |
| **Platform Channels & Deltas** | [`packages/flutter/test/services/text_input_test.dart`](../../../../packages/flutter/test/services/text_input_test.dart)<br>[`packages/flutter/test/services/delta_text_input_test.dart`](../../../../packages/flutter/test/services/delta_text_input_test.dart) | Platform channel codec, `TextInputConnection`, and `TextEditingDelta` diff stream processing. |
| **Material Text (Frozen / Legacy)** | [`packages/flutter/test/material/text_field_test.dart`](../../../../packages/flutter/test/material/text_field_test.dart)<br>[`packages/flutter/test/material/selection_area_test.dart`](../../../../packages/flutter/test/material/selection_area_test.dart)<br>[`packages/flutter/test/material/adaptive_text_selection_toolbar_test.dart`](../../../../packages/flutter/test/material/adaptive_text_selection_toolbar_test.dart) | Legacy tests for frozen Material text components in `flutter/flutter` (active tests belong in `material_ui` under `flutter/packages`). |
| **Cupertino Text (Frozen / Legacy)** | [`packages/flutter/test/cupertino/text_field_test.dart`](../../../../packages/flutter/test/cupertino/text_field_test.dart)<br>[`packages/flutter/test/cupertino/adaptive_text_selection_toolbar_test.dart`](../../../../packages/flutter/test/cupertino/adaptive_text_selection_toolbar_test.dart) | Legacy tests for frozen Cupertino text components in `flutter/flutter` (active tests belong in `cupertino_ui` under `flutter/packages`). |

---

## 2. Multi-Tap Timing & The Consecutive Tap Reset Trap

### Control Elapsed Time Between Taps

Flutter's text gesture recognizers ([`BaseTapAndDragGestureRecognizer`](../../../../packages/flutter/lib/src/gestures/tap_and_drag.dart)) track consecutive taps using `kDoubleTapTimeout` (300ms). A new pointer down can continue the series when the timer is still active, the position is within `kDoubleTapSlop`, and the buttons match. The timeout starts on pointer up; after expiry, the next down begins a new series.

`pumpAndSettle()` advances time by 100ms per pump by default and repeats while frames remain scheduled. It can preserve a tap series when it completes before the timeout, but animations can make it advance too far. Use explicit pumps between taps when the test depends on the consecutive count, and settle after the final tap when appropriate. See [`WidgetTester.pumpAndSettle`](../../../../packages/flutter_test/lib/src/widget_tester.dart).

### Correct Pattern for Double-Tap & Triple-Tap

Use [`TestGesture`](../../../../packages/flutter_test/lib/src/test_pointer.dart) with an explicit short delay or `tester.pump()`. The text tap-and-drag recognizers accept zero-delay consecutive taps; `kDoubleTapMinTime` is a constraint of the general double-tap recognizer, not this text recognizer. These interaction snippets assume a configured editable/selectable widget and a `tapLocation` inside the intended word or paragraph:

```dart
// Double-tap to select word
final TestGesture gesture = await tester.startGesture(tapLocation);
addTearDown(gesture.removePointer);
await tester.pump();
await gesture.up();
await tester.pump(const Duration(milliseconds: 40));

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

When the next interaction should begin a new tap series, advance by the timeout after the preceding pointer up:

```dart
// The next pointer down will start a new tap series.
await tester.pump(kDoubleTapTimeout);
```

---

## 3. Caret Blinking, Frame Settlement & Disposal

### Focused Inputs Can Settle

[`pumpAndSettle`](../../../../packages/flutter_test/lib/src/widget_tester.dart) waits for scheduled frames, not for all timers to disappear. A focused [`EditableText`](../../../../packages/flutter/lib/src/widgets/editable_text.dart) can settle while its cursor continues blinking:

- With `cursorOpacityAnimates == false`, the cursor uses a periodic timer.
- With `cursorOpacityAnimates == true`, `_onCursorTick` schedules the next animation asynchronously specifically to allow `pumpAndSettle` to complete.

```dart
await tester.tap(find.byType(TextField));
await tester.pumpAndSettle();
```

A widget that continuously schedules frames can still cause `pumpAndSettle` to throw after its default ten-minute simulated-time timeout. Investigate the active animation or frame scheduler when this occurs; focus alone does not establish the cause.

### Assert Cursor Phases with Explicit Pumps

When checking cursor opacity or the blink phase, advance by the interval relevant to that assertion instead of settling through an unspecified number of frames. For geometry or golden tests that require a fixed cursor, `EditableText.debugDeterministicCursor` is available; restore its previous value after the test.

### Disposal Cancels Cursor Resources

`EditableTextState.dispose` cancels `_cursorTimer` and disposes the cursor animation controller. The widget test binding normally unmounts the remaining tree before checking pending timers. Ending a successful test with a focused field does not itself leak the cursor timer. Dispose test-owned controllers and focus nodes normally; if a timer remains pending, trace its owner and cleanup path rather than adding an arbitrary post-disposal delay.

---

## 4. Font Geometry, Hit-Testing & The Drag Slop Trap

### The Headless Test Font

The default headless test font is **`FlutterTest`**. The engine also provides `Ahem` and `Cough`; its test font manager falls back to the first family, `FlutterTest`. See [`test_font_data.cc`](../../../../engine/src/flutter/runtime/test_font_data.cc) and [`test_font_manager.cc`](../../../../engine/src/flutter/txt/src/txt/test_font_manager.cc).

For unscaled `FlutterTest` text without line-height or strut overrides:

- Ordinary supported characters generally advance by one em. At `fontSize: 10.0`, that is 10 logical pixels.
- The font ascent is 0.75em and descent is 0.25em: 7.5 and 2.5 logical pixels at size 10.
- Glyph outlines are not all squares, and whitespace includes partial-em and zero-width characters. See the outlines and advance widths in [`gen_test_font.py`](../../../../engine/src/flutter/tools/gen_test_font.py).

Use measured caret positions and selection boxes for mixed styles, Unicode, custom fonts, text scaling, or struts rather than assuming every code unit occupies a square.

### Drag Slop Depends on Pointer Kind and Recognizer

[`computeHitSlop` and `computePanSlop`](../../../../packages/flutter/lib/src/gestures/events.dart) choose thresholds in logical pixels:

| Pointer kind | Hit slop | Pan slop |
| :--- | :--- | :--- |
| Mouse | `kPrecisePointerHitSlop`: 1 | `kPrecisePointerPanSlop`: 2 |
| Other kinds | `gestureSettings.touchSlop` or `kTouchSlop`: 18 | `gestureSettings.panSlop` or `kPanSlop`: 36 |

`TapAndHorizontalDragGestureRecognizer` uses hit slop for its primary-axis acceptance; `TapAndPanGestureRecognizer` uses pan slop. Arena acceptance can also affect the path taken. `SelectableRegion` uses a pan recognizer for mouse and a horizontal recognizer for other pointer kinds. Device settings can change the non-mouse thresholds.

A one-character, 10-pixel mouse drag can therefore select text. Larger fonts or longer drags are convenient when a test needs to cross the active threshold, but are not required for every selection test. Specify `PointerDeviceKind.mouse` when simulating mouse selection; `tester.startGesture` defaults to touch.

### Precise Position Calculation Helper (`textOffsetToPosition`)

These helpers use `package:flutter/rendering.dart` and convert a text offset to global logical coordinates for `tester.tapAt()` or `gesture.moveTo()`. Use the helper matching the render object; the paragraph helper targets the middle of a line with uniform styling:

```dart
Offset textOffsetToPosition(RenderParagraph paragraph, int offset) {
  const Rect caretPrototype = Rect.fromLTWH(0.0, 0.0, 2.0, 20.0);
  final Offset localOffset =
      paragraph.getOffsetForCaret(TextPosition(offset: offset), caretPrototype) +
      Offset(0.0, paragraph.preferredLineHeight / 2);
  return paragraph.localToGlobal(localOffset);
}
```

For [`RenderEditable`](../../../../packages/flutter/lib/src/rendering/editable.dart):

```dart
Offset editableOffsetToPosition(RenderEditable editable, int offset) {
  final Offset localOffset = editable.getLocalRectForCaret(
    TextPosition(offset: offset),
  ).center;
  return editable.localToGlobal(localOffset);
}
```

### The First Accepted Move Can Update Selection

In [`BaseTapAndDragGestureRecognizer`](../../../../packages/flutter/lib/src/gestures/tap_and_drag.dart), `_acceptDrag` calls `onDragStart` and then `onDragUpdate` for the same event when its local delta is nonzero. Text selection recognizers configure `DragStartBehavior.down`, so the initial press remains the drag origin. A single move can both start the drag and extend the selection; see the single-move case in [`tap_and_drag_test.dart`](../../../../packages/flutter/test/gestures/tap_and_drag_test.dart).

For a single, uniformly styled LTR paragraph with mouse selection enabled and no competing gesture, an interaction can be:

```dart
final TestGesture gesture = await tester.startGesture(
  textOffsetToPosition(paragraph, 0),
  kind: PointerDeviceKind.mouse,
);
addTearDown(gesture.removePointer);
await tester.pump();
await gesture.moveTo(textOffsetToPosition(paragraph, 5));
await tester.pump();
expect(paragraph.selections.single, const TextSelection(baseOffset: 0, extentOffset: 5));
await gesture.up();
await tester.pumpAndSettle();
```

Use intermediate moves when the scenario needs them. If an expected update is missing, inspect the event delta, pointer kind, gesture-arena result, drag-start behavior, and any `dragUpdateThrottleFrequency` before assuming a second move is required.

---

## 5. Finding & Interacting with Floating Overlays & Toolbars

### Overlay Hierarchy Isolation

Selection handles, magnifiers, and context menu toolbars are **not child widgets** of `TextField` or `SelectionArea`. They are inserted into the application root [`Overlay`](../../../../packages/flutter/lib/src/widgets/overlay.dart).

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

Selection handles are floating overlay controls attached to the text via [`CompositedTransformFollower`](../../../../packages/flutter/lib/src/widgets/basic.dart). Because handles are dynamically positioned by leader-layer offsets, Flutter tests interact with handles using two canonical approaches:

#### Method A: Geometric Dragging via Selection Endpoints (Standard Practice)

Instead of searching for handle widgets by generic types (which is fragile), calculate the handle's exact coordinates using the render object's selection endpoints:

**1. For `RenderEditable` (`TextField` / `EditableText`)**:

This snippet assumes one editable field with at least ten characters and visible handles for a non-collapsed LTR selection. It uses `editableOffsetToPosition` from section 4; endpoint offsets should target the handle shape provided by the test's selection controls.
```dart
final EditableTextState editableState = tester.state<EditableTextState>(
  find.byType(EditableText),
);
final RenderEditable renderEditable = editableState.renderEditable;
final List<TextSelectionPoint> endpoints = renderEditable.getEndpointsForSelection(
  editableState.widget.controller.selection,
);
expect(endpoints.length, 2);

// Start handle (endpoints[0]) & End handle (endpoints[1])
// Note: An offset (e.g. ±1px) targets the handle body attached to the endpoint
final Offset startHandlePos =
    renderEditable.localToGlobal(endpoints[0].point) + const Offset(-1.0, 1.0);
final Offset endHandlePos =
    renderEditable.localToGlobal(endpoints[1].point) + const Offset(1.0, 1.0);

// Drag the end handle to expand selection
final TestGesture gesture = await tester.startGesture(endHandlePos);
addTearDown(gesture.removePointer);
await tester.pump();
await gesture.moveTo(editableOffsetToPosition(renderEditable, 10));
await tester.pump();
await gesture.up();
await tester.pumpAndSettle();
```

**2. For `RenderParagraph` (`SelectableRegion` / `SelectionArea`)**:

For a single LTR paragraph with visible handles, the following locates the selection-box corners and uses `textOffsetToPosition` from section 4. Mixed-direction text or selections spanning multiple paragraphs need endpoints that reflect their actual selection geometry.
```dart
final RenderParagraph paragraph = tester.renderObject(find.byType(RichText));
final List<TextBox> boxes = paragraph.getBoxesForSelection(paragraph.selections.first);
final Offset startHandlePos = paragraph.localToGlobal(boxes.first.toRect().bottomLeft);
final Offset endHandlePos = paragraph.localToGlobal(boxes.last.toRect().bottomRight);

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

### Mocking a Supported Context Menu Action

Match the widget, platform, and channel to the action under test. The current `SelectableRegion` default menu supports Copy, Select All, Share on Android, and available process-text actions. `Look Up` is an `EditableTextState` action implemented for iOS; an ordinary `SelectionArea` does not provide that default button. `Share.invoke` uses `SystemChannels.platform` with the selected string as its argument. Process-text actions use `SystemChannels.processText` instead.

This complete widget test selects text, taps the Android Share action, and checks the outgoing payload. It uses the existing Material wrapper to build its toolbar; core channel behavior can also be tested with `SelectableRegion` and a test toolbar, as in [`selectable_region_test.dart`](../../../../packages/flutter/test/widgets/selectable_region_test.dart).

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Share sends the selected text to the platform',
    (WidgetTester tester) async {
      String? sharedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Share.invoke') {
            sharedText = call.arguments as String;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SelectionArea(child: Text('Hello')),
          ),
        ),
      );
      final SelectableRegionState region = tester.state<SelectableRegionState>(
        find.byType(SelectableRegion),
      );
      region.selectAll(SelectionChangedCause.toolbar);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(sharedText, 'Hello');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
    skip: kIsWeb, // Share is not offered by the web selection menu.
  );
}
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

### Current Inside-Edge and Outside-Edge Behavior

`_ScrollableSelectionContainerDelegate` creates a zero-size drag target at the selection event's global position. `EdgeDraggingAutoScroller` compares that target with the viewport: a target strictly inside the viewport does not start scrolling; a target beyond an edge can scroll when there is remaining extent and the resolved physics accepts user scrolling. There is no inner-edge activation band. See [`scrollable.dart`](../../../../packages/flutter/lib/src/widgets/scrollable.dart) and [`scrollable_helpers.dart`](../../../../packages/flutter/lib/src/widgets/scrollable_helpers.dart).

For a fresh, direct mouse selection that starts inside an untransformed, vertically scrolling `ListView`, with positive content extent and ordinary scroll physics, check both conditions. The snippet assumes that `gesture` is down and `controller` is the list's attached scroll controller, with no auto-scroll already in flight:

```dart
final double offsetBeforeInsideDrag = controller.offset;
final Offset insideBottom =
    tester.getBottomLeft(find.byType(ListView)) + const Offset(10, -5);
await gesture.moveTo(insideBottom);
await tester.pump();
await tester.pump(const Duration(milliseconds: 100));
expect(controller.offset, offsetBeforeInsideDrag);

final Offset outsideBottom =
    tester.getBottomLeft(find.byType(ListView)) + const Offset(10, 40);
await gesture.moveTo(outsideBottom);
await tester.pump();
await tester.pump(const Duration(milliseconds: 100));
expect(controller.offset, greaterThan(offsetBeforeInsideDrag));
```

The selection must start in the scrollable for this delegate to auto-scroll. When a nested child returns `SelectionResult.pending`, the parent stops its own auto-scroller and waits for the child. At a scroll limit, or with physics that rejects user offsets, an outside target does not produce further scrolling.

### Axis Direction and Drag Modality

For changes to shared scrolling geometry, exercise the relevant vertical and horizontal paths, including reversed axis directions. With `AxisDirection.down`, the bottom edge increases the scroll offset; with `AxisDirection.right`, the right edge increases it. `AxisDirection.up` and `AxisDirection.left` reverse these relationships.

Direct mouse drags and selection-handle drags do not necessarily dispatch the same coordinates. A handle drag tracks the handle's paint origin and subtracts half the selection line height vertically before dispatching the edge event. Inspect that event position when deciding whether it is inside or outside the viewport. Dragging a handle 5 pixels inside the bottom edge does not imply auto-scroll activation; an outside pointer may also need to move farther to place the adjusted event beyond the edge. Existing handle tests move beyond the viewport in [`scrollable_selection_test.dart`](../../../../packages/flutter/test/widgets/scrollable_selection_test.dart).

### Gesture Release and Eventual Scroll Stability

Gesture release stops the region's continuous edge-update scheduling. An already scheduled auto-scroll step can still complete: `EdgeDraggingAutoScroller` uses discrete linear `animateTo` steps, and `stopAutoScroll` clears its loop flag without cancelling the current scroll activity. Tests should allow this completion and verify eventual stability; the implementation does not promise zero movement immediately after release.

```dart
await gesture.up();
await tester.pumpAndSettle(); // Allow already scheduled scrolling to finish.
final double settledOffset = controller.offset;

await tester.pump(const Duration(seconds: 1));
expect(controller.offset, settledOffset);
```

A baseline taken after settlement checks for resumed or continuing scrolling. It does not establish that the offset stayed fixed from the instant of release. If diagnosing the size or timing of movement after release, record the offset at release and during the following frames separately.
