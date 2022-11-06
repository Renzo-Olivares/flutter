// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import 'constants.dart';
import 'drag_details.dart';
import 'events.dart';
import 'recognizer.dart';
import 'velocity_tracker.dart';

export 'dart:ui' show PointerDeviceKind;

export 'package:flutter/foundation.dart' show DiagnosticPropertiesBuilder;

export 'drag.dart' show DragEndDetails, DragUpdateDetails;
export 'drag_details.dart' show DragDownDetails, DragStartDetails, DragUpdateDetails, GestureDragDownCallback, GestureDragStartCallback, GestureDragUpdateCallback;
export 'events.dart' show PointerDownEvent, PointerEvent, PointerPanZoomStartEvent;
export 'recognizer.dart' show DragStartBehavior;
export 'velocity_tracker.dart' show VelocityEstimate, VelocityTracker;

enum DragState {
  ready,
  possible,
  accepted,
}

/// {@template flutter.gestures.monodrag.GestureDragEndCallback}
/// Signature for when a pointer that was previously in contact with the screen
/// and moving is no longer in contact with the screen.
///
/// The velocity at which the pointer was moving when it stopped contacting
/// the screen is available in the `details`.
/// {@endtemplate}
///
/// Used by [DragGestureRecognizer.onEnd].
typedef GestureDragEndCallback = void Function(DragEndDetails details);

/// Signature for when the pointer that previously triggered a
/// [GestureDragDownCallback] did not complete.
///
/// Used by [DragGestureRecognizer.onCancel].
typedef GestureDragCancelCallback = void Function();

/// Signature for a function that builds a [VelocityTracker].
///
/// Used by [DragGestureRecognizer.velocityTrackerBuilder].
typedef GestureVelocityTrackerBuilder = VelocityTracker Function(PointerEvent event);

/// Recognizes movement.
///
/// In contrast to [MultiDragGestureRecognizer], [DragGestureRecognizer]
/// recognizes a single gesture sequence for all the pointers it watches, which
/// means that the recognizer has at most one drag sequence active at any given
/// time regardless of how many pointers are in contact with the screen.
///
/// [DragGestureRecognizer] is not intended to be used directly. Instead,
/// consider using one of its subclasses to recognize specific types for drag
/// gestures.
///
/// [DragGestureRecognizer] competes on pointer events of [kPrimaryButton]
/// only when it has at least one non-null callback. If it has no callbacks, it
/// is a no-op.
///
/// See also:
///
///  * [HorizontalDragGestureRecognizer], for left and right drags.
///  * [VerticalDragGestureRecognizer], for up and down drags.
///  * [PanGestureRecognizer], for drags that are not locked to a single axis.
abstract class BaseDragGestureRecognizer extends OneSequenceGestureRecognizer {
  /// Initialize the object.
  ///
  /// [dragStartBehavior] must not be null.
  ///
  /// {@macro flutter.gestures.GestureRecognizer.supportedDevices}
  BaseDragGestureRecognizer({
    super.debugOwner,
    @Deprecated(
      'Migrate to supportedDevices. '
      'This feature was deprecated after v2.3.0-1.0.pre.',
    )
    super.kind,
    this.dragStartBehavior = DragStartBehavior.start,
    this.velocityTrackerBuilder = _defaultBuilder,
    super.supportedDevices,
  }) : assert(dragStartBehavior != null);

  static VelocityTracker _defaultBuilder(PointerEvent event) => VelocityTracker.withKind(event.kind);

