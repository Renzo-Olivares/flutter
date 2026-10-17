// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <XCTest/XCTest.h>

#import "flutter/shell/platform/darwin/common/framework/Headers/FlutterCodecs.h"
#import "flutter/shell/platform/darwin/common/framework/Headers/FlutterMacros.h"
#import "flutter/shell/platform/darwin/ios/framework/Source/FlutterSelectableTextSemanticsObject+Test.h"
#import "flutter/shell/platform/darwin/ios/framework/Source/FlutterSelectableTextSemanticsObject.h"
#import "flutter/shell/platform/darwin/ios/framework/Source/FlutterTextInputPlugin.h"
#import "flutter/shell/platform/darwin/ios/framework/Source/SemanticsObjectTestMocks.h"

FLUTTER_ASSERT_ARC

@interface FlutterSelectableTextSemanticsObjectTest : XCTestCase
@end

@implementation FlutterSelectableTextSemanticsObjectTest

- (void)testIsSelectableStaticText {
  flutter::SemanticsNode node;
  node.label = "Hello world";
  XCTAssertFalse([FlutterSelectableTextSemanticsObject isSelectableStaticText:node]);

  node.actions = static_cast<int32_t>(flutter::SemanticsAction::kSetSelection);
  XCTAssertTrue([FlutterSelectableTextSemanticsObject isSelectableStaticText:node]);

  flutter::SemanticsNode withValue = node;
  withValue.value = "42";
  XCTAssertFalse([FlutterSelectableTextSemanticsObject isSelectableStaticText:withValue]);

  flutter::SemanticsNode textField = node;
  textField.flags.isTextField = true;
  XCTAssertFalse([FlutterSelectableTextSemanticsObject isSelectableStaticText:textField]);

  flutter::SemanticsNode readOnlyTextField = textField;
  readOnlyTextField.flags.isReadOnly = true;
  XCTAssertFalse([FlutterSelectableTextSemanticsObject isSelectableStaticText:readOnlyTextField]);
}

- (void)testConformsToUITextInputAndStaysStaticText {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode node;
  node.label = "Hello world";
  node.tooltip = "a tooltip";
  node.actions = static_cast<int32_t>(flutter::SemanticsAction::kSetSelection);
  FlutterSelectableTextSemanticsObject* object =
      [[FlutterSelectableTextSemanticsObject alloc] initWithBridge:bridge uid:1];
  [object setSemanticsNode:&node];
  [object accessibilityBridgeDidFinishUpdate];

  XCTAssertTrue([object conformsToProtocol:@protocol(UITextInput)]);
  XCTAssertTrue([object isKindOfClass:[FlutterSemanticsObject class]]);
  XCTAssertEqual(object.accessibilityTraits, UIAccessibilityTraitStaticText);
  XCTAssertEqualObjects(object.accessibilityLabel, @"Hello world\na tooltip");
  // The text is the label only, without the tooltip.
  UITextRange* document = [object textRangeFromPosition:object.beginningOfDocument
                                             toPosition:object.endOfDocument];
  XCTAssertEqualObjects([object textInRange:document], @"Hello world");
  XCTAssertTrue(object.hasText);
  XCTAssertNil(object.markedTextRange);
  XCTAssertNil(object.inputDelegate);
  XCTAssertTrue([object.tokenizer isKindOfClass:[UITextInputStringTokenizer class]]);

  // The text cannot be edited.
  [object insertText:@"x"];
  [object deleteBackward];
  [object replaceRange:document withText:@"x"];
  XCTAssertEqualObjects([object textInRange:document], @"Hello world");
}

