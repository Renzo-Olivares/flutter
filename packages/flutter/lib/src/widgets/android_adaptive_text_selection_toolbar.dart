// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/rendering.dart';
import 'package:flutter/src/foundation/platform.dart';

import 'android_desktop_text_selection_toolbar.dart';
import 'android_desktop_text_selection_toolbar_button.dart';
import 'android_text_selection_toolbar.dart';
import 'android_text_selection_toolbar_text_button.dart';
import 'apple_desktop_text_selection_toolbar.dart';
import 'apple_desktop_text_selection_toolbar_button.dart';
import 'apple_text_selection_toolbar.dart';
import 'apple_text_selection_toolbar_button.dart';
import 'basic.dart';
import 'context_menu_button_item.dart';
import 'debug.dart';
import 'editable_text.dart';
import 'framework.dart';
import 'localizations.dart';
import 'selectable_region.dart';
import 'text.dart';
import 'text_selection.dart';
import 'text_selection_toolbar_anchors.dart';

/// The default context menu for text selection for the current platform.
///
/// {@template flutter.material.AdaptiveTextSelectionToolbar.contextMenuBuilders}
/// Typically, this widget would be passed to `contextMenuBuilder` in a
/// supported parent widget, such as:
///
/// * [EditableText.contextMenuBuilder]
/// * [SelectableRegion.contextMenuBuilder]
/// {@endtemplate}
///
/// See also:
///
/// * [EditableText.getEditableButtonItems], which returns the default
///   [ContextMenuButtonItem]s for [EditableText] on the platform.
/// * [AndroidAdaptiveTextSelectionToolbar.getAdaptiveButtons], which builds the button
///   Widgets for the current platform given [ContextMenuButtonItem]s.
/// * [AppleAdaptiveTextSelectionToolbar], which does the same thing as this
///   widget but only for Cupertino context menus.
/// * [AndroidTextSelectionToolbar], the default toolbar for Android.
/// * [AndroidDesktopTextSelectionToolbar], the default toolbar for desktop platforms
///    other than MacOS.
/// * [AppleTextSelectionToolbar], the default toolbar for iOS.
/// * [AppleDesktopTextSelectionToolbar], the default toolbar for MacOS.
class AndroidAdaptiveTextSelectionToolbar extends StatelessWidget {
  /// Create an instance of [AndroidAdaptiveTextSelectionToolbar] with the
  /// given [children].
  ///
  /// See also:
  ///
  /// {@template flutter.material.AdaptiveTextSelectionToolbar.buttonItems}
  /// * [AndroidAdaptiveTextSelectionToolbar.buttonItems], which takes a list of
  ///   [ContextMenuButtonItem]s instead of [children] widgets.
  /// {@endtemplate}
  /// {@template flutter.material.AdaptiveTextSelectionToolbar.editable}
  /// * [AndroidAdaptiveTextSelectionToolbar.editable], which builds the default
  ///   children for an editable field.
  /// {@endtemplate}
  /// {@template flutter.material.AdaptiveTextSelectionToolbar.editableText}
  /// * [AndroidAdaptiveTextSelectionToolbar.editableText], which builds the default
  ///   children for an [EditableText].
  /// {@endtemplate}
  /// {@template flutter.material.AdaptiveTextSelectionToolbar.selectable}
  /// * [AndroidAdaptiveTextSelectionToolbar.selectable], which builds the default
  ///   children for content that is selectable but not editable.
  /// {@endtemplate}
  const AndroidAdaptiveTextSelectionToolbar({super.key, required this.children, required this.anchors})
    : buttonItems = null;

  /// Create an instance of [AndroidAdaptiveTextSelectionToolbar] whose children will
  /// be built from the given [buttonItems].
  ///
  /// See also:
  ///
  /// {@template flutter.material.AdaptiveTextSelectionToolbar.new}
  /// * [AndroidAdaptiveTextSelectionToolbar.new], which takes the children directly as
  ///   a list of widgets.
  /// {@endtemplate}
  /// {@macro flutter.material.AdaptiveTextSelectionToolbar.editable}
  /// {@macro flutter.material.AdaptiveTextSelectionToolbar.editableText}
  /// {@macro flutter.material.AdaptiveTextSelectionToolbar.selectable}
  const AndroidAdaptiveTextSelectionToolbar.buttonItems({
    super.key,
    required this.buttonItems,
    required this.anchors,
  }) : children = null;

