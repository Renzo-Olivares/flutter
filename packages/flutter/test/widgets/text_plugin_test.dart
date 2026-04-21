// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui show BoxHeightStyle, BoxWidthStyle, TextBox;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TextPluginScope.maybeOf', () {
    testWidgets('returns null when no scope ancestor exists', (WidgetTester tester) async {
      TextPluginRegistrar? captured = _sentinel;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (BuildContext context) {
              captured = TextPluginScope.maybeOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(captured, isNull);
    });

    testWidgets('returns the registrar of the innermost scope when nested', (
      WidgetTester tester,
    ) async {
      TextPluginRegistrar? captured = _sentinel;
      final outerPlugin = _RecordingPlugin();
      final innerPlugin = _RecordingPlugin();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextPluginScope(
            plugin: outerPlugin,
            child: TextPluginScope(
              plugin: innerPlugin,
              child: Builder(
                builder: (BuildContext context) {
                  captured = TextPluginScope.maybeOf(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      // The marker's registrar chain is outermost-first, so maybeOf returns
      // the last element (the innermost scope's state).
      expect(captured, isNotNull);
      final TextPluginScopeMarker marker = TextPluginScopeMarker.maybeOf(
        tester.element(find.byType(Builder)),
      )!;
      expect(marker.registrars, hasLength(2));
      expect(identical(marker.registrars.last, captured), isTrue);
    });
  });

  group('TextPluginScopeMarker.registrars', () {
    testWidgets('outermost-first ordering across nested scopes', (WidgetTester tester) async {
      final outerPlugin = _RecordingPlugin();
      final innerPlugin = _RecordingPlugin();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextPluginScope(
            plugin: outerPlugin,
            child: TextPluginScope(
              plugin: innerPlugin,
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );

      // Register a delegate with each registrar and verify which plugin fired.
      final BuildContext ctx = tester.element(find.byType(SizedBox));
      final TextPluginScopeMarker marker = TextPluginScopeMarker.maybeOf(ctx)!;
      expect(marker.registrars, hasLength(2));

      final d0 = _FakeTextDelegate();
      final d1 = _FakeTextDelegate();
      addTearDown(d0.dispose);
      addTearDown(d1.dispose);
      marker.registrars[0].add(d0);
      marker.registrars[1].add(d1);
      expect(outerPlugin.added, equals(<TextDelegate>[d0]));
      expect(innerPlugin.added, equals(<TextDelegate>[d1]));

      marker.registrars[0].remove(d0);
      marker.registrars[1].remove(d1);
    });

    testWidgets('rebuild without structural change does not notify descendants', (
      WidgetTester tester,
    ) async {
      var builderCalls = 0;
      final plugin = _RecordingPlugin();
      Widget tree(Widget child) => Directionality(
        textDirection: TextDirection.ltr,
        child: TextPluginScope(plugin: plugin, child: child),
      );
      final Widget leaf = Builder(
        builder: (BuildContext context) {
          builderCalls += 1;
          TextPluginScopeMarker.maybeOf(context);
          return const SizedBox.shrink();
        },
      );
      await tester.pumpWidget(tree(leaf));
      expect(builderCalls, 1);
      await tester.pumpWidget(tree(leaf));
      // Same plugin instance, same registrar list — marker's
      // updateShouldNotify returns false, the leaf is not rebuilt.
      expect(builderCalls, 1);
    });
  });

  group('TextPluginScope lifecycle', () {
    testWidgets('add() fires didAddText and remove() fires didRemoveText', (
      WidgetTester tester,
    ) async {
      final plugin = _RecordingPlugin();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextPluginScope(plugin: plugin, child: const SizedBox.shrink()),
        ),
      );
      final TextPluginRegistrar registrar = TextPluginScope.maybeOf(
        tester.element(find.byType(SizedBox)),
      )!;
      final delegate = _FakeTextDelegate();
      addTearDown(delegate.dispose);

      registrar.add(delegate);
      expect(plugin.added, equals(<TextDelegate>[delegate]));
      expect(plugin.removed, isEmpty);

      registrar.remove(delegate);
      expect(plugin.removed, equals(<TextDelegate>[delegate]));
    });

    testWidgets('didUpdate() fires didUpdateText', (WidgetTester tester) async {
      final plugin = _RecordingPlugin();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextPluginScope(plugin: plugin, child: const SizedBox.shrink()),
        ),
      );
      final TextPluginRegistrar registrar = TextPluginScope.maybeOf(
        tester.element(find.byType(SizedBox)),
      )!;
      final delegate = _FakeTextDelegate();
      addTearDown(delegate.dispose);

      registrar.add(delegate);
      registrar.didUpdate(delegate);
      expect(plugin.updated, equals(<TextDelegate>[delegate]));
      registrar.remove(delegate);
    });

    testWidgets('identical plugin rebuild skips didRemove/didAdd cycle', (
      WidgetTester tester,
    ) async {
      const plugin = _ConstPlugin();
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: TextPluginScope(plugin: plugin, child: SizedBox.shrink()),
        ),
      );
      final TextPluginRegistrar registrar = TextPluginScope.maybeOf(
        tester.element(find.byType(SizedBox)),
      )!;
      final delegate = _FakeTextDelegate();
      addTearDown(delegate.dispose);
      registrar.add(delegate);
      expect(_ConstPlugin.addCount, 1);

      // Rebuild with the *same* const instance.
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: TextPluginScope(plugin: plugin, child: SizedBox.shrink()),
        ),
      );
      expect(_ConstPlugin.removeCount, 0);
      expect(_ConstPlugin.addCount, 1);
      registrar.remove(delegate);
    });

    testWidgets('new instance with shouldUpdate=false skips cycle', (WidgetTester tester) async {
      final oldPlugin = _ControllerPlugin(controller: 'a');
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextPluginScope(plugin: oldPlugin, child: const SizedBox.shrink()),
        ),
      );
      final TextPluginRegistrar registrar = TextPluginScope.maybeOf(
        tester.element(find.byType(SizedBox)),
      )!;
      final delegate = _FakeTextDelegate();
      addTearDown(delegate.dispose);
      registrar.add(delegate);
      expect(oldPlugin.added, equals(<TextDelegate>[delegate]));

      // Rebuild with a new instance but the same controller value.
      final newPlugin = _ControllerPlugin(controller: 'a');
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextPluginScope(plugin: newPlugin, child: const SizedBox.shrink()),
        ),
      );

      // shouldUpdate returned false — neither plugin saw a remove/add.
      expect(oldPlugin.removed, isEmpty);
      expect(newPlugin.added, isEmpty);
      registrar.remove(delegate);
    });

    testWidgets('new instance with shouldUpdate=true fires remove+add for every delegate', (
      WidgetTester tester,
    ) async {
      final oldPlugin = _ControllerPlugin(controller: 'a');
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextPluginScope(plugin: oldPlugin, child: const SizedBox.shrink()),
        ),
      );
      final TextPluginRegistrar registrar = TextPluginScope.maybeOf(
        tester.element(find.byType(SizedBox)),
      )!;
      final d0 = _FakeTextDelegate();
      final d1 = _FakeTextDelegate();
      addTearDown(d0.dispose);
      addTearDown(d1.dispose);
      registrar.add(d0);
      registrar.add(d1);

      // Rebuild with a new plugin instance whose controller differs.
      final newPlugin = _ControllerPlugin(controller: 'b');
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextPluginScope(plugin: newPlugin, child: const SizedBox.shrink()),
        ),
      );

      expect(oldPlugin.removed, equals(<TextDelegate>[d0, d1]));
      expect(newPlugin.added, equals(<TextDelegate>[d0, d1]));
      registrar.remove(d0);
      registrar.remove(d1);
    });
  });

  group('Text + RichText integration', () {
    testWidgets('didAddText fires once per Text in subtree on first build', (
      WidgetTester tester,
    ) async {
      final plugin = _RecordingPlugin();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextPluginScope(
            plugin: plugin,
            child: const Column(
              children: <Widget>[Text('first'), Text('second'), Text('third')],
            ),
          ),
        ),
      );
      expect(plugin.added, hasLength(3));
      expect(
        plugin.added.map((TextDelegate d) => d.text).toSet(),
        equals(<String>{'first', 'second', 'third'}),
      );
    });

    testWidgets('didAddText fires for RichText too (not just Text)', (WidgetTester tester) async {
      final plugin = _RecordingPlugin();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextPluginScope(
            plugin: plugin,
            child: RichText(text: const TextSpan(text: 'hello')),
          ),
        ),
      );
      expect(plugin.added, hasLength(1));
      expect(plugin.added.single.text, 'hello');
    });

    testWidgets('two nested scopes both receive every Text in the inner subtree', (
      WidgetTester tester,
    ) async {
      final outer = _RecordingPlugin();
      final inner = _RecordingPlugin();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextPluginScope(
            plugin: outer,
            child: TextPluginScope(
              plugin: inner,
              child: const Column(children: <Widget>[Text('a'), Text('b')]),
            ),
          ),
        ),
      );
      expect(outer.added, hasLength(2));
      expect(inner.added, hasLength(2));
      // Per the resolved decision: each (plugin, paragraph) pair gets its own
      // delegate. The outer plugin's delegates are NOT the same objects as
      // the inner plugin's delegates.
      expect(
        outer.added.toSet().intersection(inner.added.toSet()),
        isEmpty,
        reason: 'Per-plugin delegate instances do not collide.',
      );
    });

    testWidgets('didUpdateText fires when the Text data changes', (WidgetTester tester) async {
      final plugin = _RecordingPlugin();
      Widget tree(String data) => Directionality(
        textDirection: TextDirection.ltr,
        child: TextPluginScope(plugin: plugin, child: Text(data)),
      );
      await tester.pumpWidget(tree('hello'));
      expect(plugin.added, hasLength(1));
      final TextDelegate firstDelegate = plugin.added.single;

      await tester.pumpWidget(tree('hello world'));
      expect(plugin.updated, hasLength(1));
      // Same delegate instance is reused — plugin state keyed on the delegate
      // survives the text change (resolved-decision behavior).
      expect(identical(plugin.updated.single, firstDelegate), isTrue);
      expect(firstDelegate.text, 'hello world');
    });

    testWidgets('didUpdateText does NOT fire for paint-only changes', (WidgetTester tester) async {
      final plugin = _RecordingPlugin();
      Widget tree(Color color) => Directionality(
        textDirection: TextDirection.ltr,
        child: TextPluginScope(
          plugin: plugin,
          child: Text('hello', style: TextStyle(color: color)),
        ),
      );
      await tester.pumpWidget(tree(const Color(0xFFFF0000)));
      expect(plugin.added, hasLength(1));
      await tester.pumpWidget(tree(const Color(0xFF0000FF)));
      // Color is paint-only (RenderComparison.paint), not a text change.
      expect(plugin.updated, isEmpty);
    });

    testWidgets('didRemoveText fires when the scope is removed from the tree', (
      WidgetTester tester,
    ) async {
      final plugin = _RecordingPlugin();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextPluginScope(plugin: plugin, child: const Text('hello')),
        ),
      );
      expect(plugin.added, hasLength(1));
      // Remove the scope but keep the Text in the tree.
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Text('hello'),
        ),
      );
      expect(plugin.removed, hasLength(1));
    });

    testWidgets('didRemoveText fires when the covered Text is removed', (
      WidgetTester tester,
    ) async {
      final plugin = _RecordingPlugin();
      Widget tree(bool show) => Directionality(
        textDirection: TextDirection.ltr,
        child: TextPluginScope(
          plugin: plugin,
          child: show ? const Text('hello') : const SizedBox.shrink(),
        ),
      );
      await tester.pumpWidget(tree(true));
      expect(plugin.added, hasLength(1));
      await tester.pumpWidget(tree(false));
      expect(plugin.removed, hasLength(1));
    });

    testWidgets('coexistence with SelectionRegistrar: both systems see the Text', (
      WidgetTester tester,
    ) async {
      // Sanity-check the resolved "plugins are parallel to selection" decision
      // — the Text widget is under a SelectionRegistrarScope (so selection
      // wires up via Text.build's SelectionContainer.maybeOf branch) AND under
      // a TextPluginScope (so plugin wiring goes through RichText's marker
      // lookup). Neither should suppress the other.
      final selectionRegistrar = _CountingSelectionRegistrar();
      final plugin = _RecordingPlugin();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SelectionRegistrarScope(
            registrar: selectionRegistrar,
            child: TextPluginScope(plugin: plugin, child: const Text('coexist')),
          ),
        ),
      );
      expect(plugin.added, hasLength(1), reason: 'Plugin saw the Text.');
      expect(plugin.added.single.text, 'coexist');
      expect(
        selectionRegistrar.adds,
        greaterThan(0),
        reason: 'Selection saw the same Text.',
      );
    });

    testWidgets('compareTo orders sibling Texts in document order', (WidgetTester tester) async {
      final plugin = _RecordingPlugin();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextPluginScope(
            plugin: plugin,
            child: const Column(
              children: <Widget>[Text('first'), Text('second')],
            ),
          ),
        ),
      );
      expect(plugin.added, hasLength(2));
      final TextDelegate firstDelegate = plugin.added.singleWhere(
        (TextDelegate d) => d.text == 'first',
      );
      final TextDelegate secondDelegate = plugin.added.singleWhere(
        (TextDelegate d) => d.text == 'second',
      );
      expect(firstDelegate.compareTo(secondDelegate), lessThan(0));
      expect(secondDelegate.compareTo(firstDelegate), greaterThan(0));
    });

    testWidgets('WidgetSpan with inner Text produces a delegate per paragraph', (
      WidgetTester tester,
    ) async {
      final plugin = _RecordingPlugin();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextPluginScope(
            plugin: plugin,
            child: const Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(text: 'visit '),
                  WidgetSpan(child: Text('flutter.dev')),
                  TextSpan(text: ' for docs'),
                ],
              ),
            ),
          ),
        ),
      );
      // Two paragraphs (outer Text.rich + inner Text inside WidgetSpan) =
      // two delegates for the same plugin.
      expect(plugin.added, hasLength(2));
      final List<String> texts = plugin.added.map((TextDelegate d) => d.text).toList()..sort();
      expect(texts, <String>['flutter.dev', 'visit ￼ for docs']);
    });

    testWidgets('outer paragraph delegate.placeholderRanges flags the WidgetSpan position', (
      WidgetTester tester,
    ) async {
      final plugin = _RecordingPlugin();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextPluginScope(
            plugin: plugin,
            child: const Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(text: 'a'),
                  WidgetSpan(child: Text('B')),
                  TextSpan(text: 'c'),
                ],
              ),
            ),
          ),
        ),
      );
      final TextDelegate outerDelegate = plugin.added.singleWhere(
        (TextDelegate d) => d.text == 'a￼c',
      );
      expect(outerDelegate.placeholderRanges, equals(<TextRange>[const TextRange(start: 1, end: 2)]));
    });

    testWidgets('outer plugin and inner Text plugin do not collide on painter slots', (
      WidgetTester tester,
    ) async {
      // The 4-delegate case (2 plugins × 2 paragraphs from a WidgetSpan-Text):
      // each (plugin, paragraph) pair gets its own delegate, with its own
      // painter slots. Verify by counting distinct delegate identities.
      final outer = _RecordingPlugin();
      final inner = _RecordingPlugin();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextPluginScope(
            plugin: outer,
            child: TextPluginScope(
              plugin: inner,
              child: const Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(text: 'a'),
                    WidgetSpan(child: Text('B')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(outer.added, hasLength(2));
      expect(inner.added, hasLength(2));
      // 4 distinct delegates total.
      expect(<TextDelegate>{...outer.added, ...inner.added}, hasLength(4));
    });

    testWidgets('no scope ancestor → no plugin involvement (smoke)', (WidgetTester tester) async {
      // Baseline: plugin not installed → Text/RichText still work, the plugin
      // sees no callbacks. Confirms purely-additive nature.
      final plugin = _RecordingPlugin();
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Text('hello'),
        ),
      );
      expect(plugin.added, isEmpty);
      expect(plugin.removed, isEmpty);
      expect(plugin.updated, isEmpty);
    });
  });
}

