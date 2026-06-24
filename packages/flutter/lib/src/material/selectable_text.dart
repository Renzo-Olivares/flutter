// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// @docImport 'color_scheme.dart';
/// @docImport 'scaffold.dart';
/// @docImport 'selection_area.dart';
/// @docImport 'text_field.dart';
library;

import 'dart:ui' as ui show BoxHeightStyle, BoxWidthStyle;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

import 'adaptive_text_selection_toolbar.dart';
import 'magnifier.dart';
import 'selection_area.dart';
import 'theme.dart';

// Examples can assume:
// late BuildContext context;
// late FocusNode myFocusNode;

/// An eyeballed value that moves the cursor slightly left of where it is
/// rendered for text on Android so its positioning more accurately matches the
/// native iOS text cursor positioning.
///
/// This value is in device pixels, not logical pixels as is typically used
/// throughout the codebase.
const int iOSHorizontalOffset = -2;

/// A run of selectable text with a single style.
///
/// Consider using [SelectionArea] or [SelectableRegion] instead, which enable
/// selection on a widget subtree, including but not limited to [Text] widgets.
///
/// The [SelectableText] widget displays a string of text with a single style.
/// The string might break across multiple lines or might all be displayed on
/// the same line depending on the layout constraints.
///
/// {@youtube 560 315 https://www.youtube.com/watch?v=ZSU3ZXOs6hc}
///
/// The [style] argument is optional. When omitted, the text will use the style
/// from the closest enclosing [DefaultTextStyle]. If the given style's
/// [TextStyle.inherit] property is true (the default), the given style will
/// be merged with the closest enclosing [DefaultTextStyle]. This merging
/// behavior is useful, for example, to make the text bold while using the
/// default font family and size.
///
/// {@macro flutter.material.textfield.wantKeepAlive}
///
/// {@tool snippet}
///
/// ```dart
/// const SelectableText(
///   'Hello! How are you?',
///   textAlign: TextAlign.center,
///   style: TextStyle(fontWeight: FontWeight.bold),
/// )
/// ```
/// {@end-tool}
///
/// Using the [SelectableText.rich] constructor, the [SelectableText] widget can
/// display a paragraph with differently styled [TextSpan]s. The sample
/// that follows displays "Hello beautiful world" with different styles
/// for each word.
///
/// {@tool snippet}
///
/// ```dart
/// const SelectableText.rich(
///   TextSpan(
///     text: 'Hello', // default text style
///     children: <TextSpan>[
///       TextSpan(text: ' beautiful ', style: TextStyle(fontStyle: FontStyle.italic)),
///       TextSpan(text: 'world', style: TextStyle(fontWeight: FontWeight.bold)),
///     ],
///   ),
/// )
/// ```
/// {@end-tool}
///
/// ## Interactivity
///
/// To make [SelectableText] react to touch events, use callback [onTap] to achieve
/// the desired behavior.
///
/// ## Scrolling Considerations
///
/// If this [SelectableText] is not a descendant of [Scaffold] and is being used
/// within a [Scrollable] or nested [Scrollable]s, consider placing a
/// [ScrollNotificationObserver] above the root [Scrollable] that contains this
/// [SelectableText] to ensure proper scroll coordination for [SelectableText]
/// and its components like [TextSelectionOverlay].
///
/// See also:
///
///  * [Text], which is the non selectable version of this widget.
///  * [TextField], which is the editable version of this widget.
///  * [SelectionArea], which enables the selection of multiple [Text] widgets
///    and of other widgets.
class SelectableText extends StatefulWidget {
  /// Creates a selectable text widget.
  ///
  /// If the [style] argument is null, the text will use the style from the
  /// closest enclosing [DefaultTextStyle].
  ///

