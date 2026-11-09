import 'money.dart';
import 'reading.dart';

// The last rung of the reading ladder: when a page gives no price as data
// (it is drawn as a picture, or the shop hides it from scripts), Chanda can
// read the text off a screenshot of what the user is looking at. Android
// only for now (ML Kit, on the device); desktop OCR comes in Phase 3.

/// A line of text read off the screen, with its place and height in pixels.
class ScreenLine {
  const ScreenLine(this.text, {required this.top, required this.height});
  final String text;
  final double top;
  final double height;
}

final _notPrice = RegExp(
  r'\b(was|rrp|list|typical|delivery|shipping|postage|off|save|saving|coupon|per|each|from|reviews?|sold)\b|%',
  caseSensitive: false,
);
final _sign = RegExp(r'[£$€¥₹₩]|\b[A-Z]{3}\b|\d[.,]\d{2}\b');

/// [r] with the price, and the title if it had none, read from [lines]:
/// the price is the tallest price-only line (shops draw the current price
/// biggest), the title the tallest line of words in the top half.
Reading withScreenText(Reading r, List<ScreenLine> lines, {required double screenHeight}) {
  final prices =
      [
        for (final l in lines)
          if (l.text.trim().length <= 24 && _sign.hasMatch(l.text) && !_notPrice.hasMatch(l.text))
            if (parsePrice(l.text, hint: r.currency) case final p?) (l, p),
      ]..sort(
        (a, b) =>
            b.$1.height != a.$1.height ? b.$1.height.compareTo(a.$1.height) : a.$1.top.compareTo(b.$1.top),
      );
  if (prices.isEmpty) return r;
  final (_, price) = prices.first;
  String? title;
  if (r.title.isEmpty) {
    final words = [
      for (final l in lines)
        if (l.top < screenHeight / 2 &&
            l.text.trim().split(RegExp(r'\s+')).length >= 2 &&
            l.text.length >= 8 &&
            parsePrice(l.text, hint: r.currency) == null)
          l,
    ]..sort((a, b) => b.height.compareTo(a.height));
    title = words.firstOrNull?.text.trim();
  }
  return r.withFacts(
    title: title,
    price: price.minor,
    currency: price.currency,
    clearWas: true,
    layer: 'screen',
    warning: 'Read from the screen: please confirm the price.',
  );
}
