// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Included first as it collides with the X11 headers.
#include "flutter/shell/platform/linux/testing/linux_test.h"
#include "gtest/gtest.h"

#include "flutter/shell/platform/embedder/test_utils/proc_table_replacement.h"
#include "flutter/shell/platform/linux/fl_accessible_node.h"
#include "flutter/shell/platform/linux/fl_engine_private.h"
#include "flutter/shell/platform/linux/public/flutter_linux/fl_standard_message_codec.h"
#include "flutter/shell/platform/linux/testing/mock_gtk.h"
#include "flutter/shell/platform/linux/testing/mock_signal_handler.h"

class FlAccessibleNodeTest : public flutter::testing::LinuxTest {
 protected:
  ::testing::NiceMock<flutter::testing::MockGtk> mock_gtk;
};

// Checks can build a tree of nodes.
TEST_F(FlAccessibleNodeTest, BuildTree) {
  int64_t view_id = 123;
  g_autoptr(FlAccessibleNode) root = fl_accessible_node_new(engine, view_id, 0);
  g_autoptr(FlAccessibleNode) child1 =
      fl_accessible_node_new(engine, view_id, 1);
  fl_accessible_node_set_parent(child1, ATK_OBJECT(root), 0);
  g_autoptr(FlAccessibleNode) child2 =
      fl_accessible_node_new(engine, view_id, 1);
  fl_accessible_node_set_parent(child2, ATK_OBJECT(root), 1);
  g_autoptr(GPtrArray) children =
      g_ptr_array_new_with_free_func(g_object_unref);
  g_ptr_array_add(children, g_object_ref(child1));
  g_ptr_array_add(children, g_object_ref(child2));
  fl_accessible_node_set_children(root, children);

  EXPECT_EQ(atk_object_get_n_accessible_children(ATK_OBJECT(root)), 2);
  EXPECT_EQ(atk_object_get_index_in_parent(ATK_OBJECT(root)), 0);
  g_autoptr(AtkObject) c1 =
      atk_object_ref_accessible_child(ATK_OBJECT(root), 0);
  EXPECT_EQ(ATK_OBJECT(child1), c1);
  g_autoptr(AtkObject) c2 =
      atk_object_ref_accessible_child(ATK_OBJECT(root), 1);
  EXPECT_EQ(ATK_OBJECT(child2), c2);
  EXPECT_EQ(atk_object_get_parent(ATK_OBJECT(root)), nullptr);

  EXPECT_EQ(atk_object_get_parent(ATK_OBJECT(child1)), ATK_OBJECT(root));
  EXPECT_EQ(atk_object_get_index_in_parent(ATK_OBJECT(child1)), 0);
  EXPECT_EQ(atk_object_get_n_accessible_children(ATK_OBJECT(child1)), 0);

  EXPECT_EQ(atk_object_get_parent(ATK_OBJECT(child2)), ATK_OBJECT(root));
  EXPECT_EQ(atk_object_get_index_in_parent(ATK_OBJECT(child2)), 1);
  EXPECT_EQ(atk_object_get_n_accessible_children(ATK_OBJECT(child2)), 0);
}

// Checks node name is exposed to ATK.
TEST_F(FlAccessibleNodeTest, SetName) {
  g_autoptr(FlAccessibleNode) node = fl_accessible_node_new(engine, 123, 0);
  fl_accessible_node_set_name(node, "test");
  EXPECT_STREQ(atk_object_get_name(ATK_OBJECT(node)), "test");
}

// Checks node extents are exposed to ATK.
TEST_F(FlAccessibleNodeTest, SetExtents) {
  g_autoptr(FlAccessibleNode) node = fl_accessible_node_new(engine, 123, 0);
  fl_accessible_node_set_extents(node, 1, 2, 3, 4);
  gint x, y, width, height;
  atk_component_get_extents(ATK_COMPONENT(node), &x, &y, &width, &height,
                            ATK_XY_PARENT);
  EXPECT_EQ(x, 1);
  EXPECT_EQ(y, 2);
  EXPECT_EQ(width, 3);
  EXPECT_EQ(height, 4);
}

