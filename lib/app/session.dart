import 'package:brahma_core/brahma_core.dart';

import '../db/database.dart';
import '../domain/vault.dart';

/// Chanda in Brahma's terms: the app's id, name and Android package.
const chandaIdentity = AppIdentity(
  id: 'chanda',
  name: 'Chanda',
  androidPackage: 'dev.brahma.chanda',
  releases: 'sudharamachandranrajeev/chanda-shopping-assistant',
);

/// Everything a running app needs: keys, the encrypted database and the
/// vault on top of it. Opened once at start-up (and by background checks).
class AppSession extends CoreSession {
  AppSession(super.keys, super.store, this.vault, {super.deviceName});

  final Vault vault;

  @override
  AppDatabase get db => store.db as AppDatabase;

  static Future<AppSession> open(KeyVault keys) => CoreSession.open(
    chandaIdentity,
    keys,
    openDatabase: AppDatabase.open,
    build: (store, deviceName) => AppSession(keys, store, Vault(store), deviceName: deviceName),
  );
}
