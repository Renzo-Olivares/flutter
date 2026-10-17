// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Unit tests for the merge rules that keep selection semantics on pure-text
// nodes only. These use synthetic [SemanticsConfiguration]s, independent of
// [Text], so that the rules are proven before any producer sets the marker.

import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../rendering/rendering_tester.dart';

const Rect _kRect = Rect.fromLTRB(0.0, 0.0, 10.0, 10.0);

/// A configuration shaped like the one a pure-text paragraph publishes.
SemanticsConfiguration _paragraph(
  String label, {
  TextSelection? selection,
  SetSelectionHandler? onSetSelection,
  VoidCallback? onCopy,
}) {
  final config = SemanticsConfiguration()
    ..label = label
    ..textDirection = TextDirection.ltr
    ..selectableTextLength = label.length
    ..onSetSelection = onSetSelection ?? (TextSelection selection) {};
  if (selection != null) {
    config.textSelection = selection;
  }
  if (onCopy != null) {
    config.onCopy = onCopy;
  }
  return config;
}

/// A configuration shaped like the one a focused text field publishes.
SemanticsConfiguration _textField(
  String value, {
  TextSelection? selection,
  SetSelectionHandler? onSetSelection,
  VoidCallback? onCopy,
}) {
  final config = SemanticsConfiguration()
    ..isTextField = true
    ..value = value
    ..textDirection = TextDirection.ltr;
  if (onSetSelection != null) {
    config.onSetSelection = onSetSelection;
  }
  if (onCopy != null) {
    config.onCopy = onCopy;
  }
  if (selection != null) {
    config.textSelection = selection;
  }
  return config;
}

SemanticsData _dataOf(SemanticsConfiguration config) {
  final node = SemanticsNode()..rect = _kRect;
  node.updateWith(config: config);
  return node.getSemanticsData();
}

/// Attaches a node formed from [config] under a root owned by a fresh
/// [SemanticsOwner], so that actions can be dispatched to it by id.
({SemanticsOwner owner, SemanticsNode node}) _attach(
  SemanticsConfiguration config, {
  List<SemanticsNode> children = const <SemanticsNode>[],
}) {
  final owner = SemanticsOwner(onSemanticsUpdate: (SemanticsUpdate update) {});
  addTearDown(owner.dispose);
  final root = SemanticsNode.root(owner: owner)..rect = _kRect;
  final node = SemanticsNode()..rect = _kRect;
  node.updateWith(config: config, childrenInInversePaintOrder: children);
  root.updateWith(
    config: SemanticsConfiguration()..isSemanticBoundary = true,
    childrenInInversePaintOrder: <SemanticsNode>[node],
  );
  return (owner: owner, node: node);
}

const Map<String, int> _kRange = <String, int>{'base': 0, 'extent': 1};

