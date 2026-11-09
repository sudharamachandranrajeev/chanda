import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart';

import 'tables.dart';

export 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    ChandaLists,
    ChandaItems,
    ChandaPrices,
    ChandaAlerts,
    ChandaOffers,
    ChandaMatches,
    ChandaRatings,
    Prefs,
    Outbox,
    SyncCursors,
    LocalSettings,
  ],
)
class AppDatabase extends _$AppDatabase with SyncedDatabase {
  AppDatabase(super.e);

  /// Opens Chanda's encrypted database (see [openEncryptedDatabase]).
  AppDatabase.open(String key) : this(openEncryptedDatabase('chanda', key));

  @override
  final syncedTables = const [
    'chanda_lists',
    'chanda_items',
    'chanda_prices',
    'chanda_alerts',
    'chanda_matches',
    'chanda_ratings',
    'prefs',
  ];

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      for (final sql in [..._indexes, ..._phase2, ..._phase3]) {
        await customStatement(sql);
      }
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(chandaOffers);
        await m.createTable(chandaMatches);
        for (final sql in _phase2) {
          await customStatement(sql);
        }
      }
      if (from < 3) {
        await m.createTable(chandaRatings);
        for (final sql in _phase3) {
          await customStatement(sql);
        }
      }
    },
  );

  static const _indexes = [
    'CREATE INDEX chanda_items_list ON chanda_items (list_id)',
    'CREATE INDEX chanda_prices_item ON chanda_prices (item_id, seen)',
    'CREATE INDEX chanda_alerts_item ON chanda_alerts (item_id)',
  ];

  /// Search (schema 2): matches by item, and a full-text index over vault
  /// items and found offers, filled by `LocalSearch.reindex`. Two tokenizers:
  /// words (with prefixes) for most titles, trigrams for substrings and
  /// scripts written without spaces.
  static const _phase2 = [
    'CREATE INDEX chanda_matches_item ON chanda_matches (item_id)',
    "CREATE VIRTUAL TABLE chanda_words USING fts5(ref UNINDEXED, kind UNINDEXED, title, extra, "
        "tokenize = 'unicode61 remove_diacritics 2', prefix = '2 3')",
    "CREATE VIRTUAL TABLE chanda_grams USING fts5(ref UNINDEXED, kind UNINDEXED, title, tokenize = 'trigram')",
  ];

  /// Taste and shops (schema 3): ratings by page, and two local caches that
  /// are never synced: picture vectors by picture address, and facts looked
  /// up about shops' domains.
  static const _phase3 = [
    'CREATE INDEX chanda_ratings_url ON chanda_ratings (url)',
    'CREATE TABLE IF NOT EXISTS chanda_pictures (url TEXT PRIMARY KEY, vec BLOB NOT NULL)',
    'CREATE TABLE IF NOT EXISTS chanda_shop_facts (domain TEXT PRIMARY KEY, json TEXT NOT NULL, checked TEXT NOT NULL)',
  ];
}
