/// Chanda's Linux "implementation" of flutter_inappwebview: it registers
/// nothing, so hasWebView is false and shops open in the system browser.
class NoLinuxWebView {
  static void registerWith() {}
}
