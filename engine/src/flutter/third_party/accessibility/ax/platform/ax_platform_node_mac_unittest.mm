// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "ax_platform_node_mac_unittest.h"

#include "ax_platform_node_mac.h"
#include "gtest/gtest.h"
#include "test_ax_node_wrapper.h"
#include "third_party/accessibility/ax/ax_node_data.h"

namespace ui {

AXPlatformNodeMacTest::AXPlatformNodeMacTest() = default;

AXPlatformNodeMacTest::~AXPlatformNodeMacTest() = default;

void AXPlatformNodeMacTest::SetUp() {}

void AXPlatformNodeMacTest::TearDown() {
  // Destroy the tree and make sure we're not leaking any objects.
  DestroyTree();
  TestAXNodeWrapper::SetGlobalIsWebContent(false);
  ASSERT_EQ(0U, AXPlatformNodeBase::GetInstanceCountForTesting());
}

AXPlatformNode* AXPlatformNodeMacTest::AXPlatformNodeFromNode(AXNode* node) {
  const TestAXNodeWrapper* wrapper = TestAXNodeWrapper::GetOrCreate(GetTree(), node);
  return wrapper ? wrapper->ax_platform_node() : nullptr;
}

// Verify that we can get an AXPlatformNodeMac and AXPlatformNodeCocoa from the tree.
TEST_F(AXPlatformNodeMacTest, CanGetCocoaPlatformNodeFromTree) {
  AXNodeData root;
  root.id = 1;
  root.relative_bounds.bounds = gfx::RectF(0, 0, 40, 40);

  Init(root);
  AXNode* root_node = GetRootAsAXNode();
  ASSERT_TRUE(root_node != nullptr);

  AXPlatformNode* platform_node = AXPlatformNodeFromNode(root_node);
  ASSERT_TRUE(platform_node != nullptr);

  AXPlatformNodeCocoa* native_root = platform_node->GetNativeViewAccessible();
  EXPECT_TRUE(native_root != nullptr);
}

// Test that [AXPlatformNodeCocoa accessbilityRangeForPosition:] doesn't crash.
// https://github.com/flutter/flutter/issues/102416
TEST_F(AXPlatformNodeMacTest, AccessibilityRangeForPositionDoesntCrash) {
  AXNodeData root;
  root.id = 1;
  root.relative_bounds.bounds = gfx::RectF(0, 0, 40, 40);

  Init(root);
  AXNode* root_node = GetRootAsAXNode();
  ASSERT_TRUE(root_node != nullptr);

  AXPlatformNode* platform_node = AXPlatformNodeFromNode(root_node);
  ASSERT_TRUE(platform_node != nullptr);

  NSPoint point = NSMakePoint(0, 0);
  AXPlatformNodeCocoa* native_root = platform_node->GetNativeViewAccessible();
  ASSERT_TRUE(native_root != nullptr);

  [native_root accessibilityRangeForPosition:(NSPoint)point];
}

// A static text element, as a selectable paragraph is exposed.
AXPlatformNodeCocoa* AXPlatformNodeMacTest::InitStaticText(const std::string& name,
                                                           int sel_start,
                                                           int sel_end) {
  AXNodeData root;
  root.id = 1;
  root.role = ax::mojom::Role::kStaticText;
  root.SetName(name);
  root.AddIntAttribute(ax::mojom::IntAttribute::kTextSelStart, sel_start);
  root.AddIntAttribute(ax::mojom::IntAttribute::kTextSelEnd, sel_end);
  root.relative_bounds.bounds = gfx::RectF(0, 0, 40, 40);
  Init(root);
  AXPlatformNode* platform_node = AXPlatformNodeFromNode(GetRootAsAXNode());
  return platform_node ? platform_node->GetNativeViewAccessible() : nil;
}

// VoiceOver queries these text attributes on static text with indexes and
// ranges it computes itself; none of them may abort the app.
TEST_F(AXPlatformNodeMacTest, StaticTextRangeForIndexIsOneComposedCharacter) {
  // "a", one emoji (two UTF-16 code units) and "b".
  AXPlatformNodeCocoa* text = InitStaticText("a\xF0\x9F\x98\x80"
                                             "b");
  ASSERT_TRUE(text != nil);
  EXPECT_TRUE(NSEqualRanges([text accessibilityRangeForIndex:0], NSMakeRange(0, 1)));
  EXPECT_TRUE(NSEqualRanges([text accessibilityRangeForIndex:1], NSMakeRange(1, 2)));
  EXPECT_TRUE(NSEqualRanges([text accessibilityRangeForIndex:2], NSMakeRange(1, 2)));
  EXPECT_TRUE(NSEqualRanges([text accessibilityRangeForIndex:3], NSMakeRange(3, 1)));
  // Out-of-range indexes are clamped to the text.
  EXPECT_TRUE(NSEqualRanges([text accessibilityRangeForIndex:100], NSMakeRange(3, 1)));
  EXPECT_TRUE(NSEqualRanges([text accessibilityRangeForIndex:-5], NSMakeRange(0, 1)));
}

TEST_F(AXPlatformNodeMacTest, EmptyStaticTextRangeForIndexIsEmpty) {
  AXPlatformNodeCocoa* text = InitStaticText("");
  ASSERT_TRUE(text != nil);
  EXPECT_TRUE(NSEqualRanges([text accessibilityRangeForIndex:0], NSMakeRange(0, 0)));
  EXPECT_TRUE(NSEqualRanges([text accessibilityRangeForIndex:7], NSMakeRange(0, 0)));
}

TEST_F(AXPlatformNodeMacTest, StaticTextRangeForLineBeyondFirstIsNotFound) {
  AXPlatformNodeCocoa* text = InitStaticText("Hello world");
  ASSERT_TRUE(text != nil);
  EXPECT_TRUE(NSEqualRanges([text accessibilityRangeForLine:0], NSMakeRange(0, 11)));
  EXPECT_EQ([text accessibilityRangeForLine:1].location, static_cast<NSUInteger>(NSNotFound));
  EXPECT_EQ([text accessibilityRangeForLine:1].length, 0u);
  EXPECT_EQ([text accessibilityRangeForLine:-1].location, static_cast<NSUInteger>(NSNotFound));
}

TEST_F(AXPlatformNodeMacTest, StaticTextStringForRangeIsClamped) {
  AXPlatformNodeCocoa* text = InitStaticText("Hello");
  ASSERT_TRUE(text != nil);
  EXPECT_TRUE([[text accessibilityStringForRange:NSMakeRange(1, 3)] isEqualToString:@"ell"]);
  EXPECT_TRUE([[text accessibilityStringForRange:NSMakeRange(3, 10)] isEqualToString:@"lo"]);
  EXPECT_TRUE([[text accessibilityStringForRange:NSMakeRange(10, 2)] isEqualToString:@""]);
  EXPECT_TRUE([[text accessibilityStringForRange:NSMakeRange(NSNotFound, 0)] isEqualToString:@""]);
  EXPECT_TRUE([[[text accessibilityAttributedStringForRange:NSMakeRange(3, 10)] string]
      isEqualToString:@"lo"]);
}

TEST_F(AXPlatformNodeMacTest, StaticTextSelectedTextIsClamped) {
  AXPlatformNodeCocoa* selected = InitStaticText("Hello", 0, 3);
  ASSERT_TRUE(selected != nil);
  EXPECT_TRUE([[selected accessibilitySelectedText] isEqualToString:@"Hel"]);
  EXPECT_TRUE(NSEqualRanges([selected accessibilitySelectedTextRange], NSMakeRange(0, 3)));
  DestroyTree();

  // A backward selection reads the same text.
  AXPlatformNodeCocoa* backward = InitStaticText("Hello", 3, 0);
  ASSERT_TRUE(backward != nil);
  EXPECT_TRUE([[backward accessibilitySelectedText] isEqualToString:@"Hel"]);
  DestroyTree();

  AXPlatformNodeCocoa* unselected = InitStaticText("Hello");
  ASSERT_TRUE(unselected != nil);
  EXPECT_TRUE([[unselected accessibilitySelectedText] isEqualToString:@""]);
  DestroyTree();

  AXPlatformNodeCocoa* beyond = InitStaticText("Hello", 2, 99);
  ASSERT_TRUE(beyond != nil);
  EXPECT_TRUE([[beyond accessibilitySelectedText] isEqualToString:@"llo"]);
}

}  // namespace ui
