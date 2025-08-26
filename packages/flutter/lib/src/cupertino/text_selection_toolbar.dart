// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// @docImport 'package:flutter/material.dart';
library;

import 'dart:math' as math show pi;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show Brightness, clampDouble;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'text_selection_toolbar_button.dart';
import 'theme.dart';

// The radius of the toolbar RRect shape.
// Value extracted from https://developer.apple.com/design/resources/.
const Radius _kToolbarBorderRadius = Radius.circular(8.0);

// The size of the arrow pointing to the anchor. Eyeballed value.
const Size _kToolbarArrowSize = Size(14.0, 7.0);

// Color was measured from a screenshot of iOS 16.0.2
// TODO(LongCatIsLooong): https://github.com/flutter/flutter/issues/41507.
const CupertinoDynamicColor _kToolbarBackgroundColor = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFF6F6F6),
  darkColor: Color(0xFF222222),
);

/// Potentially deprecate.
/// The type for a Function that builds a toolbar's container with the given
/// child.
///
/// The anchor is provided in global coordinates.
///
/// See also:
///
///   * [CupertinoTextSelectionToolbar.toolbarBuilder], which is of this type.
///   * [TextSelectionToolbar.toolbarBuilder], which is similar, but for an
///     Material-style toolbar.
typedef CupertinoToolbarBuilder = AppleToolbarBuilder;

/// An iOS-style text selection toolbar.
///
/// Typically displays buttons for text manipulation, e.g. copying and pasting
/// text.
///
/// Tries to position itself above [anchorAbove], but if it doesn't fit, then
/// it positions itself below [anchorBelow].
///
/// If any children don't fit in the menu, an overflow menu will automatically
/// be created.
///
/// See also:
///
///  * [AdaptiveTextSelectionToolbar], which builds the toolbar for the current
///    platform.
///  * [TextSelectionToolbar], which is similar, but builds an Android-style
///    toolbar.
class CupertinoTextSelectionToolbar extends StatelessWidget {
  /// Creates an instance of CupertinoTextSelectionToolbar.
  const CupertinoTextSelectionToolbar({
    super.key,
    required this.anchorAbove,
    required this.anchorBelow,
    required this.children,
    this.toolbarBuilder = _defaultToolbarBuilder,
  }) : assert(children.length > 0);

  /// {@macro flutter.material.TextSelectionToolbar.anchorAbove}
  final Offset anchorAbove;

  /// {@macro flutter.material.TextSelectionToolbar.anchorBelow}
  final Offset anchorBelow;

  /// {@macro flutter.material.TextSelectionToolbar.children}
  ///
  /// See also:
  ///   * [CupertinoTextSelectionToolbarButton], which builds a default
  ///     Cupertino-style text selection toolbar text button.
  final List<Widget> children;

  /// {@macro flutter.material.TextSelectionToolbar.toolbarBuilder}
  ///
  /// The given anchor and isAbove can be used to position an arrow, as in the
  /// default Cupertino toolbar.
  final CupertinoToolbarBuilder toolbarBuilder;

  /// Potentially deprecate.
  /// Minimal padding from all edges of the selection toolbar to all edges of the
  /// viewport.
  ///
  /// See also:
  ///
  ///  * [SpellCheckSuggestionsToolbar], which uses this same value for its
  ///    padding from the edges of the viewport.
  ///  * [TextSelectionToolbar], which uses this same value as well.
  static const double kToolbarScreenPadding = AppleTextSelectionToolbar.kToolbarScreenPadding;

