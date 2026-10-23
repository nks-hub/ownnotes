import 'package:rybbit_flutter_sdk/rybbit_flutter_sdk.dart';
// The SDK accepts RybbitTransport but does not re-export its declaration.
// ignore: implementation_imports
import 'package:rybbit_flutter_sdk/src/services/http_client.dart';

import 'telemetry_preferences.dart';

class ConsentTransport implements RybbitTransport {
  ConsentTransport(this.delegate, this.preferences);

  final RybbitTransport delegate;
  final TelemetryPreferences preferences;

  @override
  Future<bool> sendEvent(TrackPayload payload) async =>
      !preferences.enabled || await delegate.sendEvent(payload);

  @override
  Future<bool> sendIdentify(IdentifyPayload payload) async =>
      !preferences.enabled || await delegate.sendIdentify(payload);

  @override
  Future<bool> hasSiteIcon(String siteId) async =>
      !preferences.enabled || await delegate.hasSiteIcon(siteId);

  @override
  Future<bool> uploadSiteIcon(String siteId, String base64Png) async =>
      !preferences.enabled || await delegate.uploadSiteIcon(siteId, base64Png);
}