- (void)testPositionsAreUTF16OffsetsIntoTheLabel {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode node;
  // "a😀b": the emoji is a surrogate pair at UTF-16 offsets 1 and 2.
  node.label = "a\xF0\x9F\x98\x80"
               "b";
  node.actions = static_cast<int32_t>(flutter::SemanticsAction::kSetSelection);
  FlutterSelectableTextSemanticsObject* object =
      [[FlutterSelectableTextSemanticsObject alloc] initWithBridge:bridge uid:1];
  [object setSemanticsNode:&node];

  XCTAssertEqual(((FlutterTextPosition*)object.endOfDocument).index, 4u);
  FlutterTextPosition* afterA = [FlutterTextPosition positionWithIndex:1];
  FlutterTextPosition* afterEmoji = [FlutterTextPosition positionWithIndex:3];

  // Offsets count UTF-16 code units, so they round-trip with
  // offsetFromPosition:toPosition: across the surrogate pair.
  XCTAssertEqual(((FlutterTextPosition*)[object positionFromPosition:afterA offset:2]).index, 3u);
  XCTAssertEqual(((FlutterTextPosition*)[object positionFromPosition:afterEmoji offset:-2]).index,
                 1u);
  XCTAssertEqual(((FlutterTextPosition*)[object
                      positionFromPosition:object.beginningOfDocument
                                    offset:[object offsetFromPosition:object.beginningOfDocument
                                                           toPosition:afterEmoji]])
                     .index,
                 3u);
  XCTAssertEqual(((FlutterTextPosition*)[object positionFromPosition:afterEmoji
                                                         inDirection:UITextLayoutDirectionLeft
                                                              offset:2])
                     .index,
                 1u);
  XCTAssertNil([object positionFromPosition:afterA offset:4]);
  XCTAssertNil([object positionFromPosition:object.endOfDocument offset:1]);
  XCTAssertNil([object positionFromPosition:object.beginningOfDocument offset:-1]);

  UITextRange* emoji = [object textRangeFromPosition:afterEmoji toPosition:afterA];
  XCTAssertTrue(NSEqualRanges(((FlutterTextRange*)emoji).range, NSMakeRange(1, 2)));
  XCTAssertEqualObjects([object textInRange:emoji], @"\U0001F600");
  XCTAssertEqual([object offsetFromPosition:afterA toPosition:afterEmoji], 2);
  XCTAssertEqual([object comparePosition:afterA toPosition:afterEmoji], NSOrderedAscending);
  XCTAssertEqual([object comparePosition:afterEmoji toPosition:afterA], NSOrderedDescending);
  XCTAssertEqual([object comparePosition:afterA toPosition:afterA], NSOrderedSame);
  XCTAssertTrue(NSEqualRanges(
      ((FlutterTextRange*)[object characterRangeByExtendingPosition:afterA
                                                        inDirection:UITextLayoutDirectionRight])
          .range,
      NSMakeRange(1, 3)));
  // Ranges outside the label are clamped.
  XCTAssertEqualObjects([object textInRange:[FlutterTextRange rangeWithNSRange:NSMakeRange(3, 10)]],
                        @"b");
}

- (void)testSelectionActionsDoNotMakeItInteractive {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode node;
  node.label = "Hello world";
  node.actions = static_cast<int32_t>(flutter::SemanticsAction::kSetSelection) |
                 static_cast<int32_t>(flutter::SemanticsAction::kCopy);
  FlutterSelectableTextSemanticsObject* object =
      [[FlutterSelectableTextSemanticsObject alloc] initWithBridge:bridge uid:1];
  [object setSemanticsNode:&node];
  // Like a plain label, so Voice Control does not offer every paragraph.
  XCTAssertFalse(object.accessibilityRespondsToUserInteraction);

  node.actions |= static_cast<int32_t>(flutter::SemanticsAction::kTap);
  [object setSemanticsNode:&node];
  XCTAssertTrue(object.accessibilityRespondsToUserInteraction);
}

- (void)testTokenizerFindsWords {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode node;
  node.label = "Hello world";
  node.actions = static_cast<int32_t>(flutter::SemanticsAction::kSetSelection);
  FlutterSelectableTextSemanticsObject* object =
      [[FlutterSelectableTextSemanticsObject alloc] initWithBridge:bridge uid:1];
  [object setSemanticsNode:&node];

  UITextRange* word =
      [object.tokenizer rangeEnclosingPosition:[FlutterTextPosition positionWithIndex:7]
                               withGranularity:UITextGranularityWord
                                   inDirection:UITextStorageDirectionForward];
  XCTAssertEqualObjects([object textInRange:word], @"world");
}