  // Builds a toolbar just like the default iOS toolbar, with the right color
  // background and a rounded cutout with an arrow.
  static Widget _defaultToolbarBuilder(
    BuildContext context,
    Offset anchorAbove,
    Offset anchorBelow,
    Widget child,
  ) {
    return _CupertinoTextSelectionToolbarShape(
      anchorAbove: anchorAbove,
      anchorBelow: anchorBelow,
      shadowColor: CupertinoTheme.brightnessOf(context) == Brightness.light
          ? CupertinoColors.black.withOpacity(0.2)
          : null,
      child: ColoredBox(color: _kToolbarBackgroundColor.resolveFrom(context), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMediaQuery(context));

    return AppleTextSelectionToolbar(
      anchorAbove: anchorAbove,
      anchorBelow: anchorBelow,
      toolbarBuilder: _defaultToolbarBuilder,
      children: children,
    );
  }
}

// Clips the child so that it has the shape of the default iOS text selection
// toolbar, with rounded corners and an arrow pointing at the anchor.
//
// The anchor should be in global coordinates.
class _CupertinoTextSelectionToolbarShape extends SingleChildRenderObjectWidget {
  const _CupertinoTextSelectionToolbarShape({
    required Offset anchorAbove,
    required Offset anchorBelow,
    Color? shadowColor,
    super.child,
  }) : _anchorAbove = anchorAbove,
       _anchorBelow = anchorBelow,
       _shadowColor = shadowColor;

  final Offset _anchorAbove;
  final Offset _anchorBelow;
  final Color? _shadowColor;

  @override
  _RenderCupertinoTextSelectionToolbarShape createRenderObject(BuildContext context) =>
      _RenderCupertinoTextSelectionToolbarShape(_anchorAbove, _anchorBelow, _shadowColor, null);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderCupertinoTextSelectionToolbarShape renderObject,
  ) {
    renderObject
      ..anchorAbove = _anchorAbove
      ..anchorBelow = _anchorBelow
      ..shadowColor = _shadowColor;
  }
}

// Clips the child into the shape of the default iOS text selection toolbar.
//
// The shape is a rounded rectangle with a protruding arrow pointing at the
// given anchor in the direction indicated by isAbove.
//
// In order to allow the child to render itself independent of isAbove, its
// height is clipped on both the top and the bottom, leaving the arrow remaining
// on the necessary side.
class _RenderCupertinoTextSelectionToolbarShape extends RenderShiftedBox {
  _RenderCupertinoTextSelectionToolbarShape(
    this._anchorAbove,
    this._anchorBelow,
    this._shadowColor,
    super.child,
  );

  @override
  bool get isRepaintBoundary => true;

  Offset get anchorAbove => _anchorAbove;
  Offset _anchorAbove;
  set anchorAbove(Offset value) {
    if (value == _anchorAbove) {
      return;
    }
    _anchorAbove = value;
    markNeedsLayout();
  }

  Offset get anchorBelow => _anchorBelow;
  Offset _anchorBelow;
  set anchorBelow(Offset value) {
    if (value == _anchorBelow) {
      return;
    }
    _anchorBelow = value;
    markNeedsLayout();
  }

  Color? get shadowColor => _shadowColor;
  Color? _shadowColor;
  set shadowColor(Color? value) {
    if (value == _shadowColor) {
      return;
    }
    _shadowColor = value;
    markNeedsPaint();
  }

  bool _isAbove(double childHeight) => anchorAbove.dy >= childHeight - _kToolbarArrowSize.height;

  BoxConstraints _constraintsForChild(BoxConstraints constraints) {
    return BoxConstraints(
      minWidth: _kToolbarArrowSize.width + _kToolbarBorderRadius.x * 2,
    ).enforce(constraints.loosen());
  }

