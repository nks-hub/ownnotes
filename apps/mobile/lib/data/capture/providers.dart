import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_foundation/path_provider_foundation.dart';

import 'capture_inbox.dart';
import 'capture_store.dart';

final captureStoreProvider = FutureProvider<CaptureStore>((ref) async {
  final support = await getApplicationSupportDirectory();
  return CaptureStore(Directory('${support.path}/captures'));
});

const _appGroup = 'group.com.nkshub.nextcloudnotes';

/// Android asks MainActivity over a method channel; iOS reads the App Group
/// folder the share extension writes to.
final captureSourceProvider = FutureProvider<CaptureSource>((ref) async {
  if (Platform.isIOS) {
    final path = await PathProviderFoundation().getContainerPath(
      appGroupIdentifier: _appGroup,
    );
    if (path != null) {
      return GroupFolderCaptureSource(Directory('$path/captures'));
    }
  }
  return const ChannelCaptureSource();
});
