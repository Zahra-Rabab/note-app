class ShoppingItem {
  final int? id;
  final int listId;
  final String name;       // canonical name if matched, otherwise what the user typed
  final String? unit;      // e.g. "1 L", "Dozen (12)" — null if unmatched/legacy item
  final int quantity;      // how many of that unit
  final double? unitPrice; // PKR per unit; null until fetched or entered
  final String? store;     // where the price came from, e.g. "Imtiaz" or "Multiple stores (avg)"
  final bool isChecked;

  ShoppingItem({
    this.id,
    required this.listId,
    required this.name,
    this.unit,
    this.quantity = 1,
    this.unitPrice,
    this.store,
    this.isChecked = false,
  });

  double get lineTotal => (unitPrice ?? 0) * quantity;

  ShoppingItem copyWith({
    int? id,
    int? listId,
    String? name,
    String? unit,
    int? quantity,
    double? unitPrice,
    String? store,
    bool? isChecked,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      store: store ?? this.store,
      isChecked: isChecked ?? this.isChecked,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'listId': listId,
      'name': name,
      'unit': unit,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'store': store,
      'isChecked': isChecked ? 1 : 0,
    };
  }

  factory ShoppingItem.fromMap(Map<String, dynamic> map) {
    return ShoppingItem(
      id: map['id'] as int?,
      listId: map['listId'] as int,
      name: map['name'] as String,
      unit: map['unit'] as String?,
      quantity: map['quantity'] as int,
      unitPrice: (map['unitPrice'] as num?)?.toDouble(),
      store: map['store'] as String?,
      isChecked: (map['isChecked'] as int) == 1,
    );
  }
}
