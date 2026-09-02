---
name: flutter-text-domain-expert
description: >
  Deep architectural domain expertise, troubleshooting guides, testing best practices, and subsystem routing for the Flutter text stack (painting, rendering, services, widgets, selection, editing, and IME) in the flutter/flutter repository.

  When to use:
  - When working on, debugging, or adding tests for Flutter text rendering (Text, RichText, RenderParagraph, TextPainter, InlineSpan, WidgetSpan).
  - When working on editable text and IME platform channels (TextField, CupertinoTextField, EditableText, RenderEditable, TextInput, TextInputClient, DeltaTextInputClient, DefaultTextEditingShortcuts).
  - When working on text selection subsystems (SelectionArea, SelectableRegion, SelectionContainer, SelectionOverlay, TextSelectionToolbar, magnifiers, selection handles).
  - When working on text selection context menus, adaptive toolbars, SelectionArea/SelectableRegion buttons, or text platform channels.
  - When debugging text selection scrolling, edge-scrolling, auto-scrolling, or select-to-scroll behavior in Scrollable, ListView, or CustomScrollView (_ScrollableSelectionContainerDelegate, EdgeDraggingAutoScroller).
  - When writing or fixing unit, widget, or rendering tests for text features in packages/flutter/test/.

  When not to use:
  - For general non-text issues (e.g. routing, physics simulations, non-text animations, build tooling, engine build configs).
---

# Flutter Text Domain Expert Skill (`flutter/flutter`)

This skill provides authoritative architectural guidance, subsystem reference mappings, testing invariants, and development workflows for contributing to the text subsystem in the `flutter/flutter` repository.

---

## 1. Subsystem Reference Navigation

The text stack is organized into modular reference guides located under [`references/`](references/):

| Subsystem Area | Reference Document | Key Topics & Components Covered |
| :--- | :--- | :--- |
| **Common Foundation & Primitives** | [`common_text_primitives.md`](references/common_text_primitives.md) | • `dart:ui` Engine primitives (`ParagraphBuilder`, `Paragraph`, `LineMetrics`, `TextBox`)<br>• `TextPainter` layout caching (`_TextPainterLayoutCacheWithOffset`)<br>• `InlineSpan` hierarchy (`TextSpan`, `WidgetSpan`, visitor pattern)<br>• Text geometry, BiDi, and `TextAffinity`<br>• `TextBoundary` iterators (character, word, line, paragraph)<br>• Shared gesture recognizers (`TapAndPanGestureRecognizer`, `BaseTapAndDragGestureRecognizer`)<br>• Shared selection overlays, toolbars, handles, and magnifiers |
| **Static Text & Unified Selection** | [`static_text_pipeline.md`](references/static_text_pipeline.md) | • `Text`, `RichText`, `_RichText`<br>• `RenderParagraph` layout, intrinsics, inline child layout (`WidgetSpan`), and span hit-testing<br>• `SelectionArea` & `SelectableRegion`<br>• `SelectionContainer` & delegates (`StaticSelectionContainerDelegate`, `_SelectableTextContainerDelegate`)<br>• `Scrollable` integration & `_ScrollableSelectionContainerDelegate` (`_selectionStartsInScrollable`, autoscrolling)<br>• `_SelectableFragment` & leaf `Selectable`s<br>• 7 concrete `SelectionEvent` subclasses & `compareOrder` reading order sorting |
| **Editable Text & Platform IME** | [`editable_text_pipeline.md`](references/editable_text_pipeline.md) | • `TextField`, `CupertinoTextField`, `EditableText`, `EditableTextState`<br>• `RenderEditable`, `_CaretPainter` (blinking/floating cursor), `ViewportOffset`<br>• `TextInputClient` (standard) vs. `DeltaTextInputClient` (`TextEditingDelta` stream)<br>• Platform channel: `MethodChannel('flutter/textinput')`<br>• `TextInputFormatter`, `SpellCheckService`, `LiveText`, `ProcessTextService`<br>• `DefaultTextEditingShortcuts`, `Actions`, `TextEditingIntents`, macOS selectors<br>• `TextSelectionOverlay` (isolated from `SelectionArea`) |
| **Testing, Traps & Simulation** | [`testing_text_stack.md`](references/testing_text_stack.md) | • **Test Location Guide**: directory map across `packages/flutter/test/`<br>• Multi-tap timing & `pumpAndSettle()` tap reset trap (`kDoubleTapTimeout`)<br>• Caret blinking timer hang & timeout trap<br>• Ahem font geometry & drag slop trap (`kTouchSlop` / `kPanSlop`)<br>• Multi-move event requirements (`onDragStart` vs `onDragUpdate`)<br>• Floating overlay, toolbar & handle testing patterns (geometric dragging vs. `FadeTransition`)<br>• Realistic IME simulation with `TestTextInput` (composing ranges & actions)<br>• BiDi & `TextAffinity` assertions |
| **Debugging Playbooks** | [`text_debugging_playbooks.md`](references/text_debugging_playbooks.md) | Diagnostic trees and triage runbooks for common text bug patterns *(iterative reference)*. |

