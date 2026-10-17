// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "flutter/shell/platform/darwin/macos/framework/Source/AccessibilityBridgeMac.h"

#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterDartProject_Internal.h"
#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterEngine_Internal.h"
#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterTextInputSemanticsObject.h"
#import "flutter/shell/platform/darwin/macos/framework/Source/FlutterViewController_Internal.h"
#include "flutter/shell/platform/embedder/test_utils/proc_table_replacement.h"
#include "flutter/testing/autoreleasepool_test.h"
#include "flutter/testing/testing.h"
#include "flutter/third_party/accessibility/ax/ax_action_data.h"

namespace flutter::testing {

namespace {

class AccessibilityBridgeMacSpy : public AccessibilityBridgeMac {
 public:
  using AccessibilityBridgeMac::OnAccessibilityEvent;

  AccessibilityBridgeMacSpy(__weak FlutterEngine* flutter_engine,
                            __weak FlutterViewController* view_controller)
      : AccessibilityBridgeMac(flutter_engine, view_controller),
        actual_notifications([NSMutableDictionary dictionary]) {}

  NSMutableDictionary<NSAccessibilityNotificationName, id>* actual_notifications;

  // Every posted notification of the given name, in order.
  std::vector<id> PostedTargets(NSAccessibilityNotificationName name) const {
    std::vector<id> targets;
    for (const auto& [posted_name, target] : posted_notifications_) {
      if ([posted_name isEqualToString:name]) {
        targets.push_back(target);
      }
    }
    return targets;
  }

  bool post_static_selection_notifications = false;

 protected:
  bool ShouldPostStaticSelectionNotifications() const override {
    return post_static_selection_notifications;
  }

 private:
  void DispatchMacOSNotification(gfx::NativeViewAccessible native_node,
                                 NSAccessibilityNotificationName mac_notification) override {
    actual_notifications[mac_notification] = native_node;
    posted_notifications_.emplace_back(mac_notification, native_node);
  }

  std::vector<std::pair<NSAccessibilityNotificationName, id>> posted_notifications_;
};

FlutterSemanticsNode2 CreateNode(int32_t id,
                                 const char* label,
                                 FlutterSemanticsFlags* flags,
                                 const std::vector<int32_t>* children = nullptr) {
  FlutterSemanticsNode2 node{sizeof(FlutterSemanticsNode2), id};
  node.flags2 = flags;
  // NOLINTNEXTLINE(clang-analyzer-optin.core.EnumCastOutOfRange)
  node.actions = static_cast<FlutterSemanticsAction>(0);
  node.text_selection_base = -1;
  node.text_selection_extent = -1;
  node.label = label;
  node.hint = "";
  node.value = "";
  node.increased_value = "";
  node.decreased_value = "";
  node.tooltip = "";
  node.child_count = children ? children->size() : 0;
  node.children_in_traversal_order = children ? children->data() : nullptr;
  node.custom_accessibility_actions_count = 0;
  node.identifier = "";
  return node;
}

// A paragraph under a SelectableRegion: static text with the set selection
// action.
FlutterSemanticsNode2 CreateSelectableTextNode(int32_t id,
                                               const char* label,
                                               FlutterSemanticsFlags* flags) {
  FlutterSemanticsNode2 node = CreateNode(id, label, flags);
  node.actions = FlutterSemanticsAction::kFlutterSemanticsActionSetSelection;
  return node;
}

}  // namespace
}  // namespace flutter::testing

@interface AccessibilityBridgeTestViewController : FlutterViewController
- (std::shared_ptr<flutter::AccessibilityBridgeMac>)createAccessibilityBridgeWithEngine:
    (nonnull FlutterEngine*)engine;
@end

@implementation AccessibilityBridgeTestViewController
- (std::shared_ptr<flutter::AccessibilityBridgeMac>)createAccessibilityBridgeWithEngine:
    (nonnull FlutterEngine*)engine {
  return std::make_shared<flutter::testing::AccessibilityBridgeMacSpy>(engine, self);
}
@end

namespace flutter::testing {

namespace {

// Returns an engine configured for the text fixture resource configuration.
FlutterViewController* CreateTestViewController() {
  NSString* fixtures = @(testing::GetFixturesPath());
  FlutterDartProject* project = [[FlutterDartProject alloc]
      initWithAssetsPath:fixtures
             ICUDataPath:[fixtures stringByAppendingString:@"/icudtl.dat"]];
  return [[AccessibilityBridgeTestViewController alloc] initWithProject:project];
}

// Test fixture that instantiates and re-uses a single NSWindow across multiple tests.
//
// Works around: http://www.openradar.me/FB13291861
class AccessibilityBridgeMacWindowTest : public AutoreleasePoolTest {
 public:
  AccessibilityBridgeMacWindowTest() {
    if (!gWindow_) {
      gWindow_ = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 800, 600)
                                             styleMask:NSBorderlessWindowMask
                                               backing:NSBackingStoreBuffered
                                                 defer:NO];
    }
  }

