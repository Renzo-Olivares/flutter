// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Evaluator-owned fixture. Copy only into a verification checkout, under
// packages/flutter/test/widgets/. Does not verify native presentation or UI wrappers.
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _HandleControls extends TextSelectionControls with TextSelectionHandleControls {
  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textLineHeight, [
    VoidCallback? onTap,
  ]) => const SizedBox.shrink();

  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) => Offset.zero;

  @override
  Size getHandleSize(double textLineHeight) => Size.zero;
}

const Map<ContextMenuButtonType, String> _methods = <ContextMenuButtonType, String>{
  ContextMenuButtonType.lookUp: 'LookUp.invoke',
  ContextMenuButtonType.searchWeb: 'SearchWeb.invoke',
  ContextMenuButtonType.share: 'Share.invoke',
};

Future<GlobalKey<SelectableRegionState>> _buildSelection(WidgetTester tester) async {
  final key = GlobalKey<SelectableRegionState>();
  final focusNode = FocusNode();
  addTearDown(focusNode.dispose);
  await tester.pumpWidget(
    WidgetsApp(
      color: const Color(0xFFFFFFFF),
      onGenerateRoute: (RouteSettings settings) => PageRouteBuilder<void>(
        settings: settings,
        pageBuilder: (_, _, _) => Align(
          alignment: Alignment.topLeft,
          child: SelectableRegion(
            key: key,
            focusNode: focusNode,
            selectionControls: _HandleControls(),
            contextMenuBuilder: (_, _) => const SizedBox.shrink(),
            child: const Text('Hello world', style: TextStyle(fontSize: 20)),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return key;
}

Future<void> _selectWord(WidgetTester tester, int offset, TextSelection expected) async {
  final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(find.byType(RichText));
  final Offset position = paragraph.localToGlobal(
    paragraph.getOffsetForCaret(TextPosition(offset: offset), Rect.zero) +
        Offset(2, paragraph.preferredLineHeight / 2),
  );
  await tester.longPressAt(position);
  await tester.pumpAndSettle();
  expect(paragraph.selections, <TextSelection>[
    expected,
  ], reason: 'Fixture must select the intended word.');
}

void main() {
  testWidgets(
    'requested_actions: iOS default items contain all three requested actions',
    (WidgetTester tester) async {
      final GlobalKey<SelectableRegionState> key = await _buildSelection(tester);
      await _selectWord(tester, 8, const TextSelection(baseOffset: 6, extentOffset: 11));
      expect(
        key.currentState!.contextMenuButtonItems.map((ContextMenuButtonItem item) => item.type),
        containsAll(_methods.keys),
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    skip: kIsWeb, // These cases concern non-web platform requests.
  );

  for (final platform in <TargetPlatform>[TargetPlatform.iOS, TargetPlatform.android]) {
    final Iterable<ContextMenuButtonType> types = platform == TargetPlatform.iOS
        ? _methods.keys
        : <ContextMenuButtonType>[ContextMenuButtonType.share];
    for (final type in types) {
      testWidgets(
        'actions_use_selected_text: ${platform.name} ${type.name} uses the current substring',
        (WidgetTester tester) async {
          final calls = <MethodCall>[];
          final TestDefaultBinaryMessenger messenger = tester.binding.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
            if (call.method == 'Clipboard.hasStrings') {
              return <String, bool>{'value': false};
            }
            if (_methods.values.contains(call.method)) {
              calls.add(call);
            }
            return null;
          });
          addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
          final GlobalKey<SelectableRegionState> key = await _buildSelection(tester);
          // Recreate the selection/menu after invoking each action. This also checks
          // stale content without invoking callbacks from a dismissed old menu.
          for (final (int offset, TextSelection selection, String text)
              in <(int, TextSelection, String)>[
                (8, const TextSelection(baseOffset: 6, extentOffset: 11), 'world'),
                (2, const TextSelection(baseOffset: 0, extentOffset: 5), 'Hello'),
              ]) {
            await _selectWord(tester, offset, selection);
            final List<ContextMenuButtonItem> items = key.currentState!.contextMenuButtonItems
                .where((ContextMenuButtonItem item) => item.type == type)
                .toList();
            expect(items, hasLength(1), reason: 'Requested action must be available.');
            expect(items.single.onPressed, isNotNull);
            calls.clear();
            items.single.onPressed!();
            await tester.pump();
            expect(calls, hasLength(1), reason: 'One action must send exactly one action request.');
            expect(calls.single.method, _methods[type]);
            final Object? arguments = calls.single.arguments;
            // Share may add an anchor through a structured request. The evaluator
            // must separately verify that its fields match the native implementation.
            final Object? selectedText = type == ContextMenuButtonType.share && arguments is Map
                ? arguments['text']
                : arguments;
            expect(selectedText, text);
          }
        },
        variant: TargetPlatformVariant.only(platform),
        skip: kIsWeb,
      );
    }
  }
}
