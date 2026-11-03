import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../data/catalog.dart';
import '../../ids.dart';
import '../art.dart';
import '../components.dart';

/// How long a pull to refresh spins when loading is not slowed.
const refreshTime = Duration(milliseconds: 800);
const refreshedMessage = 'Catalogue is up to date';

/// The count line with no search: fixed text (SPEC.md §6), for the fixed forty items.
const allDrawers = '40 drawers · No. 001–040';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _query = TextEditingController();
  late final Load _load = Load(AppScope.read(context).notifier!);

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    _load.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final scope = AppScope.read(context);
    await wait(scope.notifier!.slowLoading ? slowLoad : refreshTime);
    scope.snack.show(refreshedMessage);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final query = _query.text;
    final results = Catalog.search(query);
    return Scaffold(
      body: Id(
        TestIds.shopScreen,
        region: true,
        child: SafeArea(
          bottom: false,
          child: ListenableBuilder(
            listenable: _load,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(header: true, child: Text('Mossgrove', style: theme.textTheme.headlineMedium)),
                      const SizedBox(height: 12),
                      Id(
                        TestIds.shopSearch,
                        child: TextField(
                          controller: _query,
                          textInputAction: TextInputAction.search,
                          autocorrect: false,
                          decoration: InputDecoration(
                            hintText: 'Search by name or number',
                            prefixIcon: ArtIcon(Art.search, color: scheme.onSurfaceVariant),
                            suffixIcon: query.isEmpty
                                ? null
                                : IdControl(
                                    TestIds.shopSearchClear,
                                    child: IconButton(
                                      onPressed: _query.clear,
                                      icon: ArtIcon(Art.close, label: 'Clear search'),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      if (_load.status == LoadStatus.ready)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Id(
                            TestIds.shopCount,
                            child: Text(
                              query.trim().isEmpty
                                  ? allDrawers
                                  : '${results.length} of ${Catalog.items.length} drawers',
                              style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: switch (_load.status) {
                    LoadStatus.loading => const Loading('Opening the drawers…', id: TestIds.shopLoading),
                    LoadStatus.failed => StateMessage(
                      icon: Art.warning,
                      title: "The catalogue didn't load",
                      body: 'Something went wrong on our side. Your cart is safe.',
                      actionLabel: 'Try again',
                      onAction: _load.retry,
                      isError: true,
                      id: TestIds.shopError,
                      actionId: TestIds.shopRetry,
                    ),
                    LoadStatus.ready => RefreshIndicator(
                      onRefresh: _refresh,
                      child: results.isEmpty
                          ? LayoutBuilder(
                              // the empty state scrolls too, so a pull still refreshes
                              builder: (context, constraints) => SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                                  child: StateMessage(
                                    icon: Art.empty,
                                    title: 'No drawers match "${query.trim()}"',
                                    body: 'Try a shorter word, or an item number like 7.',
                                    actionLabel: 'Clear search',
                                    onAction: _query.clear,
                                    id: TestIds.shopEmpty,
                                    actionId: TestIds.shopEmptyAction,
                                  ),
                                ),
                              ),
                            )
                          : Id(
                              TestIds.shopList,
                              region: true,
                              child: ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: results.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (context, index) => DrawerRow(results[index]),
                              ),
                            ),
                    ),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One drawer front: the drawing tile, the label holder, the price. The row is one element that reads its name, number
/// and price, and opens the item.
class DrawerRow extends StatelessWidget {
  const DrawerRow(this.item, {super.key});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Id(
      TestIds.shopItem(item.id),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => AppScope.read(context).notifier!.open(ItemPlace('${item.id}')),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                GlyphTile(item, size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Align(alignment: Alignment.centerLeft, child: LabelHolder(item)),
                ),
                const SizedBox(width: 12),
                Text(formatPrice(item.priceCents), style: theme.textTheme.titleMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
