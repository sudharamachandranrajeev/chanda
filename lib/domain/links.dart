/// Query parameters that only track the visit or credit someone else for
/// the sale. Chanda drops them from every saved link: it works for the
/// shopper alone, so a saved link carries no one's affiliate tag (and none
/// is ever added).
const _tracking = {
  // Amazon Associates and Amazon's own tracking.
  'tag', 'ascsubtag', 'linkcode', 'linkid', 'creative', 'creativeasin', 'camp', 'ref_', 'psc', 'pd_rd_w',
  'pd_rd_r', 'pd_rd_wg', 'pd_rd_i', 'pf_rd_p', 'pf_rd_r', 'content-id', 'dib', 'dib_tag', 'qid', 'sr',
  'keywords', 'crid', 'sprefix', 'th',
  // AliExpress affiliate and tracking.
  'aff_platform', 'aff_trace_key', 'aff_fcid', 'aff_fsk', 'aff_short_key', 'sk', 'terminal_id', 'afsmartredirect',
  'spm', 'scm', 'algo_pvid', 'algo_exp_id', 'pdp_npi', 'pdp_ext_f', 'src', 'gatewayadapt', 'utparam-url',
  'businesstype', 'srcsns', 'sharetype', 'social_params', 'tt', 'invitationcode', 'bizfrom', 'shareid',
  // Temu and Shein referral and ad tracking.
  '_x_ads_channel', '_x_ads_sub_channel', '_x_ads_account', '_x_ads_set', '_x_ads_id', '_x_ads_creative_id',
  '_x_ns_source', '_x_ns_sku_id', '_x_vst_scene', '_x_campaign', '_x_sessn_id', 'refer_page_name',
  'refer_page_id', 'refer_page_sn', '_bg_fs', 'share_token', 'url_from', 'ici', 'scici', 'src_identifier',
  'src_module', 'src_tab_page_id', 'mallcode', 'onelink', 'scene', 'currentpagenum',
  // Everyone else.
  'gclid', 'gbraid', 'wbraid', 'fbclid', 'msclkid', 'ttclid', 'twclid', 'yclid', 'mc_cid', 'mc_eid',
  'igshid', 'si', 'srsltid', 'affiliate', 'affiliate_id', 'aff', 'aff_id', 'affid', 'clickid', 'irclickid',
  'irgwc', 'ranmid', 'raneaid', 'ransiteid', 'awc', 'cjevent', 'partnerid', 'referrer', 'ref',
};

/// [url] without tracking and affiliate parameters or a fragment, with
/// Amazon product pages cut to /dp/ASIN.
Uri cleanLink(Uri url) {
  final kept = <String, String>{
    for (final e in url.queryParameters.entries)
      if (!_tracking.contains(e.key.toLowerCase()) && !e.key.toLowerCase().startsWith('utm_')) e.key: e.value,
  };
  var path = url.path;
  final asin = RegExp(r'/(?:dp|gp/product|gp/aw/d)/([A-Z0-9]{10})').firstMatch(path);
  if (asin != null && url.host.contains('amazon.')) {
    path = '/dp/${asin[1]}';
    kept.clear();
  }
  // Amazon's /ref=... path segment is tracking too.
  path = path.replaceFirst(RegExp(r'/ref=[^/]*$'), '');
  return Uri(
    scheme: url.scheme,
    host: url.host,
    port: url.hasPort ? url.port : null,
    path: path,
    queryParameters: kept.isEmpty ? null : kept,
  );
}

/// The first web address in [text]: a shared message is often
/// "Look at this! https://...".
Uri? linkIn(String text) {
  final m = RegExp(r'https?://[^\s<>"]+').firstMatch(text);
  if (m == null) return null;
  final u = Uri.tryParse(m[0]!.replaceFirst(RegExp(r'[.,);\]]+$'), ''));
  return u != null && u.host.isNotEmpty ? u : null;
}

/// Pages where Chanda reads nothing: payment providers, and the checkout,
/// payment and sign-in steps of any shop. Card numbers, passwords and
/// one-time codes are typed into the shop's page and never touched.
bool isPrivatePage(Uri url) {
  final host = url.host.toLowerCase();
  if (_paymentHosts.any((h) => host == h || host.endsWith('.$h'))) return true;
  final path = url.path.toLowerCase();
  return RegExp(
    r'(^|/)(checkout|payment|payments|pay|billing|buy/spc|gp/buy|ap/signin|ap/register|signin|sign-in|login|'
    r'log-in|account|my-account|order-confirmation|3ds)(/|$|\.)',
  ).hasMatch(path);
}

const _paymentHosts = [
  'paypal.com',
  'klarna.com',
  'clearpay.co.uk',
  'afterpay.com',
  'stripe.com',
  'adyen.com',
  'worldpay.com',
  'checkout.com',
  'braintreegateway.com',
  'cardinalcommerce.com',
  'pay.google.com',
  'apple.com',
  'accounts.google.com',
  'appleid.apple.com',
  'secure5.arcot.com',
  'alipay.com',
  'payu.com',
  'mollie.com',
];

/// Google refuses its sign-in inside apps' embedded browsers, so these
/// pages go to the system browser with an explanation.
bool isGoogleSignIn(Uri url) =>
    url.host == 'accounts.google.com' &&
    RegExp(r'^/(o/oauth2|signin|ServiceLogin|v3/signin|AccountChooser)').hasMatch(url.path);
