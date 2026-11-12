# flutter\_inappwebview\_linux

The Linux WPE WebKit implementation of [`flutter_inappwebview`](https://pub.dev/packages/flutter_inappwebview).

## Usage

This package is [endorsed](https://flutter.dev/docs/development/packages-and-plugins/developing-packages#endorsed-federated-plugin),
which means you can simply use `flutter_inappwebview`
normally. This package will be automatically included in your app when you do,
so you do not need to add it to your `pubspec.yaml`.

However, if you `import` this package to use any of its APIs directly, you
should add it to your `pubspec.yaml` as usual.

## Chanda's copy

A copy of `flutter_inappwebview_linux` 0.1.0-beta.1 (Apache-2.0, see
LICENSE), used through `dependency_overrides` in Chanda's pubspec. The
example app is left out. Nine changes:

1. `linux/CMakeLists.txt` needs libwpe (wpe-1.0) only for the legacy
   WPEBackend-FDO path, because WPE WebKit 2.52 and later with WPEPlatform
   (Arch, Fedora) ship without it.
2. `linux/in_app_webview/in_app_webview.cc` no longer imports each page
   frame as an EGL image. The image was made on WPE's own EGL display, but
   Flutter draws it with a different one, so pages showed black. Frames now
   go through `wpe_buffer_import_to_pixels`. Set
   `FLUTTER_INAPPWEBVIEW_LINUX_EGL_IMPORT=1` to try the old path.
3. The same file no longer frees the bytes that `wpe_buffer_import_to_pixels`
   returns. They belong to the buffer, and freeing them crashed the app.
4. Frames are packed row by row using the buffer's real stride (`PackFrame`),
   and a frame too short for its size is dropped. Before, padded rows were
   copied as if tightly packed, and the texture upload read past the end.
5. A frame buffer is kept only while an EGL image uses it, and then with a
   ref. Before, a bare pointer was kept; WPE frees buffers when the view
   resizes, so the next frame crashed. Pixel frames are copied, so their
   buffer goes back to WPE at once.
6. `linux/CMakeLists.txt` no longer copies `libWPEWebKit-2.0` (148 MB) into
   the app bundle. The plugin links against the system's WPE WebKit 2.52+:
   its helper processes live in `/usr/lib/wpe-webkit-2.0`, so a bundled copy
   only ran next to the same system version anyway. Configure with
   `-DFLUTTER_INAPPWEBVIEW_LINUX_BUNDLE_WPE=ON` for the old behaviour.
7. `linux/in_app_webview/in_app_webview.cc` ends the page's web process when
   the view is destroyed (`webkit_web_view_terminate_web_process`), after
   disconnecting its own signal handlers. Unreffing the view alone left each
   `WPEWebProcess` (hundreds of MB) running after the view was gone.
8. `lib/src/in_app_webview/custom_platform_view.dart` claims mouse-wheel
   events through `pointerSignalResolver`. Before, a scroll view around the
   page scrolled along with the page.
9. `linux/in_app_webview/in_app_webview.cc`: views that name no web context
   share one the plugin makes (`webkit_web_context_new`), held only by the
   views, instead of WebKit's default context, which lives until the app
   quits. After a cross-site navigation WebKit kept the old page's web
   process and a prewarmed one in the context's process pool (its process
   cache holds up to 32, for many minutes), so 2-4 `WPEWebProcess`es
   (about 550-700 MB resident) stayed after the last view closed. Now the
   context and its pool end with the last view, and those processes with
   them. Cookies and site data are unaffected: they live in the network
   session. A lower cache model does not help: the process cache reads it
   only when the pool is made.

Drop this copy once upstream fixes changes 2-5 and 7-9 and makes 1 and 6
options.
