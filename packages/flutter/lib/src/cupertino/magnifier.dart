// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// @docImport 'package:flutter/material.dart';
library;

import 'package:flutter/widgets.dart';

import 'theme.dart';

/// A [CupertinoMagnifier] used for magnifying text in cases where a user's
/// finger may be blocking the point of interest, like a selection handle.
///
/// {@tool dartpad}
/// This sample demonstrates how to use [CupertinoTextMagnifier].
///
/// ** See code in examples/api/lib/widgets/magnifier/cupertino_text_magnifier.0.dart **
/// {@end-tool}
///
/// Delegates styling to [CupertinoMagnifier] with its position depending on
/// [magnifierInfo].
///
/// Specifically, the [CupertinoTextMagnifier] follows the following rules.
/// [CupertinoTextMagnifier]:
/// - is positioned horizontally inside the screen width, with [horizontalScreenEdgePadding] padding.
/// - is hidden if a gesture is detected [hideBelowThreshold] units below the line
///   that the magnifier is on, shown otherwise.
/// - follows the x coordinate of the gesture directly (with respect to rule 1).
/// - has some vertical drag resistance; i.e. if a gesture is detected k units below the field,
///   then has vertical offset [dragResistance] * k.
class CupertinoTextMagnifier extends StatelessWidget {
  /// Constructs a [RawMagnifier] in the Cupertino style, positioning with respect to
  /// [magnifierInfo].
  ///
  /// The default constructor parameters and constants were eyeballed on
  /// an iPhone XR iOS v15.5.
  const CupertinoTextMagnifier({
    super.key,
    this.animationCurve = Curves.easeOut,
    required this.controller,
    this.dragResistance = 10.0,
    this.hideBelowThreshold = 48.0,
    this.horizontalScreenEdgePadding = 10.0,
    required this.magnifierInfo,
  });

  /// The curve used for the in / out animations.
  final Curve animationCurve;

  /// This magnifier's controller.
  ///
  /// The [CupertinoTextMagnifier] requires a [MagnifierController]
  /// in order to show / hide itself without removing itself from the
  /// overlay.
  final MagnifierController controller;

  /// A drag resistance on the downward Y position of the lens.
  final double dragResistance;

  /// The difference in Y between the gesture position and the caret center
  /// so that the magnifier hides itself.
  final double hideBelowThreshold;

  /// The padding on either edge of the screen that any part of the magnifier
  /// cannot exist past.
  ///
  /// This includes any part of the magnifier, not just the center; for example,
  /// the left edge of the magnifier cannot be outside the [horizontalScreenEdgePadding].v
  ///
  /// If the screen has width w, then the magnifier is bound to
  /// `_kHorizontalScreenEdgePadding, w - _kHorizontalScreenEdgePadding`.
  final double horizontalScreenEdgePadding;

  /// [CupertinoTextMagnifier] will determine its own positioning
  /// based on the [MagnifierInfo] of this notifier.
  final ValueNotifier<MagnifierInfo> magnifierInfo;

  @override
  Widget build(BuildContext context) {
    final CupertinoThemeData themeData = CupertinoTheme.of(context);
    return AppleTextMagnifier(
      animationCurve: animationCurve,
      controller: controller,
      dragResistance: dragResistance,
      hideBelowThreshold: hideBelowThreshold,
      horizontalScreenEdgePadding: horizontalScreenEdgePadding,
      border: BorderSide(color: themeData.primaryColor, width: 2.0),
      magnifierInfo: magnifierInfo,
    );
  }
}

