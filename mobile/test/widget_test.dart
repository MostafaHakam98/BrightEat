// Config tests — the stock counter template was replaced. These verify the
// native app targets the production backend and derives the WebSocket URL
// correctly (the core of the "app must reach the server" contract).
import 'package:flutter_test/flutter_test.dart';
import 'package:orderq_mobile/config/app_config.dart';

void main() {
  test('native build targets the production HTTPS API', () {
    // In the Flutter test VM kIsWeb is false, so this is the native path.
    expect(AppConfig.apiBaseUrl, 'https://orderq.acai.brightskiesinc.com:19991/api');
  });

  test('wsBaseUrl drops /api and upgrades https -> wss', () {
    expect(AppConfig.wsBaseUrl, 'wss://orderq.acai.brightskiesinc.com:19991');
  });
}
