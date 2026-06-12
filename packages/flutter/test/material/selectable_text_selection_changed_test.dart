// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SelectableText onSelectionChanged is called with correct offsets', (WidgetTester tester) async {
    TextSelection? receivedSelection;
    SelectionChangedCause? receivedCause;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SelectableText(
              'Hello World',
              onSelectionChanged: (TextSelection selection, SelectionChangedCause? cause) {
                receivedSelection = selection;
                receivedCause = cause;
              },
            ),
          ),
        ),
      ),
    );

    // Focus the SelectableText first
    await tester.tap(find.byType(SelectableText));
    await tester.pump();

    // Trigger Select All using Intent
    final BuildContext context = tester.element(find.byType(Text));
    Actions.invoke(context, const SelectAllTextIntent(SelectionChangedCause.keyboard));
    await tester.pump();

    // Verify that onSelectionChanged was called with correct offsets
    expect(receivedSelection, isNotNull);
    expect(receivedSelection!.baseOffset, 0);
    expect(receivedSelection!.extentOffset, 11); // "Hello World" length is 11
    expect(receivedCause, isNull); // Cause is expected to be null in this implementation
  });
}