/// A [RawMagnifier] used for magnifying text in cases where a user's
/// finger may be blocking the point of interest, like a selection handle.
///
/// {@tool dartpad}
/// This sample demonstrates how to use [CupertinoMagnifier].
///
/// ** See code in examples/api/lib/widgets/magnifier/cupertino_magnifier.0.dart **
/// {@end-tool}
///
/// [CupertinoMagnifier] is a wrapper around [RawMagnifier] that handles styling
/// and transitions.
///
/// {@macro flutter.widgets.magnifier.intro}
///
/// See also:
///
/// * [RawMagnifier], the backing implementation.
/// * [CupertinoTextMagnifier], a widget that positions [CupertinoMagnifier] based on
/// [MagnifierInfo].
/// * [MagnifierController], the controller for this magnifier.
class CupertinoMagnifier extends StatelessWidget {
  /// Creates a [RawMagnifier] in the Cupertino style.
  ///
  /// The default constructor parameters and constants were eyeballed on
  /// an iPhone 16 iOS v18.1.
  const CupertinoMagnifier({
    super.key,
    this.size = kDefaultSize,
    this.borderRadius = const BorderRadius.all(Radius.elliptical(60, 50)),
    this.additionalFocalPointOffset = Offset.zero,
    this.shadows = const <BoxShadow>[
      BoxShadow(
        color: Color.fromARGB(25, 0, 0, 0),
        blurRadius: 11,
        spreadRadius: 0.2,
        blurStyle: BlurStyle.outer,
      ),
    ],
    this.clipBehavior = Clip.none,
    this.borderSide = const BorderSide(color: Color.fromARGB(255, 0, 124, 255), width: 2.0),
    this.inOutAnimation,
    this.magnificationScale = 1.0,
  }) : assert(magnificationScale > 0, 'The magnification scale should be greater than zero.');

  /// A list of shadows cast by the [Magnifier].
  ///
  /// If the shadows use a [BlurStyle] that paints inside the shape, or if they
  /// are offset, then a [clipBehavior] that enables clipping (such as
  /// [Clip.hardEdge]) is recommended, otherwise the shadow will occlude the
  /// magnifier (the shadow is drawn above the magnifier so as to not be
  /// included in the magnified image).
  ///
  /// A shadow that uses [BlurStyle.outer] and is not offset does not need
  /// clipping.
  ///
  /// By default, the [shadows] are not offset and use [BlurStyle.outer], and
  /// correspondingly the default [clipBehavior] is [Clip.none].
  final List<BoxShadow> shadows;

  /// Whether and how to clip the [shadows] that render inside the loupe.
  ///
  /// Defaults to [Clip.none], which is useful if the shadow will not paint
  /// where the magnified image appears, or if doing so is intentional (e.g. to
  /// blur the edges of the magnified image).
  ///
  /// The default configuration of [CupertinoMagnifier] does not render inside
  /// the loupe (the shadows are not offset and use [BlurStyle.outer]).
  ///
  /// Other values (e.g. [Clip.hardEdge]) are recommended when the [shadows]
  /// have an offset.
  ///
  /// See the discussion at [shadows].
  final Clip clipBehavior;

  /// The border, or "rim", of this magnifier.
  ///
  /// This border is drawn on a [RoundedRectangleBorder] with radius
  /// [borderRadius], and increases the [size] of the magnifier by the
  /// [BorderSide.width].
  final BorderSide borderSide;

  /// The vertical offset that the magnifier is along the Y axis above
  /// the focal point.
  static const double kMagnifierAboveFocalPoint = AppleMagnifier.kMagnifierAboveFocalPoint;

  /// The default size of the magnifier.
  ///
  /// This is public so that positioners can choose to depend on it, although
  /// it is overridable.
  static const Size kDefaultSize = AppleMagnifier.kDefaultSize;

  /// The size of this magnifier.
  ///
  /// The size does not include the [borderSide] or [shadows].
  final Size size;

  /// The border radius of this magnifier.
  ///
  /// The magnifier's shape is a [RoundedRectangleBorder] with this radius.
  final BorderRadius borderRadius;

  /// This [RawMagnifier]'s controller.
  ///
  /// Since [CupertinoMagnifier] has no knowledge of shown / hidden state,
  /// this animation should be driven by an external actor.
  final Animation<double>? inOutAnimation;

  /// Any additional focal point offset, applied over the regular focal
  /// point offset defined in [kMagnifierAboveFocalPoint].
  final Offset additionalFocalPointOffset;

  /// The magnification scale for the magnifier.
  ///
  /// Defaults to 1.0, which indicates that the magnifier does not apply any magnification.
  final double magnificationScale;

  @override
  Widget build(BuildContext context) {
    return AppleMagnifier(
      shadows: shadows,
      clipBehavior: clipBehavior,
      borderSide: borderSide,
      size: size,
      borderRadius: borderRadius,
      inOutAnimation: inOutAnimation,
      additionalFocalPointOffset: additionalFocalPointOffset,
      magnificationScale: magnificationScale,
    );
  }
}
