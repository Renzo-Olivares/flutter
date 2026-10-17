// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "flutter/shell/platform/darwin/ios/framework/Source/FlutterSelectableTextSemanticsObject.h"

#include "flutter/fml/platform/darwin/string_range_sanitization.h"
#import "flutter/shell/platform/darwin/common/framework/Headers/FlutterCodecs.h"
#import "flutter/shell/platform/darwin/ios/framework/Source/FlutterTextInputPlugin.h"

FLUTTER_ASSERT_ARC

namespace {

// Whether VoiceOver selects through a hidden `UITextView` on iOS 18.1 and
// later (`accessibilityTextInputResponder`) instead of through the semantics
// object itself.
//
// The semantics object conforms to `UITextInput` either way, which is the only
// route before iOS 18.1. Set this to true if VoiceOver offers the Text
// Selection rotor only for the backing text view.
constexpr BOOL kUsesBackingTextViewByDefault = NO;

BOOL gUsesBackingTextView = kUsesBackingTextViewByDefault;

// The keys of the argument map that the framework decodes for
// `SemanticsAction.setSelection`.
NSString* const kSelectionBaseKey = @"base";
NSString* const kSelectionExtentKey = @"extent";

// Node text directions, see `flutter::SemanticsNode::textDirection`.
constexpr int32_t kTextDirectionRtl = 1;
constexpr int32_t kTextDirectionLtr = 2;

constexpr CGFloat kCaretWidth = 2.0;

NSUInteger IndexOfPosition(UITextPosition* position) {
  if (![position isKindOfClass:[FlutterTextPosition class]]) {
    return 0;
  }
  return ((FlutterTextPosition*)position).index;
}

}  // namespace

@interface FlutterSelectableTextSemanticsObject () <UITextViewDelegate>
@end

@implementation FlutterSelectableTextSemanticsObject {
  // The node's label. Positions index its UTF-16 code units.
  NSString* _text;
  // The selection the framework published, or -1 for none.
  int32_t _publishedBase;
  int32_t _publishedExtent;
  // The last selection VoiceOver requested, reported back until the framework
  // publishes a different selection. A collapsed request records a caret,
  // which the framework does not publish.
  BOOL _hasRequestedSelection;
  NSUInteger _requestedBase;
  NSUInteger _requestedExtent;
  // The caret reported while there is no selection.
  NSUInteger _caret;
  UITextInputStringTokenizer* _tokenizer;
  UITextView* _backingTextView;
  BOOL _isUpdatingBackingTextView;
}

+ (BOOL)isSelectableStaticText:(const flutter::SemanticsNode&)node {
  return !node.flags.isTextField && node.value.empty() &&
         node.HasAction(flutter::SemanticsAction::kSetSelection);
}

+ (BOOL)usesBackingTextView {
  return gUsesBackingTextView;
}

+ (void)setUsesBackingTextView:(BOOL)usesBackingTextView {
  gUsesBackingTextView = usesBackingTextView;
}

- (instancetype)initWithBridge:(fml::WeakPtr<flutter::AccessibilityBridgeIos>)bridge
                           uid:(int32_t)uid {
  self = [super initWithBridge:bridge uid:uid];
  if (self) {
    _text = @"";
    _publishedBase = -1;
    _publishedExtent = -1;
  }
  return self;
}

- (void)dealloc {
  [_backingTextView removeFromSuperview];
}

- (UITextView*)backingTextView {
  return _backingTextView;
}

#pragma mark - SemanticsObject overrides

- (void)setSemanticsNode:(const flutter::SemanticsNode*)node {
  [super setSemanticsNode:node];
  NSString* text = @(node->label.data());
  BOOL textChanged = ![text isEqualToString:_text];
  BOOL selectionChanged =
      node->textSelectionBase != _publishedBase || node->textSelectionExtent != _publishedExtent;
  _text = text;
  _publishedBase = node->textSelectionBase;
  _publishedExtent = node->textSelectionExtent;
  if (textChanged) {
    _caret = 0;
  }
  if (textChanged || selectionChanged) {
    _hasRequestedSelection = NO;
  }
  [self updateBackingTextView];
}

- (void)accessibilityBridgeDidFinishUpdate {
  [super accessibilityBridgeDidFinishUpdate];
  // The frame depends on the ancestors' transforms, which are only complete
  // once the whole update is applied.
  if (_backingTextView) {
    _backingTextView.frame = [self textRect];
  }
}

