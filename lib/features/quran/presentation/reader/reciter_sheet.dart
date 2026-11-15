import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/features/quran/domain/reciters.dart';
import 'package:muslimku/features/reading/application/reading_settings_provider.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// "Qari murottal" sheet: who recites in the Al-Qur'an reader.
Future<void> showReciterSheet(BuildContext context) => showSenjaSheet<void>(
  context,
  title: 'Qari murottal',
  builder: (_) => const ReciterSheet(),
);

class ReciterSheet extends ConsumerWidget {
  const ReciterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(readingSettingsProvider);
    final notifier = ref.read(readingSettingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Murottal diputar ayat per ayat dari internet. Ganti qari berlaku '
          'mulai ayat berikutnya.',
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w500,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: 6),
        for (final reciter in Reciter.values)
          SenjaChoiceRow(
            icon: Icons.record_voice_over_rounded,
            title: reciter.label,
            subtitle: '${reciter.kbps} kbps',
            selected: s.reciter == reciter,
            divider: reciter != Reciter.values.last,
            onTap: () => notifier.setReciter(reciter),
          ),
      ],
    );
  }
}
