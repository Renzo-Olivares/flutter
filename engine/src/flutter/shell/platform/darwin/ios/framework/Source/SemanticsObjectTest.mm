// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import "flutter/shell/platform/darwin/common/framework/Headers/FlutterMacros.h"
#import "flutter/shell/platform/darwin/ios/framework/Source/FlutterPlatformViews_Internal.h"
#import "flutter/shell/platform/darwin/ios/framework/Source/FlutterSelectableTextSemanticsObject.h"
#import "flutter/shell/platform/darwin/ios/framework/Source/FlutterSemanticsScrollView.h"
#import "flutter/shell/platform/darwin/ios/framework/Source/FlutterTextInputPlugin.h"
#import "flutter/shell/platform/darwin/ios/framework/Source/FlutterTouchInterceptingView+Test.h"
#import "flutter/shell/platform/darwin/ios/framework/Source/SemanticsObject.h"
#import "flutter/shell/platform/darwin/ios/framework/Source/SemanticsObjectTestMocks.h"
#import "flutter/shell/platform/darwin/ios/framework/Source/TextInputSemanticsObject.h"

FLUTTER_ASSERT_ARC

const float kFloatCompareEpsilon = 0.001;

@interface SemanticsObject (UIFocusSystem) <UIFocusItem, UIFocusItemContainer>
@end

@interface FlutterScrollableSemanticsObject (UIFocusItemScrollableContainer) <
    UIFocusItemScrollableContainer>
@end

@interface TextInputSemanticsObject (Test)
- (UIView<UITextInput>*)textInputSurrogate;
@end

@interface SemanticsObjectTest : XCTestCase
@end

@implementation SemanticsObjectTest

- (void)testCreate {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();
  SemanticsObject* object = [[SemanticsObject alloc] initWithBridge:bridge uid:0];
  XCTAssertNotNil(object);
}

- (void)testUIFocusSystemMethodsDoNotCrashWhenBridgeIsDead {
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge;
  SemanticsObject* object;
  {
    auto mock_bridge = std::make_unique<flutter::testing::MockAccessibilityBridge>();
    fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(mock_bridge.get());
    bridge = factory.GetWeakPtr();
    object = [[SemanticsObject alloc] initWithBridge:bridge uid:0];
  }
  // Now bridge is nullptr.

  XCTAssertNil([object parentFocusEnvironment]);
  XCTAssertNil([object coordinateSpace]);
  XCTAssertTrue(CGRectEqualToRect([object frame], CGRectZero));
}

- (void)testSetChildren {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();
  SemanticsObject* parent = [[SemanticsObject alloc] initWithBridge:bridge uid:0];
  SemanticsObject* child = [[SemanticsObject alloc] initWithBridge:bridge uid:1];
  parent.children = @[ child ];
  XCTAssertEqual(parent, child.parent);
  parent.children = @[];
  XCTAssertNil(child.parent);
}

- (void)testOldParentDoesNotDetachReparentedChild {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();
  SemanticsObject* oldParent = [[SemanticsObject alloc] initWithBridge:bridge uid:0];
  SemanticsObject* newParent = [[SemanticsObject alloc] initWithBridge:bridge uid:1];
  SemanticsObject* child = [[SemanticsObject alloc] initWithBridge:bridge uid:2];

  oldParent.children = @[ child ];
  oldParent.childrenInHitTestOrder = @[ child ];
  newParent.children = @[ child ];
  newParent.childrenInHitTestOrder = @[ child ];

  oldParent.children = @[];
  oldParent.childrenInHitTestOrder = @[];

  XCTAssertEqual(child.parent, newParent);
}

- (void)testSetChildrenInHitTestOrderDoesNotModifyParent {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();
  SemanticsObject* traversalParent = [[SemanticsObject alloc] initWithBridge:bridge uid:0];
  SemanticsObject* hitTestParent = [[SemanticsObject alloc] initWithBridge:bridge uid:1];
  SemanticsObject* child = [[SemanticsObject alloc] initWithBridge:bridge uid:2];

  traversalParent.children = @[ child ];
  XCTAssertEqual(child.parent, traversalParent);

  hitTestParent.childrenInHitTestOrder = @[ child ];
  XCTAssertEqual(child.parent, traversalParent);

  hitTestParent.childrenInHitTestOrder = @[];
  XCTAssertEqual(child.parent, traversalParent);
}

- (void)testAccessibilityHitTestFocusAtLeaf {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();
  SemanticsObject* object0 = [[SemanticsObject alloc] initWithBridge:bridge uid:0];
  SemanticsObject* object1 = [[SemanticsObject alloc] initWithBridge:bridge uid:1];
  SemanticsObject* object2 = [[SemanticsObject alloc] initWithBridge:bridge uid:2];
  SemanticsObject* object3 = [[SemanticsObject alloc] initWithBridge:bridge uid:3];
  object0.children = @[ object1 ];
  object0.childrenInHitTestOrder = @[ object1 ];
  object1.children = @[ object2, object3 ];
  object1.childrenInHitTestOrder = @[ object2, object3 ];

  flutter::SemanticsNode node0;
  node0.id = 0;
  node0.rect = SkRect::MakeXYWH(0, 0, 200, 200);
  node0.label = "0";
  [object0 setSemanticsNode:&node0];

  flutter::SemanticsNode node1;
  node1.id = 1;
  node1.rect = SkRect::MakeXYWH(0, 0, 200, 200);
  node1.label = "1";
  [object1 setSemanticsNode:&node1];

  flutter::SemanticsNode node2;
  node2.id = 2;
  node2.rect = SkRect::MakeXYWH(0, 0, 100, 100);
  node2.label = "2";
  [object2 setSemanticsNode:&node2];

  flutter::SemanticsNode node3;
  node3.id = 3;
  node3.rect = SkRect::MakeXYWH(0, 0, 200, 200);
  node3.label = "3";
  [object3 setSemanticsNode:&node3];

  CGPoint point = CGPointMake(10, 10);
  id hitTestResult = [object0 _accessibilityHitTest:point withEvent:nil];

  // Focus to object2 because it's the first object in hit test order
  XCTAssertEqual(hitTestResult, object2);
}

- (void)testAccessibilityHitTestNoFocusableItem {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();
  SemanticsObject* object0 = [[SemanticsObject alloc] initWithBridge:bridge uid:0];
  SemanticsObject* object1 = [[SemanticsObject alloc] initWithBridge:bridge uid:1];
  SemanticsObject* object2 = [[SemanticsObject alloc] initWithBridge:bridge uid:2];
  SemanticsObject* object3 = [[SemanticsObject alloc] initWithBridge:bridge uid:3];
  object0.children = @[ object1 ];
  object0.childrenInHitTestOrder = @[ object1 ];
  object1.children = @[ object2, object3 ];
  object1.childrenInHitTestOrder = @[ object2, object3 ];

  flutter::SemanticsNode node0;
  node0.id = 0;
  node0.rect = SkRect::MakeXYWH(0, 0, 200, 200);
  [object0 setSemanticsNode:&node0];

  flutter::SemanticsNode node1;
  node1.id = 1;
  node1.rect = SkRect::MakeXYWH(0, 0, 200, 200);
  [object1 setSemanticsNode:&node1];

  flutter::SemanticsNode node2;
  node2.id = 2;
  node2.rect = SkRect::MakeXYWH(0, 0, 100, 100);
  [object2 setSemanticsNode:&node2];

  flutter::SemanticsNode node3;
  node3.id = 3;
  node3.rect = SkRect::MakeXYWH(0, 0, 200, 200);
  [object3 setSemanticsNode:&node3];

  CGPoint point = CGPointMake(10, 10);
  id hitTestResult = [object0 _accessibilityHitTest:point withEvent:nil];

  XCTAssertNil(hitTestResult);
}

- (void)testAccessibilityScrollToVisible {
  fml::WeakPtrFactory<flutter::testing::MockAccessibilityBridge> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::testing::MockAccessibilityBridge> bridge = factory.GetWeakPtr();
  SemanticsObject* object3 = [[SemanticsObject alloc] initWithBridge:bridge uid:3];

  flutter::SemanticsNode node3;
  node3.id = 3;
  node3.rect = SkRect::MakeXYWH(0, 0, 200, 200);
  [object3 setSemanticsNode:&node3];

  [object3 accessibilityScrollToVisible];

  XCTAssertTrue(bridge->observations.size() == 1);
  XCTAssertTrue(bridge->observations[0].id == 3);
  XCTAssertTrue(bridge->observations[0].action == flutter::SemanticsAction::kShowOnScreen);
}

