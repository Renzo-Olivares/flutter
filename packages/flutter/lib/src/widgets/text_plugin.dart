// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// @docImport 'package:flutter/material.dart';
///
/// @docImport 'basic.dart';
/// @docImport 'text.dart';
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'framework.dart';

/// A plugin installed over a subtree by a [TextPluginScope], which receives
/// one [TextDelegate] per `Text` or `RichText` widget in that subtree.
///
/// Plugin authors typically inspect the delegate's [TextDelegate.text],
/// compute geometry via [TextDelegate.getBoxesForSelection], and assign a
/// painter to [TextDelegate.backgroundPainter] or
/// [TextDelegate.foregroundPainter] in [didAddText]. Because each plugin gets
/// its own delegate per paragraph, writing to the painter slot on this
/// plugin's delegate does not affect any other plugin covering the same
/// paragraph — decorations from multiple plugins stack cleanly.
///
/// {@tool snippet}
/// A minimal plugin that underlines every URL in every `Text` below it:
///
/// ```dart
/// class LinkifyPlugin extends TextPlugin {
///   const LinkifyPlugin();
///
///   @override
///   void didAddText(TextDelegate delegate) {
///     // Scan delegate.text for URLs, build a painter, assign
///     // delegate.backgroundPainter = ....
///   }
///
///   @override
///   void didUpdateText(TextDelegate delegate) => didAddText(delegate);
///
///   @override
///   void didRemoveText(TextDelegate delegate) {
///     delegate.backgroundPainter = null;
///   }
/// }
/// ```
/// {@end-tool}
///
/// See also:
///
///  * [TextPluginScope], which installs a plugin over a subtree.
///  * [TextDelegate], the per-paragraph object passed to the lifecycle hooks.
abstract base class TextPlugin {
  /// Abstract const constructor. This constructor enables subclasses to
  /// provide const constructors so that they can be used in const expressions.
  const TextPlugin();

  /// Called when a `Text` or `RichText` widget enters the subtree covered by
  /// this plugin.
  ///
  /// Plugins typically inspect [TextDelegate.text], compute geometry, and
  /// assign painters to the delegate's [TextDelegate.backgroundPainter] or
  /// [TextDelegate.foregroundPainter] slots here. [TextDelegate.ensureVisible]
  /// and [TextDelegate.getBoxesForSelection] must not be called synchronously
  /// from this hook — the covered paragraph has not yet completed layout for
  /// the lifecycle event; register the painter instead and query geometry
  /// from the painter's own `paint` pass.
  ///
  /// The [delegate] is owned by this plugin alone: two plugins covering the
  /// same paragraph receive two distinct `TextDelegate` instances backed by
  /// the same underlying `RenderParagraph`.
  void didAddText(TextDelegate delegate);

  /// Called when the text in a `Text` or `RichText` widget covered by this
  /// plugin changes (i.e., a rebuild resolved to a layout-level difference on
  /// the underlying span).
  ///
  /// The same [delegate] instance is retained across the update — plugin
  /// state keyed on `identical(oldDelegate, newDelegate)` is preserved.
  void didUpdateText(TextDelegate delegate);

  /// Called when a `Text` or `RichText` widget leaves the subtree covered by
  /// this plugin.
  ///
  /// The framework tears down painters and listeners attached through
  /// [delegate] after this call returns; a plugin that wants to run any
  /// teardown beyond "clear my painter" should do so here.
  void didRemoveText(TextDelegate delegate);

  /// Called by the framework when the enclosing [TextPluginScope] rebuilds
  /// with a new plugin instance that is not identical to the previous one.
  ///
  /// Return `false` to keep existing [TextDelegate]s in place and skip the
  /// [didRemoveText] / [didAddText] cycle that would otherwise fire on every
  /// registered delegate. The default returns `true`, which is the safe
  /// behavior — every new instance is treated as a new plugin.
  ///
  /// Plugin authors with mutable configuration managed by a controller or
  /// other `Listenable` should override this to return whether the
  /// controller identity actually changed, so that a new plugin instance per
  /// keystroke (common when a `TextPluginScope` rebuilds from a parent that
  /// rebuilds on input) does not retear every delegate's decoration:
  ///
  /// ```dart
  /// @override
  /// bool shouldUpdate(TextPlugin oldPlugin) =>
  ///     oldPlugin is! SearchInPagePlugin || oldPlugin.controller != controller;
  /// ```
  ///
  /// Modeled on `CustomPainter.shouldRepaint` and `CustomClipper.shouldReclip`
  /// — both Flutter delegate-like types with methods, for which `==`/
  /// `hashCode` is a poor fit.
  bool shouldUpdate(TextPlugin oldPlugin) => true;
}

