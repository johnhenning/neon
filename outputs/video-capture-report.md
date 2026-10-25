# Preview recording investigation

Inspected downloaded original GitHub artifacts with ffprobe, decoded sampled frames with ffmpeg, and visually opened extracted frames. No synthetic footage substituted for app recordings.

## Evidence

- Run 36958331962, `Neon-iOS-Evidence-Recordings/iPhone/iPhone-walkthrough.mp4`: H264, 442×960, 219.083s. At 30s the simulator home screen is visible. Motion sample: 180 frames at 1fps, 8 changed transitions (mean grayscale pixel change threshold 1/255). This was long setup/teardown footage surrounding an unsuccessful journey, not a frozen player.
- Same artifact, `iPhone/attachments/6DF61408-96E2-44F6-8CB2-3486A7C365AC.mp4`: XCTest recording, H264, 1206×2622, 33.982s; 34 samples, 8 changed transitions. At 10s blank launching app; at 25s actual Neon manuscript editor (`The Quiet Sea`, `Opening`). This is the truthful shorter test session. It still does not prove the journey passed.
- Same run, `iPad/iPad-walkthrough.mp4`: H264, 720×960, 143.542s; 144 samples, 20 changed transitions. No XCTest MP4 exported in that artifact, so simulator fallback remains necessary.
- Run 40234462731, `Neon-macOS-Evidence-Recordings/walkthrough/macOS-walkthrough.mp4`: H264, 960×720, 1.792s; 2 samples, 1 changed transition. Too short to establish multiple visual changes; new validation rejects it.
- Run 40234840980, same artifact path: H264, 960×720, 11.750s; 12 samples, 3 changed transitions. At 3s real Neon Library is visible. `result.json` explicitly reports failed UI test and `video_complete=false`. It is partial footage of an early failure, not a working full journey.
- Run 40234104579 iOS recording artifact was unavailable during this investigation; no current iOS completion claim made.

## Changes

Prefer the single XCTest system recording on iOS as on macOS, retaining system attachments on success. This bounds preview footage to the genuine test session and avoids long simulator setup/teardown holds. Keep simulator recording as explicitly identified fallback when no XCTest attachment exists. Multiple XCTest movies are an ambiguity and fail export instead of choosing an arbitrary session.

Decode sampled output and persist `recording_status` and `media_validation`. Reject invalid/unreadable movies and movies with fewer than two meaningful frame transitions. Keep `ui_status` independent, and mark videos complete only when both the UI journey and recording validation pass. Motion validation proves decodable visual changes, not app identity or usable controls. Publisher must retain partial/failed labels.

## Validation and limits

Three real ffmpeg regression tests passed: frozen clip rejection, moving clip acceptance, malformed movie rejection. Python compile and git diff checks passed. `native/scripts/quality.py` passed with `/private/tmp/neon-quality-env/bin` on PATH.

Full Xcode/Apple UI execution is unavailable locally (CLT only). A fresh Apple CI run is required to prove successful recording selection, end-to-end interaction, and final published preview. Motion samples inspect at most the first 180 seconds and cannot distinguish an unrelated animated surface; combine with XCTest outcome and visual evidence. Existing raw MOVs remain diagnostic evidence; publish one validated MP4 per platform.

Follow-up integration review removed the pre-export requirement for an iOS simulator MOV. A failed fallback recorder startup now records a diagnostic and still runs XCTest; the preferred XCTest attachment determines recording validity. Added a mocked full-driver orchestration regression: successful XCTest, failed simulator recorder/no MOV, and validated XCTest attachment yields passed UI, passed recording, and complete video. This test and native quality checks pass.

CI47 iPad logs reached the final Done action at 119.82 seconds, then exceeded XCTest's default two-minute allowance while reporting a 123.351-second passed test; the job was subsequently cancelled during cleanup. The driver now allows 180 seconds by default, capped at 240 seconds for the complete multi-step journey. Individual control waits and assertions remain unchanged. The orchestration test checks these bounded timeout settings.
