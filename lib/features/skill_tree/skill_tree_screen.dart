import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/providers/app_providers.dart';

// ─── Branch definitions ──────────────────────────────────────────────────────

class _BranchDef {
  final String id;
  final String emoji;
  final String name;
  final Color color;
  const _BranchDef(this.id, this.emoji, this.name, this.color);
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class SkillTreeScreen extends ConsumerWidget {
  const SkillTreeScreen({super.key});

  static const _branches = [
    _BranchDef('meat',      '🥩', 'Viandes',         Color(0xFFE74C3C)),
    _BranchDef('pastry',    '🥐', 'Pâtisserie',      Color(0xFFF5A623)),
    _BranchDef('seafood',   '🐟', 'Poisson & Mer',   Color(0xFF4A90D9)),
    _BranchDef('veggie',    '🥗', 'Végétarien',      Color(0xFF4CAF7D)),
    _BranchDef('breakfast', '🍳', 'Petit-Déjeuner',  Color(0xFFFF9F43)),
    _BranchDef('misc',      '🍲', 'Cuisine Générale',Color(0xFF9B59B6)),
    _BranchDef('ecology',   '🌱', 'Zéro Gaspillage', Color(0xFF27AE60)),
  ];

  static const _xpThresholds = [0, 100, 250, 500, 1000, 2000];

  static int _level(int xp) {
    for (int i = _xpThresholds.length - 1; i >= 0; i--) {
      if (xp >= _xpThresholds[i]) return i + 1;
    }
    return 1;
  }

  static double _progress(int xp) {
    final lvl = _level(xp) - 1;
    if (lvl >= _xpThresholds.length - 1) return 1.0;
    final start = _xpThresholds[lvl];
    final end = _xpThresholds[lvl + 1];
    return ((xp - start) / (end - start)).clamp(0.0, 1.0);
  }

  static String _overallTitle(int totalXp) {
    if (totalXp >= 3000) return 'Grand Chef ⭐⭐⭐';
    if (totalXp >= 1500) return 'Chef Expérimenté ⭐⭐';
    if (totalXp >= 500) return 'Cuisinier Confirmé ⭐';
    if (totalXp >= 100) return 'Amateur Passionné';
    return 'Cuisinier en herbe';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final xpMap = ref.watch(skillTreeProvider);
    final totalXp = xpMap.values.fold(0, (a, b) => a + b);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        title: const Text(
          'Skill Tree 🌳',
          style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTotalBanner(totalXp),
              const SizedBox(height: 24),
              const Text(
                'Branches culinaires',
                style: TextStyle(color: AppColors.textDark, fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.05,
                ),
                itemCount: _branches.length,
                itemBuilder: (_, i) {
                  final b = _branches[i];
                  final xp = xpMap[b.id] ?? 0;
                  return _BranchCard(
                    branch: b,
                    xp: xp,
                    level: _level(xp),
                    progress: _progress(xp),
                  );
                },
              ),
              const SizedBox(height: 28),
              _buildHowToEarn(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalBanner(int totalXp) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFE5501A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('XP Total', style: TextStyle(color: Colors.white70, fontSize: 13)),
                Text(
                  '$totalXp XP',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  _overallTitle(totalXp),
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const Spacer(),
            const Text('🏆', style: TextStyle(fontSize: 52)),
          ],
        ),
      );

  Widget _buildHowToEarn() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comment gagner de l\'XP',
            style: TextStyle(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _earnTile('🍳', 'Terminer Cook Mode', '+25 XP dans la branche de la recette'),
          const SizedBox(height: 8),
          _earnTile('🌱', 'Utiliser Leftover Brain', '+15 XP Zéro Gaspillage'),
        ],
      );

  Widget _earnTile(String emoji, String action, String reward) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(action, style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w500)),
                  Text(reward, style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
}

// ─── Branch card ─────────────────────────────────────────────────────────────

class _BranchCard extends StatelessWidget {
  final _BranchDef branch;
  final int xp;
  final int level;
  final double progress;

  const _BranchCard({
    required this.branch,
    required this.xp,
    required this.level,
    required this.progress,
  });

  static const _levelNames = ['', 'Débutant', 'Apprenti', 'Cuisinier', 'Chef', 'Maître'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: xp > 0 ? branch.color.withValues(alpha: 0.4) : AppColors.darkBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(branch.emoji, style: const TextStyle(fontSize: 28)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: branch.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Niv.$level',
                  style: TextStyle(
                    color: branch.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                branch.name,
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                _levelNames.elementAtOrNull(level) ?? 'Maître',
                style: const TextStyle(color: AppColors.textDarkSecondary, fontSize: 11),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: AppColors.darkBorder,
                  color: branch.color,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '$xp XP',
                style: TextStyle(
                  color: branch.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
