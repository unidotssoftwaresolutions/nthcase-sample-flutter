import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../data/lobby.dart';
import '../../ids.dart';
import '../art.dart';
import '../board_view.dart';
import '../components.dart';
import '../theme.dart';

/// What takes the place of the pager, the Top 10 row and the page (SPEC.md §5, Lobby › Panels).
sealed class _Panel {
  const _Panel();
}

/// [row] 1–4, or [Lobby.topRow] for the Top 10 row.
final class _Detail extends _Panel {
  const _Detail(this.row, this.tile);

  final int row;
  final int tile;
}

final class _Promo extends _Panel {
  const _Promo(this.banner);

  final int banner;
}

final class _Saved extends _Panel {
  const _Saved();
}

/// Width of a tile, and the gap and side padding of every horizontal row (SPEC.md §5: about 100 wide).
const _tileWidth = 100.0;
const _tileGap = 8.0;
const _rowPadding = 16.0;

/// The Top 10 row: a band 100 × 64, then the name.
const _topRowHeight = 92.0;

/// A page row: the 100 × 100 drawing, the name and the number.
const _pageRowHeight = 144.0;

const _boardCell = 56.0;

/// The Lobby (SPEC.md §5, new in 1.1): a test bench for scrolling. Top to bottom, and in the semantics tree in that
/// order: the touch log, the delay choice with Show the pager, the promo pager (a `PageView`), the Top 10 row (a
/// horizontal `ListView`), the page (a vertical `ListView`) and the Lobby's own bar.
///
/// The pager and the Top 10 row sit above the page, not in it: a scroller's node comes before its children's, so a
/// scroller inside the page could never be the first in the tree. With Show the pager off the pager and its position
/// line are not built at all, so no node of theirs is left. Saved is not built until its delay has passed.
///
/// Every touch is Flutter's own: a `GestureDetector` with `onTap`, `onLongPress` and `onDoubleTap`, whose recognizers
/// decide what a moving finger is. The Lobby adds no rule of its own; it only writes the log line.
class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final _log = TouchLog();
  _Panel? _panel;
  String _barSelected = 'Home';
  int _chip = 1;
  bool _auto = false;
  bool _savedShown = true;
  Timer? _savedTimer;
  Timer? _autoTimer;

  /// Every scroll position of one visit. The panels are drawn over the scrollers, which stay built but offstage, so
  /// that closing a panel finds each one where it was.
  int _banner = 1;
  late PageController _pager = PageController();
  final _top = ScrollController();
  final _page = ScrollController();
  final _chips = ScrollController();
  final _rows = List.generate(Lobby.rows, (_) => ScrollController());
  final _inner = ScrollController();
  final _boardX = ScrollController();
  final _boardY = ScrollController();

  late AppState _state;

  @override
  void initState() {
    super.initState();
    _state = AppScope.read(context).notifier!;
    _startSavedCount();
  }

  /// Saved appears late: absent from the tree until the delay has passed. The count starts when the Lobby opens and
  /// again when a delay is chosen.
  void _startSavedCount() {
    _savedTimer?.cancel();
    final seconds = _state.lobbySavedDelay;
    _savedShown = seconds == 0;
    if (!_savedShown) {
      _savedTimer = Timer(Duration(seconds: seconds), () {
        if (mounted) setState(() => _savedShown = true);
      });
    }
  }

  void _chooseDelay(int seconds) {
    _state.lobbySavedDelay = seconds;
    setState(_startSavedCount);
  }

  void _showPager(bool on) {
    if (on) {
      // back on the banner it showed
      _pager.dispose();
      _pager = PageController(initialPage: _banner - 1);
    }
    _state.lobbyPagerShown = on;
  }

  void _setAuto(bool on) {
    setState(() => _auto = on);
    _autoTimer?.cancel();
    if (on) {
      _autoTimer = Timer.periodic(Lobby.autoAdvance, (_) {
        if (!_pager.hasClients || _panel != null) return;
        _pager.animateToPage(_banner % Lobby.banners, duration: const Duration(milliseconds: 300), curve: Curves.ease);
      });
    }
  }

  @override
  void dispose() {
    _savedTimer?.cancel();
    _autoTimer?.cancel();
    for (final c in [_pager, _top, _page, _chips, ..._rows, _inner, _boardX, _boardY]) {
      c.dispose();
    }
    _log.dispose();
    super.dispose();
  }

  void _open(_Panel panel) => setState(() => _panel = panel);

  void _close() => setState(() => _panel = null);

  bool get _panelWithBack => _panel is _Detail || _panel is _Promo;

  void _sheet(String title, _Panel opens) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _QuickSheet(
        title: title,
        onButton: (label) {
          _log.add(Touch.tap, label, 'quick sheet, $title');
          Navigator.of(sheetContext).pop();
          if (label == 'Open') _open(opens);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return PopScope(
      canPop: !_panelWithBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _panelWithBack) _close();
      },
      child: Id(
        TestIds.lobbyScreen,
        region: true,
        child: Scaffold(
          appBar: TopBar('Lobby', onBack: () => _panelWithBack ? _close() : state.back()),
          bottomNavigationBar: _bar(context),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TouchLogBlock(_log),
              _DelayChoice(
                selected: state.lobbySavedDelay,
                onChoose: _chooseDelay,
                pagerShown: state.lobbyPagerShown,
                onPagerShown: _showPager,
              ),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // offstage, the scrollers keep their places and send no node to the platform
                    Offstage(
                      offstage: _panel != null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (state.lobbyPagerShown) ...[
                            _PagerBlock(
                              controller: _pager,
                              banner: _banner,
                              onBanner: (n) => setState(() => _banner = n),
                              auto: _auto,
                              onAuto: _setAuto,
                              log: _log,
                              onPromo: (n) => _open(_Promo(n)),
                              onSheet: (n) => _sheet(Lobby.bannerTitles[n - 1], _Promo(n)),
                            ),
                          ],
                          _TopRow(
                            controller: _top,
                            log: _log,
                            onDetail: (m) => _open(_Detail(Lobby.topRow, m)),
                            onSheet: (m) => _sheet(Lobby.topItem(m).name, _Detail(Lobby.topRow, m)),
                          ),
                          Expanded(child: _pageView()),
                        ],
                      ),
                    ),
                    if (_panel case final panel?) _panelView(panel),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Saved is left out of the bar, not hidden: until its delay has passed, the tree has no node for it
    final shown = [
      for (final label in Lobby.barItems)
        if (label != 'Saved' || _savedShown) label,
    ];
    final selected = shown.indexOf(_barSelected);
    return Id(
      TestIds.lobbyBar,
      region: true,
      child: NavigationBar(
        selectedIndex: selected < 0 ? 0 : selected,
        onDestinationSelected: (index) {
          final label = shown[index];
          _log.add(Touch.tap, label, 'bar');
          setState(() {
            _barSelected = label;
            _panel = label == 'Saved' ? const _Saved() : null;
          });
        },
        destinations: [
          for (final label in shown)
            NavigationDestination(
              // NavigationBar merges each destination into one node, so the id lands on the item's own node
              icon: Semantics(
                identifier: TestIds.lobbyBarItems[Lobby.barItems.indexOf(label)],
                child: ArtIcon(_barIcon(label), color: scheme.onSurfaceVariant),
              ),
              label: label,
            ),
        ],
      ),
    );
  }

  static ArtDrawing _barIcon(String label) => switch (label) {
    'Home' => Art.shop,
    'Live' => Art.eye,
    'Saved' => Art.check,
    _ => Art.cart,
  };

  Widget _pageView() => Id(
    TestIds.lobbyPage,
    region: true,
    child: ListView(
      controller: _page,
      children: [
        _Chips(controller: _chips, log: _log, selected: _chip, onSelect: (n) => setState(() => _chip = n)),
        for (var row = 1; row <= Lobby.rows; row++)
          _TileRow(
            row: row,
            controller: _rows[row - 1],
            log: _log,
            onDetail: (m) => _open(_Detail(row, m)),
            onSheet: (m) => _sheet(Lobby.tileItem(row, m).name, _Detail(row, m)),
          ),
        _Grid(_log),
        _InnerList(controller: _inner, log: _log),
        _Board(x: _boardX, y: _boardY, log: _log),
        Id(
          TestIds.lobbyFooter,
          child: Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 48),
            child: Column(
              children: [
                Text(Lobby.footer, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  Lobby.footerNote,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _panelView(_Panel panel) {
    final theme = Theme.of(context);
    Widget column(String id, List<Widget> children) => Id(
      id,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, spacing: 8, children: children),
        ),
      ),
    );
    Widget back(String id) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: IdControl(
        id,
        child: OutlinedButton(onPressed: _close, child: const Text(Lobby.backToLobby)),
      ),
    );
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: switch (panel) {
        _Detail(:final row, :final tile) => () {
          final item = Lobby.itemAt(row, tile);
          return column(TestIds.lobbyDetail, [
            GlyphTile(item, size: 96, label: 'Drawing of the ${item.name}'),
            Text(item.name, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
            ItemNumber(item),
            Text(Lobby.detailPlace(row, tile), style: theme.textTheme.bodyMedium),
            back(TestIds.lobbyDetailBack),
          ]);
        }(),
        _Promo(:final banner) => column(TestIds.lobbyPromo, [
          Text(Lobby.bannerTitles[banner - 1], style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          Text(Lobby.pagerPosition(banner), style: theme.textTheme.labelLarge),
          Text(Lobby.promoNote, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
          back(TestIds.lobbyPromoBack),
        ]),
        _Saved() => column(TestIds.lobbySavedScreen, [
          ArtIcon(Art.check, size: 40, color: theme.colorScheme.onSurfaceVariant),
          Text(Lobby.savedEmpty, style: theme.textTheme.titleLarge),
        ]),
      },
    );
  }
}

/// A touchable thing of the Lobby: Flutter's own tap, long press and double tap, and a log line for each. A tap is
/// decided once the double-tap time has passed with no second tap, so a double tap is one line, not two taps.
class _Touchable extends StatelessWidget {
  const _Touchable({
    required this.log,
    required this.what,
    required this.where,
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  final TouchLog log;
  final String what;
  final String where;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () {
      log.add(Touch.tap, what, where);
      onTap?.call();
    },
    onLongPress: () {
      log.add(Touch.longPress, what, where);
      onLongPress?.call();
    },
    onDoubleTap: () => log.add(Touch.doubleTap, what, where),
    child: child,
  );
}

class _TouchLogBlock extends StatelessWidget {
  const _TouchLogBlock(this.log);

  final TouchLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListenableBuilder(
      listenable: log,
      builder: (context, _) => ColoredBox(
        color: scheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 8, top: 8, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Lobby.touchLogLabel,
                      style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    Id(
                      TestIds.lobbyTouchLog,
                      child: SizedBox(
                        height: 48,
                        child: Text(
                          log.text,
                          style: theme.textTheme.bodySmall,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Id(TestIds.lobbyTouchCount, child: Text(log.countText, style: theme.textTheme.labelMedium)),
                  ),
                  IdControl(
                    TestIds.lobbyTouchReset,
                    child: TextButton(onPressed: log.reset, child: const Text(Lobby.reset)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A switch with its label, one node with the id, the label, the on/off state and the tap; the drawn switch says
/// nothing of its own (the app's ToggleRow, made compact to share a line).
class _CompactSwitch extends StatelessWidget {
  const _CompactSwitch({required this.id, required this.label, required this.value, required this.onChanged});

  final String id;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    identifier: id,
    toggled: value,
    enabled: true,
    child: InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(width: 8),
            ExcludeSemantics(
              child: Transform.scale(
                scale: 0.8,
                child: Switch(value: value, onChanged: onChanged),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DelayChoice extends StatelessWidget {
  const _DelayChoice({
    required this.selected,
    required this.onChoose,
    required this.pagerShown,
    required this.onPagerShown,
  });

  final int selected;
  final ValueChanged<int> onChoose;
  final bool pagerShown;
  final ValueChanged<bool> onPagerShown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  Lobby.savedAppearsAfter,
                  style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              _CompactSwitch(
                id: TestIds.lobbyPagerShown,
                label: Lobby.showThePager,
                value: pagerShown,
                onChanged: onPagerShown,
              ),
            ],
          ),
          // five segments, each one node with its own id, its label and its selected state
          Id(
            TestIds.lobbySavedDelay,
            region: true,
            child: Row(
              children: [
                for (final (i, seconds) in Lobby.delays.indexed)
                  Expanded(
                    child: IdControl(
                      TestIds.lobbySavedDelayChoice(seconds),
                      child: Semantics(
                        selected: seconds == selected,
                        inMutuallyExclusiveGroup: true,
                        child: _Segment(
                          label: Lobby.delayLabel(seconds),
                          active: seconds == selected,
                          first: i == 0,
                          last: i == Lobby.delays.length - 1,
                          onPressed: () => onChoose(seconds),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One segment of the delay choice: Material's segmented look, drawn with a TextButton so the id sits on the button.
class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.active,
    required this.first,
    required this.last,
    required this.onPressed,
  });

  final String label;
  final bool active;
  final bool first;
  final bool last;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const round = Radius.circular(20);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: EdgeInsets.zero,
        backgroundColor: active ? scheme.secondaryContainer : null,
        foregroundColor: active ? scheme.onSecondaryContainer : scheme.onSurface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: scheme.outline),
          borderRadius: BorderRadius.horizontal(left: first ? round : Radius.zero, right: last ? round : Radius.zero),
        ),
      ),
      child: Text(label, maxLines: 1, style: TextStyle(fontWeight: active ? FontWeight.bold : FontWeight.normal)),
    );
  }
}

class _PagerBlock extends StatelessWidget {
  const _PagerBlock({
    required this.controller,
    required this.banner,
    required this.onBanner,
    required this.auto,
    required this.onAuto,
    required this.log,
    required this.onPromo,
    required this.onSheet,
  });

  final PageController controller;
  final int banner;
  final ValueChanged<int> onBanner;
  final bool auto;
  final ValueChanged<bool> onAuto;
  final TouchLog log;
  final ValueChanged<int> onPromo;
  final ValueChanged<int> onSheet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final position = Lobby.pagerPosition(banner);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Id(
            TestIds.lobbyPager,
            region: true,
            child: SizedBox(
              height: 100,
              child: PageView.builder(
                // iOS makes a scroll view (a UIScrollView, XCUITest's ScrollView) only for a node with the
                // hasImplicitScrolling flag, and a PageView sets it only with this on. Without it the pager is a plain
                // element to XCUITest, and the Top 10 row is the first scroll view. It also builds the page on each
                // side, hidden: Android leaves hidden nodes out of its tree, iOS keeps them.
                allowImplicitScrolling: true,
                controller: controller,
                itemCount: Lobby.banners,
                onPageChanged: (index) => onBanner(index + 1),
                itemBuilder: (context, index) {
                  final n = index + 1;
                  final title = Lobby.bannerTitles[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Id(
                      TestIds.lobbyBanner(n),
                      child: _Touchable(
                        log: log,
                        what: title,
                        where: 'banner $n',
                        onTap: () => onPromo(n),
                        onLongPress: () => onSheet(n),
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: radiusDrawer),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  title,
                                  style: theme.textTheme.titleMedium?.copyWith(color: scheme.onPrimaryContainer),
                                ),
                                Text(
                                  Lobby.aTestBanner,
                                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onPrimaryContainer),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                // the dots and the text are one node, labelled by the text
                child: Id(
                  TestIds.lobbyPagerPosition,
                  child: Row(
                    children: [
                      for (var i = 1; i <= Lobby.banners; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Container(
                            width: i == banner ? 10 : 6,
                            height: i == banner ? 10 : 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == banner ? scheme.primary : scheme.outlineVariant,
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),
                      Text(position, style: theme.textTheme.labelMedium),
                    ],
                  ),
                ),
              ),
              _CompactSwitch(id: TestIds.lobbyPagerAuto, label: Lobby.autoAdvanceLabel, value: auto, onChanged: onAuto),
            ],
          ),
        ),
      ],
    );
  }
}

/// The first and last fully visible tiles of a horizontal row, from 1, read from its scroll offset.
(int, int) _fullyVisible(ScrollController controller, int count) {
  if (!controller.hasClients || !controller.position.hasContentDimensions) return (1, 1);
  final offset = controller.offset;
  final width = controller.position.viewportDimension;
  double left(int m) => _rowPadding + (m - 1) * (_tileWidth + _tileGap);
  final full = [
    for (var m = 1; m <= count; m++)
      if (left(m) >= offset - 0.5 && left(m) + _tileWidth <= offset + width + 0.5) m,
  ];
  if (full.isNotEmpty) return (full.first, full.last);
  // none fully visible: the one under the left edge
  final m = ((offset - _rowPadding) / (_tileWidth + _tileGap)).floor() + 1;
  final one = m.clamp(1, count);
  return (one, one);
}

/// A row's position line: the first and last fully visible tiles, as text and as the node's label.
class _RowPosition extends StatelessWidget {
  const _RowPosition({required this.id, required this.controller, required this.count, required this.text});

  final String id;
  final ScrollController controller;
  final int count;
  final String Function(int first, int last) text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        // before the row's first layout, the tiles a phone shows at its start
        final (first, last) = controller.hasClients ? _fullyVisible(controller, count) : (1, 3);
        return Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 4),
          child: Id(
            id,
            child: Semantics(
              header: true,
              child: Text(
                text(first, last),
                style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A tile of a row: its drawing, its name and, in the page's rows, its number. [band] is the Top 10 row's 64-high
/// band; the page's rows draw the 100 × 100 tile.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.id,
    required this.row,
    required this.tile,
    required this.log,
    required this.onDetail,
    required this.onSheet,
  });

  final String id;
  final int row;
  final int tile;
  final TouchLog log;
  final ValueChanged<int> onDetail;
  final ValueChanged<int> onSheet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = Lobby.itemAt(row, tile);
    final top = row == Lobby.topRow;
    final tint = Mossgrove.of(context).aisle(item.category);
    return SizedBox(
      width: _tileWidth,
      child: Id(
        id,
        child: _Touchable(
          log: log,
          what: item.name,
          where: Lobby.tileWhere(row, tile),
          onTap: () => onDetail(tile),
          onLongPress: () => onSheet(tile),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (top)
                // a band 100 × 64, lower than a page tile, so the page keeps its room under the fixed row
                Container(
                  width: _tileWidth,
                  height: 64,
                  decoration: BoxDecoration(color: tint.tile, borderRadius: radiusTile),
                  alignment: Alignment.center,
                  child: ArtIcon(Art.glyph(item.glyph), size: 40, color: tint.ink),
                )
              else
                GlyphTile(item, size: _tileWidth),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(item.name, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (!top) ItemNumber(item),
            ],
          ),
        ),
      ),
    );
  }
}

/// A horizontal row of tiles: a `ListView` that scrolls left and right, with its position line above it.
class _HorizontalTiles extends StatelessWidget {
  const _HorizontalTiles({
    required this.id,
    required this.controller,
    required this.height,
    required this.count,
    required this.tile,
  });

  final String id;
  final ScrollController controller;
  final double height;
  final int count;
  final Widget Function(int m) tile;

  @override
  Widget build(BuildContext context) => Id(
    id,
    region: true,
    child: SizedBox(
      height: height,
      child: ListView.separated(
        controller: controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: _rowPadding),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: _tileGap),
        itemBuilder: (_, index) => tile(index + 1),
      ),
    ),
  );
}

/// The Top 10 row (SPEC.md §5, 1.1): fixed, outside the page, under the pager or in its place. Nothing vertical
/// encloses it, so a vertical swipe across it is claimed by no scroller: the case of the app where the fault was seen.
class _TopRow extends StatelessWidget {
  const _TopRow({required this.controller, required this.log, required this.onDetail, required this.onSheet});

  final ScrollController controller;
  final TouchLog log;
  final ValueChanged<int> onDetail;
  final ValueChanged<int> onSheet;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _RowPosition(
        id: TestIds.lobbyTopRowPosition,
        controller: controller,
        count: Lobby.topTiles,
        text: Lobby.topRowPosition,
      ),
      _HorizontalTiles(
        id: TestIds.lobbyTopRow,
        controller: controller,
        height: _topRowHeight,
        count: Lobby.topTiles,
        tile: (m) => _Tile(
          id: TestIds.lobbyTopRowTile(m),
          row: Lobby.topRow,
          tile: m,
          log: log,
          onDetail: onDetail,
          onSheet: onSheet,
        ),
      ),
    ],
  );
}

class _TileRow extends StatelessWidget {
  const _TileRow({
    required this.row,
    required this.controller,
    required this.log,
    required this.onDetail,
    required this.onSheet,
  });

  final int row;
  final ScrollController controller;
  final TouchLog log;
  final ValueChanged<int> onDetail;
  final ValueChanged<int> onSheet;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _RowPosition(
        id: TestIds.lobbyRowPosition(row),
        controller: controller,
        count: Lobby.tiles,
        text: (a, b) => Lobby.rowPosition(row, a, b),
      ),
      _HorizontalTiles(
        id: TestIds.lobbyRow(row),
        controller: controller,
        height: _pageRowHeight,
        count: Lobby.tiles,
        tile: (m) =>
            _Tile(id: TestIds.lobbyRowTile(row, m), row: row, tile: m, log: log, onDetail: onDetail, onSheet: onSheet),
      ),
    ],
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
      ),
    );
  }
}

/// The chips: drawn here on a GestureDetector, because Material's chips take no long press, and a long press on a
/// chip must log.
class _Chips extends StatelessWidget {
  const _Chips({required this.controller, required this.log, required this.selected, required this.onSelect});

  final ScrollController controller;
  final TouchLog log;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Id(
      TestIds.lobbyChips,
      region: true,
      child: SizedBox(
        height: 48,
        child: ListView.separated(
          controller: controller,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: Lobby.chips.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final n = i + 1;
            final on = n == selected;
            final label = Lobby.chips[i];
            return Id(
              TestIds.lobbyChip(n),
              child: Semantics(
                selected: on,
                child: _Touchable(
                  log: log,
                  what: label,
                  where: 'chip $n',
                  onTap: () => onSelect(n),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: on ? scheme.secondaryContainer : scheme.surface,
                      border: Border.all(color: on ? scheme.secondaryContainer : scheme.outline),
                      borderRadius: radiusTile,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (on) ...[
                          ArtIcon(Art.check, size: 16, color: scheme.onSecondaryContainer),
                          const SizedBox(width: 6),
                        ],
                        Text(label, style: theme.textTheme.labelLarge),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid(this.log);

  final TouchLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeading(Lobby.gridHeading),
        Id(
          TestIds.lobbyGrid,
          region: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              spacing: 8,
              children: [
                for (var r = 0; r < Lobby.gridCells ~/ 2; r++)
                  Row(
                    spacing: 8,
                    children: [
                      for (var c = 1; c <= 2; c++)
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final n = r * 2 + c;
                              final item = Lobby.gridItem(n);
                              return Id(
                                TestIds.lobbyGridCell(n),
                                child: _Touchable(
                                  log: log,
                                  what: item.name,
                                  where: 'grid, cell $n',
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: theme.colorScheme.outlineVariant),
                                      borderRadius: radiusTile,
                                    ),
                                    child: Row(
                                      children: [
                                        GlyphTile(item, size: 40),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(item.name, style: theme.textTheme.bodySmall, maxLines: 2)),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InnerList extends StatelessWidget {
  const _InnerList({required this.controller, required this.log});

  final ScrollController controller;
  final TouchLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeading(Lobby.innerListHeading),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Id(
            TestIds.lobbyInnerList,
            region: true,
            child: Container(
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: radiusTile,
              ),
              child: ListView.builder(
                controller: controller,
                itemCount: Lobby.innerLines,
                itemBuilder: (_, i) {
                  final n = i + 1;
                  return Id(
                    TestIds.lobbyInnerRow(n),
                    child: _Touchable(
                      log: log,
                      what: 'Line $n',
                      where: 'inner list',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
                        ),
                        child: Text(Lobby.innerLine(n), style: theme.textTheme.bodyMedium),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The board: a 280-square window onto 26 × 26 cells of 56, Flutter's own two-axis scroller ([BoardView]).
class _Board extends StatelessWidget {
  const _Board({required this.x, required this.y, required this.log});

  final ScrollController x;
  final ScrollController y;
  final TouchLog log;

  /// The top-left fully visible cell: a cell scrolled partly out is not counted.
  static int _first(ScrollController c) =>
      c.hasClients ? ((c.offset / _boardCell - 0.001).ceil() + 1).clamp(1, Lobby.board) : 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListenableBuilder(
          listenable: Listenable.merge([x, y]),
          builder: (context, _) {
            final position = Lobby.boardPosition(_first(x), _first(y));
            return Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
              child: Id(
                TestIds.lobbyBoardPosition,
                child: Semantics(
                  header: true,
                  child: Text(position, style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary)),
                ),
              ),
            );
          },
        ),
        Center(
          child: Id(
            TestIds.lobbyBoard,
            region: true,
            child: Container(
              width: _boardCell * 5,
              height: _boardCell * 5,
              decoration: BoxDecoration(border: Border.all(color: scheme.outline)),
              child: BoardView(
                count: Lobby.board,
                cell: _boardCell,
                horizontalDetails: ScrollableDetails.horizontal(controller: x),
                verticalDetails: ScrollableDetails.vertical(controller: y),
                delegate: TwoDimensionalChildBuilderDelegate(
                  maxXIndex: Lobby.board - 1,
                  maxYIndex: Lobby.board - 1,
                  builder: (context, vicinity) {
                    final col = vicinity.xIndex + 1;
                    final row = vicinity.yIndex + 1;
                    final label = Lobby.boardLabel(col, row);
                    return Id(
                      TestIds.lobbyBoardCell(col, row),
                      child: _Touchable(
                        log: log,
                        what: label,
                        where: 'board',
                        child: Container(
                          decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant, width: 0.5)),
                          alignment: Alignment.center,
                          child: Text(label, style: theme.textTheme.labelMedium),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The quick sheet: Flutter's own modal bottom sheet, a route of its own over the Lobby. Its barrier blocks the
/// Lobby's semantics while it is open, so the tree holds the sheet alone, as a window of its own does on Android.
class _QuickSheet extends StatelessWidget {
  const _QuickSheet({required this.title, required this.onButton});

  final String title;
  final ValueChanged<String> onButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Id(
      TestIds.lobbySheet,
      region: true,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Id(
                TestIds.lobbySheetTitle,
                child: Semantics(header: true, child: Text(title, style: theme.textTheme.titleLarge)),
              ),
            ),
            for (final (i, label) in Lobby.sheetButtons.indexed)
              IdControl(
                TestIds.lobbySheetButtons[i],
                child: TextButton(
                  onPressed: () => onButton(label),
                  style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48), alignment: Alignment.centerLeft),
                  child: Text(label),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