---

## 2. Core Architectural Invariants to Uphold

When reading, modifying, or reviewing text subsystem code in `flutter/flutter`, always maintain these structural rules:

1. **Repository Scope & Frozen Design Systems**:
   - In the `flutter/flutter` repository, active text development takes place in `packages/flutter` across `widgets/`, `rendering/`, `services/`, and `painting/`.
   - The legacy `packages/flutter/lib/src/material/` and `packages/flutter/lib/src/cupertino/` implementations are **frozen**.
   - Active development of Material and Cupertino text UI components (`TextField`, `CupertinoTextField`, `AdaptiveTextSelectionToolbar`, `SelectionArea`, selection handles) belongs in the **`material_ui`** and **`cupertino_ui`** packages under the **`flutter/packages`** repository.

2. **Subsystem Isolation**:
   - `RenderEditable` does **not** participate in the `SelectionArea` / `SelectableRegion` selection tree. It maintains its own selection and overlay state machine via `TextSelectionOverlay`.
   - `SelectableRegion` coordinates unified selection across read-only leaf registrants (`_SelectableFragment` in `RenderParagraph`, custom selectables) via the `SelectionRegistrarScope`.

3. **Layer Boundary Rules in `packages/flutter`**:
   - **`widgets/`**, **`rendering/`**, and **`services/`** must **never** import `package:flutter/material.dart` or `package:flutter/cupertino.dart`.
   - Legacy `material/` and `cupertino/` tests in `packages/flutter/test/` only verify frozen components.

4. **IME Composing Range Preservation**:
   - Never mutate `TextEditingValue.text` without recalculating or explicitly resetting `TextEditingValue.composing` (`TextRange`). Clobbering active composing ranges breaks multilingual IMEs (Japanese, Chinese, Korean, Vietnamese).

5. **BiDi & TextAffinity Disambiguation**:
   - At soft line wrap points and RTL/LTR junctions, a single glyph offset corresponds to two visually distinct caret positions. Always specify or account for `TextAffinity.upstream` vs `TextAffinity.downstream`.

6. **Geometry Resolution vs. Lifecycle Coupling**:
   - Resolve continuous coordinate and gesture-geometry calculations directly at the geometry layer (e.g. coordinate transformations, directional projection, inner proximity thresholds).
   - Never introduce cross-widget state or lifecycle listeners (e.g. subscribing to selection status notifiers) to forcibly cancel animations or reset state upon gesture release as a workaround for inaccurate or inflated spatial calculations.

---

## 3. General Contribution & Triage Workflow

Follow this step-by-step workflow when addressing an issue or PR in the Flutter text stack:

```mermaid
flowchart TD
    A["User Request / Issue Report"] --> B{"Identify Domain"}
    B -->|"Static Text / Paragraph"| C["Read static_text_pipeline.md"]
    B -->|"Editable Text / IME"| D["Read editable_text_pipeline.md"]
    B -->|"Common Spans / Boundaries / Gestures"| E["Read common_text_primitives.md"]
    B -->|"Writing or Fixing Tests"| F["Read testing_text_stack.md"]
    
    C --> G["Locate Target Source & Test File<br/>(consult Test Location Guide in testing_text_stack.md)"]
    D --> G
    E --> G
    F --> G

    G --> H["Implement Changes & Reproduce Bug in Test"]
    H --> I["Verify Invariants:<br/>• No pumpAndSettle() between taps or on focused inputs<br/>• Respect Drag Slop & issue multiple moves<br/>• Use TestTextInput for IME composing tests"]
    I --> J["Run Static Analysis & Formatting:<br/>• dart analyze --fatal-infos &lt;files&gt;<br/>• dart format &lt;files&gt;"]
    J --> K["Run Target Tests:<br/>• ./bin/flutter test &lt;test_file&gt;"]
```

> [!IMPORTANT]
> **Framework Test Runner**: Always execute framework unit and widget tests using the repository's local Flutter tool (`./bin/flutter test <test_file>`). Do not use `dart test`, which lacks Flutter engine, binary messenger, and font bindings.

### Pre-Completion Checklist
Before declaring any Flutter text task complete:
- [ ] Address all lints, warnings, and errors (`dart analyze --fatal-infos <modified_files>`).
- [ ] Format all modified Dart files (`dart format <modified_files>`).
- [ ] Verify that tests avoid `pumpAndSettle()` hangs on focused `EditableText` widgets.
- [ ] Verify that gesture tests avoid `pumpAndSettle()` between multi-taps.
- [ ] Verify that drag-selection tests account for `kTouchSlop` / `kPanSlop` (large font or multiple move events).
- [ ] Verify that all layer boundary rules are respected.
- [ ] Execute target tests with `./bin/flutter test <test_file>`.
