// Copyright 2017, Google Inc.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cable/cable.dart';
import 'package:googleapis/logging/v2.dart' as api;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart';
import 'package:meta/meta.dart';

@immutable
class Stackdriver<T extends Object> implements Sink<Record<T>> {
  final api.LoggingApi _api;
  final Map<String, Object> Function(T record) _toJson;

  final Client _client;
  final _waiting = <Future<Object>>[];

  /// Creates a new [Stackdriver] logging client for a service account.
  ///
  /// **NOTE**: This API only works where `dart:io` is an accessible API.
  ///
  /// It is assumed that [json] is the `.json`-formatted key information for
  /// a Google cloud service account that has the scope
  /// `https://www.googleapis.com/auth/logging.write` permission.
  ///
  /// May optionally define a [baseClient] for HTTP access.
  ///
  /// If [toJson] is provided, [Record.payload] ([T]) is encoded by it.
  ///
  /// Returns a future that completes once authenticated.
  static Future<Stackdriver<T>> serviceAccount<T>(
    Map<String, Object> json, {
    BaseClient baseClient,
    Map<String, Object> Function(T record) toJson,
  }) async {
    if (!const bool.fromEnvironment('dart.library.io')) {
      throw new UnsupportedError('The dart:io library is not available');
    }
    final httpClient = await clientViaServiceAccount(
      new ServiceAccountCredentials.fromJson(json),
      const [
        'https://www.googleapis.com/auth/logging.write',
      ],
      baseClient: baseClient,
    );
    return new Stackdriver.fromHttp(httpClient, toJson: toJson);
  }

  /// Creates a new [Stackdriver] logging client from an [httpClient].
  ///
  /// This is considered a lower-level API for more customized connections.
  factory Stackdriver.fromHttp(
    Client httpClient, {
    Map<String, Object> Function(T record) toJson,
  }) =>
      new Stackdriver._(
        new api.LoggingApi(httpClient),
        httpClient,
        toJson: toJson,
      );

  Stackdriver._(
    this._api,
    this._client, {
    Map<String, Object> Function(T record) toJson,
  })
      : _toJson = toJson;

  @override
  void add(Record<T> data) {
    final entry = new api.LogEntry()
      ..resource = (new api.MonitoredResource()..type = 'global')
      ..timestamp = '${data.timestamp.toIso8601String()}Z'
      ..severity = const {
            Severity.debug: 'DEBUG',
            Severity.info: 'INFO',
            Severity.notice: 'NOTICE',
            Severity.warning: 'WARNING',
            Severity.error: 'ERROR',
            Severity.critical: 'CRITICAL',
            Severity.alert: 'ALERT',
            Severity.emergency: 'EMERGENCY',
          }[data.severity] ??
          'DEFAULT';
    final payload = data.payload;
    if (payload is String) {
      entry.textPayload = payload;
    } else {
      if (_toJson == null) {
        throw new StateError('No "toJson" encoder provided for $payload.');
      }
      entry.jsonPayload = _toJson(payload);
    }
    final future = _api.entries
        .write(
          new api.WriteLogEntriesRequest()
            ..logName = data.origin
            ..entries = [entry],
        )
        .whenComplete(() => null);
    _waiting.add(future.then((_) => _waiting.remove(future)));
  }

  @override
  void close() => _client.close();

  /// Completes when all pending writes have completed.
  Future<Null> get onIdle => Future.wait(_waiting).then((_) => null);
}