- (void)testFlutterScrollableSemanticsObjectIsNotAccessibilityElementWhenVoiceOverIsRunning {
  flutter::testing::MockAccessibilityBridge* mock = new flutter::testing::MockAccessibilityBridge();
  mock->isVoiceOverRunningValue = true;
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(mock);
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode node;
  node.flags.hasImplicitScrolling = true;

  node.actions = flutter::kHorizontalScrollSemanticsActions |
                 static_cast<int32_t>(flutter::SemanticsAction::kCustomAction);

  node.rect = SkRect::MakeXYWH(0, 0, 100, 200);
  node.scrollExtentMax = 100.0;
  node.scrollPosition = 0.0;

  FlutterScrollableSemanticsObject* scrollable =
      [[FlutterScrollableSemanticsObject alloc] initWithBridge:bridge uid:0];
  [scrollable setSemanticsNode:&node];
  [scrollable accessibilityBridgeDidFinishUpdate];

  UIScrollView* scrollView = [scrollable nativeAccessibility];

  XCTAssertFalse(scrollView.isAccessibilityElement);
}

- (void)testAccessibilityScrollToVisibleWithChild {
  fml::WeakPtrFactory<flutter::testing::MockAccessibilityBridge> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::testing::MockAccessibilityBridge> bridge = factory.GetWeakPtr();
  SemanticsObject* object3 = [[SemanticsObject alloc] initWithBridge:bridge uid:3];

  flutter::SemanticsNode node3;
  node3.id = 3;
  node3.rect = SkRect::MakeXYWH(0, 0, 200, 200);
  [object3 setSemanticsNode:&node3];

  [object3 accessibilityScrollToVisibleWithChild:object3];

  XCTAssertTrue(bridge->observations.size() == 1);
  XCTAssertTrue(bridge->observations[0].id == 3);
  XCTAssertTrue(bridge->observations[0].action == flutter::SemanticsAction::kShowOnScreen);
}

- (void)testAccessibilityHitTestOutOfRect {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();
  SemanticsObject* object0 = [[SemanticsObject alloc] initWithBridge:bridge uid:0];
  SemanticsObject* object1 = [[SemanticsObject alloc] initWithBridge:bridge uid:1];
  SemanticsObject* object2 = [[SemanticsObject alloc] initWithBridge:bridge uid:2];
  SemanticsObject* object3 = [[SemanticsObject alloc] initWithBridge:bridge uid:3];
  object0.children = @[ object1 ];
  object0.childrenInHitTestOrder = @[ object1 ];
  object1.children = @[ object2, object3 ];
  object1.childrenInHitTestOrder = @[ object2, object3 ];

  flutter::SemanticsNode node0;
  node0.id = 0;
  node0.rect = SkRect::MakeXYWH(0, 0, 200, 200);
  node0.label = "0";
  [object0 setSemanticsNode:&node0];

  flutter::SemanticsNode node1;
  node1.id = 1;
  node1.rect = SkRect::MakeXYWH(0, 0, 200, 200);
  node1.label = "1";
  [object1 setSemanticsNode:&node1];

  flutter::SemanticsNode node2;
  node2.id = 2;
  node2.rect = SkRect::MakeXYWH(0, 0, 100, 100);
  node2.label = "2";
  [object2 setSemanticsNode:&node2];

  flutter::SemanticsNode node3;
  node3.id = 3;
  node3.rect = SkRect::MakeXYWH(0, 0, 200, 200);
  node3.label = "3";
  [object3 setSemanticsNode:&node3];

  CGPoint point = CGPointMake(300, 300);
  id hitTestResult = [object0 _accessibilityHitTest:point withEvent:nil];

  XCTAssertNil(hitTestResult);
}

- (void)testReplaceChildAtIndex {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();
  SemanticsObject* parent = [[SemanticsObject alloc] initWithBridge:bridge uid:0];
  SemanticsObject* child1 = [[SemanticsObject alloc] initWithBridge:bridge uid:1];
  SemanticsObject* child2 = [[SemanticsObject alloc] initWithBridge:bridge uid:2];
  parent.children = @[ child1 ];
  [parent replaceChildAtIndex:0 withChild:child2];
  XCTAssertNil(child1.parent);
  XCTAssertEqual(parent, child2.parent);
  XCTAssertEqualObjects(parent.children, @[ child2 ]);
}

- (void)testPlainSemanticsObjectWithLabelHasStaticTextTrait {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();
  flutter::SemanticsNode node;
  node.label = "foo";
  FlutterSemanticsObject* object = [[FlutterSemanticsObject alloc] initWithBridge:bridge uid:0];
  [object setSemanticsNode:&node];
  XCTAssertEqual([object accessibilityTraits], UIAccessibilityTraitStaticText);
}

- (void)testPlainSemanticsObjectWithHeadingLevelHasHeaderTrait {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();
  flutter::SemanticsNode node;
  node.headingLevel = 2;
  FlutterSemanticsObject* object = [[FlutterSemanticsObject alloc] initWithBridge:bridge uid:0];
  [object setSemanticsNode:&node];
  XCTAssertTrue(([object accessibilityTraits] & UIAccessibilityTraitHeader) > 0);
}

- (void)testNodeWithImplicitScrollIsAnAccessibilityElementWhenItisHidden {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();
  flutter::SemanticsNode node;

  node.flags.hasImplicitScrolling = true;
  node.flags.isHidden = true;
  FlutterSemanticsObject* object = [[FlutterSemanticsObject alloc] initWithBridge:bridge uid:0];
  [object setSemanticsNode:&node];
  XCTAssertEqual(object.isAccessibilityElement, YES);
}

- (void)testNodeWithImplicitScrollIsNotAnAccessibilityElementWhenItisNotHidden {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();
  flutter::SemanticsNode node;
  node.flags.hasImplicitScrolling = true;
  FlutterSemanticsObject* object = [[FlutterSemanticsObject alloc] initWithBridge:bridge uid:0];
  [object setSemanticsNode:&node];
  XCTAssertEqual(object.isAccessibilityElement, NO);
}

- (void)testIntresetingSemanticsObjectWithLabelHasStaticTextTrait {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();
  flutter::SemanticsNode node;
  node.label = "foo";
  FlutterSemanticsObject* object = [[FlutterSemanticsObject alloc] initWithBridge:bridge uid:0];
  SemanticsObject* child1 = [[SemanticsObject alloc] initWithBridge:bridge uid:1];
  object.children = @[ child1 ];
  [object setSemanticsNode:&node];
  XCTAssertEqual([object accessibilityTraits], UIAccessibilityTraitNone);
}

- (void)testIntresetingSemanticsObjectWithLabelHasStaticTextTrait1 {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();
  flutter::SemanticsNode node;
  node.label = "foo";
  node.flags.isTextField = true;
  FlutterSemanticsObject* object = [[FlutterSemanticsObject alloc] initWithBridge:bridge uid:0];
  [object setSemanticsNode:&node];
  XCTAssertEqual([object accessibilityTraits], UIAccessibilityTraitNone);
}

- (void)testIntresetingSemanticsObjectWithLabelHasStaticTextTrait2 {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();
  flutter::SemanticsNode node;
  node.label = "foo";

  node.flags.isButton = true;
  FlutterSemanticsObject* object = [[FlutterSemanticsObject alloc] initWithBridge:bridge uid:0];
  [object setSemanticsNode:&node];
  XCTAssertEqual([object accessibilityTraits], UIAccessibilityTraitButton);
}

- (void)testVerticalFlutterScrollableSemanticsObject {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  float transformScale = 0.5f;
  float screenScale = [[bridge->view() window] screen].scale;
  float effectivelyScale = transformScale / screenScale;
  float x = 10;
  float y = 10;
  float w = 100;
  float h = 200;
  float scrollExtentMax = 500.0;
  float scrollPosition = 150.0;

  flutter::SemanticsNode node;
  node.flags.hasImplicitScrolling = true;
  node.actions = flutter::kVerticalScrollSemanticsActions;
  node.rect = SkRect::MakeXYWH(x, y, w, h);
  node.scrollExtentMax = scrollExtentMax;
  node.scrollPosition = scrollPosition;
  node.transform = {
      transformScale, 0, 0, 0, 0, transformScale, 0, 0, 0, 0, transformScale, 0, 0, 0, 0, 1.0};
  FlutterScrollableSemanticsObject* scrollable =
      [[FlutterScrollableSemanticsObject alloc] initWithBridge:bridge uid:0];
  [scrollable setSemanticsNode:&node];
  [scrollable accessibilityBridgeDidFinishUpdate];
  UIScrollView* scrollView = [scrollable nativeAccessibility];

  XCTAssertEqualWithAccuracy(scrollView.frame.origin.x, x * effectivelyScale, kFloatCompareEpsilon);
  XCTAssertEqualWithAccuracy(scrollView.frame.origin.y, y * effectivelyScale, kFloatCompareEpsilon);
  XCTAssertEqualWithAccuracy(scrollView.frame.size.width, w * effectivelyScale,
                             kFloatCompareEpsilon);
  XCTAssertEqualWithAccuracy(scrollView.frame.size.height, h * effectivelyScale,
                             kFloatCompareEpsilon);

  XCTAssertEqualWithAccuracy(scrollView.contentSize.width, w * effectivelyScale,
                             kFloatCompareEpsilon);
  XCTAssertEqualWithAccuracy(scrollView.contentSize.height,
                             (h + scrollExtentMax) * effectivelyScale, kFloatCompareEpsilon);

  XCTAssertEqual(scrollView.contentOffset.x, 0);
  XCTAssertEqualWithAccuracy(scrollView.contentOffset.y, scrollPosition * effectivelyScale,
                             kFloatCompareEpsilon);
}