// Checks the Flutter focused flag are mapped to ATK flags.
TEST_F(FlAccessibleNodeTest, FocusedFlags) {
  g_autoptr(FlAccessibleNode) node = fl_accessible_node_new(engine, 123, 0);

  FlutterSemanticsFlags flags1 = {};
  flags1.is_focused = kFlutterTristateNone;
  fl_accessible_node_set_flags(node, &flags1);
  AtkStateSet* state1 = atk_object_ref_state_set(ATK_OBJECT(node));
  EXPECT_FALSE(atk_state_set_contains_state(state1, ATK_STATE_FOCUSABLE));
  EXPECT_FALSE(atk_state_set_contains_state(state1, ATK_STATE_FOCUSED));
  g_object_unref(state1);

  FlutterSemanticsFlags flags2 = {};
  flags2.is_focused = kFlutterTristateFalse;
  EXPECT_CALL(mock_gtk, atk_object_notify_state_change(
                            ::testing::_, ATK_STATE_FOCUSABLE, TRUE));
  fl_accessible_node_set_flags(node, &flags2);
  AtkStateSet* state2 = atk_object_ref_state_set(ATK_OBJECT(node));
  EXPECT_TRUE(atk_state_set_contains_state(state2, ATK_STATE_FOCUSABLE));
  EXPECT_FALSE(atk_state_set_contains_state(state2, ATK_STATE_FOCUSED));
  g_object_unref(state2);

  FlutterSemanticsFlags flags3 = {};
  flags3.is_focused = kFlutterTristateTrue;
  EXPECT_CALL(mock_gtk, atk_object_notify_state_change(
                            ::testing::_, ATK_STATE_FOCUSED, TRUE));
  fl_accessible_node_set_flags(node, &flags3);
  AtkStateSet* state3 = atk_object_ref_state_set(ATK_OBJECT(node));
  EXPECT_TRUE(atk_state_set_contains_state(state3, ATK_STATE_FOCUSABLE));
  EXPECT_TRUE(atk_state_set_contains_state(state3, ATK_STATE_FOCUSED));
  g_object_unref(state3);
}

// Checks the Flutter checked and toggled flags are mapped to ATK flags.
TEST_F(FlAccessibleNodeTest, CheckedAndToggledFlags) {
  g_autoptr(FlAccessibleNode) node = fl_accessible_node_new(engine, 123, 0);

  FlutterSemanticsFlags flags1 = {};
  flags1.is_checked = kFlutterCheckStateNone;
  flags1.is_toggled = kFlutterTristateNone;
  fl_accessible_node_set_flags(node, &flags1);
  AtkStateSet* state1 = atk_object_ref_state_set(ATK_OBJECT(node));
  EXPECT_FALSE(atk_state_set_contains_state(state1, ATK_STATE_CHECKABLE));
  EXPECT_FALSE(atk_state_set_contains_state(state1, ATK_STATE_CHECKED));
  g_object_unref(state1);

  FlutterSemanticsFlags flags2 = {};
  flags2.is_checked = kFlutterCheckStateFalse;
  flags2.is_toggled = kFlutterTristateFalse;
  EXPECT_CALL(mock_gtk, atk_object_notify_state_change(
                            ::testing::_, ATK_STATE_CHECKABLE, TRUE));
  fl_accessible_node_set_flags(node, &flags2);
  AtkStateSet* state2 = atk_object_ref_state_set(ATK_OBJECT(node));
  EXPECT_TRUE(atk_state_set_contains_state(state2, ATK_STATE_CHECKABLE));
  EXPECT_FALSE(atk_state_set_contains_state(state2, ATK_STATE_CHECKED));
  g_object_unref(state2);

  FlutterSemanticsFlags flags3 = {};
  flags3.is_checked = kFlutterCheckStateTrue;
  flags3.is_toggled = kFlutterTristateTrue;
  EXPECT_CALL(mock_gtk, atk_object_notify_state_change(
                            ::testing::_, ATK_STATE_CHECKED, TRUE));
  fl_accessible_node_set_flags(node, &flags3);
  AtkStateSet* state3 = atk_object_ref_state_set(ATK_OBJECT(node));
  EXPECT_TRUE(atk_state_set_contains_state(state3, ATK_STATE_CHECKABLE));
  EXPECT_TRUE(atk_state_set_contains_state(state3, ATK_STATE_CHECKED));
  g_object_unref(state3);

  FlutterSemanticsFlags flags4 = {};
  flags4.is_checked = kFlutterCheckStateTrue;
  flags4.is_toggled = kFlutterTristateNone;
  fl_accessible_node_set_flags(node, &flags4);
  AtkStateSet* state4 = atk_object_ref_state_set(ATK_OBJECT(node));
  EXPECT_TRUE(atk_state_set_contains_state(state4, ATK_STATE_CHECKABLE));
  EXPECT_TRUE(atk_state_set_contains_state(state4, ATK_STATE_CHECKED));
  g_object_unref(state4);

  FlutterSemanticsFlags flags5 = {};
  flags5.is_checked = kFlutterCheckStateNone;
  flags5.is_toggled = kFlutterTristateTrue;
  fl_accessible_node_set_flags(node, &flags5);
  AtkStateSet* state5 = atk_object_ref_state_set(ATK_OBJECT(node));
  EXPECT_TRUE(atk_state_set_contains_state(state5, ATK_STATE_CHECKABLE));
  EXPECT_TRUE(atk_state_set_contains_state(state5, ATK_STATE_CHECKED));
  g_object_unref(state5);
}

