import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/grocery_list.dart';
import '../providers/lists_provider.dart';
import '../providers/shopping_list_provider.dart';
import '../providers/theme_provider.dart';
import 'shopping_list_screen.dart';

class ListsScreen extends StatelessWidget {
  const ListsScreen({super.key});

  Future<void> _showCreateDialog(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New list'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'List name (e.g. "Groceries")'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty && context.mounted) {
      final created = await context.read<ListsProvider>().createList(name);
      if (context.mounted) _openList(context, created);
    }
  }

  Future<void> _confirmDeleteList(BuildContext context, GroceryList list) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this list?'),
        content: Text('"${list.name}" and all its items will be removed. This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<ListsProvider>().deleteList(list);
    }
  }

  void _openList(BuildContext context, GroceryList list) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => ShoppingListProvider(listId: list.id!)..loadItems(),
          child: ShoppingListScreen(list: list),
        ),
      ),
    );
  }

  Future<void> _showThemeMenu(BuildContext context) async {
    final themeProvider = context.read<ThemeProvider>();
    final chosen = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.light_mode_outlined),
              title: const Text('Light'),
              onTap: () => Navigator.pop(context, ThemeMode.light),
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: const Text('Dark'),
              onTap: () => Navigator.pop(context, ThemeMode.dark),
            ),
            ListTile(
              leading: const Icon(Icons.settings_suggest_outlined),
              title: const Text('Match system'),
              onTap: () => Navigator.pop(context, ThemeMode.system),
            ),
          ],
        ),
      ),
    );
    if (chosen != null) themeProvider.setThemeMode(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ListsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Lists'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
            tooltip: 'Change theme',
            onPressed: () => _showThemeMenu(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add),
      ),
      body: provider.lists.isEmpty
          ? const Center(child: Text('No lists yet. Tap + to create one.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: provider.lists.length,
              itemBuilder: (context, index) {
                final list = provider.lists[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _openList(context, list),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.list_alt),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              list.name,
                              style: Theme.of(context).textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _confirmDeleteList(context, list),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