- (void)testVerticalFlutterScrollableSemanticsObjectNoWindowDoesNotCrash {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridgeNoWindow());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  float transformScale = 0.5f;
  float x = 10;
  float y = 10;
  float w = 100;
  float h = 200;
  float scrollExtentMax = 500.0;
  float scrollPosition = 150.0;

  flutter::SemanticsNode node;
  node.flags.hasImplicitScrolling = true;
  node.actions = flutter::kVerticalScrollSemanticsActions;
  node.rect = SkRect::MakeXYWH(x, y, w, h);
  node.scrollExtentMax = scrollExtentMax;
  node.scrollPosition = scrollPosition;
  node.transform = {
      transformScale, 0, 0, 0, 0, transformScale, 0, 0, 0, 0, transformScale, 0, 0, 0, 0, 1.0};
  FlutterScrollableSemanticsObject* scrollable =
      [[FlutterScrollableSemanticsObject alloc] initWithBridge:bridge uid:0];
  [scrollable setSemanticsNode:&node];
  [scrollable accessibilityBridgeDidFinishUpdate];
  XCTAssertNoThrow([scrollable accessibilityBridgeDidFinishUpdate]);
}

- (void)testHorizontalFlutterScrollableSemanticsObject {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  float transformScale = 0.5f;
  float screenScale = [[bridge->view() window] screen].scale;
  float effectivelyScale = transformScale / screenScale;
  float x = 10;
  float y = 10;
  float w = 100;
  float h = 200;
  float scrollExtentMax = 500.0;
  float scrollPosition = 150.0;

  flutter::SemanticsNode node;
  node.flags.hasImplicitScrolling = true;
  node.actions = flutter::kHorizontalScrollSemanticsActions;
  node.rect = SkRect::MakeXYWH(x, y, w, h);
  node.scrollExtentMax = scrollExtentMax;
  node.scrollPosition = scrollPosition;
  node.transform = {
      transformScale, 0, 0, 0, 0, transformScale, 0, 0, 0, 0, transformScale, 0, 0, 0, 0, 1.0};
  FlutterScrollableSemanticsObject* scrollable =
      [[FlutterScrollableSemanticsObject alloc] initWithBridge:bridge uid:0];
  [scrollable setSemanticsNode:&node];
  [scrollable accessibilityBridgeDidFinishUpdate];
  UIScrollView* scrollView = [scrollable nativeAccessibility];

  XCTAssertEqualWithAccuracy(scrollView.frame.origin.x, x * effectivelyScale, kFloatCompareEpsilon);
  XCTAssertEqualWithAccuracy(scrollView.frame.origin.y, y * effectivelyScale, kFloatCompareEpsilon);
  XCTAssertEqualWithAccuracy(scrollView.frame.size.width, w * effectivelyScale,
                             kFloatCompareEpsilon);
  XCTAssertEqualWithAccuracy(scrollView.frame.size.height, h * effectivelyScale,
                             kFloatCompareEpsilon);

  XCTAssertEqualWithAccuracy(scrollView.contentSize.width, (w + scrollExtentMax) * effectivelyScale,
                             kFloatCompareEpsilon);
  XCTAssertEqualWithAccuracy(scrollView.contentSize.height, h * effectivelyScale,
                             kFloatCompareEpsilon);

  XCTAssertEqualWithAccuracy(scrollView.contentOffset.x, scrollPosition * effectivelyScale,
                             kFloatCompareEpsilon);
  XCTAssertEqual(scrollView.contentOffset.y, 0);
}

- (void)testCanHandleInfiniteScrollExtent {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  float transformScale = 0.5f;
  float screenScale = [[bridge->view() window] screen].scale;
  float effectivelyScale = transformScale / screenScale;
  float x = 10;
  float y = 10;
  float w = 100;
  float h = 200;
  float scrollExtentMax = INFINITY;
  float scrollPosition = 150.0;

  flutter::SemanticsNode node;
  node.flags.hasImplicitScrolling = true;
  node.actions = flutter::kVerticalScrollSemanticsActions;
  node.rect = SkRect::MakeXYWH(x, y, w, h);
  node.scrollExtentMax = scrollExtentMax;
  node.scrollPosition = scrollPosition;
  node.transform = {
      transformScale, 0, 0, 0, 0, transformScale, 0, 0, 0, 0, transformScale, 0, 0, 0, 0, 1.0};
  FlutterScrollableSemanticsObject* scrollable =
      [[FlutterScrollableSemanticsObject alloc] initWithBridge:bridge uid:0];
  [scrollable setSemanticsNode:&node];
  [scrollable accessibilityBridgeDidFinishUpdate];
  UIScrollView* scrollView = [scrollable nativeAccessibility];
  XCTAssertEqualWithAccuracy(scrollView.frame.origin.x, x * effectivelyScale, kFloatCompareEpsilon);
  XCTAssertEqualWithAccuracy(scrollView.frame.origin.y, y * effectivelyScale, kFloatCompareEpsilon);
  XCTAssertEqualWithAccuracy(scrollView.frame.size.width, w * effectivelyScale,
                             kFloatCompareEpsilon);
  XCTAssertEqualWithAccuracy(scrollView.frame.size.height, h * effectivelyScale,
                             kFloatCompareEpsilon);

  XCTAssertEqualWithAccuracy(scrollView.contentSize.width, w * effectivelyScale,
                             kFloatCompareEpsilon);
  XCTAssertEqualWithAccuracy(scrollView.contentSize.height,
                             (h + kScrollExtentMaxForInf + scrollPosition) * effectivelyScale,
                             kFloatCompareEpsilon);

  XCTAssertEqual(scrollView.contentOffset.x, 0);
  XCTAssertEqualWithAccuracy(scrollView.contentOffset.y, scrollPosition * effectivelyScale,
                             kFloatCompareEpsilon);
}

- (void)testCanHandleNaNScrollExtentAndScrollPoisition {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  float transformScale = 0.5f;
  float screenScale = [[bridge->view() window] screen].scale;
  float effectivelyScale = transformScale / screenScale;
  float x = 10;
  float y = 10;
  float w = 100;
  float h = 200;
  float scrollExtentMax = std::nan("");
  float scrollPosition = std::nan("");

  flutter::SemanticsNode node;
  node.flags.hasImplicitScrolling = true;
  node.actions = flutter::kVerticalScrollSemanticsActions;
  node.rect = SkRect::MakeXYWH(x, y, w, h);
  node.scrollExtentMax = scrollExtentMax;
  node.scrollPosition = scrollPosition;
  node.transform = {
      transformScale, 0, 0, 0, 0, transformScale, 0, 0, 0, 0, transformScale, 0, 0, 0, 0, 1.0};
  FlutterScrollableSemanticsObject* scrollable =
      [[FlutterScrollableSemanticsObject alloc] initWithBridge:bridge uid:0];
  [scrollable setSemanticsNode:&node];
  [scrollable accessibilityBridgeDidFinishUpdate];
  UIScrollView* scrollView = [scrollable nativeAccessibility];

  XCTAssertEqualWithAccuracy(scrollView.frame.origin.x, x * effectivelyScale, kFloatCompareEpsilon);
  XCTAssertEqualWithAccuracy(scrollView.frame.origin.y, y * effectivelyScale, kFloatCompareEpsilon);
  XCTAssertEqualWithAccuracy(scrollView.frame.size.width, w * effectivelyScale,
                             kFloatCompareEpsilon);
  XCTAssertEqualWithAccuracy(scrollView.frame.size.height, h * effectivelyScale,
                             kFloatCompareEpsilon);

  // Content size equal to the scrollable size.
  XCTAssertEqualWithAccuracy(scrollView.contentSize.width, w * effectivelyScale,
                             kFloatCompareEpsilon);
  XCTAssertEqualWithAccuracy(scrollView.contentSize.height, h * effectivelyScale,
                             kFloatCompareEpsilon);

  XCTAssertEqual(scrollView.contentOffset.x, 0);
  XCTAssertEqual(scrollView.contentOffset.y, 0);
}

- (void)testFlutterScrollableSemanticsObjectIsNotHittestable {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode node;
  node.flags.hasImplicitScrolling = true;
  node.actions = flutter::kHorizontalScrollSemanticsActions;
  node.rect = SkRect::MakeXYWH(0, 0, 100, 200);
  node.scrollExtentMax = 100.0;
  node.scrollPosition = 0.0;

  FlutterScrollableSemanticsObject* scrollable =
      [[FlutterScrollableSemanticsObject alloc] initWithBridge:bridge uid:0];
  [scrollable setSemanticsNode:&node];
  [scrollable accessibilityBridgeDidFinishUpdate];
  UIScrollView* scrollView = [scrollable nativeAccessibility];
  XCTAssertEqual([scrollView hitTest:CGPointMake(10, 10) withEvent:nil], nil);
}

