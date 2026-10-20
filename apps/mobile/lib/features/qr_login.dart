import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:zxing2/qrcode.dart';

import '../l10n/app_localizations.dart';

const _loginPrefix = 'nc://login/';
const _oneTimePrefix = 'nc://onetime-login/';
// A QR code holds at most 2953 bytes, so anything longer never came from one.
const _maxPayloadLength = 4096;

/// What a scanned `nc://login/` code says. The format is Nextcloud's: up to
/// three `user:`, `password:` and `server:` elements joined by `&`.
sealed class QrLoginPayload {
  const QrLoginPayload(this.server);
  final ServerBase server;
}

/// Only a server address: the caller starts a normal browser login for it.
final class QrLoginServerOnly extends QrLoginPayload {
  const QrLoginServerOnly(super.server);
}

final class QrLoginCredentials extends QrLoginPayload {
  const QrLoginCredentials({
    required ServerBase server,
    required this.loginName,
    required this.secret,
    required this.isOneTime,
  }) : super(server);
  final String loginName;

  /// The app password, or the single-use token when [isOneTime].
  final String secret;
  final bool isOneTime;

  @override
  String toString() => 'QrLoginCredentials(redacted)';
}

/// Parses an untrusted scanned string; null for anything that is not a
/// well-formed Nextcloud login code. Unknown and repeated keys are refused.
QrLoginPayload? parseQrLoginPayload(String raw) {
  if (raw.length > _maxPayloadLength) return null;
  final bool oneTime;
  final String body;
  if (raw.startsWith(_oneTimePrefix)) {
    oneTime = true;
    body = raw.substring(_oneTimePrefix.length);
  } else if (raw.startsWith(_loginPrefix)) {
    oneTime = false;
    body = raw.substring(_loginPrefix.length);
  } else {
    return null;
  }
  final elements = body.split('&');
  if (elements.length > 3) return null;
  final values = <String, String>{};
  for (final element in elements) {
    final key = const [
      'user:',
      'password:',
      'server:',
    ].where(element.startsWith).firstOrNull;
    if (key == null || values.containsKey(key)) return null;
    final String value;
    try {
      // Android decodes with URLDecoder, where `+` is a space.
      value = Uri.decodeQueryComponent(element.substring(key.length));
    } on ArgumentError {
      return null;
    } on FormatException {
      return null;
    }
    if (value.isEmpty || value.length > 4096) return null;
    values[key] = value;
  }
  final rawServer = values['server:'];
  if (rawServer == null) return null;
  final ServerBase server;
  try {
    server = ServerBase.parse(rawServer);
  } on FormatException {
    return null;
  }
  final user = values['user:'];
  final secret = values['password:'];
  if (user == null && secret == null) {
    return oneTime ? null : QrLoginServerOnly(server);
  }
  if (user == null || secret == null || user.contains(':')) return null;
  return QrLoginCredentials(
    server: server,
    loginName: user,
    secret: secret,
    isOneTime: oneTime,
  );
}

/// Reads a QR code out of one planar 8-bit luminance frame. Camera YUV frames
/// start with exactly that plane, so it is wrapped without conversion. Null
/// whenever the frame holds no readable code, which is almost every frame.
String? decodeQrFromLuminance({
  required Uint8List luma,
  required int width,
  required int height,
  required int bytesPerRow,
}) {
  if (width <= 0 || height <= 0 || bytesPerRow < width) return null;
  if (luma.length < bytesPerRow * (height - 1) + width) return null;
  try {
    final bitmap = BinaryBitmap(
      HybridBinarizer(_PlanarLuminanceSource(luma, width, height, bytesPerRow)),
    );
    return QRCodeReader().decode(bitmap).text;
  } on Object {
    // "No code here" arrives as one of several exception types; none helps.
    return null;
  }
}

final class _PlanarLuminanceSource extends LuminanceSource {
  _PlanarLuminanceSource(this._luma, int width, int height, this._bytesPerRow)
    : super(width, height);
  final Uint8List _luma;
  final int _bytesPerRow;

  @override
  Int8List getRow(int y, Int8List? row) {
    final output = row == null || row.length < width ? Int8List(width) : row;
    final start = y * _bytesPerRow;
    for (var x = 0; x < width; x++) {
      output[x] = _luma[start + x];
    }
    return output;
  }

  @override
  Int8List getMatrix() {
    final matrix = Int8List(width * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        matrix[y * width + x] = _luma[y * _bytesPerRow + x];
      }
    }
    return matrix;
  }
}

enum QrScanFailure { permissionDenied, unavailable }

final class QrScanException implements Exception {
  const QrScanException(this.failure);
  final QrScanFailure failure;
}

/// A running camera preview that reports every QR string it reads.
abstract interface class QrScanSession {
  Stream<String> get payloads;
  Widget buildPreview();
  Future<void> close();
}

typedef QrScanSessionOpener = Future<QrScanSession> Function();

const _cameraPermission = MethodChannel(
  'com.nkshub.nextcloudnotes/camera_permission',
);