  /// Create an instance of [AndroidAdaptiveTextSelectionToolbar] with the default
  /// children for an editable field.
  ///
  /// If an on* callback parameter is null, then its corresponding button will
  /// not be built.
  ///
  /// These callbacks are called when their corresponding button is activated
  /// and only then. For example, `onPaste` is called when the user taps the
  /// "Paste" button in the context menu and not when the user pastes with the
  /// keyboard.
  ///
  /// See also:
  ///
  /// {@macro flutter.material.AdaptiveTextSelectionToolbar.new}
  /// {@macro flutter.material.AdaptiveTextSelectionToolbar.editableText}
  /// {@macro flutter.material.AdaptiveTextSelectionToolbar.buttonItems}
  /// {@macro flutter.material.AdaptiveTextSelectionToolbar.selectable}
  AndroidAdaptiveTextSelectionToolbar.editable({
    super.key,
    required ClipboardStatus clipboardStatus,
    required VoidCallback? onCopy,
    required VoidCallback? onCut,
    required VoidCallback? onPaste,
    required VoidCallback? onSelectAll,
    required VoidCallback? onLookUp,
    required VoidCallback? onSearchWeb,
    required VoidCallback? onShare,
    required VoidCallback? onLiveTextInput,
    required this.anchors,
  }) : children = null,
       buttonItems = EditableText.getEditableButtonItems(
         clipboardStatus: clipboardStatus,
         onCopy: onCopy,
         onCut: onCut,
         onPaste: onPaste,
         onSelectAll: onSelectAll,
         onLookUp: onLookUp,
         onSearchWeb: onSearchWeb,
         onShare: onShare,
         onLiveTextInput: onLiveTextInput,
       );

  /// Create an instance of [AndroidAdaptiveTextSelectionToolbar] with the default
  /// children for an [EditableText].
  ///
  /// See also:
  ///
  /// {@macro flutter.material.AdaptiveTextSelectionToolbar.new}
  /// {@macro flutter.material.AdaptiveTextSelectionToolbar.editable}
  /// {@macro flutter.material.AdaptiveTextSelectionToolbar.buttonItems}
  /// {@macro flutter.material.AdaptiveTextSelectionToolbar.selectable}
  AndroidAdaptiveTextSelectionToolbar.editableText({
    super.key,
    required EditableTextState editableTextState,
  }) : children = null,
       buttonItems = editableTextState.contextMenuButtonItems,
       anchors = editableTextState.contextMenuAnchors;

  /// Create an instance of [AndroidAdaptiveTextSelectionToolbar] with the default
  /// children for selectable, but not editable, content.
  ///
  /// See also:
  ///
  /// {@macro flutter.material.AdaptiveTextSelectionToolbar.new}
  /// {@macro flutter.material.AdaptiveTextSelectionToolbar.buttonItems}
  /// {@macro flutter.material.AdaptiveTextSelectionToolbar.editable}
  /// {@macro flutter.material.AdaptiveTextSelectionToolbar.editableText}
  AndroidAdaptiveTextSelectionToolbar.selectable({
    super.key,
    required VoidCallback onCopy,
    required VoidCallback onSelectAll,
    required VoidCallback? onShare,
    required SelectionGeometry selectionGeometry,
    required this.anchors,
  }) : children = null,
       buttonItems = SelectableRegion.getSelectableButtonItems(
         selectionGeometry: selectionGeometry,
         onCopy: onCopy,
         onSelectAll: onSelectAll,
         onShare: onShare,
       );

  /// Create an instance of [AndroidAdaptiveTextSelectionToolbar] with the default
  /// children for a [SelectableRegion].
  ///
  /// See also:
  ///
  /// {@macro flutter.material.AdaptiveTextSelectionToolbar.new}
  /// {@macro flutter.material.AdaptiveTextSelectionToolbar.buttonItems}
  /// {@macro flutter.material.AdaptiveTextSelectionToolbar.editable}
  /// {@macro flutter.material.AdaptiveTextSelectionToolbar.editableText}
  /// {@macro flutter.material.AdaptiveTextSelectionToolbar.selectable}
  AndroidAdaptiveTextSelectionToolbar.selectableRegion({
    super.key,
    required SelectableRegionState selectableRegionState,
  }) : children = null,
       buttonItems = selectableRegionState.contextMenuButtonItems,
       anchors = selectableRegionState.contextMenuAnchors;

  /// {@template flutter.material.AdaptiveTextSelectionToolbar.buttonItems}
  /// The [ContextMenuButtonItem]s that will be turned into the correct button
  /// widgets for the current platform.
  /// {@endtemplate}
  final List<ContextMenuButtonItem>? buttonItems;

  /// The children of the toolbar, typically buttons.
  final List<Widget>? children;

  /// {@template flutter.material.AdaptiveTextSelectionToolbar.anchors}
  /// The location on which to anchor the menu.
  /// {@endtemplate}
  final TextSelectionToolbarAnchors anchors;