  /// {@template flutter.gestures.monodrag.DragGestureRecognizer.dragStartBehavior}
  /// Configure the behavior of offsets passed to [onStart].
  ///
  /// If set to [DragStartBehavior.start], the [onStart] callback will be called
  /// with the position of the pointer at the time this gesture recognizer won
  /// the arena. If [DragStartBehavior.down], [onStart] will be called with
  /// the position of the first detected down event for the pointer. When there
  /// are no other gestures competing with this gesture in the arena, there's
  /// no difference in behavior between the two settings.
  ///
  /// For more information about the gesture arena:
  /// https://flutter.dev/docs/development/ui/advanced/gestures#gesture-disambiguation
  ///
  /// By default, the drag start behavior is [DragStartBehavior.start].
  ///
  /// ## Example:
  ///
  /// A [HorizontalDragGestureRecognizer] and a [VerticalDragGestureRecognizer]
  /// compete with each other. A finger presses down on the screen with
  /// offset (500.0, 500.0), and then moves to position (510.0, 500.0) before
  /// the [HorizontalDragGestureRecognizer] wins the arena. With
  /// [dragStartBehavior] set to [DragStartBehavior.down], the [onStart]
  /// callback will be called with position (500.0, 500.0). If it is
  /// instead set to [DragStartBehavior.start], [onStart] will be called with
  /// position (510.0, 500.0).
  /// {@endtemplate}
  DragStartBehavior dragStartBehavior;

  /// The minimum distance an input pointer drag must have moved to
  /// to be considered a fling gesture.
  ///
  /// This value is typically compared with the distance traveled along the
  /// scrolling axis. If null then [kTouchSlop] is used.
  double? minFlingDistance;

  /// The minimum velocity for an input pointer drag to be considered fling.
  ///
  /// This value is typically compared with the magnitude of fling gesture's
  /// velocity along the scrolling axis. If null then [kMinFlingVelocity]
  /// is used.
  double? minFlingVelocity;

  /// Fling velocity magnitudes will be clamped to this value.
  ///
  /// If null then [kMaxFlingVelocity] is used.
  double? maxFlingVelocity;

  /// Determines the type of velocity estimation method to use for a potential
  /// drag gesture, when a new pointer is added.
  ///
  /// To estimate the velocity of a gesture, [DragGestureRecognizer] calls
  /// [velocityTrackerBuilder] when it starts to track a new pointer in
  /// [addAllowedPointer], and add subsequent updates on the pointer to the
  /// resulting velocity tracker, until the gesture recognizer stops tracking
  /// the pointer. This allows you to specify a different velocity estimation
  /// strategy for each allowed pointer added, by changing the type of velocity
  /// tracker this [GestureVelocityTrackerBuilder] returns.
  ///
  /// If left unspecified the default [velocityTrackerBuilder] creates a new
  /// [VelocityTracker] for every pointer added.
  ///
  /// See also:
  ///
  ///  * [VelocityTracker], a velocity tracker that uses least squares estimation
  ///    on the 20 most recent pointer data samples. It's a well-rounded velocity
  ///    tracker and is used by default.
  ///  * [IOSScrollViewFlingVelocityTracker], a specialized velocity tracker for
  ///    determining the initial fling velocity for a [Scrollable] on iOS, to
  ///    match the native behavior on that platform.
  GestureVelocityTrackerBuilder velocityTrackerBuilder;

  DragState dragState = DragState.ready;
  late OffsetPair _initialPosition;
  late OffsetPair _pendingDragOffset;
  Duration? _lastPendingEventTimestamp;
  /// The buttons sent by `PointerDownEvent`. If a `PointerMoveEvent` comes with a
  /// different set of buttons, the gesture is canceled.
  int? get initialButtons => _initialButtons;
  int? _initialButtons;
  Matrix4? _lastTransform;

  /// Distance moved in the global coordinate space of the screen in drag direction.
  ///
  /// If drag is only allowed along a defined axis, this value may be negative to
  /// differentiate the direction of the drag.
  double get globalDistanceMoved => _globalDistanceMoved;
  void set globalDistanceMoved(double value) {
    _globalDistanceMoved = value;
  }
  late double _globalDistanceMoved;

  /// Determines if a gesture is a fling or not based on velocity.
  ///
  /// A fling calls its gesture end callback with a velocity, allowing the
  /// provider of the callback to respond by carrying the gesture forward with
  /// inertia, for example.
  bool isFlingGesture(VelocityEstimate estimate, PointerDeviceKind kind);

