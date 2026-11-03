/// The four aisles of the shop. The key is what the form's picker stores; the label is what it shows.
enum Category {
  kitchen('Kitchen'),
  desk('Desk'),
  garden('Garden'),
  home('Home');

  const Category(this.label);

  final String label;

  String get key => name;
}

/// Which drawing from `art/glyphs` an item wears.
enum Glyph { mug, notebook, plant, candle, lamp, bottle, clock, tote, pen, bowl }

class Item {
  const Item(this.id, this.name, this.category, this.glyph, this.priceCents, this.description);

  final int id;
  final String name;
  final Category category;
  final Glyph glyph;
  final int priceCents;
  final String description;

  /// "No. 007": the item number every screen shows.
  String get number => itemNumber(id);
}

String itemNumber(int id) => 'No. ${id.toString().padLeft(3, '0')}';

/// Fixed US-dollar prices, so every run and every framework shows the same text: "\$14.00".
String formatPrice(int cents) => '\$${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';

/// The seeded catalogue: forty invented items, identical in every Mossgrove app (SPEC.md §3). Nothing is fetched; the
/// order here is the order of the list.
abstract final class Catalog {
  static const List<Item> items = [
    Item(
      1,
      'Stoneware Mug',
      Category.kitchen,
      Glyph.mug,
      1400,
      'A heavy, speckled mug that keeps tea warm through a long call.',
    ),
    Item(
      2,
      'Grid Notebook',
      Category.desk,
      Glyph.notebook,
      950,
      'Ninety-six pages of 5 mm grid, stitched to lie flat.',
    ),
    Item(
      3,
      'Desk Fern',
      Category.garden,
      Glyph.plant,
      1800,
      'A small fern in a glazed pot. Likes shade and a weekly drink.',
    ),
    Item(
      4,
      'Cedar Candle',
      Category.home,
      Glyph.candle,
      1600,
      'Soy wax with a dry cedar scent. Burns for about forty hours.',
    ),
    Item(
      5,
      'Brass Desk Lamp',
      Category.desk,
      Glyph.lamp,
      4200,
      'A warm, low lamp with a brass shade and a fabric cable.',
    ),
    Item(
      6,
      'Steel Water Bottle',
      Category.kitchen,
      Glyph.bottle,
      2400,
      'Double-walled steel. Cold for a day, hot for half of one.',
    ),
    Item(7, 'Wall Clock', Category.home, Glyph.clock, 3500, 'A quiet sweep movement behind a plain white face.'),
    Item(8, 'Canvas Tote', Category.home, Glyph.tote, 2200, 'Heavy canvas with long handles and one inside pocket.'),
    Item(9, 'Fineliner Pen Set', Category.desk, Glyph.pen, 1200, 'Six fineliners in muted inks, 0.4 mm tips.'),
    Item(10, 'Serving Bowl', Category.kitchen, Glyph.bowl, 2800, 'A wide stoneware bowl for salads, fruit or bread.'),
    Item(
      11,
      'Espresso Cup Pair',
      Category.kitchen,
      Glyph.mug,
      1900,
      'Two small cups with thick walls and saucers to match.',
    ),
    Item(12, 'Dot Journal', Category.desk, Glyph.notebook, 1100, 'Dotted pages, numbered, with two ribbon markers.'),
    Item(
      13,
      'Succulent Trio',
      Category.garden,
      Glyph.plant,
      2100,
      'Three hardy succulents that forgive a missed watering.',
    ),
    Item(
      14,
      'Fig Leaf Candle',
      Category.home,
      Glyph.candle,
      1750,
      'Green and milky. Smells like a fig tree after rain.',
    ),
    Item(
      15,
      'Clip Reading Lamp',
      Category.desk,
      Glyph.lamp,
      2900,
      'Clips to a shelf or a bed frame. Three brightness steps.',
    ),
    Item(
      16,
      'Glass Carafe',
      Category.kitchen,
      Glyph.bottle,
      2600,
      'A litre of water on the table, with a cup for a lid.',
    ),
    Item(17, 'Alarm Clock', Category.home, Glyph.clock, 2300, 'A silent tick and a gentle rising alarm.'),
    Item(18, 'Market Bag', Category.home, Glyph.tote, 1500, 'Folds into its own pocket. Holds a week of vegetables.'),
    Item(19, 'Fountain Pen', Category.desk, Glyph.pen, 3800, 'A steel nib, a converter, and a box of blue cartridges.'),
    Item(20, 'Salad Bowl', Category.kitchen, Glyph.bowl, 3200, 'Oiled wood, turned from one piece.'),
    Item(21, 'Travel Mug', Category.kitchen, Glyph.mug, 1800, 'Leak-proof lid, fits a car\'s cup holder.'),
    Item(22, 'Sketchbook', Category.desk, Glyph.notebook, 1350, 'Heavy blank paper that takes ink and light washes.'),
    Item(
      23,
      'Herb Planter',
      Category.garden,
      Glyph.plant,
      2700,
      'A long planter for a sunny sill. Seeds not included.',
    ),
    Item(
      24,
      'Beeswax Taper Set',
      Category.home,
      Glyph.candle,
      1450,
      'Four hand-dipped tapers that burn clean and slow.',
    ),
    Item(25, 'Floor Lamp', Category.home, Glyph.lamp, 8900, 'A tall arc of steel with a linen shade.'),
    Item(26, 'Oil Bottle', Category.kitchen, Glyph.bottle, 1250, 'A pourer that stops dripping when you stop pouring.'),
    Item(27, 'Desk Clock', Category.desk, Glyph.clock, 3100, 'A small square clock with a date window.'),
    Item(28, 'Laptop Tote', Category.desk, Glyph.tote, 3600, 'A padded sleeve with handles for a 14-inch laptop.'),
    Item(29, 'Brush Pen', Category.desk, Glyph.pen, 750, 'A soft tip for lettering and quick sketches.'),
    Item(30, 'Noodle Bowl', Category.kitchen, Glyph.bowl, 1600, 'Deep enough for broth, with a rest for chopsticks.'),
    Item(31, 'Tea Mug', Category.kitchen, Glyph.mug, 1500, 'A tall mug with a steel infuser that sits inside.'),
    Item(32, 'Pocket Notebook', Category.desk, Glyph.notebook, 600, 'Fits a back pocket. Ruled, sixty-four pages.'),
    Item(
      33,
      'Hanging Planter',
      Category.garden,
      Glyph.plant,
      2450,
      'A glazed pot on a cotton rope, for trailing plants.',
    ),
    Item(34, 'Pine Candle', Category.home, Glyph.candle, 1600, 'Resin and needles. Best on a cold evening.'),
    Item(35, 'Bedside Lamp', Category.home, Glyph.lamp, 4500, 'A touch dimmer and a shade that does not glare.'),
    Item(36, 'Vacuum Flask', Category.kitchen, Glyph.bottle, 2950, 'Keeps soup hot from breakfast until lunch.'),
    Item(
      37,
      'Kitchen Timer',
      Category.kitchen,
      Glyph.clock,
      1950,
      'A wind-up timer with a bell you can hear upstairs.',
    ),
    Item(38, 'Beach Tote', Category.home, Glyph.tote, 2500, 'Striped cotton that shakes clean of sand.'),
    Item(39, 'Pencil Set', Category.desk, Glyph.pen, 850, 'Twelve graphite pencils, 4H to 6B.'),
    Item(40, 'Fruit Bowl', Category.kitchen, Glyph.bowl, 3400, 'A wire bowl that lets fruit breathe.'),
  ];

  static final Map<int, Item> _byId = {for (final item in items) item.id: item};

  static Item? find(int id) => _byId[id];

  /// Search by name (case-insensitive, anywhere in the name) or by number: "7", "007" and "No. 007" all find item 7.
  /// A blank query matches everything.
  static List<Item> search(String query) {
    final q = query.trim();
    if (q.isEmpty) return items;
    final lower = q.toLowerCase();
    final digits = (lower.startsWith('no.') ? q.substring(3) : q).trim();
    final number = digits.isNotEmpty && RegExp(r'^[0-9]+$').hasMatch(digits) ? int.tryParse(digits) : null;
    return [
      for (final item in items)
        if (item.name.toLowerCase().contains(lower) || (number != null && item.id == number)) item,
    ];
  }
}
