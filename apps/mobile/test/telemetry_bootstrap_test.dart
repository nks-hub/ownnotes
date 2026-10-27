import 'package:flutter_test/flutter_test.dart';
import 'package:nextcloudnotes/core/telemetry_bootstrap.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() {
  test('an event loses its request, server URLs and credentials', () {
    const url =
        'https://cloud.example.invalid/index.php/apps/notes/api/v1/notes/7';
    final event = scrubSentryEvent(
      SentryEvent(
        request: SentryRequest(url: url),
        message: SentryMessage('PUT $url failed'),
        exceptions: [
          SentryException(
            type: 'HttpException',
            value: 'Authorization: Basic c2VjcmV0 at $url',
          ),
        ],
      ),
    );
    expect(event.request, isNull);
    expect(event.message, isNull);
    expect(event.exceptions!.single.value, isNot(contains('c2VjcmV0')));
    expect(event.exceptions!.single.value, isNot(contains('notes/7')));
  });

  test('a navigation breadcrumb only keeps known route names', () {
    final crumb = scrubSentryBreadcrumb(
      Breadcrumb(
        category: 'navigation',
        message: 'GET https://cloud.example.invalid/x',
        data: {'to': '/note', 'from': '/note/private-title', 'title': 'Secret'},
      ),
      Hint(),
    )!;
    expect(crumb.message, isNull);
    expect(crumb.data, {'to': '/note'});
  });

  test('messages and console breadcrumbs cannot send note text', () {
    final event = scrubSentryEvent(
      SentryEvent(
        message: SentryMessage('Private note contents'),
        // ignore: deprecated_member_use
        extra: {
          'note': {'body': 'Private note contents'},
        },
        user: SentryUser(email: 'person@example.invalid'),
        exceptions: [
          SentryException(
            type: 'FormatException',
            value: 'Unexpected character (at offset 4)',
          ),
        ],
        breadcrumbs: [
          Breadcrumb(category: 'console', message: 'Private note contents'),
        ],
      ),
    );
    expect(event.toJson().toString(), isNot(contains('Private note contents')));
    expect(event.user, isNull);
    expect(event.exceptions!.single.type, 'FormatException');
  });

  test('error text stays readable for diagnosis', () {
    final event = scrubSentryEvent(
      SentryEvent(
        exceptions: [
          SentryException(type: 'StateError', value: 'Bad state: No element'),
        ],
      ),
    );
    expect(event.exceptions!.single.value, 'Bad state: No element');
  });
}
