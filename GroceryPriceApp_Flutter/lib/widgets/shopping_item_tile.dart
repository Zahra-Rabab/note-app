import 'package:flutter/material.dart';
import '../models/shopping_item.dart';
import '../utils/currency.dart';

class ShoppingItemTile extends StatefulWidget {
  final ShoppingItem item;
  final VoidCallback onToggleChecked;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(double price) onPriceEdited;

  const ShoppingItemTile({
    super.key,
    required this.item,
    required this.onToggleChecked,
    required this.onEdit,
    required this.onDelete,
    required this.onPriceEdited,
  });

  @override
  State<ShoppingItemTile> createState() => _ShoppingItemTileState();
}

class _ShoppingItemTileState extends State<ShoppingItemTile> {
  bool _editingPrice = false;
  late TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(text: widget.item.unitPrice?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant ShoppingItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editingPrice && oldWidget.item.unitPrice != widget.item.unitPrice) {
      _priceController.text = widget.item.unitPrice?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final subtitleParts = <String>[
      'Qty: ${item.quantity}${item.unit != null ? ' × ${item.unit}' : ''}',
      if (item.store != null) 'Source: ${item.store}',
    ];

    return ListTile(
      leading: Checkbox(value: item.isChecked, onChanged: (_) => widget.onToggleChecked()),
      title: Text(
        item.name,
        style: TextStyle(
          decoration: item.isChecked ? TextDecoration.lineThrough : null,
          color: item.isChecked ? Theme.of(context).disabledColor : null,
        ),
      ),
      subtitle: Text(subtitleParts.join(' · ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_editingPrice)
            SizedBox(
              width: 110,
              child: TextField(
                controller: _priceController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(prefixText: 'Rs. '),
                onSubmitted: (_) => _savePrice(),
              ),
            )
          else
            TextButton(
              onPressed: () => setState(() => _editingPrice = true),
              child: Text(
                item.unitPrice != null ? 'Rs. ${formatPkr(item.lineTotal)}' : 'Set price',
              ),
            ),
          if (_editingPrice)
            IconButton(icon: const Icon(Icons.check), onPressed: _savePrice)
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'edit') widget.onEdit();
                if (value == 'delete') widget.onDelete();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit item')),
                PopupMenuItem(value: 'delete', child: Text('Delete item')),
              ],
            ),
        ],
      ),
    );
  }

  void _savePrice() {
    final price = double.tryParse(_priceController.text);
    if (price != null && price >= 0) {
      widget.onPriceEdited(price);
    }
    setState(() => _editingPrice = false);
  }
}
