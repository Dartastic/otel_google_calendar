// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_google_calendar_suppression.dart';

const _tracerName = 'dartastic_otel_libs_google_calendar';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

class GoogleCalendarResult {
  /// Creates a result.
  const GoogleCalendarResult({
    this.itemCount,
    this.calendarsQueried,
    this.usedSyncToken,
    this.nextSyncToken,
    this.nextPageToken,
    this.eventId,
    this.recurringEventId,
    this.conferenceCreated,
    this.requestId,
    this.statusCode,
  });

  /// Items returned (`items.length` for list endpoints).
  final int? itemCount;

  /// Number of calendars queried in a freebusy batch — Google bills
  /// extra against the per-batch limit.
  final int? calendarsQueried;

  /// Whether the call used a `syncToken` (incremental sync) — pages
  /// without sync tokens are far more expensive.
  final bool? usedSyncToken;

  /// `nextSyncToken` returned (for telemetry on sync correctness, not
  /// the value itself).
  final String? nextSyncToken;

  final String? nextPageToken;

  /// `id` of an event for insert/update/delete.
  final String? eventId;

  /// `recurringEventId` when this is an instance of a series.
  final String? recurringEventId;

  /// True if `conferenceData` was created (e.g. Google Meet provision).
  final bool? conferenceCreated;

  /// `X-Guploader-UploadID` / opaque request id.
  final String? requestId;

  final int? statusCode;
}

/// What a traced call returned: the value for the caller plus fields
/// recorded on the span.
class GoogleCalendarCallResult<T> {
  /// Creates a call result.
  const GoogleCalendarCallResult({required this.value, this.result});

  /// The value returned to the caller.
  final T value;
  final GoogleCalendarResult? result;
}

/// Wraps a Google Calendar v3 call in a CLIENT span. [operation] is
/// one of `events.list`, `events.insert`, `events.patch`,
/// `events.delete`, `events.instances`, `events.move`,
/// `events.quickAdd`, `freebusy.query`, `calendars.get`,
/// `calendars.insert`, `acl.list`, `acl.insert`, `channels.stop`.
Future<T> tracedGoogleCalendar<T>({
  required String operation,
  required Future<GoogleCalendarCallResult<T>> Function() invoke,
  String? calendarId,
}) async {
  if (googleCalendarInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'google_calendar',
    'rpc.method': operation,
    'google_calendar.operation': operation,
  };
  if (calendarId != null) m['google_calendar.calendar.id'] = calendarId;

  final span = _tracer().startSpan(
    'google_calendar $operation',
    kind: SpanKind.client,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.itemCount != null) {
        extras.add(OTelAPI.attributeInt(
          'google_calendar.item_count',
          r.result!.itemCount!,
        ));
      }
      if (r.result!.calendarsQueried != null) {
        extras.add(OTelAPI.attributeInt(
          'google_calendar.calendars_queried',
          r.result!.calendarsQueried!,
        ));
      }
      if (r.result!.usedSyncToken != null) {
        extras.add(OTelAPI.attributeBool(
          'google_calendar.sync_token.used',
          r.result!.usedSyncToken!,
        ));
      }
      if (r.result!.nextSyncToken != null) {
        extras.add(OTelAPI.attributeBool(
          'google_calendar.next_sync_token.present',
          true,
        ));
      }
      if (r.result!.nextPageToken != null) {
        extras.add(OTelAPI.attributeBool(
          'google_calendar.next_page_token.present',
          true,
        ));
      }
      if (r.result!.eventId != null) {
        extras.add(OTelAPI.attributeString(
          'google_calendar.event.id',
          r.result!.eventId!,
        ));
      }
      if (r.result!.recurringEventId != null) {
        extras.add(OTelAPI.attributeString(
          'google_calendar.event.recurring_event_id',
          r.result!.recurringEventId!,
        ));
      }
      if (r.result!.conferenceCreated != null) {
        extras.add(OTelAPI.attributeBool(
          'google_calendar.conference.created',
          r.result!.conferenceCreated!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTelAPI.attributeString(
          'google_calendar.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTelAPI.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Google Calendar HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTelAPI.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
