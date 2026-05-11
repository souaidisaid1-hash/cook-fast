import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/providers/app_providers.dart';

// ─── Challenge data ───────────────────────────────────────────────────────────

class _Challenge {
  final String title;
  final String emoji;
  final String description;
  final String hint;
  final List<Color> gradient;
  final int xp;

  const _Challenge({
    required this.title,
    required this.emoji,
    required this.description,
    required this.hint,
    required this.gradient,
    required this.xp,
  });
}

const _challenges = [
  _Challenge(
    title: 'Semaine Italienne',
    emoji: '🍝',
    description: 'Cuisine une recette italienne authentique cette semaine.',
    hint: 'Pasta, risotto, pizza maison...',
    gradient: [Color(0xFF2ECC71), Color(0xFF27AE60)],
    xp: 50,
  ),
  _Challenge(
    title: 'Défi Poulet',
    emoji: '🐔',
    description: 'Prépare un plat à base de poulet avec au moins 3 épices différentes.',
    hint: 'Poulet rôti, curry, tajine...',
    gradient: [Color(0xFFFF9F43), Color(0xFFEE5A24)],
    xp: 40,
  ),
  _Challenge(
    title: 'Veggie Week',
    emoji: '🥗',
    description: 'Réalise une recette 100 % végétarienne qui surprend par ses saveurs.',
    hint: 'Curry de légumes, buddha bowl...',
    gradient: [Color(0xFF6AB04C), Color(0xFF1e3799)],
    xp: 60,
  ),
  _Challenge(
    title: 'Fruits de Mer',
    emoji: '🦐',
    description: 'Cuisine un plat de fruits de mer ou de poisson.',
    hint: 'Saumon, crevettes, moules...',
    gradient: [Color(0xFF0652DD), Color(0xFF1289A7)],
    xp: 70,
  ),
  _Challenge(
    title: 'Brunch du Dimanche',
    emoji: '🍳',
    description: 'Prépare un brunch complet et généreux pour toute la famille.',
    hint: 'Pancakes, œufs, smoothie...',
    gradient: [Color(0xFFF9CA24), Color(0xFFF0932B)],
    xp: 45,
  ),
  _Challenge(
    title: 'Bœuf de Compétition',
    emoji: '🥩',
    description: 'Réalise un plat de bœuf digne d\'un chef — marinade ou mijotage.',
    hint: 'Bourguignon, tartare, steak...',
    gradient: [Color(0xFFB71540), Color(0xFF6F1E51)],
    xp: 55,
  ),
  _Challenge(
    title: 'Dessert Surprise',
    emoji: '🍰',
    description: 'Crée un dessert maison que tu n\'as jamais fait avant.',
    hint: 'Tiramisu, tarte, fondant...',
    gradient: [Color(0xFFFF6B9D), Color(0xFFa55eea)],
    xp: 65,
  ),
  _Challenge(
    title: 'Cuisine du Monde',
    emoji: '🌍',
    description: 'Découvre et cuisine une recette d\'un pays que tu n\'as jamais cuisiné.',
    hint: 'Japonais, mexicain, indien...',
    gradient: [Color(0xFF4a00e0), Color(0xFF8e2de2)],
    xp: 75,
  ),
  _Challenge(
    title: 'Soupe Maîtresse',
    emoji: '🍲',
    description: 'Prépare une soupe ou un mijoté fait maison avec des légumes de saison.',
    hint: 'Minestrone, ramen, pot-au-feu...',
    gradient: [Color(0xFF11998e), Color(0xFF38ef7d)],
    xp: 45,
  ),
  _Challenge(
    title: 'Entrée Raffinée',
    emoji: '🥟',
    description: 'Cuisine une entrée digne d\'un restaurant pour impressionner tes convives.',
    hint: 'Velouté, carpaccio, bruschetta...',
    gradient: [Color(0xFFfd746c), Color(0xFFff9068)],
    xp: 50,
  ),
];

_Challenge get _currentChallenge {
  final week = DateTime.now().difference(DateTime(2024, 1, 1)).inDays ~/ 7;
  return _challenges[week % _challenges.length];
}

int get _weekNumber => DateTime.now().difference(DateTime(2024, 1, 1)).inDays ~/ 7;

// ─── Screen ───────────────────────────────────────────────────────────────────

class ChallengeScreen extends ConsumerStatefulWidget {
  const ChallengeScreen({super.key});

  @override
  ConsumerState<ChallengeScreen> createState() => _State();
}

class _State extends ConsumerState<ChallengeScreen> {
  List<Map<String, dynamic>> _completions = [];
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  bool _hasCompleted = false;