  Offset getDeltaForDetails(Offset delta);
  double? getPrimaryValueFromOffset(Offset value);
  bool hasSufficientGlobalDistanceToAccept(PointerDeviceKind pointerDeviceKind, double? deviceTouchSlop);

  final Map<int, VelocityTracker> _velocityTrackers = <int, VelocityTracker>{};

  void _addPointer(PointerEvent event) {
    _velocityTrackers[event.pointer] = velocityTrackerBuilder(event);
    if (dragState == DragState.ready) {
      dragState = DragState.possible;
      _initialPosition = OffsetPair(global: event.position, local: event.localPosition);
      _pendingDragOffset = OffsetPair.zero;
      _globalDistanceMoved = 0.0;
      _lastPendingEventTimestamp = event.timeStamp;
      _lastTransform = event.transform;
      print('on down');
      _checkDown(event);
    } else if (dragState == DragState.accepted) {
      resolve(GestureDisposition.accepted);
    }
  }

  @protected
  void handleDragDown({ required PointerEvent down });

  @protected
  void handleDragStart({
    required Duration timestamp,
    required int pointer,
    required OffsetPair dragOrigin,
  });

  @protected
  void handleDragUpdate({
    Duration? sourceTimeStamp,
    required Offset delta,
    double? primaryDelta,
    required int pointer,
    required OffsetPair dragOrigin,
    required Offset globalPosition,
    required Offset localPosition,
  });

  @protected
  void handleDragEnd({ required VelocityTracker tracker });

