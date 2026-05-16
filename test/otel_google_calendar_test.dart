// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_google_calendar/otel_google_calendar.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_google_calendar-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('events.list records sync_token + page_token + item_count', () async {
    await tracedGoogleCalendar<String>(
      operation: 'events.list',
      calendarId: 'primary',
      invoke: () async => const GoogleCalendarCallResult(
        value: 'ok',
        result: GoogleCalendarResult(
          itemCount: 50,
          usedSyncToken: true,
          nextSyncToken: 'tok-1',
          nextPageToken: null,
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('google_calendar events.list')!);
    expect(a['google_calendar.calendar.id'], 'primary');
    expect(a['google_calendar.sync_token.used'], true);
    expect(a['google_calendar.next_sync_token.present'], true);
    expect(a['google_calendar.item_count'], 50);
  });

  test('freebusy.query records calendars_queried', () async {
    await tracedGoogleCalendar<String>(
      operation: 'freebusy.query',
      invoke: () async => const GoogleCalendarCallResult(
        value: 'ok',
        result: GoogleCalendarResult(calendarsQueried: 12),
      ),
    );
    final a = attrsOf(spans.findSpanByName('google_calendar freebusy.query')!);
    expect(a['google_calendar.calendars_queried'], 12);
  });

  test('events.insert with conference create', () async {
    await tracedGoogleCalendar<String>(
      operation: 'events.insert',
      invoke: () async => const GoogleCalendarCallResult(
        value: 'ok',
        result: GoogleCalendarResult(
          eventId: 'ev-1',
          conferenceCreated: true,
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('google_calendar events.insert')!);
    expect(a['google_calendar.event.id'], 'ev-1');
    expect(a['google_calendar.conference.created'], true);
  });

  test('suppression skips spans', () async {
    await runWithoutGoogleCalendarInstrumentationAsync(() async {
      await tracedGoogleCalendar<String>(
        operation: 'events.list',
        invoke: () async => const GoogleCalendarCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('google_calendar '), isEmpty);
  });
}
