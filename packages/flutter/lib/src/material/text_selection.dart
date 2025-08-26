// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.


import 'package:flutter/widgets.dart';

import 'text_selection_theme.dart';
import 'theme.dart';

/// Android Material styled text selection handle controls.
///
/// Specifically does not manage the toolbar, which is left to
/// [EditableText.contextMenuBuilder].
@Deprecated(
  'Use `MaterialTextSelectionControls`. '
  'This feature was deprecated after v3.3.0-0.5.pre.',
)
class MaterialTextSelectionHandleControls extends MaterialTextSelectionControls
    with TextSelectionHandleControls {}

/// Android Material styled text selection controls.
///
/// The [materialTextSelectionControls] global variable has a
/// suitable instance of this class.
class MaterialTextSelectionControls extends AndroidTextSelectionControls {
  /// Builder for material-style text selection handles.
  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    Color? color,
    double textHeight, [
    VoidCallback? onTap,
  ]) {
    final ThemeData theme = Theme.of(context);
    final Color handleColor =
        color ?? TextSelectionTheme.of(context).selectionHandleColor ?? theme.colorScheme.primary;
    return super.buildHandle(context, type, handleColor, textHeight);
  }
}

// TODO(justinmc): Deprecate this after TextSelectionControls.buildToolbar is
// deleted, when users should migrate back to materialTextSelectionControls.
// See https://github.com/flutter/flutter/pull/124262
/// Text selection handle controls that follow the Material Design specification.
final TextSelectionControls materialTextSelectionHandleControls =
    MaterialTextSelectionHandleControls();

/// Text selection controls that follow the Material Design specification.
final TextSelectionControls materialTextSelectionControls = MaterialTextSelectionControls();
