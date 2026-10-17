// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "flutter/shell/platform/common/set_selection_arguments.h"

#include <vector>

#include "flutter/shell/platform/common/client_wrapper/include/flutter/standard_message_codec.h"
#include "gtest/gtest.h"

namespace flutter {
namespace testing {

namespace {

std::vector<uint8_t> ToVector(const fml::MallocMapping& mapping) {
  return std::vector<uint8_t>(mapping.GetMapping(),
                              mapping.GetMapping() + mapping.GetSize());
}

}  // namespace

// The expected bytes are written by hand from the StandardMessageCodec wire
// format and match the framework's
// `const StandardMessageCodec().encodeMessage(<String, int>{'base': 2,
// 'extent': 5})`.
TEST(SetSelectionArgumentsTest, MatchesStandardMessageCodecBytes) {
  std::vector<uint8_t> expected = {
      13, 2,                                // map, two entries
      7,  4, 'b', 'a', 's', 'e',            // string "base"
      3,  2, 0,   0,   0,                   // int32 2
      7,  6, 'e', 'x', 't', 'e', 'n', 't',  // string "extent"
      3,  5, 0,   0,   0,                   // int32 5
  };
  EXPECT_EQ(ToVector(EncodeSetSelectionArguments(2, 5)), expected);
}

TEST(SetSelectionArgumentsTest, EncodesNegativeOffsets) {
  std::vector<uint8_t> expected = {
      13, 2, 7,   4,   'b', 'a', 's', 'e', 3, 0xff, 0xff, 0xff, 0xff,
      7,  6, 'e', 'x', 't', 'e', 'n', 't', 3, 0xff, 0xff, 0xff, 0xff,
  };
  EXPECT_EQ(ToVector(EncodeSetSelectionArguments(-1, -1)), expected);
}

TEST(SetSelectionArgumentsTest, DecodesWithStandardMessageCodec) {
  fml::MallocMapping encoded = EncodeSetSelectionArguments(70000, 3);
  std::unique_ptr<EncodableValue> decoded =
      StandardMessageCodec::GetInstance().DecodeMessage(encoded.GetMapping(),
                                                        encoded.GetSize());
  ASSERT_NE(decoded, nullptr);
  const EncodableMap& map = std::get<EncodableMap>(*decoded);
  ASSERT_EQ(map.size(), size_t{2});
  EXPECT_EQ(std::get<int32_t>(map.at(EncodableValue("base"))), 70000);
  EXPECT_EQ(std::get<int32_t>(map.at(EncodableValue("extent"))), 3);

  std::unique_ptr<std::vector<uint8_t>> reencoded =
      StandardMessageCodec::GetInstance().EncodeMessage(*decoded);
  EXPECT_EQ(*reencoded, ToVector(encoded));
}

}  // namespace testing
}  // namespace flutter