  @protected
  void handleDragCancel();

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    print('base first');
    if (dragState == DragState.ready) {
      _initialButtons = event.buttons;
    }
    _addPointer(event);
  }

  @override
  void addAllowedPointerPanZoom(PointerPanZoomStartEvent event) {
    super.addAllowedPointerPanZoom(event);
    startTrackingPointer(event.pointer, event.transform);
    if (dragState == DragState.ready) {
      _initialButtons = kPrimaryButton;
    }
    _addPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    assert(dragState != DragState.ready);
    print('base handle event');
    if (!event.synthesized &&
        (event is PointerDownEvent ||
         event is PointerMoveEvent ||
         event is PointerPanZoomStartEvent ||
         event is PointerPanZoomUpdateEvent)) {
      final VelocityTracker tracker = _velocityTrackers[event.pointer]!;
      assert(tracker != null);
      if (event is PointerPanZoomStartEvent) {
        tracker.addPosition(event.timeStamp, Offset.zero);
      } else if (event is PointerPanZoomUpdateEvent) {
        tracker.addPosition(event.timeStamp, event.pan);
      } else {
        tracker.addPosition(event.timeStamp, event.localPosition);
      }
    }
    if (event is PointerMoveEvent && event.buttons != _initialButtons) {
      _giveUpPointer(event.pointer);
      return;
    }
    if (event is PointerMoveEvent || event is PointerPanZoomUpdateEvent) {
      final Offset delta = (event is PointerMoveEvent) ? event.delta : (event as PointerPanZoomUpdateEvent).panDelta;
      final Offset localDelta = (event is PointerMoveEvent) ? event.localDelta : (event as PointerPanZoomUpdateEvent).localPanDelta;
      final Offset position = (event is PointerMoveEvent) ? event.position : (event.position + (event as PointerPanZoomUpdateEvent).pan);
      final Offset localPosition = (event is PointerMoveEvent) ? event.localPosition : (event.localPosition + (event as PointerPanZoomUpdateEvent).localPan);
      if (dragState == DragState.accepted) {
        _checkUpdate(
          sourceTimeStamp: event.timeStamp,
          delta: getDeltaForDetails(localDelta),
          primaryDelta: getPrimaryValueFromOffset(localDelta),
          pointer: event.pointer,
          globalPosition: position,
          localPosition: localPosition,
        );
      } else {
        _pendingDragOffset += OffsetPair(local: localDelta, global: delta);
        _lastPendingEventTimestamp = event.timeStamp;
        _lastTransform = event.transform;
        final Offset movedLocally = getDeltaForDetails(localDelta);
        final Matrix4? localToGlobalTransform = event.transform == null ? null : Matrix4.tryInvert(event.transform!);
        _globalDistanceMoved += PointerEvent.transformDeltaViaPositions(
          transform: localToGlobalTransform,
          untransformedDelta: movedLocally,
          untransformedEndPosition: localPosition
        ).distance * (getPrimaryValueFromOffset(movedLocally) ?? 1).sign;
        if (hasSufficientGlobalDistanceToAccept(event.kind, gestureSettings?.touchSlop)) {
          resolve(GestureDisposition.accepted);
        }
      }
    }
    if (event is PointerUpEvent || event is PointerCancelEvent || event is PointerPanZoomEndEvent) {
      _giveUpPointer(event.pointer);
    }
  }

  final Set<int> _acceptedActivePointers = <int>{};

  @override
  void acceptGesture(int pointer) {
    assert(!_acceptedActivePointers.contains(pointer));
    _acceptedActivePointers.add(pointer);
    if (dragState != DragState.accepted) {
      dragState = DragState.accepted;
      final OffsetPair delta = _pendingDragOffset;
      final Duration timestamp = _lastPendingEventTimestamp!;
      final Matrix4? transform = _lastTransform;
      final Offset localUpdateDelta;
      switch (dragStartBehavior) {
        case DragStartBehavior.start:
          _initialPosition = _initialPosition + delta;
          localUpdateDelta = Offset.zero;
          break;
        case DragStartBehavior.down:
          localUpdateDelta = getDeltaForDetails(delta.local);
          break;
      }
      _pendingDragOffset = OffsetPair.zero;
      _lastPendingEventTimestamp = null;
      _lastTransform = null;
      _checkStart(timestamp, pointer);
      if (localUpdateDelta != Offset.zero) {
        final Matrix4? localToGlobal = transform != null ? Matrix4.tryInvert(transform) : null;
        final Offset correctedLocalPosition = _initialPosition.local + localUpdateDelta;
        final Offset globalUpdateDelta = PointerEvent.transformDeltaViaPositions(
          untransformedEndPosition: correctedLocalPosition,
          untransformedDelta: localUpdateDelta,
          transform: localToGlobal,
        );
        final OffsetPair updateDelta = OffsetPair(local: localUpdateDelta, global: globalUpdateDelta);
        final OffsetPair correctedPosition = _initialPosition + updateDelta; // Only adds delta for down behaviour
        _checkUpdate(
          sourceTimeStamp: timestamp,
          delta: localUpdateDelta,
          primaryDelta: getPrimaryValueFromOffset(localUpdateDelta),
          pointer: pointer,
          globalPosition: correctedPosition.global,
          localPosition: correctedPosition.local,
        );
      }
      // This acceptGesture might have been called only for one pointer, instead
      // of all pointers. Resolve all pointers to `accepted`. This won't cause
      // infinite recursion because an accepted pointer won't be accepted again.
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void rejectGesture(int pointer) {
    _giveUpPointer(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    assert(dragState != DragState.ready);
    switch(dragState) {
      case DragState.ready:
        break;

      case DragState.possible:
        resolve(GestureDisposition.rejected);
        _checkCancel();
        break;

      case DragState.accepted:
        _checkEnd(pointer);
        break;
    }
    _velocityTrackers.clear();
    print('resetting initialButtons');
    _initialButtons = null;
    dragState = DragState.ready;
  }

  void _giveUpPointer(int pointer) {
    stopTrackingPointer(pointer);
    // If we never accepted the pointer, we reject it since we are no longer
    // interested in winning the gesture arena for it.
    if (!_acceptedActivePointers.remove(pointer)) {
      resolvePointer(pointer, GestureDisposition.rejected);
    }
  }

  void _checkDown(PointerEvent event) {
    // assert(_initialButtons == kPrimaryButton);
    handleDragDown(down: event);
  }

  void _checkStart(Duration timestamp, int pointer) {
    // assert(_initialButtons == kPrimaryButton);
    handleDragStart(timestamp: timestamp, pointer: pointer, dragOrigin: _initialPosition);
  }

  void _checkUpdate({
    Duration? sourceTimeStamp,
    required Offset delta,
    double? primaryDelta,
    required int pointer,
    required Offset globalPosition,
    required Offset localPosition,
  }) {
    // assert(_initialButtons == kPrimaryButton);
    handleDragUpdate(
      sourceTimeStamp: sourceTimeStamp,
      delta: delta,
      primaryDelta: primaryDelta,
      pointer: pointer,
      dragOrigin: _initialPosition,
      globalPosition: globalPosition,
      localPosition: localPosition,
    );
  }

  void _checkEnd(int pointer) {
    // assert(_initialButtons == kPrimaryButton);
    final VelocityTracker tracker = _velocityTrackers[pointer]!;
    assert(tracker != null);
    handleDragEnd(tracker: tracker);
  }

  void _checkCancel() {
    // assert(_initialButtons == kPrimaryButton);
    handleDragCancel();
  }

  @override
  void dispose() {
    _velocityTrackers.clear();
    super.dispose();
  }
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<DragStartBehavior>('start behavior', dragStartBehavior));
  }
}

