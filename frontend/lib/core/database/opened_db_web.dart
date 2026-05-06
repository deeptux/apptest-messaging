import 'package:drift/drift.dart';
import 'package:drift/web.dart';

/// Web uses sql.js (see `web/index.html`); deprecated API but avoids FFI on web.
LazyDatabase openAppDatabaseConnection() {
  return LazyDatabase(() async => WebDatabase('phase1'));
}
