// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// @docImport 'adaptive_text_selection_toolbar.dart';
/// @docImport 'desktop_text_selection_toolbar_button.dart';
library;

import 'package:flutter/widgets.dart';

import 'text_selection_toolbar.dart';

/// A Material-style desktop text selection toolbar.
///
/// Typically displays buttons for text manipulation, e.g. copying and pasting
/// text.
///
/// Tries to position its top left corner as closely as possible to [anchor]
/// while remaining fully inside the viewport.
///
/// See also:
///
///  * [AdaptiveTextSelectionToolbar], which builds the toolbar for the current
///    platform.
///  * [TextSelectionToolbar], which is similar, but builds an Android-style
///    toolbar.
class DesktopTextSelectionToolbar extends StatelessWidget {
  /// Creates a const instance of DesktopTextSelectionToolbar.
  const DesktopTextSelectionToolbar({super.key, required this.anchor, required this.children})
    : assert(children.length > 0);

  /// {@template flutter.material.DesktopTextSelectionToolbar.anchor}
  /// The point where the toolbar will attempt to position itself as closely as
  /// possible.
  /// {@endtemplate}
  final Offset anchor;

  /// {@macro flutter.material.TextSelectionToolbar.children}
  ///
  /// See also:
  ///   * [DesktopTextSelectionToolbarButton], which builds a default
  ///     Material-style desktop text selection toolbar text button.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMediaQuery(context));
    return AndroidDesktopTextSelectionToolbar(anchor: anchor, children: children);
  }
}
