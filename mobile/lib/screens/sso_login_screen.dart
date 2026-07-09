import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// In-app WebView for the Hive (Microsoft) SSO flow — the mobile mirror of
/// the web's /sso-callback:
///
/// 1. Load Hive's Microsoft login URL (from /auth/microsoft/status/).
/// 2. The user authenticates with Microsoft; the browser session lands back
///    on a Hive (or OrderQ) page holding the Hive session cookie.
/// 3. After every page load we run a credentialed fetch against Hive's
///    `/api/users/auth/check/` inside the WebView. Once it reports an
///    authenticated user, we pop with the verified email; the caller
///    exchanges it for OrderQ JWTs via POST /auth/hive-sso/.
class SsoLoginScreen extends StatefulWidget {
  /// Hive's Microsoft login URL, e.g.
  /// https://acai.brightskiesinc.com/api/users/auth/microsoft/login/
  final String loginUrl;

  const SsoLoginScreen({Key? key, required this.loginUrl}) : super(key: key);

  @override
  State<SsoLoginScreen> createState() => _SsoLoginScreenState();
}

class _SsoLoginScreenState extends State<SsoLoginScreen> {
  late final WebViewController _controller;
  bool _finished = false;
  bool _loading = true;

  /// Hive origin derived from the login URL (scheme://host[:port]).
  String get _hiveOrigin {
    final uri = Uri.parse(widget.loginUrl);
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('OrderQSso', onMessageReceived: (message) {
        _handleCheckResult(message.message);
      })
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          setState(() => _loading = false);
          _probeHiveSession();
        },
      ))
      ..loadRequest(Uri.parse(widget.loginUrl));
  }

  /// Ask Hive who is logged in. Runs inside the WebView so the Hive session
  /// cookie is sent; cross-origin pages (e.g. login.microsoftonline.com)
  /// simply fail the fetch and we try again on the next page load.
  void _probeHiveSession() {
    if (_finished) return;
    final js = '''
      fetch('$_hiveOrigin/api/users/auth/check/', { credentials: 'include' })
        .then(function (r) { return r.json(); })
        .then(function (d) { OrderQSso.postMessage(JSON.stringify(d)); })
        .catch(function (e) { OrderQSso.postMessage('{"authenticated":false}'); });
    ''';
    _controller.runJavaScript(js);
  }

  void _handleCheckResult(String raw) {
    if (_finished || !mounted) return;
    try {
      final data = jsonDecode(raw);
      if (data is Map && data['authenticated'] == true) {
        final user = data['user'];
        final email = user is Map ? user['email'] : null;
        if (email is String && email.isNotEmpty) {
          _finished = true;
          Navigator.of(context).pop(email);
        }
      }
    } catch (_) {
      // Not a session payload (cross-origin failure etc.) — keep waiting.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in with Microsoft'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
