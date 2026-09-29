# Recorded Apple UI evidence

The Apple workflow runs a separate XCTest walkthrough against the exact CMake-built
Neon.app, using accessibility clicks/taps and typing. `--ui-testing` seeds an
isolated fixture library and does not run internal smoke actions. No user library
is read or modified. XcodeGen generates a disposable test runner; its placeholder
host exists only to satisfy Xcode's build graph and is never launched.

Current assertions cover opening a project, chapter changes, typing and reading
back saved text after navigation, history/settings presentation, and Mac sidebar
collapse/expansion. These do not constitute complete app acceptance. Renaming,
trash/restore, preset selection and cross-process persistence still have internal
smoke coverage, but are not yet all part of the recorded XCTest journey.

Mac uses screencapture video with the cursor; iPhone/iPad use simctl recordVideo.
The UI runner emits named screenshot attachments and XCTest action logs. Touch
indicators are not currently overlaid on mobile video. A recorder or UI assertion
failure fails the walkthrough and is reported, retaining available failure evidence.
Both mobile families are attempted even if the first fails.

Each platform's build independently starts apple-report.yml, including on failure.
GitHub Copilot CLI reviews the evidence using the built-in GITHUB_TOKEN with
copilot-requests: write. No OpenAI API key or separate AI provider secret is used.
GitHub bills personally owned repositories to the owner's Copilot entitlement;
Copilot access and available quota are required. Review failure still produces a
deterministic report and explicitly says that Copilot review was unavailable.
The review job allows file reads, denies shell commands, writes and URL tools,
and disables built-in MCPs and repository instructions. It has no PR write token
or attachment secret. A separate publisher posts reports for same-repository PRs;
fork builds never receive secrets or write permissions through this workflow.

Original screenshots, videos and full XCTest result bundles stay in Actions
artifacts and expire under repository retention policy. PR comments link to the
artifacts and list screenshot filenames. Configure NEON_ATTACHMENT_TOKEN as a
repository secret containing a supported GitHub user token with repository write
access to enable inline previews. GitHub CLI uploads selected captures downloaded
from the artifacts as native comment attachments (not artifact URLs embedded as
images). The automatic GITHUB_TOKEN cannot upload these attachments. Files over
9 MB retain artifact links; no original is discarded. Failed or missing attachment
credentials fall back to a bot comment with artifact links and an explicit notice.
No screenshot branches or repository-content write permissions are needed.
Each platform replaces its own previous attachment comment by the same author,
with head-SHA and run-order checks. Bot fallback comments are updated in place.
Workflow-dispatch builds retain evidence but do not post to an inferred PR.

Run locally (requires Xcode and XcodeGen):

```
python3 native/scripts/ui_walkthrough.py macOS build-native/Neon.app build-native/walkthrough
python3 native/scripts/ui_walkthrough.py iPad build-ios/Debug-iphonesimulator/Neon.app build-ios/evidence/iPad --device SIMULATOR_UDID
```

Screen recording / accessibility permissions may need to be granted interactively
on a developer Mac. CI runs must produce actual video; missing permission is a
failure, not a successful empty recording.
