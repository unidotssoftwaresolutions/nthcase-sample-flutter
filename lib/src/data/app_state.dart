import 'package:flutter/foundation.dart';

import 'cart.dart';

enum ThemeChoice { system, light, dark }

/// The four tabs, in the order of the bottom bar.
enum AppTab { shop, cart, lab, settings }

/// A screen below a tab. Each has a top bar with Back, and covers the tab bar.
sealed class Place {
  const Place();
}

/// The item page. [rawId] is the id as written (in the route or the deep link), so an unknown id can say so.
final class ItemPlace extends Place {
  const ItemPlace(this.rawId);

  final String rawId;
}

/// The Lab's test benches, and Orders (also opened from Settings and the cart's snackbar).
enum Bench { form, gestures, webview, slow, orders, giftCards, lobby }

final class BenchPlace extends Place {
  const BenchPlace(this.bench);

  final Bench bench;
}

/// One screen on the stack above the tabs. [key] tells two visits to the same place apart.
class StackEntry {
  const StackEntry(this.key, this.place);

  final int key;
  final Place place;
}

/// Everything the app remembers, in memory only. A cold start is always signed out, with an empty cart, no orders and
/// Settings at their defaults, so every run begins from the same screen (SPEC.md §2).
class AppState extends ChangeNotifier {
  AppState({DateTime Function()? clock}) : clock = clock ?? DateTime.now;

  static const testEmail = 'tester@mossgrove.test';
  static const testPassword = 'Mossgrove123';

  /// Today, for the one thing that depends on the date: the month the date picker opens on. Tests fix it.
  final DateTime Function() clock;

  String? _signedInEmail;
  final Cart cart = Cart();
  final List<Order> _orders = [];

  bool _slowLoading = false;
  bool _failFirstLoad = false;
  bool _orderUpdates = false;
  ThemeChoice _theme = ThemeChoice.system;
  String? _pendingItemId;
  int _lobbySavedDelay = 0;
  bool _lobbyPagerShown = true;

  AppTab _tab = AppTab.shop;
  final List<StackEntry> _stack = [];
  int _nextKey = 1;

  String? get signedInEmail => _signedInEmail;

  bool get signedIn => _signedInEmail != null;

  /// Newest first.
  List<Order> get orders => List.unmodifiable(_orders);

  /// Settings › Testing: every list load waits 3 s first.
  bool get slowLoading => _slowLoading;
  set slowLoading(bool value) => _set(() => _slowLoading = value);

  /// Settings › Testing: the first load of each visit fails; Try again then succeeds.
  bool get failFirstLoad => _failFirstLoad;
  set failFirstLoad(bool value) => _set(() => _failFirstLoad = value);

  /// Settings › Notifications: post an "Order n placed" notification when allowed.
  bool get orderUpdates => _orderUpdates;
  set orderUpdates(bool value) => _set(() => _orderUpdates = value);

  ThemeChoice get theme => _theme;
  set theme(ThemeChoice value) => _set(() => _theme = value);

  /// The Lobby's "Saved appears after", in seconds (SPEC.md §5, 1.1). Kept in memory until the app closes, like
  /// every setting here, and not cleared by signing out: a cold start is 0 s.
  int get lobbySavedDelay => _lobbySavedDelay;
  set lobbySavedDelay(int value) => _set(() => _lobbySavedDelay = value);

  /// The Lobby's "Show the pager", on at a cold start and kept until the app closes.
  bool get lobbyPagerShown => _lobbyPagerShown;
  set lobbyPagerShown(bool value) => _set(() => _lobbyPagerShown = value);

  /// A deep link that arrived before sign-in; opened right after it.
  String? get pendingItemId => _pendingItemId;

  AppTab get tab => _tab;

  List<StackEntry> get stack => List.unmodifiable(_stack);

  void _set(void Function() change) {
    change();
    notifyListeners();
  }

  /// The one check of the sign-in screen. The email's case and surrounding spaces do not matter; the password's do.
  static bool credentialsMatch(String email, String password) =>
      email.trim().toLowerCase() == testEmail && password == testPassword;

  void signIn(String email) => _set(() {
    _signedInEmail = email.trim().toLowerCase();
    _tab = AppTab.shop;
    _stack.clear();
    final pending = _pendingItemId;
    if (pending != null) {
      _pendingItemId = null;
      _stack.add(StackEntry(_nextKey++, ItemPlace(pending)));
    }
  });

  /// Sign out returns to the sign-in screen and clears the back stack.
  void signOut() => _set(() {
    _signedInEmail = null;
    cart.clear();
    _orders.clear();
    _tab = AppTab.shop;
    _stack.clear();
  });

  /// `nthcase-sample://item/{id}`: signed in, the item opens over the Shop tab, so Back lands on the Shop. Signed out,
  /// it waits for the sign-in.
  void openDeepLink(String itemId) => _set(() {
    if (!signedIn) {
      _pendingItemId = itemId;
      return;
    }
    _tab = AppTab.shop;
    _stack
      ..clear()
      ..add(StackEntry(_nextKey++, ItemPlace(itemId)));
  });

  /// A tab always opens at its first screen (SPEC.md §4): no deeper screen is kept or restored.
  void switchTab(AppTab tab) => _set(() {
    _tab = tab;
    _stack.clear();
  });

  void open(Place place) => _set(() => _stack.add(StackEntry(_nextKey++, place)));

  /// Back from the top screen. Returns false when there is nothing to go back to.
  bool back() {
    if (_stack.isEmpty) return false;
    _set(() => _stack.removeLast());
    return true;
  }

  /// The navigator removed a page itself (system Back, the iOS edge swipe): forget it too.
  void removeEntry(int key) {
    final index = _stack.indexWhere((e) => e.key == key);
    if (index < 0) return;
    _set(() => _stack.removeRange(index, _stack.length));
  }

  void changeCart(void Function(Cart cart) change) => _set(() => change(cart));

  Order placeOrder() {
    final order = Order(_orders.length + 1, cart.lines);
    _set(() {
      _orders.insert(0, order);
      cart.clear();
    });
    return order;
  }

  /// Settings › Data: empties the cart and the order history, and keeps you signed in.
  void resetData() => _set(() {
    cart.clear();
    _orders.clear();
  });
}