- (void)accessibilityBridgeDidChangeView {
  [super accessibilityBridgeDidChangeView];
  [self updateBackingTextView];
  if (_backingTextView) {
    _backingTextView.frame = [self textRect];
  }
}

#pragma mark - Selection

- (NSUInteger)clampIndex:(NSInteger)index {
  return (NSUInteger)MAX((NSInteger)0, MIN(index, (NSInteger)_text.length));
}

// The selection as base and extent offsets into `_text`.
- (void)getSelectionBase:(NSUInteger*)base extent:(NSUInteger*)extent {
  if (_hasRequestedSelection) {
    *base = [self clampIndex:_requestedBase];
    *extent = [self clampIndex:_requestedExtent];
  } else if (_publishedBase >= 0 && _publishedExtent >= 0) {
    *base = [self clampIndex:_publishedBase];
    *extent = [self clampIndex:_publishedExtent];
  } else {
    *base = [self clampIndex:_caret];
    *extent = *base;
  }
}

- (NSRange)selectedRange {
  NSUInteger base;
  NSUInteger extent;
  [self getSelectionBase:&base extent:&extent];
  return NSMakeRange(MIN(base, extent), MAX(base, extent) - MIN(base, extent));
}

// Asks the framework to select `range`, which an assistive technology chose.
- (void)requestSelectionOfRange:(NSRange)range {
  flutter::AccessibilityBridgeIos* bridge = self.bridge;
  if (!bridge || !self.node.HasAction(flutter::SemanticsAction::kSetSelection)) {
    return;
  }
  NSUInteger start = [self clampIndex:range.location];
  NSUInteger end = [self clampIndex:NSMaxRange(range)];
  NSUInteger currentBase;
  NSUInteger currentExtent;
  [self getSelectionBase:&currentBase extent:&currentExtent];
  // A UITextRange has no direction. Keep the current base in place, so that
  // extending a selection to the left moves its extent.
  BOOL isBackward = start != end && end == currentBase;
  NSUInteger base = isBackward ? end : start;
  NSUInteger extent = isBackward ? start : end;
  if (start == end) {
    _caret = start;
  }
  _hasRequestedSelection = YES;
  _requestedBase = base;
  _requestedExtent = extent;
  NSDictionary* arguments = @{
    kSelectionBaseKey : @(static_cast<int32_t>(base)),
    kSelectionExtentKey : @(static_cast<int32_t>(extent)),
  };
  NSData* encoded = [[FlutterStandardMessageCodec sharedInstance] encode:arguments];
  bridge->DispatchSemanticsAction(self.uid, flutter::SemanticsAction::kSetSelection,
                                  fml::MallocMapping::Copy(encoded.bytes, encoded.length));
}

#pragma mark - Backing text view

- (void)updateBackingTextView {
  if (!gUsesBackingTextView) {
    return;
  }
  if (@available(iOS 18.1, *)) {
    UIView* view = self.bridgeView;
    if (!view) {
      return;
    }
    if (!_backingTextView) {
      _backingTextView = [[UITextView alloc] initWithFrame:CGRectZero];
      _backingTextView.editable = NO;
      _backingTextView.selectable = YES;
      _backingTextView.scrollEnabled = NO;
      // The text view is never drawn and never receives touches; it only
      // answers VoiceOver's text queries for this object.
      _backingTextView.textColor = UIColor.clearColor;
      _backingTextView.backgroundColor = UIColor.clearColor;
      _backingTextView.userInteractionEnabled = NO;
      _backingTextView.isAccessibilityElement = NO;
      _backingTextView.delegate = self;
    }
    if (_backingTextView.superview != view) {
      [view addSubview:_backingTextView];
    }
    _isUpdatingBackingTextView = YES;
    if (![_backingTextView.text isEqualToString:_text]) {
      _backingTextView.text = _text;
    }
    _backingTextView.selectedRange = [self selectedRange];
    _isUpdatingBackingTextView = NO;
  }
}

- (void)textViewDidChangeSelection:(UITextView*)textView {
  if (_isUpdatingBackingTextView) {
    return;
  }
  [self requestSelectionOfRange:textView.selectedRange];
}

#pragma mark - UIAccessibility overrides

