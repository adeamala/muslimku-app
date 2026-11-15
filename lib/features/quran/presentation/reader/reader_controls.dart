import 'package:flutter/material.dart';

import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

// Local stand-ins for SenjaSwitch / SenjaToggleRow: the shared ones draw the
// M3 Switch scaled into 46×28 (it ends up about 36×22) and place it mid-row
// when a tag follows the label (Flexible + Spacer split the free space).
// See the change request in the reader report.

/// 46×28 switch of the design (`.sw`): purple track when on, white knob.
class ReaderSwitch extends StatelessWidget {
  const ReaderSwitch({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160);
    return AnimatedContainer(
      duration: duration,
      width: 46,
      height: 28,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: value ? AppColors.secondary : AppColors.lilacLine,
        borderRadius: BorderRadius.circular(14),
      ),
      child: AnimatedAlign(
        duration: duration,
        curve: Curves.easeOut,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.25),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Label + switch row, 50 px with a hairline (design `.tgl`). The whole row
/// is the tap target.
class ReaderToggleRow extends StatelessWidget {
  const ReaderToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.tag,
    this.icon,
    this.fontSize = 14.5,
    this.divider = true,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  /// Small lilac tag after the label, e.g. "segera".
  final String? tag;

  /// Purple icon before the label.
  final IconData? icon;
  final double fontSize;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Semantics(
      container: true,
      toggled: value,
      enabled: enabled,
      label: tag == null ? label : '$label, $tag',
      excludeSemantics: true,
      onTap: enabled ? () => onChanged!(!value) : null,
      child: InkWell(
        onTap: enabled ? () => onChanged!(!value) : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 50),
          decoration: BoxDecoration(
            border: divider
                ? Border(bottom: BorderSide(color: AppColors.lilacLine))
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 19, color: AppColors.secondary),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    if (tag != null) ...[
                      const SizedBox(width: 8),
                      SenjaTag(tag!),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ReaderSwitch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}
