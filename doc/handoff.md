# Handoff: where Chanda is (2026-11-11)

Notes for picking the work up in a new session, possibly on another computer.

## State

- Version 0.5.0+6 on `main`, committed locally, not yet tagged or released. Phases 1–4 and 4b of
  the plan are built.
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
- 238 tests pass; `flutter analyze` is clean. Integration tests with the real try-on models:
  `integration_test/tryon_test.dart` (face, cut-out) and `integration_test/clothes_test.dart` (body
  points and segmenter against `test/fixtures/pose_reference.json`, a full clothes fit, refusals).

- Phase 4b (0.5.0+6, committed locally, not tagged or released): search stays in the app.
  - Part A: ranking by attributes (`attributes.dart`, `assets/search/attributes.json`, built by
    `tool/attribute_lexicon.py`; `rankScored` in `offers.dart`), reader fixes (`offerScript`,
    `parseOffers`, `isWallAddress`), live panels in Search (`lib/ui/shop_panels.dart`,
    `panel_script.dart`), OCR fallback (`screen_tiles.dart`), shops' own product search over HTTP
    (`shop_api.dart`), eBay with the user's keys (`ebay_api.dart`, Settings), `AppSearcher` picks the
    way per shop. Live check: `integration_test/search_live_test.dart`.
  - Part B: Linux engine A. The vendored WPE plugin links the system's WPE WebKit 2.52+ and no longer
    bundles it (`FLUTTER_INAPPWEBVIEW_LINUX_BUNDLE_WPE`, off). Release job `linux-wpe` builds
    `Chanda-<v>-linux-x64-wpe.tar.gz` in `archlinux:latest`, `linux-wpe-smoke` starts it there under
    xvfb; both go into `SHA256SUMS.txt`. The Ubuntu tarball without the in-app browser stays
    (`scripts/linux-tarball.sh` makes both). `packaging/aur/chanda-bin/` has a PKGBUILD and .SRCINFO,
    test-built with makepkg, **not published**. The plugin now ends a view's web process on dispose,
    and claims the mouse wheel (plugin README, changes 7 and 8). *Sharper ranking* (`reranker.dart`,
    Settings, off by default). Exchange rates are injectable (`fxClientProvider`), so tests stay off
    the network. CI pinned to `ubuntu-24.04` with `.github/apt-install.sh` (fails fast).

### Phase 4b part B results (2026-11-11, this laptop: Omarchy, WPE WebKit 2.54.1)

- `flutter test`: 238 pass; `flutter analyze` clean; `dart format -l 110` clean.
- Builds: `-wpe` release bundle 73 MB (tarball about 36 MB), links `/usr/lib/libWPEWebKit-2.0.so.1`.
  The plain variant (with `packages/no_linux_webview`, as CI makes it) is 71 MB, no web view plugin,
  tarball about 36 MB. The `-wpe` build ran in a nested X window for the input checks below. The
  final builds were not started: this laptop has no headless X server (Xvfb is not installed) and
  test windows must not open on the desktop. CI's `linux-smoke` and `linux-wpe-smoke` jobs start
  both under xvfb.
- Hidden searches on WPE (`integration_test/panel_live_test.dart`, scratch XDG): amazon-uk 48 tiles
  (38-45 matched), aliexpress 11 (11), 9-22 s for both at once. Peak: app about 600 MB plus helpers
  1.2-1.6 GB (two web processes). After dispose: 0 web processes, helpers 108-110 MB, within 31-39 ms.
  Before the plugin fix, about 1.1 GB stayed until quit.
- Panels: Temu and Shein show "Pass the check below" and report nothing (0 reports). Open: 2 web
  processes, 560-640 MB helpers. After closing: 1 spare web process (about 238 MB), bounded: it does
  not grow from panel to panel. Amazon panel: first tiles report after 3-4 s, 48 offers.
- Real input in a normal window: clicks, typing (with Backspace), a slider-style drag and the wheel
  reach a WPE page, both in the in-app browser (release `-wpe` build) and in a panel inside a scroll
  view. In an integration-test window real clicks are ignored by the test binding by design
  (`shouldPropagateDevicePointerEvents` is false): that is what "unable to click on the checks" was.
  A run with `XDG_RUNTIME_DIR` longer than about 100 characters aborts the app: WebKit's sandbox puts
  a D-Bus proxy socket there, and Unix socket paths stop at 108 bytes. Normal `/run/user/<uid>` is fine.
- Read from screen on a real Amazon page: flaky. 48 offers in 7.4 s in one run, 0 after 40 s in two.
  The screen read now logs why it found nothing (no screenshot, no layout, or lines and tiles without
  products) and tells the user when they asked; the cause was not found before the display rule
  above stopped live runs. Rerun `panel_live_test.dart` under Xvfb to see the reason.
- Sharper ranking parity (`integration_test/reranker_parity_test.dart`, against ONNX Runtime and the
  model's tokenizer in Python): tokens identical for all 84 x 2 pairs; rank correlation 0.993 and
  0.997; NDCG@10 0.570 and 0.565 on device against 0.524 and 0.587; 30 titles in about 1.2 s,
  84 in 3.7-4.2 s. Exact scores differ by up to 0.28: the int8 model's scores move that much with the
  runtime's version (1.28.3 bundled, 1.31.1 reference) and kernel fusion alone. Batching 16 pairs per
  run dropped the rank correlation to 0.97, so pairs run one at a time.
- Exchange rates: the live service (v1, ECB) answers 200 for every currency the app offers. The
  "HTTP 400" came from widget tests, where flutter_test answers every request with 400.
- Android: `flutter build apk --split-per-abi` with JDK 17 (mise temurin-17) builds arm64-v8a 69.3 MB,
  armeabi-v7a 59.4 MB, x86_64 77.1 MB. Not run on a device.
- Open: one spare WPE web process (about 238 MB) stays after the last panel closes; the AUR tarball
  checksum is `SKIP` until a release exists; the OCR flakiness above.

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

1. Release 0.5.0 after approval: security gate (Dependabot, audit), leak scan, push, tag `v0.5.0`.
   Then run `updpkgsums` in `packaging/aur/chanda-bin/` (the tarball's checksum is `SKIP` until a
   release exists), regenerate `.SRCINFO`, and publish to the AUR only after approval.
2. Linux engine B: a dlopen shim so one Linux build loads WPE WebKit when the system has it and runs
   without the in-app browser when not. Then a Flatpak with the WebKit runtime. Both are out of
   Phase 4b's scope.
3. Trousers and shorts on the body photo (legs warp), and the optional realistic mode on a home
   server.
4. Phase 5: screenshots from demo data and the stable release.

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
