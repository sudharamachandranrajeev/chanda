# Changelog

## Unreleased

- *Read the results from the screen* now works on long results pages. Before, it read only the part of the
  page in view, which at the top of a shop's results is often its header, adverts and a cookie notice, so
  it found nothing. It now reads up to six screens down the page, then puts the page back where it was.
  Prices drawn with small raised pence (£47⁴⁹) read as £47.49, not £4749, and a price far out of line
  with the rest is dropped. If something covers the page, such as a cookie notice, Chanda says so.
- Linux: closing the last shop page or in-app browser now frees all of its memory. Before, a page that had
  moved to another site left two to four helper processes running, about 550-700 MB, for many minutes.
  Sign-ins and site data are kept as before.

## 0.5.1

- Same app as 0.5.0, which was never published: its Ubuntu start test failed on a script error in
  the release workflow, not in Chanda. 0.5.1 is the first release with try-on and in-app search.

## 0.5.0: search that stays in the app

- Searches that ask for more than words now find things. "Walking shoes for all terrains, easy slip in" is
  read as walking shoes that are *All-terrain* and *Slip-on*; both show as chips you can tap off. Shops
  never write "for" or "easy", so results are no longer cut by how many of your words a title holds:
  they are ranked by what matched, and each card says so (*Matches: All-terrain, Slip-on*).
- Shops that show results only to a person (Temu, Shein, and any shop that asks for a check) appear in
  Search as tabs marked *needs you*, each with the shop's own page live below. Pass the check or sign in
  there, and Chanda adds the products it sees to the same results. If a page gives nothing readable,
  Chanda can read the screen; those results say *Read from screen*, are never kept, and never start an
  alert. Sign-in and payment pages are never read. *Add these results* is gone.
- After you pass a shop's check, Chanda tries that shop in the background once for the rest of the
  session, and shows its page again if it meets the check.
- Shops built on common shop software are searched through their own product search, which needs no web
  view, says it is Chanda and pauses when a shop asks it to.
- Settings: optional eBay keys (your own developer keys, kept on this device, never synced) put eBay UK in
  the results.
- Fewer wrong reads: adverts are skipped, hidden characters and screen-reader price labels no longer
  break prices (this is why one sports shop read as empty), and check pages are recognised by address.
  At most two shop pages load in the background at once on a computer, one on a phone.
- Hacoo is no longer searched on the web (its old website address is for sale); save its products from
  the app's share link instead.
- *Sharper ranking* in Settings (off by default): a 96 MB download, once, then a small model on this device
  reads your search and each product name together and puts the closest fits first among the best
  matches. Nothing is sent anywhere.
- Linux: a second download, `Chanda-<version>-linux-x64-wpe.tar.gz`, for Arch Linux, Omarchy and other
  Arch-based systems. It has the in-app browser and the shop panels and uses the system's WPE WebKit 2.52
  or later (`pacman -S wpewebkit`) instead of carrying its own copy, so the download is about 36 MB. The
  other Linux download stays, without the in-app browser.
- Linux: closing a shop page or finishing a background search now frees its web process. Before, each one
  kept hundreds of MB until Chanda quit.
- Linux: the mouse wheel over a shop panel scrolls only that page, not Search around it.
- Exchange rates: the app's tests no longer reach the network, which is where the "HTTP 400" in the logs
  came from. The live service answers normally.
- Attribute list from the Shopify Standard Product Taxonomy (MIT) and price test cases from price-parser
  (BSD-3): see THIRD_PARTY_NOTICES.md.

## 0.4.0

Try things on: glasses on your face at their real size, and clothes on your whole body, keeping your shape.

- *Your photos and sizes* in Settings keeps a face photo, a body photo, your body measurements and pupil
  distance, only after you agree, only on this device. They are never synced. *Delete my photos and
  sizes* removes them.
- Glasses from your vault get a **Try on** button. The frame is drawn on your face photo at its real
  width, sized from your eyes or the pupil distance you type, with how sure Chanda is. The frame size
  comes from the listing, or you type it.
- Tops, dresses and skirts get a **Try on** button too. The garment is cut out of the shop's picture and
  drawn on your body photo, with your hair, face, arms and hands in front. It is labelled *Fit preview,
  approximate*. The garment is stretched to your outline, never you to the garment: if the picture would
  come out narrower than you anywhere, Chanda shows *Cannot fit this photo* and why, and draws nothing.
  Trousers and shorts are not drawn yet.
- A size note sets the shop's size chart against your sizes: within a size's range, between two sizes, or
  outside the chart, with where the chart came from. It never tells you which size to buy.
- AI try-on, off by default: add your own key for FASHN, fal or Gemini (paid plan only) in Settings. Before
  the first picture, Chanda shows what is sent, how long the service keeps it and what it costs, and asks
  you; it asks again if any of that changes. Only the clothes are taken from the picture that comes back,
  checked the same way, and labelled *AI preview*.
- Try-on needs a one-time download of about 51 MB, from Hugging Face. It runs on your device.
- Deleting an item also forgets its frame size and size chart on this device.

## 0.3.1

- Linux: the download now starts. It was missing a library that the built-in text recognition and
  picture search need.

## 0.3.0

Search with a photo, suggestions that learn your taste, and shops like the ones you use.

- Built-in text recognition on every device. When a page gives no price as data, Chanda reads it off
  the screen on the device itself, with no AI plan or account needed. Windows and Linux now do this too.
- Search with a photo: take one or pick one, and Chanda names what it shows ("blue round glasses"), finds
  things you saved or found before that look like it, and searches the shops for it. On Android you can
  also share a photo to Chanda. Needs the picture model, an optional one-time download of about 94 MB.
  Your photos never leave the device.
- Rate things with one to five stars, on an item or from the *Rate a few?* card in the vault. Saving and
  buying count a little too.
- *For you* on the Search page suggests things found before that suit your taste, each with the reason.
  *Not for me* and *Stop counting* teach it what you do not want. Results can be sorted *For you*.
- Taste can be turned off, exported to a file, imported on another device, or forgotten, in Settings.
  It never uses your age or gender.
- *Shops like yours* on the Shops page suggests shops that sell what you save, at the prices you pay,
  from a list kept with Chanda. No shop pays to be on it.
- *Check this shop* shows what a shop and its domain registry publish: when its web address was first
  registered, a secure connection, company, contact and returns details, and a link to read what buyers say.
- *Add to my search* adds a suggested shop, or any shop, to Chanda's search. For a shop that does not say
  how to search it, paste one of its results pages and the words you searched.

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
