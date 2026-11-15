import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/features/prayer/application/adzan_provider.dart';
import 'package:muslimku/features/prayer/domain/adzan_plan.dart';
import 'package:muslimku/features/quran/application/quran_audio_provider.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// "Suara pengingat" sheet: the sound of the prayer-time and sahur reminders,
/// with a sample of each (design-v2 s1 look: lilac icon tile, 62 px rows).
Future<void> showAdzanSoundSheet(BuildContext context) => showSenjaSheet<void>(
  context,
  title: 'Suara pengingat',
  builder: (_) => const AdzanSoundSheet(),
);

class AdzanSoundSheet extends ConsumerStatefulWidget {
  const AdzanSoundSheet({super.key});

  @override
  ConsumerState<AdzanSoundSheet> createState() => _AdzanSoundSheetState();
}

class _AdzanSoundSheetState extends ConsumerState<AdzanSoundSheet> {
  MurottalPlayer? _player;
  StreamSubscription<void>? _done;
  AdzanSound? _playing;

  @override
  void dispose() {
    _done?.cancel();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _preview(AdzanSound sound) async {
    final preview = sound.preview;
    if (preview == null) return;
    var player = _player;
    if (player == null) {
      player = _player = ref.read(murottalPlayerFactoryProvider)();
      // Show the play button again once the sample has ended.
      _done = player.completed.listen((_) {
        if (mounted) setState(() => _playing = null);
      });
    }
    setState(() => _playing = sound);
    try {
      await player.play('asset:///assets/sounds/$preview.ogg');
    } catch (_) {
      // No audio on this device; the choice still works.
      if (mounted) setState(() => _playing = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(adzanProvider).settings;
    final notifier = ref.read(adzanProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Untuk pengingat masuk waktu sholat dan sahur. Pengingat 10 menit '
          'sebelumnya tetap memakai bunyi notifikasi HP.',
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w500,
            color: AppColors.inkMuted,
          ),
        ),
        const SizedBox(height: 6),
        for (final sound in AdzanSound.values)
          _SoundRow(
            sound: sound,
            selected: s.sound == sound,
            playing: _playing == sound,
            divider: sound != AdzanSound.values.last,
            onTap: () => notifier.setSound(sound),
            onPreview: sound.preview == null ? null : () => _preview(sound),
          ),
      ],
    );
  }
}

class _SoundRow extends StatelessWidget {
  const _SoundRow({
    required this.sound,
    required this.selected,
    required this.playing,
    required this.divider,
    required this.onTap,
    required this.onPreview,
  });

  final AdzanSound sound;
  final bool selected;
  final bool playing;
  final bool divider;
  final VoidCallback onTap;
  final VoidCallback? onPreview;

  static IconData _icon(AdzanSound sound) => switch (sound) {
    AdzanSound.bawaan => Icons.notifications_none_rounded,
    AdzanSound.adzan => Icons.mosque_rounded,
    AdzanSound.takbir => Icons.record_voice_over_rounded,
    AdzanSound.bedug => Icons.album_rounded,
    AdzanSound.kentongan => Icons.music_note_rounded,
    AdzanSound.beep => Icons.notifications_active_rounded,
    AdzanSound.senyap => Icons.notifications_off_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return SenjaChoiceRow(
      icon: _icon(sound),
      title: sound.label,
      subtitle: sound.description,
      selected: selected,
      divider: divider,
      onTap: onTap,
      trailing: onPreview == null
          ? null
          : SenjaIconButton(
              icon: playing
                  ? Icons.graphic_eq_rounded
                  : Icons.play_arrow_rounded,
              tooltip: 'Dengarkan ${sound.label}',
              style: SenjaIconStyle.lilac,
              size: 36,
              iconSize: 20,
              onPressed: onPreview,
            ),
    );
  }
}
