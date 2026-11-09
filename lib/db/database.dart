import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart';

import 'tables.dart';

export 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [ChandaLists, ChandaItems, ChandaPrices, ChandaAlerts, Prefs, Outbox, SyncCursors, LocalSettings],
)
class AppDatabase extends _$AppDatabase with SyncedDatabase {
  AppDatabase(super.e);

  /// Opens Chanda's encrypted database (see [openEncryptedDatabase]).
  AppDatabase.open(String key) : this(openEncryptedDatabase('chanda', key));

  @override
  final syncedTables = const ['chanda_lists', 'chanda_items', 'chanda_prices', 'chanda_alerts', 'prefs'];

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      for (final sql in _indexes) {
        await customStatement(sql);
      }
    },
  );

  static const _indexes = [
    'CREATE INDEX chanda_items_list ON chanda_items (list_id)',
    'CREATE INDEX chanda_prices_item ON chanda_prices (item_id, seen)',
    'CREATE INDEX chanda_alerts_item ON chanda_alerts (item_id)',
  ];
}
