import 'links.dart';
import 'offers.dart';
import 'reading.dart';

/// The name of the page-to-app channel the panel script reports on.
const tilesHandler = 'tiles';

/// The script a live shop panel runs in every page it shows. It watches the
/// page change (a MutationObserver) and, a moment after the page settles,
/// reads the products listed (the page's product data first, then its
/// tiles: [offerScript]) and reports them to the app on [tilesHandler] with
/// the page's address, but only when they changed. It does nothing on a
/// sign-in or payment page, nor on a shop's check page: those are never read.
/// It only reads; it never clicks, types or changes the page.
final panelScript =
    '''
(() => {
  if (window.__chandaTiles) return;
  window.__chandaTiles = true;
  const isPrivate = $privatePageScript;
  const wall = /${wallAddress.pattern.replaceAll('/', r'\/')}/i;
  const read = () => $offerScript;
  let last = '', timer = null;
  const report = () => {
    timer = null;
    if (isPrivate || wall.test(location.pathname + location.search)) return;
    let json = '';
    try { json = read(); } catch (e) { return; }
    if (json === last || json === '[]') return;
    last = json;
    try { window.flutter_inappwebview.callHandler('$tilesHandler', json, location.href); } catch (e) {}
  };
  const soon = () => { if (!timer) timer = setTimeout(report, 700); };
  new MutationObserver(soon).observe(document.documentElement, {childList: true, subtree: true});
  soon();
})();
''';
