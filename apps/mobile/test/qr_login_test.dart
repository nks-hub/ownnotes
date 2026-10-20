import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nextcloudnotes/features/qr_login.dart';
import 'package:zxing2/qrcode.dart';

void main() {
  group('parseQrLoginPayload', () {
    test('reads credentials in any element order, URL-decoded', () {
      final payload = parseQrLoginPayload(
        'nc://login/server:https://cloud.example.com&user:a%20b'
        '&password:p%2Bw+x',
      );
      expect(payload, isA<QrLoginCredentials>());
      final c = payload! as QrLoginCredentials;
      expect(c.loginName, 'a b');
      expect(c.secret, 'p+w x');
      expect(c.isOneTime, isFalse);
      expect(c.server.uri.toString(), 'https://cloud.example.com');
    });
    test('one-time prefix is flagged', () {
      final c =
          parseQrLoginPayload(
                'nc://onetime-login/user:u&password:t&server:https://c.test',
              )!
              as QrLoginCredentials;
      expect(c.isOneTime, isTrue);
    });
    test('server only means a normal login for that server', () {
      expect(
        parseQrLoginPayload('nc://login/server:https://c.test'),
        isA<QrLoginServerOnly>(),
      );
      expect(
        parseQrLoginPayload('nc://onetime-login/server:https://c.test'),
        isNull,
      );
    });
    test('rejects everything else', () {
      for (final raw in [
        'https://c.test',
        'nc://login/user:u&password:p',
        'nc://login/user:u&server:https://c.test',
        'nc://login/user:u&user:v&password:p',
        'nc://login/user:u&password:p&server:http://c.test',
        'nc://login/user:u&password:p&server:https://c.test&extra:1',
        'nc://login/user:a:b&password:p&server:https://c.test',
        'nc://login/user:&password:p&server:https://c.test',
        'nc://login/user:%ZZ&password:p&server:https://c.test',
      ]) {
        expect(parseQrLoginPayload(raw), isNull, reason: raw);
      }
    });
    test('credentials never show up in toString', () {
      final c = parseQrLoginPayload(
        'nc://login/user:u&password:hunter2&server:https://c.test',
      )!;
      expect('$c', isNot(contains('hunter2')));
    });
  });

  group('decodeQrFromLuminance', () {
    const text = 'nc://login/user:u&password:p&server:https://c.test';

    // Renders a real QR code into a luminance plane with padded rows.
    Uint8List render(int scale, int quiet, int padding, List<int> size) {
      final code = Encoder.encode(text, ErrorCorrectionLevel.m).matrix!;
      final side = (code.width + 2 * quiet) * scale;
      final stride = side + padding;
      final luma = Uint8List(stride * side)..fillRange(0, stride * side, 255);
      for (var y = 0; y < code.height; y++) {
        for (var x = 0; x < code.width; x++) {
          if (code.get(x, y) != 1) continue;
          for (var dy = 0; dy < scale; dy++) {
            for (var dx = 0; dx < scale; dx++) {
              luma[((y + quiet) * scale + dy) * stride +
                      (x + quiet) * scale +
                      dx] =
                  0;
            }
          }
        }
      }
      size
        ..clear()
        ..addAll([side, stride]);
      return luma;
    }

    test('decodes a rendered code, with and without row padding', () {
      for (final padding in [0, 24]) {
        final size = <int>[];
        final luma = render(6, 4, padding, size);
        expect(
          decodeQrFromLuminance(
            luma: luma,
            width: size[0],
            height: size[0],
            bytesPerRow: size[1],
          ),
          text,
          reason: 'padding $padding',
        );
      }
    });
    test('a blank frame and bad geometry give null', () {
      expect(
        decodeQrFromLuminance(
          luma: Uint8List(64 * 64)..fillRange(0, 64 * 64, 200),
          width: 64,
          height: 64,
          bytesPerRow: 64,
        ),
        isNull,
      );
      expect(
        decodeQrFromLuminance(
          luma: Uint8List(10),
          width: 64,
          height: 64,
          bytesPerRow: 64,
        ),
        isNull,
      );
    });
  });
}
