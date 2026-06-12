// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Text widget behaves like forceLine: false (shrink-to-fit)', (WidgetTester tester) async {
    // The default test screen size is 800x600.
    // We place the Text widget inside a Center, which imposes loose constraints,
    // allowing the child to choose its own size up to 800x600.
    await tester.pumpWidget(
      const Center(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Text('Hello'),
        ),
      ),
    );

    final RenderBox renderBox = tester.renderObject(find.byType(RichText));

    // If Text behaved like forceLine: true, it would expand to fill the max width (800.0).
    // Since it behaves like forceLine: false, it should shrink to fit the text "Hello".
    expect(renderBox.size.width, lessThan(800.0));
    expect(renderBox.size.width, greaterThan(0.0));
    
    // Print the actual width for visibility in logs
    print('Actual Text width: ${renderBox.size.width}');
  });
}
