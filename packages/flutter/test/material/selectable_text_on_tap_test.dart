// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SelectableText onTap is called when tapped', (WidgetTester tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SelectableText(
              'Tap me',
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      ),
    );

    // Tap the SelectableText
    await tester.tap(find.byType(SelectableText));
    await tester.pump();

    // Verify that the onTap callback was called
    expect(tapped, true);
  });
}
