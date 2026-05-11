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
    _BranchDef('meat',      '🥩', 'Viandes',          Color(0xFFE74C3C)),
    _BranchDef('pastry',    '🥐', 'Pâtisserie',       Color(0xFFF5A623)),
    _BranchDef('seafood',   '🐟', 'Poisson & Mer',    Color(0xFF4A90D9)),
    _BranchDef('veggie',    '🥗', 'Végétarien',       Color(0xFF4CAF7D)),
    _BranchDef('breakfast', '🍳', 'Petit-Déjeuner',   Color(0xFFFF9F43)),
    _BranchDef('misc',      '🍲', 'Cuisine Générale', Color(0xFF9B59B6)),
    _BranchDef('ecology',   '🌱', 'Zéro Gaspillage',  Color(0xFF27AE60)),
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
    final isDark = ref.watch(themeProvider);
    final xpMap = ref.watch(skillTreeProvider);
    final totalXp = xpMap.values.fold(0, (a, b) => a + b);
    final bg = isDark ? AppColors.darkBg : const Color(0xFFF5F2EE);
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final subColor = isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 4, height: 22,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFF9B59B6)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('Skill Tree 🌳', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textColor)),
                  ],
                ),
              ),

              // ── XP Banner ─────────────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFE5501A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFFF6B35).withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('XP Total', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        Text('$totalXp XP',
                            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(_overallTitle(totalXp),
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const Spacer(),
                    const Text('🏆', style: TextStyle(fontSize: 52)),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ── Section title ─────────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 4, height: 18,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.primary, AppColors.yellow]),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('Branches culinaires',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
                ],
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
                    isDark: isDark,
                    cardBg: cardBg,
                    textColor: textColor,
                    subColor: subColor,
                  );
                },
              ),

              const SizedBox(height: 24),

              // ── How to earn ────────────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 4, height: 18,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.primary, AppColors.yellow]),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text("Comment gagner de l'XP",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
                ],
              ),
              const SizedBox(height: 12),
              _earnTile('🍳', 'Terminer Cook Mode', '+25 XP dans la branche de la recette', isDark, cardBg, textColor),
              const SizedBox(height: 8),
              _earnTile('🌱', 'Utiliser Leftover Brain', '+15 XP Zéro Gaspillage', isDark, cardBg, textColor),
              const SizedBox(height: 8),
              _earnTile('🏆', 'Compléter un défi', 'XP variable selon le défi', isDark, cardBg, textColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _earnTile(String emoji, String action, String reward, bool isDark, Color cardBg, Color textColor) => Container(
        margin: const EdgeInsets.only(bottom: 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(action, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600)),
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
  final bool isDark;
  final Color cardBg;
  final Color textColor;
  final Color subColor;

  const _BranchCard({
    required this.branch,
    required this.xp,
    required this.level,
    required this.progress,
    required this.isDark,
    required this.cardBg,
    required this.textColor,
    required this.subColor,
  });

  static const _levelNames = ['', 'Débutant', 'Apprenti', 'Cuisinier', 'Chef', 'Maître'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: xp > 0 ? branch.color.withValues(alpha: 0.4) : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 3)),
        ],
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
                child: Text('Niv.$level',
                    style: TextStyle(color: branch.color, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(branch.name,
                  style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(_levelNames.elementAtOrNull(level) ?? 'Maître',
                  style: TextStyle(color: subColor, fontSize: 11)),
              const SizedBox(height: 6),
              Stack(
                children: [
                  Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: branch.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text('$xp XP', style: TextStyle(color: branch.color, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}
