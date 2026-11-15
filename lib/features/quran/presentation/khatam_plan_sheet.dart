import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/time/clock_provider.dart';
import 'package:muslimku/features/quran/application/khatam_plan_provider.dart';
import 'package:muslimku/features/quran/domain/khatam_plan.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// "Rencana khatam" sheet: pick a preset or a date, save; or stop a plan.
Future<void> showKhatamPlanSheet(BuildContext context) => showSenjaSheet<void>(
  context,
  title: 'Rencana khatam',
  builder: (_) => const KhatamPlanSheet(),
);

class KhatamPlanSheet extends ConsumerStatefulWidget {
  const KhatamPlanSheet({super.key});

  @override
  ConsumerState<KhatamPlanSheet> createState() => _KhatamPlanSheetState();
}

class _KhatamPlanSheetState extends ConsumerState<KhatamPlanSheet> {
  String? _preset = '30 hari';
  DateTime? _custom;

  DateTime get _today {
    final now = ref.read(clockProvider).valueOrNull ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  KhatamPlan get _plan => _custom != null
      ? KhatamPlan(start: _today, target: _custom!)
      : KhatamPlan.preset(_preset ?? '30 hari', today: _today);

  Future<void> _pickDate() async {
    final today = _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _custom ?? today.add(const Duration(days: 29)),
      firstDate: today.add(const Duration(days: 1)),
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Tanggal target khatam',
      locale: const Locale('id', 'ID'),
    );
    if (picked != null && mounted) {
      setState(() {
        _custom = picked;
        _preset = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(khatamPlanProvider);
    final plan = _plan;
    final perDay = plan.juzPerDay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          current == null
              ? 'Pilih berapa lama; progres dihitung dari juz yang kamu '
                    'tandai selesai.'
              : 'Rencana saat ini: ${current.label}. Rencana baru '
                    'mulai hari ini.',
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w500,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, _) in KhatamPlan.presets)
              SenjaChip(
                label: label,
                selected: _preset == label,
                onTap: () => setState(() {
                  _preset = label;
                  _custom = null;
                }),
              ),
            SenjaChip(
              label: _custom == null
                  ? 'Pilih tanggal'
                  : DateFormat('d MMM yyyy', 'id_ID').format(_custom!),
              icon: Icons.event_rounded,
              selected: _custom != null,
              onTap: _pickDate,
            ),
          ],
        ),
        const SizedBox(height: 14),
        SenjaCard(
          color: AppColors.stageBackground,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Text(
            '${plan.label} · ${plan.days} hari · '
            '${perDay >= 1 ? perDay.toStringAsFixed(perDay == perDay.roundToDouble() ? 0 : 1).replaceAll('.', ',') : perDay.toStringAsFixed(2).replaceAll('.', ',')} juz per hari',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 14),
        SenjaButton(
          label: 'Simpan rencana',
          icon: Icons.flag_rounded,
          height: 48,
          onPressed: () async {
            await ref.read(khatamPlanProvider.notifier).set(plan);
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
        if (current != null) ...[
          const SizedBox(height: 8),
          SenjaButton(
            label: 'Hentikan rencana',
            style: SenjaButtonStyle.outline,
            height: 48,
            onPressed: () async {
              await ref.read(khatamPlanProvider.notifier).clear();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ],
    );
  }
}
