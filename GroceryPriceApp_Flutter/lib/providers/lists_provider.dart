import 'package:flutter/foundation.dart';
import '../models/grocery_list.dart';
import '../services/database_service.dart';

class ListsProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;

  List<GroceryList> _lists = [];
  List<GroceryList> get lists => _lists;

  Future<void> loadLists() async {
    _lists = await _db.getAllLists();
    notifyListeners();
  }

  Future<GroceryList> createList(String name) async {
    final trimmed = name.trim().isEmpty ? 'New List' : name.trim();
    final id = await _db.insertList(GroceryList(name: trimmed));
    await loadLists();
    return _lists.firstWhere((l) => l.id == id);
  }

  Future<void> renameList(GroceryList list, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    await _db.updateList(list.copyWithName(trimmed));
    await loadLists();
  }

  Future<void> deleteList(GroceryList list) async {
    if (list.id == null) return;
    await _db.deleteList(list.id!);
    await loadLists();
  }
}
