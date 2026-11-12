# Handoff: where Chanda is (2026-11-12)

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
    `frame_size.dart`). Clothes (tops, dresses, skirts, trousers, shorts; jumpsuits say "not yet")
    drawn on the body photo: BlazePose body points (`pose_fit.dart`), multiclass segmenter parts (`body_mask.dart`),
    garment cut-out and shape reading and the fit (`garment_fit.dart`), wired in `clothes_fit.dart`.
    Garments are only ever widened; the result is re-segmented and refused if the outline at the
    shoulders, waist or hips (and, for trousers and shorts, thighs, knees or calves) shrank more than 3%
    (`maxOutlineShrink`). Size note from JSON-LD
    SizeSpecification or size tables (`size_chart.dart`). AI try-on with the user's own key
    (`cloud_tryon.dart`: FASHN, fal with no-store, Gemini on paid keys only), consent per service tied
    to terms, model, plan and key hash; the result goes through paste-back and the same outline check.
- Releases: 0.3.1 is published as a pre-release (all jobs passed: tests, Android, Windows, Linux,
  Linux start on Ubuntu, Fedora and Arch, Android emulator start). Assets: three APKs (arm64-v8a,
  armeabi-v7a, x86_64), Windows setup and portable zip, Linux tarball, `SHA256SUMS.txt`.
- Tags `v0.2.0` and `v0.3.0` exist without releases: their Linux smoke tests failed because the
  bundle lacked `libonnxruntime.so.1` (fixed in 0.3.1, `linux/CMakeLists.txt`). 0.3.1 supersedes both.
