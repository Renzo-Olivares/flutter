// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// @docImport 'package:flutter/material.dart';
///
/// @docImport 'adaptive_text_selection_toolbar.dart';
/// @docImport 'desktop_text_selection_toolbar_button.dart';
library;

import 'package:flutter/widgets.dart';

/// A macOS-style text selection toolbar.
///
/// Typically displays buttons for text manipulation, e.g. copying and pasting
/// text.
///
/// Tries to position itself as closely as possible to [anchor] while remaining
/// fully inside the viewport.
///
/// See also:
///
///  * [CupertinoAdaptiveTextSelectionToolbar], where this is used to build the
///    toolbar for desktop platforms.
///  * [AdaptiveTextSelectionToolbar], where this is used to build the toolbar on
///    macOS.
///  * [DesktopTextSelectionToolbar], which is similar but builds a
///    Material-style desktop toolbar.
class CupertinoDesktopTextSelectionToolbar extends StatelessWidget {
  /// Creates a const instance of CupertinoTextSelectionToolbar.
  const CupertinoDesktopTextSelectionToolbar({
    super.key,
    required this.anchor,
    required this.children,
  }) : assert(children.length > 0);

  /// {@macro flutter.material.DesktopTextSelectionToolbar.anchor}
  final Offset anchor;

  /// {@macro flutter.material.TextSelectionToolbar.children}
  ///
  /// See also:
  ///   * [CupertinoDesktopTextSelectionToolbarButton], which builds a default
  ///     macOS-style text selection toolbar text button.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMediaQuery(context));
    return AppleDesktopTextSelectionToolbar(anchor: anchor, children: children);
  }
}
