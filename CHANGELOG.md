# Changelog

## 0.2.0

Search, compare, and read prices when a page makes it hard.

- One search box for your saved items and several shops at once. Your saved items are searched by
  words, word starts and near spellings. Shops that turn automated visits away open in the in-app
  browser, where *Add these results* keeps what you see.
- Budget, size, shop, colour and material are read from what you type and shown as chips. Tap a chip
  off to widen the search.
- *Other shops* on each item finds the same product elsewhere: by barcode, brand and model, picture
  and name. When Chanda is unsure it asks you once and remembers. A different size or colour is never
  treated as the same product.
- The comparison shows the delivered total in your currency, rating, stock and how fresh each price
  is, and names the best deal with the reason.
- Smarter search (optional, a one-time download of about 252 MB, checked before use): finds items by
  meaning as well as words, in many languages. It runs on your device.
- Android: when a page gives no price as data, Chanda reads it off the screen, on the device, and asks
  you to confirm it.
- Read with AI (optional, with your own Anthropic API key, kept on your device): when Chanda is unsure
  of a name or price, one button asks Claude to read the product page's text. The answer is marked for
  you to confirm. Sign-in and payment pages are never sent.
- Android downloads come as one APK per processor type. Most phones want `arm64-v8a`.

## 0.1.0

First alpha: save products from any shop and get told when the price drops.

- Save a product from a shop link or the share menu. Chanda keeps its price history.
- Prices are re-read on a schedule. Alerts for drops, your target price and restocks, each confirmed
  by a second read.
- The in-app browser for shops and checkout. Chanda never reads or stores sign-in or payment pages.
- Prices in other currencies are shown with the delivered cost in pounds.
- Your data is kept in an encrypted database on your device.
