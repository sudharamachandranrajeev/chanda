import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart';

// Table names are unique across the Brahma suite: every app on an account
// reads the same change log and applies only its own tables. Chanda's all
// start with `chanda_`. Times are ISO 8601 in UTC; money is in minor units
// (pence, cents) of the row's own currency.

/// A list in the vault: "Glasses", "Summer clothes", "Birthday ideas".
@DataClassName('VaultList')
class ChandaLists extends Table with SyncedRow {
  TextColumn get name => text()();
  TextColumn get created => text()();
  IntColumn get ord => integer().withDefault(const Constant(0))();
}

/// One thing the user wants, as saved from a shop's page. The saved copy
/// (title, images, description, variant) stays when the listing is gone.
@DataClassName('VaultItem')
class ChandaItems extends Table with SyncedRow {
  TextColumn get listId => text()();
  TextColumn get title => text()();
  TextColumn get brand => text().withDefault(const Constant(''))();

  /// A shop id from the catalogue (lib/domain/shops.dart), else the domain.
  TextColumn get shop => text()();

  /// The product page, cleaned of tracking and affiliate tags.
  TextColumn get url => text()();

  /// The shop's own product id when known (Amazon ASIN, Shein goods id).
  TextColumn get productKey => text().withDefault(const Constant(''))();

  /// The chosen options as JSON: {"Size":"M","Colour":"Navy"}.
  TextColumn get variant => text().withDefault(const Constant('{}'))();
  TextColumn get note => text().withDefault(const Constant(''))();

  /// Comma-separated.
  TextColumn get tags => text().withDefault(const Constant(''))();

  /// Image URLs as a JSON list; copies live on the device (lib/domain/images.dart).
  TextColumn get images => text().withDefault(const Constant('[]'))();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get seller => text().withDefault(const Constant(''))();
  TextColumn get gtin => text().withDefault(const Constant(''))();
  TextColumn get mpn => text().withDefault(const Constant(''))();

  /// The shop's star rating (0-5) and number of ratings, when shown.
  RealColumn get rating => real().nullable()();
  IntColumn get reviews => integer().nullable()();

  /// Warranty and returns wording found on the page.
  TextColumn get warranty => text().withDefault(const Constant(''))();
  TextColumn get currency => text()();

  /// The latest confirmed price, its struck-through "was" price and delivery.
  IntColumn get price => integer().nullable()();
  IntColumn get was => integer().nullable()();
  IntColumn get shipping => integer().nullable()();
  BoolColumn get inStock => boolean().withDefault(const Constant(true))();

  /// Alert when the price is at or under this (minor units of [currency]).
  IntColumn get target => integer().nullable()();
  BoolColumn get alertDrop => boolean().withDefault(const Constant(true))();
  BoolColumn get alertStock => boolean().withDefault(const Constant(true))();

  /// Checked up to four times a day instead of once.
  BoolColumn get watchClose => boolean().withDefault(const Constant(false))();
  BoolColumn get bought => boolean().withDefault(const Constant(false))();
  TextColumn get added => text()();

  /// When the price was last read, and how that went: ok | needs-you (the
  /// shop wants the user present, signed in or past a check) | gone | failed.
  TextColumn get checked => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('ok'))();
  IntColumn get failures => integer().withDefault(const Constant(0))();

  /// Which part of the page the price came from (lib/domain/reading.dart).
  TextColumn get layer => text().withDefault(const Constant(''))();
}

/// A price read for an item: its history.
@DataClassName('PricePoint')
class ChandaPrices extends Table with SyncedRow {
  TextColumn get itemId => text()();
  IntColumn get price => integer()();
  TextColumn get currency => text()();
  IntColumn get was => integer().nullable()();
  IntColumn get shipping => integer().nullable()();
  BoolColumn get inStock => boolean().withDefault(const Constant(true))();
  TextColumn get seen => text()();
  TextColumn get layer => text().withDefault(const Constant(''))();

  /// save | check | manual
  TextColumn get source => text().withDefault(const Constant('check'))();
}

/// An alert Chanda raised, kept so the user can see what fired and when.
@DataClassName('AlertEvent')
class ChandaAlerts extends Table with SyncedRow {
  TextColumn get itemId => text()();

  /// target | drop | stock | test
  TextColumn get kind => text()();
  IntColumn get before => integer().nullable()();
  IntColumn get after => integer().nullable()();
  TextColumn get currency => text().withDefault(const Constant(''))();
  TextColumn get at => text()();
  BoolColumn get seen => boolean().withDefault(const Constant(false))();
}

/// Offers found on shops' search pages. A local cache: never synced, and
/// rebuilt by searching again.
@DataClassName('ShopOffer')
class ChandaOffers extends Table {
  /// shop + cleaned link.
  TextColumn get id => text()();
  TextColumn get shop => text()();
  TextColumn get url => text()();
  TextColumn get title => text()();
  TextColumn get image => text().withDefault(const Constant(''))();
  IntColumn get price => integer().nullable()();
  TextColumn get currency => text()();
  IntColumn get was => integer().nullable()();
  RealColumn get rating => real().nullable()();
  IntColumn get reviews => integer().nullable()();
  BoolColumn get inStock => boolean().withDefault(const Constant(true))();

  /// The search that last found it.
  TextColumn get query => text().withDefault(const Constant(''))();
  TextColumn get seen => text()();

  /// 64-bit difference hash of the picture, as 16 hex digits ('' until
  /// worked out).
  TextColumn get dhash => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

/// The user's answers to "Is this the same product?": an offer's link and
/// a vault item, same or not. Synced, so no device asks twice.
@DataClassName('ProductMatch')
class ChandaMatches extends Table with SyncedRow {
  TextColumn get itemId => text()();
  TextColumn get url => text()();

  /// same | different
  TextColumn get verdict => text()();
}

/// The user's star ratings, of saved items and of things seen in searches,
/// kept against the product page address. Synced: the taste model is
/// rebuilt from them on each device.
@DataClassName('Rating')
class ChandaRatings extends Table with SyncedRow {
  TextColumn get url => text()();
  TextColumn get title => text()();
  TextColumn get shop => text().withDefault(const Constant(''))();
  TextColumn get image => text().withDefault(const Constant(''))();
  IntColumn get price => integer().nullable()();
  TextColumn get currency => text().withDefault(const Constant(''))();

  /// 1-5.
  IntColumn get stars => integer()();
  TextColumn get at => text()();

  /// rated | not-for-me
  TextColumn get source => text().withDefault(const Constant('rated'))();
}

class Prefs extends Table with SyncedRow, PrefColumns {}

@DataClassName('OutboxItem')
class Outbox extends Table with OutboxColumns {}

@DataClassName('SyncCursor')
class SyncCursors extends Table with SyncCursorColumns {}

@DataClassName('LocalSetting')
class LocalSettings extends Table with LocalSettingColumns {}
