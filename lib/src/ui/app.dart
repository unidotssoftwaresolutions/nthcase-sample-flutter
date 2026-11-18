import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/deep_link.dart';
import '../ids.dart';
import '../platform/device.dart';
import 'art.dart';
import 'components.dart';
import 'screens/cart_screen.dart';
import 'screens/form_screen.dart';
import 'screens/gestures_screen.dart';
import 'screens/gift_cards_screen.dart';
import 'screens/item_screen.dart';
import 'screens/lab_screen.dart';
import 'screens/lobby_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/shop_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/slow_screen.dart';
import 'screens/webview_screen.dart';
import 'theme.dart';

/// The app: one Router whose pages follow [AppState]. Signed out, only the sign-in screen exists. Signed in, the tabs
/// are the bottom page and every screen below a tab is pushed over them, covering the tab bar.
class MossgroveApp extends StatefulWidget {
  const MossgroveApp({super.key, required this.state, required this.device, this.careGuide = platformCareGuide});

  final AppState state;
  final Device device;
  final CareGuideBuilder careGuide;

  @override
  State<MossgroveApp> createState() => _MossgroveAppState();
}

class _MossgroveAppState extends State<MossgroveApp> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  late final Snack _snack = Snack(_messenger);
  late final _AppRouter _router = _AppRouter(widget.state);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: widget.state,
      device: widget.device,
      snack: _snack,
      careGuide: widget.careGuide,
      child: ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) => MaterialApp.router(
          title: 'Mossgrove',
          debugShowCheckedModeBanner: false,
          theme: mossgroveTheme(Brightness.light),
          darkTheme: mossgroveTheme(Brightness.dark),
          themeMode: switch (widget.state.theme) {
            ThemeChoice.system => ThemeMode.system,
            ThemeChoice.light => ThemeMode.light,
            ThemeChoice.dark => ThemeMode.dark,
          },
          scaffoldMessengerKey: _messenger,
          routerDelegate: _router,
          routeInformationParser: const _DeepLinkParser(),
          backButtonDispatcher: RootBackButtonDispatcher(),
        ),
      ),
    );
  }
}

/// Reads Flutter's own deep links. The engine hands the whole URI to the Router (Android: the intent's data, iOS: the
/// opened URL), so the host is still there: `nthcase-sample://item/7` is the item, and anything else is ignored.
class _DeepLinkParser extends RouteInformationParser<_Link> {
  const _DeepLinkParser();

  @override
  Future<_Link> parseRouteInformation(RouteInformation routeInformation) =>
      SynchronousFuture(_Link(DeepLinks.itemId(routeInformation.uri)));
}

/// What a route from the platform asks for: an item, or nothing (the app's start, or a link the app does not answer).
class _Link {
  const _Link(this.itemId);

  final String? itemId;
}

class _AppRouter extends RouterDelegate<_Link> with ChangeNotifier, PopNavigatorRouterDelegateMixin<_Link> {
  _AppRouter(this.state) {
    state.addListener(notifyListeners);
  }

  final AppState state;

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey();

  /// The app never reports its place back to the platform: a deep link is a way in, not an address.
  @override
  _Link? get currentConfiguration => null;

  @override
  Future<void> setNewRoutePath(_Link link) {
    // a cold start's link arrives while the first frame is being built: change the state once that build is done
    if (link.itemId case final itemId?) scheduleMicrotask(() => state.openDeepLink(itemId));
    return SynchronousFuture(null);
  }

  @override
  void dispose() {
    state.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Page<void>>[
      if (!state.signedIn)
        const MaterialPage(key: ValueKey('signin'), child: SignInScreen())
      else ...[
        const MaterialPage(key: ValueKey('tabs'), child: TabsScreen()),
        for (final entry in state.stack) MaterialPage(key: ValueKey(entry.key), child: _screen(entry.place)),
      ],
    ];
    return Navigator(
      key: navigatorKey,
      pages: pages,
      onDidRemovePage: (page) {
        if (page.key case ValueKey<int>(:final value)) state.removeEntry(value);
      },
    );
  }

  Widget _screen(Place place) => switch (place) {
    ItemPlace(:final rawId) => ItemScreen(rawId: rawId),
    BenchPlace(:final bench) => switch (bench) {
      Bench.form => const FormScreen(),
      Bench.gestures => const GesturesScreen(),
      Bench.webview => const WebViewScreen(),
      Bench.slow => const SlowScreen(),
      Bench.orders => const OrdersScreen(),
      Bench.giftCards => const GiftCardsScreen(),
      Bench.lobby => const LobbyScreen(),
    },
  };
}

/// The four tabs and the bottom bar. A tab always opens at its first screen: the bar shows the root of the chosen tab,
/// and switching clears whatever was pushed above.
class TabsScreen extends StatelessWidget {
  const TabsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final count = state.cart.itemCount;
    Widget tab(AppTab tab, String label, ArtDrawing icon, String id, {String? countLabel, int badge = 0}) {
      final selected = state.tab == tab;
      final art = ArtIcon(icon, color: selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant);
      // NavigationBar merges each destination into one node, so the id here lands on the tab's own node, beside its
      // label, its "Tab 2 of 4" and its selected state.
      return NavigationDestination(
        icon: Semantics(
          identifier: id,
          label: countLabel,
          child: badge == 0
              ? art
              : Badge(
                  label: ExcludeSemantics(child: Text('$badge')),
                  backgroundColor: scheme.tertiary,
                  textColor: scheme.onTertiary,
                  child: art,
                ),
        ),
        label: label,
      );
    }

    return Scaffold(
      body: switch (state.tab) {
        AppTab.shop => const ShopScreen(),
        AppTab.cart => const CartScreen(),
        AppTab.lab => const LabScreen(),
        AppTab.settings => const SettingsScreen(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: state.tab.index,
        onDestinationSelected: (index) => state.switchTab(AppTab.values[index]),
        destinations: [
          tab(AppTab.shop, 'Shop', Art.shop, TestIds.navShop),
          tab(
            AppTab.cart,
            'Cart',
            Art.cart,
            TestIds.navCart,
            // the count is said by the tab itself: "Cart, 2 items"
            countLabel: count > 0 ? 'Cart, $count ${count == 1 ? 'item' : 'items'}' : null,
            badge: count,
          ),
          tab(AppTab.lab, 'Lab', Art.lab, TestIds.navLab),
          tab(AppTab.settings, 'Settings', Art.settings, TestIds.navSettings),
        ],
      ),
    );
  }
}
