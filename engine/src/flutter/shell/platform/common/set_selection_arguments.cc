// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "flutter/shell/platform/common/set_selection_arguments.h"

#include <cstring>
#include <string_view>
#include <vector>

#include "flutter/fml/logging.h"

namespace flutter {

namespace {

// Type tags of the StandardMessageCodec wire format.
constexpr uint8_t kValueInt32 = 3;
constexpr uint8_t kValueString = 7;
constexpr uint8_t kValueMap = 13;

// Sizes below 254 are written as a single byte.
void WriteString(std::vector<uint8_t>& buffer, std::string_view value) {
  FML_DCHECK(value.size() < 254);
  buffer.push_back(kValueString);
  buffer.push_back(static_cast<uint8_t>(value.size()));
  buffer.insert(buffer.end(), value.begin(), value.end());
}

// Integers are written in host byte order, as the codec does.
void WriteInt32(std::vector<uint8_t>& buffer, int32_t value) {
  buffer.push_back(kValueInt32);
  uint8_t bytes[sizeof(value)];
  std::memcpy(bytes, &value, sizeof(value));
  buffer.insert(buffer.end(), bytes, bytes + sizeof(value));
}

}  // namespace

fml::MallocMapping EncodeSetSelectionArguments(int32_t base, int32_t extent) {
  std::vector<uint8_t> buffer;
  buffer.push_back(kValueMap);
  buffer.push_back(2);
  WriteString(buffer, "base");
  WriteInt32(buffer, base);
  WriteString(buffer, "extent");
  WriteInt32(buffer, extent);
  return fml::MallocMapping::Copy(buffer.data(), buffer.size());
}

}  // namespace flutter
