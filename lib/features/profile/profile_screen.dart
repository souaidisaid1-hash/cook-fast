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
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: const Text('Mon Profil', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(onboardedProvider.notifier).reset();
            },
            child: const Text('Réinitialiser', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Premium card
            GestureDetector(
              onTap: () => context.push('/premium'),
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isPremium
                        ? [const Color(0xFFFFD700), const Color(0xFFFF8C00)]
                        : [const Color(0xFF1a0533), const Color(0xFF2d1b4e)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Text(isPremium ? '✨' : '👑', style: const TextStyle(fontSize: 32)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPremium ? 'Premium actif' : 'Passer Premium',
                            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            isPremium
                                ? 'Toutes les fonctionnalités débloquées'
                                : 'Débloquer toutes les fonctionnalités IA',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Icon(isPremium ? Icons.check_circle_rounded : Icons.chevron_right,
                        color: Colors.white70),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: () => context.push('/skill-tree'),
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFE5501A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Text('🌳', style: TextStyle(fontSize: 32)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Skill Tree', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                          Text(
                            '${ref.watch(skillTreeProvider).values.fold(0, (a, b) => a + b)} XP accumulés',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: () => context.push('/stats'),
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1a0533), Color(0xFF2d1b4e)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Text('📊', style: TextStyle(fontSize: 32)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Statistiques',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700)),
                          Text(
                            '${ref.watch(skillTreeProvider).values.fold(0, (a, b) => a + b)} XP · ${ref.watch(journalProvider).length} recettes',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white70),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: () => context.push('/journal'),
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Row(
                  children: [
                    const Text('📔', style: TextStyle(fontSize: 32)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mon Journal', style: TextStyle(color: isDark ? AppColors.textDark : AppColors.textLight, fontSize: 17, fontWeight: FontWeight.w700)),
                          Text(
                            '${ref.watch(journalProvider).length} entrée${ref.watch(journalProvider).length > 1 ? 's' : ''}',
                            style: const TextStyle(color: AppColors.textDarkSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.textDarkSecondary),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: () => context.push('/family-profiles'),
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Row(
                  children: [
                    const Text('👨‍👩‍👧', style: TextStyle(fontSize: 32)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Profils Famille', style: TextStyle(color: isDark ? AppColors.textDark : AppColors.textLight, fontSize: 17, fontWeight: FontWeight.w700)),
                          Text(
                            '${ref.watch(familyProfilesProvider).length} membre${ref.watch(familyProfilesProvider).length > 1 ? 's' : ''} · Filtrage des recettes',
                            style: const TextStyle(color: AppColors.textDarkSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.textDarkSecondary),
                  ],
                ),
              ),
            ),
            _tile(isDark, '🥗 Régime', profile.dietLabel),
            _tile(isDark, '👥 Personnes', '${profile.persons}'),
            _tile(isDark, '🎯 Objectif', profile.goalLabel),
            _tile(isDark, '💰 Budget', '${profile.weeklyBudget}€ / semaine'),
            const SizedBox(height: 8),
            _sectionTitle(isDark, '🔔 Notifications'),
            _notifTile(
              isDark,
              '🌅 Rappels repas',
              'Alertes 15 min avant chaque repas planifié',
              notifSettings.mealReminders,
              (v) async {
                notifNotifier.setMealReminders(v);
                if (!v) await NotificationService.cancelMealReminders();
              },
            ),
            _notifTile(
              isDark,
              '🏆 Défi hebdomadaire',
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
            ),
            _notifTile(
              isDark,
              '⏱️ Minuteur de cuisson',
              'Alerte quand le temps d\'une étape est écoulé',
              notifSettings.timerDone,
              (v) async => notifNotifier.setTimerDone(v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(bool isDark, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.textDark : AppColors.textLight,
          ),
        ),
      );

  Widget _notifTile(
    bool isDark,
    String label,
    String sub,
    bool value,
    Future<void> Function(bool) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textDark : AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (v) => onChanged(v),
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _tile(bool isDark, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 15, color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary)),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? AppColors.textDark : AppColors.textLight)),
        ],
      ),
    );
  }
}