- (BOOL)accessibilityRespondsToUserInteraction {
  if (self.node.flags.isAccessibilityFocusBlocked) {
    return NO;
  }
  // Selecting and copying are reached through UITextInput and the edit
  // actions, not by interacting with the element, so they alone do not make
  // the text interactive, as for a label.
  int32_t interactiveActions = self.node.actions & ~flutter::kSystemActions &
                               ~static_cast<int32_t>(flutter::SemanticsAction::kSetSelection) &
                               ~static_cast<int32_t>(flutter::SemanticsAction::kCopy);
  return interactiveActions != 0 || !self.node.customAccessibilityActions.empty();
}

- (id<UITextInput>)accessibilityTextInputResponder {
  if (_backingTextView) {
    return _backingTextView;
  }
  return self;
}

#pragma mark - UIResponderStandardEditActions

- (void)copy:(id)sender {
  flutter::AccessibilityBridgeIos* bridge = self.bridge;
  if (!bridge || !self.node.HasAction(flutter::SemanticsAction::kCopy)) {
    return;
  }
  bridge->DispatchSemanticsAction(self.uid, flutter::SemanticsAction::kCopy);
}

- (void)select:(id)sender {
  NSRange selection = [self selectedRange];
  UITextPosition* caret = [FlutterTextPosition positionWithIndex:selection.location];
  UITextRange* word = [self.tokenizer rangeEnclosingPosition:caret
                                             withGranularity:UITextGranularityWord
                                                 inDirection:UITextStorageDirectionForward];
  if (![word isKindOfClass:[FlutterTextRange class]]) {
    word = [self.tokenizer rangeEnclosingPosition:caret
                                  withGranularity:UITextGranularityWord
                                      inDirection:UITextStorageDirectionBackward];
  }
  if (![word isKindOfClass:[FlutterTextRange class]]) {
    return;
  }
  [self requestSelectionOfRange:((FlutterTextRange*)word).range];
}

- (void)selectAll:(id)sender {
  [self requestSelectionOfRange:NSMakeRange(0, _text.length)];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
  if (!self.bridge) {
    return NO;
  }
  NSRange selection = [self selectedRange];
  if (action == @selector(copy:)) {
    return selection.length > 0 && self.node.HasAction(flutter::SemanticsAction::kCopy);
  }
  if (action == @selector(select:)) {
    return selection.length == 0 && _text.length > 0 &&
           self.node.HasAction(flutter::SemanticsAction::kSetSelection);
  }
  if (action == @selector(selectAll:)) {
    return selection.length < _text.length &&
           self.node.HasAction(flutter::SemanticsAction::kSetSelection);
  }
  return NO;
}

#pragma mark - UITextInput

- (NSString*)textInRange:(UITextRange*)range {
  if (![range isKindOfClass:[FlutterTextRange class]]) {
    return nil;
  }
  NSRange textRange = ((FlutterTextRange*)range).range;
  NSUInteger start = [self clampIndex:textRange.location];
  NSUInteger end = [self clampIndex:NSMaxRange(textRange)];
  return [_text substringWithRange:NSMakeRange(start, end - start)];
}

- (void)replaceRange:(UITextRange*)range withText:(NSString*)text {
  // The text is not editable.
}

- (BOOL)shouldChangeTextInRange:(UITextRange*)range replacementText:(NSString*)text {
  return NO;
}

- (UITextRange*)selectedTextRange {
  return [FlutterTextRange rangeWithNSRange:[self selectedRange]];
}

- (void)setSelectedTextRange:(UITextRange*)selectedTextRange {
  if (![selectedTextRange isKindOfClass:[FlutterTextRange class]]) {
    return;
  }
  [self requestSelectionOfRange:((FlutterTextRange*)selectedTextRange).range];
}

- (UITextRange*)markedTextRange {
  return nil;
}

- (NSDictionary*)markedTextStyle {
  return nil;
}

- (void)setMarkedTextStyle:(NSDictionary*)markedTextStyle {
  // The text is not editable.
}

- (void)setMarkedText:(NSString*)markedText selectedRange:(NSRange)selectedRange {
  // The text is not editable.
}

- (void)unmarkText {
  // The text is not editable.
}

- (UITextPosition*)beginningOfDocument {
  return [FlutterTextPosition positionWithIndex:0 affinity:UITextStorageDirectionForward];
}

- (UITextPosition*)endOfDocument {
  return [FlutterTextPosition positionWithIndex:_text.length
                                       affinity:UITextStorageDirectionBackward];
}

