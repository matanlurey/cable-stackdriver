# cable_stackdriver

<p align="center">
  <a href="https://travis-ci.org/matanlurey/cable-stackdriver">
    <img src="https://travis-ci.org/matanlurey/cable-stackdriver.svg?branch=master" alt="Build Status" />
  </a>
  <a href="https://pub.dartlang.org/packages/cable_stackdriver">
    <img src="https://img.shields.io/pub/v/cable_stackdriver.svg" alt="Pub Package Version" />
  </a>
  <a href="https://www.dartdocs.org/documentation/cable_stackdriver/latest">
    <img src="https://img.shields.io/badge/dartdocs-latest-blue.svg" alt="Latest Dartdocs" />
  </a>
</p>

A [Google Stackdriver][] logging plugin for the [cable] logging framework.

[Google Stackdriver]: https://cloud.google.com/logging 
[cable]: https://pub.dartlang.org/packages/cable

* [Installation](#installation)
* [Usage](#usage)
* [Contributing](#contributing)
  * [Testing](#testing)

## Installation

Add `cable_stackdriver` in your [`pubspec.yaml`][pubspec] file:

```yaml
dependencies:
  cable_stackdriver: ^0.1.0
```

And that's it! See [usage](#usage) for details.

## Usage

You can use Stackdriver on the server with a Google Cloud [service account][].

[service account]: https://cloud.google.com/logging/docs/agent/authorization

Once you have a `<key>.json` file, with the scope
* `https://www.googleapis.com/auth/logging.write`

...you can create a `Stackdriver` object:

```dart
import 'dart:async';

import 'package:cable_stackdriver/cable_stackdriver.dart';

Future<Null> main() async {
  final jsonConfig = loadJsonFile();
  final stackdriver = await Stackdriver.serviceAccount<String>(
    jsonConfig,
    logName: 'projects/${jsonConfig['project_id']}/logs/example',
  );
  final logger = new Logger(
    destinations: [
      // Also write to console.
      stackdriver,
    ],
  );

  // You can now use the logger.
  logger.log('Hello World', severity: Severity.warning);

  // Wait until there are no more pending messages being written.
  await stackdriver.onIdle;
  logger.close();
}
```

## Contributing

We welcome a diverse set of contributions, including, but not limited to:

* [Filing bugs and feature requests][file_an_issue]
* [Send a pull request][pull_request]
* Or, create something awesome using this API and share with us and others!

For the stability of the API and existing users, consider opening an issue
first before implementing a large new feature or breaking an API. For smaller
changes (like documentation, minor bug fixes), just send a pull request.

### Testing

All pull requests are validated against [travis][travis], and must pass.

Ensure code passes all our [analyzer checks][analysis_options]:

```sh
$ dartanalyzer .
```

Ensure all code is formatted with the latest [dev-channel SDK][dev_sdk].

```sh
$ dartfmt -w .
```

Run all of our unit tests (IN PROGRESS):

```sh
$ pub run test
```

[analysis_options]: analysis_options.yaml
[travis]: https://travis-ci.org/
[dev_sdk]: https://www.dartlang.org/install]
[file_an_issue]: https://github.com/matanlurey/cable-stackdriver/issues/new
[pull_request]: https://github.com/matanlurey/cable-stackdriver/pulls
