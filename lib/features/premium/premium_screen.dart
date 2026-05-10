import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/providers/app_providers.dart';

// ─── Plans ────────────────────────────────────────────────────────────────────

class _Plan {
  final String id;
  final String label;
  final String price;
  final String sub;
  final String? badge;
  final bool highlighted;

  const _Plan({
    required this.id,
    required this.label,
    required this.price,
    required this.sub,
    this.badge,
    this.highlighted = false,
  });
}

const _plans = [
  _Plan(
    id: 'annual',
    label: 'Annuel',
    price: '34,99 €',
    sub: '2,92 € / mois',
    badge: '🔥 Meilleur rapport',
    highlighted: true,
  ),
  _Plan(
    id: 'monthly',
    label: 'Mensuel',
    price: '4,99 €',
    sub: 'par mois',
  ),
];

const _perks = [
  ('🚀', 'Batch Cooking jusqu\'à 5 recettes', '2 recettes en gratuit'),
  ('📔', 'Journal illimité', '5 entrées en gratuit'),
  ('👨‍👩‍👧', 'Jusqu\'à 5 profils famille', '1 profil en gratuit'),
  ('👥', 'Cook Together illimité', ''),
  ('🏆', 'Défis communautaires illimités', ''),
  ('🤖', 'IA sans restrictions', ''),
  ('⭐', 'Soutenir le développement', ''),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _State();
}

class _State extends ConsumerState<PremiumScreen> {
  String _selectedPlan = 'annual';
  bool _loading = false;

  Future<void> _subscribe() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 800)); // TODO: RevenueCat purchase
    ref.read(premiumProvider.notifier).activate();
    setState(() => _loading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ Premium activé ! Merci pour ton soutien.'),
          backgroundColor: Color(0xFFFFD700),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(premiumProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: CustomScrollView(
        slivers: [
          // ── Hero ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Stack(
              children: [
                Container(
                  height: 260,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1a0533), Color(0xFF0D0D1A)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => context.pop(),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 20),
                              ),
                            ),
                            const Spacer(),
                            if (!isPremium)
                              TextButton(
                                onPressed: () => context.pop(),
                                child: const Text('Restaurer', style: TextStyle(color: Colors.white54, fontSize: 13)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Crown + title
                        const Text('👑', style: TextStyle(fontSize: 56)),
                        const SizedBox(height: 12),
                        const Text(
                          'CookFast Premium',
                          style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900,
                              letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Cuisine sans limites avec toutes les fonctionnalités IA',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Active state ──────────────────────────────────────────────────
          if (isPremium)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Text('✨', style: TextStyle(fontSize: 32)),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Premium actif',
                                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                                SizedBox(height: 4),
                                Text('Toutes les fonctionnalités sont débloquées.',
                                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._perks.map((p) => _PerkTile(emoji: p.$1, title: p.$2, free: p.$3)),
                  ],
                ),
              ),
            )
          else ...[
            // ── Perks list ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  children: _perks.map((p) => _PerkTile(emoji: p.$1, title: p.$2, free: p.$3)).toList(),
                ),
              ),
            ),

            // ── Plans ─────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Choisir un plan',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    ..._plans.map((plan) => _PlanCard(
                      plan: plan,
                      selected: _selectedPlan == plan.id,
                      onTap: () => setState(() => _selectedPlan = plan.id),
                    )),
                  ],
                ),
              ),
            ),

            // ── CTA ───────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _subscribe,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD700),
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: const Color(0xFFFFD700).withValues(alpha: 0.5),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                            : Text(
                                _selectedPlan == 'annual'
                                    ? 'Essai gratuit 7 jours — puis 34,99 €/an'
                                    : 'S\'abonner — 4,99 €/mois',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Résiliation à tout moment · Renouvellement automatique\nEn t\'abonnant tu acceptes nos CGU et politique de confidentialité.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white30, fontSize: 11, height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Perk tile ────────────────────────────────────────────────────────────────

class _PerkTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String free;

  const _PerkTile({required this.emoji, required this.title, required this.free});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                if (free.isNotEmpty)
                  Text(free, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: Color(0xFFFFD700), size: 20),
        ],
      ),
    );
  }
}

// ─── Plan card ────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final _Plan plan;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({required this.plan, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFD700).withValues(alpha: 0.1) : const Color(0xFF1C1C2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFFFFD700) : Colors.white12,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? const Color(0xFFFFD700) : Colors.transparent,
                border: Border.all(
                    color: selected ? const Color(0xFFFFD700) : Colors.white30, width: 2),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 13, color: Colors.black)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(plan.label,
                          style: TextStyle(
                              color: selected ? const Color(0xFFFFD700) : Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      if (plan.badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(plan.badge!,
                              style: const TextStyle(color: Color(0xFFFFD700), fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(plan.sub, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            Text(plan.price,
                style: TextStyle(
                    color: selected ? const Color(0xFFFFD700) : Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
