# Neon native prototype

- This is the separate native AppKit prototype. Preserve the Qt reference branch and PR.
- C++23 portable core must not import Qt, Foundation, AppKit, filesystem locations or native rendering objects.
- Put persistence codecs, paths, permissions and atomic file operations in platform adapters implementing the core repository contract.
- AppKit owns input, typography, accessibility and view rendering. Layer-backed views permit Core Animation compositing; do not claim all text layout runs on the GPU.
- Preserve manuscripts. Prototype storage is isolated from Neo and the Qt preview. Do not load existing libraries without a validated migration adapter.
- Run native/scripts/quality.py before every commit and in CI; missing quality tools must fail.
- Run portable core tests and macOS UI/persistence smoke before claiming a working native build. No performance claims without matched measurements.
- Keep native UI/core boundaries testable. Opaque RTF is prototype-only; a portable semantic rich-text model remains work.
