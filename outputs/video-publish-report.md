# Recording publication repair

PR 7 comments were inspected through the GitHub connector. Existing comments already render real `<video controls>` elements: the CLI correctly rewrites standalone image references into player URLs. The latest Mac report documents an approximately 11.7-second failed XCTest capture, while the older iPhone report documents an incomplete recording. The evidence points to capture/content failures, not absent player controls.

Publisher changes:

- UI verdict uses `ui_status`, independently of recording outcome.
- Exactly one preferred MP4 per family is eligible for inline publication; raw MOV duplicates remain artifact-only.
- Inline eligibility requires passed recording validation, positive dimensions/duration, multiple sampled frames and detected visual changes, plus a nonempty local MP4.
- Failed/unverified recordings remain artifact-linked and are labeled accordingly. Validated captures from incomplete/failed UI tests are explicitly labeled partial.
- Video references use the documented standalone `![](local.mp4)` form; screenshots retain image syntax. GitHub CLI rewrites the entire standalone video reference to a player URL.
- Existing current-SHA checks, run ordering and per-platform author identity separation remain intact.

Validation: `node native/scripts/test_publish_report.cjs` passes, covering missing media, stale reports, UI/recording status separation, video paragraph markup, duplicate MOV exclusion, partial labels, failed/unvalidated media exclusion, and attachment failure fallback. `PATH=/private/tmp/neon-quality-env/bin:$PATH /private/tmp/neon-quality-env/bin/python native/scripts/quality.py` passes with the pinned tool environment. No push or comment publication was performed.

Official CLI rendering contract: https://docs.github.com/en/github-cli/github-cli/attaching-files-with-github-cli
