// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "flutter_platform_node_delegate.h"

#include "flutter/third_party/accessibility/ax/ax_action_data.h"
#include "gtest/gtest.h"

#include "test_accessibility_bridge.h"

namespace flutter {
namespace testing {

TEST(FlutterPlatformNodeDelegateTest, NodeDelegateHasUniqueId) {
  std::shared_ptr<TestAccessibilityBridge> bridge =
      std::make_shared<TestAccessibilityBridge>();

  // Add node 0: root.
  FlutterSemanticsNode2 node0{sizeof(FlutterSemanticsNode2), 0};
  std::vector<int32_t> node0_children{1};
  FlutterSemanticsFlags emptyFlags = FlutterSemanticsFlags{};
  node0.child_count = node0_children.size();
  node0.children_in_traversal_order = node0_children.data();
  node0.children_in_hit_test_order = node0_children.data();
  node0.flags2 = &emptyFlags;

  // Add node 1: text child of node 0.
  FlutterSemanticsNode2 node1{sizeof(FlutterSemanticsNode2), 1};
  node1.label = "prefecture";
  node1.value = "Kyoto";
  node1.flags2 = &emptyFlags;

  bridge->AddFlutterSemanticsNodeUpdate(node0);
  bridge->AddFlutterSemanticsNodeUpdate(node1);
  bridge->CommitUpdates();

  auto node0_delegate = bridge->GetFlutterPlatformNodeDelegateFromID(0).lock();
  auto node1_delegate = bridge->GetFlutterPlatformNodeDelegateFromID(1).lock();
  EXPECT_TRUE(node0_delegate->GetUniqueId() != node1_delegate->GetUniqueId());
}

TEST(FlutterPlatformNodeDelegateTest, canPerfomActions) {
  std::shared_ptr<TestAccessibilityBridge> bridge =
      std::make_shared<TestAccessibilityBridge>();
  FlutterSemanticsNode2 root;
  root.id = 0;
  FlutterSemanticsFlags flags = FlutterSemanticsFlags{0};
  flags.is_text_field = true;
  root.flags2 = &flags;
  // NOLINTNEXTLINE(clang-analyzer-optin.core.EnumCastOutOfRange)
  root.actions = static_cast<FlutterSemanticsAction>(0);
  root.text_selection_base = -1;
  root.text_selection_extent = -1;
  root.label = "root";
  root.hint = "";
  root.value = "";
  root.increased_value = "";
  root.decreased_value = "";
  root.tooltip = "";
  root.child_count = 0;
  root.custom_accessibility_actions_count = 0;
  root.identifier = "";
  bridge->AddFlutterSemanticsNodeUpdate(root);

  bridge->CommitUpdates();

  auto accessibility = bridge->GetFlutterPlatformNodeDelegateFromID(0).lock();
  // Performs an AXAction.
  ui::AXActionData action_data;
  action_data.action = ax::mojom::Action::kDoDefault;
  accessibility->AccessibilityPerformAction(action_data);
  EXPECT_EQ(bridge->performed_actions.size(), size_t{1});
  EXPECT_EQ(bridge->performed_actions[0],
            FlutterSemanticsAction::kFlutterSemanticsActionTap);

  action_data.action = ax::mojom::Action::kFocus;
  accessibility->AccessibilityPerformAction(action_data);
  EXPECT_EQ(bridge->performed_actions.size(), size_t{2});
  EXPECT_EQ(
      bridge->performed_actions[1],
      FlutterSemanticsAction::kFlutterSemanticsActionDidGainAccessibilityFocus);

  action_data.action = ax::mojom::Action::kScrollToMakeVisible;
  accessibility->AccessibilityPerformAction(action_data);
  EXPECT_EQ(bridge->performed_actions.size(), size_t{3});
  EXPECT_EQ(bridge->performed_actions[2],
            FlutterSemanticsAction::kFlutterSemanticsActionShowOnScreen);
}

namespace {

FlutterSemanticsNode2 CreateSetSelectionTestNode(int32_t id,
                                                 const char* label,
                                                 FlutterSemanticsFlags* flags) {
  FlutterSemanticsNode2 node{sizeof(FlutterSemanticsNode2), id};
  node.flags2 = flags;
  node.actions = FlutterSemanticsAction::kFlutterSemanticsActionSetSelection;
  node.text_selection_base = -1;
  node.text_selection_extent = -1;
  node.label = label;
  node.hint = "";
  node.value = "";
  node.increased_value = "";
  node.decreased_value = "";
  node.tooltip = "";
  node.identifier = "";
  return node;
}

// The StandardMessageCodec encoding of {"base": 1, "extent": 4}.
const std::vector<uint8_t> kBase1Extent4 = {
    13, 2, 7,   4,   'b', 'a', 's', 'e', 3, 1, 0, 0, 0,
    7,  6, 'e', 'x', 't', 'e', 'n', 't', 3, 4, 0, 0, 0,
};

}  // namespace

TEST(FlutterPlatformNodeDelegateTest, setSelectionOnStaticTextDispatchesRange) {
  std::shared_ptr<TestAccessibilityBridge> bridge =
      std::make_shared<TestAccessibilityBridge>();
  FlutterSemanticsFlags flags = FlutterSemanticsFlags{0};
  std::vector<int32_t> children{1, 2};
  FlutterSemanticsNode2 root = CreateSetSelectionTestNode(0, "root", &flags);
  root.actions = static_cast<FlutterSemanticsAction>(0);
  root.child_count = children.size();
  root.children_in_traversal_order = children.data();
  FlutterSemanticsNode2 paragraph =
      CreateSetSelectionTestNode(1, "Hello world", &flags);
  FlutterSemanticsNode2 label = CreateSetSelectionTestNode(2, "Other", &flags);
  label.actions = static_cast<FlutterSemanticsAction>(0);
  bridge->AddFlutterSemanticsNodeUpdate(root);
  bridge->AddFlutterSemanticsNodeUpdate(paragraph);
  bridge->AddFlutterSemanticsNodeUpdate(label);
  bridge->CommitUpdates();

  auto paragraph_delegate =
      bridge->GetFlutterPlatformNodeDelegateFromID(1).lock();
  // The macOS AXSelectedTextRange setter fills only the offsets; node ids of
  // -1 mean this node.
  ui::AXActionData action_data;
  action_data.action = ax::mojom::Action::kSetSelection;
  action_data.anchor_offset = 1;
  action_data.focus_offset = 4;
  EXPECT_TRUE(paragraph_delegate->AccessibilityPerformAction(action_data));
  ASSERT_EQ(bridge->performed_actions.size(), size_t{1});
  EXPECT_EQ(bridge->performed_actions[0],
            FlutterSemanticsAction::kFlutterSemanticsActionSetSelection);
  EXPECT_EQ(bridge->performed_action_targets[0], 1);
  EXPECT_EQ(bridge->performed_action_data[0], kBase1Extent4);

  // UIA sets the node ids; they must name this node.
  action_data.anchor_node_id = 1;
  action_data.focus_node_id = 1;
  EXPECT_TRUE(paragraph_delegate->AccessibilityPerformAction(action_data));
  ASSERT_EQ(bridge->performed_actions.size(), size_t{2});
  EXPECT_EQ(bridge->performed_action_data[1], kBase1Extent4);

  action_data.focus_node_id = 2;
  EXPECT_FALSE(paragraph_delegate->AccessibilityPerformAction(action_data));
  EXPECT_EQ(bridge->performed_actions.size(), size_t{2});

  // A node without the set selection action is not selectable.
  auto label_delegate = bridge->GetFlutterPlatformNodeDelegateFromID(2).lock();
  action_data.anchor_node_id = -1;
  action_data.focus_node_id = -1;
  EXPECT_FALSE(label_delegate->AccessibilityPerformAction(action_data));
  EXPECT_EQ(bridge->performed_actions.size(), size_t{2});
}

TEST(FlutterPlatformNodeDelegateTest, setSelectionOnTextFieldIsNoOp) {
  std::shared_ptr<TestAccessibilityBridge> bridge =
      std::make_shared<TestAccessibilityBridge>();
  FlutterSemanticsFlags flags = FlutterSemanticsFlags{0};
  flags.is_text_field = true;
  flags.is_focused = FlutterTristate::kFlutterTristateTrue;
  FlutterSemanticsNode2 field = CreateSetSelectionTestNode(0, "Email", &flags);
  field.value = "me@example.com";
  field.text_selection_base = 2;
  field.text_selection_extent = 2;
  bridge->AddFlutterSemanticsNodeUpdate(field);
  bridge->CommitUpdates();

  auto field_delegate = bridge->GetFlutterPlatformNodeDelegateFromID(0).lock();
  ui::AXActionData action_data;
  action_data.action = ax::mojom::Action::kSetSelection;
  action_data.anchor_offset = 1;
  action_data.focus_offset = 4;
  EXPECT_FALSE(field_delegate->AccessibilityPerformAction(action_data));
  EXPECT_TRUE(bridge->performed_actions.empty());
}

TEST(FlutterPlatformNodeDelegateTest, canGetAXNode) {
  // Set up a flutter accessibility node.
  std::shared_ptr<TestAccessibilityBridge> bridge =
      std::make_shared<TestAccessibilityBridge>();
  FlutterSemanticsNode2 root;
  root.id = 0;
  FlutterSemanticsFlags flags = FlutterSemanticsFlags{0};
  flags.is_text_field = true;
  root.flags2 = &flags;
  // NOLINTNEXTLINE(clang-analyzer-optin.core.EnumCastOutOfRange)
  root.actions = static_cast<FlutterSemanticsAction>(0);
  root.text_selection_base = -1;
  root.text_selection_extent = -1;
  root.label = "root";
  root.hint = "";
  root.value = "";
  root.increased_value = "";
  root.decreased_value = "";
  root.tooltip = "";
  root.child_count = 0;
  root.custom_accessibility_actions_count = 0;
  root.identifier = "";
  bridge->AddFlutterSemanticsNodeUpdate(root);

  bridge->CommitUpdates();

  auto accessibility = bridge->GetFlutterPlatformNodeDelegateFromID(0).lock();
  EXPECT_EQ(accessibility->GetData().id, 0);
}

TEST(FlutterPlatformNodeDelegateTest, canCalculateBoundsCorrectly) {
  std::shared_ptr<TestAccessibilityBridge> bridge =
      std::make_shared<TestAccessibilityBridge>();
  FlutterSemanticsFlags flags = FlutterSemanticsFlags{0};
  FlutterSemanticsNode2 root;
  root.id = 0;
  root.label = "root";
  root.hint = "";
  root.value = "";
  root.increased_value = "";
  root.decreased_value = "";
  root.tooltip = "";
  root.child_count = 1;
  root.flags2 = &flags;
  int32_t children[] = {1};
  root.children_in_traversal_order = children;
  root.custom_accessibility_actions_count = 0;
  root.identifier = "";
  root.rect = {0, 0, 100, 100};  // LTRB
  root.transform = {1, 0, 0, 0, 1, 0, 0, 0, 1};
  bridge->AddFlutterSemanticsNodeUpdate(root);

  FlutterSemanticsNode2 child1;
  child1.id = 1;
  child1.label = "child 1";
  child1.hint = "";
  child1.value = "";
  child1.increased_value = "";
  child1.decreased_value = "";
  child1.tooltip = "";
  child1.child_count = 0;
  child1.flags2 = &flags;
  child1.custom_accessibility_actions_count = 0;
  child1.identifier = "";
  child1.rect = {0, 0, 50, 50};  // LTRB
  child1.transform = {0.5, 0, 0, 0, 0.5, 0, 0, 0, 1};
  bridge->AddFlutterSemanticsNodeUpdate(child1);

  bridge->CommitUpdates();
  auto child1_node = bridge->GetFlutterPlatformNodeDelegateFromID(1).lock();
  ui::AXOffscreenResult result;
  gfx::Rect bounds =
      child1_node->GetBoundsRect(ui::AXCoordinateSystem::kScreenDIPs,
                                 ui::AXClippingBehavior::kClipped, &result);
  EXPECT_EQ(bounds.x(), 0);
  EXPECT_EQ(bounds.y(), 0);
  EXPECT_EQ(bounds.width(), 25);
  EXPECT_EQ(bounds.height(), 25);
  EXPECT_EQ(result, ui::AXOffscreenResult::kOnscreen);
}

TEST(FlutterPlatformNodeDelegateTest, canCalculateOffScreenBoundsCorrectly) {
  std::shared_ptr<TestAccessibilityBridge> bridge =
      std::make_shared<TestAccessibilityBridge>();
  FlutterSemanticsFlags flags = FlutterSemanticsFlags{0};
  FlutterSemanticsNode2 root;
  root.id = 0;
  root.label = "root";
  root.hint = "";
  root.value = "";
  root.increased_value = "";
  root.decreased_value = "";
  root.tooltip = "";
  root.child_count = 1;
  root.flags2 = &flags;
  int32_t children[] = {1};
  root.children_in_traversal_order = children;
  root.custom_accessibility_actions_count = 0;
  root.identifier = "";
  root.rect = {0, 0, 100, 100};  // LTRB
  root.transform = {1, 0, 0, 0, 1, 0, 0, 0, 1};
  bridge->AddFlutterSemanticsNodeUpdate(root);

  FlutterSemanticsNode2 child1;
  child1.id = 1;
  child1.label = "child 1";
  child1.hint = "";
  child1.value = "";
  child1.increased_value = "";
  child1.decreased_value = "";
  child1.tooltip = "";
  child1.child_count = 0;
  child1.flags2 = &flags;
  child1.custom_accessibility_actions_count = 0;
  child1.identifier = "";
  child1.rect = {90, 90, 100, 100};  // LTRB
  child1.transform = {2, 0, 0, 0, 2, 0, 0, 0, 1};
  bridge->AddFlutterSemanticsNodeUpdate(child1);

  bridge->CommitUpdates();
  auto child1_node = bridge->GetFlutterPlatformNodeDelegateFromID(1).lock();
  ui::AXOffscreenResult result;
  gfx::Rect bounds =
      child1_node->GetBoundsRect(ui::AXCoordinateSystem::kScreenDIPs,
                                 ui::AXClippingBehavior::kUnclipped, &result);
  EXPECT_EQ(bounds.x(), 180);
  EXPECT_EQ(bounds.y(), 180);
  EXPECT_EQ(bounds.width(), 20);
  EXPECT_EQ(bounds.height(), 20);
  EXPECT_EQ(result, ui::AXOffscreenResult::kOffscreen);
}

TEST(FlutterPlatformNodeDelegateTest, canUseOwnerBridge) {
  std::shared_ptr<TestAccessibilityBridge> bridge =
      std::make_shared<TestAccessibilityBridge>();
  FlutterSemanticsFlags flags = FlutterSemanticsFlags{0};
  FlutterSemanticsNode2 root{sizeof(FlutterSemanticsNode2), 0};
  root.label = "root";
  root.hint = "";
  root.value = "";
  root.increased_value = "";
  root.decreased_value = "";
  root.tooltip = "";
  root.heading_level = 0;
  root.child_count = 1;
  root.flags2 = &flags;
  int32_t children[] = {1};
  root.children_in_traversal_order = children;
  root.custom_accessibility_actions_count = 0;
  root.identifier = "";
  root.rect = {0, 0, 100, 100};  // LTRB
  root.transform = {1, 0, 0, 0, 1, 0, 0, 0, 1};
  bridge->AddFlutterSemanticsNodeUpdate(root);

  FlutterSemanticsNode2 child1{sizeof(FlutterSemanticsNode2), 1};
  child1.label = "child 1";
  child1.hint = "";
  child1.value = "";
  child1.increased_value = "";
  child1.decreased_value = "";
  child1.tooltip = "";
  child1.heading_level = 0;
  child1.child_count = 0;
  child1.flags2 = &flags;
  child1.custom_accessibility_actions_count = 0;
  child1.identifier = "";
  child1.rect = {0, 0, 50, 50};  // LTRB
  child1.transform = {0.5, 0, 0, 0, 0.5, 0, 0, 0, 1};
  bridge->AddFlutterSemanticsNodeUpdate(child1);

  bridge->CommitUpdates();
  auto child1_node = bridge->GetFlutterPlatformNodeDelegateFromID(1).lock();
  auto owner_bridge = child1_node->GetOwnerBridge().lock();

  bool result = false;
  gfx::RectF bounds = owner_bridge->RelativeToGlobalBounds(
      child1_node->GetAXNode(), result, true);
  EXPECT_EQ(bounds.x(), 0);
  EXPECT_EQ(bounds.y(), 0);
  EXPECT_EQ(bounds.width(), 25);
  EXPECT_EQ(bounds.height(), 25);
  EXPECT_EQ(result, false);
}

TEST(FlutterPlatformNodeDelegateTest, selfIsLowestPlatformAncestor) {
  std::shared_ptr<TestAccessibilityBridge> bridge =
      std::make_shared<TestAccessibilityBridge>();
  FlutterSemanticsFlags flags = FlutterSemanticsFlags{0};
  FlutterSemanticsNode2 root;
  root.id = 0;
  root.label = "root";
  root.hint = "";
  root.value = "";
  root.increased_value = "";
  root.decreased_value = "";
  root.tooltip = "";
  root.child_count = 0;
  root.flags2 = &flags;
  root.children_in_traversal_order = nullptr;
  root.custom_accessibility_actions_count = 0;
  root.identifier = "";
  bridge->AddFlutterSemanticsNodeUpdate(root);

  bridge->CommitUpdates();
  auto root_node = bridge->GetFlutterPlatformNodeDelegateFromID(0).lock();
  auto lowest_platform_ancestor = root_node->GetLowestPlatformAncestor();
  EXPECT_EQ(root_node->GetNativeViewAccessible(), lowest_platform_ancestor);
}

TEST(FlutterPlatformNodeDelegateTest, canGetFromNodeID) {
  std::shared_ptr<TestAccessibilityBridge> bridge =
      std::make_shared<TestAccessibilityBridge>();
  FlutterSemanticsFlags flags = FlutterSemanticsFlags{0};
  FlutterSemanticsNode2 root;
  root.id = 0;
  root.label = "root";
  root.hint = "";
  root.value = "";
  root.increased_value = "";
  root.decreased_value = "";
  root.tooltip = "";
  root.child_count = 1;
  root.flags2 = &flags;
  int32_t children[] = {1};
  root.children_in_traversal_order = children;
  root.custom_accessibility_actions_count = 0;
  root.identifier = "";
  bridge->AddFlutterSemanticsNodeUpdate(root);

  FlutterSemanticsNode2 child1;
  child1.id = 1;
  child1.label = "child 1";
  child1.hint = "";
  child1.value = "";
  child1.increased_value = "";
  child1.decreased_value = "";
  child1.tooltip = "";
  child1.child_count = 0;
  child1.flags2 = &flags;
  child1.custom_accessibility_actions_count = 0;
  child1.identifier = "";
  bridge->AddFlutterSemanticsNodeUpdate(child1);

  bridge->CommitUpdates();
  auto root_node = bridge->GetFlutterPlatformNodeDelegateFromID(0).lock();
  auto child1_node = bridge->GetFlutterPlatformNodeDelegateFromID(1).lock();
  auto node_by_id = root_node->GetFromNodeID(1);
  EXPECT_EQ(child1_node->GetPlatformNode(), node_by_id);
}

}  // namespace testing
}  // namespace flutter
