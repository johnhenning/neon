#include "neon/document.h"
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
    project.schemaVersion = 2;
    check(!replaceText(&project, "block", "bad", "editor").ok, "future schema read-only");
    project.schemaVersion = 1;
    project.revision = std::numeric_limits<std::uint64_t>::max();
    check(!replaceText(&project, "block", "overflow", "editor").ok, "revision overflow rejected");
    std::cout << "Semantic document scenarios passed\n";
}
