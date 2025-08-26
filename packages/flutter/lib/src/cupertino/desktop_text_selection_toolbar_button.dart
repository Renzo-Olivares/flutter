// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'theme.dart';

// These values were measured from a screenshot of the native context menu on
// macOS 13.2 on a Macbook Pro.
const TextStyle _kToolbarButtonFontStyle = TextStyle(
  inherit: false,
  fontSize: 14.0,
  letterSpacing: -0.15,
  fontWeight: FontWeight.w400,
);

/// A button in the style of the Mac context menu buttons.
class CupertinoDesktopTextSelectionToolbarButton extends StatefulWidget {
  /// Creates an instance of CupertinoDesktopTextSelectionToolbarButton.
  const CupertinoDesktopTextSelectionToolbarButton({
    super.key,
    required this.onPressed,
    required Widget this.child,
  }) : buttonItem = null,
       text = null;

  /// Create an instance of [CupertinoDesktopTextSelectionToolbarButton] whose child is
  /// a [Text] widget styled like the default Mac context menu button.
  const CupertinoDesktopTextSelectionToolbarButton.text({
    super.key,
    required this.onPressed,
    required this.text,
  }) : buttonItem = null,
       child = null;

  /// Create an instance of [CupertinoDesktopTextSelectionToolbarButton] from
  /// the given [ContextMenuButtonItem].
  CupertinoDesktopTextSelectionToolbarButton.buttonItem({
    super.key,
    required ContextMenuButtonItem this.buttonItem,
  }) : onPressed = buttonItem.onPressed,
       text = null,
       child = null;

  /// {@macro flutter.cupertino.CupertinoTextSelectionToolbarButton.onPressed}
  final VoidCallback? onPressed;

  /// {@macro flutter.cupertino.CupertinoTextSelectionToolbarButton.child}
  final Widget? child;

  /// {@macro flutter.cupertino.CupertinoTextSelectionToolbarButton.onPressed}
  final ContextMenuButtonItem? buttonItem;

  /// {@macro flutter.cupertino.CupertinoTextSelectionToolbarButton.text}
  final String? text;

  @override
  State<CupertinoDesktopTextSelectionToolbarButton> createState() =>
      _CupertinoDesktopTextSelectionToolbarButtonState();
}

class _CupertinoDesktopTextSelectionToolbarButtonState
    extends State<CupertinoDesktopTextSelectionToolbarButton> {
  @override
  Widget build(BuildContext context) {
    final WidgetStateProperty<Color?> color = WidgetStateProperty<Color?>.fromMap(
      <WidgetStatesConstraint, Color?>{
        WidgetState.hovered: CupertinoTheme.of(context).primaryColor,
        WidgetState.any: null,
      },
    );

    if (widget.child != null) {
      return AppleDesktopTextSelectionToolbarButton(
        color: color,
        onPressed: widget.onPressed,
        child: widget.child!,
      );
    }

    final WidgetStateProperty<TextStyle> labelStyle =
        WidgetStateProperty<TextStyle>.fromMap(<WidgetStatesConstraint, TextStyle>{
          WidgetState.hovered: _kToolbarButtonFontStyle.copyWith(
            color: CupertinoTheme.of(context).primaryContrastingColor,
          ),
          WidgetState.any: _kToolbarButtonFontStyle.copyWith(
            color: const CupertinoDynamicColor.withBrightness(
              color: CupertinoColors.black,
              darkColor: CupertinoColors.white,
            ).resolveFrom(context),
          ),
        });

    if (widget.text != null) {
      return AppleDesktopTextSelectionToolbarButton.text(
        color: color,
        labelStyle: labelStyle,
        onPressed: widget.onPressed,
        text: widget.text,
      );
    }

    if (widget.buttonItem != null) {
      return AppleDesktopTextSelectionToolbarButton.buttonItem(
        color: color,
        labelStyle: labelStyle,
        buttonItem: widget.buttonItem!,
      );
    }
    assert(widget.child != null || widget.text != null || widget.buttonItem != null);
    return const SizedBox.shrink();
  }
}