  NSWindow* GetWindow() const { return gWindow_; }

 private:
  static NSWindow* gWindow_;
  FML_DISALLOW_COPY_AND_ASSIGN(AccessibilityBridgeMacWindowTest);
};

NSWindow* AccessibilityBridgeMacWindowTest::gWindow_ = nil;

// Test-specific name for AutoreleasePoolTest fixture.
using AccessibilityBridgeMacTest = AutoreleasePoolTest;

}  // namespace

TEST_F(AccessibilityBridgeMacWindowTest, SendsAccessibilityCreateNotificationFlutterViewWindow) {
  FlutterViewController* viewController = CreateTestViewController();
  FlutterEngine* engine = viewController.engine;
  NSWindow* expectedTarget = GetWindow();
  expectedTarget.contentView = viewController.view;

  // Setting up bridge so that the AccessibilityBridgeMacDelegateSpy
  // can query semantics information from.
  engine.semanticsEnabled = YES;
  auto bridge = std::static_pointer_cast<AccessibilityBridgeMacSpy>(
      viewController.accessibilityBridge.lock());
  FlutterSemanticsNode2 root;
  FlutterSemanticsFlags flags = FlutterSemanticsFlags{0};
  root.id = 0;
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
  auto platform_node_delegate = bridge->GetFlutterPlatformNodeDelegateFromID(0).lock();

  // Creates a targeted event.
  ui::AXTree tree;
  ui::AXNode ax_node(&tree, nullptr, 0, 0);
  ui::AXNodeData node_data;
  node_data.id = 0;
  ax_node.SetData(node_data);
  std::vector<ui::AXEventIntent> intent;
  ui::AXEventGenerator::EventParams event_params(ui::AXEventGenerator::Event::CHILDREN_CHANGED,
                                                 ax::mojom::EventFrom::kNone, intent);
  ui::AXEventGenerator::TargetedEvent targeted_event(&ax_node, event_params);

  bridge->OnAccessibilityEvent(targeted_event);

  ASSERT_EQ(bridge->actual_notifications.count, 1u);
  id target = bridge->actual_notifications[NSAccessibilityCreatedNotification];
  ASSERT_NE(target, nil);
  EXPECT_EQ(target, expectedTarget);
  [engine shutDownEngine];
}

// Flutter used to assume that the accessibility root had ID 0.
// In a multi-view world, each view has its own accessibility root
// with a globally unique node ID.
//
//        node1
//          |
//        node2
TEST_F(AccessibilityBridgeMacWindowTest, NonZeroRootNodeId) {
  FlutterViewController* viewController = CreateTestViewController();
  FlutterEngine* engine = viewController.engine;
  NSWindow* expectedTarget = GetWindow();
  expectedTarget.contentView = viewController.view;

  // Setting up bridge so that the AccessibilityBridgeMacDelegateSpy
  // can query semantics information from.
  engine.semanticsEnabled = YES;
  auto bridge = std::static_pointer_cast<AccessibilityBridgeMacSpy>(
      viewController.accessibilityBridge.lock());

  FlutterSemanticsNode2 node1;
  FlutterSemanticsFlags flags = FlutterSemanticsFlags{0};
  std::vector<int32_t> node1_children{2};
  node1.id = 1;
  node1.flags2 = &flags;
  // NOLINTNEXTLINE(clang-analyzer-optin.core.EnumCastOutOfRange)
  node1.actions = static_cast<FlutterSemanticsAction>(0);
  node1.text_selection_base = -1;
  node1.text_selection_extent = -1;
  node1.label = "node1";
  node1.hint = "";
  node1.value = "";
  node1.increased_value = "";
  node1.decreased_value = "";
  node1.tooltip = "";
  node1.child_count = node1_children.size();
  node1.children_in_traversal_order = node1_children.data();
  node1.children_in_hit_test_order = node1_children.data();
  node1.custom_accessibility_actions_count = 0;
  node1.identifier = "";

  FlutterSemanticsNode2 node2;
  node2.id = 2;
  node2.flags2 = &flags;
  // NOLINTNEXTLINE(clang-analyzer-optin.core.EnumCastOutOfRange)
  node2.actions = static_cast<FlutterSemanticsAction>(0);
  node2.text_selection_base = -1;
  node2.text_selection_extent = -1;
  node2.label = "node2";
  node2.hint = "";
  node2.value = "";
  node2.increased_value = "";
  node2.decreased_value = "";
  node2.tooltip = "";
  node2.child_count = 0;
  node2.custom_accessibility_actions_count = 0;
  node2.identifier = "";

  bridge->AddFlutterSemanticsNodeUpdate(node1);
  bridge->AddFlutterSemanticsNodeUpdate(node2);
  bridge->CommitUpdates();

  // Look up the root node delegate.
  auto root_delegate = bridge->GetFlutterPlatformNodeDelegateFromID(1).lock();
  ASSERT_TRUE(root_delegate);
  ASSERT_EQ(root_delegate->GetChildCount(), 1);

  // Look up the child node delegate.
  auto child_delegate = bridge->GetFlutterPlatformNodeDelegateFromID(2).lock();
  ASSERT_TRUE(child_delegate);
  ASSERT_EQ(child_delegate->GetChildCount(), 0);

  // Ensure a node with ID 0 does not exist.
  auto invalid_delegate = bridge->GetFlutterPlatformNodeDelegateFromID(0).lock();
  ASSERT_FALSE(invalid_delegate);

  [engine shutDownEngine];
}

