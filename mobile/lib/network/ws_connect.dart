// Facade: native passes an Origin header (for AllowedHostsOriginValidator);
// web lets the browser set Origin automatically.
export 'ws_connect_web.dart' if (dart.library.io) 'ws_connect_io.dart';
