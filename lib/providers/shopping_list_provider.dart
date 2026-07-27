import 'package:flutter/foundation.dart';
import '../models/shopping_item.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';

class ShoppingListProvider extends ChangeNotifier {
  final int listId;
  final DatabaseService _db = DatabaseService.instance;
  final ApiService _api = ApiService();

  ShoppingListProvider({required this.listId});

  List<ShoppingItem> _items = [];
  bool _isFetchingPrices = false;
  String? _errorMessage;

  List<ShoppingItem> get items => _items;
  bool get isFetchingPrices => _isFetchingPrices;
  String? get errorMessage => _errorMessage;

  double get billTotal => _items.fold(0.0, (sum, item) => sum + item.lineTotal);

  Future<void> loadItems() async {
    _items = await _db.getItemsForList(listId);
    notifyListeners();
  }

  /// Looks up a free-text item name against the product catalog.
  /// Returns null if the backend can't be reached — caller should fall back
  /// to treating it as a plain, unmatched item.
  Future<ProductMatch?> lookupProduct(String query) async {
    try {
      return await _api.matchProduct(query);
    } catch (_) {
      return null;
    }
  }

  /// Adds an item. If [unit] is provided (from a catalog match), it's stored
  /// alongside the name so pricing can look up the right unit later.
  /// Adding an item with the same name+unit that already exists just bumps
  /// its quantity instead of duplicating the row.
  Future<void> addItem(String name, int quantity, {String? unit}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final qty = quantity < 1 ? 1 : quantity;

    final existing = _items.where(
      (i) => i.name.toLowerCase() == trimmed.toLowerCase() && i.unit == unit,
    );
    if (existing.isNotEmpty) {
      final match = existing.first;
      await _db.updateItem(match.copyWith(quantity: match.quantity + qty));
    } else {
      await _db.insertItem(
        ShoppingItem(listId: listId, name: trimmed, unit: unit, quantity: qty),
      );
    }
    await loadItems();
  }

  Future<void> editItem(
    ShoppingItem item, {
    required String name,
    required int quantity,
    String? unit,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final updated = item.copyWith(
      name: trimmed,
      quantity: quantity < 1 ? 1 : quantity,
      unit: unit,
    );
    await _db.updateItem(updated);
    await loadItems();
  }

  Future<void> deleteItem(ShoppingItem item) async {
    if (item.id == null) return;
    await _db.deleteItem(item.id!);
    await loadItems();
  }

  Future<void> clearAllItems() async {
    for (final item in List<ShoppingItem>.from(_items)) {
      if (item.id != null) await _db.deleteItem(item.id!);
    }
    await loadItems();
  }

  Future<void> toggleChecked(ShoppingItem item) async {
    final updated = item.copyWith(isChecked: !item.isChecked);
    await _db.updateItem(updated);
    await loadItems();
  }

  Future<void> setManualPrice(ShoppingItem item, double price) async {
    final updated = item.copyWith(unitPrice: price, store: 'Manual');
    await _db.updateItem(updated);
    await loadItems();
  }

  /// Fetches approx (multi-store average) prices for every item that has a
  /// unit set. Items without a unit (added before a catalog match, or never
  /// matched) are skipped — they need a manual price.
  Future<void> fetchPricesForAllItems() async {
    final itemsWithUnit = _items.where((i) => i.unit != null).toList();
    if (itemsWithUnit.isEmpty) {
      _errorMessage = _items.isEmpty
          ? null
          : "None of your items have a matched unit yet, so there's nothing "
              "to auto-fetch. Edit an item and make sure it shows a green "
              "\"Matched\" checkmark with a unit selected.";
      notifyListeners();
      return;
    }
    _errorMessage = null;

    _isFetchingPrices = true;
    notifyListeners();

    try {
      for (final item in itemsWithUnit) {
        final result = await _api.fetchPrice(item.name, item.unit!);
        if (result.found && result.approxAverage != null) {
          final storeLabel = result.storePrices.length > 1
              ? '${result.storePrices.length} stores (avg)'
              : result.storePrices.first.store;
          await _db.updateItem(
            item.copyWith(unitPrice: result.approxAverage, store: storeLabel),
          );
        }
      }
      await loadItems();
    } catch (e) {
      _errorMessage = "Couldn't fetch prices — is the backend running? ($e)";
    } finally {
      _isFetchingPrices = false;
      notifyListeners();
    }
  }
}