/// Whether the camera may be opened, asking once if never asked. Android's
/// camera plugin never reports a refusal to Dart (initialize() just hangs), so
/// the host activity answers instead; iOS reports it as a CameraException.
Future<bool> ensureCameraPermission() async {
  if (defaultTargetPlatform != TargetPlatform.android) return true;
  Future<String?> status(String method) async {
    try {
      final r = await _cameraPermission.invokeMapMethod<String, String>(method);
      return r?['status'];
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  var result = await status('status');
  if (result == 'notDetermined') result = await status('request');
  return result == 'granted';
}

Future<bool> openAppSettings() async {
  try {
    return await _cameraPermission.invokeMethod<bool>('openSettings') ?? false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}

Future<QrScanSession> openCameraQrScanSession() async {
  if (!await ensureCameraPermission()) {
    throw const QrScanException(QrScanFailure.permissionDenied);
  }
  final List<CameraDescription> cameras;
  try {
    cameras = await availableCameras();
  } on CameraException {
    throw const QrScanException(QrScanFailure.unavailable);
  }
  if (cameras.isEmpty) throw const QrScanException(QrScanFailure.unavailable);
  final description = cameras.firstWhere(
    (c) => c.lensDirection == CameraLensDirection.back,
    orElse: () => cameras.first,
  );
  final controller = CameraController(
    description,
    ResolutionPreset.medium,
    enableAudio: false,
    imageFormatGroup: ImageFormatGroup.yuv420,
  );
  final session = _CameraQrScanSession(controller);
  try {
    await controller.initialize();
    await controller.startImageStream(session._onFrame);
  } on CameraException catch (e) {
    await session.close();
    final denied =
        e.code.toLowerCase().contains('permission') ||
        e.code.toLowerCase().contains('accessdenied');
    throw QrScanException(
      denied ? QrScanFailure.permissionDenied : QrScanFailure.unavailable,
    );
  } on Object {
    await session.close();
    throw const QrScanException(QrScanFailure.unavailable);
  }
  return session;
}

final class _CameraQrScanSession implements QrScanSession {
  _CameraQrScanSession(this._controller);
  final CameraController _controller;
  final _payloads = StreamController<String>();
  DateTime _lastAttempt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _closed = false;

  @override
  Stream<String> get payloads => _payloads.stream;

  @override
  Widget buildPreview() => CameraPreview(_controller);

  void _onFrame(CameraImage image) {
    if (_closed || image.planes.isEmpty) return;
    final now = DateTime.now();
    // One decode per interval keeps a codeless camera from pinning the CPU.
    if (now.difference(_lastAttempt) < const Duration(milliseconds: 200)) {
      return;
    }
    _lastAttempt = now;
    final plane = image.planes.first;
    final payload = decodeQrFromLuminance(
      luma: plane.bytes,
      width: image.width,
      height: image.height,
      bytesPerRow: plane.bytesPerRow,
    );
    if (payload != null && !_closed) _payloads.add(payload);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    // Best effort: the screen closes this without awaiting.
    try {
      if (_controller.value.isStreamingImages) {
        await _controller.stopImageStream();
      }
    } on Object {
      /* disposed below either way */
    }
    try {
      await _controller.dispose();
    } on Object {
      /* CameraX throws when the preview surface was never set up */
    }
    await _payloads.close();
  }
}

/// Full-screen camera view that returns the parsed `nc://login/` payload. The
/// scanned string carries an app password, so it never leaves this screen
/// unparsed and is never logged or shown.
class QrLoginScannerScreen extends StatefulWidget {
  const QrLoginScannerScreen({
    super.key,
    this.openSession = openCameraQrScanSession,
  });
  final QrScanSessionOpener openSession;

  static Future<QrLoginPayload?> push(BuildContext context) =>
      Navigator.of(context).push<QrLoginPayload>(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/login/qr'),
          builder: (_) => const QrLoginScannerScreen(),
        ),
      );

  @override
  State<QrLoginScannerScreen> createState() => _QrLoginScannerScreenState();
}

class _QrLoginScannerScreenState extends State<QrLoginScannerScreen> {
  QrScanSession? _session;
  StreamSubscription<String>? _subscription;
  QrScanFailure? _failure;
  bool _unreadable = false;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_session?.close());
    super.dispose();
  }

  Future<void> _open() async {
    try {
      final session = await widget.openSession();
      if (!mounted) {
        await session.close();
        return;
      }
      _subscription = session.payloads.listen(_onPayload);
      setState(() => _session = session);
    } on QrScanException catch (e) {
      if (mounted) setState(() => _failure = e.failure);
    } on Object {
      if (mounted) setState(() => _failure = QrScanFailure.unavailable);
    }
  }

  void _onPayload(String raw) {
    if (_handled) return;
    final payload = parseQrLoginPayload(raw);
    if (payload == null) {
      if (!_unreadable) setState(() => _unreadable = true);
      return;
    }
    _handled = true;
    Navigator.of(context).pop(payload);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final failure = _failure;
    final session = _session;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(l.scanLoginCode)),
      body: failure != null
          ? _ScannerMessage(
              message: failure == QrScanFailure.permissionDenied
                  ? l.scanCameraDenied
                  : l.scanCameraUnavailable,
              onOpenSettings: failure == QrScanFailure.permissionDenied
                  ? openAppSettings
                  : null,
              label: l.openAppSettings,
            )
          : session == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              fit: StackFit.expand,
              children: [
                session.buildPreview(),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 24,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        _unreadable
                            ? l.scanLoginCodeUnreadable
                            : l.scanLoginCodeHint,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ScannerMessage extends StatelessWidget {
  const _ScannerMessage({
    required this.message,
    required this.onOpenSettings,
    required this.label,
  });
  final String message;
  final Future<bool> Function()? onOpenSettings;
  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_photography_outlined, color: Colors.white70),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
          if (onOpenSettings != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => unawaited(onOpenSettings!()),
              child: Text(label),
            ),
          ],
        ],
      ),
    ),
  );
}
