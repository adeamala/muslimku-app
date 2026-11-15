import 'package:flutter/material.dart';

import 'package:muslimku/core/theme/app_colors.dart';

const _wrongLine = Color(0xFFEE7B5B);
const _rightLine = Color(0xFFB8DA00);
const _rightLip = Color(0xFFA9C800);

/// How an answer looks once the question is answered.
enum QuizMark { none, right, wrong }

/// One answer (design `.opt`): lime with a check when right, a peach outline
/// when it was a wrong pick.
class QuizOption extends StatelessWidget {
  const QuizOption({
    super.key,
    required this.text,
    required this.mark,
    required this.onTap,
  });

  final String text;
  final QuizMark mark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color line, Color lip) = switch (mark) {
      QuizMark.right => (AppColors.primary, _rightLine, _rightLip),
      QuizMark.wrong => (
        AppColors.offlineSurface,
        _wrongLine,
        AppColors.offlineLine,
      ),
      QuizMark.none => (Colors.white, AppColors.lilacLine, AppColors.lilac),
    };
    final radius = BorderRadius.circular(18);
    return Semantics(
      button: true,
      selected: mark != QuizMark.none,
      hint: switch (mark) {
        QuizMark.right => 'Jawaban benar',
        QuizMark.wrong => 'Pilihanmu, belum tepat',
        QuizMark.none => null,
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [BoxShadow(color: lip, offset: const Offset(0, 3))],
        ),
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: line, width: 1.5),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 54),
              padding: const EdgeInsets.fromLTRB(18, 8, 14, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.3,
                        fontWeight: mark == QuizMark.right
                            ? FontWeight.w800
                            : FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  if (mark != QuizMark.none) ...[
                    const SizedBox(width: 10),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        mark == QuizMark.right
                            ? Icons.check_rounded
                            : Icons.close_rounded,
                        size: 17,
                        color: mark == QuizMark.right
                            ? AppColors.ink
                            : AppColors.offlineAccent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class QuizFeedback extends StatelessWidget {
  const QuizFeedback({super.key, required this.right, required this.text});

  final bool right;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = right ? AppColors.secondary : AppColors.offlineAccent;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              right ? Icons.auto_awesome_rounded : Icons.info_outline_rounded,
              size: 17,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.35,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
