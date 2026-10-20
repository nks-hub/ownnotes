import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _fontLicenseAsset = 'assets/fonts/OFL-NotoSansMono.txt';
var _registered = false;

/// Adds the SIL Open Font License notice of the bundled Noto Sans Mono subset
/// to the licence page. Call once at startup, before the first frame.
void registerFontLicenses() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(_fontLicenseAsset);
    yield LicenseEntryWithLineBreaks(const ['Noto Sans Mono'], text);
  });
}
