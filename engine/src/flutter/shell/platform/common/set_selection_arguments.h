// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef FLUTTER_SHELL_PLATFORM_COMMON_SET_SELECTION_ARGUMENTS_H_
#define FLUTTER_SHELL_PLATFORM_COMMON_SET_SELECTION_ARGUMENTS_H_

#include <cstdint>

#include "flutter/fml/mapping.h"

namespace flutter {

//------------------------------------------------------------------------------
/// @brief      Encodes the arguments of kFlutterSemanticsActionSetSelection,
///             the map {"base": base, "extent": extent}, as the framework's
///             StandardMessageCodec decodes them.
///
///             The accessibility bridge does not depend on the client wrapper
///             that holds the full codec, so this writes the few bytes the
///             action needs.
fml::MallocMapping EncodeSetSelectionArguments(int32_t base, int32_t extent);

}  // namespace flutter

#endif  // FLUTTER_SHELL_PLATFORM_COMMON_SET_SELECTION_ARGUMENTS_H_
