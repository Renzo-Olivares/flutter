// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

/// Desktop Material styled text selection handle controls.
///
/// Specifically does not manage the toolbar, which is left to
/// [EditableText.contextMenuBuilder].
class _DesktopTextSelectionHandleControls extends DesktopTextSelectionControls
    with TextSelectionHandleControls {}

/// Desktop Material styled text selection controls.
///
/// The [desktopTextSelectionControls] global variable has a
/// suitable instance of this class.
class DesktopTextSelectionControls extends AndroidDesktopTextSelectionControls {
}

// TODO(justinmc): Deprecate this after TextSelectionControls.buildToolbar is
// deleted, when users should migrate back to desktopTextSelectionControls.
// See https://github.com/flutter/flutter/pull/124262
/// Desktop text selection handle controls that loosely follow Material design
/// conventions.
final TextSelectionControls desktopTextSelectionHandleControls =
    _DesktopTextSelectionHandleControls();

/// Desktop text selection controls that loosely follow Material design
/// conventions.
final TextSelectionControls desktopTextSelectionControls = DesktopTextSelectionControls();
