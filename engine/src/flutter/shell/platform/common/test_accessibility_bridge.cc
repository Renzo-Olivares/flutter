// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "test_accessibility_bridge.h"

namespace flutter {

std::shared_ptr<FlutterPlatformNodeDelegate>
TestAccessibilityBridge::CreateFlutterPlatformNodeDelegate() {
  return std::make_unique<FlutterPlatformNodeDelegate>();
};

void TestAccessibilityBridge::OnAccessibilityEvent(
    ui::AXEventGenerator::TargetedEvent targeted_event) {
  accessibility_events.push_back(targeted_event.event_params.event);
}

void TestAccessibilityBridge::DispatchAccessibilityAction(
    AccessibilityNodeId target,
    FlutterSemanticsAction action,
    fml::MallocMapping data) {
  performed_actions.push_back(action);
  performed_action_targets.push_back(target);
  performed_action_data.emplace_back(data.GetMapping(),
                                     data.GetMapping() + data.GetSize());
}

}  // namespace flutter
