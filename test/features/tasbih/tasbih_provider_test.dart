import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/features/tasbih/application/tasbih_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> container() async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(tasbihProvider.notifier).ready;
    return c;
  }

  test('starts at zero with a target of 33', () async {
    SharedPreferences.setMockInitialValues({});
    final c = await container();
    final s = c.read(tasbihProvider);
    expect(s.count, 0);
    expect(s.target, 33);
    expect(s.roundCount, 0);
    expect(s.completedRounds, 0);
  });

  test(
    'a tap that completes a round reports it and wraps the counter',
    () async {
      SharedPreferences.setMockInitialValues({});
      final c = await container();
      final n = c.read(tasbihProvider.notifier);
      for (var i = 0; i < 32; i++) {
        expect(n.increment(), isFalse);
      }
      expect(n.increment(), isTrue);
      expect(c.read(tasbihProvider).roundCount, 33);
      expect(c.read(tasbihProvider).completedRounds, 1);
      n.increment();
      expect(c.read(tasbihProvider).roundCount, 1);
    },
  );

  test('dzikir after salat follows tasbih, tahmid, takbir per 33', () async {
    SharedPreferences.setMockInitialValues({});
    final c = await container();
    final n = c.read(tasbihProvider.notifier);
    expect(c.read(tasbihProvider).dzikirIndex, 0);
    for (var i = 0; i < 34; i++) {
      n.increment();
    }
    expect(c.read(tasbihProvider).dzikirIndex, 1);
    for (var i = 0; i < 33; i++) {
      n.increment();
    }
    expect(c.read(tasbihProvider).dzikirIndex, 2);
  });

  test('no target keeps counting and never completes a round', () async {
    SharedPreferences.setMockInitialValues({});
    final c = await container();
    final n = c.read(tasbihProvider.notifier);
    n.setTarget(0);
    for (var i = 0; i < 120; i++) {
      expect(n.increment(), isFalse);
    }
    expect(c.read(tasbihProvider).roundCount, 120);
    expect(c.read(tasbihProvider).dzikirIndex, isNull);
  });

  test('changing the target or resetting starts from zero', () async {
    SharedPreferences.setMockInitialValues({});
    final c = await container();
    final n = c.read(tasbihProvider.notifier);
    n.increment();
    n.setTarget(99);
    expect(c.read(tasbihProvider).count, 0);
    expect(c.read(tasbihProvider).target, 99);
    n.increment();
    n.reset();
    expect(c.read(tasbihProvider).count, 0);
    expect(c.read(tasbihProvider).target, 99);
  });

  test('restores and saves the count and target', () async {
    SharedPreferences.setMockInitialValues({
      'tasbih_count': 40,
      'tasbih_target': 99,
    });
    final c = await container();
    expect(c.read(tasbihProvider).count, 40);
    expect(c.read(tasbihProvider).target, 99);
    c.read(tasbihProvider.notifier).increment();
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('tasbih_count'), 41);
    expect(prefs.getInt('tasbih_target'), 99);
  });
}
