// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Included first as it collides with the X11 headers.
#include "flutter/shell/platform/linux/testing/linux_test.h"
#include "gtest/gtest.h"

#include "flutter/shell/platform/linux/fl_accessible_node.h"
#include "flutter/shell/platform/linux/fl_view_accessible.h"
#include "flutter/shell/platform/linux/public/flutter_linux/fl_engine.h"
#include "flutter/shell/platform/linux/testing/mock_signal_handler.h"

class FlViewAccessibleTest : public flutter::testing::LinuxTest {};

TEST_F(FlViewAccessibleTest, BuildTree) {
  g_autoptr(FlViewAccessible) accessible = fl_view_accessible_new(engine, 456);

  int32_t children[] = {111, 222};
  FlutterSemanticsFlags flags = {};
  FlutterSemanticsNode2 root_node = {.id = 0,
                                     .label = "root",
                                     .child_count = 2,
                                     .children_in_traversal_order = children,
                                     .flags2 = &flags,
                                     .identifier = ""};
  FlutterSemanticsNode2 child1_node = {
      .id = 111, .label = "child 1", .flags2 = &flags};
  FlutterSemanticsNode2 child2_node = {
      .id = 222, .label = "child 2", .flags2 = &flags};
  FlutterSemanticsNode2* nodes[3] = {&root_node, &child1_node, &child2_node};
  FlutterSemanticsUpdate2 update = {.node_count = 3, .nodes = nodes};
  fl_view_accessible_handle_update_semantics(accessible, &update);

  AtkObject* root_object =
      atk_object_ref_accessible_child(ATK_OBJECT(accessible), 0);
  EXPECT_STREQ(atk_object_get_name(root_object), "root");
  EXPECT_EQ(atk_object_get_index_in_parent(root_object), 0);
  EXPECT_EQ(atk_object_get_n_accessible_children(root_object), 2);

  AtkObject* child1_object = atk_object_ref_accessible_child(root_object, 0);
  EXPECT_STREQ(atk_object_get_name(child1_object), "child 1");
  EXPECT_EQ(atk_object_get_parent(child1_object), root_object);
  EXPECT_EQ(atk_object_get_index_in_parent(child1_object), 0);
  EXPECT_EQ(atk_object_get_n_accessible_children(child1_object), 0);

  AtkObject* child2_object = atk_object_ref_accessible_child(root_object, 1);
  EXPECT_STREQ(atk_object_get_name(child2_object), "child 2");
  EXPECT_EQ(atk_object_get_parent(child2_object), root_object);
  EXPECT_EQ(atk_object_get_index_in_parent(child2_object), 1);
  EXPECT_EQ(atk_object_get_n_accessible_children(child2_object), 0);
}

TEST_F(FlViewAccessibleTest, AddRemoveChildren) {
  g_autoptr(FlViewAccessible) accessible = fl_view_accessible_new(engine, 456);

  FlutterSemanticsFlags flags = {};
  FlutterSemanticsNode2 root_node = {
      .id = 0, .label = "root", .child_count = 0, .flags2 = &flags};
  FlutterSemanticsNode2* nodes[1] = {&root_node};
  FlutterSemanticsUpdate2 update = {.node_count = 1, .nodes = nodes};
  fl_view_accessible_handle_update_semantics(accessible, &update);

  AtkObject* root_object =
      atk_object_ref_accessible_child(ATK_OBJECT(accessible), 0);
  EXPECT_EQ(atk_object_get_n_accessible_children(root_object), 0);

  // add child1
  AtkObject* child1_object = nullptr;
  FlutterSemanticsNode2 child1_node = {
      .id = 111, .label = "child 1", .flags2 = &flags};
  {
    flutter::testing::MockSignalHandler2<gint, AtkObject*> child1_added(
        root_object, "children-changed::add");
    EXPECT_SIGNAL2(child1_added, ::testing::Eq(0), ::testing::A<AtkObject*>())
        .WillOnce(::testing::SaveArg<1>(&child1_object));

    int32_t children[] = {111};
    root_node.child_count = 1;
    root_node.children_in_traversal_order = children;
    FlutterSemanticsNode2* nodes[2] = {&root_node, &child1_node};
    FlutterSemanticsUpdate2 update = {.node_count = 2, .nodes = nodes};
    fl_view_accessible_handle_update_semantics(accessible, &update);
  }

  EXPECT_EQ(atk_object_get_n_accessible_children(root_object), 1);
  EXPECT_EQ(atk_object_ref_accessible_child(root_object, 0), child1_object);

  EXPECT_STREQ(atk_object_get_name(child1_object), "child 1");
  EXPECT_EQ(atk_object_get_parent(child1_object), root_object);
  EXPECT_EQ(atk_object_get_index_in_parent(child1_object), 0);
  EXPECT_EQ(atk_object_get_n_accessible_children(child1_object), 0);

  // add child2
  AtkObject* child2_object = nullptr;
  FlutterSemanticsNode2 child2_node = {
      .id = 222, .label = "child 2", .flags2 = &flags};
  {
    flutter::testing::MockSignalHandler2<gint, AtkObject*> child2_added(
        root_object, "children-changed::add");
    EXPECT_SIGNAL2(child2_added, ::testing::Eq(1), ::testing::A<AtkObject*>())
        .WillOnce(::testing::SaveArg<1>(&child2_object));

    int32_t children[] = {111, 222};
    root_node.child_count = 2;
    root_node.children_in_traversal_order = children;
    FlutterSemanticsNode2* nodes[3] = {&root_node, &child1_node, &child2_node};
    FlutterSemanticsUpdate2 update = {.node_count = 3, .nodes = nodes};
    fl_view_accessible_handle_update_semantics(accessible, &update);
  }

  EXPECT_EQ(atk_object_get_n_accessible_children(root_object), 2);
  EXPECT_EQ(atk_object_ref_accessible_child(root_object, 0), child1_object);
  EXPECT_EQ(atk_object_ref_accessible_child(root_object, 1), child2_object);

  EXPECT_STREQ(atk_object_get_name(child1_object), "child 1");
  EXPECT_EQ(atk_object_get_parent(child1_object), root_object);
  EXPECT_EQ(atk_object_get_index_in_parent(child1_object), 0);
  EXPECT_EQ(atk_object_get_n_accessible_children(child1_object), 0);

  EXPECT_STREQ(atk_object_get_name(child2_object), "child 2");
  EXPECT_EQ(atk_object_get_parent(child2_object), root_object);
  EXPECT_EQ(atk_object_get_index_in_parent(child2_object), 1);
  EXPECT_EQ(atk_object_get_n_accessible_children(child2_object), 0);

  // remove child1
  {
    flutter::testing::MockSignalHandler2<gint, AtkObject*> child1_removed(
        root_object, "children-changed::remove");
    EXPECT_SIGNAL2(child1_removed, ::testing::Eq(0),
                   ::testing::Eq(child1_object));

    const int32_t children[] = {222};
    root_node.child_count = 1;
    root_node.children_in_traversal_order = children;
    FlutterSemanticsNode2* nodes[3] = {&root_node, &child2_node};
    FlutterSemanticsUpdate2 update = {.node_count = 2, .nodes = nodes};
    fl_view_accessible_handle_update_semantics(accessible, &update);
  }

  EXPECT_EQ(atk_object_get_n_accessible_children(root_object), 1);
  EXPECT_EQ(atk_object_ref_accessible_child(root_object, 0), child2_object);

  EXPECT_STREQ(atk_object_get_name(child2_object), "child 2");
  EXPECT_EQ(atk_object_get_parent(child2_object), root_object);
  EXPECT_EQ(atk_object_get_index_in_parent(child2_object), 0);
  EXPECT_EQ(atk_object_get_n_accessible_children(child2_object), 0);

  // remove child2
  {
    flutter::testing::MockSignalHandler2<gint, AtkObject*> child2_removed(
        root_object, "children-changed::remove");
    EXPECT_SIGNAL2(child2_removed, ::testing::Eq(0),
                   ::testing::Eq(child2_object));

    root_node.child_count = 0;
    FlutterSemanticsNode2* nodes[1] = {&root_node};
    FlutterSemanticsUpdate2 update = {.node_count = 1, .nodes = nodes};
    fl_view_accessible_handle_update_semantics(accessible, &update);
  }

  EXPECT_EQ(atk_object_get_n_accessible_children(root_object), 0);
}

