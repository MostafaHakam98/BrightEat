import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';

/// Native WebSocket connect. Sends an Origin header matching the backend host
/// so Channels' AllowedHostsOriginValidator upgrades the connection (a bare
/// dart:io WebSocket sends no Origin, which the server rejects with 403).
WebSocketChannel connectWebSocket(String url) {
  return IOWebSocketChannel.connect(
    Uri.parse(url),
    headers: {'Origin': AppConfig.httpOrigin},
  );
}