// Checks the Flutter selected flag is mapped to ATK flags.
TEST_F(FlAccessibleNodeTest, SelectedFlags) {
  g_autoptr(FlAccessibleNode) node = fl_accessible_node_new(engine, 123, 0);

  FlutterSemanticsFlags flags1 = {};
  flags1.is_selected = kFlutterTristateNone;
  fl_accessible_node_set_flags(node, &flags1);
  AtkStateSet* state1 = atk_object_ref_state_set(ATK_OBJECT(node));
  EXPECT_FALSE(atk_state_set_contains_state(state1, ATK_STATE_SELECTED));
  g_object_unref(state1);

  FlutterSemanticsFlags flags2 = {};
  flags2.is_selected = kFlutterTristateFalse;
  fl_accessible_node_set_flags(node, &flags2);
  AtkStateSet* state2 = atk_object_ref_state_set(ATK_OBJECT(node));
  EXPECT_FALSE(atk_state_set_contains_state(state2, ATK_STATE_SELECTED));
  g_object_unref(state2);

  FlutterSemanticsFlags flags3 = {};
  flags3.is_selected = kFlutterTristateTrue;
  EXPECT_CALL(mock_gtk, atk_object_notify_state_change(
                            ::testing::_, ATK_STATE_SELECTED, TRUE));
  fl_accessible_node_set_flags(node, &flags3);
  AtkStateSet* state3 = atk_object_ref_state_set(ATK_OBJECT(node));
  EXPECT_TRUE(atk_state_set_contains_state(state3, ATK_STATE_SELECTED));
  g_object_unref(state3);
}

// Checks the Flutter enabled flag is mapped to ATK flags.
TEST_F(FlAccessibleNodeTest, EnabledFlags) {
  g_autoptr(FlAccessibleNode) node = fl_accessible_node_new(engine, 123, 0);

  FlutterSemanticsFlags flags1 = {};
  flags1.is_enabled = kFlutterTristateNone;
  fl_accessible_node_set_flags(node, &flags1);
  AtkStateSet* state1 = atk_object_ref_state_set(ATK_OBJECT(node));
  EXPECT_FALSE(atk_state_set_contains_state(state1, ATK_STATE_SENSITIVE));
  EXPECT_FALSE(atk_state_set_contains_state(state1, ATK_STATE_ENABLED));
  g_object_unref(state1);

  FlutterSemanticsFlags flags2 = {};
  flags2.is_enabled = kFlutterTristateFalse;
  EXPECT_CALL(mock_gtk, atk_object_notify_state_change(
                            ::testing::_, ATK_STATE_SENSITIVE, TRUE));
  fl_accessible_node_set_flags(node, &flags2);
  AtkStateSet* state2 = atk_object_ref_state_set(ATK_OBJECT(node));
  EXPECT_TRUE(atk_state_set_contains_state(state2, ATK_STATE_SENSITIVE));
  EXPECT_FALSE(atk_state_set_contains_state(state2, ATK_STATE_ENABLED));
  g_object_unref(state2);

  FlutterSemanticsFlags flags3 = {};
  flags3.is_enabled = kFlutterTristateTrue;
  EXPECT_CALL(mock_gtk, atk_object_notify_state_change(
                            ::testing::_, ATK_STATE_ENABLED, TRUE));
  fl_accessible_node_set_flags(node, &flags3);
  AtkStateSet* state3 = atk_object_ref_state_set(ATK_OBJECT(node));
  EXPECT_TRUE(atk_state_set_contains_state(state3, ATK_STATE_SENSITIVE));
  EXPECT_TRUE(atk_state_set_contains_state(state3, ATK_STATE_ENABLED));
  g_object_unref(state3);
}

