// Copyright 2017, Google Inc.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cable/cable.dart';
import 'package:cable_stackdriver/cable_stackdriver.dart';

/// An example of using `cable-stackdriver` on the server in the VM.
///
/// It is expected that this is running in a privileged environment with
/// a Google Cloud service account. To be able to run this example, create
/// a service account, download the provided `.json` key file, and provide the
/// path to the file as the only argument to this binary:
/// ```bash
/// $ dart bin/example.dart /path/to/file.json
/// ```
///
/// You should expect a simple message, 'Hello World', to be logged.
///
/// The scope `'https://www.googleapis.com/auth/logging.write'` is required.
Future<Null> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln(
      'Expected a single argument, a path to a <account>.json file',
    );
    exitCode = 1;
    return;
  }

  // We need to connect to Google first, and authenticate.
  print('Authenticating...');
  final Map<String, Object> json = JSON.decode(
    new File(args.first).readAsStringSync(),
  );
  final stackdriver = await Stackdriver.serviceAccount<String>(json);

  // Now we use the authenticated state to create a Sink<Record>.
  print('Authenticated!');

  // And then create a logger to use below.
  final logger = new Logger(
    destinations: [
      // Also write to console.
      LogSink.printSink,
      stackdriver,
    ],
    // This exact format is required to log to Google cloud.
    name: 'projects/${json['project_id']}/logs/example',
  )..log('Hello World', severity: Severity.warning);

  // Wait until there are no more pending messages being written.
  await stackdriver.onIdle;
  logger.close();
}
