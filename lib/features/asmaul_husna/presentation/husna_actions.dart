import 'package:flutter/material.dart';
import 'package:muslimku/features/asmaul_husna/application/asmaul_husna_provider.dart';
import 'package:muslimku/features/asmaul_husna/presentation/husna_quiz_screen.dart';
import 'package:muslimku/features/tasbih/application/tasbih_provider.dart';
import 'package:muslimku/features/tasbih/presentation/tasbih_screen.dart';
import 'package:share_plus/share_plus.dart';

/// "Dzikir 33×": the tasbih counter with this name instead of the dzikir
/// after salat.
void openHusnaDzikir(BuildContext context, HusnaName name) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TasbihScreen(
        preset: TasbihPreset(arabic: name.arabic, latin: name.latin),
      ),
    ),
  );
}

void openHusnaQuiz(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const HusnaQuizScreen()));
}

Future<void> shareHusna(HusnaName name) async {
  try {
    await SharePlus.instance.share(ShareParams(text: name.shareText));
  } catch (_) {
    // No share sheet on this platform; nothing to do.
  }
}