  @override
  void initState() {
    super.initState();
    _sub = Supabase.instance.client
        .from('challenge_completions')
        .stream(primaryKey: ['id'])
        .eq('week_number', _weekNumber)
        .listen((rows) {
      if (mounted) setState(() => _completions = rows);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _openSubmitSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SubmitSheet(
        challenge: _currentChallenge,
        weekNumber: _weekNumber,
        onSubmitted: (name, emoji, recipe, note) async {
          await Supabase.instance.client.from('challenge_completions').insert({
            'week_number': _weekNumber,
            'challenge_title': _currentChallenge.title,
            'participant_name': name,
            'participant_emoji': emoji,
            'recipe_title': recipe,
            'note': note,
          });
          ref.read(skillTreeProvider.notifier).addXp('misc', _currentChallenge.xp);
          if (mounted) setState(() => _hasCompleted = true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final challenge = _currentChallenge;
    final isDark = ref.watch(themeProvider);
    final bg = isDark ? AppColors.darkBg : const Color(0xFFF5F2EE);
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        iconTheme: IconThemeData(color: textColor),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 4, height: 20,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.yellow]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text('Défi de la semaine 🏆', style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Hero banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: challenge.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                      child: Text('Semaine ${_weekNumber % 52 + 1}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                      child: Text('+${challenge.xp} XP',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(challenge.emoji, style: const TextStyle(fontSize: 52)),
                const SizedBox(height: 10),
                Text(challenge.title,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(challenge.description,
                    style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
                const SizedBox(height: 6),
                Text('💡 ${challenge.hint}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic)),
                const SizedBox(height: 20),
                if (_hasCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(14)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Défi complété cette semaine !',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  )
                else
                  GestureDetector(
                    onTap: _openSubmitSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🏆', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text('Je relève le défi',
                              style: TextStyle(
                                  color: challenge.gradient[0],
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Community counter
          Row(
            children: [
              const Text('🍳', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                '${_completions.length} cuisinier${_completions.length > 1 ? 's' : ''} ont relevé ce défi',
                style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Community feed
          if (_completions.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Center(
                child: Text('Sois le premier à relever le défi cette semaine !',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary, fontSize: 14)),
              ),
            )
          else
            ...(_completions.reversed.map((c) => _CompletionCard(data: c, isDark: isDark, cardBg: cardBg))),
        ],
      ),
    );
  }
}

// ─── Completion card ──────────────────────────────────────────────────────────

class _CompletionCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDark;
  final Color cardBg;
  const _CompletionCard({required this.data, required this.isDark, required this.cardBg});

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(data['completed_at'] as String? ?? '') ?? DateTime.now();
    final daysSince = DateTime.now().difference(dt).inDays;
    final timeLabel = daysSince == 0 ? "aujourd'hui" : 'il y a $daysSince j.';
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final subColor = isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(data['participant_emoji'] as String? ?? '🧑',
                style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(data['participant_name'] as String? ?? '',
                        style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(timeLabel, style: TextStyle(color: subColor, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.restaurant_menu_rounded, size: 12, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(data['recipe_title'] as String? ?? '',
                          style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
                if ((data['note'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text('"${data['note']}"',
                      style: TextStyle(color: subColor, fontSize: 12, fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Submit sheet ─────────────────────────────────────────────────────────────

const _sheetEmojis = ['👨‍🍳', '👩‍🍳', '🧑', '👨', '👩', '🧔', '👱', '🧒', '🎩', '😎'];

class _SubmitSheet extends StatefulWidget {
  final _Challenge challenge;
  final int weekNumber;
  final Future<void> Function(String name, String emoji, String recipe, String note) onSubmitted;

  const _SubmitSheet({required this.challenge, required this.weekNumber, required this.onSubmitted});

  @override
  State<_SubmitSheet> createState() => _SubmitSheetState();
}

class _SubmitSheetState extends State<_SubmitSheet> {
  final _nameCtrl = TextEditingController();
  final _recipeCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _emoji = '👨‍🍳';
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _recipeCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _recipeCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    await widget.onSubmitted(
      _nameCtrl.text.trim(),
      _emoji,
      _recipeCtrl.text.trim(),
      _noteCtrl.text.trim(),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final navBar = MediaQuery.of(context).viewPadding.bottom;
    final keyboard = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + keyboard + navBar),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: AppColors.darkBorder, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(widget.challenge.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Valider mon défi',
                      style: const TextStyle(color: AppColors.textDark, fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Emoji picker
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _sheetEmojis.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final e = _sheetEmojis[i];
                  final sel = e == _emoji;
                  return GestureDetector(
                    onTap: () => setState(() => _emoji = e),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary.withValues(alpha: 0.2) : AppColors.darkSurface,
                        shape: BoxShape.circle,
                        border: Border.all(color: sel ? AppColors.primary : Colors.transparent, width: 2),
                      ),
                      child: Center(child: Text(e, style: const TextStyle(fontSize: 22))),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: AppColors.textDark),
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Ton prénom *',
                labelStyle: TextStyle(color: AppColors.textDarkSecondary),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _recipeCtrl,
              style: const TextStyle(color: AppColors.textDark),
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Recette cuisinée *',
                labelStyle: TextStyle(color: AppColors.textDarkSecondary),
                hintText: 'ex: Pasta Carbonara',
                hintStyle: TextStyle(color: AppColors.textDarkSecondary),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _noteCtrl,
              style: const TextStyle(color: AppColors.textDark),
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note (facultatif)',
                labelStyle: TextStyle(color: AppColors.textDarkSecondary),
                hintText: 'Un commentaire sur ta préparation...',
                hintStyle: TextStyle(color: AppColors.textDarkSecondary),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('🏆', style: TextStyle(fontSize: 16)),
                label: Text(_loading ? 'Envoi...' : 'Valider mon défi (+${widget.challenge.xp} XP)',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
