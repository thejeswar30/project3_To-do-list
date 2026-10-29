import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project03_todo_list/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPreferences.getInstance();
  });

  Future<void> loadApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(const TodoApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  Future<void> addTask(WidgetTester tester, String title) async {
    final input = find.byType(TextField).first;

    await tester.ensureVisible(input);
    await tester.enterText(input, title);
    await tester.pump();

    final addButton = find.widgetWithText(FilledButton, 'Add');

    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  testWidgets('App loads successfully', (tester) async {
    await loadApp(tester);

    expect(find.text('TaskFlow'), findsOneWidget);
    expect(find.text('Add a new task'), findsOneWidget);
    expect(find.text('Stay organized.'), findsOneWidget);
  });

  testWidgets('Add task works', (tester) async {
    await loadApp(tester);

    await addTask(tester, 'Complete Flutter project');

    expect(find.text('Complete Flutter project'), findsOneWidget);
    expect(find.text('1 item'), findsOneWidget);
    expect(find.text('1 active'), findsOneWidget);
  });

  testWidgets('Complete task works', (tester) async {
    await loadApp(tester);

    await addTask(tester, 'Study Flutter');

    expect(find.text('In progress'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(find.text('1 completed'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('Search tasks works', (tester) async {
    await loadApp(tester);

    await addTask(tester, 'First task');
    await addTask(tester, 'Second task');

    final searchField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Search your tasks...',
    );

    await tester.ensureVisible(searchField);
    await tester.enterText(searchField, 'First task');
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(Checkbox).first,
        matching: find.text('First task'),
      ),
      findsNothing,
    );

    expect(find.text('Second task'), findsNothing);

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.controller?.text == 'First task',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Delete task works', (tester) async {
    await loadApp(tester);

    await addTask(tester, 'Task to delete');

    final deleteButton = find.byTooltip('Delete task');

    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(find.text('Task to delete'), findsNothing);
    expect(find.text('Your list is empty'), findsOneWidget);
  });

  testWidgets('Edit task dialog opens', (tester) async {
    await loadApp(tester);

    await addTask(tester, 'Original task');

    final editButton = find.byTooltip('Edit task');

    await tester.ensureVisible(editButton);
    await tester.tap(editButton);
    await tester.pumpAndSettle();

    expect(find.text('Edit task'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}
