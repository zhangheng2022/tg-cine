import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/ui/features/player/player_interaction_test.dart'
    show playerInteractionTests;
import '../test/ui/features/library/work_watching_test.dart'
    show workWatchingTests;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const output = String.fromEnvironment('TG_CINE_SCREENSHOT_DIR');
  Future<void> capture(WidgetTester tester, String name) async {
    if (output.isEmpty) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('daily-capture')),
    );
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('$output/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  }

  playerInteractionTests(capture: capture);
  workWatchingTests(capture: capture);
}
