// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'apple_button.dart';

// Extracted from lib/src/cupertino/constants.dart

/// Standard iOS 17 button minimum interactive dimension.
const double kMinInteractiveDimensionApple = 44.0;

/// Values for focus color.
///
/// These values were eyeballed from a screenshot of a focused Cupertino button
/// in a macOS app.
const double kAppleFocusColorOpacity = 0.80,
      kAppleFocusColorBrightness = 0.69,
      kAppleFocusColorSaturation = 0.835;

/// Opacity of a tinted Apple button, in light and dark modes.
const double kAppleButtonTintedOpacityLight = 0.12, kAppleButtonTintedOpacityDark = 0.26;

/// The default icon size for a [AppleButton].
const double kAppleButtonDefaultIconSize = 20.0;

/// The padding of a [AppleButton].
const Map<AppleButtonSize, EdgeInsetsGeometry> kAppleButtonPadding =
  <AppleButtonSize, EdgeInsetsGeometry>{
    AppleButtonSize.small: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    AppleButtonSize.medium: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    AppleButtonSize.large: EdgeInsets.symmetric(horizontal: 22, vertical: 14),
  };

/// The border radius of a [AppleButton].
final Map<AppleButtonSize, BorderRadius> kAppleButtonSizeBorderRadius =
  <AppleButtonSize, BorderRadius>{
    AppleButtonSize.small: BorderRadius.circular(20),
    AppleButtonSize.medium: BorderRadius.circular(20),
    AppleButtonSize.large: BorderRadius.circular(12),
  };

/// The minimum size of a [AppleButton].
const Map<AppleButtonSize, double> kAppleButtonMinSize = <AppleButtonSize, double>{
  AppleButtonSize.small: 32.0,
  AppleButtonSize.medium: 40.0,
  AppleButtonSize.large: 50.0,
};

/// The distance a button needs to be moved after being pressed for its opacity to change.
///
/// The opacity changes when the position moved is this distance away from the button.
const double kAppleButtonTapMoveSlop = 70.0;

// Please update _TextThemeDefaultsBuilder accordingly after changing the default
// color here, as their implementation depends on the default value of the color
// field.
//
// Values derived from https://developer.apple.com/design/resources/.
// See [iOS 17 + iPadOS 17 UI Kit](https://www.figma.com/community/file/1248375255495415511) for details.
const TextStyle kDefaultActionSmallTextStyle = TextStyle(
  inherit: false,
  fontFamily: 'CupertinoSystemText',
  fontSize: 15.0,
  letterSpacing: -0.23,
  color: CupertinoColors.activeBlue,
  decoration: TextDecoration.none,
);

// Please update _TextThemeDefaultsBuilder accordingly after changing the default
// color here, as their implementation depends on the default value of the color
// field.
//
// Values derived from https://developer.apple.com/design/resources/.
// See [iOS 17 + iPadOS 17 UI Kit](https://www.figma.com/community/file/1248375255495415511) for details.
const TextStyle kDefaultActionTextStyle = TextStyle(
  inherit: false,
  fontFamily: 'CupertinoSystemText',
  fontSize: 17.0,
  letterSpacing: -0.41,
  color: CupertinoColors.activeBlue,
  decoration: TextDecoration.none,
);

// Extracted from lib/src/cupertino/colors.dart
/// A collection of color constants mimicking those in Cupertino.
final class CupertinoColors {
  /// The blue color used for active elements in the light theme.
  static const Color activeBlue = Color(0xFF007AFF);

  /// A light grey color.
  static const Color systemGrey = Color(0xFF8E8E93);

  /// A grey color for tertiary labels.
  static const Color tertiaryLabel = Color(0x4D3C3C43);

  /// A grey color for tertiary system fill.
  static const Color tertiarySystemFill = Color(0x1F767680);

  /// A grey color for quaternary system fill.
  static const Color quaternarySystemFill = Color(0x1A787880);

  /// Opaque black.
  static const Color black = Color(0xFF000000);

  /// Opaque white.
  static const Color white = Color(0xFFFFFFFF);

  static const Color systemBlue = Color.fromARGB(255, 0, 122, 255);// TODO(Renzo-Olivares): Should be CupertinoDynamicColor.
  static const Color systemBackground = Color.fromARGB(255, 255, 255, 255);// TODO(Renzo-Olivares): Should be CupertinoDynamicColor.
}

