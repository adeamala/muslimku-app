import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/theme/app_text_styles.dart';
import 'package:muslimku/features/asmaul_husna/application/husna_quiz_provider.dart';
import 'package:muslimku/features/asmaul_husna/domain/husna_quiz_engine.dart';
import 'package:muslimku/features/asmaul_husna/presentation/quiz_widgets.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

const _flame = Color(0xFFE8743B);

/// Asmaul Husna quiz (design-v2 a2): what does this name mean? Works offline
/// from the saved list; progress and the day streak stay on the phone.
class HusnaQuizScreen extends ConsumerWidget {
  const HusnaQuizScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(husnaQuizProvider);
    final question = s.question;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          SenjaDetailAppBar(
            title: 'Kuis Asmaul Husna',
            subtitle: 'Mode hafalan',
            leadingIcon: Icons.close_rounded,
            leadingTooltip: 'Tutup kuis',
            actions: [
              SizedBox(
                width: 46,
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      question == null
                          ? ''
                          : '${question.position}/${question.total}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: s.error
                ? SenjaEmptyState(
                    image: 'images/3d/icon_husna.webp',
                    badgeIcon: Icons.wifi_off_rounded,
                    title: 'Kuis belum bisa dimulai',
                    message:
                        'Daftar Asmaul Husna belum tersimpan. Buka tab Asmaul '
                        'Husna sekali saat ada internet.',
                    primaryLabel: 'Kembali',
                    primaryIcon: Icons.arrow_back_rounded,
                    onPrimary: () => Navigator.maybePop(context),
                  )
                : question == null
                ? const SizedBox.shrink()
                : _QuizBody(state: s, question: question),
          ),
        ],
      ),
    );
  }
}

class _QuizBody extends ConsumerWidget {
  const _QuizBody({required this.state, required this.question});

  final HusnaQuizState state;
  final QuizQuestion question;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quiz = ref.read(husnaQuizProvider.notifier);
    final progress = state.progress!;
    final name = question.name;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SenjaProgressBar(
            value: progress.answered / question.total,
            height: 8,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ScoreChip(
                icon: Icons.check_rounded,
                color: AppColors.secondary,
                text: 'Benar ${progress.correct} dari ${progress.answered}',
              ),
              _ScoreChip(
                icon: Icons.local_fire_department_outlined,
                color: _flame,
                text: '${state.streak} hari beruntun',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FlashCard(question: question),
          const SizedBox(height: 16),
          for (var i = 0; i < question.options.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            QuizOption(
              text: question.options[i],
              mark: !state.answered
                  ? QuizMark.none
                  : i == question.answer
                  ? QuizMark.right
                  : i == state.selected
                  ? QuizMark.wrong
                  : QuizMark.none,
              onTap: state.answered
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      quiz.answer(i);
                    },
            ),
          ],
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 20),
            child: !state.answered
                ? const SizedBox.shrink()
                : QuizFeedback(
                    right: state.answeredRight,
                    text: state.answeredRight
                        ? 'Benar! ${name.latin} artinya ${name.meaning}.'
                        : 'Belum tepat. ${name.latin} artinya ${name.meaning}.',
                  ),
          ),
          const SizedBox(height: 14),
          SenjaButton(
            label: progress.finished && state.answered
                ? 'Mulai putaran baru'
                : 'Lanjut',
            onPressed: state.answered ? quiz.next : null,
          ),
        ],
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.stageBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.lilacLine, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Purple card with the name (design `.flash`).
class _FlashCard extends StatelessWidget {
  const _FlashCard({required this.question});

  final QuizQuestion question;

  @override
  Widget build(BuildContext context) {
    final name = question.name;
    return Container(
      constraints: const BoxConstraints(minHeight: 280),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment(-0.36, -1),
          end: Alignment(0.36, 1),
          colors: [AppColors.duskHigh, AppColors.duskMid, AppColors.duskLow],
          stops: [0, 0.6, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.duskHigh.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: CustomPaint(
          painter: OctagramPatternPainter(
            color: Colors.white.withValues(alpha: 0.12),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 52),
                      child: Text(
                        'Apa arti nama ini?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        name.arabic,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          fontFamily: AppTextStyles.arabicFontFamily,
                          fontSize: 56,
                          height: 1.6,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      name.latin,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 16,
                top: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    'No. ${name.number}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
