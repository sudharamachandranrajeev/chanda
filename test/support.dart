import 'package:brahma_core/brahma_core.dart';
import 'package:chanda/db/database.dart';
import 'package:chanda/domain/reading.dart';
import 'package:chanda/domain/vault.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// A fresh in-memory database (the bundled SQLite3MultipleCiphers works
/// unkeyed in memory).
AppDatabase memoryDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}

/// A vault over a fresh in-memory database.
Future<Vault> memoryVault() async => Vault(await Store.open(memoryDatabase()));

/// A product page reading, as the reader would give it.
Reading reading({
  String url = 'https://www.amazon.co.uk/dp/B000000001',
  String title = 'Desk lamp',
  int? price = 4599,
  String currency = 'GBP',
  bool inStock = true,
  bool check = false,
}) => Reading(url: url, title: title, price: price, currency: currency, inStock: inStock, check: check);

/// Saves [r] into the default list and returns the stored item.
Future<VaultItem> saved(Vault v, Reading r, {int? target}) async {
  final id = await v.saveReading(r, listId: await v.defaultList(), target: target);
  return (await v.item(id))!;
}
