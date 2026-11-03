import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../data/catalog.dart';
import '../../ids.dart';
import '../art.dart';
import '../components.dart';
import '../theme.dart';

const addedMessage = 'Added to cart';

/// The detail page. [rawId] is the id as written in the route or the deep link, so an unknown id can say so.
class ItemScreen extends StatefulWidget {
  const ItemScreen({super.key, required this.rawId});

  final String rawId;

  @override
  State<ItemScreen> createState() => _ItemScreenState();
}

class _ItemScreenState extends State<ItemScreen> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.read(context);
    final state = scope.notifier!;
    final number = int.tryParse(widget.rawId);
    final item = number == null ? null : Catalog.find(number);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Id(
      TestIds.itemScreen,
      region: true,
      child: Scaffold(
        appBar: TopBar(item?.name ?? 'Not found', onBack: state.back),
        body: item == null
            ? StateMessage(
                icon: Art.empty,
                title: 'No drawer has the number "${widget.rawId}"',
                body: 'Items are numbered 1 to ${Catalog.items.length}.',
                actionLabel: 'Back to the shop',
                onAction: () => state.switchTab(AppTab.shop),
                id: TestIds.itemNotFound,
                actionId: TestIds.itemNotFoundAction,
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Id(
                            TestIds.itemImage,
                            child: GlyphTile(item, size: 220, label: 'Drawing of the ${item.name}'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // the drawer's label holder, at the scale of the page: the name, then its number
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: scheme.outlineVariant),
                              borderRadius: radiusLabel,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Id(TestIds.itemName, child: Text(item.name, style: theme.textTheme.headlineSmall)),
                                ItemNumber(item, id: TestIds.itemNumber),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Id(
                          TestIds.itemPrice,
                          child: Text(formatPrice(item.priceCents), style: theme.textTheme.titleLarge),
                        ),
                        const SizedBox(height: 12),
                        Id(
                          TestIds.itemDescription,
                          child: Text(
                            item.description,
                            style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${item.category.label} aisle',
                          style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(child: Text('Quantity', style: theme.textTheme.titleSmall)),
                            QuantityStepper(
                              value: _quantity,
                              onChanged: (value) => setState(() => _quantity = value),
                              decreaseId: TestIds.itemQtyDecrease,
                              valueId: TestIds.itemQtyValue,
                              increaseId: TestIds.itemQtyIncrease,
                              subject: item.name,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 48,
                          child: IdControl(
                            TestIds.itemAddToCart,
                            child: FilledButton(
                              // brass, like the item number and the cart count it fills: the one live action of the page
                              style: FilledButton.styleFrom(
                                backgroundColor: scheme.tertiary,
                                foregroundColor: scheme.onTertiary,
                              ),
                              onPressed: () {
                                state.changeCart((cart) => cart.add(item.id, _quantity));
                                scope.snack.show(
                                  addedMessage,
                                  action: 'View cart',
                                  onAction: () => state.switchTab(AppTab.cart),
                                );
                              },
                              child: Text('Add to cart · ${formatPrice(item.priceCents * _quantity)}'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
