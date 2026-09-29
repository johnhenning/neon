#include "neon/document.h"
#include "neon/presets.h"
#include <cstdlib>
#include <iostream>
#include <limits>

void check(bool value, const char* message) {
    if (!value) {
        std::cerr << message << '\n';
        std::exit(1);
    }
}
int main() {
    using neon::core::Project;
    using neon::core::replaceText;
    using neon::core::validate;
    Project project{1,
                    0,
                    "project",
                    "Essay",
                    {{"document",
                      "Draft",
                      {{"section", "Opening", {{"block", "Original", "author", "author"}}}}}}};
    check(validate(project).ok, "valid non-book project");
    auto& block = project.documents[0].sections[0].blocks[0];
    check(replaceText(&project, "block", "Unicode: café 👩🏽‍💻 العربية", "editor")
              .ok,
          "unicode replacement");
    check(project.revision == 1 && block.createdBy == "author" && block.lastEditedBy == "editor",
          "creator survives edits by a different actor");
    check(replaceText(&project, "block", block.text, "third").ok && project.revision == 1 &&
              block.lastEditedBy == "editor",
          "no-op preserves attribution");
    check(!replaceText(&project, "missing", "bad", "editor").ok && project.revision == 1,
          "missing target is atomic");
    check(!replaceText(&project, "block", "bad", "").ok, "actor required");
    check(!replaceText(&project, "block", "\xed\xa0\x80", "editor").ok, "reject surrogate UTF-8");
    check(!replaceText(&project, "block", "\xf0\x80\x80\x80", "editor").ok,
          "reject overlong UTF-8");
    project.documents[0].sections[0].blocks.push_back(block);
    check(!validate(project).ok, "duplicate block identity rejected");
    project.documents[0].sections[0].blocks.pop_back();
    auto before = project.revision;
    check(!neon::core::addSection(&project, "document",
                                  {"section", "Duplicate", {{"new", "", "author", "author"}}})
                  .ok &&
              project.revision == before,
          "duplicate structural edit rejected atomically");
    check(neon::core::addSection(&project, "document",
                                 {"section2", "Next", {{"new", "", "author", "author"}}})
              .ok,
          "append ordered section");
    check(project.documents[0].sections.size() == 2 &&
              project.documents[0].sections[0].id == "section",
          "order preserved");
    check(neon::core::renameSection(&project, "section2", "Renamed").ok, "rename section");
    check(neon::core::moveSection(&project, "section2", -1).ok &&
              project.documents[0].sections[0].id == "section2",
          "move preserves identity");
    before = project.revision;
    check(!neon::core::moveSection(&project, "section2", -1).ok && project.revision == before,
          "edge move atomic");
    check(neon::core::trashSection(&project, "section2", true).ok &&
              project.documents[0].sections[0].trashed,
          "trash preserves content");
    check(neon::core::trashSection(&project, "section2", false).ok &&
              project.documents[0].sections[0].title == "Renamed",
          "restore title");
    auto original = project;
    auto revision = project.revision;
    project.title = "Current draft";
    project.preset = "research";
    check(neon::core::restoreProject(&project, original).ok && project.title == original.title &&
              project.revision == revision + 1 && project.schemaVersion == 3 &&
              project.preset == "book",
          "restore creates new revision and restores preset");
    original.id = "another-project";
    check(!neon::core::restoreProject(&project, original).ok && project.revision == revision + 1,
          "foreign restore is atomic");
    for (const auto& preset : neon::core::writingPresets()) {
        check(!preset.sections.empty() && !preset.sectionLabel.empty(), "usable preset");
        for (const auto& section : preset.sections)
            check(!section.role.empty() && !section.guidance.empty(),
                  "semantic role and workflow guidance");
    }
    check(neon::core::writingPreset("research")->sections.front().role == "abstract" &&
              neon::core::writingPreset("research")->sections.back().role == "references" &&
              neon::core::writingPreset("newsletter")->sectionLabel == "Section" &&
              !neon::core::writingPreset("unknown"),
          "use-case specific catalog");
    project.schemaVersion = 4;
    check(!replaceText(&project, "block", "bad", "editor").ok, "future schema read-only");
    project.schemaVersion = 1;
    project.revision = std::numeric_limits<std::uint64_t>::max();
    check(!replaceText(&project, "block", "overflow", "editor").ok, "revision overflow rejected");
    std::cout << "Semantic document scenarios passed\n";
}
