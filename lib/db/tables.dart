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

class Prefs extends Table with SyncedRow, PrefColumns {}

@DataClassName('OutboxItem')
class Outbox extends Table with OutboxColumns {}

@DataClassName('SyncCursor')
class SyncCursors extends Table with SyncCursorColumns {}

@DataClassName('LocalSetting')
class LocalSettings extends Table with LocalSettingColumns {}
