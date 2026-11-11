# Handoff: where Chanda is (2026-11-11)

Notes for picking the work up in a new session, possibly on another computer.

## State

- Version 0.4.0+5 on `main`, committed locally, not yet tagged or released. Phases 1–4 of the plan
  are built.
  - Phase 1: vault, price history, confirmed drop alerts, in-app browser.
  - Phase 2: search across the vault and shops, query chips, matching the same product at other
    shops, best-deal comparison, optional smarter search model, Read with AI (user's own key).
  - Phase 3: built-in text recognition (PP-OCRv5) on every platform; search by photo (optional
    picture model, 94 MB); star ratings and a taste model behind *For you*; *Shops like yours*
    with shop checks and *Add to my search*.
  - Phase 4: try-on. Saved people (face and body photos, sizes, pupil distance; local only, never
    synced, consent first). Glasses at real size from the iris or typed PD (`glasses_fit.dart`,
    `frame_size.dart`). Clothes (tops, dresses, skirts; trousers say "not yet") drawn on the body
    photo: BlazePose body points (`pose_fit.dart`), multiclass segmenter parts (`body_mask.dart`),
    garment cut-out and shape reading and the fit (`garment_fit.dart`), wired in `clothes_fit.dart`.
    Garments are only ever widened; the result is re-segmented and refused if the outline at the
    shoulders, waist or hips shrank more than 3% (`maxOutlineShrink`). Size note from JSON-LD
    SizeSpecification or size tables (`size_chart.dart`). AI try-on with the user's own key
    (`cloud_tryon.dart`: FASHN, fal with no-store, Gemini on paid keys only), consent per service tied
    to terms, model, plan and key hash; the result goes through paste-back and the same outline check.
- Releases: 0.3.1 is published as a pre-release (all jobs passed: tests, Android, Windows, Linux,
  Linux start on Ubuntu, Fedora and Arch, Android emulator start). Assets: three APKs (arm64-v8a,
  armeabi-v7a, x86_64), Windows setup and portable zip, Linux tarball, `SHA256SUMS.txt`.
- Tags `v0.2.0` and `v0.3.0` exist without releases: their Linux smoke tests failed because the
  bundle lacked `libonnxruntime.so.1` (fixed in 0.3.1, `linux/CMakeLists.txt`). 0.3.1 supersedes both.
- CI: format, analyze, test on every push. Release: push a `v*` tag; Android signing secrets are set.
- 184 tests pass; `flutter analyze` is clean. Integration tests with the real try-on models:
  `integration_test/tryon_test.dart` (face, cut-out) and `integration_test/clothes_test.dart` (body
  points and segmenter against `test/fixtures/pose_reference.json`, a full clothes fit, refusals).

## Not verified yet

- Windows on a real machine (CI builds and smoke-starts it).
- A real Android phone: screen price reading, search by photo, sharing a photo to Chanda.
- Look-alike thresholds with the real picture model (`lib/domain/picture_index.dart`, floor 0.55).
- Try-on on Android and Windows (only Linux has run the real models). Clothes were checked on two
  stock photos with drawn garments; real shop pictures vary more.
- The cloud try-on services were never called for real (fake HTTP clients only); their request and
  answer shapes follow their public docs as of 2026-11.
- Known clothes limits: objects in front of the body are drawn over; a loose shirt on the body photo
  makes the garment wide; long sleeves hung down the sides read as sleeveless; no relighting.

## Next

1. Release 0.4.0 after approval: security gate (Dependabot, audit), leak scan, push, tag `v0.4.0`.
2. Trousers and shorts on the body photo (legs warp), and the optional realistic mode on a home
   server.
3. Phase 5: screenshots from demo data and the stable release.

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
