import 'package:flutter/foundation.dart';

import 'catalog.dart';

/// The Lobby (SPEC.md §5, new in 1.1): its names, numbers and texts. The screen only draws them.
abstract final class Lobby {
  static const banners = 5;
  static const rows = 4;
  static const tiles = 20;
  static const gridCells = 12;
  static const innerLines = 30;
  static const board = 26;

  /// The Top 10 row: fixed, outside the page, under the pager (or in its place when the pager is off).
  static const topTiles = 10;

  /// The Top 10 row's number where a row is asked for: it is not one of the page's rows 1–4.
  static const topRow = 0;

  /// "Saved appears after": the choices, in seconds. 0 is the default; SPEC.md §5 says why each one.
  static const delays = [0, 3, 6, 12, 20];

  /// Auto-advance moves the pager every 4 s when it is on.
  static const autoAdvance = Duration(seconds: 4);

  static const bannerTitles = [
    'New in the Kitchen aisle',
    'Warm, low desk lamps',
    'Ferns that like the shade',
    'Candles for long evenings',
    'Totes for market day',
  ];

  static const chips = [
    'All',
    'Kitchen',
    'Desk',
    'Garden',
    'Home',
    'Under \$20',
    'Under \$40',
    'New',
    'Gifts',
    'Sets',
    'Lamps',
    'Candles',
  ];

  static const barItems = ['Home', 'Live', 'Saved', 'Offers'];
  static const sheetButtons = ['Open', 'Preview', 'Saved', 'Rate'];

  static const touchLogLabel = 'Touch log';
  static const nothingTouched = 'Nothing touched';
  static const reset = 'Reset';
  static const savedAppearsAfter = 'Saved appears after';
  static const showThePager = 'Show the pager';
  static const autoAdvanceLabel = 'Auto-advance';
  static const aTestBanner = 'A test banner';
  static const gridHeading = 'Grid';
  static const innerListHeading = 'Inner list';
  static const footer = 'End of the lobby';
  static const footerNote = 'A test bench: nothing here is for sale.';
  static const promoNote = 'A test banner. Nothing here is for sale.';
  static const backToLobby = 'Back to the lobby';
  static const savedEmpty = 'Saved: nothing yet';

  /// Tile [m] of row [n] (both from 1) shows item ((n − 1) × 10 + m − 1) mod 40 + 1.
  static Item tileItem(int row, int tile) => Catalog.items[((row - 1) * 10 + tile - 1) % Catalog.items.length];

  /// Tile [m] (from 1) of the Top 10 row shows item m + 30: No. 031 to No. 040.
  static Item topItem(int tile) => Catalog.items[tile + 29];

  /// The item a tile shows, for a row from 1 to 4 or [topRow].
  static Item itemAt(int row, int tile) => row == topRow ? topItem(tile) : tileItem(row, tile);

  /// Grid cell [n] (from 1) shows item n + 28.
  static Item gridItem(int cell) => Catalog.items[cell + 27];

  /// "A1" … "Z26": column letter, then row number, both from 1.
  static String boardLabel(int col, int row) => '${String.fromCharCode(64 + col)}$row';

  /// The choices' labels, as SPEC.md §6 writes them.
  static const delayLabels = ['0 s', '3 s', '6 s', '12 s', '20 s'];

  static String delayLabel(int seconds) => delayLabels[delays.indexOf(seconds)];

  static String pagerPosition(int page) => 'Banner $page of $banners';

  /// The first and last fully visible tiles of a row; [first] alone when only one is.
  static String rowPosition(int row, int first, int last) =>
      last <= first ? 'Row $row: tile $first of $tiles' : 'Row $row: tiles $first–$last of $tiles';

  /// "Top 10: tiles 1–3 of 10"; [first] alone when only one is fully visible.
  static String topRowPosition(int first, int last) =>
      last <= first ? 'Top 10: tile $first of $topTiles' : 'Top 10: tiles $first–$last of $topTiles';

  /// The detail's place line: "Row 3, tile 15", or "Top 10, tile 2".
  static String detailPlace(int row, int tile) => row == topRow ? 'Top 10, tile $tile' : 'Row $row, tile $tile';

  /// Where the log says a tile was touched: "row 3, tile 15" or "top row, tile 2".
  static String tileWhere(int row, int tile) => row == topRow ? 'top row, tile $tile' : 'row $row, tile $tile';

  static String boardPosition(int col, int row) => 'Board: top-left ${boardLabel(col, row)}';

  static String innerLine(int n) => 'Line $n of $innerLines';
}

/// How a touch came: the words each line of the touch log starts with.
enum Touch {
  tap('Tapped'),
  longPress('Long-pressed'),
  doubleTap('Double-tapped');

  const Touch(this.words);

  final String words;
}

/// The Lobby's oracle: every tap, long press and double tap on a touchable element, newest first. It shows at most
/// three lines; the count keeps every touch since the last reset. Nothing that scrolls writes here.
class TouchLog extends ChangeNotifier {
  List<String> _lines = const [];
  int _count = 0;

  List<String> get lines => _lines;

  int get count => _count;

  String get text => _lines.isEmpty ? Lobby.nothingTouched : _lines.join('\n');

  String get countText => 'Touches: $_count';

  void add(Touch touch, String what, String where) {
    _lines = ['${touch.words}: $what ($where)', ..._lines].take(3).toList();
    _count++;
    notifyListeners();
  }

  void reset() {
    _lines = const [];
    _count = 0;
    notifyListeners();
  }
}