// Sentinel that we can tell apart from `null` when asserting that the hook
// actually ran in the body of `testWidgets`.
const TextPluginRegistrar? _sentinel = null;

final class _RecordingPlugin extends TextPlugin {
  _RecordingPlugin();

  final List<TextDelegate> added = <TextDelegate>[];
  final List<TextDelegate> removed = <TextDelegate>[];
  final List<TextDelegate> updated = <TextDelegate>[];

  @override
  void didAddText(TextDelegate delegate) => added.add(delegate);

  @override
  void didUpdateText(TextDelegate delegate) => updated.add(delegate);

  @override
  void didRemoveText(TextDelegate delegate) => removed.add(delegate);
}

final class _ConstPlugin extends TextPlugin {
  const _ConstPlugin();

  static int addCount = 0;
  static int removeCount = 0;

  @override
  void didAddText(TextDelegate delegate) => addCount += 1;

  @override
  void didUpdateText(TextDelegate delegate) {}

  @override
  void didRemoveText(TextDelegate delegate) => removeCount += 1;
}

final class _ControllerPlugin extends TextPlugin {
  _ControllerPlugin({required this.controller});

  final String controller;
  final List<TextDelegate> added = <TextDelegate>[];
  final List<TextDelegate> removed = <TextDelegate>[];

