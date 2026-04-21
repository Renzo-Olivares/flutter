// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// @docImport 'package:flutter/widgets.dart';
///
/// @docImport 'paragraph.dart';
library;

import 'dart:ui' as ui show BoxHeightStyle, BoxWidthStyle, TextBox;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import 'custom_paint.dart';
import 'object.dart';

/// An object handed to a [TextPlugin] for each `Text`/`RichText` widget in the
/// subtree covered by an enclosing `TextPluginScope`.
///
/// The delegate exposes the displayed text, geometry queries, and slots for
/// foreground and background painters. Setting [backgroundPainter] or
/// [foregroundPainter] asks the framework to paint the given
/// [CustomPainter] behind or in front of the paragraph's glyphs during the
/// paragraph's own paint pass.
///
/// There is exactly one delegate per (plugin, `RenderParagraph`) pair — so two
/// plugins that cover the same `Text` receive two distinct delegates backed by
/// the same underlying `TextPainter`. Writing to one delegate's painter slot
/// does not affect another delegate's slot; decorations from different plugins
/// stack cleanly.
///
/// A delegate is a [Listenable]: it notifies listeners after the underlying
/// paragraph completes a layout pass, so painters can invalidate their cached
/// geometry. A delegate is also [Comparable], ordering delegates by document
/// order in the render tree so that plugins maintaining ordered lists of
/// matches can insert incrementally-arriving delegates at the correct
/// position.
///
/// See also:
///
///  * `TextPlugin`, which is handed delegates through its lifecycle hooks.
///  * `TextPluginScope`, which installs one or more plugins over a subtree.
mixin TextDelegate implements Listenable, Comparable<TextDelegate> {
  /// The plain-text contents of the covered `Text`/`RichText` widget.
  ///
  /// Equivalent to `InlineSpan.toPlainText(includeSemanticsLabels: false)` on
  /// the underlying span. Contains the placeholder code unit
  /// `PlaceholderSpan.placeholderCodeUnit` (`￼`) at every position where
  /// a `WidgetSpan` or other `PlaceholderSpan` appears. Plugins doing string
  /// matching should treat `￼` as an opaque boundary.
  String get text;

  /// The code unit ranges in [text] that hold placeholder code units.
  ///
  /// Each range corresponds to one `PlaceholderSpan` (or `WidgetSpan`) and is
  /// one code unit wide. Useful for plugins that want to skip placeholder
  /// regions when computing match ranges, or that want to know whether a
  /// query range crosses a placeholder before deciding how to paint.
  List<TextRange> get placeholderRanges;

  /// Returns visual bounding boxes for [selection] in the covered widget's
  /// local coordinate space.
  ///
  /// By default the result matches `RenderParagraph.getBoxesForSelection`
  /// exactly — including boxes that cover placeholder regions where
  /// `WidgetSpan`s will paint. Pass `includePlaceholders: false` to drop boxes
  /// whose underlying run is a placeholder; this is the right choice for most
  /// decorations (highlights, underlines) that should not paint behind
  /// embedded widgets. Positive naming follows the framework style guide's
  /// ["avoid double negatives in APIs"](https://github.com/flutter/flutter/blob/master/docs/contributing/Style-guide-for-Flutter-repo.md#avoid-double-negatives-in-apis)
  /// rule and matches the precedent
  /// `InlineSpan.toPlainText({bool includePlaceholders = true})`.
  ///
  /// The [boxHeightStyle] and [boxWidthStyle] arguments default to
  /// [ui.BoxHeightStyle.tight] and [ui.BoxWidthStyle.tight], matching
  /// `RenderParagraph.getBoxesForSelection`. Plugins that want visually
  /// uniform rects across lines with mixed metrics (e.g., emoji + standard
  /// text) should pass `boxHeightStyle: ui.BoxHeightStyle.max` explicitly.
  ///
  /// Sub-grapheme ranges return an empty list. This matches SkParagraph's
  /// behavior for Arabic ligatures and emoji ZWJ sequences: a query that
  /// covers only part of a grapheme cluster is collapsed to empty by the
  /// shaping engine.
  ///
  /// **Performance:** Skia recomputes the result on every call (no result
  /// memoization at the engine level). Plugins should cache the returned
  /// boxes on their painter and recompute only in response to plugin state
  /// changes or this delegate's [Listenable] notifications — not per-frame
  /// from inside `paint()`.
  List<ui.TextBox> getBoxesForSelection(
    TextSelection selection, {
    ui.BoxHeightStyle boxHeightStyle = ui.BoxHeightStyle.tight,
    ui.BoxWidthStyle boxWidthStyle = ui.BoxWidthStyle.tight,
    bool includePlaceholders = true,
  });

  /// The painter invoked behind the text by the plugin owning this delegate,
  /// or null if no painter is installed.
  ///
  /// The painter receives a canvas pre-translated to the covered widget's
  /// local origin and a [Size] matching the widget's box, matching the
  /// contract of `CustomPainter`. Setting a painter with a non-null
  /// `CustomPainter.repaint` [Listenable] causes the enclosing paragraph to
  /// repaint when that listenable fires; plugin authors do not need to reach
  /// for render-object APIs themselves.
  ///
  /// Other plugins covering the same widget have their own delegates and
  /// their own painter slots; writing to this one does not overwrite any of
  /// theirs.
  CustomPainter? get backgroundPainter;
  set backgroundPainter(CustomPainter? value);

  /// The painter invoked in front of the text by the plugin owning this
  /// delegate, or null if no painter is installed.
  ///
  /// See [backgroundPainter] for the repaint contract and the
  /// non-overwriting multi-plugin semantics.
  CustomPainter? get foregroundPainter;
  set foregroundPainter(CustomPainter? value);

  /// Compares this delegate to [other] by document order.
  ///
  /// Returns negative if this delegate's paragraph appears earlier in the
  /// depth-first walk of the render tree, positive if later, zero if they are
  /// the same delegate. Both delegates must currently be attached.
  ///
  /// The implementation walks the render tree to find the lowest common
  /// ancestor, so the worst-case cost is O(depth × 2). Plugin authors should
  /// avoid calling `compareTo` in tight loops; the recommended pattern is
  /// binary-search insertion when adding to an already-sorted list.
  ///
  /// Used together with the document-order `didAddText` guarantee on initial
  /// scope mount (see `TextPlugin`) for plugins that need a document-ordered
  /// list of delegates and ranges.
  @override
  int compareTo(TextDelegate other);

  /// Scrolls enclosing scrollables so that [range]'s geometry is visible.
  ///
  /// Walks the render tree via `RenderObject.showOnScreen`, so it works with
  /// any number of nested scrollables and does not require a `BuildContext`
  /// from the plugin author.
  ///
  /// Safe to call from external event handlers (e.g., a "next match" button
  /// press in a search-in-page UI). Not safe to call synchronously from
  /// `TextPlugin.didAddText`, `TextPlugin.didUpdateText`, painter `paint`, or
  /// this delegate's own `Listenable` callbacks — those fire during build,
  /// layout, or paint phases. From inside any framework-driven callback,
  /// wrap in `WidgetsBinding.instance.addPostFrameCallback(...)`.
  void ensureVisible(
    TextRange range, {
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  });
}