// Checks the Flutter obscured flag is mapped to ATK flags.
TEST_F(FlAccessibleNodeTest, ObscuredFlags) {
  g_autoptr(FlAccessibleNode) node = fl_accessible_node_new(engine, 123, 0);

  FlutterSemanticsFlags flags1 = {};
  flags1.is_obscured = true;
  fl_accessible_node_set_flags(node, &flags1);
  AtkStateSet* state1 = atk_object_ref_state_set(ATK_OBJECT(node));
  EXPECT_FALSE(atk_state_set_contains_state(state1, ATK_STATE_SHOWING));
  g_object_unref(state1);

  FlutterSemanticsFlags flags2 = {};
  flags2.is_obscured = false;
  EXPECT_CALL(mock_gtk, atk_object_notify_state_change(
                            ::testing::_, ATK_STATE_SHOWING, TRUE));
  fl_accessible_node_set_flags(node, &flags2);
  AtkStateSet* state2 = atk_object_ref_state_set(ATK_OBJECT(node));
  EXPECT_TRUE(atk_state_set_contains_state(state2, ATK_STATE_SHOWING));
  g_object_unref(state2);
}

// Checks the Flutter hidden flag is mapped to ATK flags.
TEST_F(FlAccessibleNodeTest, HiddenFlags) {
  g_autoptr(FlAccessibleNode) node = fl_accessible_node_new(engine, 123, 0);

  FlutterSemanticsFlags flags1 = {};
  flags1.is_hidden = true;
  fl_accessible_node_set_flags(node, &flags1);
  AtkStateSet* state1 = atk_object_ref_state_set(ATK_OBJECT(node));
  EXPECT_FALSE(atk_state_set_contains_state(state1, ATK_STATE_VISIBLE));
  g_object_unref(state1);

  FlutterSemanticsFlags flags2 = {};
  flags2.is_hidden = false;
  EXPECT_CALL(mock_gtk, atk_object_notify_state_change(
                            ::testing::_, ATK_STATE_VISIBLE, TRUE));
  fl_accessible_node_set_flags(node, &flags2);
  AtkStateSet* state2 = atk_object_ref_state_set(ATK_OBJECT(node));
  EXPECT_TRUE(atk_state_set_contains_state(state2, ATK_STATE_VISIBLE));
  g_object_unref(state2);
}

// Checks the Flutter read only flag is mapped to ATK flags.
TEST_F(FlAccessibleNodeTest, ReadOnlyFlags) {
  g_autoptr(FlAccessibleNode) node = fl_accessible_node_new(engine, 123, 0);

  FlutterSemanticsFlags flags1 = {};
  flags1.is_read_only = false;
  fl_accessible_node_set_flags(node, &flags1);
  AtkStateSet* state1 = atk_object_ref_state_set(ATK_OBJECT(node));
  EXPECT_FALSE(atk_state_set_contains_state(state1, ATK_STATE_READ_ONLY));
  g_object_unref(state1);

  FlutterSemanticsFlags flags2 = {};
  flags2.is_read_only = true;
  EXPECT_CALL(mock_gtk, atk_object_notify_state_change(
                            ::testing::_, ATK_STATE_READ_ONLY, TRUE));
  fl_accessible_node_set_flags(node, &flags2);
  AtkStateSet* state2 = atk_object_ref_state_set(ATK_OBJECT(node));
  EXPECT_TRUE(atk_state_set_contains_state(state2, ATK_STATE_READ_ONLY));
  g_object_unref(state2);
}

// Checks the Flutter text field flag is mapped to ATK flags.
TEST_F(FlAccessibleNodeTest, TextFieldFlags) {
  g_autoptr(FlAccessibleNode) node = fl_accessible_node_new(engine, 123, 0);

  FlutterSemanticsFlags flags1 = {};
  flags1.is_text_field = false;
  fl_accessible_node_set_flags(node, &flags1);
  AtkStateSet* state1 = atk_object_ref_state_set(ATK_OBJECT(node));
  EXPECT_FALSE(atk_state_set_contains_state(state1, ATK_STATE_EDITABLE));
  g_object_unref(state1);

  FlutterSemanticsFlags flags2 = {};
  flags2.is_text_field = true;
  EXPECT_CALL(mock_gtk, atk_object_notify_state_change(
                            ::testing::_, ATK_STATE_EDITABLE, TRUE));
  fl_accessible_node_set_flags(node, &flags2);
  AtkStateSet* state2 = atk_object_ref_state_set(ATK_OBJECT(node));
  EXPECT_TRUE(atk_state_set_contains_state(state2, ATK_STATE_EDITABLE));
  g_object_unref(state2);
}