  /// If the [showCursor], [autofocus], [dragStartBehavior],
  /// [selectionHeightStyle], [selectionWidthStyle] and [data] arguments are
  /// specified, the [maxLines] argument must be greater than zero.
  const SelectableText(
    String this.data, {
    super.key,
    this.focusNode,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    @Deprecated(
      'Use textScaler instead. '
      'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
      'This feature was deprecated after v3.12.0-2.0.pre.',
    )
    this.textScaleFactor,
    this.textScaler,
    this.showCursor = false,
    this.autofocus = false,
    @Deprecated(
      'Use `contextMenuBuilder` instead. '
      'This feature was deprecated after v3.3.0-0.5.pre.',
    )
    this.toolbarOptions,
    this.minLines,
    this.maxLines,
    this.cursorWidth = 2.0,
    this.cursorHeight,
    this.cursorRadius,
    this.cursorColor,
    this.selectionColor,
    this.selectionHeightStyle,
    this.selectionWidthStyle,
    this.dragStartBehavior = DragStartBehavior.start,
    this.enableInteractiveSelection = true,
    this.selectionControls,
    this.onTap,
    this.scrollPhysics,
    this.scrollBehavior,
    this.semanticsLabel,
    this.textHeightBehavior,
    this.textWidthBasis,
    this.onSelectionChanged,
    this.contextMenuBuilder = _defaultContextMenuBuilder,
    this.magnifierConfiguration,
  }) : assert(maxLines == null || maxLines > 0),
       assert(minLines == null || minLines > 0),
       assert(
         (maxLines == null) || (minLines == null) || (maxLines >= minLines),
         "minLines can't be greater than maxLines",
       ),
       assert(
         textScaler == null || textScaleFactor == null,
         'textScaleFactor is deprecated and cannot be specified when textScaler is specified.',
       ),
       textSpan = null;

  /// Creates a selectable text widget with a [TextSpan].
  ///
  /// The [TextSpan.children] attribute of the [textSpan] parameter must only
  /// contain [TextSpan]s. Other types of [InlineSpan] are not allowed.
  const SelectableText.rich(
    TextSpan this.textSpan, {
    super.key,
    this.focusNode,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    @Deprecated(
      'Use textScaler instead. '
      'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
      'This feature was deprecated after v3.12.0-2.0.pre.',
    )
    this.textScaleFactor,
    this.textScaler,
    this.showCursor = false,
    this.autofocus = false,
    @Deprecated(
      'Use `contextMenuBuilder` instead. '
      'This feature was deprecated after v3.3.0-0.5.pre.',
    )
    this.toolbarOptions,
    this.minLines,
    this.maxLines,
    this.cursorWidth = 2.0,
    this.cursorHeight,
    this.cursorRadius,
    this.cursorColor,
    this.selectionColor,
    this.selectionHeightStyle,
    this.selectionWidthStyle,
    this.dragStartBehavior = DragStartBehavior.start,
    this.enableInteractiveSelection = true,
    this.selectionControls,
    this.onTap,
    this.scrollPhysics,
    this.scrollBehavior,
    this.semanticsLabel,
    this.textHeightBehavior,
    this.textWidthBasis,
    this.onSelectionChanged,
    this.contextMenuBuilder = _defaultContextMenuBuilder,
    this.magnifierConfiguration,
  }) : assert(maxLines == null || maxLines > 0),
       assert(minLines == null || minLines > 0),
       assert(
         (maxLines == null) || (minLines == null) || (maxLines >= minLines),
         "minLines can't be greater than maxLines",
       ),
       assert(
         textScaler == null || textScaleFactor == null,
         'textScaleFactor is deprecated and cannot be specified when textScaler is specified.',
       ),
       data = null;

  /// The text to display.
  ///
  /// This will be null if a [textSpan] is provided instead.
  final String? data;

  /// The text to display as a [TextSpan].
  ///
  /// This will be null if [data] is provided instead.
  final TextSpan? textSpan;

  /// Defines the focus for this widget.
  ///
  /// Text is only selectable when widget is focused.
  ///
  /// The [focusNode] is a long-lived object that's typically managed by a
  /// [StatefulWidget] parent. See [FocusNode] for more information.
  ///
  /// To give the focus to this widget, provide a [focusNode] and then
  /// use the current [FocusScope] to request the focus:
  ///
  /// ```dart
  /// FocusScope.of(context).requestFocus(myFocusNode);
  /// ```
  ///
  /// This happens automatically when the widget is tapped.
  ///
  /// To be notified when the widget gains or loses the focus, add a listener
  /// to the [focusNode]:
  ///
  /// ```dart
  /// myFocusNode.addListener(() { print(myFocusNode.hasFocus); });
  /// ```
  ///
  /// If null, this widget will create its own [FocusNode] with
  /// [FocusNode.skipTraversal] parameter set to `true`, which causes the widget
  /// to be skipped over during focus traversal.
  final FocusNode? focusNode;

  /// The style to use for the text.
  ///
  /// If null, defaults [DefaultTextStyle] of context.
  final TextStyle? style;

  /// {@macro flutter.widgets.editableText.strutStyle}
  final StrutStyle? strutStyle;

  /// {@macro flutter.widgets.editableText.textAlign}
  final TextAlign? textAlign;

