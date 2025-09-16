// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'android_constants.dart';
import 'android_text_button.dart';
import 'basic.dart';
// import 'colors.dart';
import 'constants.dart';
import 'framework.dart';
import 'media_query.dart';
import 'text.dart';
// import 'theme.dart';

const TextStyle _kToolbarButtonFontStyle = TextStyle(
  inherit: false,
  fontSize: 14.0,
  letterSpacing: -0.15,
  fontWeight: FontWeight.w400,
);

const EdgeInsets _kToolbarButtonPadding = EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 3.0);

/// A [TextButton] for the Material desktop text selection toolbar.
class AndroidDesktopTextSelectionToolbarButton extends StatelessWidget {
  /// Creates an instance of AndroidDesktopTextSelectionToolbarButton.
  const AndroidDesktopTextSelectionToolbarButton({
    super.key,
    this.foregroundColor,
    required this.onPressed,
    required this.child,
  });

  /// Create an instance of [AndroidDesktopTextSelectionToolbarButton] whose child is
  /// a [Text] widget in the style of the Material text selection toolbar.
  AndroidDesktopTextSelectionToolbarButton.text({
    super.key,
    this.foregroundColor,
    required BuildContext context,
    required this.onPressed,
    required String text,
  }) : child = Text(
         text,
         overflow: TextOverflow.ellipsis,
         style: _kToolbarButtonFontStyle.copyWith(
           color: MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark
               ? AndroidMaterialColors.white// From Material library.
               : AndroidMaterialColors.black87,// From Material library.
         ),
       );

  final Color? foregroundColor;

  /// {@macro flutter.material.TextSelectionToolbarTextButton.onPressed}
  final VoidCallback? onPressed;

  /// {@macro flutter.material.TextSelectionToolbarTextButton.child}
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // TODO(hansmuller): Should be colorScheme.onSurface
    final Color effectiveForegroundColor =
        foregroundColor ??
        (MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark
            ? AndroidMaterialColors.white
            : AndroidMaterialColors.black87);// Colors pulled from Material library.

    return SizedBox(
      width: double.infinity,
      child: TextButton(
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          enabledMouseCursor: SystemMouseCursors.basic,
          disabledMouseCursor: SystemMouseCursors.basic,
          foregroundColor: effectiveForegroundColor,
          shape: const RoundedRectangleBorder(),
          minimumSize: const Size(kMinInteractiveDimension, 36.0),
          padding: _kToolbarButtonPadding,
        ),
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}
