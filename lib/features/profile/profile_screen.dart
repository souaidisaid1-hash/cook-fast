import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/services/notification_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    final profile = ref.watch(userProfileProvider);
    final isPremium = ref.watch(premiumProvider);
    final notifSettings = ref.watch(notifSettingsProvider);
    final notifNotifier = ref.read(notifSettingsProvider.notifier);
    final bg = isDark ? AppColors.darkBg : const Color(0xFFF5F2EE);
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final subColor = isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary;
    final xp = ref.watch(skillTreeProvider).values.fold(0, (a, b) => a + b);
    final journalLen = ref.watch(journalProvider).length;
    final familyCount = ref.watch(familyProfilesProvider).length;
    final navBar = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // ── Header ────────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: bg,
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 14, 20, 20),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4, height: 22,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, AppColors.yellow],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text('Mon Profil', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textColor)),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: Text('$xp XP · $journalLen recettes cuisinées',
                            style: TextStyle(fontSize: 12, color: subColor)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => ref.read(onboardedProvider.notifier).reset(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: const Text('Reset', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 20 + navBar),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Premium card ───────────────────────────────────────────────
                GestureDetector(
                  onTap: () => context.push('/premium'),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isPremium
                            ? [const Color(0xFFFFD700), const Color(0xFFFF8C00)]
                            : [const Color(0xFF1a0533), const Color(0xFF3d1f6e)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: (isPremium ? const Color(0xFFFFD700) : AppColors.purple).withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Text(isPremium ? '✨' : '👑', style: const TextStyle(fontSize: 34)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isPremium ? 'Premium actif' : 'Passer Premium',
                                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isPremium
                                    ? 'Toutes les fonctionnalités débloquées'
                                    : 'Débloquer toutes les fonctionnalités IA',
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPremium ? Icons.check_rounded : Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Quick stats row ────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(child: _statCard('$xp', 'XP', AppColors.primary, isDark)),
                    const SizedBox(width: 10),
                    Expanded(child: _statCard('$journalLen', 'Recettes', AppColors.green, isDark)),
                    const SizedBox(width: 10),
                    Expanded(child: _statCard('$familyCount', 'Membres', AppColors.blue, isDark)),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Navigation tiles ───────────────────────────────────────────
                _sectionLabel('FONCTIONNALITÉS', subColor),
                const SizedBox(height: 8),

                _navTile(
                  emoji: '🌳',
                  title: 'Skill Tree',
                  subtitle: '$xp XP accumulés',
                  colors: [const Color(0xFFFF6B35), const Color(0xFFE5501A)],
                  isDark: isDark,
                  onTap: () => context.push('/skill-tree'),
                ),

                _navTile(
                  emoji: '📊',
                  title: 'Statistiques',
                  subtitle: '$xp XP · $journalLen recettes',
                  colors: [const Color(0xFF1a0533), const Color(0xFF2d1b4e)],
                  isDark: isDark,
                  onTap: () => context.push('/stats'),
                ),

                _navTile(
                  emoji: '📔',
                  title: 'Mon Journal',
                  subtitle: '$journalLen entrée${journalLen != 1 ? 's' : ''}',
                  colors: [AppColors.blue, const Color(0xFF1565C0)],
                  isDark: isDark,
                  onTap: () => context.push('/journal'),
                ),

                _navTile(
                  emoji: '👨‍👩‍👧',
                  title: 'Profils Famille',
                  subtitle: '$familyCount membre${familyCount != 1 ? 's' : ''} · Filtrage des recettes',
                  colors: [AppColors.green, const Color(0xFF1B8A4F)],
                  isDark: isDark,
                  onTap: () => context.push('/family-profiles'),
                ),

                const SizedBox(height: 16),

                // ── Profile info ───────────────────────────────────────────────
                _sectionLabel('MON PROFIL', subColor),
                const SizedBox(height: 8),

                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _infoRow('🥗 Régime', profile.dietLabel, isDark, first: true),
                      _divider(isDark),
                      _infoRow('👥 Personnes', '${profile.persons}', isDark),
                      _divider(isDark),
                      _infoRow('🎯 Objectif', profile.goalLabel, isDark),
                      _divider(isDark),
                      _infoRow('💰 Budget', '${profile.weeklyBudget}€ / semaine', isDark, last: true),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Langue ─────────────────────────────────────────────────────
                _sectionLabel('LANGUE DES RECETTES', subColor),
                const SizedBox(height: 8),
                _langToggle(ref.watch(langProvider), ref, isDark, textColor, subColor),
                const SizedBox(height: 16),

                // ── Notifications ──────────────────────────────────────────────
                _sectionLabel('NOTIFICATIONS', subColor),
                const SizedBox(height: 8),

                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _notifRow(
                        '🌅',
                        'Rappels repas',
                        'Alertes 15 min avant chaque repas planifié',
                        notifSettings.mealReminders,
                        (v) async {
                          notifNotifier.setMealReminders(v);
                          if (!v) await NotificationService.cancelMealReminders();
                        },
                        isDark,
                        textColor,
                        subColor,
                        first: true,
                      ),
                      _divider(isDark),
                      _notifRow(
                        '🏆',
                        'Défi hebdomadaire',
                        'Rappel chaque lundi à 9h pour le nouveau défi',
                        notifSettings.challengeReminder,
                        (v) async {
                          notifNotifier.setChallengeReminder(v);
                          if (v) {
                            await NotificationService.requestPermission();
                            await NotificationService.scheduleChallengeReminder();
                          } else {
                            await NotificationService.cancelChallengeReminder();
                          }
                        },
                        isDark,
                        textColor,
                        subColor,
                      ),
                      _divider(isDark),
                      _notifRow(
                        '⏱️',
                        'Minuteur de cuisson',
                        "Alerte quand le temps d'une étape est écoulé",
                        notifSettings.timerDone,
                        (v) async => notifNotifier.setTimerDone(v),
                        isDark,
                        textColor,
                        subColor,
                        last: true,
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _statCard(String value, String label, Color color, bool isDark) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.75))),
          ],
        ),
      );

  static Widget _sectionLabel(String text, Color subColor) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(text,
            style: TextStyle(color: subColor, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
      );

  static Widget _navTile({
    required String emoji,
    required String title,
    required String subtitle,
    required List<Color> colors,
    required bool isDark,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: colors.first.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                          color: isDark ? AppColors.textDark : AppColors.textLight,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                          color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                          fontSize: 12,
                        )),
                  ],
                ),
              ),
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary),
              ),
            ],
          ),
        ),
      );

  static Widget _infoRow(String label, String value, bool isDark,
      {bool first = false, bool last = false}) =>
      Padding(
        padding: EdgeInsets.fromLTRB(16, first ? 14 : 12, 16, last ? 14 : 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                )),
            Text(value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textDark : AppColors.textLight,
                )),
          ],
        ),
      );

  static Widget _notifRow(
    String emoji,
    String title,
    String subtitle,
    bool value,
    Future<void> Function(bool) onChanged,
    bool isDark,
    Color textColor,
    Color subColor, {
    bool first = false,
    bool last = false,
  }) =>
      Padding(
        padding: EdgeInsets.fromLTRB(16, first ? 14 : 10, 16, last ? 14 : 10),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: subColor)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.primary,
            ),
          ],
        ),
      );

  static Widget _langToggle(String lang, WidgetRef ref, bool isDark, Color textColor, Color subColor) =>
      Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            const Text('🌐', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Langue des recettes',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                  const SizedBox(height: 2),
                  Text('Traduit automatiquement via IA',
                      style: TextStyle(fontSize: 12, color: subColor)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBg : const Color(0xFFF5F2EE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _langBtn('FR', '🇫🇷', lang == 'fr', () => ref.read(langProvider.notifier).set('fr')),
                  _langBtn('EN', '🇬🇧', lang == 'en', () => ref.read(langProvider.notifier).set('en')),
                ],
              ),
            ),
          ],
        ),
      );

  static Widget _langBtn(String label, String flag, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: active
                ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(flag, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : AppColors.textLightSecondary,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );

  static Widget _divider(bool isDark) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      );
}
