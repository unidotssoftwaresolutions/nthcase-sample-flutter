import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../ids.dart';
import '../components.dart';
import '../theme.dart';

/// The app's version and the spec it builds, as the version line says them. A test checks it against pubspec.yaml.
const appVersion = '1.0.0';
const specVersion = '1.0';

const notificationsNotAllowed = 'Not allowed. Turn this on to be asked.';
const notificationsOff = 'Off';
const notificationsOn = "On: we'll tell you when an order is placed.";
const notificationSent = 'Notification sent';
const resetDone = 'Cart and orders emptied';

/// Settings. Android and iOS build this screen with their classic toolkits (XML Views, UIKit); Flutter has no second
/// toolkit, so here it is plain Material widgets like every other screen (SPEC.md §12). It holds the app's one system
/// permission prompt: notifications.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _allowed = false;
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(onResume: _check);

  @override
  void initState() {
    super.initState();
    _lifecycle;
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Reads the permission again: it may have changed in the system's settings while the app was away.
  Future<void> _check() async {
    if (!mounted) return;
    final scope = AppScope.read(context);
    final allowed = await scope.device.notificationsAllowed();
    if (!mounted) return;
    if (!allowed && scope.notifier!.orderUpdates) scope.notifier!.orderUpdates = false;
    setState(() => _allowed = allowed);
  }

  Future<void> _setOrderUpdates(bool on) async {
    final scope = AppScope.read(context);
    final state = scope.notifier!;
    if (on && !_allowed) {
      // the one permission prompt: Android 13+ POST_NOTIFICATIONS, iOS UNUserNotificationCenter
      final granted = await scope.device.requestNotifications();
      if (!mounted) return;
      setState(() => _allowed = granted);
      state.orderUpdates = granted;
    } else {
      state.orderUpdates = on;
    }
  }

  Future<void> _confirmReset() async {
    final scope = AppScope.read(context);
    final emptied = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Empty the cart and orders?'),
        content: const Text("You stay signed in. This can't be undone."),
        // its own buttons carry the spec's ids
        actions: [
          IdControl(
            TestIds.settingsResetCancel,
            child: TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ),
          IdControl(
            TestIds.settingsResetConfirm,
            child: TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Empty')),
          ),
        ],
      ),
    );
    if (emptied != true) return;
    scope.notifier!.resetData();
    scope.snack.show(resetDone);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.read(context);
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary)),
      ),
    );

    final status = !_allowed ? notificationsNotAllowed : (state.orderUpdates ? notificationsOn : notificationsOff);

    return Id(
      TestIds.settingsScreen,
      region: true,
      child: Scaffold(
        appBar: const TopBar('Settings'),
        // one scrolling column, as the Android XML screen is: every control exists, on screen or below it
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              section('Account'),
              Id(
                TestIds.settingsAccountEmail,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    state.signedInEmail ?? 'Not signed in',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontFamily: monospace,
                      fontFamilyFallback: monospaceFallback,
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: IdControl(
                        TestIds.settingsOrders,
                        child: OutlinedButton(
                          onPressed: () => state.open(const BenchPlace(Bench.orders)),
                          child: const Text('Order history'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: IdControl(
                        TestIds.settingsSignOut,
                        child: FilledButton.tonal(onPressed: state.signOut, child: const Text('Sign out')),
                      ),
                    ),
                  ),
                ],
              ),
              section('Appearance'),
              Id(
                TestIds.settingsTheme,
                region: true,
                child: Semantics(
                  label: 'Theme',
                  child: Column(
                    children: [
                      for (final (choice, label, id) in [
                        (ThemeChoice.system, 'Follow the system', TestIds.settingsThemeSystem),
                        (ThemeChoice.light, 'Light', TestIds.settingsThemeLight),
                        (ThemeChoice.dark, 'Dark', TestIds.settingsThemeDark),
                      ])
                        ToggleRow(
                          label: label,
                          value: state.theme == choice,
                          onChanged: (_) => state.theme = choice,
                          kind: ToggleKind.radio,
                          leading: true,
                          id: id,
                        ),
                    ],
                  ),
                ),
              ),
              section('Notifications'),
              ToggleRow(
                label: 'Order updates',
                value: _allowed && state.orderUpdates,
                onChanged: _setOrderUpdates,
                kind: ToggleKind.switcher,
                id: TestIds.settingsNotifications,
              ),
              Id(
                TestIds.settingsNotificationsStatus,
                child: Semantics(
                  liveRegion: true,
                  child: Text(status, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  height: 48,
                  child: IdControl(
                    TestIds.settingsSendNotification,
                    child: TextButton(
                      onPressed: _allowed && state.orderUpdates
                          ? () async {
                              await scope.device.postNotification(
                                'Your order is packed',
                                'A test notification from Mossgrove.',
                              );
                              scope.snack.show(notificationSent);
                            }
                          : null,
                      child: const Text('Send a test notification'),
                    ),
                  ),
                ),
              ),
              section('Testing'),
              Text(
                "These change how the shop's lists load. Nothing goes over the network.",
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              ToggleRow(
                label: 'Slow loading (3 seconds)',
                value: state.slowLoading,
                onChanged: (on) => state.slowLoading = on,
                kind: ToggleKind.switcher,
                id: TestIds.settingsSlowLoading,
              ),
              ToggleRow(
                label: 'Fail the first load',
                value: state.failFirstLoad,
                onChanged: (on) => state.failFirstLoad = on,
                kind: ToggleKind.switcher,
                id: TestIds.settingsFailLoading,
              ),
              section('Data'),
              SizedBox(
                height: 48,
                child: IdControl(
                  TestIds.settingsReset,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.error,
                      side: BorderSide(color: scheme.error),
                    ),
                    onPressed: _confirmReset,
                    child: const Text('Empty the cart and orders'),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Id(
                TestIds.settingsVersion,
                child: Text(
                  'Mossgrove $appVersion · spec $specVersion · a sample app for NthCase',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
