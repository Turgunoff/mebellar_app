import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woody_app/shared/models/cancel_reason.dart';
import 'package:woody_app/shared/widgets/cancel_reason_sheet.dart';

const _style = CancelReasonStyle(
  surface: Colors.white,
  ink: Colors.black,
  muted: Colors.grey,
  border: Colors.black12,
  field: Color(0xFFF5F5F5),
  accent: Color(0xFFDC2626),
  danger: Color(0xFFDC2626),
);

const _labels = CancelReasonLabels(
  title: 'Buyurtmani bekor qilish',
  subtitle: 'Sababni tanlang',
  otherHint: 'Sababni yozing...',
  confirm: 'Tasdiqlash',
  otherRequired: 'Iltimos, sababni yozing',
  loadError: 'Yuklab bolmadi',
);

const _reasons = [
  CancelReason(code: 'changed_mind', title: 'Fikrimdan qaytdim'),
  CancelReason(code: 'other', title: 'Boshqa sabab'),
];

void main() {
  testWidgets('renders fetched reasons and returns the picked code', (
    tester,
  ) async {
    CancelReasonSelection? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showCancelReasonSheet(
                  context: context,
                  loadReasons: () async => _reasons,
                  style: _style,
                  labels: _labels,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Fikrimdan qaytdim'), findsOneWidget);
    expect(find.text('Boshqa sabab'), findsOneWidget);

    await tester.tap(find.text('Fikrimdan qaytdim'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tasdiqlash'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.code, 'changed_mind');
    expect(result!.text, isNull);
  });

  testWidgets('selecting "other" reveals a field and requires non-empty text', (
    tester,
  ) async {
    CancelReasonSelection? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showCancelReasonSheet(
                  context: context,
                  loadReasons: () async => _reasons,
                  style: _style,
                  labels: _labels,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // No free-text field until `other` is picked.
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Boshqa sabab'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    // Confirm with an empty field → validation, no pop.
    await tester.tap(find.text('Tasdiqlash'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.text('Iltimos, sababni yozing'), findsOneWidget);

    // Enter text → confirm returns the structured selection.
    await tester.enterText(find.byType(TextField), 'Boshqa dokondan oldim');
    await tester.tap(find.text('Tasdiqlash'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.code, 'other');
    expect(result!.text, 'Boshqa dokondan oldim');
  });

  testWidgets('degrades to an other-only free-text flow when load fails', (
    tester,
  ) async {
    CancelReasonSelection? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showCancelReasonSheet(
                  context: context,
                  loadReasons: () async => throw Exception('network down'),
                  style: _style,
                  labels: _labels,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Soft error copy + an immediately-usable free-text field.
    expect(find.text('Yuklab bolmadi'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Sababim bor');
    await tester.tap(find.text('Tasdiqlash'));
    await tester.pumpAndSettle();
    expect(result?.code, 'other');
    expect(result?.text, 'Sababim bor');
  });
}
