import 'package:brahma_core/brahma_core.dart';
import 'package:flutter/material.dart';

import '../ui/alerts_page.dart';
import '../ui/search_page.dart';
import '../ui/shops_page.dart';
import '../ui/vault_page.dart';
import 'settings_page.dart';

Destination _d(String id, String label, IconData icon, IconData selected, Widget page) =>
    Destination(id: id, label: label, icon: icon, selectedIcon: selected, primary: true, page: (_) => page);

final shoppingModule = AppModule(
  id: 'shopping',
  name: 'Shopping',
  destinations: [
    _d('vault', 'Vault', Icons.favorite_border, Icons.favorite, const VaultPage()),
    _d('search', 'Search', Icons.search, Icons.manage_search, const SearchPage()),
    _d('alerts', 'Alerts', Icons.notifications_none, Icons.notifications, const AlertsPage()),
    _d('shops', 'Shops', Icons.storefront_outlined, Icons.storefront, const ShopsPage()),
  ],
);

final modules = <AppModule>[shoppingModule];

/// Settings is app-wide, so it comes after every module's screens.
final settingsDestination = _d(
  'settings',
  'Settings',
  Icons.settings_outlined,
  Icons.settings,
  const SettingsPage(),
);

List<Destination> get allDestinations => [for (final m in modules) ...m.destinations, settingsDestination];