- (void)testSelectedTextRangeComesFromBaseAndExtent {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode node;
  node.label = "Hello world";
  node.actions = static_cast<int32_t>(flutter::SemanticsAction::kSetSelection);
  FlutterSelectableTextSemanticsObject* object =
      [[FlutterSelectableTextSemanticsObject alloc] initWithBridge:bridge uid:1];
  [object setSemanticsNode:&node];

  // No selection: a caret at the start.
  XCTAssertTrue(
      NSEqualRanges(((FlutterTextRange*)object.selectedTextRange).range, NSMakeRange(0, 0)));

  // A backward selection.
  node.textSelectionBase = 5;
  node.textSelectionExtent = 1;
  [object setSemanticsNode:&node];
  XCTAssertTrue(
      NSEqualRanges(((FlutterTextRange*)object.selectedTextRange).range, NSMakeRange(1, 4)));
  XCTAssertEqualObjects([object textInRange:object.selectedTextRange], @"ello");

  // Offsets past the label are clamped.
  node.textSelectionBase = 6;
  node.textSelectionExtent = 40;
  [object setSemanticsNode:&node];
  XCTAssertTrue(
      NSEqualRanges(((FlutterTextRange*)object.selectedTextRange).range, NSMakeRange(6, 5)));
}

- (void)testSetSelectedTextRangeDispatchesSetSelection {
  flutter::testing::MockAccessibilityBridge* mock = new flutter::testing::MockAccessibilityBridge();
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(mock);
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode node;
  node.label = "Hello world";
  node.actions = static_cast<int32_t>(flutter::SemanticsAction::kSetSelection);
  FlutterSelectableTextSemanticsObject* object =
      [[FlutterSelectableTextSemanticsObject alloc] initWithBridge:bridge uid:7];
  [object setSemanticsNode:&node];

  object.selectedTextRange = [FlutterTextRange rangeWithNSRange:NSMakeRange(0, 5)];

  XCTAssertEqual(mock->observations.size(), 1u);
  XCTAssertEqual(mock->observations[0].id, 7);
  XCTAssertEqual(mock->observations[0].action, flutter::SemanticsAction::kSetSelection);
  const std::vector<uint8_t>& args = mock->observations[0].args;
  // A StandardMessageCodec map (13) of two entries, each a string key and an
  // int32 value (3): 1 + 1 + (1 + 1 + 4 + 1 + 4) + (1 + 1 + 6 + 1 + 4) bytes.
  XCTAssertEqual(args.size(), 26u);
  XCTAssertEqual(args[0], 13);
  XCTAssertEqual(args[1], 2);
  NSDictionary* decoded = [[FlutterStandardMessageCodec sharedInstance]
      decode:[NSData dataWithBytes:args.data() length:args.size()]];
  XCTAssertEqualObjects(decoded, (@{@"base" : @0, @"extent" : @5}));
  XCTAssertEqual(strcmp([decoded[@"base"] objCType], @encode(int32_t)), 0);
  XCTAssertEqual(strcmp([decoded[@"extent"] objCType], @encode(int32_t)), 0);

  // The requested selection is reported until the framework answers.
  XCTAssertTrue(
      NSEqualRanges(((FlutterTextRange*)object.selectedTextRange).range, NSMakeRange(0, 5)));
  node.textSelectionBase = 0;
  node.textSelectionExtent = 5;
  [object setSemanticsNode:&node];
  XCTAssertTrue(
      NSEqualRanges(((FlutterTextRange*)object.selectedTextRange).range, NSMakeRange(0, 5)));
}