// Checks that a selection change across several paragraphs (static text with
// the set selection action) in one update is signalled by the node holding
// the selection extent only.
TEST_F(FlViewAccessibleTest, SelectionChangeAcrossNodesIsSignalledOnce) {
  g_autoptr(FlViewAccessible) accessible = fl_view_accessible_new(engine, 456);

  int32_t children[] = {111, 222};
  FlutterSemanticsFlags flags = {};
  FlutterSemanticsNode2 root_node = {.id = 0,
                                     .text_selection_base = -1,
                                     .text_selection_extent = -1,
                                     .label = "root",
                                     .child_count = 2,
                                     .children_in_traversal_order = children,
                                     .flags2 = &flags};
  FlutterSemanticsNode2 first_node = {
      .id = 111,
      .actions = kFlutterSemanticsActionSetSelection,
      .text_selection_base = -1,
      .text_selection_extent = -1,
      .label = "Hello world",
      .flags2 = &flags};
  FlutterSemanticsNode2 second_node = {
      .id = 222,
      .actions = kFlutterSemanticsActionSetSelection,
      .text_selection_base = -1,
      .text_selection_extent = -1,
      .label = "Second line",
      .flags2 = &flags};
  FlutterSemanticsNode2* nodes[3] = {&root_node, &first_node, &second_node};
  FlutterSemanticsUpdate2 update = {.node_count = 3, .nodes = nodes};
  fl_view_accessible_handle_update_semantics(accessible, &update);

  g_autoptr(AtkObject) root_object =
      atk_object_ref_accessible_child(ATK_OBJECT(accessible), 0);
  g_autoptr(AtkObject) first_object =
      atk_object_ref_accessible_child(root_object, 0);
  g_autoptr(AtkObject) second_object =
      atk_object_ref_accessible_child(root_object, 1);
  EXPECT_EQ(atk_object_get_role(first_object), ATK_ROLE_PARAGRAPH);

  flutter::testing::MockSignalHandler first_changed(first_object,
                                                    "text-selection-changed");
  flutter::testing::MockSignalHandler second_changed(second_object,
                                                     "text-selection-changed");
  EXPECT_SIGNAL(first_changed).Times(0);
  EXPECT_SIGNAL(second_changed);

  // A forward selection from "world" to "Second", listed in any order.
  first_node.text_selection_base = 6;
  first_node.text_selection_extent = 11;
  second_node.text_selection_base = 0;
  second_node.text_selection_extent = 6;
  FlutterSemanticsNode2* selection_nodes[2] = {&second_node, &first_node};
  FlutterSemanticsUpdate2 selection_update = {.node_count = 2,
                                              .nodes = selection_nodes};
  fl_view_accessible_handle_update_semantics(accessible, &selection_update);

  EXPECT_EQ(atk_text_get_n_selections(ATK_TEXT(first_object)), 1);
  EXPECT_EQ(atk_text_get_n_selections(ATK_TEXT(second_object)), 1);
}
