#pragma once
#include "neon/workspace.h"
#include <memory>
#include <string>

namespace neon::mac {
// The path and Foundation serialization are owned entirely by this adapter.
std::unique_ptr<core::LibraryRepository> makeRepository(const std::string& directory);
} // namespace neon::mac
