import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:notes_protocol/notes_protocol.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  late http.Client transport;
  late NotesClient api;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    transport = http.Client();
    api = NotesClient(
      base: ServerBase.parse(
        'http://127.0.0.1:${server.port}/nc',
        allowInsecureHttp: true,
      ),
      transport: transport,
      loginName: 'synthetic',
      appPassword: 'synthetic',
      timeout: const Duration(milliseconds: 150),
      maxResponseBytes: 1024,
    );
  });
  tearDown(() async {
    transport.close();
    await server.close(force: true);
  });

  test(
    'real HTTP redirect does not send credentials to another endpoint',
    () async {
      var hits = 0;
      server.listen((request) async {
        hits++;
        request.response.statusCode = HttpStatus.found;
        request.response.headers.set(
          HttpHeaders.locationHeader,
          'http://127.0.0.1:${server.port}/unexpected',
        );
        await request.response.close();
      });
      await expectLater(api.get(42), throwsA(isA<NotesHttpException>()));
      expect(hits, 1);
    },
  );

  test(
    'real socket disconnect after receiving POST is uncertain, never retried',
    () async {
      var hits = 0;
      final received = Completer<Map<String, Object?>>();
      server.listen((request) async {
        hits++;
        final body = await utf8.decoder.bind(request).join();
        received.complete(jsonDecode(body) as Map<String, Object?>);
        final socket = await request.response.detachSocket(writeHeaders: false);
        socket.destroy();
      });
      await expectLater(
        api.create(content: 'durable draft', title: 'synthetic'),
        throwsA(isA<MutationUncertain>()),
      );
      expect((await received.future)['content'], 'durable draft');
      expect(hits, 1);
    },
  );

  test(
    'real stalled response hits deadline without repeated mutation',
    () async {
      var hits = 0;
      server.listen((request) async {
        hits++;
        await request.drain<void>();
        // Deliberately leave the response pending until teardown closes it.
      });
      await expectLater(
        api.create(content: 'draft', title: 'synthetic'),
        throwsA(isA<MutationUncertain>()),
      );
      expect(hits, 1);
    },
  );

  test('real oversized stream is bounded', () async {
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(List.filled(2000, 'x')));
      await request.response.close();
    });
    await expectLater(api.list(), throwsA(isA<NotesProtocolException>()));
  });
}
