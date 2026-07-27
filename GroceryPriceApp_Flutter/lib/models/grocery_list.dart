class GroceryList {
  final int? id;
  final String name;
  final int createdAtMillis;

  GroceryList({
    this.id,
    required this.name,
    int? createdAtMillis,
  }) : createdAtMillis = createdAtMillis ?? DateTime.now().millisecondsSinceEpoch;

  GroceryList copyWithName(String newName) {
    return GroceryList(id: id, name: newName, createdAtMillis: createdAtMillis);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAtMillis': createdAtMillis,
    };
  }

  factory GroceryList.fromMap(Map<String, dynamic> map) {
    return GroceryList(
      id: map['id'] as int?,
      name: map['name'] as String,
      createdAtMillis: map['createdAtMillis'] as int,
    );
  }
}
