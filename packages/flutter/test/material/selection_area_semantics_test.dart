// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Material forms of the merge-rule cases in
// test/widgets/selectable_region_semantics_test.dart (flutter/flutter#182909).

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  testWidgets('Material controls under a SelectionArea keep their semantics', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController(text: 'abc');
    addTearDown(controller.dispose);
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SelectionArea(
            child: Column(
              children: <Widget>[
                TextButton(onPressed: () {}, child: const Text('OK')),
                const ListTile(title: Text('Inbox')),
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(labelText: 'Email', suffixText: '.com'),
                ),
                const Text('plain'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.showKeyboard(find.byType(TextField));
    await tester.pump();
    expect(focusNode.hasPrimaryFocus, isTrue);
    tester.state<SelectableRegionState>(find.byType(SelectableRegion)).selectAll();
    await tester.pump();

    final SemanticsNode ok = _allNodes(tester)
        .singleWhere((SemanticsNode node) => node.label == 'OK');
    expect(ok.flagsCollection.isButton, isTrue);
    expect(ok.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(ok.getSemanticsData().hasAction(SemanticsAction.setSelection), isFalse);
    expect(ok.getSemanticsData().textSelection, isNull);

    final SemanticsNode inbox = _allNodes(tester)
        .singleWhere((SemanticsNode node) => node.label == 'Inbox');
    expect(inbox.getSemanticsData().hasAction(SemanticsAction.setSelection), isFalse);
    expect(inbox.getSemanticsData().textSelection, isNull);

    // The focused field is one node that carries its label, affix, value and
    // its own selection handlers.
    final List<SemanticsNode> fields = _allNodes(tester)
        .where((SemanticsNode node) => node.flagsCollection.isTextField)
        .toList();
    expect(fields, hasLength(1));
    final SemanticsData field = fields.single.getSemanticsData();
    expect(field.label, 'Email');
    expect(field.value, 'abc');
    expect(field.textSelection, controller.selection);
    expect(field.hasAction(SemanticsAction.setSelection), isTrue);
    // The label is merged into the field exactly as before; the suffix is its
    // own node today and, as plain text under the SelectionArea, selectable.
    expect(_allNodes(tester).where((SemanticsNode node) => node.label == 'Email'), hasLength(1));
    final SemanticsNode suffix = _allNodes(tester)
        .singleWhere((SemanticsNode node) => node.label == '.com');
    expect(suffix.getSemanticsData().hasAction(SemanticsAction.setSelection), isTrue);
    tester.semantics.performAction(
      find.semantics.byValue('abc'),
      SemanticsAction.setSelection,
      args: <String, int>{'base': 1, 'extent': 2},
    );
    await tester.pump();
    expect(controller.selection, const TextSelection(baseOffset: 1, extentOffset: 2));

    final SemanticsNode plain = _allNodes(tester)
        .singleWhere((SemanticsNode node) => node.label == 'plain');
    expect(plain.getSemanticsData().hasAction(SemanticsAction.setSelection), isTrue);
    expect(
      plain.getSemanticsData().textSelection,
      const TextSelection(baseOffset: 0, extentOffset: 5),
    );
  });

  testWidgets('an unfocused TextField under a SelectionArea advertises no selection action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: SelectionArea(
            child: TextField(
              decoration: InputDecoration(labelText: 'Email', suffixText: '.com'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final List<SemanticsNode> fields = _allNodes(tester)
        .where((SemanticsNode node) => node.flagsCollection.isTextField)
        .toList();
    expect(fields, hasLength(1));
    expect(fields.single.getSemanticsData().hasAction(SemanticsAction.setSelection), isFalse);
    expect(fields.single.getSemanticsData().textSelection, isNull);
  });
}
