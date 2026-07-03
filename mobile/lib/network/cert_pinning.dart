// Facade: native uses dart:io HttpOverrides; web is a no-op (browsers handle TLS).
export 'cert_pinning_stub.dart'
    if (dart.library.io) 'cert_pinning_io.dart';