/// A widget that installs a [TextPlugin] over its descendant subtree.
///
/// Any `Text` or `RichText` inside [child] is registered with this scope's
/// plugin on mount and unregistered on removal. Plugins compose by nesting
/// scopes: each scope contributes one `TextDelegate` per descendant
/// paragraph, and painters from different scopes stack in leaf-first order
/// (the innermost scope's painter draws first / at the back; the outermost
/// scope's painter draws last / on top). This matches the natural wrapping
/// where broad, app-wide plugins like `SelectableRegion` sit near the root
/// and paint above narrowly-scoped feature plugins nested inside.
///
/// ```dart
/// TextPluginScope(
///   plugin: const LinkifyPlugin(),
///   child: const Column(
///     children: <Widget>[
///       Text('Visit https://flutter.dev for docs.'),
///       Text('See https://api.flutter.dev for the API.'),
///     ],
///   ),
/// )
/// ```
///
/// See also:
///
///  * [TextPlugin], which defines the lifecycle hooks the scope routes to.
///  * [TextDelegate], the per-paragraph object that plugins receive.
final class TextPluginScope extends StatefulWidget {
  /// Creates a scope that covers [child] with [plugin].
  const TextPluginScope({super.key, required this.plugin, required this.child});

  /// The plugin that observes descendant `Text` and `RichText` widgets.
  final TextPlugin plugin;

  /// The widget below this one in the tree, whose descendant paragraphs are
  /// covered by [plugin].
  ///
  /// {@macro flutter.widgets.ProxyWidget.child}
  final Widget child;

  /// Returns the chain of enclosing [TextPluginRegistrar]s above [context],
  /// ordered from outermost at index 0 to innermost at the last index, or
  /// `null` if no enclosing [TextPluginScope] exists.
  ///
  /// Registers [context] as a dependent on the scope chain, so the caller
  /// rebuilds when a scope is inserted, removed, or replaced.
  static List<TextPluginRegistrar>? maybeRegistrarsOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_TextPluginScopeMarker>()
        ?.registrars;
  }

  @override
  State<TextPluginScope> createState() => _TextPluginScopeState();
}

class _TextPluginScopeState extends State<TextPluginScope> implements TextPluginRegistrar {
  final Set<TextDelegate> _delegates = <TextDelegate>{};

  @override
  void add(TextDelegate delegate) {
    final bool added = _delegates.add(delegate);
    assert(added, 'TextDelegate was already registered with this scope.');
    widget.plugin.didAddText(delegate);
  }

  @override
  void remove(TextDelegate delegate) {
    final bool removed = _delegates.remove(delegate);
    assert(removed, 'TextDelegate was not registered with this scope.');
    widget.plugin.didRemoveText(delegate);
  }

  @override
  void didUpdate(TextDelegate delegate) {
    assert(
      _delegates.contains(delegate),
      'TextDelegate was not registered with this scope.',
    );
    widget.plugin.didUpdateText(delegate);
  }

  @override
  void didUpdateWidget(TextPluginScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.plugin, widget.plugin)) {
      return;
    }
    if (!widget.plugin.shouldUpdate(oldWidget.plugin)) {
      return;
    }
    for (final TextDelegate delegate in _delegates) {
      oldWidget.plugin.didRemoveText(delegate);
      widget.plugin.didAddText(delegate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final outer = TextPluginScope.maybeRegistrarsOf(context);
    final registrars = <TextPluginRegistrar>[...?outer, this];
    return _TextPluginScopeMarker(registrars: registrars, child: widget.child);
  }
}

/// An [InheritedWidget] that carries the chain of ancestor
/// [TextPluginRegistrar]s down the tree.
///
/// Each [TextPluginScope] builds one of these with a list that appends its
/// own registrar to the list exposed by the next outer marker. `RichText`
/// in `basic.dart` reads the chain via [TextPluginScope.maybeRegistrarsOf]
/// and hands it to the underlying `RenderParagraph`, which materializes one
/// [TextDelegate] per registrar and forwards lifecycle callbacks through
/// each.
final class _TextPluginScopeMarker extends InheritedWidget {
  const _TextPluginScopeMarker({required this.registrars, required super.child});

  /// The chain of enclosing [TextPluginRegistrar]s at this point in the tree,
  /// ordered from outermost at index 0 to innermost at the last index.
  final List<TextPluginRegistrar> registrars;

  @override
  bool updateShouldNotify(_TextPluginScopeMarker oldWidget) =>
      !listEquals(registrars, oldWidget.registrars);
}