- (void)testExtendingLeftFromACaretKeepsTheBase {
  flutter::testing::MockAccessibilityBridge* mock = new flutter::testing::MockAccessibilityBridge();
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(mock);
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode node;
  node.label = "Hello world";
  node.actions = static_cast<int32_t>(flutter::SemanticsAction::kSetSelection);
  FlutterSelectableTextSemanticsObject* object =
      [[FlutterSelectableTextSemanticsObject alloc] initWithBridge:bridge uid:1];
  [object setSemanticsNode:&node];

  // A collapsed range places the caret; the framework only records it.
  object.selectedTextRange = [FlutterTextRange rangeWithNSRange:NSMakeRange(5, 0)];
  XCTAssertTrue(
      NSEqualRanges(((FlutterTextRange*)object.selectedTextRange).range, NSMakeRange(5, 0)));
  object.selectedTextRange = [FlutterTextRange rangeWithNSRange:NSMakeRange(4, 1)];

  XCTAssertEqual(mock->observations.size(), 2u);
  NSDictionary* caret = [[FlutterStandardMessageCodec sharedInstance]
      decode:[NSData dataWithBytes:mock->observations[0].args.data()
                            length:mock->observations[0].args.size()]];
  XCTAssertEqualObjects(caret, (@{@"base" : @5, @"extent" : @5}));
  NSDictionary* extended = [[FlutterStandardMessageCodec sharedInstance]
      decode:[NSData dataWithBytes:mock->observations[1].args.data()
                            length:mock->observations[1].args.size()]];
  XCTAssertEqualObjects(extended, (@{@"base" : @5, @"extent" : @4}));
}

- (void)testReportsTheRequestedCaretUntilTheSelectionChanges {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode node;
  node.label = "Hello world";
  node.actions = static_cast<int32_t>(flutter::SemanticsAction::kSetSelection);
  node.textSelectionBase = 0;
  node.textSelectionExtent = 5;
  FlutterSelectableTextSemanticsObject* object =
      [[FlutterSelectableTextSemanticsObject alloc] initWithBridge:bridge uid:1];
  [object setSemanticsNode:&node];

  // The framework keeps its selection for a collapsed request, so the caret
  // is reported locally.
  object.selectedTextRange = [FlutterTextRange rangeWithNSRange:NSMakeRange(7, 0)];
  [object setSemanticsNode:&node];
  XCTAssertTrue(
      NSEqualRanges(((FlutterTextRange*)object.selectedTextRange).range, NSMakeRange(7, 0)));

  node.textSelectionBase = 7;
  node.textSelectionExtent = 9;
  [object setSemanticsNode:&node];
  XCTAssertTrue(
      NSEqualRanges(((FlutterTextRange*)object.selectedTextRange).range, NSMakeRange(7, 2)));

  // Without a selection, the last caret is reported.
  node.textSelectionBase = -1;
  node.textSelectionExtent = -1;
  [object setSemanticsNode:&node];
  XCTAssertTrue(
      NSEqualRanges(((FlutterTextRange*)object.selectedTextRange).range, NSMakeRange(7, 0)));

  // A new label resets the caret.
  node.label = "Hi";
  [object setSemanticsNode:&node];
  XCTAssertTrue(
      NSEqualRanges(((FlutterTextRange*)object.selectedTextRange).range, NSMakeRange(0, 0)));
}