abstract class DragGestureRecognizer extends BaseDragGestureRecognizer {
  DragGestureRecognizer({
    super.debugOwner,
    @Deprecated(
      'Migrate to supportedDevices. '
      'This feature was deprecated after v2.3.0-1.0.pre.',
    )
    super.kind,
    super.dragStartBehavior,
    super.velocityTrackerBuilder,
    super.supportedDevices,
  });

  /// A pointer has contacted the screen with a primary button and might begin
  /// to move.
  ///
  /// The position of the pointer is provided in the callback's `details`
  /// argument, which is a [DragDownDetails] object.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  ///  * [DragDownDetails], which is passed as an argument to this callback.
  GestureDragDownCallback? onDown;

  /// {@template flutter.gestures.monodrag.DragGestureRecognizer.onStart}
  /// A pointer has contacted the screen with a primary button and has begun to
  /// move.
  ///
  /// The position of the pointer is provided in the callback's `details`
  /// argument, which is a [DragStartDetails] object. The [dragStartBehavior]
  /// determines this position.
  /// {@endtemplate}
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  ///  * [DragStartDetails], which is passed as an argument to this callback.
  GestureDragStartCallback? onStart;

  /// {@template flutter.gestures.monodrag.DragGestureRecognizer.onUpdate}
  /// A pointer that is in contact with the screen with a primary button and
  /// moving has moved again.
  ///
  /// The distance traveled by the pointer since the last update is provided in
  /// the callback's `details` argument, which is a [DragUpdateDetails] object.
  /// {@endtemplate}
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  ///  * [DragUpdateDetails], which is passed as an argument to this callback.
  GestureDragUpdateCallback? onUpdate;

  /// {@template flutter.gestures.monodrag.DragGestureRecognizer.onEnd}
  /// A pointer that was previously in contact with the screen with a primary
  /// button and moving is no longer in contact with the screen and was moving
  /// at a specific velocity when it stopped contacting the screen.
  ///
  /// The velocity is provided in the callback's `details` argument, which is a
  /// [DragEndDetails] object.
  /// {@endtemplate}
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  ///  * [DragEndDetails], which is passed as an argument to this callback.
  GestureDragEndCallback? onEnd;

  /// The pointer that previously triggered [onDown] did not complete.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  GestureDragCancelCallback? onCancel;