// Checks Flutter flags are mapped to appropriate ATK roles.
TEST_F(FlAccessibleNodeTest, GetRole) {
  g_autoptr(FlAccessibleNode) node = fl_accessible_node_new(engine, 123, 0);

  FlutterSemanticsFlags flags1 = {};
  flags1.is_button = true;
  fl_accessible_node_set_flags(node, &flags1);
  EXPECT_EQ(atk_object_get_role(ATK_OBJECT(node)), ATK_ROLE_PUSH_BUTTON);

  FlutterSemanticsFlags flags2 = {};
  flags2.is_checked = kFlutterCheckStateFalse;
  fl_accessible_node_set_flags(node, &flags2);
  EXPECT_EQ(atk_object_get_role(ATK_OBJECT(node)), ATK_ROLE_CHECK_BOX);

  FlutterSemanticsFlags flags3 = {};
  flags3.is_checked = kFlutterCheckStateFalse;
  flags3.is_in_mutually_exclusive_group = true;
  fl_accessible_node_set_flags(node, &flags3);
  EXPECT_EQ(atk_object_get_role(ATK_OBJECT(node)), ATK_ROLE_RADIO_BUTTON);

  FlutterSemanticsFlags flags4 = {};
  flags4.is_toggled = kFlutterTristateFalse;
  fl_accessible_node_set_flags(node, &flags4);
  EXPECT_EQ(atk_object_get_role(ATK_OBJECT(node)), ATK_ROLE_TOGGLE_BUTTON);

  FlutterSemanticsFlags flags5 = {};
  flags5.is_text_field = true;
  fl_accessible_node_set_flags(node, &flags5);
  EXPECT_EQ(atk_object_get_role(ATK_OBJECT(node)), ATK_ROLE_TEXT);

  FlutterSemanticsFlags flags6 = {};
  flags6.is_text_field = true;
  flags6.is_obscured = true;
  fl_accessible_node_set_flags(node, &flags6);
  EXPECT_EQ(atk_object_get_role(ATK_OBJECT(node)), ATK_ROLE_PASSWORD_TEXT);

  FlutterSemanticsFlags flags7 = {};
  flags7.is_header = true;
  fl_accessible_node_set_flags(node, &flags7);
  EXPECT_EQ(atk_object_get_role(ATK_OBJECT(node)), ATK_ROLE_HEADING);
}

// Checks the node's name is exposed through the AtkText interface so that
// screen readers can read the text content of objects such as headings.
TEST_F(FlAccessibleNodeTest, ExposesTextViaAtkText) {
  g_autoptr(FlAccessibleNode) node = fl_accessible_node_new(engine, 123, 0);
  fl_accessible_node_set_name(node, "Section One");

  EXPECT_EQ(atk_text_get_character_count(ATK_TEXT(node)), 11);

  g_autofree gchar* text = atk_text_get_text(ATK_TEXT(node), 0, -1);
  EXPECT_STREQ(text, "Section One");

  g_autofree gchar* substring = atk_text_get_text(ATK_TEXT(node), 0, 7);
  EXPECT_STREQ(substring, "Section");

  EXPECT_EQ(atk_text_get_character_at_offset(ATK_TEXT(node), 0), gunichar('S'));

  EXPECT_EQ(atk_text_get_caret_offset(ATK_TEXT(node)), -1);
  EXPECT_EQ(atk_text_get_n_selections(ATK_TEXT(node)), 0);

  gint start_offset = -1;
  gint end_offset = -1;
  g_autofree gchar* selection =
      atk_text_get_selection(ATK_TEXT(node), 0, &start_offset, &end_offset);
  EXPECT_EQ(selection, nullptr);
  EXPECT_EQ(start_offset, 0);
  EXPECT_EQ(end_offset, 0);

  start_offset = -1;
  end_offset = -1;
  g_autofree gchar* text_at_offset = atk_text_get_string_at_offset(
      ATK_TEXT(node), 0, ATK_TEXT_GRANULARITY_CHAR, &start_offset, &end_offset);
  EXPECT_STREQ(text_at_offset, "S");
  EXPECT_EQ(start_offset, 0);
  EXPECT_EQ(end_offset, 1);

  start_offset = -1;
  end_offset = -1;
  g_autofree gchar* text_at_line_offset = atk_text_get_string_at_offset(
      ATK_TEXT(node), 0, ATK_TEXT_GRANULARITY_LINE, &start_offset, &end_offset);
  EXPECT_STREQ(text_at_line_offset, "Section One");
  EXPECT_EQ(start_offset, 0);
  EXPECT_EQ(end_offset, 11);

  start_offset = -1;
  end_offset = -1;
  g_autofree gchar* text_out_of_bounds = atk_text_get_string_at_offset(
      ATK_TEXT(node), 100, ATK_TEXT_GRANULARITY_CHAR, &start_offset,
      &end_offset);
  EXPECT_EQ(text_out_of_bounds, nullptr);
  EXPECT_EQ(start_offset, 0);
  EXPECT_EQ(end_offset, 0);
}

