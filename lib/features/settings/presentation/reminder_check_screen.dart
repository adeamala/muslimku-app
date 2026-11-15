import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:muslimku/core/theme/app_colors.dart';
import 'package:muslimku/core/theme/app_text_styles.dart';
import 'package:muslimku/core/time/clock_provider.dart';
import 'package:muslimku/features/prayer/application/adzan_provider.dart';
import 'package:muslimku/features/prayer/data/reminder_gateway.dart';
import 'package:muslimku/features/prayer/domain/adzan_plan.dart';
import 'package:muslimku/shared/widgets/senja/senja.dart';

/// What the phone says about the reminders: three permissions plus whether
/// anything is scheduled. Null means not read yet.
class ReminderChecks {
  const ReminderChecks({
    required this.notifications,
    required this.exactAlarms,
    required this.battery,
  });

  final bool notifications;
  final bool exactAlarms;
  final bool battery;

  static Future<ReminderChecks> read(ReminderGateway gateway) async {
    Future<bool> safe(Future<bool> Function() f) async {
      try {
        return await f();
      } catch (_) {
        return true;
      }
    }

    return ReminderChecks(
      notifications: await safe(gateway.notificationsAllowed),
      exactAlarms: await safe(gateway.exactAlarmsAllowed),
      battery: await safe(gateway.batteryUnrestricted),
    );
  }

  /// Number of failed checks, counting [scheduled] == 0 as one.
  int problems({required int scheduled}) =>
      (notifications ? 0 : 1) +
      (exactAlarms ? 0 : 1) +
      (battery ? 0 : 1) +
      (scheduled > 0 ? 0 : 1);
}

/// "Berikutnya: 10 menit lagi Isya · 18:30 hari ini".
String nextReminderLine(AdzanReminder next, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(next.at.year, next.at.month, next.at.day);
  final diff = day.difference(today).inDays;
  final when = diff == 0
      ? 'hari ini'
      : diff == 1
      ? 'besok'
      : DateFormat('EEEE d MMM', 'id_ID').format(next.at);
  final time = DateFormat('HH:mm').format(next.at);
  return 'Berikutnya: ${next.title} · $time $when';
}

/// Pengaturan > Pengingat adzan > Cek pengingat: why a reminder might not
/// come, each with its fix, and a test notification with the chosen sound.
class ReminderCheckScreen extends ConsumerStatefulWidget {
  const ReminderCheckScreen({super.key});

  @override
  ConsumerState<ReminderCheckScreen> createState() =>
      _ReminderCheckScreenState();
}

class _ReminderCheckScreenState extends ConsumerState<ReminderCheckScreen> {
  ReminderChecks? _checks;
  String? _toast;

  ReminderGateway get _gateway => ref.read(reminderGatewayProvider);

  @override
  void initState() {
    super.initState();
    // Like Pengaturan: plan again on open, so the count and "Berikutnya" are
    // current, then read the permissions.
    Future.microtask(() async {
      await ref.read(adzanProvider.notifier).reschedule();
      await _refresh();
    });
  }

  Future<void> _refresh() async {
    final checks = await ReminderChecks.read(_gateway);
    if (mounted) setState(() => _checks = checks);
  }

  Future<void> _fixNotifications() async {
    var allowed = false;
    try {
      allowed = await _gateway.notificationsAllowed(request: true);
      if (!allowed) await _gateway.openNotificationSettings();
    } catch (_) {}
    if (allowed) await ref.read(adzanProvider.notifier).reschedule();
    await _refresh();
  }

  Future<void> _fixExactAlarms() async {
    await ref.read(adzanProvider.notifier).requestExactAlarms();
    await _refresh();
  }

  Future<void> _fixBattery() async {
    try {
      await _gateway.openBatterySettings();
    } catch (_) {}
    await _refresh();
  }

  Future<void> _replan() async {
    await ref.read(adzanProvider.notifier).reschedule();
    await _refresh();
  }

