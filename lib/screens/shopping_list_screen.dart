import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/shopping_list_provider.dart';
import '../models/shopping_item.dart';
import '../models/grocery_list.dart';
import '../utils/currency.dart';
import '../widgets/add_item_dialog.dart';
import '../widgets/shopping_item_tile.dart';

class ShoppingListScreen extends StatelessWidget {
  final GroceryList list;

  const ShoppingListScreen({super.key, required this.list});

  Future<void> _confirmClearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear this list?'),
        content: const Text("This removes every item from this list. This can't be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<ShoppingListProvider>().clearAllItems();
    }
  }

  Future<bool> _confirmDelete(BuildContext context, ShoppingItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove item?'),
        content: Text('Remove "${item.name}" from your list?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _showEditDialog(BuildContext context, ShoppingItem item) {
    final provider = context.read<ShoppingListProvider>();
    showDialog(
      context: context,
      builder: (_) => AddItemDialog(
        initialName: item.name,
        initialQuantity: item.quantity,
        initialUnit: item.unit,
        title: 'Edit item',
        onLookup: provider.lookupProduct,
        onAdd: (name, qty, unit) => provider.editItem(item, name: name, quantity: qty, unit: unit),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final provider = context.read<ShoppingListProvider>();
    showDialog(
      context: context,
      builder: (_) => AddItemDialog(
        onLookup: provider.lookupProduct,
        onAdd: (name, qty, unit) => provider.addItem(name, qty, unit: unit),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShoppingListProvider>();
    final missingPriceCount = provider.items.where((i) => i.unitPrice == null).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(list.name),
        actions: [
          if (provider.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear all',
              onPressed: () => _confirmClearAll(context),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Approx. Bill', style: Theme.of(context).textTheme.labelMedium),
                      Text(
                        'Rs. ${formatPkr(provider.billTotal)}',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (provider.items.isNotEmpty)
                        Text(
                          '${provider.items.length} item(s)'
                          '${missingPriceCount > 0 ? ' · $missingPriceCount missing price' : ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                  FilledButton(
                    onPressed: provider.items.isEmpty || provider.isFetchingPrices
                        ? null
                        : () => context.read<ShoppingListProvider>().fetchPricesForAllItems(),
                    child: provider.isFetchingPrices
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Fetch Prices'),
                  ),
                ],
              ),
            ),
          ),
          if (provider.errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                provider.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: provider.items.isEmpty
                ? const Center(child: Text('Your list is empty. Tap + to add items.'))
                : ListView.separated(
                    itemCount: provider.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = provider.items[index];
                      return Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Theme.of(context).colorScheme.errorContainer,
                          child: const Icon(Icons.delete_outline),
                        ),
                        confirmDismiss: (_) => _confirmDelete(context, item),
                        onDismissed: (_) => context.read<ShoppingListProvider>().deleteItem(item),
                        child: ShoppingItemTile(
                          item: item,
                          onToggleChecked: () =>
                              context.read<ShoppingListProvider>().toggleChecked(item),
                          onEdit: () => _showEditDialog(context, item),
                          onDelete: () async {
                            final confirmed = await _confirmDelete(context, item);
                            if (confirmed && context.mounted) {
                              context.read<ShoppingListProvider>().deleteItem(item);
                            }
                          },
                          onPriceEdited: (price) =>
                              context.read<ShoppingListProvider>().setManualPrice(item, price),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