// Checks Flutter actions are mapped to the appropriate ATK actions.
TEST_F(FlAccessibleNodeTest, SetActions) {
  g_autoptr(FlAccessibleNode) node = fl_accessible_node_new(engine, 123, 0);
  fl_accessible_node_set_actions(
      node, static_cast<FlutterSemanticsAction>(
                kFlutterSemanticsActionTap | kFlutterSemanticsActionLongPress));

  EXPECT_EQ(atk_action_get_n_actions(ATK_ACTION(node)), 2);
  EXPECT_STREQ(atk_action_get_name(ATK_ACTION(node), 0), "Tap");
  EXPECT_STREQ(atk_action_get_name(ATK_ACTION(node), 1), "LongPress");
}

// The AT-SPI bridge can keep nodes alive past engine teardown. Accessing a
// node after its engine is destroyed must not dereference freed memory.
// https://github.com/flutter/flutter/issues/188660
TEST_F(FlAccessibleNodeTest, SurvivesEngineDestruction) {
  g_autoptr(FlDartProject) project = fl_dart_project_new();
  FlEngine* local_engine = fl_engine_new(project);
  g_autoptr(FlAccessibleNode) node =
      fl_accessible_node_new(local_engine, 123, 0);
  fl_accessible_node_set_actions(node, kFlutterSemanticsActionTap);

  // Destroy the engine while the node is still alive.
  g_object_unref(local_engine);

  // Performing an action no longer reaches the engine, but does not crash.
  EXPECT_FALSE(atk_action_do_action(ATK_ACTION(node), 0));
}

// Accessing a node after its parent is destroyed must not dereference freed
// memory.
TEST_F(FlAccessibleNodeTest, SurvivesParentDestruction) {
  FlAccessibleNode* root = fl_accessible_node_new(engine, 123, 0);
  g_autoptr(FlAccessibleNode) child = fl_accessible_node_new(engine, 123, 1);
  fl_accessible_node_set_parent(child, ATK_OBJECT(root), 0);

  // Destroy the parent while the child is still alive.
  g_object_unref(root);

  // The child no longer reports a parent, but does not crash.
  EXPECT_EQ(atk_object_get_parent(ATK_OBJECT(child)), nullptr);
  gint x = 0, y = 0, width = 0, height = 0;
  atk_component_get_extents(ATK_COMPONENT(child), &x, &y, &width, &height,
                            ATK_XY_SCREEN);
}

// A paragraph under a SelectableRegion: a node that is not a text field and has
// the set selection action.
static FlAccessibleNode* create_selectable_text(FlEngine* engine,
                                                int32_t id,
                                                const gchar* name) {
  FlAccessibleNode* node = fl_accessible_node_new(engine, 123, id);
  FlutterSemanticsFlags flags = {};
  fl_accessible_node_set_flags(node, &flags);
  fl_accessible_node_set_actions(node, kFlutterSemanticsActionSetSelection);
  fl_accessible_node_set_name(node, name);
  return node;
}

// Applies a selection update to [node] as one semantics update.
static void update_selection(FlAccessibleNode* node, gint base, gint extent) {
  fl_accessible_node_set_text_selection(node, base, extent);
  g_autoptr(GPtrArray) nodes = g_ptr_array_new();
  g_ptr_array_add(nodes, node);
  fl_accessible_node_emit_text_selection_changes(nodes);
}

// Checks selectable static text exposes its selection through AtkText and
// emits the AtkText signals.
TEST_F(FlAccessibleNodeTest, SelectableTextSelection) {
  g_autoptr(FlAccessibleNode) node =
      create_selectable_text(engine, 1, "Hello world");
  EXPECT_EQ(atk_object_get_role(ATK_OBJECT(node)), ATK_ROLE_PARAGRAPH);
  EXPECT_EQ(atk_text_get_n_selections(ATK_TEXT(node)), 0);
  EXPECT_EQ(atk_text_get_caret_offset(ATK_TEXT(node)), -1);

  {
    flutter::testing::MockSignalHandler text_selection_changed(
        node, "text-selection-changed");
    flutter::testing::MockSignalHandler1<int> text_caret_moved(
        node, "text-caret-moved");
    EXPECT_SIGNAL(text_selection_changed);
    EXPECT_SIGNAL1(text_caret_moved, ::testing::Eq(5));
    update_selection(node, 0, 5);
  }

  EXPECT_EQ(atk_text_get_n_selections(ATK_TEXT(node)), 1);
  gint start_offset = -1;
  gint end_offset = -1;
  g_autofree gchar* selection =
      atk_text_get_selection(ATK_TEXT(node), 0, &start_offset, &end_offset);
  EXPECT_STREQ(selection, "Hello");
  EXPECT_EQ(start_offset, 0);
  EXPECT_EQ(end_offset, 5);
  EXPECT_EQ(atk_text_get_caret_offset(ATK_TEXT(node)), 5);

  // Clearing emits only text-selection-changed.
  {
    flutter::testing::MockSignalHandler text_selection_changed(
        node, "text-selection-changed");
    flutter::testing::MockSignalHandler text_caret_moved(node,
                                                         "text-caret-moved");
    EXPECT_SIGNAL(text_selection_changed);
    EXPECT_SIGNAL(text_caret_moved).Times(0);
    update_selection(node, -1, -1);
  }
  EXPECT_EQ(atk_text_get_n_selections(ATK_TEXT(node)), 0);
  EXPECT_EQ(atk_text_get_caret_offset(ATK_TEXT(node)), -1);
}

