// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Widgets-layer tests for screen-reader selection in [SelectableRegion]
// (flutter/flutter#182909). No material import: the Material forms of these
// cases live in test/material/selection_area_semantics_test.dart.

import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'clipboard_utils.dart';
import 'editable_text_tester.dart';
import 'keyboard_utils.dart';

Widget _region({
  required Widget child,
  FocusNode? focusNode,
  ValueChanged<SelectedContent?>? onSelectionChanged,
}) {
  return TestWidgetsApp(
    home: SelectableRegion(
      focusNode: focusNode,
      selectionControls: emptyTextSelectionControls,
      onSelectionChanged: onSelectionChanged,
      child: child,
    ),
  );
}

/// The [Selectable] fragment of the paragraph rendered by the `index`-th
/// [RichText] in the tree.
Selectable _fragmentAt(WidgetTester tester, int index) {
  final BuildContext context = tester.element(find.byType(RichText).at(index));
  final delegate =
      SelectionContainer.maybeOf(context)! as MultiSelectableSelectionContainerDelegate;
  return delegate.selectables.first;
}

RenderParagraph _paragraphAt(WidgetTester tester, int index) {
  return tester.renderObject<RenderParagraph>(find.byType(RichText).at(index));
}

SelectionSemanticsDelegate _delegateOf(WidgetTester tester) {
  final BuildContext context = tester.element(find.byType(RichText).first);
  return context
      .getInheritedWidgetOfExactType<SelectableRegionSelectionStatusScope>()!
      .selectionSemanticsDelegate;
}

SelectableRegionState _regionState(WidgetTester tester) {
  return tester.state<SelectableRegionState>(find.byType(SelectableRegion));
}

Offset _textOffsetToPosition(RenderParagraph paragraph, int offset) {
  const caret = Rect.fromLTWH(0.0, 0.0, 2.0, 20.0);
  final Offset localOffset =
      paragraph.getOffsetForCaret(TextPosition(offset: offset), caret) +
      Offset(0.0, paragraph.preferredLineHeight / 2);
  return paragraph.localToGlobal(localOffset);
}

List<SemanticsNode> _childrenOf(SemanticsNode node) {
  final children = <SemanticsNode>[];
  node.visitChildren((SemanticsNode child) {
    children.add(child);
    return true;
  });
  return children;
}