- (void)testFlutterScrollableSemanticsObjectIsHiddenWhenVoiceOverIsRunning {
  flutter::testing::MockAccessibilityBridge* mock = new flutter::testing::MockAccessibilityBridge();
  mock->isVoiceOverRunningValue = false;
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(mock);
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode node;
  node.flags.hasImplicitScrolling = true;
  node.actions = flutter::kHorizontalScrollSemanticsActions;
  node.rect = SkRect::MakeXYWH(0, 0, 100, 200);
  node.scrollExtentMax = 100.0;
  node.scrollPosition = 0.0;

  FlutterScrollableSemanticsObject* scrollable =
      [[FlutterScrollableSemanticsObject alloc] initWithBridge:bridge uid:0];
  [scrollable setSemanticsNode:&node];
  [scrollable accessibilityBridgeDidFinishUpdate];
  UIScrollView* scrollView = [scrollable nativeAccessibility];
  XCTAssertTrue(scrollView.isAccessibilityElement);
  mock->isVoiceOverRunningValue = true;
  XCTAssertFalse(scrollView.isAccessibilityElement);
}

- (void)testFlutterSemanticsObjectHasIdentifier {
  flutter::testing::MockAccessibilityBridge* mock = new flutter::testing::MockAccessibilityBridge();
  mock->isVoiceOverRunningValue = true;
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(mock);
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode node;
  node.identifier = "identifier";

  FlutterSemanticsObject* object = [[FlutterSemanticsObject alloc] initWithBridge:bridge uid:0];
  [object setSemanticsNode:&node];
  XCTAssertTrue([object.accessibilityIdentifier isEqualToString:@"identifier"]);
}

- (void)testFlutterSemanticsObjectHasLocale {
  flutter::testing::MockAccessibilityBridge* mock = new flutter::testing::MockAccessibilityBridge();
  mock->isVoiceOverRunningValue = true;
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(mock);
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode node;
  node.locale = "es-MX";

  FlutterSemanticsObject* object = [[FlutterSemanticsObject alloc] initWithBridge:bridge uid:0];
  [object setSemanticsNode:&node];
  XCTAssertTrue([object.accessibilityLanguage isEqualToString:@"es-MX"]);
}

- (void)testFlutterSemanticsObjectUseDefaultLocale {
  flutter::testing::MockAccessibilityBridge* mock = new flutter::testing::MockAccessibilityBridge();
  mock->isVoiceOverRunningValue = true;
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(mock);
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode node;
  mock->mockedLocale = @"es-MX";

  FlutterSemanticsObject* object = [[FlutterSemanticsObject alloc] initWithBridge:bridge uid:0];
  [object setSemanticsNode:&node];
  XCTAssertTrue([object.accessibilityLanguage isEqualToString:@"es-MX"]);
}

- (void)testFlutterSemanticsObjectPrioritizedSectionLocale {
  flutter::testing::MockAccessibilityBridge* mock = new flutter::testing::MockAccessibilityBridge();
  mock->isVoiceOverRunningValue = true;
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(mock);
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode node;
  // Set both locales.
  mock->mockedLocale = @"es-MX";
  node.locale = "zh-TW";

  FlutterSemanticsObject* object = [[FlutterSemanticsObject alloc] initWithBridge:bridge uid:0];
  [object setSemanticsNode:&node];
  // node.locale takes priority.
  XCTAssertTrue([object.accessibilityLanguage isEqualToString:@"zh-TW"]);
}

- (void)testFlutterSemanticsObjectLocaleNil {
  flutter::testing::MockAccessibilityBridge* mock = new flutter::testing::MockAccessibilityBridge();
  mock->isVoiceOverRunningValue = true;
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(mock);
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode node;

  FlutterSemanticsObject* object = [[FlutterSemanticsObject alloc] initWithBridge:bridge uid:0];
  [object setSemanticsNode:&node];
  XCTAssertTrue(object.accessibilityLanguage == nil);
}

- (void)testFlutterScrollableSemanticsObjectWithLabelValueHintIsNotHiddenWhenVoiceOverIsRunning {
  flutter::testing::MockAccessibilityBridge* mock = new flutter::testing::MockAccessibilityBridge();
  mock->isVoiceOverRunningValue = true;
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(mock);
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode node;
  node.flags.hasImplicitScrolling = true;
  node.actions = flutter::kHorizontalScrollSemanticsActions;
  node.rect = SkRect::MakeXYWH(0, 0, 100, 200);
  node.label = "label";
  node.value = "value";
  node.hint = "hint";
  node.scrollExtentMax = 100.0;
  node.scrollPosition = 0.0;

  FlutterScrollableSemanticsObject* scrollable =
      [[FlutterScrollableSemanticsObject alloc] initWithBridge:bridge uid:0];
  [scrollable setSemanticsNode:&node];
  [scrollable accessibilityBridgeDidFinishUpdate];
  UIScrollView* scrollView = [scrollable nativeAccessibility];
  XCTAssertTrue(scrollView.isAccessibilityElement);
  XCTAssertTrue(
      [scrollView.accessibilityLabel isEqualToString:NSLocalizedString(@"label", @"test")]);
  XCTAssertTrue(
      [scrollView.accessibilityValue isEqualToString:NSLocalizedString(@"value", @"test")]);
  XCTAssertTrue([scrollView.accessibilityHint isEqualToString:NSLocalizedString(@"hint", @"test")]);
}

- (void)testFlutterSemanticsObjectMergeTooltipToLabel {
  flutter::testing::MockAccessibilityBridge* mock = new flutter::testing::MockAccessibilityBridge();
  mock->isVoiceOverRunningValue = true;
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(mock);
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode node;
  node.rect = SkRect::MakeXYWH(0, 0, 100, 200);
  node.label = "label";
  node.tooltip = "tooltip";
  FlutterSemanticsObject* object = [[FlutterSemanticsObject alloc] initWithBridge:bridge uid:0];
  [object setSemanticsNode:&node];
  XCTAssertTrue(object.isAccessibilityElement);
  XCTAssertTrue([object.accessibilityLabel isEqualToString:@"label\ntooltip"]);
}

- (void)testSemanticsObjectContainerAccessibilityFrameCoversEntireScreen {
  flutter::testing::MockAccessibilityBridge* mock = new flutter::testing::MockAccessibilityBridge();
  mock->isVoiceOverRunningValue = true;
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(mock);
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode parent;
  parent.id = 0;
  parent.actions = static_cast<int32_t>(flutter::SemanticsAction::kTap);

  flutter::SemanticsNode child;
  child.id = 1;
  child.actions = static_cast<int32_t>(flutter::SemanticsAction::kTap);
  child.rect = SkRect::MakeXYWH(0, 0, 100, 100);
  parent.childrenInTraversalOrder.push_back(1);

  FlutterSemanticsObject* parentObject = [[FlutterSemanticsObject alloc] initWithBridge:bridge
                                                                                    uid:0];
  [parentObject setSemanticsNode:&parent];

  FlutterSemanticsObject* childObject = [[FlutterSemanticsObject alloc] initWithBridge:bridge
                                                                                   uid:1];
  [childObject setSemanticsNode:&child];

  parentObject.children = @[ childObject ];
  [parentObject accessibilityBridgeDidFinishUpdate];
  [childObject accessibilityBridgeDidFinishUpdate];

  SemanticsObjectContainer* container =
      static_cast<SemanticsObjectContainer*>(parentObject.accessibilityContainer);

  XCTAssertTrue(childObject.accessibilityRespondsToUserInteraction);
  XCTAssertTrue(CGRectEqualToRect(container.accessibilityFrame, UIScreen.mainScreen.bounds));
}

- (void)testRootSemanticsObjectContainerAccessibilityContainerIsBridgeView {
  flutter::testing::MockAccessibilityBridge* mock = new flutter::testing::MockAccessibilityBridge();
  mock->isVoiceOverRunningValue = true;
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(mock);
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode root;
  root.id = kRootNodeId;

  FlutterSemanticsObject* rootObject = [[FlutterSemanticsObject alloc] initWithBridge:bridge
                                                                                  uid:kRootNodeId];
  [rootObject setSemanticsNode:&root];

  SemanticsObjectContainer* container =
      static_cast<SemanticsObjectContainer*>(rootObject.accessibilityContainer);

  XCTAssertEqual(container.accessibilityContainer, mock->view());
}

