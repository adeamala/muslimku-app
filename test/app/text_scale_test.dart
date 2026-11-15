import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muslimku/app/app.dart';

void main() {
  test('follows the phone text size between 100 % and 130 %', () {
    expect(appTextScaler(const TextScaler.linear(1.15)).scale(10), 11.5);
    expect(appTextScaler(const TextScaler.linear(2.0)).scale(10), 13);
    expect(appTextScaler(const TextScaler.linear(0.85)).scale(10), 10);
    expect(appTextScaler(TextScaler.noScaling).scale(10), 10);
  });
}
