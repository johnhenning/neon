#include "neon/document.h"
#include <limits>
#include <set>
#include <string>
#include <utility>

namespace neon::core {
namespace {
bool validUTF8(const std::string& text) {
    for (std::size_t i = 0; i < text.size();) {
        const auto first = static_cast<unsigned char>(text[i++]);
        if (first < 0x80)
            continue;
        unsigned count = 0;
        std::uint32_t point = 0;
        if (first >= 0xc2 && first <= 0xdf) {
            count = 1;
            point = first & 0x1f;
        } else if (first >= 0xe0 && first <= 0xef) {
            count = 2;
            point = first & 0x0f;
        } else if (first >= 0xf0 && first <= 0xf4) {
            count = 3;
            point = first & 0x07;
        } else {
            return false;
        }
        const unsigned width = count;
        if (i + count > text.size())
            return false;
        while (count--) {
            const auto next = static_cast<unsigned char>(text[i++]);
            if ((next & 0xc0) != 0x80)
                return false;
            point = (point << 6) | (next & 0x3f);
        }
        if ((width == 2 && point < 0x800) || (width == 3 && point < 0x10000) ||
            (point >= 0xd800 && point <= 0xdfff) || point > 0x10ffff)
            return false;
    }
    return true;
}
} // namespace
Result validate(const Project& project) {
    if (project.schemaVersion != 1)
        return Result::failure("Unsupported project schema; do not overwrite this file.");
    std::set<std::string> ids;
    auto id = [&](const std::string& value) {
        return !value.empty() && validUTF8(value) && ids.insert(value).second;
    };
    if (!id(project.id) || !validUTF8(project.title))
        return Result::failure("Invalid project metadata.");
    for (const auto& document : project.documents) {
        if (!id(document.id) || !validUTF8(document.title))
            return Result::failure("Invalid or duplicate document identifier.");
        for (const auto& section : document.sections) {
            if (!id(section.id) || !validUTF8(section.title))
                return Result::failure("Invalid or duplicate section identifier.");
            for (const auto& block : section.blocks) {
                if (!id(block.id) || !validUTF8(block.text) || block.createdBy.empty() ||
                    block.lastEditedBy.empty() || !validUTF8(block.createdBy) ||
                    !validUTF8(block.lastEditedBy))
                    return Result::failure("Invalid text block or provenance.");
            }
        }
    }
    return Result::success();
}
Result replaceText(Project* project, const std::string& blockId, const std::string& text,
                   const std::string& actor) {
    if (!project || actor.empty() || !validUTF8(actor) || !validUTF8(text))
        return Result::failure("A valid project, text and local actor are required.");
    auto result = validate(*project);
    if (!result.ok)
        return result;
    for (auto& document : project->documents)
        for (auto& section : document.sections)
            for (auto& block : section.blocks)
                if (block.id == blockId) {
                    if (block.text == text)
                        return Result::success();
                    if (project->revision == std::numeric_limits<std::uint64_t>::max())
                        return Result::failure("Revision limit reached.");
                    block.text = text;
                    block.lastEditedBy = actor;
                    ++project->revision;
                    return Result::success();
                }
    return Result::failure("Text block does not exist.");
}
Result renameProject(Project* project, const std::string& title) {
    if (!project || title.empty() || !validUTF8(title))
        return Result::failure("A title is required.");
    if (project->title == title)
        return Result::success();
    if (project->revision == std::numeric_limits<std::uint64_t>::max())
        return Result::failure("Revision limit reached.");
    auto candidate = *project;
    candidate.title = title;
    auto result = validate(candidate);
    if (!result.ok)
        return result;
    ++candidate.revision;
    *project = std::move(candidate);
    return Result::success();
}
Result addSection(Project* project, const std::string& documentId, Section section) {
    if (!project || section.title.empty() || section.blocks.empty())
        return Result::failure("A section needs a title and content block.");
    if (project->revision == std::numeric_limits<std::uint64_t>::max())
        return Result::failure("Revision limit reached.");
    auto candidate = *project;
    for (auto& document : candidate.documents) {
        if (document.id != documentId)
            continue;
        document.sections.push_back(std::move(section));
        auto result = validate(candidate);
        if (!result.ok)
            return result;
        ++candidate.revision;
        *project = std::move(candidate);
        return Result::success();
    }
    return Result::failure("Document does not exist.");
}
} // namespace neon::core