- (UITextRange*)textRangeFromPosition:(UITextPosition*)fromPosition
                           toPosition:(UITextPosition*)toPosition {
  NSUInteger from = [self clampIndex:IndexOfPosition(fromPosition)];
  NSUInteger to = [self clampIndex:IndexOfPosition(toPosition)];
  return
      [FlutterTextRange rangeWithNSRange:NSMakeRange(MIN(from, to), MAX(from, to) - MIN(from, to))];
}

- (UITextPosition*)positionFromPosition:(UITextPosition*)position offset:(NSInteger)offset {
  NSUInteger index = IndexOfPosition(position);
  NSInteger newIndex = (NSInteger)index + offset;
  if (newIndex < 0 || newIndex > (NSInteger)_text.length) {
    return nil;
  }
  // Move by whole grapheme clusters, as FlutterTextInputView does.
  if (offset >= 0) {
    for (NSInteger i = 0; i < offset && index < _text.length; ++i) {
      index = MIN(NSMaxRange(fml::RangeForCharacterAtIndex(_text, index)), _text.length);
    }
  } else {
    for (NSInteger i = 0; i < -offset && index > 0; ++i) {
      index = fml::RangeForCharacterAtIndex(_text, index - 1).location;
    }
  }
  return [FlutterTextPosition positionWithIndex:index];
}

- (UITextPosition*)positionFromPosition:(UITextPosition*)position
                            inDirection:(UITextLayoutDirection)direction
                                 offset:(NSInteger)offset {
  switch (direction) {
    case UITextLayoutDirectionLeft:
    case UITextLayoutDirectionUp:
      return [self positionFromPosition:position offset:-offset];
    case UITextLayoutDirectionRight:
    case UITextLayoutDirectionDown:
      return [self positionFromPosition:position offset:offset];
  }
}

- (NSComparisonResult)comparePosition:(UITextPosition*)position toPosition:(UITextPosition*)other {
  NSUInteger index = IndexOfPosition(position);
  NSUInteger otherIndex = IndexOfPosition(other);
  if (index < otherIndex) {
    return NSOrderedAscending;
  }
  if (index > otherIndex) {
    return NSOrderedDescending;
  }
  return NSOrderedSame;
}

- (NSInteger)offsetFromPosition:(UITextPosition*)from toPosition:(UITextPosition*)toPosition {
  return (NSInteger)IndexOfPosition(toPosition) - (NSInteger)IndexOfPosition(from);
}

- (id<UITextInputDelegate>)inputDelegate {
  // Nothing about the text changes through UITextInput, so there is nothing
  // to report to an input delegate.
  return nil;
}

- (void)setInputDelegate:(id<UITextInputDelegate>)inputDelegate {
}

- (id<UITextInputTokenizer>)tokenizer {
  if (!_tokenizer) {
    // FlutterTokenizer only works with a FlutterTextInputView. The string
    // tokenizer only sends UITextInput messages to its text input, so this
    // object can stand in for the UIResponder the initializer names.
    _tokenizer =
        [[UITextInputStringTokenizer alloc] initWithTextInput:(UIResponder<UITextInput>*)self];
  }
  return _tokenizer;
}

- (UITextPosition*)positionWithinRange:(UITextRange*)range
                   farthestInDirection:(UITextLayoutDirection)direction {
  switch (direction) {
    case UITextLayoutDirectionLeft:
    case UITextLayoutDirectionUp:
      return range.start;
    case UITextLayoutDirectionRight:
    case UITextLayoutDirectionDown:
      return range.end;
  }
}

- (UITextRange*)characterRangeByExtendingPosition:(UITextPosition*)position
                                      inDirection:(UITextLayoutDirection)direction {
  NSUInteger index = [self clampIndex:IndexOfPosition(position)];
  switch (direction) {
    case UITextLayoutDirectionLeft:
    case UITextLayoutDirectionUp:
      return [FlutterTextRange rangeWithNSRange:NSMakeRange(0, index)];
    case UITextLayoutDirectionRight:
    case UITextLayoutDirectionDown:
      return [FlutterTextRange rangeWithNSRange:NSMakeRange(index, _text.length - index)];
  }
}

