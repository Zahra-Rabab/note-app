import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AddItemDialog extends StatefulWidget {
  /// Called with (name, quantity, unit). [unit] is null if the item never
  /// matched a catalog product (still allowed — falls back to manual pricing).
  final void Function(String name, int quantity, String? unit) onAdd;

  /// Given the current text, looks up the product catalog. Returns null if
  /// the backend is unreachable (caller treats this as "no match available").
  final Future<ProductMatch?> Function(String query) onLookup;

  final String? initialName;
  final int? initialQuantity;
  final String? initialUnit;
  final String title;

  const AddItemDialog({
    super.key,
    required this.onAdd,
    required this.onLookup,
    this.initialName,
    this.initialQuantity,
    this.initialUnit,
    this.title = 'Add item',
  });

  @override
  State<AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<AddItemDialog> {
  late final TextEditingController _nameController;
  int _quantity = 1;

  Timer? _debounce;
  bool _isSearching = false;
  ProductMatch? _match;
  String? _selectedUnit;
  bool _wantsUnit = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _quantity = widget.initialQuantity ?? 1;
    _selectedUnit = widget.initialUnit;
    // When editing an existing item that has no unit, default to "no unit"
    // rather than forcing one on them.
    _wantsUnit = widget.initialName == null || widget.initialUnit != null;

    if (widget.initialName != null && widget.initialName!.isNotEmpty) {
      _runLookup(widget.initialName!);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _runLookup(value));
  }

  Future<void> _runLookup(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _match = null;
        _selectedUnit = null;
        _wantsUnit = true;
      });
      return;
    }
    setState(() => _isSearching = true);
    final result = await widget.onLookup(query);
    if (!mounted) return;
    setState(() {
      _isSearching = false;
      _match = result;
      if (result != null && result.matched) {
        _wantsUnit = true;
        _selectedUnit = result.defaultUnit;
      } else {
        _selectedUnit = null;
      }
    });
  }

  void _pickSuggestion(ProductMatch suggestion) {
    _nameController.text = suggestion.canonicalName!;
    setState(() {
      _match = suggestion;
      _selectedUnit = suggestion.defaultUnit;
    });
  }

  @override
  Widget build(BuildContext context) {
    final matched = _match?.matched == true;

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              onChanged: _onNameChanged,
              decoration: InputDecoration(
                labelText: 'Item name (any language — e.g. Milk, doodh, دودھ)',
                suffixIcon: _isSearching
                    ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
                    : null,
              ),
            ),
            const SizedBox(height: 10),

            if (matched) ...[
              Row(
                children: [
                  const Icon(Icons.check_circle, size: 16, color: Colors.green),
                  const SizedBox(width: 6),
                  Text('Matched: ${_match!.canonicalName}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: const Text('Pick a size/unit (needed for auto price fetch)',
                    style: TextStyle(fontSize: 13)),
                value: _wantsUnit,
                onChanged: (value) => setState(() {
                  _wantsUnit = value ?? true;
                  if (!_wantsUnit) _selectedUnit = null;
                  if (_wantsUnit && _selectedUnit == null) _selectedUnit = _match!.defaultUnit;
                }),
              ),
              if (_wantsUnit)
                DropdownButtonFormField<String>(
                  value: _selectedUnit,
                  decoration: const InputDecoration(labelText: 'Unit'),
                  items: _match!.units
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedUnit = value),
                )
              else
                const Text(
                  "Added as a plain note — no unit, so you'll set its price manually.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ] else if (_match != null && _match!.suggestions.isNotEmpty) ...[
              const Text('No exact match — did you mean:'),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: _match!.suggestions
                    .map((s) => ActionChip(
                  label: Text(s.canonicalName!),
                  onPressed: () => _pickSuggestion(s),
                ))
                    .toList(),
              ),
            ] else if (_nameController.text.trim().isNotEmpty && !_isSearching) ...[
              const Text(
                "No catalog match — this item will be added as-is. "
                    "You'll set its price manually.",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Quantity'),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                    ),
                    Text('$_quantity', style: const TextStyle(fontSize: 16)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => setState(() => _quantity++),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: _nameController.text.trim().isEmpty
              ? null
              : () {
            final unitToSend = _wantsUnit ? _selectedUnit : null;
            // IMPORTANT FIX: when the item matched a catalog product,
            // send the canonical name (e.g. "Tea", "Flour (Atta)"),
            // not whatever raw text the user typed (e.g. "tea", "atta").
            // The backend's prices.json and Alfatah's category matching
            // both key off the exact canonical name — sending raw user
            // text silently broke price fetching for anything not
            // typed with the exact same casing/wording as the catalog.
            final nameToSend = matched ? _match!.canonicalName! : _nameController.text;
            widget.onAdd(nameToSend, _quantity, unitToSend);
            Navigator.pop(context);
          },
          child: Text(widget.initialName != null ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}