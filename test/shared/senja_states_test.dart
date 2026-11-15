import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';
import 'package:shimmer/shimmer.dart';

Future<void> _pumpSkeleton(WidgetTester tester, {required bool still}) {
  return tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: still),
        child: child!,
      ),
      home: const Scaffold(body: SenjaSkeletonList(rows: 3)),
    ),
  );
}

void main() {
  testWidgets('the skeleton shimmers while animations are allowed', (
    tester,
  ) async {
    await _pumpSkeleton(tester, still: false);
    expect(find.byType(Shimmer), findsOneWidget);
    expect(find.bySemanticsLabel('Memuat'), findsOneWidget);
  });

  testWidgets('the skeleton stands still when the phone asks for less motion', (
    tester,
  ) async {
    await _pumpSkeleton(tester, still: true);
    expect(find.byType(Shimmer), findsNothing);
    // Settles at once: nothing repeats.
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Memuat'), findsOneWidget);
    // Without the shimmer the shapes must still show on the white sheet.
    final lilac = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color == AppColors.lilac,
    );
    expect(lilac, findsWidgets);
  });
}