- (void)testEditActions {
  flutter::testing::MockAccessibilityBridge* mock = new flutter::testing::MockAccessibilityBridge();
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(mock);
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode node;
  node.label = "Hello world";
  node.actions = static_cast<int32_t>(flutter::SemanticsAction::kSetSelection);
  FlutterSelectableTextSemanticsObject* object =
      [[FlutterSelectableTextSemanticsObject alloc] initWithBridge:bridge uid:1];
  [object setSemanticsNode:&node];

  XCTAssertFalse([object canPerformAction:@selector(copy:) withSender:nil]);
  XCTAssertTrue([object canPerformAction:@selector(select:) withSender:nil]);
  XCTAssertTrue([object canPerformAction:@selector(selectAll:) withSender:nil]);
  XCTAssertFalse([object canPerformAction:@selector(cut:) withSender:nil]);
  XCTAssertFalse([object canPerformAction:@selector(paste:) withSender:nil]);
  XCTAssertFalse([object canPerformAction:@selector(delete:) withSender:nil]);

  node.actions |= static_cast<int32_t>(flutter::SemanticsAction::kCopy);
  node.textSelectionBase = 0;
  node.textSelectionExtent = 5;
  [object setSemanticsNode:&node];
  XCTAssertTrue([object canPerformAction:@selector(copy:) withSender:nil]);
  XCTAssertFalse([object canPerformAction:@selector(select:) withSender:nil]);
  XCTAssertFalse([object canPerformAction:@selector(cut:) withSender:nil]);

  [object copy:nil];
  XCTAssertEqual(mock->observations.size(), 1u);
  XCTAssertEqual(mock->observations[0].action, flutter::SemanticsAction::kCopy);
  XCTAssertTrue(mock->observations[0].args.empty());

  [object selectAll:nil];
  XCTAssertEqual(mock->observations.size(), 2u);
  XCTAssertEqual(mock->observations[1].action, flutter::SemanticsAction::kSetSelection);
  NSDictionary* all = [[FlutterStandardMessageCodec sharedInstance]
      decode:[NSData dataWithBytes:mock->observations[1].args.data()
                            length:mock->observations[1].args.size()]];
  XCTAssertEqualObjects(all, (@{@"base" : @0, @"extent" : @11}));

  node.textSelectionBase = 0;
  node.textSelectionExtent = 11;
  [object setSemanticsNode:&node];
  XCTAssertFalse([object canPerformAction:@selector(selectAll:) withSender:nil]);

  // `select:` selects the word at the caret.
  node.textSelectionBase = -1;
  node.textSelectionExtent = -1;
  [object setSemanticsNode:&node];
  object.selectedTextRange = [FlutterTextRange rangeWithNSRange:NSMakeRange(7, 0)];
  [object select:nil];
  XCTAssertEqual(mock->observations.size(), 4u);
  NSDictionary* word = [[FlutterStandardMessageCodec sharedInstance]
      decode:[NSData dataWithBytes:mock->observations[3].args.data()
                            length:mock->observations[3].args.size()]];
  XCTAssertEqualObjects(word, (@{@"base" : @6, @"extent" : @11}));
}

- (void)testSelectIsOnlyOfferedOnAWord {
  flutter::testing::MockAccessibilityBridge* mock = new flutter::testing::MockAccessibilityBridge();
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(mock);
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode node;
  node.label = "Hello   world";
  node.actions = static_cast<int32_t>(flutter::SemanticsAction::kSetSelection);
  FlutterSelectableTextSemanticsObject* object =
      [[FlutterSelectableTextSemanticsObject alloc] initWithBridge:bridge uid:1];
  [object setSemanticsNode:&node];

  object.selectedTextRange = [FlutterTextRange rangeWithNSRange:NSMakeRange(6, 0)];
  XCTAssertFalse([object canPerformAction:@selector(select:) withSender:nil]);
  [object select:nil];
  XCTAssertEqual(mock->observations.size(), 1u);

  object.selectedTextRange = [FlutterTextRange rangeWithNSRange:NSMakeRange(10, 0)];
  XCTAssertTrue([object canPerformAction:@selector(select:) withSender:nil]);
}

- (void)testARequestedRangeIsDroppedWhenTheFrameworkKeepsItsSelection {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode node;
  node.label = "Hello world";
  node.actions = static_cast<int32_t>(flutter::SemanticsAction::kSetSelection) |
                 static_cast<int32_t>(flutter::SemanticsAction::kCopy);
  node.textSelectionBase = 0;
  node.textSelectionExtent = 5;
  FlutterSelectableTextSemanticsObject* object =
      [[FlutterSelectableTextSemanticsObject alloc] initWithBridge:bridge uid:1];
  [object setSemanticsNode:&node];

  object.selectedTextRange = [FlutterTextRange rangeWithNSRange:NSMakeRange(6, 5)];
  // The framework updates the node but keeps its selection, so the request
  // did not take effect; report what the framework has, which copy: copies.
  [object setSemanticsNode:&node];
  XCTAssertTrue(
      NSEqualRanges(((FlutterTextRange*)object.selectedTextRange).range, NSMakeRange(0, 5)));
}