// Checks Flutter's UTF-16 selection offsets are reported as character offsets.
TEST_F(FlAccessibleNodeTest, SelectableTextSelectionOffsetsAreCharacters) {
  // One emoji (two UTF-16 code units), then "ab".
  g_autoptr(FlAccessibleNode) node = create_selectable_text(engine, 1,
                                                            "\xF0\x9F\x98\x80"
                                                            "ab");

  {
    flutter::testing::MockSignalHandler1<int> text_caret_moved(
        node, "text-caret-moved");
    EXPECT_SIGNAL1(text_caret_moved, ::testing::Eq(3));
    update_selection(node, 2, 4);
  }

  gint start_offset = -1;
  gint end_offset = -1;
  g_autofree gchar* selection =
      atk_text_get_selection(ATK_TEXT(node), 0, &start_offset, &end_offset);
  EXPECT_STREQ(selection, "ab");
  EXPECT_EQ(start_offset, 1);
  EXPECT_EQ(end_offset, 3);
}

// MOCK_ENGINE_PROC is leaky by design
// NOLINTBEGIN(clang-analyzer-core.StackAddressEscape)

// Checks the AtkText selection setters send the framework UTF-16 offsets.
TEST_F(FlAccessibleNodeTest, SelectableTextSetSelection) {
  int base = -2;
  int extent = -2;
  StartEngine();
  fl_engine_get_embedder_api(engine)->SendSemanticsAction = MOCK_ENGINE_PROC(
      SendSemanticsAction,
      ([&base, &extent](auto engine,
                        const FlutterSendSemanticsActionInfo* info) {
        EXPECT_EQ(info->action, kFlutterSemanticsActionSetSelection);
        g_autoptr(GBytes) bytes = g_bytes_new(info->data, info->data_length);
        g_autoptr(FlStandardMessageCodec) codec =
            fl_standard_message_codec_new();
        g_autoptr(FlValue) value = fl_message_codec_decode_message(
            FL_MESSAGE_CODEC(codec), bytes, nullptr);
        EXPECT_EQ(fl_value_get_type(value), FL_VALUE_TYPE_MAP);
        base = fl_value_get_int(fl_value_lookup_string(value, "base"));
        extent = fl_value_get_int(fl_value_lookup_string(value, "extent"));
        return kSuccess;
      }));

  g_autoptr(FlAccessibleNode) node = create_selectable_text(engine, 1,
                                                            "\xF0\x9F\x98\x80"
                                                            "ab");

  // Characters [1, 3) are UTF-16 [2, 4).
  EXPECT_TRUE(atk_text_add_selection(ATK_TEXT(node), 1, 3));
  EXPECT_EQ(base, 2);
  EXPECT_EQ(extent, 4);

  // There is at most one selection.
  update_selection(node, 2, 4);
  base = extent = -2;
  EXPECT_FALSE(atk_text_add_selection(ATK_TEXT(node), 0, 1));
  EXPECT_EQ(base, -2);

  EXPECT_TRUE(atk_text_set_selection(ATK_TEXT(node), 0, 0, 1));
  EXPECT_EQ(base, 0);
  EXPECT_EQ(extent, 2);
  EXPECT_FALSE(atk_text_set_selection(ATK_TEXT(node), 1, 0, 1));

  // A collapsed selection is a caret too.
  update_selection(node, -1, -1);
  EXPECT_TRUE(atk_text_set_selection(ATK_TEXT(node), 0, 2, 2));
  EXPECT_EQ(base, 3);
  EXPECT_EQ(extent, 3);
  EXPECT_EQ(atk_text_get_caret_offset(ATK_TEXT(node)), 2);
  update_selection(node, 2, 4);

  // Negative offsets clear the selection in the framework.
  EXPECT_TRUE(atk_text_remove_selection(ATK_TEXT(node), 0));
  EXPECT_EQ(base, -1);
  EXPECT_EQ(extent, -1);

  // A caret is only recorded by the framework, so the node reports it until
  // a selection is published.
  update_selection(node, -1, -1);
  EXPECT_FALSE(atk_text_remove_selection(ATK_TEXT(node), 0));
  EXPECT_TRUE(atk_text_set_caret_offset(ATK_TEXT(node), 1));
  EXPECT_EQ(base, 2);
  EXPECT_EQ(extent, 2);
  EXPECT_EQ(atk_text_get_caret_offset(ATK_TEXT(node)), 1);
  update_selection(node, 3, 4);
  EXPECT_EQ(atk_text_get_caret_offset(ATK_TEXT(node)), 3);
}

