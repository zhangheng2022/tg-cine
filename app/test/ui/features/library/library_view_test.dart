import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tg_cine/app/application.dart';
import 'package:tg_cine/domain/models/telegram_account.dart';

import '../../../support/fake_media_library_repository.dart';
import '../../../support/fake_telegram_repository.dart';
import '../../../support/memory_settings_repository.dart';

void main() {
  testWidgets(
    'failure and retry remain scrollable on a small screen at twice the font size',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final library = FakeMediaLibraryRepository()..fail = true;
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
      expect(tester.takeException(), isNull);
      final scroll = find
          .descendant(
            of: find.byKey(const PageStorageKey('library-files')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('重新读取'),
        100,
        scrollable: scroll,
      );
      await tester.pumpAndSettle();
      library.fail = false;
      await tester.tap(find.text('重新读取'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('重新读取'), findsNothing);
    },
  );
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final size in [
      const Size(320, 568),
      const Size(800, 900),
      const Size(1440, 900),
    ]) {
      for (final brightness in Brightness.values) {
        for (final scale in [1.0, 2.0]) {
          testWidgets(
            'raw library and details adapt to $platform $size $brightness $scale',
            (tester) async {
              tester.view.physicalSize = size;
              tester.view.devicePixelRatio = 1;
              tester.platformDispatcher.platformBrightnessTestValue =
                  brightness;
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              addTearDown(
                tester.platformDispatcher.clearPlatformBrightnessTestValue,
              );
              addTearDown(
                tester.platformDispatcher.clearTextScaleFactorTestValue,
              );
              final telegram = FakeTelegramRepository(
                restored: true,
                persisted: {-1},
              );
              final library = FakeMediaLibraryRepository();
              await tester.pumpWidget(
                Application(
                  settingsRepository: MemorySettingsRepository(),
                  telegramRepository: telegram,
                  libraryRepository: library,
                ),
              );
              await tester.pumpAndSettle();
              await tester.tap(find.text('导入来源'));
              await tester.pumpAndSettle();
              final scroll = find
                  .descendant(
                    of: find.byKey(const PageStorageKey('library-files')),
                    matching: find.byType(Scrollable),
                  )
                  .first;
              await tester.scrollUntilVisible(
                find.text('历史整理完成'),
                150,
                scrollable: scroll,
              );
              await tester.pumpAndSettle();
              expect(find.text('历史整理完成'), findsOneWidget);
              final file = find.byKey(
                ValueKey('media-${library.records.first.versionKey}'),
              );
              await tester.scrollUntilVisible(file, 150, scrollable: scroll);
              await tester.pumpAndSettle();
              final filename = find.descendant(
                of: file,
                matching: find.text(library.records.first.fileName),
              );
              await tester.ensureVisible(filename);
              await tester.pumpAndSettle();
              await tester.tap(filename);
              await tester.pumpAndSettle();
              expect(find.text('原消息说明'), findsOneWidget);
              final button = find.text('复制源消息链接');
              await tester.ensureVisible(button);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              await tester.pumpWidget(const SizedBox());
              await tester.pumpAndSettle();
            },
            variant: TargetPlatformVariant({platform}),
          );
        }
      }
    }
  }
  testWidgets(
    'search preserves focus and navigation context, clears input, copies links and logout clears details',
    (tester) async {
      final telegram = FakeTelegramRepository(restored: true, persisted: {-1});
      final library = FakeMediaLibraryRepository();
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
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
      await tester.enterText(find.byType(EditableText), '山间');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      await tester.tap(find.bySemanticsLabel('设置').last);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('片库').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '山间',
      );
      await tester.enterText(find.byType(EditableText), '不存在');
      await tester.pumpAndSettle();
      final scroll = find
          .descendant(
            of: find.byKey(const PageStorageKey('library-files')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('清除搜索'),
        150,
        scrollable: scroll,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('清除搜索'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        isEmpty,
      );
      await tester.enterText(find.byType(EditableText), '上一账号的搜索');
      await tester.pumpAndSettle();
      telegram.emit(
        TelegramAccount(
          stage: TelegramStage.ready,
          id: 200,
          selectedSources: {-1},
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        isEmpty,
      );
      final file = find.byKey(
        ValueKey('media-${library.records.first.versionKey}'),
      );
      await tester.scrollUntilVisible(file, 150, scrollable: scroll);
      await tester.pumpAndSettle();
      await tester.tap(file);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('复制源消息链接'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('复制源消息链接'));
      await tester.pumpAndSettle();
      expect(clipboard, 'https://t.me/c/123456/20');
      telegram.emit(TelegramAccount(stage: TelegramStage.disconnected));
      await tester.pumpAndSettle();
      expect(find.text('当前条目已不可用，请返回片库。'), findsOneWidget);
      expect(find.text(library.records.first.fileName), findsNothing);
    },
  );
}
