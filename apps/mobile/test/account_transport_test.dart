import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nextcloudnotes/data/account_transport.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';

import 'app_test.dart' show Vault;

void main() {
  test(
    'a cached transport observes a reauthenticated pin and removal',
    () async {
      final db = NotesDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final accounts = AccountRepository(db, Vault());
      LoginCredentials credentials(String password) => LoginCredentials(
        server: ServerBase.parse('https://cloud.example.com'),
        loginName: 'user',
        appPassword: password,
      );
      final id = await accounts.add(credentials('first'));
      final pins = <String?>[];
      var requests = 0;
      final client = AccountTransport(
        db,
        id,
        createClient: (uri, pin) {
          pins.add(pin);
          return MockClient((_) async {
            requests++;
            return http.Response('ok', 200);
          });
        },
      );
      addTearDown(client.close);
      final uri = Uri.parse('https://cloud.example.com/status.php');
      await client.get(uri);
      expect(pins, [null]);
      await accounts.reauthenticate(
        id,
        credentials('next'),
        certificateFingerprint: 'a' * 64,
      );
      await client.get(uri);
      expect(pins, [null, 'a' * 64]);
      await accounts.remove(id);
      await expectLater(
        client.get(uri),
        throwsA(
          isA<http.ClientException>().having(
            (e) => e.message,
            'message',
            'account_removed',
          ),
        ),
      );
      expect(requests, 2);
    },
  );
}
