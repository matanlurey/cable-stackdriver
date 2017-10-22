// Copyright 2017, Google Inc.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cable/cable.dart';
import 'package:googleapis/logging/v2.dart' as api;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart';
import 'package:meta/meta.dart';

/// Connects and uses the Google Cloud Logging (Stackdriver) API.
class Stackdriver<T extends Object> implements Sink<Record<T>> {
  final api.LoggingApi _api;
  final Map<String, Object> Function(T record) _toJson;

  final Client _client;

  Timer _buffer;
  final String _logName;
  final Duration _bufferTime;
  final _pending = <api.LogEntry>[];
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
  /// If [logName] is provided, it is used instead of [Record.origin]. This is
  /// **highly suggested**, and relying on [Record.origin] is now _deprecated_.
  ///
  /// If [toJson] is provided, [Record.payload] ([T]) is encoded by it.
  ///
  /// Returns a future that completes once authenticated.
  static Future<Stackdriver<T>> serviceAccount<T>(
    Map<String, Object> json, {
    BaseClient baseClient,
    String logName,
    Duration buffer: const Duration(seconds: 1),
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
    return new Stackdriver.fromHttp(
      httpClient,
      logName: logName,
      buffer: buffer,
      toJson: toJson,
    );
  }

  /// Creates a new [Stackdriver] logging client from an [httpClient].
  ///
  /// This is considered a lower-level API for more customized connections.
  factory Stackdriver.fromHttp(
    Client httpClient, {
    String logName,
    Duration buffer: const Duration(seconds: 1),
    Map<String, Object> Function(T record) toJson,
  }) =>
      new Stackdriver._(
        new api.LoggingApi(httpClient),
        httpClient,
        logName: logName,
        buffer: buffer,
        toJson: toJson,
      );

  Stackdriver._(
    this._api,
    this._client, {
    @required String logName,
    Duration buffer: const Duration(seconds: 1),
    Map<String, Object> Function(T record) toJson,
  })
      : _bufferTime = buffer,
        _logName = logName,
        _toJson = toJson;

  @override
  void add(Record<T> data) {
    final entry = new api.LogEntry()
      ..resource = (new api.MonitoredResource()..type = 'global')
      ..timestamp = '${data.timestamp.toIso8601String()}Z'
      ..labels = {'from': data.origin}
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
    _pending.add(entry);
    if (_bufferTime != Duration.ZERO) {
      final completer = new Completer<Null>.sync();
      _waiting.add(completer.future);
      _buffer ??= new Timer(_bufferTime, () {
        completer.complete();
        _flushBuffer();
      });
    }
  }

  void _flushBuffer() {
    final future = _api.entries
        .write(
          new api.WriteLogEntriesRequest()
            ..logName = _logName
            ..entries = _pending,
        )
        .whenComplete(() => null);
    _waiting.add(future.then((_) => _waiting.remove(future)));
    _buffer = null;
  }

  @override
  void close() {
    _buffer?.cancel();
    _client.close();
  }

  /// Completes when all pending writes have completed.
  Future<Null> get onIdle => Future.wait(_waiting).then((_) => null);
}
