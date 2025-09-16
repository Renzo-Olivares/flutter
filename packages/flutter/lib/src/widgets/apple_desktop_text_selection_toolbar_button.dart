// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:flutter/gestures.dart';

import 'apple_button.dart';
import 'apple_constants.dart';
import 'apple_text_selection_toolbar_button.dart';
import 'basic.dart';
import 'context_menu_button_item.dart';
import 'framework.dart';
import 'media_query.dart';
import 'text.dart';
import 'widget_state.dart';

// These values were measured from a screenshot of the native context menu on
// macOS 13.2 on a Macbook Pro.
const TextStyle _kToolbarButtonFontStyle = TextStyle(
  inherit: false,
  fontSize: 14.0,
  letterSpacing: -0.15,
  fontWeight: FontWeight.w400,
);

// This value was measured from a screenshot of the native context menu on
// macOS 13.2 on a Macbook Pro.
const EdgeInsets _kToolbarButtonPadding = EdgeInsets.fromLTRB(8.0, 2.0, 8.0, 5.0);

/// A button in the style of the Mac context menu buttons.
class AppleDesktopTextSelectionToolbarButton extends StatefulWidget {
  /// Creates an instance of CupertinoDesktopTextSelectionToolbarButton.
  const AppleDesktopTextSelectionToolbarButton({
    super.key,
    this.color,
    required this.onPressed,
    required Widget this.child,
  }) : buttonItem = null,
       text = null,
       labelStyle = null;

  /// Create an instance of [AppleDesktopTextSelectionToolbarButton] whose child is
  /// a [Text] widget styled like the default Mac context menu button.
  const AppleDesktopTextSelectionToolbarButton.text({
    super.key,
    this.color,
    this.labelStyle,
    required this.onPressed,
    required this.text,
  }) : buttonItem = null,
       child = null;

  /// Create an instance of [AppleDesktopTextSelectionToolbarButton] from
  /// the given [ContextMenuButtonItem].
  AppleDesktopTextSelectionToolbarButton.buttonItem({
    super.key,
    this.color,
    this.labelStyle,
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

  final WidgetStateProperty<Color?>? color;

  final WidgetStateProperty<TextStyle>? labelStyle;

  @override
  State<AppleDesktopTextSelectionToolbarButton> createState() =>
      _AppleDesktopTextSelectionToolbarButtonState();
}

class _AppleDesktopTextSelectionToolbarButtonState
    extends State<AppleDesktopTextSelectionToolbarButton> {
  late Set<WidgetState> _states;

  @override
  void initState() {
    super.initState();
    _states = <WidgetState>{};
  }

  @override
  void dispose() {
    _states.clear();
    super.dispose();
  }

  void _onEnter(PointerEnterEvent event) {
    setState(() {
      _states.add(WidgetState.hovered);
    });
  }

  void _onExit(PointerExitEvent event) {
    setState(() {
      _states.remove(WidgetState.hovered);
    });
  }

  @override
  Widget build(BuildContext context) {
    const WidgetStateProperty<Color?> color = WidgetStateProperty<Color?>.fromMap(
      <WidgetStatesConstraint, Color?>{
        WidgetState.hovered: CupertinoColors
            .systemBlue, // TODO(Renzo-Olivares): was CupertinoTheme.of(context).primaryColor,
        WidgetState.any: null,
      },
    );
    final WidgetStateProperty<Color> labelColor = WidgetStateProperty<Color>.fromMap(
      <WidgetStatesConstraint, Color>{
        WidgetState.hovered: CupertinoColors
            .white, // TODO(Renzo-Olivares): was CupertinoTheme.of(context).primaryContrastingColor,
        WidgetState.any:
            (MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light) == Brightness.light
            ? CupertinoColors.black
            : CupertinoColors
                  .white, // TODO (Renzo-Olivares): was CupertinoDynamicColor.withBrightness
      },
    );
    final Widget child =
        widget.child ??
        Text(
          widget.text ??
              AppleTextSelectionToolbarButton.getButtonLabel(context, widget.buttonItem!),
          overflow: TextOverflow.ellipsis,
          style:
              widget.labelStyle?.resolve(_states) ??
              _kToolbarButtonFontStyle.copyWith(color: labelColor.resolve(_states)),
        );

    return SizedBox(
      width: double.infinity,
      child: MouseRegion(
        onEnter: _onEnter,
        onExit: _onExit,
        child: AppleButton(
          alignment: Alignment.centerLeft,
          borderRadius: const BorderRadius.all(Radius.circular(4.0)),
          color: widget.color?.resolve(_states) ?? color.resolve(_states),
          minSize: 0.0,
          onPressed: widget.onPressed,
          padding: _kToolbarButtonPadding,
          pressedOpacity: 0.7,
          child: child,
        ),
      ),
    );
  }
}
