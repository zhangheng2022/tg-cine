import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart' show MaterialApp;
import 'package:tg_cine/domain/models/local_media.dart';
import 'package:tg_cine/domain/models/media_organization.dart';
import 'package:tg_cine/domain/models/media_work.dart';
import 'package:tg_cine/domain/models/watch_record.dart';
import 'package:tg_cine/l10n/generated/app_localizations.dart';
import 'package:tg_cine/theme/theme.dart';
import 'package:tg_cine/ui/features/library/view_models/library_view_model.dart';
import 'package:tg_cine/ui/features/library/views/works_page.dart';

import '../../../support/fake_media_library_repository.dart';
import '../../../support/fake_telegram_repository.dart';

void main() => workWatchingTests();

void workWatchingTests({Future<void> Function(WidgetTester, String)? capture}) {
  for (final size in [const Size(390, 844), const Size(1440, 900)]) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('work watching versions $size dark=$dark scale=$scale', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
          tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
          addTearDown(tester.view.resetPadding);
          addTearDown(tester.view.resetViewPadding);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final repo = FakeMediaLibraryRepository(empty: true);
          repo.records.addAll(
            List.generate(
              3,
              (i) => LocalMedia(
                sourceId: -1,
                messageId: i + 1,
                remoteUniqueId: 'design-$i',
                sizeBytes: 1024,
                fileName: '设计数据 · 文件版本$i.mp4',
              ),
            ),
          );
          await repo.assignWork(
            const MediaWork(title: '设计数据 · 山间故事', kind: MediaKind.series),
            [
              for (var i = 0; i < 3; i++)
                WorkFileEdit(
                  repo.records[i].versionKey,
                  season: 1,
                  episode: i == 0 ? 1 : 3,
                ),
            ],
          );
          repo.watched.add(
            WatchRecord(
              media: repo.records.first,
              sourceTitle: '设计来源',
              position: const Duration(minutes: 3),
              duration: const Duration(minutes: 20),
              completed: false,
              available: true,
            ),
          );
          final telegram = FakeTelegramRepository(
            restored: true,
            persisted: {-1},
          );
          await telegram.connect();
          final vm = LibraryViewModel(repo, telegram);
          final played = <String>[];
          final theme = dark ? darkTheme : lightTheme;
          await tester.pumpWidget(
            RepaintBoundary(
              key: const ValueKey('daily-capture'),
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                locale: const Locale('zh', 'CN'),
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  ...FLocalizations.localizationsDelegates,
                ],
                supportedLocales: AppLocalizations.supportedLocales,
                theme: theme.toApproximateMaterialTheme(),
                builder: (_, child) => FTheme(data: theme, child: child!),
                home: WorksPage(
                  viewModel: vm,
                  work: (await repo.works()).single,
                  onPlayMedia: (_, media) async {
                    played.add(media.versionKey);
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          Future<void> tap(String label) async {
            final target = find.text(label).first;
            await tester.ensureVisible(target);
            await tester.pumpAndSettle();
            await tester.tap(target);
            await tester.pumpAndSettle();
          }

          final name = '${size.width.toInt()}-$dark-$scale';
          await capture?.call(tester, '$name-work');
          await tap('继续观看');
          expect(played, [repo.records.first.versionKey]);
          await tap('下一集');
          expect(find.text('第 1 季 · 第 3 集'), findsOneWidget);
          expect(find.text('设计数据 · 文件版本0.mp4'), findsNothing);
          expect(played, hasLength(1));
          await capture?.call(tester, '$name-next-versions');
          await tap('播放此文件');
          expect(played.last, repo.records[1].versionKey);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          vm.dispose();
          await telegram.close();
        });
      }
    }
  }
}
