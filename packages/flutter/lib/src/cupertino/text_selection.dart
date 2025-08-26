// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.


import 'package:flutter/widgets.dart';

import 'theme.dart';

/// iOS Cupertino styled text selection handle controls.
///
/// Specifically does not manage the toolbar, which is left to
/// [EditableText.contextMenuBuilder].
@Deprecated(
  'Use `CupertinoTextSelectionControls`. '
  'This feature was deprecated after v3.3.0-0.5.pre.',
)
class CupertinoTextSelectionHandleControls extends CupertinoTextSelectionControls
    with TextSelectionHandleControls {}

/// iOS Cupertino styled text selection controls.
///
/// The [cupertinoTextSelectionControls] global variable has a
/// suitable instance of this class.
class CupertinoTextSelectionControls extends AppleTextSelectionControls {
  /// Builder for iOS text selection edges.
  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    Color? color,
    double textLineHeight, [
    VoidCallback? onTap,
  ]) {
    final Color handleColor = color ?? CupertinoTheme.of(context).selectionHandleColor;
    return super.buildHandle(context, type, handleColor, textLineHeight, onTap);
  }
}

// TODO(justinmc): Deprecate this after TextSelectionControls.buildToolbar is
// deleted, when users should migrate back to cupertinoTextSelectionControls.
// See https://github.com/flutter/flutter/pull/124262
/// Text selection handle controls that follow iOS design conventions.
final TextSelectionControls cupertinoTextSelectionHandleControls =
    CupertinoTextSelectionHandleControls();

/// Text selection controls that follow iOS design conventions.
final TextSelectionControls cupertinoTextSelectionControls = CupertinoTextSelectionControls();
