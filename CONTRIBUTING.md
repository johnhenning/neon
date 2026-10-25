# Contributing to Neon

Neon is a developer preview. Keep changes focused and describe observable behavior,
including limitations. Use an issue for a substantial feature or architecture proposal.
Never attach private manuscripts, credentials, or personal library data.

## Development

Follow the [README](README.md) for setup and [AGENTS.md](AGENTS.md) for repository
constraints. Keep the portable C++23 core independent of platform frameworks; Apple
adapters own storage and native views own input and rendering. Preserve stable IDs,
existing manuscripts, migration backups, native undo, and stale-write protection.

Create a branch from current `main` and open a pull request. The main branch requires
passing `portable-core`, `macos-native`, and `ios-native` checks against an up-to-date
base, plus resolved conversations. Squash merging is enabled. A sole maintainer can
merge without a second human reviewer; this does not waive CI.

## Validation

Before committing, run `python native/scripts/quality.py` with the pinned tools.
For native changes, build and run CTest, then the relevant recorded Apple journeys.
See [UI test guidance](native/uitests/README.md). Core-only tests do not demonstrate
that native input, layout, or persistence work. UI changes should include screenshots
or recordings with the source revision and device/viewport identified.

For release-tool changes, run:

```sh
python3 -m unittest discover -s .github/scripts -p 'test_*.py'
```

State exactly what was tested and where. Missing tools, unavailable devices, skipped
checks, and incomplete coverage should remain explicit. Use disposable fixtures for
failure injection and data-loss tests.

## Dependencies and licensing

Pin GitHub Actions to full commit SHAs; Dependabot proposes weekly updates. Review
new runtime dependencies for platform compatibility and licensing. Preserve all font
and third-party notices. Do not introduce a new project license or signing identity
as part of an unrelated change.