- (void)testLayoutDirectionsFollowTheTextDirection {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode node;
  node.label = "\xD7\xA9\xD7\x9C\xD7\x95\xD7\x9D";  // "שלום"
  node.actions = static_cast<int32_t>(flutter::SemanticsAction::kSetSelection);
  node.textDirection = 1;  // RTL
  FlutterSelectableTextSemanticsObject* object =
      [[FlutterSelectableTextSemanticsObject alloc] initWithBridge:bridge uid:1];
  [object setSemanticsNode:&node];

  FlutterTextPosition* two = [FlutterTextPosition positionWithIndex:2];
  // In right-to-left text, left is towards the end.
  XCTAssertEqual(((FlutterTextPosition*)[object positionFromPosition:two
                                                         inDirection:UITextLayoutDirectionLeft
                                                              offset:1])
                     .index,
                 3u);
  XCTAssertEqual(((FlutterTextPosition*)[object positionFromPosition:two
                                                         inDirection:UITextLayoutDirectionRight
                                                              offset:1])
                     .index,
                 1u);
  XCTAssertTrue(NSEqualRanges(
      ((FlutterTextRange*)[object characterRangeByExtendingPosition:two
                                                        inDirection:UITextLayoutDirectionLeft])
          .range,
      NSMakeRange(2, 2)));
  UITextRange* all = [object textRangeFromPosition:object.beginningOfDocument
                                        toPosition:object.endOfDocument];
  XCTAssertEqual(((FlutterTextPosition*)[object positionWithinRange:all
                                                farthestInDirection:UITextLayoutDirectionLeft])
                     .index,
                 4u);
  // Up and down stay logical.
  XCTAssertEqual(((FlutterTextPosition*)[object positionFromPosition:two
                                                         inDirection:UITextLayoutDirectionUp
                                                              offset:1])
                     .index,
                 1u);
}

- (void)testALabelThatIsNotUTF8IsEmptyText {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode node;
  node.label = "\xFF\xFE";
  node.actions = static_cast<int32_t>(flutter::SemanticsAction::kSetSelection);
  FlutterSelectableTextSemanticsObject* object =
      [[FlutterSelectableTextSemanticsObject alloc] initWithBridge:bridge uid:1];
  [object setSemanticsNode:&node];
  object.selectedTextRange = [FlutterTextRange rangeWithNSRange:NSMakeRange(0, 0)];
  [object setSemanticsNode:&node];

  XCTAssertFalse(object.hasText);
  XCTAssertEqualObjects([object textInRange:[FlutterTextRange rangeWithNSRange:NSMakeRange(0, 0)]],
                        @"");
}

- (void)testGeometryComesFromTheNodeRect {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode node;
  node.label = "Hello world";
  node.actions = static_cast<int32_t>(flutter::SemanticsAction::kSetSelection);
  node.rect = SkRect::MakeXYWH(0, 0, 330, 60);
  FlutterSelectableTextSemanticsObject* object =
      [[FlutterSelectableTextSemanticsObject alloc] initWithBridge:bridge uid:1];
  [object setSemanticsNode:&node];
  [object accessibilityBridgeDidFinishUpdate];

  XCTAssertEqual(object.textInputView, bridge->view());
  UITextRange* hello = [FlutterTextRange rangeWithNSRange:NSMakeRange(0, 5)];
  CGRect first = [object firstRectForRange:hello];
  XCTAssertFalse(CGRectIsEmpty(first));
  NSArray<UITextSelectionRect*>* rects = [object selectionRectsForRange:hello];
  XCTAssertEqual(rects.count, 1u);
  XCTAssertTrue(CGRectEqualToRect(rects[0].rect, first));

  CGRect start = [object caretRectForPosition:object.beginningOfDocument];
  CGRect end = [object caretRectForPosition:object.endOfDocument];
  XCTAssertGreaterThan(CGRectGetHeight(start), 0);
  XCTAssertLessThan(CGRectGetMinX(start), CGRectGetMinX(end));

  CGPoint right = CGPointMake(CGRectGetMaxX(first), CGRectGetMidY(first));
  XCTAssertEqual(((FlutterTextPosition*)[object closestPositionToPoint:right]).index, 11u);
  CGPoint left = CGPointMake(CGRectGetMinX(first), CGRectGetMidY(first));
  XCTAssertEqual(((FlutterTextPosition*)[object closestPositionToPoint:left]).index, 0u);
  XCTAssertEqual(
      ((FlutterTextPosition*)[object closestPositionToPoint:right withinRange:hello]).index, 5u);
  XCTAssertTrue(NSEqualRanges(((FlutterTextRange*)[object characterRangeAtPoint:left]).range,
                              NSMakeRange(0, 1)));
}

