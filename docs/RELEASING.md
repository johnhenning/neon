# Preview releases

Neon currently distributes developer previews. The release workflow creates a draft;
a maintainer reviews it and publishes manually. It does not merge PRs, create production
signing credentials, notarize builds, or distribute to physical iOS devices.

## Versioning

`native/CMakeLists.txt` is the application version source. Both Apple bundle metadata
files use that project version. Use preview tags `v0.MINOR.PATCH-preview.N`, for example
`v0.3.0-preview.1`. Increase N for another preview of the same application version.
Release tags are immutable; never move a published tag to a different commit.

## Create a draft

1. Merge the intended changes through protected `main`.
2. Wait for a **Native Apple foundation** run triggered by that push to `main` to pass.
   All three required jobs must pass. A successful PR run is not eligible.
3. Open Actions → **Draft preview release** → Run workflow on `main`. Supply the tag and
   successful run ID. The tag's base version must match both packaged applications.
4. The workflow validates the run/repository/branch/event/jobs and nonexpired artifacts,
   downloads the exact packages, validates their bundle identity/version, and creates a
   draft prerelease with generated notes, checksums, and source provenance.
5. Review the draft's source SHA, CI evidence, known issues, package contents, and notes.
   Test downloads and verify checksums before publishing manually on GitHub.

The release workflow must first be merged into `main` to become dispatchable. The first
eligible source is a successful main push build after this setup lands. No preview is
published merely by merging the maintenance PR.

## Assets and evidence

| Asset | Meaning |
| --- | --- |
| `Neon.zip` | macOS application, ad-hoc signed and not notarized |
| `Neon-Simulator.zip` | iPhone/iPad Simulator application, not an IPA |
| `SHA256SUMS` | SHA-256 checksums for both packages |
| `provenance.json` | Exact source SHA, repository, CI run URL, and package hashes |

Screenshots, recordings, and XCTest results remain in the source run's separate evidence
artifacts and are subject to GitHub artifact retention. Checksums detect package changes;
they do not replace signing/notarization. Never describe Simulator tests as physical-device
validation or report-only job success as native acceptance.

If a workflow fails, inspect the failure before retrying. If a draft already exists, review
or remove that unpublished draft explicitly before reusing its version; the workflow does
not overwrite releases or tags. If source artifacts have expired, obtain a new successful
main build rather than substituting unrelated binaries.
