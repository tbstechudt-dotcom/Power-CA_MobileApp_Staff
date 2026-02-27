// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:powerca_mobile/app/theme.dart';
import 'package:powerca_mobile/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PlaceholderHomePage smoke test', (WidgetTester tester) async {
    // Build the placeholder page which doesn't require Supabase
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(393, 852),
        minTextAdapt: true,
        builder: (context, child) {
          return MaterialApp(
            title: 'PowerCA - Test',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: const PlaceholderHomePage(),
          );
        },
      ),
    );

    // Allow the widget to build
    await tester.pump();

    // Verify the app loads without crashing
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(PlaceholderHomePage), findsOneWidget);

    // Verify key UI elements are present
    expect(find.text('POWER CA'), findsOneWidget);
    expect(find.text('Auditor WorkLog'), findsOneWidget);
    expect(find.text('Scaffold Ready'), findsOneWidget);
  });

  testWidgets('AppTheme is applied correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(393, 852),
        minTextAdapt: true,
        builder: (context, child) {
          return MaterialApp(
            theme: AppTheme.lightTheme,
            home: const PlaceholderHomePage(),
          );
        },
      ),
    );

    await tester.pump();

    // Verify theme is applied
    final MaterialApp app = tester.widget(find.byType(MaterialApp));
    expect(app.theme, equals(AppTheme.lightTheme));
  });
}
