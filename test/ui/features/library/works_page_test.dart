import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tg_cine/app/application.dart';
import 'package:tg_cine/domain/models/local_media.dart';
import 'package:tg_cine/domain/models/media_work.dart';
import 'package:tg_cine/domain/models/media_organization.dart';
import 'package:tg_cine/domain/models/telegram_account.dart';

import '../../../support/fake_media_library_repository.dart';
import '../../../support/fake_telegram_repository.dart';
import '../../../support/memory_settings_repository.dart';

void main() {
  workUiTests();
  testWidgets('work file detail shows saved metadata without reopening', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final library = FakeMediaLibraryRepository();
    await library.assignWork(
      const MediaWork(title: '设计数据 · 作品', kind: MediaKind.movie, year: 2024),
      [WorkFileEdit(library.records.first.versionKey)],
    );
    await tester.pumpWidget(
      Application(
        settingsRepository: MemorySettingsRepository(),
        telegramRepository: FakeTelegramRepository(
          restored: true,
          persisted: {-1},
        ),
        libraryRepository: library,
      ),
    );
    await tester.pumpAndSettle();
    Future<void> tap(String text) async {
      final finder = find.text(text).last;
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    await tap('作品片库');
    await tap('设计数据 · 作品 · 2024\n1 个文件版本');
    await tap('文件详情');
    await tap('修正影视信息');
    final field = find.byKey(const ValueKey('organization-title'));
    await tester.ensureVisible(field);
    await tester.enterText(field, '设计数据 · 新片名');
    await tap('保存信息');
    expect(find.text('设计数据 · 新片名'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}

void workUiTests({Future<void> Function(WidgetTester, String)? capture}) {
  for (final size in [const Size(320, 568), const Size(1440, 900)]) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'works grouping, seasons, preview, failure and scope $size $brightness $scale',
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
            final library = FakeMediaLibraryRepository(empty: true);
            library.records.addAll(
              List.generate(
                3,
                (i) => LocalMedia(
                  sourceId: -1,
                  messageId: i + 1,
                  remoteUniqueId: 'design-$i',
                  sizeBytes: 1024 * 1024,
                  fileName: '设计数据 · 原文件$i.mp4',
                ),
              ),
            );
            const work = MediaWork(
              title: '设计数据 · 山间故事',
              kind: MediaKind.series,
              year: 2024,
            );
            await library.assignWork(work, [
              for (var i = 0; i < 3; i++)
                WorkFileEdit(
                  library.records[i].versionKey,
                  season: i == 2 ? 2 : 1,
                  episode: 1,
                ),
            ]);
            final telegram = PlaybackLayoutTelegramRepository(
              restored: true,
              persisted: {-1},
            );
            await tester.pumpWidget(
              RepaintBoundary(
                key: const ValueKey('works-capture'),
                child: Application(
                  key: UniqueKey(),
                  settingsRepository: MemorySettingsRepository(),
                  telegramRepository: telegram,
                  libraryRepository: library,
                ),
              ),
            );
            await tester.pumpAndSettle();
            Future<void> tap(String text) async {
              if (find.text(text).evaluate().isEmpty) {
                final page =
                    find
                        .byKey(const PageStorageKey('work-editor'))
                        .evaluate()
                        .isNotEmpty
                    ? find.byKey(const PageStorageKey('work-editor'))
                    : find.byKey(const PageStorageKey('work-list'));
                final scroll = find
                    .descendant(of: page, matching: find.byType(Scrollable))
                    .first;
                for (
                  var attempt = 0;
                  attempt < 40 && find.text(text).evaluate().isEmpty;
                  attempt++
                ) {
                  final toTop = ['调整归组', '撤销选中归组', '确认撤销归组'].contains(text);
                  await tester.drag(scroll, Offset(0, toTop ? 150 : -150));
                  await tester.pumpAndSettle();
                }
              }
              final target = find.byWidget(
                tester.widget(find.text(text).first),
              );
              await tester.ensureVisible(target);
              await tester.pumpAndSettle();
              await tester.tap(target);
              await tester.pumpAndSettle();
            }

            Future<void> shot(String name) async {
              expect(tester.takeException(), isNull);
              await capture?.call(
                tester,
                '${size.width < 600 ? 'phone' : 'wide'}-${brightness.name}-$scale-$name',
              );
            }

            await tap('作品片库');
            await shot('works');
            await tap('设计数据 · 山间故事 · 2024\n3 个文件版本');
            expect(find.text('第 1 季 · 第 1 集'), findsOneWidget);
            await shot('episodes');
            await tap('选择文件');
            await tap('调整归组');
            await tap('新建独立作品');
            final title = find.byKey(const ValueKey('work-title'));
            await tester.ensureVisible(title);
            await tester.enterText(title, '设计数据 · 独立作品');
            await tester.pumpAndSettle();
            await tap('电视剧');
            await shot('editor');
            await tap('预览归组');
            await shot('preview');
            library.fail = true;
            await tap('确认整批保存');
            expect(find.text('影视信息保存失败，请重试。'), findsOneWidget);
            await tester.ensureVisible(find.text('影视信息保存失败，请重试。'));
            await tester.pumpAndSettle();
            await shot('failure');
            library.fail = false;
            await tap('确认整批保存');
            expect(library.grouped, hasLength(2));
            expect(
              library.membership.values.where((id) => id == 1),
              hasLength(2),
            );
            await tap('选择文件');
            await tap('撤销选中归组');
            expect(library.membership, hasLength(3));
            await tap('确认撤销归组');
            expect(library.membership, hasLength(2));
            expect(library.records, hasLength(3));
            telegram.emit(
              TelegramAccount(
                stage: TelegramStage.ready,
                id: 200,
                selectedSources: {-1},
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text('当前条目已不可用，请返回片库。'), findsOneWidget);
            expect(find.text('设计数据 · 原文件0.mp4'), findsNothing);
            expect(find.text('设计数据 · 山间故事'), findsNothing);
            await shot('scope');
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
            await tester.pumpAndSettle();
          },
        );
      }
    }
  }
}