- (void)testBridgeViewIsNilWhileBridgeIsAliveAndViewIsNotLoaded {
  flutter::testing::MockAccessibilityBridge* mock = new flutter::testing::MockAccessibilityBridge();
  mock->isViewLoaded = false;
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(mock);
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode root;
  root.id = kRootNodeId;
  root.rect = SkRect::MakeXYWH(0, 0, 100, 100);

  FlutterSemanticsObject* rootObject = [[FlutterSemanticsObject alloc] initWithBridge:bridge
                                                                                  uid:kRootNodeId];
  [rootObject setSemanticsNode:&root];

  XCTAssertNotNil(mock->view());
  XCTAssertTrue(rootObject.bridge != nullptr);
  XCTAssertNil(rootObject.bridgeView);
  XCTAssertTrue(CGRectEqualToRect(rootObject.accessibilityFrame, CGRectZero));

  SemanticsObjectContainer* container =
      static_cast<SemanticsObjectContainer*>(rootObject.accessibilityContainer);
  XCTAssertNotNil(container);
  XCTAssertNil(container.accessibilityContainer);
}

- (void)testChildSemanticsObjectContainerAccessibilityContainerIsParentContainer {
  flutter::testing::MockAccessibilityBridge* mock = new flutter::testing::MockAccessibilityBridge();
  mock->isVoiceOverRunningValue = true;
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(mock);
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode root;
  root.id = kRootNodeId;
  root.childrenInTraversalOrder.push_back(1);

  flutter::SemanticsNode child;
  child.id = 1;
  child.childrenInTraversalOrder.push_back(2);

  flutter::SemanticsNode grandchild;
  grandchild.id = 2;

  FlutterSemanticsObject* rootObject = [[FlutterSemanticsObject alloc] initWithBridge:bridge
                                                                                  uid:kRootNodeId];
  [rootObject setSemanticsNode:&root];

  FlutterSemanticsObject* childObject = [[FlutterSemanticsObject alloc] initWithBridge:bridge
                                                                                   uid:1];
  [childObject setSemanticsNode:&child];

  FlutterSemanticsObject* grandchildObject = [[FlutterSemanticsObject alloc] initWithBridge:bridge
                                                                                        uid:2];
  [grandchildObject setSemanticsNode:&grandchild];

  rootObject.children = @[ childObject ];
  childObject.children = @[ grandchildObject ];

  SemanticsObjectContainer* rootContainer =
      static_cast<SemanticsObjectContainer*>(rootObject.accessibilityContainer);
  SemanticsObjectContainer* childContainer =
      static_cast<SemanticsObjectContainer*>(childObject.accessibilityContainer);

  XCTAssertEqual(childContainer.accessibilityContainer, rootContainer);
}

- (void)testFlutterSemanticsObjectAttributedStringsDoNotCrashWhenEmpty {
  flutter::testing::MockAccessibilityBridge* mock = new flutter::testing::MockAccessibilityBridge();
  mock->isVoiceOverRunningValue = true;
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(mock);
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode node;
  node.rect = SkRect::MakeXYWH(0, 0, 100, 200);
  FlutterSemanticsObject* object = [[FlutterSemanticsObject alloc] initWithBridge:bridge uid:0];
  [object setSemanticsNode:&node];
  XCTAssertTrue(object.accessibilityAttributedLabel == nil);
}

- (void)testFlutterScrollableSemanticsObjectReturnsParentContainerIfNoChildren {
  flutter::testing::MockAccessibilityBridge* mock = new flutter::testing::MockAccessibilityBridge();
  mock->isVoiceOverRunningValue = true;
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(mock);
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode parent;
  parent.id = 0;
  parent.rect = SkRect::MakeXYWH(0, 0, 100, 200);
  parent.label = "label";
  parent.value = "value";
  parent.hint = "hint";

  flutter::SemanticsNode node;
  node.id = 1;
  node.flags.hasImplicitScrolling = true;
  node.actions = flutter::kHorizontalScrollSemanticsActions;
  node.rect = SkRect::MakeXYWH(0, 0, 100, 200);
  node.label = "label";
  node.value = "value";
  node.hint = "hint";
  node.scrollExtentMax = 100.0;
  node.scrollPosition = 0.0;
  parent.childrenInTraversalOrder.push_back(1);

  FlutterSemanticsObject* parentObject = [[FlutterSemanticsObject alloc] initWithBridge:bridge
                                                                                    uid:0];
  [parentObject setSemanticsNode:&parent];

  FlutterScrollableSemanticsObject* scrollable =
      [[FlutterScrollableSemanticsObject alloc] initWithBridge:bridge uid:1];
  [scrollable setSemanticsNode:&node];
  UIScrollView* scrollView = [scrollable nativeAccessibility];

  parentObject.children = @[ scrollable ];
  [parentObject accessibilityBridgeDidFinishUpdate];
  [scrollable accessibilityBridgeDidFinishUpdate];
  XCTAssertTrue(scrollView.isAccessibilityElement);
  SemanticsObjectContainer* container =
      static_cast<SemanticsObjectContainer*>(scrollable.accessibilityContainer);
  XCTAssertEqual(container.semanticsObject, parentObject);
}

- (void)testFlutterScrollableSemanticsObjectNoScrollBarOrContentInsets {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode node;
  node.flags.hasImplicitScrolling = true;
  node.actions = flutter::kHorizontalScrollSemanticsActions;
  node.rect = SkRect::MakeXYWH(0, 0, 100, 200);
  node.scrollExtentMax = 100.0;
  node.scrollPosition = 0.0;

  FlutterScrollableSemanticsObject* scrollable =
      [[FlutterScrollableSemanticsObject alloc] initWithBridge:bridge uid:0];
  [scrollable setSemanticsNode:&node];
  [scrollable accessibilityBridgeDidFinishUpdate];
  UIScrollView* scrollView = [scrollable nativeAccessibility];

  XCTAssertFalse(scrollView.showsHorizontalScrollIndicator);
  XCTAssertFalse(scrollView.showsVerticalScrollIndicator);
  XCTAssertEqual(scrollView.contentInsetAdjustmentBehavior,
                 UIScrollViewContentInsetAdjustmentNever);
  XCTAssertTrue(UIEdgeInsetsEqualToEdgeInsets(scrollView.contentInset, UIEdgeInsetsZero));
}

- (void)testSemanticsObjectBuildsAttributedString {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();
  flutter::SemanticsNode node;
  node.label = "label";
  std::shared_ptr<flutter::SpellOutStringAttribute> attribute =
      std::make_shared<flutter::SpellOutStringAttribute>();
  attribute->start = 1;
  attribute->end = 2;
  attribute->type = flutter::StringAttributeType::kSpellOut;
  node.labelAttributes.push_back(attribute);
  node.value = "value";
  attribute = std::make_shared<flutter::SpellOutStringAttribute>();
  attribute->start = 2;
  attribute->end = 3;
  attribute->type = flutter::StringAttributeType::kSpellOut;
  node.valueAttributes.push_back(attribute);
  node.hint = "hint";
  std::shared_ptr<flutter::LocaleStringAttribute> local_attribute =
      std::make_shared<flutter::LocaleStringAttribute>();
  local_attribute->start = 3;
  local_attribute->end = 4;
  local_attribute->type = flutter::StringAttributeType::kLocale;
  local_attribute->locale = "en-MX";
  node.hintAttributes.push_back(local_attribute);
  FlutterSemanticsObject* object = [[FlutterSemanticsObject alloc] initWithBridge:bridge uid:0];
  [object setSemanticsNode:&node];
  NSMutableAttributedString* expectedAttributedLabel =
      [[NSMutableAttributedString alloc] initWithString:NSLocalizedString(@"label", @"test")];
  NSDictionary* attributeDict = @{
    UIAccessibilitySpeechAttributeSpellOut : @YES,
  };
  [expectedAttributedLabel setAttributes:attributeDict range:NSMakeRange(1, 1)];
  XCTAssertTrue(
      [object.accessibilityAttributedLabel isEqualToAttributedString:expectedAttributedLabel]);

  NSMutableAttributedString* expectedAttributedValue =
      [[NSMutableAttributedString alloc] initWithString:NSLocalizedString(@"value", @"test")];
  attributeDict = @{
    UIAccessibilitySpeechAttributeSpellOut : @YES,
  };
  [expectedAttributedValue setAttributes:attributeDict range:NSMakeRange(2, 1)];
  XCTAssertTrue(
      [object.accessibilityAttributedValue isEqualToAttributedString:expectedAttributedValue]);

  NSMutableAttributedString* expectedAttributedHint =
      [[NSMutableAttributedString alloc] initWithString:NSLocalizedString(@"hint", @"test")];
  attributeDict = @{
    UIAccessibilitySpeechAttributeLanguage : @"en-MX",
  };
  [expectedAttributedHint setAttributes:attributeDict range:NSMakeRange(3, 1)];
  XCTAssertTrue(
      [object.accessibilityAttributedHint isEqualToAttributedString:expectedAttributedHint]);
}

