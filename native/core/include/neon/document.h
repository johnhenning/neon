#pragma once
#include "neon/workspace.h"
#include <cstdint>
#include <string>
#include <vector>

namespace neon::core {
// First semantic slice: ordered plain-text blocks. No platform rich-text payloads.
struct TextBlock {
    std::string id;
    std::string text;
    std::string createdBy;
    std::string lastEditedBy;
};
struct Section {
    std::string id;
    std::string title;
    std::vector<TextBlock> blocks;
};
struct Document {
    std::string id;
    std::string title;
    std::vector<Section> sections;
};
struct Project {
    std::uint32_t schemaVersion = 1;
    std::uint64_t revision = 0;
    std::string id;
    std::string title;
    std::vector<Document> documents;
};
// IDs are project-wide unique. Vector order is semantic reading order.
Result validate(const Project& project);
// Whole-block UTF-8 replacement avoids mixing UIKit UTF-16 offsets with core offsets.
// No-op edits do not advance revision. Failed commands leave the project untouched.
Result replaceText(Project* project, const std::string& blockId, const std::string& text,
                   const std::string& actor);
} // namespace neon::core
