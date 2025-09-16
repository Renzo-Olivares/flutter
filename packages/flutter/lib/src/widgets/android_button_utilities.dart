import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'basic.dart';

/// Configures the tap target and layout size of certain Material widgets.
///
/// Changing the value in [ThemeData.materialTapTargetSize] will affect the
/// accessibility experience.
///
/// Some of the impacted widgets include:
///
///   * [FloatingActionButton], only the mini tap target size is increased.
///   * [MaterialButton]
///   * [OutlinedButton]
///   * [TextButton]
///   * [ElevatedButton]
///   * [IconButton]
///   * The time picker widget ([showTimePicker])
///   * [SnackBar]
///   * [Chip]
///   * [RawChip]
///   * [InputChip]
///   * [ChoiceChip]
///   * [FilterChip]
///   * [ActionChip]
///   * [Radio]
///   * [Switch]
///   * [Checkbox]
enum MaterialTapTargetSize {
  /// Expands the minimum tap target size to 48px by 48px.
  ///
  /// This is the default value of [ThemeData.materialTapTargetSize] and the
  /// recommended size to conform to Android accessibility scanner
  /// recommendations.
  padded,

  /// Shrinks the tap target size to the minimum provided by the Material
  /// specification.
  shrinkWrap,
}

/// Defines the visual density of user interface components.
///
/// Density, in the context of a UI, is the vertical and horizontal
/// "compactness" of the components in the UI. It is unitless, since it means
/// different things to different UI components.
///
/// The default for visual densities is zero for both vertical and horizontal
/// densities, which corresponds to the default visual density of components in
/// the Material Design specification. It does not affect text sizes, icon
/// sizes, or padding values.
///
/// For example, for buttons, it affects the spacing around the child of the
/// button. For lists, it affects the distance between baselines of entries in
/// the list. For chips, it only affects the vertical size, not the horizontal
/// size.
///
/// Here are some examples of widgets that respond to density changes:
///
///  * [Checkbox]
///  * [Chip]
///  * [ElevatedButton]
///  * [IconButton]
///  * [InputDecorator] (which gives density support to [TextField], etc.)
///  * [ListTile]
///  * [MaterialButton]
///  * [OutlinedButton]
///  * [Radio]
///  * [RawMaterialButton]
///  * [TextButton]
///
/// See also:
///
///  * [ThemeData.visualDensity], where this property is used to specify the base
///    horizontal density of Material components.
///  * [Material design guidance on density](https://material.io/design/layout/applying-density.html).
@immutable
class VisualDensity with Diagnosticable {
  /// A const constructor for [VisualDensity].
  ///
  /// The [horizontal] and [vertical] arguments must be in the interval between
  /// [minimumDensity] and [maximumDensity], inclusive.
  const VisualDensity({this.horizontal = 0.0, this.vertical = 0.0})
    : assert(vertical <= maximumDensity),
      assert(vertical >= minimumDensity),
      assert(horizontal <= maximumDensity),
      assert(horizontal >= minimumDensity);

  /// The minimum allowed density.
  static const double minimumDensity = -4.0;

  /// The maximum allowed density.
  static const double maximumDensity = 4.0;

  /// The default profile for [VisualDensity] in [ThemeData].
  ///
  /// This default value represents a visual density that is less dense than
  /// either [comfortable] or [compact], and corresponds to density values of
  /// zero in both axes.
  static const VisualDensity standard = VisualDensity();

  /// The profile for a "comfortable" interpretation of [VisualDensity].
  ///
  /// Individual components will interpret the density value independently,
  /// making themselves more visually dense than [standard] and less dense than
  /// [compact] to different degrees based on the Material Design specification
  /// of the "comfortable" setting for their particular use case.
  ///
  /// It corresponds to a density value of -1 in both axes.
  static const VisualDensity comfortable = VisualDensity(horizontal: -1.0, vertical: -1.0);

  /// The profile for a "compact" interpretation of [VisualDensity].
  ///
  /// Individual components will interpret the density value independently,
  /// making themselves more visually dense than [standard] and [comfortable] to
  /// different degrees based on the Material Design specification of the
  /// "comfortable" setting for their particular use case.
  ///
  /// It corresponds to a density value of -2 in both axes.
  static const VisualDensity compact = VisualDensity(horizontal: -2.0, vertical: -2.0);