- (void)testGeometryFollowsTheAncestorsTransforms {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode parent;
  parent.id = 0;
  parent.rect = SkRect::MakeXYWH(0, 0, 600, 800);
  parent.transform = SkM44::Translate(30, 90);
  parent.childrenInTraversalOrder = {1};
  flutter::SemanticsNode node;
  node.id = 1;
  node.label = "Hello world";
  node.actions = static_cast<int32_t>(flutter::SemanticsAction::kSetSelection);
  node.rect = SkRect::MakeXYWH(0, 0, 330, 60);
  node.transform = SkM44::Translate(60, 0);
  FlutterSemanticsObject* parentObject = [[FlutterSemanticsObject alloc] initWithBridge:bridge
                                                                                    uid:0];
  [parentObject setSemanticsNode:&parent];
  FlutterSelectableTextSemanticsObject* object =
      [[FlutterSelectableTextSemanticsObject alloc] initWithBridge:bridge uid:1];
  [object setSemanticsNode:&node];
  parentObject.children = @[ object ];

  CGFloat scale = (bridge->view().window.screen ?: UIScreen.mainScreen).scale;
  CGRect expected = CGRectMake(90 / scale, 90 / scale, 330 / scale, 60 / scale);
  XCTAssertTrue(CGRectEqualToRect(
      [object firstRectForRange:[FlutterTextRange rangeWithNSRange:NSMakeRange(0, 5)]], expected));
  XCTAssertEqual(CGRectGetMinX([object caretRectForPosition:object.beginningOfDocument]),
                 CGRectGetMinX(expected));
}

- (void)testTextInputViewIsNeverNil {
  UIView* view;
  FlutterSelectableTextSemanticsObject* object;
  {
    auto mock = std::make_unique<flutter::testing::MockAccessibilityBridge>();
    fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(mock.get());
    fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();
    view = mock->view();
    object = [[FlutterSelectableTextSemanticsObject alloc] initWithBridge:bridge uid:1];
    XCTAssertEqual(object.textInputView, view);
  }
  // The bridge is gone.
  XCTAssertNotNil(object.textInputView);
  XCTAssertNotEqual(object.textInputView, view);
}

- (void)testDeallocatesWithItsTokenizer {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();
  __weak FlutterSelectableTextSemanticsObject* weakObject;
  @autoreleasepool {
    flutter::SemanticsNode node;
    node.label = "Hello world";
    node.actions = static_cast<int32_t>(flutter::SemanticsAction::kSetSelection);
    FlutterSelectableTextSemanticsObject* object =
        [[FlutterSelectableTextSemanticsObject alloc] initWithBridge:bridge uid:1];
    [object setSemanticsNode:&node];
    XCTAssertNotNil(object.tokenizer);
    weakObject = object;
  }
  XCTAssertNil(weakObject);
}

- (void)testAnswersTextInputItself {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode node;
  node.label = "Hello world";
  node.actions = static_cast<int32_t>(flutter::SemanticsAction::kSetSelection);
  FlutterSelectableTextSemanticsObject* object =
      [[FlutterSelectableTextSemanticsObject alloc] initWithBridge:bridge uid:1];
  [object setSemanticsNode:&node];
  [object accessibilityBridgeDidFinishUpdate];

  XCTAssertFalse(object.usesBackingTextView);
  XCTAssertNil(object.backingTextView);
  if (@available(iOS 18.1, *)) {
    XCTAssertEqual(object.accessibilityTextInputResponder, object);
  }
}

