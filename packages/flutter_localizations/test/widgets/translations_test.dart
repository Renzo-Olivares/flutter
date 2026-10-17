// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final String language in kWidgetsSupportedLanguages) {
    testWidgets('translations exist for $language', (WidgetTester tester) async {
      final locale = Locale(language);

      expect(GlobalWidgetsLocalizations.delegate.isSupported(locale), isTrue);

      final WidgetsLocalizations localizations = await GlobalWidgetsLocalizations.delegate.load(
        locale,
      );

      expect(localizations.reorderItemDown, isNotNull);
      expect(localizations.reorderItemLeft, isNotNull);
      expect(localizations.reorderItemRight, isNotNull);
      expect(localizations.reorderItemToEnd, isNotNull);
      expect(localizations.reorderItemToStart, isNotNull);
      expect(localizations.reorderItemUp, isNotNull);
      expect(localizations.selectedTextAnnouncement('x'), contains('x'));
      expect(localizations.unselectedTextAnnouncement('x'), contains('x'));
      expect(localizations.selectionClearedAnnouncement, isNotEmpty);
      expect(localizations.selectedCharacterCountAnnouncement(1), isNotEmpty);
      // Every plural form, including untranslated placeholders, carries the
      // count: the language's own rules decide which form 300 takes.
      expect(localizations.selectedCharacterCountAnnouncement(300), contains('300'));
      expect(localizations.allTextSelectedAnnouncement, isNotEmpty);
      expect(
        localizations.selectionReplacedAnnouncement('a', 'b'),
        allOf(contains('a'), contains('b')),
      );
      expect(localizations.spaceCharacterName, isNotEmpty);
      expect(localizations.newLineCharacterName, isNotEmpty);
      expect(localizations.tabCharacterName, isNotEmpty);
    });
  }

  testWidgets('selection announcements substitute and pluralize', (WidgetTester tester) async {
    final WidgetsLocalizations en = await GlobalWidgetsLocalizations.delegate.load(
      const Locale('en'),
    );
    expect(en.selectedTextAnnouncement('Hello'), 'Hello selected');
    expect(en.unselectedTextAnnouncement('Hello'), 'Hello unselected');
    expect(en.selectionReplacedAnnouncement('old', 'new'), 'old unselected, new selected');
    expect(en.selectedCharacterCountAnnouncement(1), '1 character selected');
    expect(en.selectedCharacterCountAnnouncement(2), '2 characters selected');
    expect(en.selectedCharacterCountAnnouncement(1000), '1000 characters selected');
    // A `$` in the text is not treated as a placeholder.
    expect(en.selectedTextAnnouncement(r'$text'), r'$text selected');

    // A language whose plural rules have "few" and "many" falls back to the
    // "other" form where no such form is provided.
    final WidgetsLocalizations ru = await GlobalWidgetsLocalizations.delegate.load(
      const Locale('ru'),
    );
    expect(ru.selectedCharacterCountAnnouncement(5), contains('5'));
  });
}
