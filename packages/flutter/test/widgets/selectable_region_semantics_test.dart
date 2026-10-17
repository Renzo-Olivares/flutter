// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Widgets-layer tests for screen-reader selection in [SelectableRegion]
// (flutter/flutter#182909). No material import: the Material forms of these
// cases live in test/material/selection_area_semantics_test.dart.

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'clipboard_utils.dart';
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
  return delegate.selectables.single;
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
}
