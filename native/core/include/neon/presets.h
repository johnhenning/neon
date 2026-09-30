#pragma once
#include <string>
#include <vector>

namespace neon::core {
struct SectionTemplate {
    std::string role;
    std::string title;
    std::string guidance;
};
struct WritingPreset {
    std::string id;
    std::string title;
    std::string documentLabel;
    std::string sectionLabel;
    std::string sectionsLabel;
    std::string description;
    std::string font;
    double lineHeightMultiple;
    double paragraphSpacing;
    double firstLineIndent;
    bool centeredHeading;
    bool numberedSections;
    std::vector<SectionTemplate> sections;
};
const std::vector<WritingPreset>& writingPresets();
const WritingPreset* writingPreset(const std::string& id);
} // namespace neon::core
