// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/rendering.dart';

import '../web.dart' as web;
import 'basic.dart';
import 'framework.dart';
import 'platform_view.dart';
import 'selection_container.dart';

const String _viewType = 'Browser__WebContextMenuViewType__';
const String _kClassName = 'web-selectable-region-context-menu';
// These css rules hides the dom element with the class name.
const String _kClassSelectionRule = '.$_kClassName::selection { background: transparent; }';
const String _kClassRule =
    '''
.$_kClassName {
  color: transparent;
  user-select: text;
  -webkit-user-select: text; /* Safari */
  -moz-user-select: text; /* Firefox */
  -ms-user-select: text; /* IE10+ */
}
''';
const int _kRightClickButton = 2;

typedef _WebSelectionCallBack = void Function(web.HTMLElement, web.MouseEvent?);

/// Function signature for `ui_web.platformViewRegistry.registerViewFactory`.
@visibleForTesting
typedef RegisterViewFactory = void Function(String, Object Function(int viewId), {bool isVisible});

/// See `_platform_selectable_region_context_menu_io.dart` for full
/// documentation.
class PlatformSelectableRegionContextMenu extends StatelessWidget {
  /// See `_platform_selectable_region_context_menu_io.dart`.
  PlatformSelectableRegionContextMenu({required this.delegate, required this.child, super.key}) {
    if (_registeredViewType == null) {
      _register();
    }
  }

  /// See `_platform_selectable_region_context_menu_io.dart`.
  final SelectionContainerDelegate delegate;

  /// See `_platform_selectable_region_context_menu_io.dart`.
  final Widget child;

  /// See `_platform_selectable_region_context_menu_io.dart`.
  // ignore: use_setters_to_change_properties
  static void attach(SelectionContainerDelegate client) {
    _activeClient = client;
  }

  /// See `_platform_selectable_region_context_menu_io.dart`.
  static void detach(SelectionContainerDelegate client) {
    if (_activeClient != client) {
      _activeClient = null;
    }
  }

  static SelectionContainerDelegate? _activeClient;

  static final Map<int, web.HTMLElement> _hashCodeToElement = {};

  // Keeps track if this widget has already registered its view factories or not.
  static String? _registeredViewType;

  static RegisterViewFactory get _registerViewFactory =>
      debugOverrideRegisterViewFactory ?? ui_web.platformViewRegistry.registerViewFactory;

  /// Override this to provide a custom implementation of [ui_web.platformViewRegistry.registerViewFactory].
  ///
  /// This should only be used for testing.
  // See `_platform_selectable_region_context_menu_io.dart`.
  @visibleForTesting
  static RegisterViewFactory? debugOverrideRegisterViewFactory;

  /// Synchronizes the browser DOM selection with the active selectable region.
  static void syncSelection(SelectionContainerDelegate client) {
    final element = _hashCodeToElement[client.hashCode];
    print('syncSelection: called! client hashCode: ${client.hashCode}');
    print(
      'syncSelection: element is null? ${element == null}. _activeClient is null? ${_activeClient == null}',
    );
    print('syncSelection: client matches _activeClient? ${_activeClient == client}');
    if (element != null && _activeClient == client) {
      final String? selectedText = client.getSelectedContent()?.plainText;
      print('syncSelection: selectedText is: "$selectedText"');
      if (selectedText != null && selectedText.isNotEmpty) {
        element.innerText = selectedText;

        try {
          final web.Range range = web.document.createRange()..selectNode(element);
          web.window.getSelection()
            ?..removeAllRanges()
            ..addRange(range);
          print('syncSelection: Successfully set DOM selection range in browser!');
        } catch (e) {
          print('syncSelection: Error setting DOM selection: $e');
        }
      } else {
        print('syncSelection: selectedText is null or empty!');
      }
    } else {
      print('syncSelection: Preconditions failed! sync skipped.');
    }
  }

  /// Resets the view factory registration to its initial state.
  @visibleForTesting
  static void debugResetRegistry() {
    _registeredViewType = null;
  }

  // Registers the view factories for the interceptor widgets.
  static void _register() {
    assert(_registeredViewType == null);
    _registeredViewType = _registerWebSelectionCallback((
      web.HTMLElement element,
      // event will be the mouse event if the callback was triggered by
      // right-clicking and `null` if triggered another way (such as a `copy`
      // event).
      web.MouseEvent? event,
    ) {
      final SelectionContainerDelegate? client = _activeClient;
      if (client != null) {
        // If we were triggered by a right click, select the word
        if (event != null) {
          // Converts the html right click event to flutter coordinate.
          final localOffset = Offset(event.offsetX.toDouble(), event.offsetY.toDouble());
          final Matrix4 transform = client.getTransformTo(null);
          final Offset globalOffset = MatrixUtils.transformPoint(transform, localOffset);
          client.dispatchSelectionEvent(SelectWordSelectionEvent(globalPosition: globalOffset));

          // Programmatically select the dom element in browser.
          final web.Range range = web.document.createRange()..selectNode(element);

          web.window.getSelection()
            ?..removeAllRanges()
            ..addRange(range);
        }

        // The innerText must contain the text in order to be selected by
        // the browser.
        element.innerText = client.getSelectedContent()?.plainText ?? '';
      }
    });
  }

  static String _registerWebSelectionCallback(_WebSelectionCallBack callback) {
    // Create css style for _kClassName.
    final styleElement = web.document.createElement('style') as web.HTMLStyleElement;
    web.document.head!.append(styleElement as JSAny);
    final web.CSSStyleSheet sheet = styleElement.sheet!;
    sheet.insertRule(_kClassRule, 0);
    sheet.insertRule(_kClassSelectionRule, 1);

    _registerViewFactory(_viewType, (int viewId, {Object? params}) {
      final htmlElement = web.document.createElement('div') as web.HTMLElement;
      final int? delegateHashCode = params as int?;
      print(
        'ViewFactory: Created htmlElement. viewId: $viewId. params: $params. delegateHashCode: $delegateHashCode',
      );
      if (delegateHashCode != null) {
        _hashCodeToElement[delegateHashCode] = htmlElement;
      }
      htmlElement
        ..style.width = '100%'
        ..style.height = '100%'
        ..classList.add(_kClassName);

      htmlElement.addEventListener(
        'mousedown',
        (web.Event event) {
          print(
            'htmlElement: mousedown event triggered! element hashCode: ${htmlElement.hashCode}',
          );
          final mouseEvent = event as web.MouseEvent;
          mouseEvent.preventDefault();
          if (mouseEvent.button != _kRightClickButton) {
            return;
          }
          callback(htmlElement, mouseEvent);
        }.toJS,
      );

      htmlElement.addEventListener(
        'mouseup',
        (web.Event event) {
          print('htmlElement: mouseup event triggered! element hashCode: ${htmlElement.hashCode}');
        }.toJS,
      );
      return htmlElement;
    }, isVisible: false);
    return _viewType;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        Positioned.fill(
          child: HtmlElementView(viewType: _viewType, creationParams: delegate.hashCode),
        ),
        child,
      ],
    );
  }
}
