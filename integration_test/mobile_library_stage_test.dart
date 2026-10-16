import 'package:integration_test/integration_test.dart';

import '../test/data/repositories/media_work_test.dart' as works;

// Runs the transactional migration/grouping checks against the platform SQLite
// library, using only test-created temporary databases.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  works.main();
}