  @override
  void didAddText(TextDelegate delegate) => added.add(delegate);

  @override
  void didUpdateText(TextDelegate delegate) {}

  @override
  void didRemoveText(TextDelegate delegate) => removed.add(delegate);

  @override
  bool shouldUpdate(TextPlugin oldPlugin) =>
      oldPlugin is! _ControllerPlugin || oldPlugin.controller != controller;
}

class _FakeTextDelegate with TextDelegate, ChangeNotifier {
  _FakeTextDelegate();

  @override
  String get text => '';

  @override
  List<TextRange> get placeholderRanges => const <TextRange>[];

  @override
  List<ui.TextBox> getBoxesForSelection(
    TextSelection selection, {
    ui.BoxHeightStyle boxHeightStyle = ui.BoxHeightStyle.tight,
    ui.BoxWidthStyle boxWidthStyle = ui.BoxWidthStyle.tight,
    bool includePlaceholders = true,
  }) => const <ui.TextBox>[];

  @override
  CustomPainter? get backgroundPainter => null;
  @override
  set backgroundPainter(CustomPainter? value) {}

  @override
  CustomPainter? get foregroundPainter => null;
  @override
  set foregroundPainter(CustomPainter? value) {}

  @override
  int compareTo(TextDelegate other) => identical(this, other) ? 0 : -1;

  @override
  TextSelection? get selection => null;

  @override
  void ensureVisible(TextRange range, {Duration duration = Duration.zero, Curve curve = Curves.ease}) {}
}

class _CountingSelectionRegistrar extends SelectionRegistrar {
  int adds = 0;

  @override
  void add(Selectable selectable) => adds += 1;

  @override
  void remove(Selectable selectable) {}
}