  Future<void> _testNow() async {
    final ok = await ref.read(adzanProvider.notifier).testNow();
    if (!mounted) return;
    setState(
      () => _toast = ok
          ? 'Notifikasi percobaan dikirim. Kalau tidak muncul atau tidak '
                'berbunyi, periksa poin di atas dan volume HP.'
          : 'HP ini menolak menampilkan notifikasi.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final adzan = ref.watch(adzanProvider);
    final now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    final checks = _checks;
    final enabled = adzan.settings.enabled;
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final problems = checks?.problems(scheduled: adzan.scheduled);
    final next = adzan.next;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.stageBackground,
        body: DefaultTextStyle(
          style: TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 14,
            height: 1.45,
            fontWeight: FontWeight.w500,
            color: AppColors.ink,
          ),
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, top + 4, 16, bottom + 28),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SenjaIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Kembali',
                  iconSize: 24,
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 2),
                child: Semantics(
                  header: true,
                  child: Text(
                    'Cek pengingat',
                    style: TextStyle(
                      fontSize: 30,
                      height: 1.15,
                      letterSpacing: -0.6,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 16),
                child: Text(
                  !enabled
                      ? 'Pengingat adzan mati'
                      : problems == null
                      ? 'Memeriksa…'
                      : problems == 0
                      ? 'Semua siap'
                      : '$problems hal perlu dicek',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: problems == 0 && enabled
                        ? AppColors.secondary
                        : AppColors.inkMuted,
                  ),
                ),
              ),
              if (!enabled)
                SenjaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nyalakan "Pengingat adzan" di Pengaturan dulu, baru '
                        'pemeriksaan ini berguna.',
                      ),
                      const SizedBox(height: 12),
                      SenjaButton(
                        label: 'Kembali ke Pengaturan',
                        height: 48,
                        style: SenjaButtonStyle.outline,
                        onPressed: () => Navigator.maybePop(context),
                      ),
                    ],
                  ),
                )
              else ...[
                SenjaCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _CheckRow(
                        icon: Icons.notifications_none_rounded,
                        title: 'Notifikasi',
                        ok: checks?.notifications,
                        okLabel: 'Diizinkan',
                        badLabel: 'Ditolak',
                        detail:
                            'Tanpa izin ini tidak ada pengingat yang bisa '
                            'tampil.',
                        onFix: _fixNotifications,
                      ),
                      _CheckRow(
                        icon: Icons.alarm_rounded,
                        title: 'Alarm tepat waktu',
                        ok: checks?.exactAlarms,
                        okLabel: 'Diizinkan',
                        badLabel: 'Belum diizinkan',
                        detail:
                            'Tanpa ini Android boleh menunda pengingat '
                            'beberapa menit.',
                        onFix: _fixExactAlarms,
                      ),
                      _CheckRow(
                        icon: Icons.battery_saver_rounded,
                        title: 'Penghemat baterai',
                        ok: checks?.battery,
                        okLabel: 'Tidak dibatasi',
                        badLabel: 'Dibatasi',
                        detail:
                            'HP yang membatasi Muslimku bisa menahan '
                            'pengingat saat layar mati. Pilih "Tidak '
                            'dibatasi" / "Jangan optimalkan".',
                        onFix: _fixBattery,
                      ),
                      _CheckRow(
                        icon: Icons.event_available_rounded,
                        title: 'Pengingat terpasang',
                        ok: adzan.busy ? null : adzan.scheduled > 0,
                        okLabel:
                            '${adzan.scheduled} pengingat 14 hari ke depan',
                        badLabel: adzan.message ?? 'Belum ada',
                        detail: next == null
                            ? 'Pengingat disusun dari jadwal sholat yang '
                                  'tersimpan di HP.'
                            : nextReminderLine(next, now),
                        onFix: _replan,
                        divider: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SenjaButton(
                  label: 'Coba bunyikan sekarang',
                  icon: Icons.notifications_active_rounded,
                  onPressed: _testNow,
                ),
                const SizedBox(height: 10),
                SenjaButton(
                  label: 'Cek lagi',
                  icon: Icons.refresh_rounded,
                  style: SenjaButtonStyle.outline,
                  height: 48,
                  onPressed: _refresh,
                ),
                if (_toast != null) ...[
                  const SizedBox(height: 14),
                  SenjaCard(
                    color: AppColors.lilac,
                    child: Text(
                      _toast!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                const SenjaSectionTitle('Kalau masih tidak berbunyi'),
                const SizedBox(height: 10),
                SenjaCard(
                  child: Text(
                    'Beberapa merek (Xiaomi, Oppo, Vivo, Realme, Samsung) '
                    'punya pengaturan tambahan: izinkan "Mulai otomatis" '
                    '(Autostart) untuk Muslimku, dan matikan "Tidur '
                    'nyenyak"/"Deep sleep" untuknya. Pastikan juga mode '
                    'Jangan Ganggu tidak membisukan notifikasi pengingat.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One check: icon tile, title, state (green check or amber warning) and
/// "Perbaiki" when it fails. [ok] null shows a small spinner.
class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.icon,
    required this.title,
    required this.ok,
    required this.okLabel,
    required this.badLabel,
    required this.detail,
    required this.onFix,
    this.divider = true,
  });

  final IconData icon;
  final String title;
  final bool? ok;
  final String okLabel;
  final String badLabel;
  final String detail;
  final Future<void> Function() onFix;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final state = ok;
    final color = state == null
        ? AppColors.inkMuted
        : state
        ? AppColors.success
        : AppColors.warning;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        border: divider
            ? Border(bottom: BorderSide(color: AppColors.lilacLine))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.lilac,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: AppColors.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (state == null)
                      SizedBox.square(
                        dimension: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.inkMuted,
                        ),
                      )
                    else
                      Icon(
                        state
                            ? Icons.check_circle_rounded
                            : Icons.error_rounded,
                        size: 15,
                        color: color,
                      ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        state == null
                            ? 'Memeriksa…'
                            : state
                            ? okLabel
                            : badLabel,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          if (state == false) ...[
            const SizedBox(width: 10),
            SenjaSmallButton(label: 'Perbaiki', onTap: onFix),
          ],
        ],
      ),
    );
  }
}