  /// {@macro flutter.widgets.editableText.textDirection}
  final TextDirection? textDirection;

  /// {@macro flutter.widgets.editableText.textScaleFactor}
  @Deprecated(
    'Use textScaler instead. '
    'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
    'This feature was deprecated after v3.12.0-2.0.pre.',
  )
  final double? textScaleFactor;

  /// {@macro flutter.painting.textPainter.textScaler}
  final TextScaler? textScaler;

  /// {@macro flutter.widgets.editableText.autofocus}
  final bool autofocus;

  /// {@macro flutter.widgets.editableText.minLines}
  final int? minLines;

  /// {@macro flutter.widgets.editableText.maxLines}
  final int? maxLines;

  /// {@macro flutter.widgets.editableText.showCursor}
  final bool showCursor;

  /// {@macro flutter.widgets.editableText.cursorWidth}
  final double cursorWidth;

  /// {@macro flutter.widgets.editableText.cursorHeight}
  final double? cursorHeight;

  /// {@macro flutter.widgets.editableText.cursorRadius}
  final Radius? cursorRadius;

  /// The color of the cursor.
  ///
  /// The cursor indicates the current text insertion point.
  ///
  /// If null then [DefaultSelectionStyle.cursorColor] is used. If that is also
  /// null and [ThemeData.platform] is [TargetPlatform.iOS] or
  /// [TargetPlatform.macOS], then [CupertinoThemeData.primaryColor] is used.
  /// Otherwise [ColorScheme.primary] of [ThemeData.colorScheme] is used.
  final Color? cursorColor;

  /// The color to use when painting the selection.
  ///
  /// If this property is null, this widget gets the selection color from the
  /// inherited [DefaultSelectionStyle] (if any); if none, the selection
  /// color is derived from the [CupertinoThemeData.primaryColor] on
  /// Apple platforms and [ColorScheme.primary] of [ThemeData.colorScheme] on
  /// other platforms.
  final Color? selectionColor;

  /// Controls how tall the selection highlight boxes are computed to be.
  ///
  /// See [ui.BoxHeightStyle] for details on available styles.
  final ui.BoxHeightStyle? selectionHeightStyle;

  /// Controls how wide the selection highlight boxes are computed to be.
  ///
  /// See [ui.BoxWidthStyle] for details on available styles.
  final ui.BoxWidthStyle? selectionWidthStyle;

  /// {@macro flutter.widgets.editableText.enableInteractiveSelection}
  final bool enableInteractiveSelection;

  /// {@macro flutter.widgets.editableText.selectionControls}
  final TextSelectionControls? selectionControls;

  /// {@macro flutter.widgets.scrollable.dragStartBehavior}
  final DragStartBehavior dragStartBehavior;

  /// Configuration of toolbar options.
  ///
  /// Paste and cut will be disabled regardless.
  ///
  /// If not set, select all and copy will be enabled by default.
  @Deprecated(
    'Use `contextMenuBuilder` instead. '
    'This feature was deprecated after v3.3.0-0.5.pre.',
  )
  final ToolbarOptions? toolbarOptions;

  /// {@macro flutter.widgets.editableText.selectionEnabled}
  bool get selectionEnabled => enableInteractiveSelection;

  /// Called when the user taps on this selectable text.
  ///
  /// The selectable text builds a [GestureDetector] to handle input events like tap,
  /// to trigger focus requests, to move the caret, adjust the selection, etc.
  /// Handling some of those events by wrapping the selectable text with a competing
  /// GestureDetector is problematic.
  ///
  /// To unconditionally handle taps, without interfering with the selectable text's
  /// internal gesture detector, provide this callback.
  ///
  /// To be notified when the text field gains or loses the focus, provide a
  /// [focusNode] and add a listener to that.
  ///
  /// To listen to arbitrary pointer events without competing with the
  /// selectable text's internal gesture detector, use a [Listener].
  final GestureTapCallback? onTap;

  /// {@macro flutter.widgets.editableText.scrollPhysics}
  final ScrollPhysics? scrollPhysics;

  /// {@macro flutter.widgets.editableText.scrollBehavior}
  final ScrollBehavior? scrollBehavior;

  /// {@macro flutter.widgets.Text.semanticsLabel}
  final String? semanticsLabel;

  /// {@macro dart.ui.textHeightBehavior}
  final TextHeightBehavior? textHeightBehavior;

  /// {@macro flutter.painting.textPainter.textWidthBasis}
  final TextWidthBasis? textWidthBasis;

  /// {@macro flutter.widgets.editableText.onSelectionChanged}
  final SelectionChangedCallback? onSelectionChanged;