  /// Returns a [VisualDensity] that is adaptive based on the current platform
  /// on which the framework is executing, from [defaultTargetPlatform].
  ///
  /// When [defaultTargetPlatform] is a desktop platform, this returns
  /// [compact], and for other platforms, it returns a default-constructed
  /// [VisualDensity].
  ///
  /// See also:
  ///
  /// * [defaultDensityForPlatform] which returns a [VisualDensity] that is
  ///   adaptive based on the platform given to it.
  /// * [defaultTargetPlatform] which returns the platform on which the
  ///   framework is currently executing.
  static VisualDensity get adaptivePlatformDensity =>
      defaultDensityForPlatform(defaultTargetPlatform);

  /// Returns a [VisualDensity] that is adaptive based on the given [platform].
  ///
  /// For desktop platforms, this returns [compact], and for other platforms, it
  /// returns a default-constructed [VisualDensity].
  ///
  /// See also:
  ///
  /// * [adaptivePlatformDensity] which returns a [VisualDensity] that is
  ///   adaptive based on [defaultTargetPlatform].
  static VisualDensity defaultDensityForPlatform(TargetPlatform platform) {
    return switch (platform) {
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.fuchsia => standard,
      TargetPlatform.linux || TargetPlatform.macOS || TargetPlatform.windows => compact,
    };
  }

  /// Copy the current [VisualDensity] with the given values replacing the
  /// current values.
  VisualDensity copyWith({double? horizontal, double? vertical}) {
    return VisualDensity(
      horizontal: horizontal ?? this.horizontal,
      vertical: vertical ?? this.vertical,
    );
  }

  /// The horizontal visual density of UI components.
  ///
  /// This property affects only the horizontal spacing between and within
  /// components, to allow for different UI visual densities. It does not affect
  /// text sizes, icon sizes, or padding values. The default value is 0.0,
  /// corresponding to the metrics specified in the Material Design
  /// specification. The value can range from [minimumDensity] to
  /// [maximumDensity], inclusive.
  ///
  /// See also:
  ///
  ///  * [ThemeData.visualDensity], where this property is used to specify the base
  ///    horizontal density of Material components.
  ///  * [Material design guidance on density](https://material.io/design/layout/applying-density.html).
  final double horizontal;

  /// The vertical visual density of UI components.
  ///
  /// This property affects only the vertical spacing between and within
  /// components, to allow for different UI visual densities. It does not affect
  /// text sizes, icon sizes, or padding values. The default value is 0.0,
  /// corresponding to the metrics specified in the Material Design
  /// specification. The value can range from [minimumDensity] to
  /// [maximumDensity], inclusive.
  ///
  /// See also:
  ///
  ///  * [ThemeData.visualDensity], where this property is used to specify the base
  ///    vertical density of Material components.
  ///  * [Material design guidance on density](https://material.io/design/layout/applying-density.html).
  final double vertical;

  /// The base adjustment in logical pixels of the visual density of UI components.
  ///
  /// The input density values are multiplied by a constant to arrive at a base
  /// size adjustment that fits Material Design guidelines.
  ///
  /// Individual components may adjust this value based upon their own
  /// individual interpretation of density.
  Offset get baseSizeAdjustment {
    // The number of logical pixels represented by an increase or decrease in
    // density by one. The Material Design guidelines say to increment/decrement
    // sizes in terms of four pixel increments.
    const double interval = 4.0;

    return Offset(horizontal, vertical) * interval;
  }

  /// Linearly interpolate between two densities.
  static VisualDensity lerp(VisualDensity a, VisualDensity b, double t) {
    if (identical(a, b)) {
      return a;
    }
    return VisualDensity(
      horizontal: lerpDouble(a.horizontal, b.horizontal, t)!,
      vertical: lerpDouble(a.vertical, b.vertical, t)!,
    );
  }

  /// Return a copy of [constraints] whose minimum width and height have been
  /// updated with the [baseSizeAdjustment].
  ///
  /// The resulting minWidth and minHeight values are clamped to not exceed the
  /// maxWidth and maxHeight values, respectively.
  BoxConstraints effectiveConstraints(BoxConstraints constraints) {
    assert(constraints.debugAssertIsValid());
    return constraints.copyWith(
      minWidth: clampDouble(
        constraints.minWidth + baseSizeAdjustment.dx,
        0.0,
        constraints.maxWidth,
      ),
      minHeight: clampDouble(
        constraints.minHeight + baseSizeAdjustment.dy,
        0.0,
        constraints.maxHeight,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is VisualDensity && other.horizontal == horizontal && other.vertical == vertical;
  }

  @override
  int get hashCode => Object.hash(horizontal, vertical);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('horizontal', horizontal, defaultValue: 0.0));
    properties.add(DoubleProperty('vertical', vertical, defaultValue: 0.0));
  }

  @override
  String toStringShort() {
    return '${super.toStringShort()}(h: ${debugFormatDouble(horizontal)}, v: ${debugFormatDouble(vertical)})';
  }
}
