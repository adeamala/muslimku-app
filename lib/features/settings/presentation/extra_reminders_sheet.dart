import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/features/prayer/application/adzan_provider.dart';
import 'package:muslimku/features/prayer/domain/adzan_plan.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// "Pengingat lainnya" sheet: tahajjud, Al-Kahfi, fasting and the daily
/// ayah/hadith, each a toggle with its schedule as subtitle.
Future<void> showExtraRemindersSheet(BuildContext context) =>
    showSenjaSheet<void>(
      context,
      title: 'Pengingat lainnya',
      builder: (_) => const ExtraRemindersSheet(),
    );

class ExtraRemindersSheet extends ConsumerWidget {
  const ExtraRemindersSheet({super.key});

  static IconData iconFor(ExtraReminder e) => switch (e) {
    ExtraReminder.tahajjud => Icons.nightlight_round,
    ExtraReminder.kahfi => Icons.menu_book_rounded,
    ExtraReminder.puasaSunnah => Icons.no_meals_rounded,
    ExtraReminder.harian => Icons.wb_sunny_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(adzanProvider).settings;
    final notifier = ref.read(adzanProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Memakai bunyi notifikasi HP, bukan adzan. Waktu tahajjud dihitung '
          'dari Maghrib dan Subuh kotamu.',
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w500,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: 6),
        for (final e in ExtraReminder.values)
          SenjaToggleRow(
            icon: iconFor(e),
            label: e.label,
            subtitle: e.description,
            value: s.extras.contains(e),
            onChanged: (_) => notifier.toggleExtra(e),
            divider: e != ExtraReminder.values.last,
          ),
      ],
    );
  }
}

/// "Tahajjud · Al-Kahfi" or "Tidak ada", for the settings row.
String extraRemindersSummary(Set<ExtraReminder> extras) {
  final names = [
    for (final e in ExtraReminder.values)
      if (extras.contains(e)) e.label.split(' ').first,
  ];
  return names.isEmpty ? 'Tidak ada' : names.join(' · ');
}
