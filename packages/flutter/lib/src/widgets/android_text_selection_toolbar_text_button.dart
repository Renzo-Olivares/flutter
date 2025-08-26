// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// @docImport 'android_text_selection_toolbar.dart';
/// @docImport 'text.dart';
library;

import 'package:flutter/foundation.dart';

import 'basic.dart';
import 'color_scheme.dart';
import 'constants.dart';
import 'framework.dart';
import 'media_query.dart';
import 'text_button.dart';
import 'theme.dart';

enum _TextSelectionToolbarItemPosition {
  /// The first item among multiple in the menu.
  first,

  /// One of several items, not the first or last.
  middle,

  /// The last item among multiple in the menu.
  last,

  /// The only item in the menu.
  only,
}

/// A button styled like a Material native Android text selection menu button.
class AndroidTextSelectionToolbarTextButton extends StatelessWidget {
  /// Creates an instance of AndroidTextSelectionToolbarTextButton.
  const AndroidTextSelectionToolbarTextButton({
    super.key,
    required this.child,
    required this.padding,
    this.foregroundColor,
    this.onPressed,
    this.alignment,
  });

  // These values were eyeballed to match the native text selection menu on a
  // Pixel 2 running Android 10.
  static const double _kMiddlePadding = 9.5;
  static const double _kEndPadding = 14.5;

  final Color? foregroundColor;

  /// {@template flutter.material.AndroidTextSelectionToolbarTextButton.child}
  /// The child of this button.
  ///
  /// Usually a [Text].
  /// {@endtemplate}
  final Widget child;

  /// {@template flutter.material.AndroidTextSelectionToolbarTextButton.onPressed}
  /// Called when this button is pressed.
  /// {@endtemplate}
  final VoidCallback? onPressed;

  /// The padding between the button's edge and its child.
  ///
  /// In a standard Material [AndroidTextSelectionToolbar], the padding depends on the
  /// button's position within the toolbar.
  ///
  /// See also:
  ///
  ///  * [getPadding], which calculates the standard padding based on the
  ///    button's position.
  ///  * [ButtonStyle.padding], which is where this padding is applied.
  final EdgeInsetsGeometry padding;

  /// The alignment of the button's child.
  ///
  /// By default, this will be [Alignment.center].
  ///
  /// See also:
  ///
  ///  * [ButtonStyle.alignment], which is where this alignment is applied.
  final AlignmentGeometry? alignment;

  /// Returns the standard padding for a button at index out of a total number
  /// of buttons.
  ///
  /// Standard Material [AndroidTextSelectionToolbar]s have buttons with different
  /// padding depending on their position in the toolbar.
  static EdgeInsetsGeometry getPadding(int index, int total) {
    assert(total > 0 && index >= 0 && index < total);
    final _TextSelectionToolbarItemPosition position = _getPosition(index, total);
    return EdgeInsetsDirectional.only(
      start: _getStartPadding(position),
      end: _getEndPadding(position),
    );
  }

  static double _getStartPadding(_TextSelectionToolbarItemPosition position) {
    if (position == _TextSelectionToolbarItemPosition.first ||
        position == _TextSelectionToolbarItemPosition.only) {
      return _kEndPadding;
    }
    return _kMiddlePadding;
  }

  static double _getEndPadding(_TextSelectionToolbarItemPosition position) {
    if (position == _TextSelectionToolbarItemPosition.last ||
        position == _TextSelectionToolbarItemPosition.only) {
      return _kEndPadding;
    }
    return _kMiddlePadding;
  }

  static _TextSelectionToolbarItemPosition _getPosition(int index, int total) {
    if (index == 0) {
      return total == 1
          ? _TextSelectionToolbarItemPosition.only
          : _TextSelectionToolbarItemPosition.first;
    }
    if (index == total - 1) {
      return _TextSelectionToolbarItemPosition.last;
    }
    return _TextSelectionToolbarItemPosition.middle;
  }

  /// Returns a copy of the current [AndroidTextSelectionToolbarTextButton] instance
  /// with specific overrides.
  AndroidTextSelectionToolbarTextButton copyWith({
    Widget? child,
    VoidCallback? onPressed,
    EdgeInsetsGeometry? padding,
    AlignmentGeometry? alignment,
  }) {
    return AndroidTextSelectionToolbarTextButton(
      onPressed: onPressed ?? this.onPressed,
      padding: padding ?? this.padding,
      alignment: alignment ?? this.alignment,
      child: child ?? this.child,
    );
  }

  // These colors were taken from a screenshot of a Pixel 6 emulator running
  // Android API level 34.
  static const Color _defaultForegroundColorLight = Color(0xff000000);
  static const Color _defaultForegroundColorDark = Color(0xffffffff);

  // The background color is hardcoded to transparent by default so the buttons
  // are the color of the container behind them. For example TextSelectionToolbar
  // hardcodes the color value, and AndroidTextSelectionToolbarTextButtons that are its
  // children become that color.
  static const Color _defaultBackgroundColorTransparent = Color(0x00000000);

  static Color _getForegroundColor(Brightness brightness) {
    return switch (brightness) {
      Brightness.light => _defaultForegroundColorLight,
      Brightness.dark => _defaultForegroundColorDark,
    };
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light;
    return TextButton(
      style: TextButton.styleFrom(
        backgroundColor: _defaultBackgroundColorTransparent,
        foregroundColor: foregroundColor ?? _getForegroundColor(brightness),
        shape: const RoundedRectangleBorder(),
        minimumSize: const Size(kMinInteractiveDimension, kMinInteractiveDimension),
        padding: padding,
        alignment: alignment,
        textStyle: const TextStyle(
          // This value was eyeballed from a screenshot of a Pixel 6 emulator
          // running Android API level 34.
          fontWeight: FontWeight.w400,
        ),
      ),
      onPressed: onPressed,
      child: child,
    );
  }
}