/// An object a `TextPluginScope` exposes so that descendant `RenderParagraph`s
/// can register a [TextDelegate] per (plugin, paragraph) pair.
///
/// Mirrors the subscribe/unsubscribe shape of `SelectionRegistrar` for
/// selectable leaves: a [RenderObject] that becomes covered by a scope calls
/// [add] once per ancestor scope (each with its own [TextDelegate]), and
/// calls [remove] when it leaves or is disposed.
///
/// Plugin authors do not interact with this type directly; they implement
/// `TextPlugin` and let the framework route delegates through their plugin.
///
/// See also:
///
///  * `SelectionRegistrar`, which this type intentionally parallels so that
///    selection and plugins coexist without sharing state.
abstract interface class TextPluginRegistrar {
  /// Registers [delegate] with this registrar.
  ///
  /// The registrar's owner (a `TextPluginScope`) is expected to fire
  /// `plugin.didAddText(delegate)` synchronously in response, so that the
  /// plugin sees the delegate before any paint pass that could observe an
  /// unset painter slot.
  void add(TextDelegate delegate);

  /// Unregisters a [delegate] previously passed to [add].
  ///
  /// The registrar's owner is expected to fire `plugin.didRemoveText(delegate)`
  /// synchronously in response.
  void remove(TextDelegate delegate);

  /// Signals that [delegate]'s underlying `RenderParagraph` has had a
  /// text-level change (equivalent to a `RenderComparison.layout` result
  /// from comparing the old span to the new span).
  ///
  /// The registrar's owner is expected to fire
  /// `plugin.didUpdateText(delegate)` synchronously in response. The same
  /// delegate instance is retained across the update — the per-plugin
  /// painters and controller wiring are not torn down.
  ///
  /// Layout-only changes (e.g., resizing the paragraph) do not go through
  /// this hook — the delegate's [Listenable] notification is the signal for
  /// painters to recompute their cached geometry in that case.
  void didUpdate(TextDelegate delegate);
}