  @override
  bool isPointerAllowed(PointerEvent event) {
    if (_initialButtons == null) {
      switch (event.buttons) {
        case kPrimaryButton:
          if (onDown == null &&
              onStart == null &&
              onUpdate == null &&
              onEnd == null &&
              onCancel == null) {
            return false;
          }
          break;
        default:
          return false;
      }
    } else {
      // There can be multiple drags simultaneously. Their effects are combined.
      if (event.buttons != _initialButtons) {
        return false;
      }
    }
    return super.isPointerAllowed(event as PointerDownEvent);
  }

  @protected
  @override
  void handleDragDown({ required PointerEvent down }) {
    if (onDown != null) {
      final DragDownDetails details = DragDownDetails(
        globalPosition: down.position,
        localPosition: down.localPosition,
      );
      invokeCallback<void>('onDown', () => onDown!(details));
    }
  }

  @protected
  @override
  void handleDragStart({
    required Duration timestamp,
    required int pointer,
    required OffsetPair dragOrigin,
  }) {
    if (onStart != null) {
      final DragStartDetails details = DragStartDetails(
        sourceTimeStamp: timestamp,
        globalPosition: dragOrigin.global,
        localPosition: dragOrigin.local,
        kind: getKindForPointer(pointer),
      );
      invokeCallback<void>('onStart', () => onStart!(details));
    }
  }

  @protected
  @override
  void handleDragUpdate({
    Duration? sourceTimeStamp,
    required Offset delta,
    double? primaryDelta,
    required int pointer,
    required OffsetPair dragOrigin,
    required Offset globalPosition,
    required Offset localPosition,
  }) {
    if (onUpdate != null) {
      final DragUpdateDetails details = DragUpdateDetails(
        sourceTimeStamp: sourceTimeStamp,
        delta: delta,
        primaryDelta: primaryDelta,
        globalPosition: globalPosition,
        localPosition: localPosition,
        offsetFromOrigin: globalPosition - dragOrigin.global,
        localOffsetFromOrigin: localPosition! - dragOrigin.local,
      );
      invokeCallback<void>('onUpdate', () => onUpdate!(details));
    }
  }

  @protected
  @override
  void handleDragEnd({ required VelocityTracker tracker }) {
    final DragEndDetails details;
    final String Function() debugReport;

    final VelocityEstimate? estimate = tracker.getVelocityEstimate();
    if (estimate != null && isFlingGesture(estimate, tracker.kind)) {
      final Velocity velocity = Velocity(pixelsPerSecond: estimate.pixelsPerSecond)
        .clampMagnitude(minFlingVelocity ?? kMinFlingVelocity, maxFlingVelocity ?? kMaxFlingVelocity);
      details = DragEndDetails(
        velocity: velocity,
        primaryVelocity: getPrimaryValueFromOffset(velocity.pixelsPerSecond),
      );
      debugReport = () {
        return '$estimate; fling at $velocity.';
      };
    } else {
      details = DragEndDetails(
        primaryVelocity: 0.0,
      );
      debugReport = () {
        if (estimate == null) {
          return 'Could not estimate velocity.';
        }
        return '$estimate; judged to not be a fling.';
      };
    }
    invokeCallback<void>('onEnd', () => onEnd!(details), debugReport: debugReport);
  }

  @protected
  @override
  void handleDragCancel() {
    if (onCancel != null) {
      invokeCallback<void>('onCancel', onCancel!);
    }
  }
}

/// Recognizes movement in the vertical direction.
///
/// Used for vertical scrolling.
///
/// See also:
///
///  * [HorizontalDragGestureRecognizer], for a similar recognizer but for
///    horizontal movement.
///  * [MultiDragGestureRecognizer], for a family of gesture recognizers that
///    track each touch point independently.
class VerticalDragGestureRecognizer extends DragGestureRecognizer {
  /// Create a gesture recognizer for interactions in the vertical axis.
  ///
  /// {@macro flutter.gestures.GestureRecognizer.supportedDevices}
  VerticalDragGestureRecognizer({
    super.debugOwner,
    @Deprecated(
      'Migrate to supportedDevices. '
      'This feature was deprecated after v2.3.0-1.0.pre.',
    )
    super.kind,
    super.supportedDevices,
  });