- CI: format, analyze, test on every push. Release: push a `v*` tag; Android signing secrets are set.
- 263 tests pass (2026-11-12); `flutter analyze` is clean. Integration tests with the real try-on models:
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
    and claims the mouse wheel (plugin README, changes 7 and 8); views share a web context that ends with
    the last view (change 9). *Sharper ranking* (`reranker.dart`,
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
- Panels: Temu and Shein show "Pass the check below" and report nothing (0 reports). Amazon panel:
  first tiles report after 3-5 s, 48 offers. The spare web process seen after closing is fixed
  (see "Fixes after 0.5.1" below).
- Real input in a normal window: clicks, typing (with Backspace), a slider-style drag and the wheel
  reach a WPE page, both in the in-app browser (release `-wpe` build) and in a panel inside a scroll
  view. In an integration-test window real clicks are ignored by the test binding by design
  (`shouldPropagateDevicePointerEvents` is false): that is what "unable to click on the checks" was.
  A run with `XDG_RUNTIME_DIR` longer than about 100 characters aborts the app: WebKit's sandbox puts
  a D-Bus proxy socket there, and Unix socket paths stop at 108 bytes. Normal `/run/user/<uid>` is fine.
- Read from screen on a real Amazon page: flaky. Fixed after 0.5.1, see below.
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
- Open: the AUR tarball checksum is `SKIP` until a release exists.

### Fixes after 0.5.1 (2026-11-12, unreleased; under Xvfb, scratch XDG dirs)

Live runs use a headless X server, never the desktop: `Xvfb :99 -screen 0 1280x900x24 -nolisten tcp`,
then `DISPLAY=:99 WAYLAND_DISPLAY= GDK_BACKEND=x11 XDG_DATA_HOME=<scratch> XDG_CACHE_HOME=<scratch>
flutter test integration_test/panel_live_test.dart -d linux` (`--dart-define=SHOP=aliexpress` for the
screen read on another shop; `--plain-name` for one test). WebKit's own log goes to the journal with
`WEBKIT_DEBUG=Process,ProcessSwapping,BackForwardCache,PerformanceLogging`.

- Read from screen (`_readScreen` in `shop_panels.dart`, `screen_tiles.dart`, `pp_ocr.dart`).
  - Causes: (1) it read one screenful. At the top of a results page that is the shop's header, a
    sponsored block (its links are adverts, rightly dropped) and often a fixed cookie notice, so no
    product tile with a price was ever on screen. (2) Raised pence ("£47" with small "49") read as one
    number, "£4749". (3) In the live test, the tap on the menu item could land while the menu was still
    growing in.
  - Fixes: it now reads up to `screenViews` (6) screens. For each one it waits for a settled frame,
    takes the screenshot, then reads the layout (`viewScript`: the band between fixed and sticky bars,
    links and picture links). Screens with no product picture are skipped. It scrolls to the next row of
    pictures (`screenStep`) and scrolls back afterwards. A background try does not move a page the user
    scrolled. Tiles from all screens are merged by link (`mergeTiles`). Titles come only from lines
    above the price, without badge noise. Prices far out of line with the rest are dropped
    (`plausiblePrices`). OCR splits a glued price at its raised tail (`raisedTail`) and reads both parts.
    If a bar covers most of the view, the user is told to close it (the page is never clicked for them).
  - Before: 0 products in 6 of 6 runs on Amazon UK (one of them a missed tap). After: products in 7 of
    7 Amazon UK runs (1-7 each, 5 typical) and 2 of 2 AliExpress runs (8 and 3). A debug build takes
    47-61 s for six screens, most of it OCR. A release build was not timed.
  - Still limited: a cookie notice covering the lower part of the page leaves fewer rows to read, and
    AliExpress titles can carry badge words.
- Spare web processes after the last view (plugin change 9, `in_app_webview.cc`).
  - Cause: WebKit's default web context lives until the app quits, and its process pool keeps web
    processes no view uses. After a cross-site navigation the old page's process goes to the
    back/forward cache and then to the process cache (capacity 32, kept for many minutes). A provisional
    process and a prewarmed process stay too. Terminating the view's own process (change 7) does not
    reach them. A page that stays on one site frees its only process within about 0.5 s. The 238 MB
    "spare" was such a process, measured before it had ended, or a page that had changed site.
  - Setting the cache model does not help: changing it to document viewer when the last view closes
    empties the back/forward cache, but the process cache reads the model only when the pool is made, so
    it still kept 32.
  - Fix: views that name no context share one made by the plugin and held only by the views (a weak
    pointer, no count). When the last view goes, the context and its pool go, and every process with
    them. Cookies and local storage are kept: they belong to the default network session (checked
    across two contexts).
  - Numbers (example.com, then a cross-site page; helpers RSS / PSS):
    - Open: 4 web processes, about 800 MB / 285 MB.
    - Before the fix, after closing: 3 processes, 557 MB / 218 MB, still there 30 s later. A second
      round left 4, 682 MB / 243 MB.
    - After the fix: 0 processes within 0.3-0.4 s, 78-81 MB / 49-51 MB. That is the network process
      and other shared helpers, which stay once started (39-54 MB / 17-32 MB before the first page).
    - Temu and Shein panels, Amazon panel and the hidden searches: 0 web processes 0.06-0.5 s after
      closing.
  - `panel_live_test.dart` now expects 0 web processes after the last view, measures PSS, and has a
    cross-site test (two rounds, site data kept).

### Trousers and shorts on the body photo (2026-11-12, unreleased)

- Kinds (`garmentKind` in `garment_fit.dart`): title first, then the shop's JSON-LD category
  (`Reading.category`: Product `category`, else the page's BreadcrumbList), then tags and list name.
  New kinds `shorts` (needs knees) and `onePiece` (jumpsuits, playsuits, dungarees: "not yet", sent to
  the cloud services as one-pieces). The vault has no category column: the save sheet pre-fills the
  garment word from the category as a tag (`garmentTag`) when the title names none; the user sees it.
- Shape (`_readLegs`): waistband at the top (at least 45% of the width), the crotch found up the middle
  column from the bottom through the gap between the legs, each leg's inner edge row by row (`Legs`).
  Refused (`GarmentProblem.legs`) when the bottom middle is solid, the rise or leg lengths are out of
  range, a leg is thin, or a leg splays out. Ratios: trousers 0.9-3.6, shorts 0.4-1.6 (h/w).
- Fit (`_fitLegs`): the waistband at 80% of the way from the shoulders to the hip joints
  (`legsWaistAt`), scale from the body's width there as for skirts; the seat (waist to crotch) is mapped
  per pixel like a skirt, each row at least as wide as the body plus ease. Each leg is 12 slices
  (`legSlices`) mapped as triangles along hip, knee, ankle; the top slice is the seat's bottom row, the
  offset from the seat to the bone fades out by the knee, each slice at least as wide as the body's leg
  (legs together are split at the middle between them). Hems stop at the ankle plus 5% (`pastAnkle`).
  Never drawn above the middle of shoulders and hips (`lowerHalf`), nor over hair, face, hands or arms.
  `FitProblem.legs` when a knee (or, for a leg reaching past the knee, an ankle) is not seen, a leg is
  raised or folded, or the legs cross. `BodyProblem.legs` replaces `cropped` when only knees or ankles
  are missing. The outline check measures each leg at thigh, knee and calf (`legRows`) for these kinds.
- Size chart: trousers compare waist, inside leg, hip; shorts waist, hip. "Leg" / "Leg length" columns
  are the inside leg (not outside leg, opening, width); unlabelled charts are taken as inches by a vote
  of figures too small for centimetres (chest/hip < 60, waist < 50, leg < 45).
- Tests: synthetic trousers (200×370) and shorts (240×200) cut-outs on the drawn 400×800 body, legs
  together and apart; legs hidden, crossed; cover check; leg outline shrink; JSON-LD inseam and an inch
  jeans table; category and breadcrumbs; the save-sheet tag; the try-on page with trousers and with
  hidden knees. `flutter test`: 263 pass.
- Not run with the real models (none downloaded on this laptop). `integration_test/clothes_test.dart`
  takes `--dart-define=TROUSERS=/path/flat-trousers.jpg` for that.

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
- Trousers: only a flat or hung picture with the legs apart works (legs touching at the hem are
  refused). The hem's height follows the garment's own proportions scaled from the waist, so it is
  approximate; a long skirt or dress on the body photo makes trouser legs wide; low-rise and high-rise
  both sit at the same waist line; folds at the knee and the gap between the legs are not shaded.

## Next

1. Release 0.5.0 after approval: security gate (Dependabot, audit), leak scan, push, tag `v0.5.0`.
   Then run `updpkgsums` in `packaging/aur/chanda-bin/` (the tarball's checksum is `SKIP` until a
   release exists), regenerate `.SRCINFO`, and publish to the AUR only after approval.
2. Linux engine B: a dlopen shim so one Linux build loads WPE WebKit when the system has it and runs
   without the in-app browser when not. Then a Flatpak with the WebKit runtime. Both are out of
   Phase 4b's scope.
3. Trousers and shorts: check with the real models on real shop pictures (`TROUSERS=` in the
   integration test). Then the optional realistic mode on a home server.
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
