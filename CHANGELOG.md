# 0.1.1

* Added a `logName` parameter, which is `@required` to use Stackdriver. Before
  we used `Logger.name`, but that was both awkward and not technically correct.

* Log entries are buffered, and messages collected within a second are sent
  together. It is possible to change (or disable) this feature by setting
  the `buffer` duration.

# 0.1.0

* Initial release.
