import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  // Optional build-time override:
  //   flutter build web --dart-define=API_BASE_URL=https://example.com/api
  static const String _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

  // Fallback for native (non-web) builds where there is no page origin.
  static const String productionUrl =
      'https://orderq.acai.brightskiesinc.com:19991/api';

  // For Android emulator (use 10.0.2.2 to access host machine):
  static const String androidEmulatorUrl = 'http://10.0.2.2:19992/api';

  // For iOS simulator (use localhost):
  static const String iosSimulatorUrl = 'http://localhost:19992/api';

  /// REST base URL.
  ///
  /// On web the PWA is served by the same nginx that proxies /api to the
  /// backend, so the page origin is always correct (and same-origin — no
  /// mixed-content or CORS issues). Never hardcode a host here for web.
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    if (kIsWeb) return '${Uri.base.origin}/api';
    return productionUrl;
  }

  /// WebSocket base URL (no /api suffix — nginx routes /ws at the root).
  /// e.g. wss://host:19991 → connect to '$wsBaseUrl/ws/orders/1/'.
  static String get wsBaseUrl {
    var base = apiBaseUrl;
    if (base.endsWith('/api')) {
      base = base.substring(0, base.length - '/api'.length);
    }
    if (base.startsWith('https://')) {
      return base.replaceFirst('https://', 'wss://');
    }
    if (base.startsWith('http://')) {
      return base.replaceFirst('http://', 'ws://');
    }
    return 'wss://$base';
  }
}