// NOLINTEND(clang-analyzer-core.StackAddressEscape)

// Checks nodes without the set selection action are not selectable, and that
// selectable headings keep their role.
TEST_F(FlAccessibleNodeTest, NotSelectableText) {
  g_autoptr(FlAccessibleNode) label = fl_accessible_node_new(engine, 123, 1);
  fl_accessible_node_set_name(label, "Hello world");
  EXPECT_EQ(atk_object_get_role(ATK_OBJECT(label)), ATK_ROLE_PANEL);
  {
    flutter::testing::MockSignalHandler text_selection_changed(
        label, "text-selection-changed");
    EXPECT_SIGNAL(text_selection_changed).Times(0);
    update_selection(label, 0, 5);
  }
  EXPECT_EQ(atk_text_get_n_selections(ATK_TEXT(label)), 0);
  EXPECT_EQ(atk_text_get_caret_offset(ATK_TEXT(label)), -1);
  EXPECT_FALSE(atk_text_add_selection(ATK_TEXT(label), 0, 5));
  EXPECT_FALSE(atk_text_set_caret_offset(ATK_TEXT(label), 1));

  // A selectable heading keeps its role.
  g_autoptr(FlAccessibleNode) heading =
      create_selectable_text(engine, 2, "Title");
  FlutterSemanticsFlags flags = {};
  flags.is_header = true;
  fl_accessible_node_set_flags(heading, &flags);
  EXPECT_EQ(atk_object_get_role(ATK_OBJECT(heading)), ATK_ROLE_HEADING);
}

// Checks that when the selection of several nodes changes in one update, only
// the node holding the selection extent emits the AtkText signals.
TEST_F(FlAccessibleNodeTest, OnlyTheExtentNodeEmitsSelectionSignals) {
  g_autoptr(FlAccessibleNode) root = fl_accessible_node_new(engine, 123, 0);
  g_autoptr(FlAccessibleNode) first =
      create_selectable_text(engine, 1, "Hello world");
  g_autoptr(FlAccessibleNode) second =
      create_selectable_text(engine, 2, "Second line");
  fl_accessible_node_set_parent(first, ATK_OBJECT(root), 0);
  fl_accessible_node_set_parent(second, ATK_OBJECT(root), 1);
  g_autoptr(GPtrArray) children = g_ptr_array_new();
  g_ptr_array_add(children, first);
  g_ptr_array_add(children, second);
  fl_accessible_node_set_children(root, children);

  // The update lists the nodes in any order.
  g_autoptr(GPtrArray) nodes = g_ptr_array_new();
  g_ptr_array_add(nodes, second);
  g_ptr_array_add(nodes, first);

  // Forward: the extent is in the last node.
  {
    flutter::testing::MockSignalHandler first_changed(first,
                                                      "text-selection-changed");
    flutter::testing::MockSignalHandler second_changed(
        second, "text-selection-changed");
    EXPECT_SIGNAL(first_changed).Times(0);
    EXPECT_SIGNAL(second_changed);
    fl_accessible_node_set_text_selection(first, 6, 11);
    fl_accessible_node_set_text_selection(second, 0, 6);
    fl_accessible_node_emit_text_selection_changes(nodes);
  }
  EXPECT_EQ(atk_text_get_n_selections(ATK_TEXT(first)), 1);

  // Backward: the extent is in the first node.
  {
    flutter::testing::MockSignalHandler first_changed(first,
                                                      "text-selection-changed");
    flutter::testing::MockSignalHandler second_changed(
        second, "text-selection-changed");
    EXPECT_SIGNAL(first_changed);
    EXPECT_SIGNAL(second_changed).Times(0);
    fl_accessible_node_set_text_selection(first, 11, 6);
    fl_accessible_node_set_text_selection(second, 6, 0);
    fl_accessible_node_emit_text_selection_changes(nodes);
  }
}
