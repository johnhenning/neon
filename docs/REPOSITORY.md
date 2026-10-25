# Repository maintenance

## Protected main

- Pull requests are required, including for administrators.
- Required checks: `portable-core`, `macos-native`, and `ios-native`, from GitHub Actions.
- Branches must be up to date before merging; conversations must be resolved.
- Force pushes and branch deletion are blocked; linear history and squash merges are used.
- Merged branches are deleted automatically.
- Required approving reviews: zero while there is only one maintainer. Revisit this when
  another maintainer joins. Dismiss stale reviews; do not treat reporting jobs as test gates.

Release tags matching `v*` cannot be updated or deleted. Create a new preview version to
correct a release. Keep repository visibility, collaborator access, and signing credentials
separate from routine maintenance changes.

## Automation

Actions default to read access and cannot approve PRs. Third-party actions are pinned
by full commit SHA. Dependabot checks Action updates weekly and security fixes are enabled.
Secret scanning and push protection remain enabled. Native CI runs on PRs and pushes to
`main`; obsolete PR runs are cancelled, while main-branch runs are retained for release provenance.

The draft-release workflow uses explicit dispatch, verified successful main CI, version
validation, and checksums. It never publishes automatically. See [RELEASING.md](RELEASING.md).

Repository settings are administered on GitHub; changing this document alone does not
change protection. After updates, verify the live branch rules, required-check names,
Actions permissions, and security settings. This document describes the intended policy.
