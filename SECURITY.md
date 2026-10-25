# Security policy

Neon is a developer preview, not a production-supported release. Security fixes are
made on current `main`; historical previews do not receive a guaranteed backport or
response-time commitment.

## Report a vulnerability

Use [GitHub private vulnerability reporting](https://github.com/johnhenning/neon/security/advisories/new).
Include the affected commit/version, platform, reproduction steps, and expected impact.
Use a minimal synthetic document when possible. Do not disclose a vulnerability,
private manuscript, access token, or personal data in a public issue.

For ordinary defects without a security impact, use the public bug-report template.

## Scope

Document parsing and migration, asset/file access, persistence integrity, release
artifacts, and CI credential boundaries are security-sensitive areas. Preview packages
are ad-hoc signed or Simulator-only; they are not notarized production distributions.
Secret scanning and push protection are enabled. Actions default to read-only tokens;
write access is granted only to jobs that need it.
