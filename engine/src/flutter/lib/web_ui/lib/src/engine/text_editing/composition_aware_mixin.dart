// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:js_interop';

import '../dom.dart';
import 'text_editing.dart';

/// Provides default functionality for listening to HTML composition events.
///
/// A class with this mixin generally calls [determineCompositionState] in order to update
/// an [EditingState] with new composition values; namely, [EditingState.composingBaseOffset]
/// and [EditingState.composingExtentOffset].
///
/// A class with this mixin should call [addCompositionEventHandlers] on initalization, and
/// [removeCompositionEventHandlers] on deinitalization.
///
/// See also:
///
/// * [EditingState], the state of a text field that [CompositionAwareMixin] updates.
/// * [DefaultTextEditingStrategy], the primary implementer of [CompositionAwareMixin].
mixin CompositionAwareMixin {
  /// The name of the HTML composition event type that triggers on starting a composition.
  static const String _kCompositionStart = 'compositionstart';

  /// The name of the browser composition event type that triggers on updating a composition.
  static const String _kCompositionUpdate = 'compositionupdate';

  /// The name of the browser composition event type that triggers on ending a composition.
  static const String _kCompositionEnd = 'compositionend';

  late final DomEventListener _compositionStartListener = createDomEventListener(
    _handleCompositionStart,
  );
  late final DomEventListener _compositionUpdateListener = createDomEventListener(
    _handleCompositionUpdate,
  );
  late final DomEventListener _compositionEndListener = createDomEventListener(
    _handleCompositionEnd,
  );

  /// The currently composing text in the `domElement`.
  ///
  /// Will be null if composing just started, ended, or no composing is being done.
  /// This member is kept up to date provided compositionEventHandlers are in place,
  /// so it is safe to reference it to get the current composingText.
  String? composingText;

  DomHTMLElement? _domElement;

  void addCompositionEventHandlers(DomHTMLElement domElement) {
    _domElement = domElement;
    domElement.addEventListener(_kCompositionStart, _compositionStartListener);
    domElement.addEventListener(_kCompositionUpdate, _compositionUpdateListener);
    domElement.addEventListener(_kCompositionEnd, _compositionEndListener);
  }

  void removeCompositionEventHandlers(DomHTMLElement domElement) {
    _domElement = null;
    domElement.removeEventListener(_kCompositionStart, _compositionStartListener);
    domElement.removeEventListener(_kCompositionUpdate, _compositionUpdateListener);
    domElement.removeEventListener(_kCompositionEnd, _compositionEndListener);
  }

  void _handleCompositionStart(DomEvent event) {
    if (event.isA<DomCompositionEvent>()) {
      print('composing start: ${(event as DomCompositionEvent).data}');
    }
    composingText = null;
  }

  void _handleCompositionUpdate(DomEvent event) {
    if (event.isA<DomCompositionEvent>()) {
      composingText = (event as DomCompositionEvent).data;
      EditingState? newState;
      if (_domElement != null && _domElement.isA<DomHTMLInputElement>()) {
        final DomHTMLInputElement element = _domElement as DomHTMLInputElement;
        if (element.selectionDirection == 'backward') {
          newState = EditingState(
            text: element.value,
            baseOffset: element.selectionEnd?.toInt(),
            extentOffset: element.selectionStart?.toInt(),
          );
        } else {
          newState = EditingState(
            text: element.value,
            baseOffset: element.selectionStart?.toInt(),
            extentOffset: element.selectionEnd?.toInt(),
          );
        }
      } else if (_domElement != null && _domElement.isA<DomHTMLTextAreaElement>()) {
        final DomHTMLTextAreaElement element = _domElement as DomHTMLTextAreaElement;
        if (element.selectionDirection == 'backward') {
          newState = EditingState(
            text: element.value,
            baseOffset: element.selectionEnd?.toInt(),
            extentOffset: element.selectionStart?.toInt(),
          );
        } else {
          newState = EditingState(
            text: element.value,
            baseOffset: element.selectionStart?.toInt(),
            extentOffset: element.selectionEnd?.toInt(),
          );
        }
      }
      print(
        'composing update: $composingText, selection start ${newState?.baseOffset}, selection end ${newState?.extentOffset}',
      );
    }
  }

  void _handleCompositionEnd(DomEvent event) {
    if (event.isA<DomCompositionEvent>()) {
      print('composing end: ${(event as DomCompositionEvent).data}');
    }
    composingText = null;
  }

  EditingState determineCompositionState(EditingState editingState) {
    if (editingState.extentOffset == null || composingText == null || editingState.text == null) {
      print('1. determining composing state $editingState, composing text $composingText');
      return editingState;
    }

    final int composingBase = editingState.extentOffset! - composingText!.length;

    if (composingBase < 0) {
      print('2. determining composing state $editingState, composing text $composingText');
      return editingState;
    }
    final EditingState newEditingState = editingState.copyWith(
      composingBaseOffset: composingBase,
      composingExtentOffset: composingBase + composingText!.length,
    );
    print('3. determining composing state $newEditingState, composing text $composingText');
    return newEditingState;
  }
}
