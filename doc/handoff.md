# Handoff: where Chanda is (2026-11-11)

Notes for picking the work up in a new session, possibly on another computer.

## State

- Version 0.3.1 on `main`. Phases 1–3 of the plan are built.
  - Phase 1: vault, price history, confirmed drop alerts, in-app browser.
  - Phase 2: search across the vault and shops, query chips, matching the same product at other
    shops, best-deal comparison, optional smarter search model, Read with AI (user's own key).
  - Phase 3: built-in text recognition (PP-OCRv5) on every platform; search by photo (optional
    picture model, 94 MB); star ratings and a taste model behind *For you*; *Shops like yours*
    with shop checks and *Add to my search*.
- Releases: 0.3.1 is published as a pre-release (all jobs passed: tests, Android, Windows, Linux,
  Linux start on Ubuntu, Fedora and Arch, Android emulator start). Assets: three APKs (arm64-v8a,
  armeabi-v7a, x86_64), Windows setup and portable zip, Linux tarball, `SHA256SUMS.txt`.
- Tags `v0.2.0` and `v0.3.0` exist without releases: their Linux smoke tests failed because the
  bundle lacked `libonnxruntime.so.1` (fixed in 0.3.1, `linux/CMakeLists.txt`). 0.3.1 supersedes both.
- CI: format, analyze, test on every push. Release: push a `v*` tag; Android signing secrets are set.
- 118 tests pass; `flutter analyze` is clean.

## Not verified yet

- Windows on a real machine (CI builds and smoke-starts it).
- A real Android phone: screen price reading, search by photo, sharing a photo to Chanda.
- Look-alike thresholds with the real picture model (`lib/domain/picture_index.dart`, floor 0.55).

## Next

1. Phase 4 (0.4.0): virtual try-on. Research first, then ask for approval before building.
   - Saved people (base photo, face photo, measurements, pupillary distance), on the device only,
     encrypted, explicit consent, never synced unless the user opts in.
   - Glasses: face landmarks, iris-based true scale, frame width from the listing, 2D overlay.
   - Clothing offline: garment cut-out, pose-based warp, composite; size-fit note.
   - Optional realistic mode on desktop or a home server; optional cloud try-on with the user's own
     key, with a clear notice that the photo leaves the device.
2. Phase 5: screenshots from demo data and the stable release.

## Rules that hold

- Never work around a shop's bot checks: no user-agent swaps, CAPTCHA solving, fingerprint spoofing
  or proxies. A blocked shop opens in the in-app browser with the user there.
- Checkout only in the in-app browser. Never store card details; never read or send sign-in or
  payment pages.
- No taste features from age or gender.
- Public text names no third-party brands except platforms Chanda integrates with.
- `test/live_pages/` and keystores are never committed. Run a leak scan before every push.
- Commit messages end with `Co-Authored-By: Claude Code <noreply@anthropic.com>`.
- READMEs are plain language, step by step.
- Market research and the full plan live outside this repo, on the original computer.

## Build

```
flutter pub get
flutter analyze
flutter test
dart format -l 110 lib test integration_test
```

Linux needs WPE WebKit 2.52+ for the in-app browser. Android builds need JDK 17.
