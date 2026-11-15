/// Tajweed rules as marked up by alquran.cloud's `quran-tajweed` edition
/// (`[code:id[text]`), with Indonesian labels and the usual colours.
enum TajweedRule {
  hamzatWasl('h', 'Hamzah washal', 0xFFAAAAAA),
  silent('s', 'Huruf tidak dibaca', 0xFFAAAAAA),
  lamShamsiyyah('l', 'Lam syamsiyah', 0xFFAAAAAA),
  maddaNormal('n', 'Mad thabi\'i (2 harakat)', 0xFF537FFF),
  maddaPermissible('p', 'Mad jaiz (2, 4, atau 6 harakat)', 0xFF4050FF),
  maddaNecessary('m', 'Mad lazim (6 harakat)', 0xFF000EBC),
  maddaObligatory('o', 'Mad wajib (4–5 harakat)', 0xFF2144C1),
  qalqalah('q', 'Qalqalah', 0xFFDD0008),
  ikhfaShafawi('c', 'Ikhfa syafawi', 0xFFD500B7),
  ikhfa('f', 'Ikhfa', 0xFF9400A8),
  idghamShafawi('w', 'Idgham syafawi', 0xFF58B800),
  iqlab('i', 'Iqlab', 0xFF26BFFD),
  idghamGhunnah('a', 'Idgham bighunnah', 0xFF169777),
  idghamWithoutGhunnah('u', 'Idgham bilaghunnah', 0xFF169200),
  idghamMutajanisayn('d', 'Idgham mutajanisain', 0xFFA1A1A1),
  idghamMutaqaribayn('b', 'Idgham mutaqaribain', 0xFFA1A1A1),
  ghunnah('g', 'Ghunnah', 0xFFFF7E1E);

  const TajweedRule(this.code, this.label, this.argb);

  final String code;
  final String label;

  /// Colour of the rule as 0xAARRGGBB (see `tajweed_style.dart` in the reader).
  final int argb;

  static TajweedRule? byCode(String code) =>
      values.where((r) => r.code == code).firstOrNull;
}

class TajweedSpan {
  const TajweedSpan(this.text, this.rule);

  final String text;

  /// Null for text outside any rule.
  final TajweedRule? rule;
}

/// Splits `ذ[n[َٲ]لِكَ [h:11[ٱ]لْ…` into runs. Rules may nest (`[o[…[s[…]…]`):
/// the innermost wins for its run. Unknown codes and stray brackets are
/// kept as plain text, so a markup change can never lose letters.
List<TajweedSpan> parseTajweed(String markup) {
  final out = <TajweedSpan>[];
  final open = RegExp(r'\[([a-z]+)(?::\d+)?\[');
  final stack = <TajweedRule?>[];
  final buffer = StringBuffer();
  void flush() {
    if (buffer.isEmpty) return;
    final rule = stack.lastWhere((r) => r != null, orElse: () => null);
    final text = buffer.toString();
    buffer.clear();
    if (out.isNotEmpty && out.last.rule == rule) {
      out[out.length - 1] = TajweedSpan(out.last.text + text, rule);
    } else {
      out.add(TajweedSpan(text, rule));
    }
  }

  var i = 0;
  while (i < markup.length) {
    final ch = markup[i];
    if (ch == '[') {
      final m = open.matchAsPrefix(markup, i);
      if (m != null) {
        final rule = TajweedRule.byCode(m.group(1)!);
        flush();
        // An unknown code opens an unstyled run so its closing ']' is eaten.
        stack.add(rule);
        i = m.end;
        continue;
      }
    }
    if (ch == ']' && stack.isNotEmpty) {
      flush();
      stack.removeLast();
      i++;
      continue;
    }
    buffer.write(ch);
    i++;
  }
  flush();
  return out;
}

/// The Arabic text without the markup.
String plainTajweed(String markup) =>
    parseTajweed(markup).map((s) => s.text).join();