- (void)testShouldTriggerAnnouncement {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();
  SemanticsObject* object = [[SemanticsObject alloc] initWithBridge:bridge uid:0];

  // Handle nil with no node set.
  XCTAssertFalse([object nodeShouldTriggerAnnouncement:nil]);

  // Handle initial setting of node with liveRegion
  flutter::SemanticsNode node;
  node.flags.isLiveRegion = true;
  node.label = "foo";
  XCTAssertTrue([object nodeShouldTriggerAnnouncement:&node]);

  // Handle nil with node set.
  [object setSemanticsNode:&node];
  XCTAssertFalse([object nodeShouldTriggerAnnouncement:nil]);

  // Handle new node, still has live region, same label.
  XCTAssertFalse([object nodeShouldTriggerAnnouncement:&node]);

  // Handle update node with new label, still has live region.
  flutter::SemanticsNode updatedNode;
  updatedNode.flags.isLiveRegion = true;
  updatedNode.label = "bar";
  XCTAssertTrue([object nodeShouldTriggerAnnouncement:&updatedNode]);

  // Handle dropping the live region flag.
  updatedNode.flags = flutter::SemanticsFlags{};
  XCTAssertFalse([object nodeShouldTriggerAnnouncement:&updatedNode]);

  // Handle adding the flag when the label has not changed.
  updatedNode.label = "foo";
  [object setSemanticsNode:&updatedNode];
  XCTAssertTrue([object nodeShouldTriggerAnnouncement:&node]);
}

- (void)testShouldDispatchShowOnScreenActionForHeader {
  fml::WeakPtrFactory<flutter::testing::MockAccessibilityBridge> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::testing::MockAccessibilityBridge> bridge = factory.GetWeakPtr();
  SemanticsObject* object = [[SemanticsObject alloc] initWithBridge:bridge uid:1];

  // Handle initial setting of node with header.
  flutter::SemanticsNode node;
  node.flags.isHeader = true;
  node.label = "foo";

  [object setSemanticsNode:&node];

  // Simulate accessibility focus.
  [object accessibilityElementDidBecomeFocused];

  XCTAssertTrue(bridge->observations.size() == 1);
  XCTAssertTrue(bridge->observations[0].id == 1);
  XCTAssertTrue(bridge->observations[0].action == flutter::SemanticsAction::kShowOnScreen);
}

- (void)testShouldDispatchShowOnScreenActionForHidden {
  fml::WeakPtrFactory<flutter::testing::MockAccessibilityBridge> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::testing::MockAccessibilityBridge> bridge = factory.GetWeakPtr();
  SemanticsObject* object = [[SemanticsObject alloc] initWithBridge:bridge uid:1];

  // Handle initial setting of node with hidden.
  flutter::SemanticsNode node;
  node.flags.isHidden = true;
  node.label = "foo";

  [object setSemanticsNode:&node];

  // Simulate accessibility focus.
  [object accessibilityElementDidBecomeFocused];

  XCTAssertTrue(bridge->observations.size() == 1);
  XCTAssertTrue(bridge->observations[0].id == 1);
  XCTAssertTrue(bridge->observations[0].action == flutter::SemanticsAction::kShowOnScreen);
}

- (void)testFlutterSwitchSemanticsObjectMatchesUISwitch {
  fml::WeakPtrFactory<flutter::testing::MockAccessibilityBridge> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::testing::MockAccessibilityBridge> bridge = factory.GetWeakPtr();
  FlutterSwitchSemanticsObject* object = [[FlutterSwitchSemanticsObject alloc] initWithBridge:bridge
                                                                                          uid:1];

  // Handle initial setting of node with header.
  flutter::SemanticsNode node;
  node.flags.isToggled = flutter::SemanticsTristate::kTrue;
  node.flags.isEnabled = flutter::SemanticsTristate::kTrue;
  node.label = "foo";
  [object setSemanticsNode:&node];
  // Create ab real UISwitch to compare the FlutterSwitchSemanticsObject with.
  UISwitch* nativeSwitch = [[UISwitch alloc] init];
  nativeSwitch.on = YES;

  XCTAssertEqual(object.accessibilityTraits, nativeSwitch.accessibilityTraits);
  XCTAssertEqualObjects(object.accessibilityValue, nativeSwitch.accessibilityValue);

  // Set the toggled to false;
  flutter::SemanticsNode update;
  update.flags.isToggled = flutter::SemanticsTristate::kFalse;
  update.flags.isEnabled = flutter::SemanticsTristate::kTrue;

  update.label = "foo";
  [object setSemanticsNode:&update];

  nativeSwitch.on = NO;

  XCTAssertEqual(object.accessibilityTraits, nativeSwitch.accessibilityTraits);
  XCTAssertEqualObjects(object.accessibilityValue, nativeSwitch.accessibilityValue);
}

- (void)testFlutterSemanticsObjectOfRadioButton {
  fml::WeakPtrFactory<flutter::testing::MockAccessibilityBridge> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::testing::MockAccessibilityBridge> bridge = factory.GetWeakPtr();
  FlutterSemanticsObject* object = [[FlutterSemanticsObject alloc] initWithBridge:bridge uid:0];

  // Handle initial setting of node with header.
  flutter::SemanticsNode node;
  node.flags.isInMutuallyExclusiveGroup = true;
  node.flags.isChecked = flutter::SemanticsCheckState::kFalse;
  node.flags.isEnabled = flutter::SemanticsTristate::kTrue;
  node.label = "foo";
  [object setSemanticsNode:&node];
  XCTAssertTrue((object.accessibilityTraits & UIAccessibilityTraitButton) > 0);
  XCTAssertNil(object.accessibilityValue);
}

- (void)testFlutterSwitchSemanticsObjectMatchesUISwitchDisabled {
  fml::WeakPtrFactory<flutter::testing::MockAccessibilityBridge> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::testing::MockAccessibilityBridge> bridge = factory.GetWeakPtr();
  FlutterSwitchSemanticsObject* object = [[FlutterSwitchSemanticsObject alloc] initWithBridge:bridge
                                                                                          uid:1];

  // Handle initial setting of node with header.
  flutter::SemanticsNode node;
  node.flags.isToggled = flutter::SemanticsTristate::kTrue;
  node.label = "foo";
  [object setSemanticsNode:&node];
  // Create ab real UISwitch to compare the FlutterSwitchSemanticsObject with.
  UISwitch* nativeSwitch = [[UISwitch alloc] init];
  nativeSwitch.on = YES;
  nativeSwitch.enabled = NO;

  XCTAssertEqual(object.accessibilityTraits, nativeSwitch.accessibilityTraits);
  XCTAssertEqualObjects(object.accessibilityValue, nativeSwitch.accessibilityValue);
}

- (void)testSemanticsObjectDeallocated {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();
  SemanticsObject* parent = [[SemanticsObject alloc] initWithBridge:bridge uid:0];
  SemanticsObject* child = [[SemanticsObject alloc] initWithBridge:bridge uid:1];
  parent.children = @[ child ];
  // Validate SemanticsObject deallocation does not crash.
  // https://github.com/flutter/flutter/issues/66032
  __weak SemanticsObject* weakObject = parent;
  parent = nil;
  XCTAssertNil(weakObject);
}

- (void)testFlutterSemanticsObjectReturnsNilContainerWhenBridgeIsNotAlive {
  FlutterSemanticsObject* parentObject;
  FlutterScrollableSemanticsObject* scrollable;
  FlutterSemanticsObject* object2;

  flutter::SemanticsNode parent;
  parent.id = 0;
  parent.rect = SkRect::MakeXYWH(0, 0, 100, 200);
  parent.label = "label";
  parent.value = "value";
  parent.hint = "hint";

  flutter::SemanticsNode node;
  node.id = 1;
  node.flags.hasImplicitScrolling = true;
  node.actions = flutter::kHorizontalScrollSemanticsActions;
  node.rect = SkRect::MakeXYWH(0, 0, 100, 200);
  node.label = "label";
  node.value = "value";
  node.hint = "hint";
  node.scrollExtentMax = 100.0;
  node.scrollPosition = 0.0;
  parent.childrenInTraversalOrder.push_back(1);

  flutter::SemanticsNode node2;
  node2.id = 2;
  node2.rect = SkRect::MakeXYWH(0, 0, 100, 200);
  node2.label = "label";
  node2.value = "value";
  node2.hint = "hint";
  node2.scrollExtentMax = 100.0;
  node2.scrollPosition = 0.0;
  parent.childrenInTraversalOrder.push_back(2);

  {
    flutter::testing::MockAccessibilityBridge* mock =
        new flutter::testing::MockAccessibilityBridge();
    mock->isVoiceOverRunningValue = true;
    fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(mock);
    fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

    parentObject = [[FlutterSemanticsObject alloc] initWithBridge:bridge uid:0];
    [parentObject setSemanticsNode:&parent];

    scrollable = [[FlutterScrollableSemanticsObject alloc] initWithBridge:bridge uid:1];
    [scrollable setSemanticsNode:&node];
    [scrollable accessibilityBridgeDidFinishUpdate];

    object2 = [[FlutterSemanticsObject alloc] initWithBridge:bridge uid:2];
    [object2 setSemanticsNode:&node2];

    parentObject.children = @[ scrollable, object2 ];
    [parentObject accessibilityBridgeDidFinishUpdate];
    [scrollable accessibilityBridgeDidFinishUpdate];
    [object2 accessibilityBridgeDidFinishUpdate];

    // Returns the correct container if the bridge is alive.
    SemanticsObjectContainer* container =
        static_cast<SemanticsObjectContainer*>(scrollable.accessibilityContainer);
    XCTAssertEqual(container.semanticsObject, parentObject);
    SemanticsObjectContainer* container2 =
        static_cast<SemanticsObjectContainer*>(object2.accessibilityContainer);
    XCTAssertEqual(container2.semanticsObject, parentObject);
  }
  // The bridge pointer went out of scope and was deallocated.

  XCTAssertNil(scrollable.accessibilityContainer);
  XCTAssertNil(object2.accessibilityContainer);
}

