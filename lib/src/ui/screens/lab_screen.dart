import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../ids.dart';
import '../art.dart';
import '../components.dart';

class _Bench {
  const _Bench(this.id, this.bench, this.title, this.body);

  final String id;
  final Bench bench;
  final String title;
  final String body;
}

const _benches = [
  _Bench(
    TestIds.labForm,
    Bench.form,
    'Join the club',
    'A form: text, email, number, password, picker, date, switch, slider, checkbox',
  ),
  _Bench(
    TestIds.labGestures,
    Bench.gestures,
    'Gestures',
    'Tap, double tap, long press, swipe, drag and drop, pinch, rotate, scroll, shake',
  ),
  _Bench(TestIds.labWebview, Bench.webview, 'Care guide', 'A web page inside the app, bundled with it'),
  _Bench(TestIds.labSlow, Bench.slow, 'Delivery slots', 'Loads for 3 seconds, then shows its content'),
  _Bench(TestIds.labOrders, Bench.orders, 'Orders', 'An empty state, and an error state with retry'),
  _Bench(TestIds.labGiftCards, Bench.giftCards, 'Gift cards', 'No test ids at all: find things by their text'),
];

/// The Lab: Mossgrove's second cabinet, one drawer per test bench. It says plainly what each one is for.
class LabScreen extends StatelessWidget {
  const LabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context).notifier!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Id(
      TestIds.labScreen,
      region: true,
      child: Scaffold(
        appBar: const TopBar('Lab'),
        body: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Screens for testing. Each one exercises verbs that NthCase records and replays.',
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            for (final bench in _benches) ...[
              Id(
                bench.id,
                child: InkWell(
                  onTap: () => state.open(BenchPlace(bench.bench)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(bench.title, style: theme.textTheme.bodyLarge),
                              Text(
                                bench.body,
                                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        ArtIcon(Art.chevron, color: scheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
              Divider(height: 1, indent: 16, endIndent: 16, color: scheme.outlineVariant),
            ],
          ],
        ),
      ),
    );
  }
}
