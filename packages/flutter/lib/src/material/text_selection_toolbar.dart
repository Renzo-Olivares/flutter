// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// @docImport 'adaptive_text_selection_toolbar.dart';
/// @docImport 'spell_check_suggestions_toolbar.dart';
/// @docImport 'text_selection_toolbar_text_button.dart';
library;

import 'package:flutter/cupertino.dart';

import 'color_scheme.dart';
import 'material.dart';
import 'theme.dart';

const double _kToolbarHeight = 44.0;

/// A fully-functional Material-style text selection toolbar.
///
/// Tries to position itself above [anchorAbove], but if it doesn't fit, then
/// it positions itself below [anchorBelow].
///
/// If any children don't fit in the menu, an overflow menu will automatically
/// be created.
///
/// See also:
///
///  * [AdaptiveTextSelectionToolbar], which builds the toolbar for the current
///    platform.
///  * [CupertinoTextSelectionToolbar], which is similar, but builds an iOS-
///    style toolbar.
class TextSelectionToolbar extends StatelessWidget {
  /// Creates an instance of TextSelectionToolbar.
  const TextSelectionToolbar({
    super.key,
    required this.anchorAbove,
    required this.anchorBelow,
    this.toolbarBuilder = _defaultToolbarBuilder,
    required this.children,
  }) : assert(children.length > 0);

  /// {@template flutter.material.TextSelectionToolbar.anchorAbove}
  /// The focal point above which the toolbar attempts to position itself.
  ///
  /// If there is not enough room above before reaching the top of the screen,
  /// then the toolbar will position itself below [anchorBelow].
  /// {@endtemplate}
  final Offset anchorAbove;

  /// {@template flutter.material.TextSelectionToolbar.anchorBelow}
  /// The focal point below which the toolbar attempts to position itself, if it
  /// doesn't fit above [anchorAbove].
  /// {@endtemplate}
  final Offset anchorBelow;

  /// {@template flutter.material.TextSelectionToolbar.children}
  /// The children that will be displayed in the text selection toolbar.
  ///
  /// Typically these are buttons.
  ///
  /// Must not be empty.
  /// {@endtemplate}
  ///
  /// See also:
  ///   * [TextSelectionToolbarTextButton], which builds a default Material-
  ///     style text selection toolbar text button.
  final List<Widget> children;

  /// {@template flutter.material.TextSelectionToolbar.toolbarBuilder}
  /// Builds the toolbar container.
  ///
  /// Useful for customizing the high-level background of the toolbar. The given
  /// child Widget will contain all of the [children].
  /// {@endtemplate}
  final ToolbarBuilder toolbarBuilder;

  /// The size of the text selection handles.
  ///
  /// See also:
  ///
  ///  * [SpellCheckSuggestionsToolbar], which references this value to calculate
  ///    the padding between the toolbar and anchor.
  static const double kHandleSize = 22.0;

  /// Padding between the toolbar and the anchor.
  static const double kToolbarContentDistanceBelow = kHandleSize - 2.0;

  // Build the default Android Material text selection menu toolbar.
  static Widget _defaultToolbarBuilder(BuildContext context, Widget child) {
    return _TextSelectionToolbarContainer(child: child);
  }

  @override
  Widget build(BuildContext context) {
    return AndroidTextSelectionToolbar(
      anchorAbove: anchorAbove,
      anchorBelow: anchorBelow,
      toolbarBuilder: toolbarBuilder,
      children: children,
    );
  }
}

// The Material-styled toolbar outline. Fill it with any widgets you want. No
// overflow ability.
class _TextSelectionToolbarContainer extends StatelessWidget {
  const _TextSelectionToolbarContainer({required this.child});

  final Widget child;

  // These colors were taken from a screenshot of a Pixel 6 emulator running
  // Android API level 34.
  static const Color _defaultColorLight = Color(0xffffffff);
  static const Color _defaultColorDark = Color(0xff424242);

  static Color _getColor(ColorScheme colorScheme) {
    final bool isDefaultSurface = switch (colorScheme.brightness) {
      Brightness.light => identical(ThemeData().colorScheme.surface, colorScheme.surface),
      Brightness.dark => identical(ThemeData.dark().colorScheme.surface, colorScheme.surface),
    };
    if (!isDefaultSurface) {
      return colorScheme.surface;
    }
    return switch (colorScheme.brightness) {
      Brightness.light => _defaultColorLight,
      Brightness.dark => _defaultColorDark,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      // This value was eyeballed to match the native text selection menu on
      // a Pixel 6 emulator running Android API level 34.
      borderRadius: const BorderRadius.all(Radius.circular(_kToolbarHeight / 2)),
      clipBehavior: Clip.antiAlias,
      color: _getColor(theme.colorScheme),
      elevation: 1.0,
      type: MaterialType.card,
      child: child,
    );
  }
}
