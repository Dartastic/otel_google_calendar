// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_google_calendar/otel_google_calendar.dart';

/// Traces Google Calendar v3 calls with OpenTelemetry.
///
/// `otel_google_calendar` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Google Calendar v3 call in
/// [tracedGoogleCalendar]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'google-calendar-example');

  // Wraps a Google Calendar v3 call in a CLIENT span.
  final googleCalendarId = await tracedGoogleCalendar<String>(
    operation: 'events.insert',
    calendarId: 'calendar_8f3a2c',
    invoke: () async {
      // Make the Google Calendar v3 call here, then report what it returned.
      const id = 'google_calendar_8f3a2c';
      return const GoogleCalendarCallResult(
          value: id,
          result: GoogleCalendarResult(
              itemCount: 3,
              calendarsQueried: 1,
              usedSyncToken: true,
              nextSyncToken: 'example',
              nextPageToken: 'example',
              eventId: 'event_8f3a2c',
              recurringEventId: 'recurringevent_8f3a2c',
              conferenceCreated: true,
              requestId: 'request_8f3a2c',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedGoogleCalendar events.insert returned $googleCalendarId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutGoogleCalendarInstrumentationAsync.
  await runWithoutGoogleCalendarInstrumentationAsync(
    () => tracedGoogleCalendar<String>(
      operation: 'events.insert',
      calendarId: 'calendar_8f3a2c',
      invoke: () async {
        const id = 'google_calendar_8f3a2c';
        return const GoogleCalendarCallResult(
            value: id,
            result: GoogleCalendarResult(
                itemCount: 3,
                calendarsQueried: 1,
                usedSyncToken: true,
                nextSyncToken: 'example',
                nextPageToken: 'example',
                eventId: 'event_8f3a2c',
                recurringEventId: 'recurringevent_8f3a2c',
                conferenceCreated: true,
                requestId: 'request_8f3a2c',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