// While SelectableRegion announces selection changes itself on macOS, the
// selection of static text posts no notification, not even on the root.
TEST_F(AccessibilityBridgeMacWindowTest, StaticSelectionPostsNothingWhileGateIsOff) {
  FlutterViewController* viewController = CreateTestViewController();
  FlutterEngine* engine = viewController.engine;
  GetWindow().contentView = viewController.view;
  engine.semanticsEnabled = YES;
  auto bridge = std::static_pointer_cast<AccessibilityBridgeMacSpy>(
      viewController.accessibilityBridge.lock());
  ASSERT_FALSE(bridge->post_static_selection_notifications);

  FlutterSemanticsFlags flags = FlutterSemanticsFlags{0};
  std::vector<int32_t> children{1};
  FlutterSemanticsNode2 root = CreateNode(0, "root", &flags, &children);
  FlutterSemanticsNode2 paragraph = CreateSelectableTextNode(1, "Hello world", &flags);
  bridge->AddFlutterSemanticsNodeUpdate(root);
  bridge->AddFlutterSemanticsNodeUpdate(paragraph);
  bridge->CommitUpdates();

  paragraph.text_selection_base = 0;
  paragraph.text_selection_extent = 4;
  bridge->AddFlutterSemanticsNodeUpdate(paragraph);
  bridge->CommitUpdates();
  ASSERT_EQ(bridge->GetAXTreeData().sel_focus_object_id, 1);
  EXPECT_TRUE(bridge->PostedTargets(NSAccessibilitySelectedTextChangedNotification).empty());

  paragraph.text_selection_base = -1;
  paragraph.text_selection_extent = -1;
  bridge->AddFlutterSemanticsNodeUpdate(paragraph);
  bridge->CommitUpdates();
  ASSERT_EQ(bridge->GetAXTreeData().sel_focus_object_id, ui::AXNode::kInvalidAXID);
  EXPECT_TRUE(bridge->PostedTargets(NSAccessibilitySelectedTextChangedNotification).empty());

  [engine shutDownEngine];
}

