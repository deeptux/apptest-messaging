import 'dart:io';

import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

/// Android-only sqlite3 workaround; no-op on other IO platforms.
Future<void> maybeApplySqliteAndroidWorkaround() async {
  if (Platform.isAndroid) {
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
  }
}
