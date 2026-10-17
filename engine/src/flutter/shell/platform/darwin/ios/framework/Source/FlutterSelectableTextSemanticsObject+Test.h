// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_SHELL_PLATFORM_DARWIN_IOS_FRAMEWORK_SOURCE_FLUTTERSELECTABLETEXTSEMANTICSOBJECT_TEST_H_
#define FLUTTER_SHELL_PLATFORM_DARWIN_IOS_FRAMEWORK_SOURCE_FLUTTERSELECTABLETEXTSEMANTICSOBJECT_TEST_H_

#import "flutter/shell/platform/darwin/ios/framework/Source/FlutterSelectableTextSemanticsObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface FlutterSelectableTextSemanticsObject (Test)

/**
 * Whether this object mirrors its text and selection into a hidden
 * `UITextView` and names it as its `accessibilityTextInputResponder` on
 * iOS 18.1 and later, instead of answering `UITextInput` only itself.
 *
 * Defaults to `kUsesBackingTextViewByDefault`. Set it before the first
 * `setSemanticsNode:`.
 */
@property(nonatomic) BOOL usesBackingTextView;

/**
 * The hidden text view that mirrors this object's text and selection, or nil
 * if `usesBackingTextView` is `NO`, the system is older than iOS 18.1, or the
 * bridge has no view.
 */
@property(nonatomic, readonly, nullable) UITextView* backingTextView;

@end

NS_ASSUME_NONNULL_END

#endif  // FLUTTER_SHELL_PLATFORM_DARWIN_IOS_FRAMEWORK_SOURCE_FLUTTERSELECTABLETEXTSEMANTICSOBJECT_TEST_H_
