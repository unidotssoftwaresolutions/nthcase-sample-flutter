import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../ids.dart';
import '../components.dart';

/// The bundled page, from the app's own assets: the web view never touches the network.
const careGuideAsset = 'assets/web/care-guide.html';
const pageLoading = 'Loading the care guide…';
const pageLoaded = 'Care guide loaded';

/// Draws the care guide and calls `onLoaded` once the page has finished loading. The app uses [platformCareGuide];
/// the host tests, which have no web engine, pass a stand-in.
typedef CareGuideBuilder = Widget Function(BuildContext context, VoidCallback onLoaded);

Widget platformCareGuide(BuildContext context, VoidCallback onLoaded) => _CareGuideWebView(onLoaded: onLoaded);

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  String _status = pageLoading;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.read(context);
    final theme = Theme.of(context);
    return Id(
      TestIds.webviewScreen,
      region: true,
      child: Scaffold(
        appBar: TopBar('Care guide', onBack: scope.notifier!.back),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Id(
                TestIds.webviewStatus,
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _status,
                    style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Id(
                TestIds.webview,
                region: true,
                child: scope.careGuide(context, () {
                  if (mounted && _status != pageLoaded) setState(() => _status = pageLoaded);
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CareGuideWebView extends StatefulWidget {
  const _CareGuideWebView({required this.onLoaded});

  final VoidCallback onLoaded;

  @override
  State<_CareGuideWebView> createState() => _CareGuideWebViewState();
}

class _CareGuideWebViewState extends State<_CareGuideWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    // Debug builds let Appium switch into the page's WEBVIEW context; release builds do not.
    if (defaultTargetPlatform == TargetPlatform.android) AndroidWebViewController.enableDebugging(kDebugMode);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          // Only the bundled page may load, and its in-page links; a link leaving it is refused.
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            final own = uri != null && uri.scheme == 'file' && uri.path.endsWith('/$careGuideAsset');
            return own ? NavigationDecision.navigate : NavigationDecision.prevent;
          },
          onPageFinished: (_) => widget.onLoaded(),
        ),
      );
    final platform = _controller.platform;
    if (platform is WebKitWebViewController) platform.setInspectable(kDebugMode);
    _controller.loadFlutterAsset(careGuideAsset);
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}
