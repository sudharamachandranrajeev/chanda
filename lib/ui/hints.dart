/// Chanda's hints, by id, on top of the shared ones (coreHints). Page
/// banners (ids starting `page.`) explain a whole screen once.
const chandaHints = <String, String>{
  'nav.vault': 'Everything you want to buy, from any shop, with its price kept up to date.',
  'nav.alerts': 'Price drops, your target prices and things back in stock.',
  'nav.search': 'Search your vault and the shops at once, and compare what you find.',
  'nav.shops': 'Open a shop inside Chanda, sign in, and save what you find.',
  'nav.settings': 'Money, alerts, background checks, look, sync and security.',
  'page.vault':
      'Save a product from any shop: open it in Shops and press Save, share a link to Chanda, or paste one '
      'here. Chanda checks each price about once a day and tells you when it drops.',
  'page.alerts':
      'Before any alert Chanda reads the page twice, a few seconds apart, and alerts only when both reads '
      'agree.',
  'page.shops':
      'Shops open inside Chanda. Sign in on the shop\'s own page: Chanda keeps the shop\'s cookies on this '
      'device like a browser does and never sees your password. Payment and sign-in pages are never read.',
  'page.search':
      'Type what you want: "black linen shirt size M under £30". Budget, size, colour, material and shop become '
      'chips you can tap off. Chanda searches your vault and the shops that allow it; the others open in the '
      'browser, where you press Add these results.',
  'action.compare':
      'Offers found at other shops for this item. Chanda marks the same product only when the barcode or '
      'brand and model number agree, never across sizes or colours. Anything less certain asks you once.',
  'action.save':
      'Chanda reads the product\'s name, price, pictures and details from the page you are looking at. '
      'Check the price before saving: you can correct it.',
  'action.landed':
      'What it costs you delivered: price, delivery and, for goods sent from abroad, the UK import VAT and '
      'duty you may pay on arrival. Foreign prices use the European Central Bank\'s daily rate.',
  'action.check':
      'Reads the shop\'s page again now. Chanda also checks by itself: about once a day for each item, every '
      'six hours for items you watch closely.',
  'action.background':
      'Checks prices while Chanda is closed, as plain web pages that say they come from Chanda. Shops that '
      'turn such visits away are checked only while Chanda is open.',
  'action.ntfy':
      'ntfy sends alerts to your phone or any device through a topic address you choose. Only the alert '
      'text is sent.',
};