  /// {@macro flutter.widgets.EditableText.contextMenuBuilder}
  final EditableTextContextMenuBuilder? contextMenuBuilder;

  static Widget _defaultContextMenuBuilder(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    return AdaptiveTextSelectionToolbar.editableText(editableTextState: editableTextState);
  }

  /// The configuration for the magnifier used when the text is selected.
  ///
  /// By default, builds a [CupertinoTextMagnifier] on iOS and [TextMagnifier]
  /// on Android, and builds nothing on all other platforms. To suppress the
  /// magnifier, consider passing [TextMagnifierConfiguration.disabled].
  ///
  /// {@macro flutter.widgets.magnifier.intro}
  final TextMagnifierConfiguration? magnifierConfiguration;

  @override
  State<SelectableText> createState() => _SelectableTextState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<String>('data', data, defaultValue: null));
    properties.add(
      DiagnosticsProperty<String>('semanticsLabel', semanticsLabel, defaultValue: null),
    );
    properties.add(DiagnosticsProperty<FocusNode>('focusNode', focusNode, defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle>('style', style, defaultValue: null));
    properties.add(DiagnosticsProperty<bool>('autofocus', autofocus, defaultValue: false));
    properties.add(DiagnosticsProperty<bool>('showCursor', showCursor, defaultValue: false));
    properties.add(IntProperty('minLines', minLines, defaultValue: null));
    properties.add(IntProperty('maxLines', maxLines, defaultValue: null));
    properties.add(EnumProperty<TextAlign>('textAlign', textAlign, defaultValue: null));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection, defaultValue: null));
    properties.add(DoubleProperty('textScaleFactor', textScaleFactor, defaultValue: null));
    properties.add(DiagnosticsProperty<TextScaler>('textScaler', textScaler, defaultValue: null));
    properties.add(DoubleProperty('cursorWidth', cursorWidth, defaultValue: 2.0));
    properties.add(DoubleProperty('cursorHeight', cursorHeight, defaultValue: null));
    properties.add(DiagnosticsProperty<Radius>('cursorRadius', cursorRadius, defaultValue: null));
    properties.add(DiagnosticsProperty<Color>('cursorColor', cursorColor, defaultValue: null));
    properties.add(
      DiagnosticsProperty<Color>('selectionColor', selectionColor, defaultValue: null),
    );
    properties.add(
      FlagProperty(
        'selectionEnabled',
        value: selectionEnabled,
        defaultValue: true,
        ifFalse: 'selection disabled',
      ),
    );
    properties.add(
      DiagnosticsProperty<TextSelectionControls>(
        'selectionControls',
        selectionControls,
        defaultValue: null,
      ),
    );
    properties.add(
      DiagnosticsProperty<ScrollPhysics>('scrollPhysics', scrollPhysics, defaultValue: null),
    );
    properties.add(
      DiagnosticsProperty<ScrollBehavior>('scrollBehavior', scrollBehavior, defaultValue: null),
    );
    properties.add(
      DiagnosticsProperty<TextHeightBehavior>(
        'textHeightBehavior',
        textHeightBehavior,
        defaultValue: null,
      ),
    );
  }
}

