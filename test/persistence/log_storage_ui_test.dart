import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:requests_inspector/requests_inspector.dart';
import 'package:requests_inspector/src/shared_widgets/log_storage_dialog.dart';
import 'package:requests_inspector/src/shared_widgets/log_storage_prompt_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  final controller = LogPersistenceController.instance;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('inspector_ui_test');
  });

  tearDown(() async {
    await controller.resetForTesting();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  /// Lets the real file I/O these widgets kick off run outside `testWidgets`'
  /// fake-async zone (where it would never complete), then renders whatever it
  /// changed.
  ///
  /// Note this only covers writes the widgets fire and forget; what the dialog
  /// *reads back* from disk (the per-category entry counts) isn't asserted
  /// here, since that read is awaited inside the fake zone. Those paths are
  /// covered directly in `log_persistence_controller_test.dart` and by
  /// [PersistedLogStats]' own formatting tests.
  Future<void> settleIo(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> initPersistence(
    WidgetTester tester,
    LogPersistenceConfig config,
  ) async {
    await tester.runAsync(() => controller.init(config, directory: tempDir));
  }

  /// Pumps a button that opens [openDialog], and taps it.
  Future<void> openVia(
    WidgetTester tester,
    void Function(BuildContext context) openDialog,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => openDialog(context),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  void openPrompt(BuildContext context) =>
      LogStoragePromptDialog.showIfNeeded(context, isDarkMode: true);

  void openStorageDialog(BuildContext context) =>
      LogStorageDialog.show(context, isDarkMode: false);

  group('LogStoragePromptDialog', () {
    testWidgets('is skipped once the choice is stored', (tester) async {
      await initPersistence(
        tester,
        const LogPersistenceConfig(askOnFirstOpen: false),
      );

      await openVia(tester, openPrompt);

      expect(find.text('Save logs to disk?'), findsNothing);
    });

    testWidgets('saves the picked categories', (tester) async {
      await initPersistence(tester, const LogPersistenceConfig());

      await openVia(tester, openPrompt);
      expect(find.text('Save logs to disk?'), findsOneWidget);

      // Nothing is pre-selected, so there is nothing to save yet.
      expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save selected'))
            .onPressed,
        isNull,
      );

      await tester.tap(find.text('HTTP & GraphQL requests'));
      await tester.pump();
      await tester.tap(find.text('Save selected'));
      await settleIo(tester);

      expect(controller.enabledTypes.value, {PersistedLogType.http});
      expect(controller.shouldPromptOnOpen, isFalse);
      expect(find.text('Save logs to disk?'), findsNothing);
    });

    testWidgets('"Not now" is remembered too', (tester) async {
      await initPersistence(tester, const LogPersistenceConfig());

      await openVia(tester, openPrompt);
      await tester.tap(find.text('Not now'));
      await settleIo(tester);

      expect(controller.enabledTypes.value, isEmpty);
      expect(controller.shouldPromptOnOpen, isFalse);
    });
  });

  group('LogStorageDialog', () {
    testWidgets('offers one switch per category', (tester) async {
      await initPersistence(
        tester,
        const LogPersistenceConfig(askOnFirstOpen: false),
      );

      await openVia(tester, openStorageDialog);
      await settleIo(tester);

      expect(find.text('Save logs to disk'), findsOneWidget);
      expect(
        find.byType(Switch),
        findsNWidgets(PersistedLogType.values.length),
      );
      expect(find.text('Export CSV & share'), findsOneWidget);
    });

    testWidgets('toggling a switch starts saving that category',
        (tester) async {
      await initPersistence(
        tester,
        const LogPersistenceConfig(askOnFirstOpen: false),
      );

      await openVia(tester, openStorageDialog);
      await settleIo(tester);

      await tester.tap(find.byType(Switch).first);
      await settleIo(tester);

      expect(controller.enabledTypes.value, {PersistedLogType.http});
    });

    testWidgets('picking an export format relabels the export button',
        (tester) async {
      await initPersistence(
        tester,
        const LogPersistenceConfig(askOnFirstOpen: false),
      );

      await openVia(tester, openStorageDialog);
      await settleIo(tester);

      expect(find.text('Export CSV & share'), findsOneWidget);

      await tester.tap(find.text('JSON'));
      await tester.pump();

      expect(find.text('Export JSON & share'), findsOneWidget);
      expect(find.text('Export CSV & share'), findsNothing);
    });
  });
}