void main() {
  TestRenderingFlutterBinding.ensureInitialized();

  setUp(() {
    debugResetSemanticsIdCounter();
  });

  group('marker', () {
    test('is copied by copy() and compared by updateWith', () {
      final SemanticsConfiguration config = _paragraph('Hello');
      expect(config.selectableTextLength, 5);
      expect(config.copy().selectableTextLength, 5);

      final (:SemanticsOwner owner, :SemanticsNode node) = _attach(config);
      expect(node.debugIsDirty, isTrue);
      owner.sendSemanticsUpdate();
      expect(node.debugIsDirty, isFalse);
      node.updateWith(config: config.copy());
      expect(node.debugIsDirty, isFalse);
      node.updateWith(config: config.copy()..selectableTextLength = null);
      expect(node.debugIsDirty, isTrue);
    });
  });

  group('isCompatibleWith', () {
    test('ignores the selection bits of two marked configs', () {
      final SemanticsConfiguration a = _paragraph('a', onCopy: () {});
      final SemanticsConfiguration b = _paragraph('b', onCopy: () {});
      expect(a.isCompatibleWith(b), isTrue);
      expect(b.isCompatibleWith(a), isTrue);
    });

    test('ignores the selection bits of a marked config next to a text field', () {
      final SemanticsConfiguration label = _paragraph('Email');
      final SemanticsConfiguration field = _textField(
        '',
        onSetSelection: (TextSelection selection) {},
      );
      expect(label.isCompatibleWith(field), isTrue);
      expect(field.isCompatibleWith(label), isTrue);
    });

    test('keeps the conflict between two unmarked setSelection configs', () {
      final a = SemanticsConfiguration()..onSetSelection = (TextSelection selection) {};
      final b = SemanticsConfiguration()..onSetSelection = (TextSelection selection) {};
      expect(a.isCompatibleWith(b), isFalse);
    });

    test('keeps every other action conflict for a marked config', () {
      final SemanticsConfiguration a = _paragraph('a')..onTap = () {};
      final b = SemanticsConfiguration()..onTap = () {};
      expect(a.isCompatibleWith(b), isFalse);
    });
  });

  group('absorb', () {
    test('a text field child overwrites the selection data of a marked label', () {
      var labelCalls = 0;
      var fieldCalls = 0;
      final merged = SemanticsConfiguration()
        ..absorb(
          _paragraph(
            'Email',
            selection: const TextSelection(baseOffset: 0, extentOffset: 2),
            onSetSelection: (TextSelection selection) => labelCalls += 1,
          ),
        )
        ..absorb(
          _textField(
            'abc',
            selection: const TextSelection.collapsed(offset: 1),
            onSetSelection: (TextSelection selection) => fieldCalls += 1,
          ),
        );
      expect(merged.isTextField, isTrue);
      expect(merged.textSelection, const TextSelection.collapsed(offset: 1));
      final (:SemanticsOwner owner, :SemanticsNode node) = _attach(merged);
      owner.performAction(node.id, SemanticsAction.setSelection, _kRange);
      expect(fieldCalls, 1);
      expect(labelCalls, 0);
    });

    test('a marked suffix never overwrites a text field that came first', () {
      var suffixCalls = 0;
      var fieldCalls = 0;
      final merged = SemanticsConfiguration()
        ..absorb(
          _textField(
            'abc',
            selection: const TextSelection.collapsed(offset: 1),
            onSetSelection: (TextSelection selection) => fieldCalls += 1,
            onCopy: () => fieldCalls += 10,
          ),
        )
        ..absorb(
          _paragraph(
            '.com',
            selection: const TextSelection(baseOffset: 0, extentOffset: 1),
            onSetSelection: (TextSelection selection) => suffixCalls += 1,
            onCopy: () => suffixCalls += 10,
          ),
        );
      expect(merged.textSelection, const TextSelection.collapsed(offset: 1));
      final (:SemanticsOwner owner, :SemanticsNode node) = _attach(merged);
      owner.performAction(node.id, SemanticsAction.setSelection, _kRange);
      owner.performAction(node.id, SemanticsAction.copy);
      expect(fieldCalls, 11);
      expect(suffixCalls, 0);
    });

    test('a marked suffix never publishes a selection on an unselected text field', () {
      final merged = SemanticsConfiguration()
        ..absorb(_textField('abc'))
        ..absorb(
          _paragraph('.com', selection: const TextSelection(baseOffset: 0, extentOffset: 1)),
        );
      expect(merged.isTextField, isTrue);
      expect(merged.textSelection, isNull);
      // The text field is unfocused and has no handlers; the suffix's handler
      // is dropped at node time because the merged node is a text field.
      expect(_dataOf(merged).hasAction(SemanticsAction.setSelection), isFalse);
      expect(_dataOf(merged).textSelection, isNull);
    });

    test('an unmarked parent keeps a single marked child selectable', () {
      final merged = SemanticsConfiguration()
        ..absorb(
          _paragraph('Hello', selection: const TextSelection(baseOffset: 1, extentOffset: 3)),
        );
      final SemanticsData data = _dataOf(merged);
      expect(data.hasAction(SemanticsAction.setSelection), isTrue);
      expect(data.textSelection, const TextSelection(baseOffset: 1, extentOffset: 3));
    });
  });

  group('node-time filter', () {
    test('a pure-text config keeps its selection semantics', () {
      final SemanticsData data = _dataOf(
        _paragraph(
          'Hello',
          selection: const TextSelection(baseOffset: 0, extentOffset: 2),
          onCopy: () {},
        ),
      );
      expect(data.hasAction(SemanticsAction.setSelection), isTrue);
      expect(data.hasAction(SemanticsAction.copy), isTrue);
      expect(data.textSelection, const TextSelection(baseOffset: 0, extentOffset: 2));
    });

    test('a label concatenation drops the selection semantics', () {
      final merged = SemanticsConfiguration()
        ..label = 'Price'
        ..textDirection = TextDirection.ltr
        ..absorb(_paragraph(r'$5', selection: const TextSelection(baseOffset: 0, extentOffset: 1)));
      final SemanticsData data = _dataOf(merged);
      expect(data.label, 'Price\n\$5');
      expect(data.hasAction(SemanticsAction.setSelection), isFalse);
      expect(data.textSelection, isNull);
    });

    test('two marked configs merged together drop the selection semantics', () {
      final merged = SemanticsConfiguration()
        ..absorb(_paragraph('a', selection: const TextSelection(baseOffset: 0, extentOffset: 1)))
        ..absorb(_paragraph('b'));
      final SemanticsData data = _dataOf(merged);
      expect(data.hasAction(SemanticsAction.setSelection), isFalse);
      expect(data.textSelection, isNull);
    });

    test('a button drops the selection semantics but keeps its tap', () {
      var tapped = false;
      final merged = SemanticsConfiguration()
        ..isButton = true
        ..onTap = () {
          tapped = true;
        }
        ..absorb(_paragraph('OK', selection: const TextSelection(baseOffset: 0, extentOffset: 1)));
      final (:SemanticsOwner owner, :SemanticsNode node) = _attach(merged);
      final SemanticsData data = node.getSemanticsData();
      expect(data.label, 'OK');
      expect(data.hasAction(SemanticsAction.setSelection), isFalse);
      expect(data.hasAction(SemanticsAction.copy), isFalse);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.textSelection, isNull);
      owner.performAction(node.id, SemanticsAction.setSelection, _kRange);
      expect(tapped, isFalse);
      owner.performAction(node.id, SemanticsAction.tap);
      expect(tapped, isTrue);
    });

    test('a disabled button drops the selection semantics', () {
      final merged = SemanticsConfiguration()
        ..isButton = true
        ..isEnabled = false
        ..absorb(_paragraph('OK'));
      expect(_dataOf(merged).hasAction(SemanticsAction.setSelection), isFalse);
    });

    test('a tap handler in either order drops the selection semantics', () {
      final tapFirst = SemanticsConfiguration()
        ..absorb(SemanticsConfiguration()..onTap = () {})
        ..absorb(_paragraph('Hello'));
      final tapLast = SemanticsConfiguration()
        ..absorb(_paragraph('Hello'))
        ..absorb(SemanticsConfiguration()..onTap = () {});
      for (final config in <SemanticsConfiguration>[tapFirst, tapLast]) {
        final SemanticsData data = _dataOf(config);
        expect(data.hasAction(SemanticsAction.setSelection), isFalse);
        expect(data.hasAction(SemanticsAction.tap), isTrue);
      }
    });

    test('an explicit role, a value or a hint drops the selection semantics', () {
      expect(
        _dataOf(_paragraph('a')..isLink = true).hasAction(SemanticsAction.setSelection),
        isFalse,
      );
      expect(
        _dataOf(_paragraph('a')..role = SemanticsRole.tab).hasAction(SemanticsAction.setSelection),
        isFalse,
      );
      expect(
        _dataOf(_paragraph('a')..value = 'v').hasAction(SemanticsAction.setSelection),
        isFalse,
      );
      expect(_dataOf(_paragraph('a')..hint = 'h').hasAction(SemanticsAction.setSelection), isFalse);
    });

    test('state flags drop the selection semantics', () {
      // A list tile: selected and enabled state around a title.
      final tile = SemanticsConfiguration()
        ..isSelected = false
        ..isEnabled = true
        ..absorb(
          _paragraph('Inbox', selection: const TextSelection(baseOffset: 0, extentOffset: 5)),
        );
      final SemanticsData data = _dataOf(tile);
      expect(data.hasAction(SemanticsAction.setSelection), isFalse);
      expect(data.textSelection, isNull);
      expect(data.flagsCollection.isSelected, Tristate.isFalse);
      // A heading trait and clipping are plain text.
      expect(
        _dataOf(
          _paragraph('Title')
            ..isHeader = true
            ..isHidden = true,
        ).hasAction(SemanticsAction.setSelection),
        isTrue,
      );
    });

    test('a focusable and focused paragraph keeps its selection semantics', () {
      final SemanticsData data = _dataOf(
        _paragraph('a')
          ..isFocusable = true
          ..isFocused = true,
      );
      expect(data.hasAction(SemanticsAction.setSelection), isTrue);
    });

    test('an unmarked setSelection config is untouched', () {
      var calls = 0;
      final custom = SemanticsConfiguration()
        ..label = 'Price'
        ..textDirection = TextDirection.ltr
        ..onTap = () {}
        ..onSetSelection = (TextSelection selection) => calls += 1;
      final (:SemanticsOwner owner, :SemanticsNode node) = _attach(custom);
      expect(node.getSemanticsData().hasAction(SemanticsAction.setSelection), isTrue);
      owner.performAction(node.id, SemanticsAction.setSelection, _kRange);
      expect(calls, 1);
    });

    test('a marked child only drops its own handler next to an unmarked one', () {
      var customCalls = 0;
      var paragraphCalls = 0;
      final merged = SemanticsConfiguration()
        ..label = 'Price'
        ..textDirection = TextDirection.ltr
        ..onSetSelection = (TextSelection selection) {
          customCalls += 1;
        }
        ..absorb(
          _paragraph(
            r'$5',
            selection: const TextSelection(baseOffset: 0, extentOffset: 1),
            onSetSelection: (TextSelection selection) => paragraphCalls += 1,
            onCopy: () => paragraphCalls += 10,
          ),
        );
      final (:SemanticsOwner owner, :SemanticsNode node) = _attach(merged);
      final SemanticsData data = node.getSemanticsData();
      expect(data.hasAction(SemanticsAction.setSelection), isTrue);
      expect(data.hasAction(SemanticsAction.copy), isFalse);
      expect(data.textSelection, isNull);
      owner.performAction(node.id, SemanticsAction.setSelection, _kRange);
      owner.performAction(node.id, SemanticsAction.copy);
      expect(customCalls, 1);
      expect(paragraphCalls, 0);
    });
  });

  group('getSemanticsData with mergeAllDescendantsIntoThisNode', () {
    SemanticsNode mergeRoot(List<SemanticsNode> children) {
      final root = SemanticsNode()..rect = _kRect;
      root.updateWith(
        config: SemanticsConfiguration()
          ..isSemanticBoundary = true
          ..isMergingSemanticsOfDescendants = true,
        childrenInInversePaintOrder: children,
      );
      return root;
    }

    SemanticsNode leaf(SemanticsConfiguration config) {
      final node = SemanticsNode()..rect = _kRect;
      node.updateWith(config: config);
      return node;
    }

    test('a single merged paragraph keeps its selection semantics', () {
      final SemanticsNode root = mergeRoot(<SemanticsNode>[
        leaf(_paragraph('Hello', selection: const TextSelection(baseOffset: 0, extentOffset: 2))),
      ]);
      final SemanticsData data = root.getSemanticsData();
      expect(data.label, 'Hello');
      expect(data.hasAction(SemanticsAction.setSelection), isTrue);
      expect(data.textSelection, const TextSelection(baseOffset: 0, extentOffset: 2));
    });

    test('two merged paragraphs drop the selection semantics', () {
      final SemanticsNode root = mergeRoot(<SemanticsNode>[
        leaf(_paragraph('a', selection: const TextSelection(baseOffset: 0, extentOffset: 1))),
        leaf(_paragraph('b')),
      ]);
      final SemanticsData data = root.getSemanticsData();
      expect(data.label, 'a\nb');
      expect(data.hasAction(SemanticsAction.setSelection), isFalse);
      expect(data.textSelection, isNull);
    });

    test('a merged paragraph under a button drops the selection semantics', () {
      final root = SemanticsNode()..rect = _kRect;
      root.updateWith(
        config: SemanticsConfiguration()
          ..isSemanticBoundary = true
          ..isMergingSemanticsOfDescendants = true
          ..isButton = true
          ..onTap = () {},
        childrenInInversePaintOrder: <SemanticsNode>[leaf(_paragraph('OK'))],
      );
      final SemanticsData data = root.getSemanticsData();
      expect(data.hasAction(SemanticsAction.setSelection), isFalse);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
    });

    test('a merged text field wins over a merged paragraph in either order', () {
      for (final fieldFirst in <bool>[true, false]) {
        final SemanticsNode field = leaf(
          _textField(
            'abc',
            selection: const TextSelection.collapsed(offset: 2),
            onSetSelection: (TextSelection selection) {},
          ),
        );
        final SemanticsNode label = leaf(
          _paragraph('Email', selection: const TextSelection(baseOffset: 0, extentOffset: 1)),
        );
        final SemanticsNode root = mergeRoot(
          fieldFirst ? <SemanticsNode>[field, label] : <SemanticsNode>[label, field],
        );
        final SemanticsData data = root.getSemanticsData();
        expect(data.flagsCollection.isTextField, isTrue);
        expect(data.textSelection, const TextSelection.collapsed(offset: 2));
        expect(data.hasAction(SemanticsAction.setSelection), isTrue);
      }
    });

    test('a merged paragraph advertises nothing on an unselected text field', () {
      final SemanticsNode root = mergeRoot(<SemanticsNode>[
        leaf(_paragraph('Email', selection: const TextSelection(baseOffset: 0, extentOffset: 1))),
        leaf(_textField('abc')),
      ]);
      final SemanticsData data = root.getSemanticsData();
      expect(data.flagsCollection.isTextField, isTrue);
      expect(data.textSelection, isNull);
      expect(data.hasAction(SemanticsAction.setSelection), isFalse);
    });
  });

  group('handler walk', () {
    test('a merged text field answers setSelection before a merged paragraph', () {
      var fieldCalls = 0;
      var paragraphCalls = 0;
      final owner = SemanticsOwner(onSemanticsUpdate: (SemanticsUpdate update) {});
      addTearDown(owner.dispose);
      final root = SemanticsNode.root(owner: owner)..rect = _kRect;
      final merged = SemanticsNode()..rect = _kRect;
      final paragraph = SemanticsNode()..rect = _kRect;
      final field = SemanticsNode()..rect = _kRect;
      paragraph.updateWith(
        config: _paragraph(
          'Email',
          onSetSelection: (TextSelection selection) => paragraphCalls += 1,
        ),
      );
      field.updateWith(
        config: _textField(
          'abc',
          selection: const TextSelection.collapsed(offset: 1),
          onSetSelection: (TextSelection selection) => fieldCalls += 1,
        ),
      );
      merged.updateWith(
        config: SemanticsConfiguration()
          ..isSemanticBoundary = true
          ..isMergingSemanticsOfDescendants = true,
        childrenInInversePaintOrder: <SemanticsNode>[paragraph, field],
      );
      root.updateWith(
        config: SemanticsConfiguration()..isSemanticBoundary = true,
        childrenInInversePaintOrder: <SemanticsNode>[merged],
      );
      owner.performAction(merged.id, SemanticsAction.setSelection, <String, int>{
        'base': 0,
        'extent': 1,
      });
      expect(fieldCalls, 1);
      expect(paragraphCalls, 0);
    });

    test('a merged paragraph never answers for an unselected merged text field', () {
      var paragraphCalls = 0;
      final owner = SemanticsOwner(onSemanticsUpdate: (SemanticsUpdate update) {});
      addTearDown(owner.dispose);
      final root = SemanticsNode.root(owner: owner)..rect = _kRect;
      final merged = SemanticsNode()..rect = _kRect;
      final paragraph = SemanticsNode()..rect = _kRect;
      final field = SemanticsNode()..rect = _kRect;
      paragraph.updateWith(
        config: _paragraph(
          'Email',
          onSetSelection: (TextSelection selection) => paragraphCalls += 1,
        ),
      );
      field.updateWith(config: _textField('abc'));
      merged.updateWith(
        config: SemanticsConfiguration()
          ..isSemanticBoundary = true
          ..isMergingSemanticsOfDescendants = true,
        childrenInInversePaintOrder: <SemanticsNode>[paragraph, field],
      );
      root.updateWith(
        config: SemanticsConfiguration()..isSemanticBoundary = true,
        childrenInInversePaintOrder: <SemanticsNode>[merged],
      );
      owner.performAction(merged.id, SemanticsAction.setSelection, <String, int>{
        'base': 0,
        'extent': 1,
      });
      expect(paragraphCalls, 0);
    });

    test('a merged paragraph answers setSelection when no text field is merged', () {
      var paragraphCalls = 0;
      final owner = SemanticsOwner(onSemanticsUpdate: (SemanticsUpdate update) {});
      addTearDown(owner.dispose);
      final root = SemanticsNode.root(owner: owner)..rect = _kRect;
      final merged = SemanticsNode()..rect = _kRect;
      final paragraph = SemanticsNode()..rect = _kRect;
      paragraph.updateWith(
        config: _paragraph(
          'Hello',
          onSetSelection: (TextSelection selection) => paragraphCalls += 1,
        ),
      );
      merged.updateWith(
        config: SemanticsConfiguration()
          ..isSemanticBoundary = true
          ..isMergingSemanticsOfDescendants = true,
        childrenInInversePaintOrder: <SemanticsNode>[paragraph],
      );
      root.updateWith(
        config: SemanticsConfiguration()..isSemanticBoundary = true,
        childrenInInversePaintOrder: <SemanticsNode>[merged],
      );
      owner.performAction(merged.id, SemanticsAction.setSelection, <String, int>{
        'base': 0,
        'extent': 1,
      });
      expect(paragraphCalls, 1);
    });
  });
}