// Once the gate is on, each change posts one notification, on the node whose
// selection edge moved.
TEST_F(AccessibilityBridgeMacWindowTest, StaticSelectionNotifiesTheMovingNodeWhenGateIsOn) {
  FlutterViewController* viewController = CreateTestViewController();
  FlutterEngine* engine = viewController.engine;
  GetWindow().contentView = viewController.view;
  engine.semanticsEnabled = YES;
  auto bridge = std::static_pointer_cast<AccessibilityBridgeMacSpy>(
      viewController.accessibilityBridge.lock());
  bridge->post_static_selection_notifications = true;

  FlutterSemanticsFlags flags = FlutterSemanticsFlags{0};
  std::vector<int32_t> children{1, 2};
  FlutterSemanticsNode2 root = CreateNode(0, "root", &flags, &children);
  FlutterSemanticsNode2 first = CreateSelectableTextNode(1, "Hello world", &flags);
  FlutterSemanticsNode2 second = CreateSelectableTextNode(2, "Second line", &flags);
  bridge->AddFlutterSemanticsNodeUpdate(root);
  bridge->AddFlutterSemanticsNodeUpdate(first);
  bridge->AddFlutterSemanticsNodeUpdate(second);
  bridge->CommitUpdates();
  id native_first =
      bridge->GetFlutterPlatformNodeDelegateFromID(1).lock()->GetNativeViewAccessible();
  id native_second =
      bridge->GetFlutterPlatformNodeDelegateFromID(2).lock()->GetNativeViewAccessible();

  first.text_selection_base = 0;
  first.text_selection_extent = 4;
  bridge->AddFlutterSemanticsNodeUpdate(first);
  bridge->CommitUpdates();
  std::vector<id> posted = bridge->PostedTargets(NSAccessibilitySelectedTextChangedNotification);
  ASSERT_EQ(posted.size(), 1u);
  EXPECT_EQ(posted[0], native_first);

  // Extending into the second paragraph notifies the second paragraph.
  first.text_selection_extent = 11;
  second.text_selection_base = 0;
  second.text_selection_extent = 3;
  bridge->AddFlutterSemanticsNodeUpdate(first);
  bridge->AddFlutterSemanticsNodeUpdate(second);
  bridge->CommitUpdates();
  posted = bridge->PostedTargets(NSAccessibilitySelectedTextChangedNotification);
  ASSERT_EQ(posted.size(), 2u);
  EXPECT_EQ(posted[1], native_second);

  // Clearing notifies the node the selection ended on.
  first.text_selection_base = -1;
  first.text_selection_extent = -1;
  second.text_selection_base = -1;
  second.text_selection_extent = -1;
  bridge->AddFlutterSemanticsNodeUpdate(first);
  bridge->AddFlutterSemanticsNodeUpdate(second);
  bridge->CommitUpdates();
  posted = bridge->PostedTargets(NSAccessibilitySelectedTextChangedNotification);
  ASSERT_EQ(posted.size(), 3u);
  EXPECT_EQ(posted[2], native_second);

  [engine shutDownEngine];
}

// MOCK_ENGINE_PROC is leaky by design
// NOLINTBEGIN(clang-analyzer-core.StackAddressEscape)

// VoiceOver focusing a text field earlier must not route a later static
// selection change to that field.
TEST_F(AccessibilityBridgeMacWindowTest, StaticSelectionDoesNotStartEditingTheATFocusedTextField) {
  FlutterViewController* viewController = CreateTestViewController();
  FlutterEngine* engine = viewController.engine;
  GetWindow().contentView = viewController.view;
  engine.semanticsEnabled = YES;
  engine.embedderAPI.DispatchSemanticsAction = MOCK_ENGINE_PROC(
      DispatchSemanticsAction, ([](auto engine, uint64_t id, FlutterSemanticsAction action,
                                   const uint8_t* data, size_t data_length) { return kSuccess; }));
  auto bridge = std::static_pointer_cast<AccessibilityBridgeMacSpy>(
      viewController.accessibilityBridge.lock());
  bridge->post_static_selection_notifications = true;

  FlutterSemanticsFlags flags = FlutterSemanticsFlags{0};
  FlutterSemanticsFlags field_flags = FlutterSemanticsFlags{.is_text_field = true};
  std::vector<int32_t> children{1, 2};
  FlutterSemanticsNode2 root = CreateNode(0, "root", &flags, &children);
  FlutterSemanticsNode2 paragraph = CreateSelectableTextNode(1, "Hello world", &flags);
  FlutterSemanticsNode2 field = CreateNode(2, "Email", &field_flags);
  bridge->AddFlutterSemanticsNodeUpdate(root);
  bridge->AddFlutterSemanticsNodeUpdate(paragraph);
  bridge->AddFlutterSemanticsNodeUpdate(field);
  bridge->CommitUpdates();

  auto field_delegate = bridge->GetFlutterPlatformNodeDelegateFromID(2).lock();
  FlutterTextField* native_field = (FlutterTextField*)field_delegate->GetNativeViewAccessible();
  ASSERT_TRUE([native_field isKindOfClass:[FlutterTextField class]]);
  ui::AXActionData focus;
  focus.action = ax::mojom::Action::kFocus;
  field_delegate->AccessibilityPerformAction(focus);
  ASSERT_EQ(field_delegate->GetFocus(), native_field);

  paragraph.text_selection_base = 0;
  paragraph.text_selection_extent = 4;
  bridge->AddFlutterSemanticsNodeUpdate(paragraph);
  bridge->CommitUpdates();

  EXPECT_EQ(native_field.currentEditor, nil);
  std::vector<id> posted = bridge->PostedTargets(NSAccessibilitySelectedTextChangedNotification);
  ASSERT_EQ(posted.size(), 1u);
  EXPECT_EQ(posted[0],
            bridge->GetFlutterPlatformNodeDelegateFromID(1).lock()->GetNativeViewAccessible());

  // When the field takes focus with a selection, it owns the tree selection
  // and the text field path runs as before.
  FlutterSemanticsFlags focused_field_flags = FlutterSemanticsFlags{
      .is_focused = FlutterTristate::kFlutterTristateTrue,
      .is_text_field = true,
  };
  field.flags2 = &focused_field_flags;
  field.text_selection_base = 0;
  field.text_selection_extent = 0;
  bridge->AddFlutterSemanticsNodeUpdate(field);
  bridge->CommitUpdates();
  ASSERT_EQ(bridge->GetAXTreeData().sel_focus_object_id, 2);
  EXPECT_NE(native_field.currentEditor, nil);
  EXPECT_EQ(bridge->PostedTargets(NSAccessibilitySelectedTextChangedNotification).size(), 1u);

  [engine shutDownEngine];
}

