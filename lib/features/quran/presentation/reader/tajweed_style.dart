import 'package:flutter/painting.dart';
import 'package:muslimku/features/quran/domain/tajweed.dart';

extension TajweedRuleColor on TajweedRule {
  Color get color => Color(argb);
}

/// [spans] as one TextSpan: [base] for plain runs, the rule colour otherwise.
TextSpan tajweedTextSpan(List<TajweedSpan> spans, TextStyle base) => TextSpan(
  style: base,
  children: [
    for (final s in spans)
      TextSpan(
        text: s.text,
        style: s.rule == null ? null : TextStyle(color: s.rule!.color),
      ),
  ],
);
