// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

/// A button in the style of the iOS text selection toolbar buttons.
class CupertinoTextSelectionToolbarButton extends StatelessWidget {
  /// Create an instance of [CupertinoTextSelectionToolbarButton].
  const CupertinoTextSelectionToolbarButton({super.key, this.onPressed, required this.child})
    : buttonItem = null,
      text = null;

  /// Create an instance of [CupertinoTextSelectionToolbarButton] whose child is
  /// a [Text] widget styled like the default iOS text selection toolbar button.
  const CupertinoTextSelectionToolbarButton.text({super.key, this.onPressed, required this.text})
    : buttonItem = null,
      child = null;

  /// Create an instance of [CupertinoTextSelectionToolbarButton] from the given
  /// [ContextMenuButtonItem].
  CupertinoTextSelectionToolbarButton.buttonItem({
    super.key,
    required ContextMenuButtonItem this.buttonItem,
  }) : child = null,
       text = null,
       onPressed = buttonItem.onPressed;

  /// {@template flutter.cupertino.CupertinoTextSelectionToolbarButton.child}
  /// The child of this button.
  ///
  /// Usually a [Text] or an [Icon].
  /// {@endtemplate}
  final Widget? child;

  /// {@template flutter.cupertino.CupertinoTextSelectionToolbarButton.onPressed}
  /// Called when this button is pressed.
  /// {@endtemplate}
  final VoidCallback? onPressed;

  /// {@template flutter.cupertino.CupertinoTextSelectionToolbarButton.onPressed}
  /// The buttonItem used to generate the button when using
  /// [CupertinoTextSelectionToolbarButton.buttonItem].
  /// {@endtemplate}
  final ContextMenuButtonItem? buttonItem;

  /// {@template flutter.cupertino.CupertinoTextSelectionToolbarButton.text}
  /// The text used in the button's label when using
  /// [CupertinoTextSelectionToolbarButton.text].
  /// {@endtemplate}
  final String? text;

  /// Returns the default button label String for the button of the given
  /// [ContextMenuButtonItem]'s [ContextMenuButtonType].
  static String getButtonLabel(BuildContext context, ContextMenuButtonItem buttonItem) {
    return AppleTextSelectionToolbarButton.getButtonLabel(context, buttonItem);
  }

  @override
  Widget build(BuildContext context) {
    if (child != null) {
      return AppleTextSelectionToolbarButton(onPressed: onPressed, child: child!);
    }
    if (text != null) {
      return AppleTextSelectionToolbarButton.text(onPressed: onPressed, text: text);
    }
    if (buttonItem != null) {
      return AppleTextSelectionToolbarButton.buttonItem(buttonItem: buttonItem!);
    }
    assert(child != null || text != null || buttonItem != null);
    return const SizedBox.shrink();
  }
}
