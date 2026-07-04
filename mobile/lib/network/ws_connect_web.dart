import 'package:web_socket_channel/web_socket_channel.dart';

/// Web WebSocket connect — the browser sets the Origin header itself.
WebSocketChannel connectWebSocket(String url) {
  return WebSocketChannel.connect(Uri.parse(url));
}