- (void)testBackingTextViewMirrorsTheNode {
  if (@available(iOS 18.1, *)) {
    flutter::testing::MockAccessibilityBridge* mock =
        new flutter::testing::MockAccessibilityBridge();
    fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(mock);
    fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();
    UITextView* textView;
    @autoreleasepool {
      flutter::SemanticsNode node;
      node.label = "Hello world";
      node.actions = static_cast<int32_t>(flutter::SemanticsAction::kSetSelection);
      node.rect = SkRect::MakeXYWH(0, 0, 330, 60);
      node.textSelectionBase = 0;
      node.textSelectionExtent = 5;
      FlutterSelectableTextSemanticsObject* object =
          [[FlutterSelectableTextSemanticsObject alloc] initWithBridge:bridge uid:1];
      object.usesBackingTextView = YES;
      [object setSemanticsNode:&node];
      [object accessibilityBridgeDidFinishUpdate];

      textView = object.backingTextView;
      XCTAssertNotNil(textView);
      XCTAssertEqual(object.accessibilityTextInputResponder, textView);
      XCTAssertEqual(textView.superview, bridge->view());
      XCTAssertFalse(textView.isEditable);
      XCTAssertFalse(textView.userInteractionEnabled);
      XCTAssertFalse(textView.isAccessibilityElement);
      XCTAssertFalse(CGRectIsEmpty(textView.frame));
      XCTAssertEqualObjects(textView.text, @"Hello world");
      XCTAssertTrue(NSEqualRanges(textView.selectedRange, NSMakeRange(0, 5)));
      XCTAssertEqual(mock->observations.size(), 0u);

      // VoiceOver selects through the text view's UITextInput.
      UITextPosition* start = [textView positionFromPosition:textView.beginningOfDocument offset:6];
      UITextPosition* end = [textView positionFromPosition:textView.beginningOfDocument offset:11];
      textView.selectedTextRange = [textView textRangeFromPosition:start toPosition:end];
      XCTAssertEqual(mock->observations.size(), 1u);
      NSDictionary* decoded = [[FlutterStandardMessageCodec sharedInstance]
          decode:[NSData dataWithBytes:mock->observations[0].args.data()
                                length:mock->observations[0].args.size()]];
      XCTAssertEqualObjects(decoded, (@{@"base" : @6, @"extent" : @11}));

      // A request made through the object itself is mirrored too.
      object.selectedTextRange = [FlutterTextRange rangeWithNSRange:NSMakeRange(0, 11)];
      XCTAssertEqual(mock->observations.size(), 2u);
      XCTAssertTrue(NSEqualRanges(textView.selectedRange, NSMakeRange(0, 11)));

      // The framework's answer is mirrored without dispatching again.
      node.textSelectionBase = 6;
      node.textSelectionExtent = 11;
      [object setSemanticsNode:&node];
      XCTAssertTrue(NSEqualRanges(textView.selectedRange, NSMakeRange(6, 5)));
      XCTAssertEqual(mock->observations.size(), 2u);
    }
    // The text view leaves the Flutter view with its semantics object.
    XCTAssertNil(textView.superview);
  }
}

- (void)testBackingTextViewLeavesAnUnloadedView {
  if (@available(iOS 18.1, *)) {
    flutter::testing::MockAccessibilityBridge* mock =
        new flutter::testing::MockAccessibilityBridge();
    fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(mock);
    fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

    flutter::SemanticsNode node;
    node.label = "Hello world";
    node.actions = static_cast<int32_t>(flutter::SemanticsAction::kSetSelection);
    FlutterSelectableTextSemanticsObject* object =
        [[FlutterSelectableTextSemanticsObject alloc] initWithBridge:bridge uid:1];
    object.usesBackingTextView = YES;
    [object setSemanticsNode:&node];
    UITextView* textView = object.backingTextView;
    XCTAssertEqual(textView.superview, mock->view());

    mock->isViewLoaded = false;
    [object accessibilityBridgeDidChangeView];
    XCTAssertNil(textView.superview);
    XCTAssertEqual(object.accessibilityTextInputResponder, object);
  }
}

@end
