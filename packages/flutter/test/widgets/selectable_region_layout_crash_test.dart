import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SelectableRegion crash with Navigator', (WidgetTester tester) async {
    final FocusNode focusNode = FocusNode();
    
    await tester.pumpWidget(
      MaterialApp(
        home: SelectableRegion(
          focusNode: focusNode,
          selectionControls: materialTextSelectionControls,
          child: Navigator(
            pages: [
              MaterialPage(child: Scaffold(body: Text('background'))),
              MaterialPage(child: Scaffold(body: Text('foreground'))),
            ],
            onDidRemovePage: (page) {
              print('onDidRemovePage: $page');
            },
          ),
        ),
      ),
    );

    // Initial pump
    await tester.pumpAndSettle();

    // Trigger something that might cause the crash? 
    // The user said "using the code sample below" causes it.
    // Usually invalidating layout or selection might trigger it.
    // Trying to select something?
    
    // Maybe removing a page? But the Navigator has static pages here.
    // If I just run it, maybe it crashes on first frame if both are considered "selectable" but one is not laid out?
    // But Navigator (Overlay) uses Offstage for the background page if it's opaque?
    // MaterialPage is opaque by default.
    // So 'background' is offstage.
    // SelectableRegion tries to find all selectables.
    // If 'background' is offstage, it might still register itself?
    
    // Let's try to simulate what happens during updates.
  });
}
