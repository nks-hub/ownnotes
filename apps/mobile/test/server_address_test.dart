import 'package:flutter_test/flutter_test.dart';
import 'package:nextcloudnotes/features/server_address.dart';

void main() {
  group('normalizeServerAddressInput', () {
    test('strips clipboard wrapping and whitespace', () {
      expect(
        normalizeServerAddressInput('  <https://cloud.example.com>, '),
        'https://cloud.example.com',
      );
    });
    test('collapses a doubled scheme', () {
      expect(
        normalizeServerAddressInput('https://https://cloud.example.com'),
        'https://cloud.example.com',
      );
    });
    test('drops query, fragment and Nextcloud routes', () {
      expect(
        normalizeServerAddressInput(
          'https://cloud.example.com/index.php/apps/notes/?x=1#top',
        ),
        'https://cloud.example.com',
      );
    });
    test('keeps a subdirectory install', () {
      expect(
        normalizeServerAddressInput('https://example.com/nc/index.php/login'),
        'https://example.com/nc',
      );
      expect(
        normalizeServerAddressInput('https://example.com/nc/'),
        'https://example.com/nc',
      );
    });
  });

  group('parseServerAddress', () {
    test('assumes https when no scheme is typed', () {
      expect(
        parseServerAddress('cloud.example.com').uri.toString(),
        'https://cloud.example.com',
      );
    });
    test('empty input and the bare scheme are reported as empty', () {
      for (final raw in ['', '   ', 'https://']) {
        expect(
          () => parseServerAddress(raw),
          throwsA(
            isA<ServerAddressException>().having(
              (e) => e.problem,
              'problem',
              ServerAddressProblem.empty,
            ),
          ),
        );
      }
    });
    test('plain http is refused with its own message', () {
      expect(
        () => parseServerAddress('http://cloud.example.com'),
        throwsA(
          isA<ServerAddressException>().having(
            (e) => e.problem,
            'problem',
            ServerAddressProblem.insecure,
          ),
        ),
      );
    });
    test('garbage is invalid', () {
      expect(
        () => parseServerAddress('https://user:pw@cloud.example.com'),
        throwsA(isA<ServerAddressException>()),
      );
      expect(
        () => parseServerAddress('ftp://cloud.example.com'),
        throwsA(isA<ServerAddressException>()),
      );
    });
  });
}