  @override
  bool isFlingGesture(VelocityEstimate estimate, PointerDeviceKind kind) {
    final double minVelocity = minFlingVelocity ?? kMinFlingVelocity;
    final double minDistance = minFlingDistance ?? computeHitSlop(kind, gestureSettings);
    return estimate.pixelsPerSecond.dy.abs() > minVelocity && estimate.offset.dy.abs() > minDistance;
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(PointerDeviceKind pointerDeviceKind, double? deviceTouchSlop) {
    return globalDistanceMoved.abs() > computeHitSlop(pointerDeviceKind, gestureSettings);
  }

  @override
  Offset getDeltaForDetails(Offset delta) => Offset(0.0, delta.dy);

  @override
  double getPrimaryValueFromOffset(Offset value) => value.dy;

  @override
  String get debugDescription => 'vertical drag';
}

/// Recognizes movement in the horizontal direction.
///
/// Used for horizontal scrolling.
///
/// See also:
///
///  * [VerticalDragGestureRecognizer], for a similar recognizer but for
///    vertical movement.
///  * [MultiDragGestureRecognizer], for a family of gesture recognizers that
///    track each touch point independently.
class HorizontalDragGestureRecognizer extends DragGestureRecognizer {
  /// Create a gesture recognizer for interactions in the horizontal axis.
  ///
  /// {@macro flutter.gestures.GestureRecognizer.supportedDevices}
  HorizontalDragGestureRecognizer({
    super.debugOwner,
    @Deprecated(
      'Migrate to supportedDevices. '
      'This feature was deprecated after v2.3.0-1.0.pre.',
    )
    super.kind,
    super.supportedDevices,
  });

  @override
  bool isFlingGesture(VelocityEstimate estimate, PointerDeviceKind kind) {
    final double minVelocity = minFlingVelocity ?? kMinFlingVelocity;
    final double minDistance = minFlingDistance ?? computeHitSlop(kind, gestureSettings);
    return estimate.pixelsPerSecond.dx.abs() > minVelocity && estimate.offset.dx.abs() > minDistance;
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(PointerDeviceKind pointerDeviceKind, double? deviceTouchSlop) {
    return globalDistanceMoved.abs() > computeHitSlop(pointerDeviceKind, gestureSettings);
  }

  @override
  Offset getDeltaForDetails(Offset delta) => Offset(delta.dx, 0.0);

  @override
  double getPrimaryValueFromOffset(Offset value) => value.dx;

  @override
  String get debugDescription => 'horizontal drag';
}

/// Recognizes movement both horizontally and vertically.
///
/// See also:
///
///  * [ImmediateMultiDragGestureRecognizer], for a similar recognizer that
///    tracks each touch point independently.
///  * [DelayedMultiDragGestureRecognizer], for a similar recognizer that
///    tracks each touch point independently, but that doesn't start until
///    some time has passed.
class PanGestureRecognizer extends DragGestureRecognizer {
  /// Create a gesture recognizer for tracking movement on a plane.
  PanGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
  });

  @override
  bool isFlingGesture(VelocityEstimate estimate, PointerDeviceKind kind) {
    final double minVelocity = minFlingVelocity ?? kMinFlingVelocity;
    final double minDistance = minFlingDistance ?? computeHitSlop(kind, gestureSettings);
    return estimate.pixelsPerSecond.distanceSquared > minVelocity * minVelocity
        && estimate.offset.distanceSquared > minDistance * minDistance;
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(PointerDeviceKind pointerDeviceKind, double? deviceTouchSlop) {
    return globalDistanceMoved.abs() > computePanSlop(pointerDeviceKind, gestureSettings);
  }

  @override
  Offset getDeltaForDetails(Offset delta) => delta;

  @override
  double? getPrimaryValueFromOffset(Offset value) => null;

  @override
  String get debugDescription => 'pan';
}