class _SelectableTextState extends State<SelectableText> {
  FocusNode? _focusNode;
  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_focusNode ??= FocusNode(skipTraversal: true));

  late final SelectionListenerNotifier _selectionNotifier;

  // To match EditableText's internal scrollable.
  bool get _isMultiline => widget.maxLines != 1;

  @override
  void initState() {
    super.initState();
    _selectionNotifier = SelectionListenerNotifier();
    _selectionNotifier.addListener(_handleSelectionDetailsChanged);
    if (widget.autofocus) {
      _effectiveFocusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _selectionNotifier.removeListener(_handleSelectionDetailsChanged);
    _selectionNotifier.dispose();
    _focusNode?.dispose();
    super.dispose();
  }

  void _handleSelectionDetailsChanged() {
    if (widget.onSelectionChanged == null) {
      return;
    }
    if (_selectionNotifier.registered) {
      final SelectionDetails details = _selectionNotifier.selection;
      final SelectedContentRange? range = details.range;
      if (range != null) {
        final selection = TextSelection(
          baseOffset: range.startOffset,
          extentOffset: range.endOffset,
        );
        widget.onSelectionChanged!(selection, null);
      } else {
        widget.onSelectionChanged!(const TextSelection.collapsed(offset: -1), null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMediaQuery(context));
    assert(debugCheckHasDirectionality(context));
    assert(
      !(widget.style != null &&
          !widget.style!.inherit &&
          (widget.style!.fontSize == null || widget.style!.textBaseline == null)),
      'inherit false style must supply fontSize and textBaseline',
    );

    final DefaultSelectionStyle selectionStyle = DefaultSelectionStyle.of(context);
    final FocusNode focusNode = _effectiveFocusNode;

    final TextSelectionControls? textSelectionControls = widget.selectionControls;

    final DefaultTextStyle defaultTextStyle = DefaultTextStyle.of(context);
    TextStyle? effectiveTextStyle = widget.style;
    if (effectiveTextStyle == null || effectiveTextStyle.inherit) {
      effectiveTextStyle = defaultTextStyle.style.merge(widget.style ?? widget.textSpan?.style);
    }
    final TextScaler? effectiveScaler =
        widget.textScaler ??
        switch (widget.textScaleFactor) {
          null => null,
          final double textScaleFactor => TextScaler.linear(textScaleFactor),
        };

    final Widget textWidget = widget.textSpan != null
        ? Text.rich(
            widget.textSpan!,
            style: effectiveTextStyle,
            strutStyle: widget.strutStyle,
            textAlign: widget.textAlign ?? defaultTextStyle.textAlign ?? TextAlign.start,
            textDirection: widget.textDirection,
            textScaler: effectiveScaler,
            maxLines: widget.maxLines ?? defaultTextStyle.maxLines,
            selectionColor: widget.selectionColor ?? selectionStyle.selectionColor,
            textWidthBasis: widget.textWidthBasis ?? defaultTextStyle.textWidthBasis,
            textHeightBehavior: widget.textHeightBehavior ?? defaultTextStyle.textHeightBehavior,
            semanticsLabel: widget.semanticsLabel,
          )
        : Text(
            widget.data!,
            style: effectiveTextStyle,
            strutStyle: widget.strutStyle,
            textAlign: widget.textAlign ?? defaultTextStyle.textAlign ?? TextAlign.start,
            textDirection: widget.textDirection,
            textScaler: effectiveScaler,
            maxLines: widget.maxLines ?? defaultTextStyle.maxLines,
            selectionColor: widget.selectionColor ?? selectionStyle.selectionColor,
            textWidthBasis: widget.textWidthBasis ?? defaultTextStyle.textWidthBasis,
            textHeightBehavior: widget.textHeightBehavior ?? defaultTextStyle.textHeightBehavior,
            semanticsLabel: widget.semanticsLabel,
          );

    var textWidgetWithTap = textWidget;
    if (widget.onTap != null) {
      textWidgetWithTap = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onTap,
        child: textWidget,
      );
    }

    Widget scrollableChild = ScrollConfiguration(
      // To match EditableText's internal scrollable.
      behavior:
          widget.scrollBehavior ??
          ScrollConfiguration.of(context).copyWith(scrollbars: _isMultiline, overscroll: false),
      child: SingleChildScrollView(
        // To match EditableText's internal scrollable.
        scrollDirection: _isMultiline ? Axis.vertical : Axis.horizontal,
        // end.
        physics: widget.scrollPhysics,
        dragStartBehavior: widget.dragStartBehavior,
        child: textWidgetWithTap,
      ),
    );

    if (widget.scrollBehavior != null) {
      scrollableChild = ScrollConfiguration(
        behavior: widget.scrollBehavior!,
        child: scrollableChild,
      );
    }

    var result = scrollableChild;

    if (widget.enableInteractiveSelection) {
      result = SelectionArea(
        focusNode: focusNode,
        selectionControls: textSelectionControls,
        magnifierConfiguration: widget.magnifierConfiguration,
        contextMenuBuilder: _adaptContextMenuBuilder,
        child: SelectionListener(selectionNotifier: _selectionNotifier, child: scrollableChild),
      );
    } else {
      result = SelectionContainer.disabled(child: scrollableChild);
    }

    return Semantics(
      label: widget.semanticsLabel,
      excludeSemantics: widget.semanticsLabel != null,
      onLongPress: () {
        focusNode.requestFocus();
      },
      child: result,
    );
  }

  Widget _adaptContextMenuBuilder(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    // Phase 1: Note that we cannot easily adapt EditableTextContextMenuBuilder to SelectableRegionContextMenuBuilder.
    // We fall back to the default SelectableRegion context menu.
    return AdaptiveTextSelectionToolbar.selectableRegion(
      selectableRegionState: selectableRegionState,
    );
  }
}
