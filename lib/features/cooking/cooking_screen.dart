import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/providers/app_providers.dart';

class CookingScreen extends ConsumerWidget {
  const CookingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mode Cuisson 🍳', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: textColor)),
              const SizedBox(height: 4),
              const Text('Choisis comment tu veux cuisiner', style: TextStyle(color: AppColors.textDarkSecondary, fontSize: 14)),
              const SizedBox(height: 28),

              // Batch Cooking — featured
              GestureDetector(
                onTap: () => context.push('/batch-select'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFF9B59B6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🚀', style: TextStyle(fontSize: 40)),
                      const SizedBox(height: 12),
                      const Text('Batch Cooking', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      const Text(
                        'Cuisine 2 à 5 recettes en une seule session optimisée par l\'IA.\nGagne du temps en parallélisant les tâches.',
                        style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                        child: const Text('Démarrer une session →', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Cook Together
              _modeCard(
                context,
                cardBg: cardBg,
                emoji: '👥',
                title: 'Cook Together',
                subtitle: 'Cuisinez la même recette en temps réel avec des amis ou la famille.',
                hint: 'Rejoindre une session →',
                onTap: () => context.push('/cook-together-join'),
              ),

              const SizedBox(height: 12),

              // Cook Mode solo
              _modeCard(
                context,
                cardBg: cardBg,
                emoji: '🍽️',
                title: 'Cook Mode',
                subtitle: 'Suis une recette étape par étape avec timer et sous-chef vocal.',
                hint: 'Lance depuis une recette →',
                onTap: null,
              ),

              const SizedBox(height: 12),

              // Leftover Brain
              _modeCard(
                context,
                cardBg: cardBg,
                emoji: '🧠',
                title: 'Leftover Brain',
                subtitle: 'Réinventez vos restes après la cuisson et réduisez le gaspillage.',
                hint: 'Accessible depuis Cook Mode →',
                onTap: null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeCard(
    BuildContext context, {
    required Color cardBg,
    required String emoji,
    required String title,
    required String subtitle,
    required String hint,
    VoidCallback? onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: AppColors.textDarkSecondary, fontSize: 12, height: 1.4)),
                    const SizedBox(height: 6),
                    Text(hint, style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
