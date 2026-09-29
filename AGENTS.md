# Neon development

- C++23 and Qt Quick/QML. macOS desktop feature parity is the first release goal; other platforms follow.
- No Electron, Chromium, web views, or JavaScript application backend. QML presentation expressions are allowed.
- Preserve user manuscripts. Never silently discard unknown Neo markup or metadata. Save failures must remain visible.
- Keep Qt documents on their owner thread. Workers receive snapshots only.
- Validate storage, structural undo, and format conversion with meaningful tests. Keep docs/parity.md honest: implemented is not the same as independently validated.
- Run CMake/CTest and the QML smoke check before claiming a working build. macOS CI produces an unsigned preview, not a notarized public release.
- No claims of performance gains without matched benchmarks.
