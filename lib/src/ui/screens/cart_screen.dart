import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../data/cart.dart';
import '../../data/catalog.dart';
import '../../ids.dart';
import '../art.dart';
import '../components.dart';

String orderPlacedMessage(int number) => 'Order $number placed';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  Future<void> _checkOut(BuildContext context) async {
    final scope = AppScope.read(context);
    final state = scope.notifier!;
    final cart = state.cart;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Id(
        TestIds.dialog,
        region: true,
        child: AlertDialog(
          title: Id(TestIds.dialogTitle, child: const Text('Place this order?')),
          content: Id(
            TestIds.dialogText,
            child: Text(
              '${cart.itemCount} ${cart.itemCount == 1 ? 'item' : 'items'} · ${formatPrice(cart.totalCents)}. '
              'This is a sample shop: nothing is charged or shipped.',
            ),
          ),
          actions: [
            IdControl(
              TestIds.dialogDismiss,
              child: TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            ),
            IdControl(
              TestIds.dialogConfirm,
              child: TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Place order')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final order = state.placeOrder();
    if (state.orderUpdates) {
      await scope.device.postNotification(orderPlacedMessage(order.number), "We're packing it now.");
    }
    scope.snack.show(
      orderPlacedMessage(order.number),
      action: 'View orders',
      onAction: () => state.open(const BenchPlace(Bench.orders)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final cart = state.cart;
    final theme = Theme.of(context);
    return Id(
      TestIds.cartScreen,
      region: true,
      child: Scaffold(
        appBar: const TopBar('Cart'),
        body: cart.isEmpty
            ? StateMessage(
                icon: Art.cart,
                title: 'Your cart is empty',
                body: 'Open a drawer in the shop and add something.',
                actionLabel: 'Browse the shop',
                onAction: () => state.switchTab(AppTab.shop),
                id: TestIds.cartEmpty,
                actionId: TestIds.cartEmptyAction,
              )
            : Id(
                TestIds.cartList,
                region: true,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: cart.lines.length,
                  separatorBuilder: (_, _) => Divider(height: 24, color: theme.colorScheme.outlineVariant),
                  itemBuilder: (context, index) => _CartLineRow(cart.lines[index]),
                ),
              ),
        bottomNavigationBar: cart.isEmpty
            ? null
            : Material(
                color: theme.colorScheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('Total', style: theme.textTheme.titleMedium)),
                          Id(
                            TestIds.cartTotal,
                            child: Text(formatPrice(cart.totalCents), style: theme.textTheme.titleLarge),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: IdControl(
                          TestIds.cartCheckout,
                          child: FilledButton(onPressed: () => _checkOut(context), child: const Text('Check out')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _CartLineRow extends StatelessWidget {
  const _CartLineRow(this.line);

  final CartLine line;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context).notifier!;
    final item = line.item;
    final theme = Theme.of(context);
    return Id(
      TestIds.cartLine(item.id),
      region: true,
      child: Column(
        children: [
          Row(
            children: [
              GlyphTile(item, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: theme.textTheme.titleMedium),
                    ItemNumber(item),
                  ],
                ),
              ),
              Id(
                TestIds.cartLineTotal(item.id),
                child: Text(formatPrice(line.totalCents), style: theme.textTheme.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${formatPrice(item.priceCents)} each',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              QuantityStepper(
                value: line.quantity,
                onChanged: (value) => state.changeCart((cart) => cart.setQuantity(item.id, value)),
                decreaseId: TestIds.cartLineDecrease(item.id),
                valueId: TestIds.cartLineQty(item.id),
                increaseId: TestIds.cartLineIncrease(item.id),
                subject: item.name,
              ),
              IdControl(
                TestIds.cartLineRemove(item.id),
                child: IconButton(
                  onPressed: () => state.changeCart((cart) => cart.remove(item.id)),
                  icon: ArtIcon(Art.trash, label: 'Remove ${item.name}'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
