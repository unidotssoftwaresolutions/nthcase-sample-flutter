import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../data/catalog.dart';
import '../../ids.dart';
import '../art.dart';
import '../components.dart';

/// Order history: the empty state and, with Settings › Fail the first load, the error state with retry.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late final Load _load = Load(AppScope.read(context).notifier!);

  @override
  void dispose() {
    _load.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    return Id(
      TestIds.ordersScreen,
      region: true,
      child: Scaffold(
        appBar: TopBar('Orders', onBack: state.back),
        body: ListenableBuilder(
          listenable: _load,
          builder: (context, _) => switch (_load.status) {
            LoadStatus.loading => const Loading('Fetching your orders…', id: TestIds.ordersLoading),
            LoadStatus.failed => StateMessage(
              icon: Art.warning,
              title: "Orders didn't load",
              body: 'Something went wrong on our side. Try again in a moment.',
              actionLabel: 'Try again',
              onAction: _load.retry,
              isError: true,
              id: TestIds.ordersError,
              actionId: TestIds.ordersRetry,
            ),
            LoadStatus.ready when state.orders.isEmpty => StateMessage(
              icon: Art.empty,
              title: 'No orders yet',
              body: 'Orders you place appear here.',
              actionLabel: 'Start shopping',
              onAction: () => state.switchTab(AppTab.shop),
              id: TestIds.ordersEmpty,
              actionId: TestIds.ordersEmptyAction,
            ),
            LoadStatus.ready => Id(
              TestIds.ordersList,
              region: true,
              child: ListView(
                children: [
                  for (final order in state.orders)
                    Id(
                      TestIds.ordersRow(order.number),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Order ${order.number}', style: theme.textTheme.bodyLarge),
                                  Text(
                                    '${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'} · '
                                    '${order.lines.map((l) => l.item.name).join(', ')}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(formatPrice(order.totalCents), style: theme.textTheme.titleMedium),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          },
        ),
      ),
    );
  }
}
