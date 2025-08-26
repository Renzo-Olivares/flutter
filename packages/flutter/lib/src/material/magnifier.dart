// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

/// A [Magnifier] positioned by rules dictated by the native Android magnifier.
///
/// The positioning rules are based on [magnifierInfo], as follows:
///
/// - The loupe tracks the gesture's _x_ coordinate, clamping to the beginning
///   and end of the currently editing line.
///
/// - The focal point never contains anything out of the bounds of the text
///   field or other widget being magnified (the [MagnifierInfo.fieldBounds]).
///
/// - The focal point always remains aligned with the _y_ coordinate of the touch.
///
/// - The loupe always remains on the screen.
///
/// - When the line targeted by the touch's _y_ coordinate changes, the position
///   is animated over [jumpBetweenLinesAnimationDuration].
///
/// This behavior was based on the Android 12 source code, where possible, and
/// on eyeballing a Pixel 6 running Android 12 otherwise.
class TextMagnifier extends StatefulWidget {
  /// Creates a [TextMagnifier].
  ///
  /// The [magnifierInfo] must be provided, and must be updated with new values
  /// as the user's touch changes.
  const TextMagnifier({super.key, required this.magnifierInfo});

  /// A [TextMagnifierConfiguration] that returns a [CupertinoTextMagnifier] on
  /// iOS, [TextMagnifier] on Android, and null on all other platforms, and
  /// shows the editing handles only on iOS.
  static TextMagnifierConfiguration adaptiveMagnifierConfiguration = TextMagnifierConfiguration(
    shouldDisplayHandlesInMagnifier: defaultTargetPlatform == TargetPlatform.iOS,
    magnifierBuilder:
        (
          BuildContext context,
          MagnifierController controller,
          ValueNotifier<MagnifierInfo> magnifierInfo,
        ) {
          switch (defaultTargetPlatform) {
            case TargetPlatform.iOS:
              return CupertinoTextMagnifier(controller: controller, magnifierInfo: magnifierInfo);
            case TargetPlatform.android:
              return TextMagnifier(magnifierInfo: magnifierInfo);
            case TargetPlatform.fuchsia:
            case TargetPlatform.linux:
            case TargetPlatform.macOS:
            case TargetPlatform.windows:
              return null;
          }
        },
  );

  /// The duration that the position is animated if [TextMagnifier] just switched
  /// between lines.
  static const Duration jumpBetweenLinesAnimationDuration = AndroidTextMagnifier.jumpBetweenLinesAnimationDuration;

  /// The current status of the user's touch.
  ///
  /// As the value of the [magnifierInfo] changes, the position of the loupe is
  /// adjusted automatically, according to the rules described in the
  /// [TextMagnifier] class description.
  final ValueNotifier<MagnifierInfo> magnifierInfo;

  @override
  State<TextMagnifier> createState() => _TextMagnifierState();
}

class _TextMagnifierState extends State<TextMagnifier> {
  @override
  Widget build(BuildContext context) {
    return AndroidTextMagnifier(magnifierInfo: widget.magnifierInfo);
  }
}

/// A Material-styled magnifying glass.
///
/// {@macro flutter.widgets.magnifier.intro}
///
/// This widget focuses on mimicking the _style_ of the magnifier on material.
/// For a widget that is focused on mimicking the _behavior_ of a material
/// magnifier, see [TextMagnifier], which uses [Magnifier].
///
/// The styles implemented in this widget were based on the Android 12 source
/// code, where possible, and on eyeballing a Pixel 6 running Android 12
/// otherwise.
class Magnifier extends StatelessWidget {
  /// Creates a [RawMagnifier] in the Material style.
  const Magnifier({
    super.key,
    this.additionalFocalPointOffset = Offset.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(_borderRadius)),
    this.filmColor = const Color.fromARGB(8, 158, 158, 158),
    this.shadows = const <BoxShadow>[
      BoxShadow(
        blurRadius: 1.5,
        offset: Offset(0.0, 2.0),
        spreadRadius: 0.75,
        color: Color.fromARGB(25, 0, 0, 0),
      ),
    ],
    this.clipBehavior = Clip.hardEdge,
    this.size = AndroidMagnifier.kDefaultMagnifierSize,
  });

  /// The default size of this [Magnifier].
  ///
  /// The size of the magnifier may be modified through the constructor;
  /// [kDefaultMagnifierSize] is extracted from the default parameter of
  /// [Magnifier]'s constructor so that positioners may depend on it.
  static const Size kDefaultMagnifierSize = AndroidMagnifier.kDefaultMagnifierSize;

  /// The vertical distance that the magnifier should be above the focal point.
  ///
  /// The [kStandardVerticalFocalPointShift] value is a constant so that
  /// positioning of this [Magnifier] can be done with a guaranteed size, as
  /// opposed to an estimate.
  static const double kStandardVerticalFocalPointShift = AndroidMagnifier.kStandardVerticalFocalPointShift;

  static const double _borderRadius = 40;

  /// Any additional offset the focal point requires to "point"
  /// to the correct place.
  ///
  /// This value is added to [kStandardVerticalFocalPointShift] to obtain the
  /// actual offset.
  ///
  /// This is useful for instances where the magnifier is not pointing to
  /// something directly below it.
  final Offset additionalFocalPointOffset;

  /// The border radius for this magnifier.
  ///
  /// The magnifier's shape is a [RoundedRectangleBorder] with this radius.
  final BorderRadius borderRadius;

  /// The color to tint the image in this [Magnifier].
  ///
  /// On native Android, there is a almost transparent gray tint to the
  /// magnifier, in order to better distinguish the contents of the lens from
  /// the background.
  final Color filmColor;

  /// A list of shadows cast by the [Magnifier].
  ///
  /// If the shadows use a [BlurStyle] that paints inside the shape, or if they
  /// are offset, then a [clipBehavior] that enables clipping (such as the
  /// default [Clip.hardEdge]) is recommended, otherwise the shadow will occlude
  /// the magnifier (the shadow is drawn above the magnifier so as to not be
  /// included in the magnified image).
  ///
  /// By default, the shadows are offset vertically by two logical pixels, so
  /// clipping is recommended.
  ///
  /// A shadow that uses [BlurStyle.outer] and is not offset does not need
  /// clipping; in that case, consider setting [clipBehavior] to [Clip.none].
  final List<BoxShadow> shadows;

  /// Whether and how to clip the [shadows] that render inside the loupe.
  ///
  /// Defaults to [Clip.hardEdge].
  ///
  /// A value of [Clip.none] can be used if the shadow will not paint where the
  /// magnified image appears, or if doing so is intentional (e.g. to blur the
  /// edges of the magnified image).
  ///
  /// See the discussion at [shadows].
  final Clip clipBehavior;

  /// The [Size] of this [Magnifier].
  ///
  /// The [shadows] are drawn outside of the [size].
  final Size size;

  @override
  Widget build(BuildContext context) {
    return AndroidMagnifier(
      additionalFocalPointOffset: additionalFocalPointOffset,
      borderRadius: borderRadius,
      filmColor: filmColor,
      shadows: shadows,
      clipBehavior: clipBehavior,
      size: size,
    );
  }
}
