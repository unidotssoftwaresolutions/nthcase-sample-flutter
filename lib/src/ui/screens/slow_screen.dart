import 'package:flutter/material.dart';

import '../../ids.dart';
import '../art.dart';
import '../components.dart';

/// The five delivery slots the slow screen shows, in order. Fixed text, so a check can name any of them.
const deliverySlots = [
  'Monday · 8:00–10:00',
  'Monday · 18:00–20:00',
  'Wednesday · 12:00–14:00',
  'Friday · 8:00–10:00',
  'Saturday · 10:00–12:00',
];

/// Always slow: a 3 s spinner, then the slots. Reload starts the wait again.
class SlowScreen extends StatefulWidget {
  const SlowScreen({super.key});

  @override
  State<SlowScreen> createState() => _SlowScreenState();
}

class _SlowScreenState extends State<SlowScreen> {
  late Load _load = Load(AppScope.read(context).notifier!, alwaysSlow: true);

  @override
  void dispose() {
    _load.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _load.dispose();
      _load = Load(AppScope.read(context).notifier!, alwaysSlow: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context).notifier!;
    final theme = Theme.of(context);
    return Id(
      TestIds.slowScreen,
      region: true,
      child: Scaffold(
        appBar: TopBar('Delivery slots', onBack: state.back),
        body: ListenableBuilder(
          listenable: _load,
          builder: (context, _) => switch (_load.status) {
            LoadStatus.loading => const Loading('Finding delivery slots…', id: TestIds.slowLoading),
            LoadStatus.failed => StateMessage(
              icon: Art.warning,
              title: "Slots didn't load",
              body: 'Something went wrong on our side.',
              actionLabel: 'Try again',
              onAction: _load.retry,
              isError: true,
            ),
            LoadStatus.ready => Id(
              TestIds.slowContent,
              region: true,
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Choose when we bring your order.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  for (final (index, slot) in deliverySlots.indexed)
                    Id(
                      TestIds.slowSlot(index + 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        child: Text(slot, style: theme.textTheme.bodyLarge),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      height: 48,
                      child: IdControl(
                        TestIds.slowReload,
                        child: OutlinedButton(onPressed: _reload, child: const Text('Reload')),
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
