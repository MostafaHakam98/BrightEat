import 'dart:io';
import 'package:crypto/crypto.dart';

/// Trusts ONLY the OrderQ production server's self-signed certificate,
/// identified by its SHA-256 fingerprint. Every other host is validated
/// normally, and any other invalid cert is still rejected — so this does
/// not weaken TLS globally, it just lets the app reach the one server whose
/// cert isn't issued by a public CA (and whose CN doesn't match the domain).
///
/// If the server certificate is ever regenerated, update _pinnedSha256.
/// Current cert is valid until 2027-01-04.
const _pinnedSha256 =
    '0d8f4f442335723a291d96578e74921ec9777e8a12bbd712df65502e5c7061c6';

class _PinnedHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    // Only fires when default validation fails (untrusted issuer / CN mismatch).
    client.badCertificateCallback = (X509Certificate cert, String host, int port) {
      return sha256.convert(cert.der).toString() == _pinnedSha256;
    };
    return client;
  }
}

void applyCertPinning() {
  HttpOverrides.global = _PinnedHttpOverrides();
}