  Offset _computeChildOffset(Size childSize) {
    return Offset(0.0, _isAbove(childSize.height) ? -_kToolbarArrowSize.height : 0.0);
  }

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) {
    final RenderBox? child = this.child;
    if (child == null) {
      return null;
    }
    final BoxConstraints enforcedConstraint = _constraintsForChild(constraints);
    final double? result = child.getDryBaseline(enforcedConstraint, baseline);
    return result == null
        ? null
        : result + _computeChildOffset(child.getDryLayout(enforcedConstraint)).dy;
  }

  @override
  void performLayout() {
    final RenderBox? child = this.child;
    if (child == null) {
      return;
    }

    child.layout(_constraintsForChild(constraints), parentUsesSize: true);
    // The buttons are padded on both top and bottom sufficiently to have
    // the arrow clipped out of it on either side. By
    // using this approach, the buttons don't need any special padding that
    // depends on isAbove.
    // The height of one arrow will be clipped off of the child, so adjust the
    // size and position to remove that piece from the layout.
    final BoxParentData childParentData = child.parentData! as BoxParentData;
    childParentData.offset = _computeChildOffset(child.size);
    size = Size(child.size.width, child.size.height - _kToolbarArrowSize.height);
  }

  // Returns the RRect inside which the child is painted.
  RRect _shapeRRect(RenderBox child) {
    final Rect rect =
        Offset(0.0, _kToolbarArrowSize.height) &
        Size(child.size.width, child.size.height - _kToolbarArrowSize.height * 2);
    return RRect.fromRectAndRadius(rect, _kToolbarBorderRadius).scaleRadii();
  }

  // Adds the given `rrect` to the current `path`, starting from the last point
  // in `path` and ends after the last corner of the rrect (closest corner to
  // `startAngle` in the counterclockwise direction), without closing the path.
  //
  // The `startAngle` argument must be a multiple of pi / 2, with 0 being the
  // positive half of the x-axis, and pi / 2 being the negative half of the
  // y-axis.
  //
  // For instance, if `startAngle` equals pi/2 then this method draws a line
  // segment to the bottom-left corner of `rrect` from the last point in `path`,
  // and follows the `rrect` path clockwise until the bottom-right corner is
  // added, then this method returns the mutated path without closing it.
  static Path _addRRectToPath(Path path, RRect rrect, {required double startAngle}) {
    const double halfPI = math.pi / 2;
    assert(startAngle % halfPI == 0.0);
    final Rect rect = rrect.outerRect;

    final List<(Offset, Radius)> rrectCorners = <(Offset, Radius)>[
      (rect.bottomRight, -rrect.brRadius),
      (rect.bottomLeft, Radius.elliptical(rrect.blRadiusX, -rrect.blRadiusY)),
      (rect.topLeft, rrect.tlRadius),
      (rect.topRight, Radius.elliptical(-rrect.trRadiusX, rrect.trRadiusY)),
    ];

    // Add the 4 corners to the path clockwise. Convert radians to quadrants
    // to avoid fp arithmetics. The order is br -> bl -> tl -> tr if the starting
    // angle is 0.
    final int startQuadrantIndex = startAngle ~/ halfPI;
    for (int i = startQuadrantIndex; i < rrectCorners.length + startQuadrantIndex; i += 1) {
      final (Offset vertex, Radius rectCenterOffset) = rrectCorners[i % rrectCorners.length];
      final Offset otherVertex = Offset(
        vertex.dx + 2 * rectCenterOffset.x,
        vertex.dy + 2 * rectCenterOffset.y,
      );
      final Rect rect = Rect.fromPoints(vertex, otherVertex);
      path.arcTo(rect, halfPI * i, halfPI, false);
    }
    return path;
  }

  // The path is described in the toolbar child's coordinate system.
  Path _clipPath(RenderBox child, RRect rrect) {
    final Path path = Path();
    // If there isn't enough width for the arrow + radii, ignore the arrow.
    // Because of the constraints we gave children in performLayout, this should
    // only happen if the parent isn't wide enough which should be very rare, and
    // when that happens the arrow won't be too useful anyways.
    if (_kToolbarBorderRadius.x * 2 + _kToolbarArrowSize.width > size.width) {
      return path..addRRect(rrect);
    }

    final bool isAbove = _isAbove(child.size.height);
    final Offset localAnchor = globalToLocal(isAbove ? _anchorAbove : _anchorBelow);
    final double arrowTipX = clampDouble(
      localAnchor.dx,
      _kToolbarBorderRadius.x + _kToolbarArrowSize.width / 2,
      size.width - _kToolbarArrowSize.width / 2 - _kToolbarBorderRadius.x,
    );

    // Draw the path clockwise, starting from the beginning side of the arrow.
    if (isAbove) {
      final double arrowBaseY = child.size.height - _kToolbarArrowSize.height;
      final double arrowTipY = child.size.height;
      path
        ..moveTo(
          arrowTipX + _kToolbarArrowSize.width / 2,
          arrowBaseY,
        ) // right side of the arrow triangle
        ..lineTo(arrowTipX, arrowTipY) // The tip of the arrow
        ..lineTo(
          arrowTipX - _kToolbarArrowSize.width / 2,
          arrowBaseY,
        ); // left side of the arrow triangle
    } else {
      final double arrowBaseY = _kToolbarArrowSize.height;
      const double arrowTipY = 0.0;
      path
        ..moveTo(
          arrowTipX - _kToolbarArrowSize.width / 2,
          arrowBaseY,
        ) // right side of the arrow triangle
        ..lineTo(arrowTipX, arrowTipY) // The tip of the arrow
        ..lineTo(
          arrowTipX + _kToolbarArrowSize.width / 2,
          arrowBaseY,
        ); // left side of the arrow triangle
    }
    final double startAngle = isAbove ? math.pi / 2 : -math.pi / 2;
    return _addRRectToPath(path, rrect, startAngle: startAngle)..close();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderBox? child = this.child;
    if (child == null) {
      return;
    }

    final BoxParentData childParentData = child.parentData! as BoxParentData;

    final RRect rrect = _shapeRRect(child);
    final Path clipPath = _clipPath(child, rrect);

    // If configured, paint the shadow beneath the shape.
    if (_shadowColor != null) {
      final BoxShadow boxShadow = BoxShadow(color: _shadowColor!, blurRadius: 15.0);
      final RRect shadowRRect = RRect.fromLTRBR(
        rrect.left,
        rrect.top,
        rrect.right,
        rrect.bottom + _kToolbarArrowSize.height,
        _kToolbarBorderRadius,
      ).shift(offset + childParentData.offset + boxShadow.offset);
      context.canvas.drawRRect(shadowRRect, boxShadow.toPaint());
    }

    _clipPathLayer.layer = context.pushClipPath(
      needsCompositing,
      offset + childParentData.offset,
      Offset.zero & child.size,
      clipPath,
      (PaintingContext innerContext, Offset innerOffset) =>
          innerContext.paintChild(child, innerOffset),
      oldLayer: _clipPathLayer.layer,
    );
  }

  final LayerHandle<ClipPathLayer> _clipPathLayer = LayerHandle<ClipPathLayer>();
  Paint? _debugPaint;

  @override
  void dispose() {
    _clipPathLayer.layer = null;
    super.dispose();
  }

  @override
  void debugPaintSize(PaintingContext context, Offset offset) {
    assert(() {
      final RenderBox? child = this.child;
      if (child == null) {
        return true;
      }

      final ui.Paint debugPaint = _debugPaint ??= Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          const Offset(10.0, 10.0),
          const <Color>[
            CupertinoColors.transparent,
            Color(0xFFFF00FF),
            Color(0xFFFF00FF),
            CupertinoColors.transparent,
          ],
          const <double>[0.25, 0.25, 0.75, 0.75],
          TileMode.repeated,
        )
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      final BoxParentData childParentData = child.parentData! as BoxParentData;
      final Path clipPath = _clipPath(child, _shapeRRect(child));
      context.canvas.drawPath(clipPath.shift(offset + childParentData.offset), debugPaint);
      return true;
    }());
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final RenderBox? child = this.child;
    if (child == null) {
      return false;
    }

    // Positions outside of the clipped area of the child are not counted as
    // hits.
    final BoxParentData childParentData = child.parentData! as BoxParentData;
    final Rect hitBox = Rect.fromLTWH(
      childParentData.offset.dx,
      childParentData.offset.dy + _kToolbarArrowSize.height,
      child.size.width,
      child.size.height - _kToolbarArrowSize.height * 2,
    );
    if (!hitBox.contains(position)) {
      return false;
    }

    return super.hitTestChildren(result, position: position);
  }
}
