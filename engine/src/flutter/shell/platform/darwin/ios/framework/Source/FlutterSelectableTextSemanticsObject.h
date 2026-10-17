// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_SHELL_PLATFORM_DARWIN_IOS_FRAMEWORK_SOURCE_FLUTTERSELECTABLETEXTSEMANTICSOBJECT_H_
#define FLUTTER_SHELL_PLATFORM_DARWIN_IOS_FRAMEWORK_SOURCE_FLUTTERSELECTABLETEXTSEMANTICSOBJECT_H_

#import <UIKit/UIKit.h>

#import "flutter/shell/platform/darwin/ios/framework/Source/SemanticsObject.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A semantics object for selectable static text, such as a paragraph inside a
 * `SelectionArea`, that VoiceOver can select through `UITextInput`.
 *
 * Unlike `TextInputSemanticsObject`, which forwards `UITextInput` to a text
 * input view, this object answers `UITextInput` itself over the node's label:
 * positions are UTF-16 offsets into the label, `selectedTextRange` is the
 * node's `textSelectionBase`/`textSelectionExtent`, and setting it dispatches
 * `SemanticsAction::kSetSelection` to the framework. The text cannot be edited.
 *
 * The node keeps the traits of a `FlutterSemanticsObject`, so it is still
 * reported as static text.
 *
 * See also:
 *  * `TextInputSemanticsObject`, which represents editable text fields.
 */
@interface FlutterSelectableTextSemanticsObject : FlutterSemanticsObject <UITextInput>

/**
 * Whether `node` is selectable static text: a node that is not a text field,
 * has no value, and handles `SemanticsAction::kSetSelection`.
 *
 * The node's `textSelectionBase` and `textSelectionExtent` are offsets into its
 * label.
 */
+ (BOOL)isSelectableStaticText:(const flutter::SemanticsNode&)node;

/**
 * Whether new objects mirror their text and selection into a hidden
 * `UITextView` and name it as their `accessibilityTextInputResponder` on
 * iOS 18.1 and later, instead of answering `UITextInput` only themselves.
 *
 * Defaults to `NO`.
 *
 * Visible for testing.
 */
@property(class, nonatomic) BOOL usesBackingTextView;

/**
 * The hidden text view that mirrors this object's text and selection, or nil
 * if `usesBackingTextView` is `NO`, the system is older than iOS 18.1, or the
 * bridge has no view.
 *
 * Visible for testing.
 */
@property(nonatomic, readonly, nullable) UITextView* backingTextView;

@end

NS_ASSUME_NONNULL_END

#endif  // FLUTTER_SHELL_PLATFORM_DARWIN_IOS_FRAMEWORK_SOURCE_FLUTTERSELECTABLETEXTSEMANTICSOBJECT_H_