  /// Returns the default button label String for the button of the given
  /// [ContextMenuButtonType] on any platform.
  static String getButtonLabel(BuildContext context, ContextMenuButtonItem buttonItem) {
    if (buttonItem.label != null) {
      return buttonItem.label!;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppleTextSelectionToolbarButton.getButtonLabel(context, buttonItem);
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        assert(debugCheckHasWidgetsLocalizations(context));
        final WidgetsLocalizations localizations = WidgetsLocalizations.of(context);
        return switch (buttonItem.type) {
          ContextMenuButtonType.cut => localizations.cutButtonLabel,
          ContextMenuButtonType.copy => localizations.copyButtonLabel,
          ContextMenuButtonType.paste => localizations.pasteButtonLabel,
          ContextMenuButtonType.selectAll => localizations.selectAllButtonLabel,
          ContextMenuButtonType.delete => 'delete',// TODO(Renzo-Olivares): add localizations.deleteButtonTooltip.toUpperCase(),
          ContextMenuButtonType.lookUp => localizations.lookUpButtonLabel,
          ContextMenuButtonType.searchWeb => localizations.searchWebButtonLabel,
          ContextMenuButtonType.share => localizations.shareButtonLabel,
          ContextMenuButtonType.liveTextInput => 'scan',// TODO(Renzo-Olivares): add localizations.scanTextButtonLabel,
          ContextMenuButtonType.custom => '',
        };
    }
  }

  /// Returns a List of Widgets generated by turning [buttonItems] into the
  /// default context menu buttons for the current platform.
  ///
  /// This is useful when building a text selection toolbar with the default
  /// button appearance for the given platform, but where the toolbar and/or the
  /// button actions and labels may be custom.
  ///
  /// {@tool dartpad}
  /// This sample demonstrates how to use `getAdaptiveButtons` to generate
  /// default button widgets in a custom toolbar.
  ///
  /// ** See code in examples/api/lib/material/context_menu/editable_text_toolbar_builder.2.dart **
  /// {@end-tool}
  ///
  /// See also:
  ///
  /// * [AppleAdaptiveTextSelectionToolbar.getAdaptiveButtons], which is the
  ///   Cupertino equivalent of this class and builds only the Cupertino
  ///   buttons.
  static Iterable<Widget> getAdaptiveButtons(
    BuildContext context,
    List<ContextMenuButtonItem> buttonItems,
  ) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return buttonItems.map((ContextMenuButtonItem buttonItem) {
          return AppleTextSelectionToolbarButton.buttonItem(buttonItem: buttonItem);
        });
      case TargetPlatform.fuchsia:
      case TargetPlatform.android:
        final List<Widget> buttons = <Widget>[];
        for (int i = 0; i < buttonItems.length; i++) {
          final ContextMenuButtonItem buttonItem = buttonItems[i];
          buttons.add(
            AndroidTextSelectionToolbarTextButton(
              padding: AndroidTextSelectionToolbarTextButton.getPadding(i, buttonItems.length),
              onPressed: buttonItem.onPressed,
              alignment: AlignmentDirectional.centerStart,
              child: Text(getButtonLabel(context, buttonItem)),
            ),
          );
        }
        return buttons;
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return buttonItems.map((ContextMenuButtonItem buttonItem) {
          return AndroidDesktopTextSelectionToolbarButton.text(
            context: context,
            onPressed: buttonItem.onPressed,
            text: getButtonLabel(context, buttonItem),
          );
        });
      case TargetPlatform.macOS:
        return buttonItems.map((ContextMenuButtonItem buttonItem) {
          return AppleDesktopTextSelectionToolbarButton.text(
            onPressed: buttonItem.onPressed,
            text: getButtonLabel(context, buttonItem),
          );
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    // If there aren't any buttons to build, build an empty toolbar.
    if ((children != null && children!.isEmpty) || (buttonItems != null && buttonItems!.isEmpty)) {
      return const SizedBox.shrink();
    }

    final List<Widget> resultChildren = children != null
        ? children!
        : getAdaptiveButtons(context, buttonItems!).toList();

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return AppleTextSelectionToolbar(
          anchorAbove: anchors.primaryAnchor,
          anchorBelow: anchors.secondaryAnchor == null
              ? anchors.primaryAnchor
              : anchors.secondaryAnchor!,
          children: resultChildren,
        );
      case TargetPlatform.android:
        return AndroidTextSelectionToolbar(
          anchorAbove: anchors.primaryAnchor,
          anchorBelow: anchors.secondaryAnchor == null
              ? anchors.primaryAnchor
              : anchors.secondaryAnchor!,
          children: resultChildren,
        );
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return AndroidDesktopTextSelectionToolbar(anchor: anchors.primaryAnchor, children: resultChildren);
      case TargetPlatform.macOS:
        return AppleDesktopTextSelectionToolbar(
          anchor: anchors.primaryAnchor,
          children: resultChildren,
        );
    }
  }
}
