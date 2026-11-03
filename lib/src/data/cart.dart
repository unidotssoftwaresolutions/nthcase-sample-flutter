import 'catalog.dart';

class CartLine {
  const CartLine(this.itemId, this.quantity);

  final int itemId;
  final int quantity;

  Item get item => Catalog.find(itemId)!;

  int get totalCents => item.priceCents * quantity;
}

class Order {
  Order(this.number, List<CartLine> lines) : lines = List.unmodifiable(lines);

  final int number;
  final List<CartLine> lines;

  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);

  int get totalCents => lines.fold(0, (sum, line) => sum + line.totalCents);
}

/// The cart: one line per item, in the order items were first added. Quantities stay within 1–9.
class Cart {
  static const minQuantity = 1;
  static const maxQuantity = 9;

  final List<CartLine> _lines = [];

  List<CartLine> get lines => List.unmodifiable(_lines);

  bool get isEmpty => _lines.isEmpty;

  int get itemCount => _lines.fold(0, (sum, line) => sum + line.quantity);

  int get totalCents => _lines.fold(0, (sum, line) => sum + line.totalCents);

  int quantityOf(int itemId) => _lines.where((l) => l.itemId == itemId).firstOrNull?.quantity ?? 0;

  void add(int itemId, int quantity) {
    if (Catalog.find(itemId) == null) throw ArgumentError('No item $itemId');
    final index = _lines.indexWhere((l) => l.itemId == itemId);
    if (index < 0) {
      _lines.add(CartLine(itemId, quantity.clamp(minQuantity, maxQuantity)));
    } else {
      _lines[index] = CartLine(itemId, (_lines[index].quantity + quantity).clamp(minQuantity, maxQuantity));
    }
  }

  void setQuantity(int itemId, int quantity) {
    final index = _lines.indexWhere((l) => l.itemId == itemId);
    if (index >= 0) _lines[index] = CartLine(itemId, quantity.clamp(minQuantity, maxQuantity));
  }

  void remove(int itemId) => _lines.removeWhere((l) => l.itemId == itemId);

  void clear() => _lines.clear();
}
