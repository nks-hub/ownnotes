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
    expect(event.message!.formatted, isNot(contains('example.invalid')));
    expect(event.exceptions!.single.value, isNot(contains('c2VjcmV0')));
    expect(event.exceptions!.single.value, isNot(contains('notes/7')));
  });

  test('a breadcrumb keeps its shape but loses the URL', () {
    final crumb = scrubSentryBreadcrumb(
      Breadcrumb(
        message: 'GET https://cloud.example.invalid/x',
        data: {'url': 'https://cloud.example.invalid/x', 'status': 200},
      ),
      Hint(),
    )!;
    expect(crumb.message, 'GET https://<host>');
    expect(crumb.data, {'url': 'https://<host>', 'status': 200});
  });
}