- (NSWritingDirection)baseWritingDirectionForPosition:(UITextPosition*)position
                                          inDirection:(UITextStorageDirection)direction {
  switch (self.node.textDirection) {
    case kTextDirectionRtl:
      return NSWritingDirectionRightToLeft;
    case kTextDirectionLtr:
      return NSWritingDirectionLeftToRight;
    default:
      return NSWritingDirectionNatural;
  }
}

- (void)setBaseWritingDirection:(NSWritingDirection)writingDirection forRange:(UITextRange*)range {
  // The text is not editable.
}

#pragma mark - UITextInput geometry

// The framework sends no text layout, so every range is reported as the whole
// node, and carets and points are mapped linearly across the node's width.

- (UIView*)textInputView {
  return self.bridgeView;
}

// The node's frame in the coordinate space of `textInputView`.
- (CGRect)textRect {
  CGRect frame = self.accessibilityFrame;
  UIView* view = self.bridgeView;
  UIScreen* screen = view.window.screen;
  if (!screen) {
    return frame;
  }
  return [view convertRect:frame fromCoordinateSpace:screen.coordinateSpace];
}

- (BOOL)isRightToLeft {
  return self.node.textDirection == kTextDirectionRtl;
}

- (CGFloat)xForIndex:(NSUInteger)index inRect:(CGRect)rect {
  if (_text.length == 0) {
    return self.isRightToLeft ? CGRectGetMaxX(rect) : CGRectGetMinX(rect);
  }
  CGFloat fraction = (CGFloat)[self clampIndex:index] / _text.length;
  if (self.isRightToLeft) {
    fraction = 1.0 - fraction;
  }
  return CGRectGetMinX(rect) + fraction * CGRectGetWidth(rect);
}

- (NSUInteger)indexForPoint:(CGPoint)point {
  CGRect rect = [self textRect];
  if (_text.length == 0 || CGRectGetWidth(rect) <= 0) {
    return 0;
  }
  CGFloat fraction = (point.x - CGRectGetMinX(rect)) / CGRectGetWidth(rect);
  fraction = MAX(0.0, MIN(1.0, fraction));
  if (self.isRightToLeft) {
    fraction = 1.0 - fraction;
  }
  NSUInteger index = [self clampIndex:lround(fraction * _text.length)];
  if (index < _text.length) {
    index = fml::RangeForCharacterAtIndex(_text, index).location;
  }
  return index;
}

- (CGRect)firstRectForRange:(UITextRange*)range {
  return [self textRect];
}

- (CGRect)caretRectForPosition:(UITextPosition*)position {
  CGRect rect = [self textRect];
  CGFloat x = [self xForIndex:IndexOfPosition(position) inRect:rect];
  return CGRectMake(x, CGRectGetMinY(rect), kCaretWidth, CGRectGetHeight(rect));
}

- (NSArray<UITextSelectionRect*>*)selectionRectsForRange:(UITextRange*)range {
  NSUInteger start = [self clampIndex:IndexOfPosition(range.start)];
  return @[ [FlutterTextSelectionRect
      selectionRectWithRectAndInfo:[self textRect]
                          position:start
                  writingDirection:self.isRightToLeft ? NSWritingDirectionRightToLeft
                                                      : NSWritingDirectionLeftToRight
                     containsStart:YES
                       containsEnd:YES
                        isVertical:NO] ];
}

- (UITextPosition*)closestPositionToPoint:(CGPoint)point {
  return [FlutterTextPosition positionWithIndex:[self indexForPoint:point]];
}

- (UITextPosition*)closestPositionToPoint:(CGPoint)point withinRange:(UITextRange*)range {
  NSUInteger index = [self indexForPoint:point];
  NSUInteger start = IndexOfPosition(range.start);
  NSUInteger end = IndexOfPosition(range.end);
  return [FlutterTextPosition positionWithIndex:MAX(start, MIN(end, index))];
}

- (UITextRange*)characterRangeAtPoint:(CGPoint)point {
  NSUInteger index = [self indexForPoint:point];
  if (index == _text.length) {
    return [FlutterTextRange rangeWithNSRange:NSMakeRange(index, 0)];
  }
  return [FlutterTextRange rangeWithNSRange:fml::RangeForCharacterAtIndex(_text, index)];
}

#pragma mark - UIKeyInput

- (BOOL)hasText {
  return _text.length > 0;
}

- (void)insertText:(NSString*)text {
  // The text is not editable.
}

- (void)deleteBackward {
  // The text is not editable.
}

@end