List<SemanticsNode> _allNodes(WidgetTester tester) {
  final nodes = <SemanticsNode>[];
  void visit(SemanticsNode node) {
    nodes.add(node);
    node.visitChildren((SemanticsNode child) {
      visit(child);
      return true;
    });
  }

  visit(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
  return nodes;
}

SemanticsNode _nodeWithLabel(WidgetTester tester, String label) {
  return _allNodes(tester).singleWhere((SemanticsNode node) => node.label == label);
}

Future<void> _mouseDrag(WidgetTester tester, Offset from, Offset to, {int frames = 10}) async {
  final TestGesture gesture = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
  addTearDown(gesture.removePointer);
  await tester.pump();
  for (var i = 1; i <= frames; i += 1) {
    await gesture.moveTo(Offset.lerp(from, to, i / frames)!);
    await tester.pump();
  }
  await gesture.up();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final mockClipboard = MockClipboard();

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      mockClipboard.handleMethodCall,
    );
    await Clipboard.setData(const ClipboardData(text: 'empty'));
  });

  group('selection by accessibility', () {
    testWidgets('selects the range in the target paragraph and clears the others', (
      WidgetTester tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      final changes = <String?>[];
      await tester.pumpWidget(
        _region(
          focusNode: focusNode,
          onSelectionChanged: (SelectedContent? content) => changes.add(content?.plainText),
          child: const Column(children: <Widget>[Text('Hello world'), Text('Second line')]),
        ),
      );
      await tester.pump();
      var finalizedCount = 0;
      final ValueListenable<SelectableRegionSelectionStatus> status =
          SelectableRegionSelectionStatusScope.maybeOf(
            tester.element(find.byType(RichText).first),
          )!;
      status.addListener(() {
        if (status.value == SelectableRegionSelectionStatus.finalized) {
          finalizedCount += 1;
        }
      });
      expect(focusNode.hasFocus, isFalse);

      _delegateOf(tester).select(_fragmentAt(tester, 0), 0, 5);
      await tester.pump();
      expect(_paragraphAt(tester, 0).selections, const <TextSelection>[
        TextSelection(baseOffset: 0, extentOffset: 5),
      ]);
      expect(_paragraphAt(tester, 1).selections, isEmpty);
      expect(focusNode.hasFocus, isTrue);
      expect(changes, <String?>['Hello']);
      expect(finalizedCount, 1);

      _delegateOf(tester).select(_fragmentAt(tester, 1), 7, 11);
      await tester.pump();
      expect(_paragraphAt(tester, 0).selections, isEmpty);
      expect(_paragraphAt(tester, 1).selections, const <TextSelection>[
        TextSelection(baseOffset: 7, extentOffset: 11),
      ]);
      expect(changes, <String?>['Hello', null, 'line']);
      expect(finalizedCount, 2);
      expect(_regionState(tester).selectionOverlay, isNull);
    });

    testWidgets('keeps the direction of a reversed range and clamps offsets', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_region(child: const Text('Hello world')));
      await tester.pump();

      _delegateOf(tester).select(_fragmentAt(tester, 0), 5, 0);
      await tester.pump();
      expect(_paragraphAt(tester, 0).selections, const <TextSelection>[
        TextSelection(baseOffset: 5, extentOffset: 0),
      ]);

      _delegateOf(tester).select(_fragmentAt(tester, 0), -4, 100);
      await tester.pump();
      expect(_paragraphAt(tester, 0).selections, const <TextSelection>[
        TextSelection(baseOffset: 0, extentOffset: 11),
      ]);
    });

    testWidgets('a following Shift+Right extends the selection', (WidgetTester tester) async {
      await tester.pumpWidget(
        _region(child: const Column(children: <Widget>[Text('Hello world'), Text('Second')])),
      );
      await tester.pump();

      _delegateOf(tester).select(_fragmentAt(tester, 0), 0, 3);
      await tester.pump();
      await sendKeyCombination(
        tester,
        const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true),
      );
      await tester.pump();
      expect(_paragraphAt(tester, 0).selections, const <TextSelection>[
        TextSelection(baseOffset: 0, extentOffset: 4),
      ]);

      // Extend across the paragraph boundary.
      _delegateOf(tester).select(_fragmentAt(tester, 0), 9, 11);
      await tester.pump();
      await sendKeyCombination(
        tester,
        const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true),
      );
      await tester.pump();
      expect(_paragraphAt(tester, 0).selections, const <TextSelection>[
        TextSelection(baseOffset: 9, extentOffset: 11),
      ]);
      expect(_paragraphAt(tester, 1).selections, const <TextSelection>[
        TextSelection(baseOffset: 0, extentOffset: 1),
      ]);
    }, variant: TargetPlatformVariant.all());

    testWidgets('a collapsed range has no side effect', (WidgetTester tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      final fieldFocusNode = FocusNode();
      addTearDown(fieldFocusNode.dispose);
      final controller = TextEditingController(text: 'field');
      addTearDown(controller.dispose);
      var statusChanges = 0;
      await tester.pumpWidget(
        TestWidgetsApp(
          home: Column(
            children: <Widget>[
              EditableText(
                controller: controller,
                focusNode: fieldFocusNode,
                style: const TextStyle(),
                cursorColor: const Color(0xFF000000),
                backgroundCursorColor: const Color(0xFF000000),
              ),
              SelectableRegion(
                focusNode: focusNode,
                selectionControls: emptyTextSelectionControls,
                child: const Text('Hello world'),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      SelectableRegionSelectionStatusScope.maybeOf(tester.element(find.byType(RichText).first))!
          .addListener(() => statusChanges += 1);
      fieldFocusNode.requestFocus();
      await tester.pump();
      expect(fieldFocusNode.hasPrimaryFocus, isTrue);

      _delegateOf(tester).select(_fragmentAt(tester, 0), 3, 3);
      await tester.pump();
      expect(fieldFocusNode.hasPrimaryFocus, isTrue);
      expect(focusNode.hasFocus, isFalse);
      expect(_paragraphAt(tester, 0).selections, isEmpty);
      expect(statusChanges, 0);

      // An existing selection is not cleared either.
      _delegateOf(tester).select(_fragmentAt(tester, 0), 0, 2);
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);
      _delegateOf(tester).select(_fragmentAt(tester, 0), 3, 3);
      await tester.pump();
      expect(_paragraphAt(tester, 0).selections, const <TextSelection>[
        TextSelection(baseOffset: 0, extentOffset: 2),
      ]);
    });

    testWidgets('copy copies the selection and keeps it', (WidgetTester tester) async {
      await tester.pumpWidget(_region(child: const Text('Hello world')));
      await tester.pump();

      _delegateOf(tester).select(_fragmentAt(tester, 0), 6, 11);
      await tester.pump();
      _delegateOf(tester).copy();
      await tester.pump();
      final clipboardData = mockClipboard.clipboardData as Map<String, dynamic>;
      expect(clipboardData['text'], 'world');
      expect(_paragraphAt(tester, 0).selections, const <TextSelection>[
        TextSelection(baseOffset: 6, extentOffset: 11),
      ]);
    });

    testWidgets('selects in a paragraph of a scrolled list without scrolling', (
      WidgetTester tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _region(
          child: ListView(
            controller: controller,
            itemExtent: 50.0,
            children: <Widget>[for (int i = 0; i < 40; i += 1) Text('Item $i')],
          ),
        ),
      );
      await tester.pump();
      controller.jumpTo(600.0);
      await tester.pump();
      final Finder item14 = find.text('Item 14');
      expect(item14, findsOneWidget);
      final Element richText = find
          .descendant(of: item14, matching: find.byType(RichText))
          .evaluate()
          .single;
      final delegate =
          SelectionContainer.maybeOf(richText)! as MultiSelectableSelectionContainerDelegate;
      final Selectable fragment = delegate.selectables.single;
      final paragraph = richText.findRenderObject()! as RenderParagraph;

      _delegateOf(tester).select(fragment, 0, 4);
      await tester.pump();
      expect(paragraph.selections, const <TextSelection>[
        TextSelection(baseOffset: 0, extentOffset: 4),
      ]);
      expect(controller.offset, 600.0);
      await sendKeyCombination(
        tester,
        const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true),
      );
      await tester.pump();
      expect(paragraph.selections, const <TextSelection>[
        TextSelection(baseOffset: 0, extentOffset: 5),
      ]);
      expect(controller.offset, 600.0);
    });
  });

  group('node layer', () {
    testWidgets('a selectable paragraph publishes its selection in label offsets', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_region(child: const Text('Hello world')));
      await tester.pump();

      final SemanticsNode paragraph = tester.getSemantics(find.byType(RichText));
      expect(paragraph.getSemanticsData().hasAction(SemanticsAction.setSelection), isTrue);
      expect(paragraph.getSemanticsData().hasAction(SemanticsAction.copy), isFalse);
      expect(paragraph.getSemanticsData().textSelection, isNull);

      tester.semantics.setSelection(find.semantics.byLabel('Hello world'), base: 0, extent: 5);
      await tester.pump();
      expect(
        paragraph.getSemanticsData().textSelection,
        const TextSelection(baseOffset: 0, extentOffset: 5),
      );
      expect(paragraph.getSemanticsData().hasAction(SemanticsAction.copy), isTrue);
      expect(_regionState(tester).selectionOverlay, isNull);

      // A following keystroke grows it.
      await sendKeyCombination(
        tester,
        const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true),
      );
      await tester.pump();
      expect(
        paragraph.getSemanticsData().textSelection,
        const TextSelection(baseOffset: 0, extentOffset: 6),
      );

      // The copy action copies the selection and keeps it.
      tester.semantics.copy(find.semantics.byLabel('Hello world'));
      await tester.pump();
      expect((mockClipboard.clipboardData as Map<String, dynamic>)['text'], 'Hello ');
      expect(
        paragraph.getSemanticsData().textSelection,
        const TextSelection(baseOffset: 0, extentOffset: 6),
      );
    });

    testWidgets('publishes one update per keystroke and keeps direction', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_region(child: const Text('Hello world')));
      await tester.pump();
      final SemanticsNode paragraph = tester.getSemantics(find.byType(RichText));
      tester.semantics.setSelection(find.semantics.byLabel('Hello world'), base: 0, extent: 1);
      await tester.pump();

      var updates = 0;
      final SemanticsOwner owner = tester.binding.pipelineOwner.semanticsOwner!;
      void count() => updates += 1;
      owner.addListener(count);
      addTearDown(() => owner.removeListener(count));
      for (var i = 2; i <= 4; i += 1) {
        await sendKeyCombination(
          tester,
          const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true),
        );
        await tester.pump();
        expect(
          paragraph.getSemanticsData().textSelection,
          TextSelection(baseOffset: 0, extentOffset: i),
        );
        expect(updates, i - 1);
      }

      // Backward selections keep base > extent.
      tester.semantics.setSelection(find.semantics.byLabel('Hello world'), base: 8, extent: 3);
      await tester.pump();
      expect(
        paragraph.getSemanticsData().textSelection,
        const TextSelection(baseOffset: 8, extentOffset: 3),
      );
    });

    testWidgets('a mouse drag publishes nothing until pointer up, then once', (
      WidgetTester tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        _region(
          focusNode: focusNode,
          child: const Text('Hello world', style: TextStyle(fontSize: 20)),
        ),
      );
      await tester.pump();
      final SemanticsNode node = tester.getSemantics(find.byType(RichText));
      final RenderParagraph paragraph = _paragraphAt(tester, 0);
      var updates = 0;
      final SemanticsOwner owner = tester.binding.pipelineOwner.semanticsOwner!;
      void count() => updates += 1;
      owner.addListener(count);
      addTearDown(() => owner.removeListener(count));

      final Offset from = _textOffsetToPosition(paragraph, 1);
      final Offset to = _textOffsetToPosition(paragraph, 8);
      // Give the region focus first: the focus representation is its own update.
      focusNode.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(node.flagsCollection.isFocused, Tristate.isTrue);
      updates = 0;
      final TestGesture gesture = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await tester.pump();
      for (var i = 1; i <= 10; i += 1) {
        await gesture.moveTo(Offset.lerp(from, to, i / 10)!);
        await tester.pump();
        expect(node.getSemanticsData().textSelection, isNull);
      }
      expect(paragraph.selections, isNotEmpty);
      expect(updates, 0);
      await gesture.up();
      await tester.pump();
      expect(
        node.getSemanticsData().textSelection,
        const TextSelection(baseOffset: 1, extentOffset: 8),
      );
      expect(updates, 1);
    });

    testWidgets('a paragraph with recognizer spans publishes per pure child', (
      WidgetTester tester,
    ) async {
      final recognizer = TapGestureRecognizer()..onTap = () {};
      addTearDown(recognizer.dispose);
      await tester.pumpWidget(
        _region(
          child: Text.rich(
            TextSpan(
              text: 'Tap ',
              style: const TextStyle(fontSize: 20),
              children: <InlineSpan>[
                TextSpan(text: 'here', recognizer: recognizer),
                const TextSpan(text: ' to continue.'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      final RenderParagraph paragraph = _paragraphAt(tester, 0);
      final SemanticsNode boundary = tester.getSemantics(find.byType(RichText));
      List<SemanticsNode> children() => _childrenOf(boundary);
      expect(children().map((SemanticsNode n) => n.label), <String>[
        'Tap ',
        'here',
        ' to continue.',
      ]);
      expect(children()[0].getSemanticsData().hasAction(SemanticsAction.setSelection), isTrue);
      expect(children()[1].getSemanticsData().hasAction(SemanticsAction.setSelection), isFalse);
      expect(children()[1].getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(children()[2].getSemanticsData().hasAction(SemanticsAction.setSelection), isTrue);

      await _mouseDrag(
        tester,
        _textOffsetToPosition(paragraph, 2),
        _textOffsetToPosition(paragraph, 10),
      );
      expect(paragraph.selections, const <TextSelection>[
        TextSelection(baseOffset: 2, extentOffset: 10),
      ]);
      expect(
        children()[0].getSemanticsData().textSelection,
        const TextSelection(baseOffset: 2, extentOffset: 4),
      );
      expect(children()[1].getSemanticsData().textSelection, isNull);
      expect(
        children()[2].getSemanticsData().textSelection,
        const TextSelection(baseOffset: 0, extentOffset: 2),
      );

      // A reversed drag keeps the direction in every child.
      await _mouseDrag(
        tester,
        _textOffsetToPosition(paragraph, 10),
        _textOffsetToPosition(paragraph, 2),
      );
      expect(paragraph.selections, const <TextSelection>[
        TextSelection(baseOffset: 10, extentOffset: 2),
      ]);
      expect(
        children()[0].getSemanticsData().textSelection,
        const TextSelection(baseOffset: 4, extentOffset: 2),
      );
      expect(
        children()[2].getSemanticsData().textSelection,
        const TextSelection(baseOffset: 2, extentOffset: 0),
      );

      // Setting a selection on a child maps to paragraph offsets.
      tester.semantics.setSelection(find.semantics.byLabel(' to continue.'), base: 0, extent: 1);
      await tester.pump();
      expect(paragraph.selections, const <TextSelection>[
        TextSelection(baseOffset: 8, extentOffset: 9),
      ]);
      expect(
        children()[2].getSemanticsData().textSelection,
        const TextSelection(baseOffset: 0, extentOffset: 1),
      );
      expect(children()[0].getSemanticsData().textSelection, isNull);
    });

    testWidgets('placeholder and semanticsLabel paragraphs publish nothing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _region(
          child: const Column(
            children: <Widget>[
              Text.rich(
                TextSpan(
                  text: 'Price: ',
                  children: <InlineSpan>[
                    WidgetSpan(child: SizedBox(width: 10, height: 10)),
                    TextSpan(text: '42'),
                  ],
                ),
              ),
              Text.rich(TextSpan(text: 'smile', semanticsLabel: 'smiling face')),
            ],
          ),
        ),
      );
      await tester.pump();
      _delegateOf(tester).select(_fragmentAt(tester, 0), 0, 6);
      await tester.pump();
      expect(_paragraphAt(tester, 0).selections, isNotEmpty);
      final SemanticsNode priceNode = tester.getSemantics(find.byType(RichText).first);
      expect(priceNode.getSemanticsData().hasAction(SemanticsAction.setSelection), isFalse);
      expect(priceNode.getSemanticsData().textSelection, isNull);

      _delegateOf(tester).select(_fragmentAt(tester, 1), 0, 2);
      await tester.pump();
      final SemanticsNode smileNode = tester.getSemantics(find.byType(RichText).last);
      expect(smileNode.label, 'smiling face');
      expect(smileNode.getSemanticsData().hasAction(SemanticsAction.setSelection), isFalse);
      expect(smileNode.getSemanticsData().textSelection, isNull);
    });

    testWidgets('a paragraph outside a region publishes nothing', (WidgetTester tester) async {
      await tester.pumpWidget(const TestWidgetsApp(home: Text('Hello world')));
      final SemanticsNode node = tester.getSemantics(find.byType(RichText));
      expect(node.getSemanticsData().hasAction(SemanticsAction.setSelection), isFalse);
    });

    testWidgets('a text change drops the published selection', (WidgetTester tester) async {
      await tester.pumpWidget(_region(child: const Text('Hello world')));
      await tester.pump();
      tester.semantics.setSelection(find.semantics.byLabel('Hello world'), base: 0, extent: 5);
      await tester.pump();
      expect(
        tester.getSemantics(find.byType(RichText)).getSemanticsData().textSelection,
        isNotNull,
      );

      await tester.pumpWidget(_region(child: const Text('Hi')));
      await tester.pump();
      // The stale [0, 5) is gone; whatever selection the new text inherits
      // from the region's selection geometry is published instead.
      final List<TextSelection> inherited = _paragraphAt(tester, 0).selections;
      expect(
        tester.getSemantics(find.byType(RichText)).getSemanticsData().textSelection,
        inherited.isEmpty ? isNull : inherited.single,
      );
      expect(tester.getSemantics(find.byType(RichText)).label, 'Hi');

      await tester.pumpWidget(_region(child: const Text('Hello world')));
      await tester.pump();
      tester.semantics.setSelection(find.semantics.byLabel('Hello world'), base: 0, extent: 5);
      await tester.pump();
      expect(
        tester.getSemantics(find.byType(RichText)).getSemanticsData().textSelection,
        isNotNull,
      );
      // An equal-length replacement drops the stale range the same way.
      _regionState(tester).clearSelection();
      await tester.pumpWidget(_region(child: const Text('Hello there')));
      await tester.pump();
      expect(_paragraphAt(tester, 0).selections, isEmpty);
      expect(tester.getSemantics(find.byType(RichText)).getSemanticsData().textSelection, isNull);
    });

    testWidgets('a clear outside a status bracket publishes from a microtask', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_region(child: const Text('Hello world')));
      await tester.pump();
      tester.semantics.setSelection(find.semantics.byLabel('Hello world'), base: 0, extent: 5);
      await tester.pump();
      final SemanticsNode node = tester.getSemantics(find.byType(RichText));
      expect(node.getSemanticsData().textSelection, isNotNull);

      _regionState(tester).clearSelection();
      await tester.pump();
      expect(node.getSemanticsData().textSelection, isNull);
      expect(node.getSemanticsData().hasAction(SemanticsAction.copy), isFalse);
      expect(node.getSemanticsData().hasAction(SemanticsAction.setSelection), isTrue);
    });
  });

  group('merge rules under a region', () {
    testWidgets(
      'buttons, labeled ancestors, merged paragraphs and gesture detectors keep their shape',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _region(
            child: Column(
              children: <Widget>[
                Semantics(button: true, onTap: () {}, child: const Text('OK')),
                Semantics(button: true, enabled: false, child: const Text('Disabled')),
                Semantics(label: 'Price', child: const Text(r'$5')),
                const MergeSemantics(child: Column(children: <Widget>[Text('a'), Text('b')])),
                GestureDetector(onTap: () {}, child: const Text('tap me')),
                Semantics(
                  label: 'cell one',
                  child: Column(
                    children: <Widget>[
                      const Text('x'),
                      GestureDetector(onTap: () {}, child: const SizedBox(width: 10, height: 10)),
                    ],
                  ),
                ),
                Semantics(
                  label: 'cell two',
                  child: Column(
                    children: <Widget>[
                      GestureDetector(onTap: () {}, child: const SizedBox(width: 10, height: 10)),
                      const Text('y'),
                    ],
                  ),
                ),
                const Text('plain'),
              ],
            ),
          ),
        );
        await tester.pump();
        // Select everything so that every paragraph has a selection to publish.
        _regionState(tester).selectAll();
        await tester.pump();

        final SemanticsNode ok = _nodeWithLabel(tester, 'OK');
        expect(ok.flagsCollection.isButton, isTrue);
        expect(ok.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        final SemanticsNode disabled = _nodeWithLabel(tester, 'Disabled');
        expect(disabled.flagsCollection.isButton, isTrue);
        final SemanticsNode price = _nodeWithLabel(tester, 'Price\n\$5');
        final SemanticsNode merged = _nodeWithLabel(tester, 'a\nb');
        final SemanticsNode tapMe = _nodeWithLabel(tester, 'tap me');
        expect(tapMe.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        final SemanticsNode cellOne = _nodeWithLabel(tester, 'cell one\nx');
        expect(cellOne.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        final SemanticsNode cellTwo = _nodeWithLabel(tester, 'cell two\ny');
        expect(cellTwo.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        for (final node in <SemanticsNode>[ok, disabled, price, merged, tapMe, cellOne, cellTwo]) {
          expect(node.getSemanticsData().hasAction(SemanticsAction.setSelection), isFalse);
          expect(node.getSemanticsData().hasAction(SemanticsAction.copy), isFalse);
          expect(node.getSemanticsData().textSelection, isNull);
          expect(node.flagsCollection.isFocused, Tristate.none);
        }
        final SemanticsNode plain = _nodeWithLabel(tester, 'plain');
        expect(plain.getSemanticsData().hasAction(SemanticsAction.setSelection), isTrue);
        expect(
          plain.getSemanticsData().textSelection,
          const TextSelection(baseOffset: 0, extentOffset: 5),
        );
        // The paragraph of every absorbed case is still merged: no stray label nodes.
        for (final label in <String>['x', 'y', 'a', 'b', r'$5']) {
          expect(_allNodes(tester).where((SemanticsNode node) => node.label == label), isEmpty);
        }
      },
    );

    testWidgets('a merged text field keeps its label, value and handlers', (
      WidgetTester tester,
    ) async {
      final controller = TextEditingController(text: 'abc');
      addTearDown(controller.dispose);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        _region(
          child: Column(
            children: <Widget>[
              const Text('Hello world'),
              MergeSemantics(
                child: Column(
                  children: <Widget>[
                    const Text('Email'),
                    EditableText(
                      controller: controller,
                      focusNode: focusNode,
                      style: const TextStyle(),
                      cursorColor: const Color(0xFF000000),
                      backgroundCursorColor: const Color(0xFF000000),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      focusNode.requestFocus();
      await tester.pump();
      _regionState(tester).selectAll();
      await tester.pump();

      final SemanticsNode field = tester.getSemantics(find.byType(MergeSemantics));
      final SemanticsData data = field.getSemanticsData();
      expect(data.flagsCollection.isTextField, isTrue);
      expect(data.label, 'Email');
      expect(data.value, 'abc');
      expect(data.textSelection, controller.selection);
      expect(data.hasAction(SemanticsAction.setSelection), isTrue);
      expect(_allNodes(tester).where((SemanticsNode node) => node.label == 'Email'), hasLength(1));

      tester.semantics.setSelection(find.semantics.byLabel('Email'), base: 1, extent: 2);
      await tester.pump();
      expect(controller.selection, const TextSelection(baseOffset: 1, extentOffset: 2));
      expect(_paragraphAt(tester, 0).selections, isNotEmpty);
    });
  });

  group('accessibility input', () {
    testWidgets('exact ranges for RTL, wrapped, ellipsized and mixed-direction text', (
      WidgetTester tester,
    ) async {
      final changes = <String?>[];
      await tester.pumpWidget(
        _region(
          onSelectionChanged: (SelectedContent? content) => changes.add(content?.plainText),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('שלום עולם'),
              SizedBox(width: 100, child: Text('aaaaaaaaaa bb')),
              SizedBox(
                width: 60,
                child: Text('Hello world', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Text('abc שלום def'),
            ],
          ),
        ),
      );
      await tester.pump();
      final cases = <(String, int, int, String)>[
        ('שלום עולם', 0, 3, 'שלו'),
        ('aaaaaaaaaa bb', 0, 11, 'aaaaaaaaaa '),
        ('Hello world', 9, 11, 'ld'),
        ('abc שלום def', 2, 5, 'c ש'),
      ];
      for (final (String label, int base, int extent, String text) in cases) {
        tester.semantics.setSelection(find.semantics.byLabel(label), base: base, extent: extent);
        await tester.pump();
        expect(
          _nodeWithLabel(tester, label).getSemanticsData().textSelection,
          TextSelection(baseOffset: base, extentOffset: extent),
          reason: label,
        );
        expect(changes.last, text, reason: label);
        expect(_regionState(tester).widget, isA<SelectableRegion>());
      }
      // Every other paragraph was cleared by the last request.
      expect(
        _allNodes(tester)
            .where((SemanticsNode node) => node.getSemanticsData().textSelection != null)
            .map((SemanticsNode node) => node.label),
        <String>['abc שלום def'],
      );
    });

    testWidgets('a range takes focus from a text field outside the region', (
      WidgetTester tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      final fieldFocusNode = FocusNode();
      addTearDown(fieldFocusNode.dispose);
      final controller = TextEditingController(text: 'field');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        TestWidgetsApp(
          home: Column(
            children: <Widget>[
              EditableText(
                controller: controller,
                focusNode: fieldFocusNode,
                style: const TextStyle(),
                cursorColor: const Color(0xFF000000),
                backgroundCursorColor: const Color(0xFF000000),
              ),
              SelectableRegion(
                focusNode: focusNode,
                selectionControls: emptyTextSelectionControls,
                child: const Text('Hello world'),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      fieldFocusNode.requestFocus();
      await tester.pump();

      // A caret leaves the field focused and the region untouched.
      tester.semantics.setSelection(find.semantics.byLabel('Hello world'), base: 11, extent: 11);
      await tester.pump();
      expect(fieldFocusNode.hasPrimaryFocus, isTrue);
      expect(_nodeWithLabel(tester, 'Hello world').getSemanticsData().textSelection, isNull);
      expect(_paragraphAt(tester, 0).selections, isEmpty);

      // A range moves primary focus to the region.
      tester.semantics.setSelection(find.semantics.byLabel('Hello world'), base: 0, extent: 2);
      await tester.pump();
      expect(focusNode.hasPrimaryFocus, isTrue);
      expect(fieldFocusNode.hasFocus, isFalse);
      expect(
        _nodeWithLabel(tester, 'Hello world').getSemanticsData().textSelection,
        const TextSelection(baseOffset: 0, extentOffset: 2),
      );
    });

    testWidgets('negative offsets clear the selection without an anchor', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_region(child: const Text('Hello world')));
      await tester.pump();
      // No selection: nothing happens.
      tester.semantics.setSelection(find.semantics.byLabel('Hello world'), base: -1, extent: -1);
      await tester.pump();
      expect(_regionState(tester).widget.focusNode, isNull);
      expect(_paragraphAt(tester, 0).selections, isEmpty);

      tester.semantics.setSelection(find.semantics.byLabel('Hello world'), base: 0, extent: 4);
      await tester.pump();
      expect(_paragraphAt(tester, 0).selections, isNotEmpty);
      tester.semantics.setSelection(find.semantics.byLabel('Hello world'), base: -1, extent: -1);
      await tester.pump();
      expect(_paragraphAt(tester, 0).selections, isEmpty);
      expect(_nodeWithLabel(tester, 'Hello world').getSemanticsData().textSelection, isNull);
    });
  });

  group('focus representation', () {
    testWidgets('the anchor paragraph is focused while the region has primary focus', (
      WidgetTester tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      final fieldFocusNode = FocusNode();
      addTearDown(fieldFocusNode.dispose);
      final controller = TextEditingController(text: 'abc');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _region(
          focusNode: focusNode,
          child: Column(
            children: <Widget>[
              const Text('First'),
              const Text('Second'),
              EditableText(
                controller: controller,
                focusNode: fieldFocusNode,
                style: const TextStyle(),
                cursorColor: const Color(0xFF000000),
                backgroundCursorColor: const Color(0xFF000000),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      bool focused(String label) =>
          _nodeWithLabel(tester, label).flagsCollection.isFocused == Tristate.isTrue;
      bool focusable(String label) =>
          _nodeWithLabel(tester, label).flagsCollection.isFocused != Tristate.none;
      expect(focused('First'), isFalse);
      expect(focusable('First'), isFalse);

      focusNode.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(focusNode.hasPrimaryFocus, isTrue);
      expect(focused('First'), isTrue);
      expect(focusable('First'), isTrue);
      expect(focused('Second'), isFalse);
      expect(focusable('Second'), isFalse);
      expect(
        _nodeWithLabel(tester, 'First').getSemanticsData().hasAction(SemanticsAction.setSelection),
        isTrue,
      );

      // A nested text field takes primary focus: no paragraph is focused.
      fieldFocusNode.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);
      expect(focusNode.hasPrimaryFocus, isFalse);
      expect(focused('First'), isFalse);
      expect(focusable('First'), isFalse);

      // Back to the region: the anchor is still the first paragraph.
      focusNode.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(focused('First'), isTrue);

      // An accessibility range moves the anchor.
      tester.semantics.setSelection(find.semantics.byLabel('Second'), base: 0, extent: 2);
      await tester.pump();
      expect(focused('First'), isFalse);
      expect(focused('Second'), isTrue);

      // Losing focus removes the representation.
      focusNode.unfocus();
      await tester.pump();
      await tester.pump();
      expect(focused('Second'), isFalse);
      expect(focusable('Second'), isFalse);
    });

    testWidgets('the anchor follows the last pointer down', (WidgetTester tester) async {
      await tester.pumpWidget(
        _region(child: const Column(children: <Widget>[Text('First'), Text('Second')])),
      );
      await tester.pump();
      await tester.tapAt(_textOffsetToPosition(_paragraphAt(tester, 1), 2));
      await tester.pump();
      await tester.pump();
      expect(_regionState(tester).widget, isA<SelectableRegion>());
      expect(_nodeWithLabel(tester, 'Second').flagsCollection.isFocused, Tristate.isTrue);
      expect(_nodeWithLabel(tester, 'First').flagsCollection.isFocused, Tristate.none);
    });

    testWidgets('an anchor absorbed into a button never reports focus', (
      WidgetTester tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        _region(
          focusNode: focusNode,
          child: Column(
            children: <Widget>[
              Semantics(button: true, onTap: () {}, child: const Text('OK')),
              const Text('Hello'),
            ],
          ),
        ),
      );
      await tester.pump();
      focusNode.requestFocus();
      await tester.pump();
      await tester.pump();
      final SemanticsNode ok = _nodeWithLabel(tester, 'OK');
      expect(ok.flagsCollection.isButton, isTrue);
      expect(ok.flagsCollection.isFocused, Tristate.none);
      expect(ok.getSemanticsData().hasAction(SemanticsAction.setSelection), isFalse);
    });
  });

  group('two regions and a nested text field', () {
    testWidgets('each region publishes only its own paragraphs', (WidgetTester tester) async {
      final recognizer = TapGestureRecognizer()..onTap = () {};
      addTearDown(recognizer.dispose);
      final fieldFocusNode = FocusNode();
      addTearDown(fieldFocusNode.dispose);
      final controller = TextEditingController(text: 'abc');
      addTearDown(controller.dispose);
      final r1FocusNode = FocusNode();
      addTearDown(r1FocusNode.dispose);
      await tester.pumpWidget(
        TestWidgetsApp(
          home: Column(
            children: <Widget>[
              SelectableRegion(
                focusNode: r1FocusNode,
                selectionControls: emptyTextSelectionControls,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('Order number', style: TextStyle(fontSize: 20)),
                    Text.rich(
                      TextSpan(
                        text: 'Track ',
                        style: const TextStyle(fontSize: 20),
                        children: <InlineSpan>[
                          TextSpan(text: 'here', recognizer: recognizer),
                          const TextSpan(text: ' anytime.'),
                        ],
                      ),
                    ),
                    EditableText(
                      controller: controller,
                      focusNode: fieldFocusNode,
                      style: const TextStyle(),
                      cursorColor: const Color(0xFF000000),
                      backgroundCursorColor: const Color(0xFF000000),
                    ),
                  ],
                ),
              ),
              SelectableRegion(
                selectionControls: emptyTextSelectionControls,
                child: const Text('Footer note'),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      final RenderParagraph p1 = _paragraphAt(tester, 0);
      final RenderParagraph p2 = _paragraphAt(tester, 1);
      TextSelection? selectionOf(String label) =>
          _nodeWithLabel(tester, label).getSemanticsData().textSelection;

      // 1. Drag in R1 from "Order" into "here".
      await _mouseDrag(tester, _textOffsetToPosition(p1, 0), _textOffsetToPosition(p2, 8));
      expect(selectionOf('Order number'), const TextSelection(baseOffset: 0, extentOffset: 12));
      expect(selectionOf('Track '), const TextSelection(baseOffset: 0, extentOffset: 6));
      expect(selectionOf('here'), isNull);
      expect(selectionOf(' anytime.'), isNull);
      expect(selectionOf('Footer note'), isNull);
      expect(_nodeWithLabel(tester, 'Order number').flagsCollection.isFocused, Tristate.isTrue);

      // 2. A screen reader selects the first character of " anytime.".
      tester.semantics.setSelection(find.semantics.byLabel(' anytime.'), base: 0, extent: 1);
      await tester.pump();
      expect(p2.selections, const <TextSelection>[TextSelection(baseOffset: 10, extentOffset: 11)]);
      expect(selectionOf(' anytime.'), const TextSelection(baseOffset: 0, extentOffset: 1));
      expect(selectionOf('Order number'), isNull);
      expect(selectionOf('Track '), isNull);

      // 3. Focusing the nested field keeps R1's selection and drops the paragraph focus.
      fieldFocusNode.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(r1FocusNode.hasFocus, isTrue);
      expect(r1FocusNode.hasPrimaryFocus, isFalse);
      expect(selectionOf(' anytime.'), const TextSelection(baseOffset: 0, extentOffset: 1));
      expect(
        _allNodes(tester)
            .where((SemanticsNode node) => node.flagsCollection.isFocused == Tristate.isTrue)
            .map((SemanticsNode node) => node.flagsCollection.isTextField),
        <bool>[true],
      );

      // 4. Selecting in R2 leaves R1 untouched.
      tester.semantics.setSelection(find.semantics.byLabel('Footer note'), base: 0, extent: 6);
      await tester.pump();
      expect(selectionOf('Footer note'), const TextSelection(baseOffset: 0, extentOffset: 6));
      expect(selectionOf(' anytime.'), const TextSelection(baseOffset: 0, extentOffset: 1));
    });
  });

  group('keyboard start', () {
    const shiftRight = SingleActivator(LogicalKeyboardKey.arrowRight, shift: true);
    const shiftLeft = SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true);

    testWidgets('Shift+Right with no selection starts at the anchor paragraph', (
      WidgetTester tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        _region(
          focusNode: focusNode,
          child: const Column(children: <Widget>[Text('First'), Text('Second')]),
        ),
      );
      await tester.pump();
      focusNode.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(_paragraphAt(tester, 0).selections, isEmpty);

      for (var i = 1; i <= 3; i += 1) {
        await sendKeyCombination(tester, shiftRight);
        await tester.pump();
        expect(_paragraphAt(tester, 0).selections, <TextSelection>[
          TextSelection(baseOffset: 0, extentOffset: i),
        ]);
        expect(
          _nodeWithLabel(tester, 'First').getSemanticsData().textSelection,
          TextSelection(baseOffset: 0, extentOffset: i),
        );
      }
      expect(_paragraphAt(tester, 1).selections, isEmpty);
    });

    testWidgets('Shift+Left with no selection starts at the end of the last paragraph', (
      WidgetTester tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        _region(
          focusNode: focusNode,
          child: const Column(children: <Widget>[Text('First'), Text('Second')]),
        ),
      );
      await tester.pump();
      focusNode.requestFocus();
      await tester.pump();
      await tester.pump();

      await sendKeyCombination(tester, shiftLeft);
      await tester.pump();
      expect(_paragraphAt(tester, 0).selections, isEmpty);
      // Extending backward from a caret moves the start edge, as it does
      // after a click, so the range stays forward.
      expect(_paragraphAt(tester, 1).selections, const <TextSelection>[
        TextSelection(baseOffset: 5, extentOffset: 6),
      ]);
      expect(
        _nodeWithLabel(tester, 'Second').getSemanticsData().textSelection,
        const TextSelection(baseOffset: 5, extentOffset: 6),
      );
    });

    testWidgets('starts in the first visible paragraph of a scrolled list', (
      WidgetTester tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _region(
          focusNode: focusNode,
          child: ListView(
            controller: controller,
            itemExtent: 50.0,
            children: <Widget>[for (int i = 0; i < 50; i += 1) Text('Item $i')],
          ),
        ),
      );
      await tester.pump();
      controller.jumpTo(
        1500.0,
      ); // Item 30 at the top; items in the cache extent above are laid out.
      await tester.pump();
      focusNode.requestFocus();
      await tester.pump();
      await tester.pump();

      await sendKeyCombination(tester, shiftRight);
      await tester.pump();
      expect(controller.offset, 1500.0);
      final Iterable<SemanticsNode> selected = _allNodes(tester)
          .where((SemanticsNode node) => node.getSemanticsData().textSelection != null);
      expect(selected.map((SemanticsNode node) => node.label), <String>['Item 30']);
      expect(
        selected.single.getSemanticsData().textSelection,
        const TextSelection(baseOffset: 0, extentOffset: 1),
      );
    });

    testWidgets('is a no-op while a descendant has focus or semantics is off', (
      WidgetTester tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      final buttonFocusNode = FocusNode();
      addTearDown(buttonFocusNode.dispose);
      await tester.pumpWidget(
        _region(
          focusNode: focusNode,
          child: Column(
            children: <Widget>[
              const Text('First'),
              Focus(focusNode: buttonFocusNode, child: const SizedBox(width: 10, height: 10)),
            ],
          ),
        ),
      );
      await tester.pump();
      buttonFocusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);
      expect(focusNode.hasPrimaryFocus, isFalse);
      await sendKeyCombination(tester, shiftRight);
      await tester.pump();
      expect(_paragraphAt(tester, 0).selections, isEmpty);
    });

    testWidgets('is a no-op with semantics off', (WidgetTester tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(_region(focusNode: focusNode, child: const Text('First')));
      await tester.pump();
      focusNode.requestFocus();
      await tester.pump();
      expect(SemanticsBinding.instance.semanticsEnabled, isFalse);
      await sendKeyCombination(tester, shiftRight);
      await tester.pump();
      expect(_paragraphAt(tester, 0).selections, isEmpty);
    }, semanticsEnabled: false);

    testWidgets('starts at an accessibility caret', (WidgetTester tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        _region(
          focusNode: focusNode,
          child: const Column(children: <Widget>[Text('First'), Text('Second')]),
        ),
      );
      await tester.pump();
      tester.semantics.setSelection(find.semantics.byLabel('Second'), base: 3, extent: 3);
      await tester.pump();
      expect(focusNode.hasFocus, isFalse);
      focusNode.requestFocus();
      await tester.pump();
      await tester.pump();
      // The caret paragraph represents the focus and is where the selection starts.
      expect(_nodeWithLabel(tester, 'Second').flagsCollection.isFocused, Tristate.isTrue);
      await sendKeyCombination(tester, shiftRight);
      await tester.pump();
      expect(_paragraphAt(tester, 1).selections, const <TextSelection>[
        TextSelection(baseOffset: 3, extentOffset: 4),
      ]);
      // Shift+Down continues from there.
      await sendKeyCombination(
        tester,
        const SingleActivator(LogicalKeyboardKey.arrowDown, shift: true),
      );
      await tester.pump();
      expect(_paragraphAt(tester, 1).selections, const <TextSelection>[
        TextSelection(baseOffset: 3, extentOffset: 6),
      ]);
    });
  });

  group('Escape', () {
    testWidgets('clears the selection when semantics is on and no toolbar is visible', (
      WidgetTester tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      var dismissed = 0;
      await tester.pumpWidget(
        TestWidgetsApp(
          home: Actions(
            actions: <Type, Action<Intent>>{
              DismissIntent: CallbackAction<DismissIntent>(
                onInvoke: (DismissIntent intent) => dismissed += 1,
              ),
            },
            child: SelectableRegion(
              focusNode: focusNode,
              selectionControls: emptyTextSelectionControls,
              child: const Text('Hello world'),
            ),
          ),
        ),
      );
      await tester.pump();
      tester.semantics.setSelection(find.semantics.byLabel('Hello world'), base: 0, extent: 5);
      await tester.pump();
      expect(focusNode.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(_paragraphAt(tester, 0).selections, isEmpty);
      expect(_nodeWithLabel(tester, 'Hello world').getSemanticsData().textSelection, isNull);
      expect(dismissed, 0);

      // Nothing left to clear: the intent reaches the ancestor.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(dismissed, 1);
    });

    testWidgets('hides a visible toolbar and keeps the selection', (WidgetTester tester) async {
      final toolbarKey = UniqueKey();
      await tester.pumpWidget(
        TestWidgetsApp(
          home: SelectableRegion(
            selectionControls: testTextSelectionHandleControls,
            contextMenuBuilder: (BuildContext context, SelectableRegionState state) {
              return SizedBox.shrink(key: toolbarKey);
            },
            child: const Text('How are you?'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final RenderParagraph paragraph = _paragraphAt(tester, 0);
      // A long press selects a word and shows the context menu.
      final TestGesture gesture = await tester.startGesture(_textOffsetToPosition(paragraph, 6));
      addTearDown(gesture.removePointer);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(paragraph.selections, const <TextSelection>[
        TextSelection(baseOffset: 4, extentOffset: 7),
      ]);
      expect(find.byKey(toolbarKey), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byKey(toolbarKey), findsNothing);
      expect(paragraph.selections, const <TextSelection>[
        TextSelection(baseOffset: 4, extentOffset: 7),
      ]);

      // The next Escape clears it.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(paragraph.selections, isEmpty);
    }, skip: kIsWeb); // [intended] Web uses its native context menu.

    testWidgets('leaves the selection alone with semantics off and propagates', (
      WidgetTester tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      var dismissed = 0;
      await tester.pumpWidget(
        TestWidgetsApp(
          home: Actions(
            actions: <Type, Action<Intent>>{
              DismissIntent: CallbackAction<DismissIntent>(
                onInvoke: (DismissIntent intent) => dismissed += 1,
              ),
            },
            child: SelectableRegion(
              focusNode: focusNode,
              selectionControls: emptyTextSelectionControls,
              child: const Text('Hello world'),
            ),
          ),
        ),
      );
      await tester.pump();
      _delegateOf(tester).select(_fragmentAt(tester, 0), 0, 5);
      await tester.pump();
      expect(focusNode.hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(_paragraphAt(tester, 0).selections, isNotEmpty);
      expect(dismissed, 1);
    }, semanticsEnabled: false);
  });

  group('announcements', () {
    const window = Duration(milliseconds: 300);
    const shiftRight = SingleActivator(LogicalKeyboardKey.arrowRight, shift: true);
    const shiftLeft = SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true);
    List<String> messages(WidgetTester tester) =>
        tester.takeAnnouncements().map((CapturedAccessibilityAnnouncement a) => a.message).toList();

    testWidgets('one phrase per keystroke, coalesced over the window', (WidgetTester tester) async {
      await tester.pumpWidget(_region(child: const Text('Hello world')));
      await tester.pump();
      tester.semantics.setSelection(find.semantics.byLabel('Hello world'), base: 0, extent: 1);
      await tester.pump();
      expect(messages(tester), isEmpty);
      await tester.pump(window);
      expect(messages(tester), <String>['H selected']);

      await sendKeyCombination(tester, shiftRight);
      await tester.pump(window);
      expect(messages(tester), <String>['e selected']);

      // Five auto-repeat presses inside the window produce one phrase.
      for (var i = 0; i < 5; i += 1) {
        await sendKeyCombination(tester, shiftRight);
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(messages(tester), isEmpty);
      await tester.pump(window);
      expect(messages(tester), <String>['llo w selected']);

      // Shrinking speaks what was unselected.
      await sendKeyCombination(tester, shiftLeft);
      await tester.pump(window);
      expect(messages(tester), <String>['w unselected']);

      // A single whitespace character is named.
      await sendKeyCombination(tester, shiftLeft);
      await tester.pump(window);
      expect(messages(tester), <String>['space unselected']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('one phrase per drag end and none during the drag', (WidgetTester tester) async {
      await tester.pumpWidget(
        _region(child: const Text('Hello world', style: TextStyle(fontSize: 20))),
      );
      await tester.pump();
      final RenderParagraph paragraph = _paragraphAt(tester, 0);
      final Offset from = _textOffsetToPosition(paragraph, 0);
      final Offset to = _textOffsetToPosition(paragraph, 5);
      final TestGesture gesture = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await tester.pump();
      for (var i = 1; i <= 10; i += 1) {
        await gesture.moveTo(Offset.lerp(from, to, i / 10)!);
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(messages(tester), isEmpty);
      await gesture.up();
      await tester.pump();
      await tester.pump(window);
      expect(messages(tester), <String>['Hello selected']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('select all, clear, replacement and cross-paragraph deltas', (
      WidgetTester tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        _region(
          focusNode: focusNode,
          child: const Column(children: <Widget>[Text('First'), Text('Second')]),
        ),
      );
      await tester.pump();
      tester.semantics.setSelection(find.semantics.byLabel('First'), base: 3, extent: 5);
      await tester.pump(window);
      expect(messages(tester), <String>['st selected']);

      // Moving the selection elsewhere is a replacement.
      tester.semantics.setSelection(find.semantics.byLabel('Second'), base: 0, extent: 3);
      await tester.pump(window);
      expect(messages(tester), <String>['st unselected, Sec selected']);

      // Growing across the paragraph boundary joins the paragraphs with a space.
      await sendKeyCombination(
        tester,
        const SingleActivator(LogicalKeyboardKey.arrowUp, shift: true),
      );
      await tester.pump(window);
      final List<String> grown = messages(tester);
      expect(grown, hasLength(1));
      expect(grown.single, endsWith(' selected'));
      expect(grown.single, contains('First'));
      expect(grown.single, isNot(contains('FirstSec')));

      _regionState(tester).selectAll();
      await tester.pump(window);
      expect(messages(tester), <String>['All text selected']);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(window);
      expect(messages(tester), <String>['Selection cleared']);

      // Nothing to clear: no announcement.
      _regionState(tester).clearSelection();
      await tester.pump(window);
      expect(messages(tester), isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('a focus-loss clear is silent', (WidgetTester tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      final otherFocusNode = FocusNode();
      addTearDown(otherFocusNode.dispose);
      await tester.pumpWidget(
        TestWidgetsApp(
          home: Column(
            children: <Widget>[
              SelectableRegion(
                focusNode: focusNode,
                selectionControls: emptyTextSelectionControls,
                child: const Text('Hello world'),
              ),
              Focus(focusNode: otherFocusNode, child: const SizedBox(width: 10, height: 10)),
            ],
          ),
        ),
      );
      await tester.pump();
      // The region clears its selection on focus loss only while the app is
      // running in the foreground.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      tester.semantics.setSelection(find.semantics.byLabel('Hello world'), base: 0, extent: 5);
      await tester.pump(window);
      expect(messages(tester), <String>['Hello selected']);

      otherFocusNode.requestFocus();
      await tester.pump();
      await tester.pump(window);
      expect(_paragraphAt(tester, 0).selections, isEmpty);
      expect(messages(tester), isEmpty);

      // The next selection is announced as new, not as a replacement.
      tester.semantics.setSelection(find.semantics.byLabel('Hello world'), base: 6, extent: 11);
      await tester.pump(window);
      expect(messages(tester), <String>['world selected']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('a long delta is announced as a count', (WidgetTester tester) async {
      final String text = List<String>.generate(60, (int i) => 'word$i').join(' ');
      await tester.pumpWidget(_region(child: Text(text)));
      await tester.pump();
      tester.semantics.setSelection(find.semantics.byLabel(text), base: 0, extent: 210);
      await tester.pump(window);
      expect(messages(tester), <String>['210 characters selected']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('follows the per-platform policy', (WidgetTester tester) async {
      await tester.pumpWidget(_region(child: const Text('Hello world')));
      await tester.pump();
      tester.semantics.setSelection(find.semantics.byLabel('Hello world'), base: 0, extent: 1);
      await tester.pump(window);
      final bool speaks = switch (defaultTargetPlatform) {
        TargetPlatform.macOS || TargetPlatform.windows || TargetPlatform.iOS => true,
        TargetPlatform.android || TargetPlatform.linux || TargetPlatform.fuchsia => false,
      };
      expect(messages(tester), speaks ? <String>['H selected'] : isEmpty);
      // Keyboard changes follow the same table.
      await sendKeyCombination(tester, shiftRight);
      await tester.pump(window);
      expect(messages(tester), speaks ? <String>['e selected'] : isEmpty);
    }, variant: TargetPlatformVariant.all());

    testWidgets('a WidgetsLocalizations override wins', (WidgetTester tester) async {
      await tester.pumpWidget(
        TestWidgetsApp(
          localizationsDelegates: const <LocalizationsDelegate<Object?>>[
            _CustomWidgetsLocalizationsDelegate(),
          ],
          home: SelectableRegion(
            selectionControls: emptyTextSelectionControls,
            child: const Text('Hello world'),
          ),
        ),
      );
      await tester.pump();
      tester.semantics.setSelection(find.semantics.byLabel('Hello world'), base: 0, extent: 5);
      await tester.pump(window);
      expect(messages(tester), <String>['[Hello]']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('a pending phrase is flushed on dispose', (WidgetTester tester) async {
      await tester.pumpWidget(_region(child: const Text('Hello world')));
      await tester.pump();
      tester.semantics.setSelection(find.semantics.byLabel('Hello world'), base: 0, extent: 5);
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      expect(messages(tester), <String>['Hello selected']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });
}

class _CustomWidgetsLocalizations extends DefaultWidgetsLocalizations {
  const _CustomWidgetsLocalizations();

  @override
  String selectedTextAnnouncement(String text) => '[$text]';
}

class _CustomWidgetsLocalizationsDelegate extends LocalizationsDelegate<WidgetsLocalizations> {
  const _CustomWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<WidgetsLocalizations> load(Locale locale) {
    return SynchronousFuture<WidgetsLocalizations>(const _CustomWidgetsLocalizations());
  }

  @override
  bool shouldReload(_CustomWidgetsLocalizationsDelegate old) => false;
}
