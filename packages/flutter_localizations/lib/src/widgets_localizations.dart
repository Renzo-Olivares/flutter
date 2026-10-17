// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// @docImport 'package:flutter/material.dart';
///
/// @docImport 'material_localizations.dart';
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' as intl;

import 'l10n/generated_widgets_localizations.dart';

/// Localized values for widgets.
///
/// ## Supported languages
///
/// This class supports locales with the following [Locale.languageCode]s:
///
/// {@macro flutter.localizations.widgets.languages}
///
/// This list is available programmatically via [kWidgetsSupportedLanguages].
///
/// Besides localized strings, this class also maps [Locale] to [textDirection].
/// All locales are [TextDirection.ltr] except for locales with the following
/// [Locale.languageCode] values, which are [TextDirection.rtl]:
///
///   * ar - Arabic
///   * fa - Farsi
///   * he - Hebrew
///   * ps - Pashto
///   * sd - Sindhi
///   * ur - Urdu
///
abstract class GlobalWidgetsLocalizations implements WidgetsLocalizations {
  /// Construct an object that defines the localized values for the widgets
  /// library for the given [textDirection].
  ///
  /// The `localeName` selects the plural rules of
  /// [selectedCharacterCountAnnouncement] (see [intl.Intl.pluralLogic]); the
  /// generated subclasses pass their own locale and it defaults to English.
  const GlobalWidgetsLocalizations(this.textDirection, {this._localeName = 'en'});

  @override
  final TextDirection textDirection;

  final String _localeName;

  /// The raw version of [selectedTextAnnouncement], with `$text` verbatim in
  /// the string.
  @protected
  String get selectedTextAnnouncementRaw;

  @override
  String selectedTextAnnouncement(String text) {
    return selectedTextAnnouncementRaw.replaceFirst(r'$text', text);
  }

  /// The raw version of [unselectedTextAnnouncement], with `$text` verbatim
  /// in the string.
  @protected
  String get unselectedTextAnnouncementRaw;

  @override
  String unselectedTextAnnouncement(String text) {
    return unselectedTextAnnouncementRaw.replaceFirst(r'$text', text);
  }

  /// The raw version of [selectionReplacedAnnouncement], with `$unselected`
  /// and `$selected` verbatim in the string.
  @protected
  String get selectionReplacedAnnouncementRaw;

  static final RegExp _selectionReplacedPlaceholders = RegExp(r'\$(unselected|selected)');

  @override
  String selectionReplacedAnnouncement(String unselected, String selected) {
    // One pass, so that a placeholder-like substring in the user's text is
    // never substituted.
    return selectionReplacedAnnouncementRaw.replaceAllMapped(
      _selectionReplacedPlaceholders,
      (Match match) => match[1] == 'unselected' ? unselected : selected,
    );
  }

  /// The "zero" form of [selectedCharacterCountAnnouncement].
  ///
  /// This form is optional.
  ///
  /// See also:
  ///
  ///  * [intl.Intl.plural], to which this form is passed.
  ///  * [selectedCharacterCountAnnouncementOther], the "other" form
  @protected
  String? get selectedCharacterCountAnnouncementZero => null;

  /// The "one" form of [selectedCharacterCountAnnouncement].
  ///
  /// This form is optional.
  @protected
  String? get selectedCharacterCountAnnouncementOne => null;

  /// The "two" form of [selectedCharacterCountAnnouncement].
  ///
  /// This form is optional.
  @protected
  String? get selectedCharacterCountAnnouncementTwo => null;

  /// The "few" form of [selectedCharacterCountAnnouncement].
  ///
  /// This form is optional.
  @protected
  String? get selectedCharacterCountAnnouncementFew => null;

  /// The "many" form of [selectedCharacterCountAnnouncement].
  ///
  /// This form is optional.
  @protected
  String? get selectedCharacterCountAnnouncementMany => null;

  /// The "other" form of [selectedCharacterCountAnnouncement], with `$count`
  /// verbatim in the string.
  ///
  /// This form is required.
  @protected
  String get selectedCharacterCountAnnouncementOther;

  @override
  String selectedCharacterCountAnnouncement(int count) {
    return intl.Intl.pluralLogic(
      count,
      zero: selectedCharacterCountAnnouncementZero,
      one: selectedCharacterCountAnnouncementOne,
      two: selectedCharacterCountAnnouncementTwo,
      few: selectedCharacterCountAnnouncementFew,
      many: selectedCharacterCountAnnouncementMany,
      other: selectedCharacterCountAnnouncementOther,
      locale: _localeName,
    ).replaceFirst(r'$count', count.toString());
  }

  /// A [LocalizationsDelegate] for [WidgetsLocalizations].
  ///
  /// Most internationalized apps will use [GlobalMaterialLocalizations.delegates]
  /// as the value of [MaterialApp.localizationsDelegates] to include
  /// the localizations for both the material and widget libraries.
  static const LocalizationsDelegate<WidgetsLocalizations> delegate =
      _WidgetsLocalizationsDelegate();
}

class _WidgetsLocalizationsDelegate extends LocalizationsDelegate<WidgetsLocalizations> {
  const _WidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => kWidgetsSupportedLanguages.contains(locale.languageCode);

  static final Map<Locale, Future<WidgetsLocalizations>> _loadedTranslations =
      <Locale, Future<WidgetsLocalizations>>{};

  @override
  Future<WidgetsLocalizations> load(Locale locale) {
    assert(isSupported(locale));
    return _loadedTranslations.putIfAbsent(locale, () {
      return SynchronousFuture<WidgetsLocalizations>(getWidgetsTranslation(locale)!);
    });
  }

  @override
  bool shouldReload(_WidgetsLocalizationsDelegate old) => false;

  @override
  String toString() =>
      'GlobalWidgetsLocalizations.delegate(${kWidgetsSupportedLanguages.length} locales)';
}
