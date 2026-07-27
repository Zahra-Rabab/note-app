import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/shopping_item.dart';
import '../models/grocery_list.dart';

class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'grocery_price.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE grocery_lists (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            createdAtMillis INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE shopping_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            listId INTEGER NOT NULL,
            name TEXT NOT NULL,
            unit TEXT,
            quantity INTEGER NOT NULL,
            unitPrice REAL,
            store TEXT,
            isChecked INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (listId) REFERENCES grocery_lists (id) ON DELETE CASCADE
          )
        ''');
        // A default list so a fresh install isn't empty of lists.
        await db.insert('grocery_lists', {
          'name': 'My Grocery List',
          'createdAtMillis': DateTime.now().millisecondsSinceEpoch,
        });
      },
    );
  }

  // ---------- Lists ----------

  Future<List<GroceryList>> getAllLists() async {
    final db = await database;
    final rows = await db.query('grocery_lists', orderBy: 'id ASC');
    return rows.map((r) => GroceryList.fromMap(r)).toList();
  }

  Future<int> insertList(GroceryList list) async {
    final db = await database;
    return db.insert('grocery_lists', list.toMap()..remove('id'));
  }

  Future<void> updateList(GroceryList list) async {
    final db = await database;
    await db.update('grocery_lists', list.toMap(), where: 'id = ?', whereArgs: [list.id]);
  }

  Future<void> deleteList(int listId) async {
    final db = await database;
    await db.delete('shopping_items', where: 'listId = ?', whereArgs: [listId]);
    await db.delete('grocery_lists', where: 'id = ?', whereArgs: [listId]);
  }

  // ---------- Items ----------

  Future<List<ShoppingItem>> getItemsForList(int listId) async {
    final db = await database;
    final rows = await db.query(
      'shopping_items',
      where: 'listId = ?',
      whereArgs: [listId],
      orderBy: 'id DESC',
    );
    return rows.map((r) => ShoppingItem.fromMap(r)).toList();
  }

  Future<int> insertItem(ShoppingItem item) async {
    final db = await database;
    return db.insert('shopping_items', item.toMap()..remove('id'));
  }

  Future<void> updateItem(ShoppingItem item) async {
    final db = await database;
    await db.update(
      'shopping_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> deleteItem(int id) async {
    final db = await database;
    await db.delete('shopping_items', where: 'id = ?', whereArgs: [id]);
  }
}