// NOLINTEND(clang-analyzer-core.StackAddressEscape)

TEST_F(AccessibilityBridgeMacTest, DoesNotSendAccessibilityCreateNotificationWhenHeadless) {
  FlutterViewController* viewController = CreateTestViewController();
  FlutterEngine* engine = viewController.engine;

  // Setting up bridge so that the AccessibilityBridgeMacDelegateSpy
  // can query semantics information from.
  engine.semanticsEnabled = YES;
  auto bridge = std::static_pointer_cast<AccessibilityBridgeMacSpy>(
      viewController.accessibilityBridge.lock());
  FlutterSemanticsNode2 root;
  FlutterSemanticsFlags flags = FlutterSemanticsFlags{0};
  root.id = 0;
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
  auto platform_node_delegate = bridge->GetFlutterPlatformNodeDelegateFromID(0).lock();

  // Creates a targeted event.
  ui::AXTree tree;
  ui::AXNode ax_node(&tree, nullptr, 0, 0);
  ui::AXNodeData node_data;
  node_data.id = 0;
  ax_node.SetData(node_data);
  std::vector<ui::AXEventIntent> intent;
  ui::AXEventGenerator::EventParams event_params(ui::AXEventGenerator::Event::CHILDREN_CHANGED,
                                                 ax::mojom::EventFrom::kNone, intent);
  ui::AXEventGenerator::TargetedEvent targeted_event(&ax_node, event_params);

  bridge->OnAccessibilityEvent(targeted_event);

  // Does not send any notification if the engine is headless.
  EXPECT_EQ(bridge->actual_notifications.count, 0u);
  [engine shutDownEngine];
}

TEST_F(AccessibilityBridgeMacTest, DoesNotSendAccessibilityCreateNotificationWhenNoWindow) {
  FlutterViewController* viewController = CreateTestViewController();
  FlutterEngine* engine = viewController.engine;

  // Setting up bridge so that the AccessibilityBridgeMacDelegateSpy
  // can query semantics information from.
  engine.semanticsEnabled = YES;
  auto bridge = std::static_pointer_cast<AccessibilityBridgeMacSpy>(
      viewController.accessibilityBridge.lock());
  FlutterSemanticsNode2 root;
  FlutterSemanticsFlags flags = FlutterSemanticsFlags{0};
  root.id = 0;
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
  auto platform_node_delegate = bridge->GetFlutterPlatformNodeDelegateFromID(0).lock();

  // Creates a targeted event.
  ui::AXTree tree;
  ui::AXNode ax_node(&tree, nullptr, 0, 0);
  ui::AXNodeData node_data;
  node_data.id = 0;
  ax_node.SetData(node_data);
  std::vector<ui::AXEventIntent> intent;
  ui::AXEventGenerator::EventParams event_params(ui::AXEventGenerator::Event::CHILDREN_CHANGED,
                                                 ax::mojom::EventFrom::kNone, intent);
  ui::AXEventGenerator::TargetedEvent targeted_event(&ax_node, event_params);

  bridge->OnAccessibilityEvent(targeted_event);

  // Does not send any notification if the flutter view is not attached to a NSWindow.
  EXPECT_EQ(bridge->actual_notifications.count, 0u);
  [engine shutDownEngine];
}

}  // namespace flutter::testing
