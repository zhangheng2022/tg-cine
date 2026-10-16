import 'package:tg_cine/domain/models/local_media.dart';
import 'package:forui/forui.dart';
import 'package:tg_cine/domain/models/telegram_account.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tg_cine/app/application.dart';
import 'package:tg_cine/domain/models/watch_record.dart';
import 'package:tg_cine/domain/models/media_organization.dart';

import '../../../support/fake_media_library_repository.dart';
import '../../../support/fake_telegram_repository.dart';
import '../../../support/memory_settings_repository.dart';

// Timed swipes give native scrolling a realistic gesture velocity.
Future<void> settledScrollUntilVisible(
  WidgetTester tester,
  Finder target,
  double delta, {
  required Finder scrollable,
  int maxScrolls = 50,
}) async {
  for (var i = 0; i < maxScrolls && target.evaluate().isEmpty; i++) {
    await tester.timedDrag(
      scrollable,
      Offset(0, -delta),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

void main() {
  nextStageUiTests();
  historyRecoveryTests();
  testWidgets('clear-history confirmation is revoked when accounts change', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final telegram = FakeTelegramRepository(restored: true, persisted: {-1});
    final library = FakeMediaLibraryRepository();
    library.watched.add(
      WatchRecord(
        media: library.records.first,
        sourceTitle: 'design',
        position: const Duration(seconds: 10),
        duration: const Duration(seconds: 60),
        completed: false,
        available: true,
      ),
    );
    await tester.pumpWidget(
      Application(
        settingsRepository: MemorySettingsRepository(),
        telegramRepository: telegram,
        libraryRepository: library,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清空观看记录'));
    await tester.pumpAndSettle();
    expect(find.text('确认清空记录'), findsOneWidget);
    telegram.emit(
      TelegramAccount(
        stage: TelegramStage.ready,
        id: 999,
        selectedSources: {-1},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('确认清空记录'), findsNothing);
    expect(find.text('清空观看记录'), findsOneWidget);
    expect(library.watched, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}

void nextStageUiTests({Future<void> Function(WidgetTester, String)? capture}) {
  for (final size in [const Size(320, 568), const Size(1440, 900)]) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'history, continue, update and correction $size $brightness $scale',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.platformBrightnessTestValue = brightness;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(
              tester.platformDispatcher.clearPlatformBrightnessTestValue,
            );
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            final library = FakeMediaLibraryRepository();
            final item = library.records.first;
            library.watched.addAll([
              WatchRecord(
                media: item,
                sourceTitle: '设计数据 · 私人片库',
                position: const Duration(seconds: 42),
                duration: const Duration(minutes: 3),
                completed: false,
                available: true,
                watchedAt: DateTime(2026, 10, 16, 12),
              ),
              WatchRecord(
                media: library.records.last,
                sourceTitle: '设计数据 · 已取消来源',
                position: Duration.zero,
                duration: Duration.zero,
                completed: true,
                available: false,
              ),
            ]);
            await tester.pumpWidget(
              RepaintBoundary(
                key: const ValueKey('next-stage-capture'),
                child: Application(
                  key: UniqueKey(),
                  settingsRepository: MemorySettingsRepository(),
                  telegramRepository: PlaybackLayoutTelegramRepository(
                    restored: true,
                    persisted: {-1},
                  ),
                  libraryRepository: library,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('继续观看'), findsWidgets);
            Future<void> shot(String name) async {
              expect(tester.takeException(), isNull);
              await capture?.call(
                tester,
                '${size.width < 600 ? 'phone' : 'wide'}-${brightness.name}-$scale-$name',
              );
            }

            Future<void> tapText(String text) async {
              final target = find.byWidget(tester.widget(find.text(text).last));
              await tester.ensureVisible(target);
              await tester.pumpAndSettle();
              await tester.tap(target);
              await tester.pumpAndSettle();
            }

            await tester.ensureVisible(find.text('继续观看').first);
            await tester.pumpAndSettle();
            await shot('continue');
            await tapText('记录');
            await shot('history');
            final historyScroll = find
                .descendant(
                  of: find.byKey(const PageStorageKey('watch-history')),
                  matching: find.byType(Scrollable),
                )
                .first;
            await settledScrollUntilVisible(
              tester,
              find.text('已看完'),
              100,
              scrollable: historyScroll,
            );
            expect(find.text('已看完'), findsOneWidget);
            expect(find.text('来源未选中或文件已被替换，请到来源页或片库确认。'), findsOneWidget);
            await tester.ensureVisible(find.text('来源未选中或文件已被替换，请到来源页或片库确认。'));
            await tester.pumpAndSettle();
            await shot('unavailable');
            await settledScrollUntilVisible(
              tester,
              find.text('清空观看记录'),
              -150,
              scrollable: historyScroll,
            );
            await tapText('清空观看记录');
            expect(library.watched, hasLength(2));
            await settledScrollUntilVisible(
              tester,
              find.text('取消'),
              100,
              scrollable: historyScroll,
            );
            await tapText('取消');
            await settledScrollUntilVisible(
              tester,
              find.text('已看完'),
              100,
              scrollable: historyScroll,
            );
            await tapText('移除记录');
            await settledScrollUntilVisible(
              tester,
              find.text('清空观看记录'),
              -150,
              scrollable: historyScroll,
            );
            expect(library.watched, hasLength(1));
            await tapText('清空观看记录');
            await settledScrollUntilVisible(
              tester,
              find.text('确认清空记录'),
              100,
              scrollable: historyScroll,
            );
            await tapText('确认清空记录');
            expect(library.watched, isEmpty);
            expect(library.records, hasLength(2));
            await tapText('片库');
            expect(find.text('继续观看'), findsNothing);
            final scroll = find
                .descendant(
                  of: find.byKey(const PageStorageKey('library-files')),
                  matching: find.byType(Scrollable),
                )
                .first;
            await settledScrollUntilVisible(
              tester,
              find.text('导入来源'),
              -150,
              scrollable: scroll,
            );
            await tapText('导入来源');
            await settledScrollUntilVisible(
              tester,
              find.text('检查更新'),
              100,
              scrollable: scroll,
            );
            await tapText('检查更新');
            expect(library.calls, 1);
            await settledScrollUntilVisible(
              tester,
              find.byKey(ValueKey('media-${item.versionKey}')),
              100,
              scrollable: scroll,
            );
            await tester.tap(find.byKey(ValueKey('media-${item.versionKey}')));
            await tester.pumpAndSettle();
            await tapText('修正影视信息');
            final title = find.byKey(const ValueKey('organization-title'));
            await tester.ensureVisible(title);
            await tester.enterText(title, '设计数据 · 修正后的片名');
            await tester.pumpAndSettle();
            await shot('edit');
            final year = find.byKey(const ValueKey('organization-year'));
            await tester.ensureVisible(year);
            await tester.enterText(year, 'invalid');
            await tapText('保存信息');
            expect(find.textContaining('请填写片名'), findsOneWidget);
            await tester.ensureVisible(year);
            await tester.enterText(year, '2024');
            await tester.pumpAndSettle();
            await tapText('保存信息');
            expect(library.records.first.organization.title, '设计数据 · 修正后的片名');
            expect(library.records.first.organization.year, 2024);
            expect(library.records.first.organization.kind, MediaKind.movie);
            expect(library.records.first.fileName, item.fileName);
            await tapText('修正影视信息');
            await tapText('电视剧');
            for (final entry in {
              'organization-season': '2',
              'organization-episode': '3',
            }.entries) {
              final field = find.byKey(ValueKey(entry.key));
              await tester.ensureVisible(field);
              await tester.enterText(field, entry.value);
              await tester.pumpAndSettle();
            }
            await tapText('保存信息');
            expect(library.records.first.organization.kind, MediaKind.series);
            expect(library.records.first.organization.season, 2);
            expect(library.records.first.organization.episode, 3);

            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
            await tester.pumpAndSettle();
          },
        );
      }
    }
  }
}

void historyRecoveryTests({
  Future<void> Function(WidgetTester, String)? capture,
}) {
  for (final size in [const Size(390, 844), const Size(1440, 900)]) {
    testWidgets('history recovery and paging targets $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final library = FakeMediaLibraryRepository()..fail = true;
      library.watched.addAll(
        List.generate(
          55,
          (i) => WatchRecord(
            media: LocalMedia(
              sourceId: -1,
              messageId: 500 + i,
              remoteUniqueId: 'design-$i',
              sizeBytes: 1024,
              fileName: '设计数据 · 文件 $i.mp4',
            ),
            sourceTitle: '设计数据 · 私人片库',
            position: const Duration(seconds: 10),
            duration: const Duration(seconds: 60),
            completed: false,
            available: true,
          ),
        ),
      );
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('next-stage-capture'),
          child: Application(
            key: UniqueKey(),
            settingsRepository: MemorySettingsRepository(),
            telegramRepository: FakeTelegramRepository(
              restored: true,
              persisted: {-1},
            ),
            libraryRepository: library,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('记录'));
      await tester.pumpAndSettle();
      final retry = find.ancestor(
        of: find.text('重新读取'),
        matching: find.byType(FButton),
      );
      expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
      await capture?.call(
        tester,
        '${size.width < 600 ? 'phone' : 'wide'}-system-1.0-history-error',
      );
      library.fail = false;
      await tester.tap(find.text('重新读取'));
      await tester.pumpAndSettle();
      final scroll = find
          .descendant(
            of: find.byKey(const PageStorageKey('watch-history')),
            matching: find.byType(Scrollable),
          )
          .first;
      await settledScrollUntilVisible(
        tester,
        find.text('加载更多视频'),
        500,
        scrollable: scroll,
        maxScrolls: 100,
      );
      await tester.pumpAndSettle();
      final more = find.ancestor(
        of: find.text('加载更多视频'),
        matching: find.byType(FButton),
      );
      expect(tester.getSize(more).height, greaterThanOrEqualTo(48));
      await capture?.call(
        tester,
        '${size.width < 600 ? 'phone' : 'wide'}-system-1.0-history-more',
      );
      await tester.tap(find.text('加载更多视频'));
      await tester.pumpAndSettle();
      await settledScrollUntilVisible(
        tester,
        find.text('设计数据 · 文件 54.mp4'),
        200,
        scrollable: scroll,
      );
      expect(find.text('加载更多视频'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
