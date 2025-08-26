// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

/// MacOS Cupertino styled text selection handle controls.
///
/// Specifically does not manage the toolbar, which is left to
/// [EditableText.contextMenuBuilder].
class _CupertinoDesktopTextSelectionHandleControls extends CupertinoDesktopTextSelectionControls
    with TextSelectionHandleControls {}

/// Desktop Cupertino styled text selection controls.
///
/// The [cupertinoDesktopTextSelectionControls] global variable has a
/// suitable instance of this class.
class CupertinoDesktopTextSelectionControls extends AppleDesktopTextSelectionControls {
}

// TODO(justinmc): Deprecate this after TextSelectionControls.buildToolbar is
// deleted, when users should migrate back to
// cupertinoDesktopTextSelectionControls.
// See https://github.com/flutter/flutter/pull/124262
/// Text selection handle controls that follow MacOS design conventions.
final TextSelectionControls cupertinoDesktopTextSelectionHandleControls =
    _CupertinoDesktopTextSelectionHandleControls();

/// Text selection controls that follows MacOS design conventions.
final TextSelectionControls cupertinoDesktopTextSelectionControls =
    CupertinoDesktopTextSelectionControls();