- (void)testAccessibilityHitTestSearchCanReturnPlatformView {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();
  SemanticsObject* object0 = [[SemanticsObject alloc] initWithBridge:bridge uid:0];
  SemanticsObject* object1 = [[SemanticsObject alloc] initWithBridge:bridge uid:1];
  SemanticsObject* object3 = [[SemanticsObject alloc] initWithBridge:bridge uid:3];
  FlutterTouchInterceptingView* platformView =
      [[FlutterTouchInterceptingView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
  FlutterPlatformViewSemanticsContainer* platformViewSemanticsContainer =
      [[FlutterPlatformViewSemanticsContainer alloc] initWithBridge:bridge
                                                                uid:1
                                                       platformView:platformView];

  object0.children = @[ object1 ];
  object0.childrenInHitTestOrder = @[ object1 ];
  object1.children = @[ platformViewSemanticsContainer, object3 ];
  object1.childrenInHitTestOrder = @[ platformViewSemanticsContainer, object3 ];

  flutter::SemanticsNode node0;
  node0.id = 0;
  node0.rect = SkRect::MakeXYWH(0, 0, 200, 200);
  node0.label = "0";
  [object0 setSemanticsNode:&node0];

  flutter::SemanticsNode node1;
  node1.id = 1;
  node1.rect = SkRect::MakeXYWH(0, 0, 200, 200);
  node1.label = "1";
  [object1 setSemanticsNode:&node1];

  flutter::SemanticsNode node2;
  node2.id = 2;
  node2.rect = SkRect::MakeXYWH(0, 0, 100, 100);
  node2.label = "2";
  [platformViewSemanticsContainer setSemanticsNode:&node2];

  flutter::SemanticsNode node3;
  node3.id = 3;
  node3.rect = SkRect::MakeXYWH(0, 0, 200, 200);
  node3.label = "3";
  [object3 setSemanticsNode:&node3];

  CGPoint point = CGPointMake(10, 10);
  id hitTestResult = [object0 _accessibilityHitTest:point withEvent:nil];

  XCTAssertEqual(hitTestResult, platformView);
}

- (void)testFlutterPlatformViewSemanticsContainer {
  fml::WeakPtrFactory<flutter::testing::MockAccessibilityBridge> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::testing::MockAccessibilityBridge> bridge = factory.GetWeakPtr();
  __weak FlutterTouchInterceptingView* weakPlatformView;
  __weak FlutterPlatformViewSemanticsContainer* weakContainer;
  @autoreleasepool {
    FlutterTouchInterceptingView* platformView = [[FlutterTouchInterceptingView alloc] init];
    weakPlatformView = platformView;

    @autoreleasepool {
      FlutterPlatformViewSemanticsContainer* container =
          [[FlutterPlatformViewSemanticsContainer alloc] initWithBridge:bridge
                                                                    uid:1
                                                           platformView:platformView];
      weakContainer = container;
      XCTAssertEqualObjects(platformView.accessibilityContainer, container);
      XCTAssertNotNil(weakPlatformView);
      XCTAssertNotNil(weakContainer);
    }
    // Check the variables are still lived.
    // `container` is `retain` in `platformView`, so it will not be nil here.
    XCTAssertNotNil(weakPlatformView);
    XCTAssertNotNil(weakContainer);
  }
  // Check if there's no more strong references to `platformView` after container and platformView
  // are released.
  XCTAssertNil(weakPlatformView);
  XCTAssertNil(weakContainer);
}

- (void)testTextInputSemanticsObject {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode node;
  node.label = "foo";
  node.flags.isTextField = true;
  node.flags.isReadOnly = true;
  TextInputSemanticsObject* object = [[TextInputSemanticsObject alloc] initWithBridge:bridge uid:0];
  [object setSemanticsNode:&node];
  [object accessibilityBridgeDidFinishUpdate];
  XCTAssertEqual([object accessibilityTraits], UIAccessibilityTraitNone);
}

- (void)testTextInputSemanticsObject_isSecureTextEntry {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode node;
  node.label = "foo";
  node.flags.isTextField = true;
  node.flags.isObscured = true;

  TextInputSemanticsObject* object = [[TextInputSemanticsObject alloc] initWithBridge:bridge uid:0];
  [object setSemanticsNode:&node];
  [object accessibilityBridgeDidFinishUpdate];

  XCTAssertTrue([object isSecureTextEntry]);

  node.flags.isObscured = false;
  [object setSemanticsNode:&node];
  [object accessibilityBridgeDidFinishUpdate];

  XCTAssertFalse([object isSecureTextEntry]);
}

- (void)testTextInputSemanticsObject_canPerformAction {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode node;
  node.label = "foo";
  node.flags.isTextField = true;
  node.flags.isReadOnly = true;
  TextInputSemanticsObject* object = [[TextInputSemanticsObject alloc] initWithBridge:bridge uid:0];
  [object setSemanticsNode:&node];
  [object accessibilityBridgeDidFinishUpdate];

  id textInputSurrogate = OCMClassMock([UIResponder class]);
  id partialSemanticsObject = OCMPartialMock(object);
  OCMStub([partialSemanticsObject textInputSurrogate]).andReturn(textInputSurrogate);

  OCMExpect([textInputSurrogate canPerformAction:[OCMArg anySelector] withSender:OCMOCK_ANY])
      .andReturn(YES);
  XCTAssertTrue([partialSemanticsObject canPerformAction:@selector(copy:) withSender:nil]);

  OCMExpect([textInputSurrogate canPerformAction:[OCMArg anySelector] withSender:OCMOCK_ANY])
      .andReturn(NO);
  XCTAssertFalse([partialSemanticsObject canPerformAction:@selector(copy:) withSender:nil]);
}

- (void)testTextInputSemanticsObject_editActions {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode node;
  node.label = "foo";

  node.flags.isTextField = true;
  node.flags.isReadOnly = true;
  TextInputSemanticsObject* object = [[TextInputSemanticsObject alloc] initWithBridge:bridge uid:0];
  [object setSemanticsNode:&node];
  [object accessibilityBridgeDidFinishUpdate];

  id textInputSurrogate = OCMClassMock([UIResponder class]);
  id partialSemanticsObject = OCMPartialMock(object);
  OCMStub([partialSemanticsObject textInputSurrogate]).andReturn(textInputSurrogate);

  XCTestExpectation* copyExpectation =
      [self expectationWithDescription:@"Surrogate's copy method is called."];
  XCTestExpectation* cutExpectation =
      [self expectationWithDescription:@"Surrogate's cut method is called."];
  XCTestExpectation* pasteExpectation =
      [self expectationWithDescription:@"Surrogate's paste method is called."];
  XCTestExpectation* selectAllExpectation =
      [self expectationWithDescription:@"Surrogate's selectAll method is called."];
  XCTestExpectation* deleteExpectation =
      [self expectationWithDescription:@"Surrogate's delete method is called."];

  OCMStub([textInputSurrogate copy:OCMOCK_ANY]).andDo(^(NSInvocation* invocation) {
    [copyExpectation fulfill];
  });
  OCMStub([textInputSurrogate cut:OCMOCK_ANY]).andDo(^(NSInvocation* invocation) {
    [cutExpectation fulfill];
  });
  OCMStub([textInputSurrogate paste:OCMOCK_ANY]).andDo(^(NSInvocation* invocation) {
    [pasteExpectation fulfill];
  });
  OCMStub([textInputSurrogate selectAll:OCMOCK_ANY]).andDo(^(NSInvocation* invocation) {
    [selectAllExpectation fulfill];
  });
  OCMStub([textInputSurrogate delete:OCMOCK_ANY]).andDo(^(NSInvocation* invocation) {
    [deleteExpectation fulfill];
  });

  [partialSemanticsObject copy:nil];
  [partialSemanticsObject cut:nil];
  [partialSemanticsObject paste:nil];
  [partialSemanticsObject selectAll:nil];
  [partialSemanticsObject delete:nil];

  [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testSliderSemanticsObject {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();

  flutter::SemanticsNode node;
  node.flags.isSlider = true;
  SemanticsObject* object = [[SemanticsObject alloc] initWithBridge:bridge uid:0];
  [object setSemanticsNode:&node];
  [object accessibilityBridgeDidFinishUpdate];
  XCTAssertEqual([object accessibilityActivate], YES);
}

- (void)testUIFocusItemConformance {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();
  SemanticsObject* parent = [[SemanticsObject alloc] initWithBridge:bridge uid:0];
  SemanticsObject* child = [[SemanticsObject alloc] initWithBridge:bridge uid:1];
  parent.children = @[ child ];

  // parentFocusEnvironment
  XCTAssertTrue([parent.parentFocusEnvironment isKindOfClass:[UIView class]]);
  XCTAssertEqual(child.parentFocusEnvironment, child.parent);

  // canBecomeFocused
  flutter::SemanticsNode childNode;
  childNode.flags.isHidden = true;
  childNode.actions = static_cast<int32_t>(flutter::SemanticsAction::kTap);
  [child setSemanticsNode:&childNode];
  XCTAssertFalse(child.canBecomeFocused);
  childNode.flags = flutter::SemanticsFlags{};
  [child setSemanticsNode:&childNode];
  XCTAssertTrue(child.canBecomeFocused);
  childNode.actions = 0;
  [child setSemanticsNode:&childNode];
  XCTAssertFalse(child.canBecomeFocused);

  CGFloat scale = ((bridge->view().window.screen ?: UIScreen.mainScreen)).scale;

  childNode.rect = SkRect::MakeXYWH(0, 0, 100 * scale, 100 * scale);
  [child setSemanticsNode:&childNode];
  flutter::SemanticsNode parentNode;
  parentNode.rect = SkRect::MakeXYWH(0, 0, 200, 200);
  [parent setSemanticsNode:&parentNode];

  XCTAssertTrue(CGRectEqualToRect(child.frame, CGRectMake(0, 0, 100, 100)));
}

- (void)testUIFocusItemContainerConformance {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();
  SemanticsObject* parent = [[SemanticsObject alloc] initWithBridge:bridge uid:0];
  SemanticsObject* child1 = [[SemanticsObject alloc] initWithBridge:bridge uid:1];
  SemanticsObject* child2 = [[SemanticsObject alloc] initWithBridge:bridge uid:2];
  parent.childrenInHitTestOrder = @[ child1, child2 ];

  // focusItemsInRect
  NSArray<id<UIFocusItem>>* itemsInRect = [parent focusItemsInRect:CGRectMake(0, 0, 100, 100)];
  XCTAssertEqual(itemsInRect.count, (unsigned long)2);
  XCTAssertTrue([itemsInRect containsObject:child1]);
  XCTAssertTrue([itemsInRect containsObject:child2]);
}

- (void)testUIFocusItemScrollableContainerConformance {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::testing::MockAccessibilityBridge> bridge = factory.GetWeakPtr();
  FlutterScrollableSemanticsObject* scrollable =
      [[FlutterScrollableSemanticsObject alloc] initWithBridge:bridge uid:5];

  // setContentOffset
  CGPoint p = CGPointMake(123.0, 456.0);
  [scrollable.scrollView scrollViewWillEndDragging:scrollable.scrollView
                                      withVelocity:CGPointZero
                               targetContentOffset:&p];
  scrollable.scrollView.contentOffset = p;
  [scrollable.scrollView scrollViewDidEndDecelerating:scrollable.scrollView];
  XCTAssertEqual(bridge->observations.size(), (size_t)1);
  XCTAssertEqual(bridge->observations[0].id, 5);
  XCTAssertEqual(bridge->observations[0].action, flutter::SemanticsAction::kScrollToOffset);

  std::vector<uint8_t> args = bridge->observations[0].args;
  XCTAssertEqual(args.size(), 3 * sizeof(CGFloat));

  NSData* encoded = [NSData dataWithBytes:args.data() length:args.size()];
  FlutterStandardTypedData* decoded = [[FlutterStandardMessageCodec sharedInstance] decode:encoded];
  CGPoint point = CGPointZero;
  memcpy(&point, decoded.data.bytes, decoded.data.length);
  XCTAssertTrue(CGPointEqualToPoint(point, p));
}

- (void)testUIFocusItemScrollableContainerNoFeedbackLoops {
  fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(
      new flutter::testing::MockAccessibilityBridge());
  fml::WeakPtr<flutter::testing::MockAccessibilityBridge> bridge = factory.GetWeakPtr();
  FlutterScrollableSemanticsObject* scrollable =
      [[FlutterScrollableSemanticsObject alloc] initWithBridge:bridge uid:5];

  // setContentOffset
  const CGPoint p = CGPointMake(0.0, 456.0);
  scrollable.scrollView.contentOffset = p;
  bridge->observations.clear();

  const SkScalar scrollPosition = p.y + 0.0000000000000001;
  flutter::SemanticsNode node;
  node.flags.hasImplicitScrolling = true;
  node.actions = flutter::kVerticalScrollSemanticsActions;
  node.rect = SkRect::MakeXYWH(0, 0, 100, 200);
  node.scrollExtentMax = 10000;
  node.scrollPosition = scrollPosition;
  node.transform = {1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0, 0, 0, scrollPosition, 0, 1.0};
  [scrollable setSemanticsNode:&node];
  [scrollable accessibilityBridgeDidFinishUpdate];

  XCTAssertEqual(bridge->observations.size(), (size_t)0);
}
- (void)testSelectableTextSemanticsObject_isSelectableStaticText {
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

- (void)testSelectableTextSemanticsObject_conformsToUITextInputAndStaysStaticText {
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

- (void)testSelectableTextSemanticsObject_positionsAreUTF16OffsetsIntoTheLabel {
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

  // Moving by one character steps over the whole surrogate pair.
  XCTAssertEqual(((FlutterTextPosition*)[object positionFromPosition:afterA offset:1]).index, 3u);
  XCTAssertEqual(((FlutterTextPosition*)[object positionFromPosition:afterEmoji offset:-1]).index,
                 1u);
  XCTAssertEqual(((FlutterTextPosition*)[object positionFromPosition:afterA
                                                         inDirection:UITextLayoutDirectionRight
                                                              offset:1])
                     .index,
                 3u);
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

- (void)testSelectableTextSemanticsObject_selectionActionsDoNotMakeItInteractive {
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

- (void)testSelectableTextSemanticsObject_tokenizerFindsWords {
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

- (void)testSelectableTextSemanticsObject_selectedTextRangeComesFromBaseAndExtent {
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

- (void)testSelectableTextSemanticsObject_setSelectedTextRangeDispatchesSetSelection {
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

- (void)testSelectableTextSemanticsObject_extendingLeftFromACaretKeepsTheBase {
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

- (void)testSelectableTextSemanticsObject_reportsTheRequestedCaretUntilTheSelectionChanges {
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

- (void)testSelectableTextSemanticsObject_editActions {
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

- (void)testSelectableTextSemanticsObject_geometryComesFromTheNodeRect {
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

- (void)testSelectableTextSemanticsObject_deallocatesWithItsTokenizer {
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

- (void)testSelectableTextSemanticsObject_answersTextInputItself {
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

  XCTAssertFalse(FlutterSelectableTextSemanticsObject.usesBackingTextView);
  XCTAssertNil(object.backingTextView);
  if (@available(iOS 18.1, *)) {
    XCTAssertEqual(object.accessibilityTextInputResponder, object);
  }
}

- (void)testSelectableTextSemanticsObject_backingTextViewMirrorsTheNode {
  if (@available(iOS 18.1, *)) {
    flutter::testing::MockAccessibilityBridge* mock =
        new flutter::testing::MockAccessibilityBridge();
    fml::WeakPtrFactory<flutter::AccessibilityBridgeIos> factory(mock);
    fml::WeakPtr<flutter::AccessibilityBridgeIos> bridge = factory.GetWeakPtr();
    UITextView* textView;
    @autoreleasepool {
      FlutterSelectableTextSemanticsObject.usesBackingTextView = YES;
      flutter::SemanticsNode node;
      node.label = "Hello world";
      node.actions = static_cast<int32_t>(flutter::SemanticsAction::kSetSelection);
      node.rect = SkRect::MakeXYWH(0, 0, 330, 60);
      node.textSelectionBase = 0;
      node.textSelectionExtent = 5;
      FlutterSelectableTextSemanticsObject* object =
          [[FlutterSelectableTextSemanticsObject alloc] initWithBridge:bridge uid:1];
      [object setSemanticsNode:&node];
      [object accessibilityBridgeDidFinishUpdate];
      FlutterSelectableTextSemanticsObject.usesBackingTextView = NO;

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

      // The framework's answer is mirrored without dispatching again.
      node.textSelectionBase = 6;
      node.textSelectionExtent = 11;
      [object setSemanticsNode:&node];
      XCTAssertTrue(NSEqualRanges(textView.selectedRange, NSMakeRange(6, 5)));
      XCTAssertEqual(mock->observations.size(), 1u);
    }
    // The text view leaves the Flutter view with its semantics object.
    XCTAssertNil(textView.superview);
  }
}
@end
