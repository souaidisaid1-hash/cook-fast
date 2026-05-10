import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/providers/app_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // Selections
  String _diet = 'omnivore';
  int _persons = 2;
  String _goal = 'maintain';
  int _budget = 50;
  final List<String> _cuisines = [];

  final _steps = ['Régime', 'Foyer', 'Objectif', 'Budget', 'Cuisines'];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_step < _steps.length - 1) {
      _animController.reverse().then((_) {
        setState(() => _step++);
        _animController.forward();
      });
    } else {
      _finish();
    }
  }

  void _finish() {
    final profile = UserProfile(
      diet: _diet,
      persons: _persons,
      goal: _goal,
      weeklyBudget: _budget,
      preferredCuisines: _cuisines,
    );
    ref.read(userProfileProvider.notifier).save(profile);
    ref.read(onboardedProvider.notifier).complete();
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              // Progress
              Row(
                children: List.generate(_steps.length, (i) {
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= _step ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 48),

              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: SingleChildScrollView(
                      child: _buildStep(isDark, cardColor, textColor),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _nextStep,
                  child: Text(
                    _step == _steps.length - 1 ? '🚀 Commencer !' : 'Continuer',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(bool isDark, Color cardColor, Color textColor) {
    return switch (_step) {
      0 => _stepDiet(isDark, cardColor, textColor),
      1 => _stepPersons(isDark, cardColor, textColor),
      2 => _stepGoal(isDark, cardColor, textColor),
      3 => _stepBudget(isDark, cardColor, textColor),
      _ => _stepCuisines(isDark, cardColor, textColor),
    };
  }

  Widget _stepDiet(bool isDark, Color cardColor, Color textColor) {
    final options = [
      ('omnivore', '🍖', 'Omnivore', 'Je mange de tout'),
      ('vegetarian', '🥗', 'Végétarien', 'Pas de viande'),
      ('vegan', '🌱', 'Vegan', 'Aucun produit animal'),
      ('gluten_free', '🌾', 'Sans gluten', 'Intolérance au gluten'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quel est ton régime\nalimentaire ?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: textColor, height: 1.2)),
        const SizedBox(height: 8),
        Text('On personnalise tes recettes selon tes besoins.', style: TextStyle(color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary, fontSize: 15)),
        const SizedBox(height: 32),
        ...options.map((o) => _optionCard(o.$1, o.$2, o.$3, o.$4, _diet == o.$1, isDark, cardColor, textColor, () => setState(() => _diet = o.$1))),
      ],
    );
  }

  Widget _stepPersons(bool isDark, Color cardColor, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Combien de personnes\ndans ton foyer ?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: textColor, height: 1.2)),
        const SizedBox(height: 8),
        Text('Pour calculer les bonnes quantités.', style: TextStyle(color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary, fontSize: 15)),
        const SizedBox(height: 60),
        Center(
          child: Column(
            children: [
              Text('👨‍👩‍👧‍👦', style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _circleButton(Icons.remove, () => setState(() => _persons = (_persons - 1).clamp(1, 10))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text('$_persons', style: TextStyle(fontSize: 52, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ),
                  _circleButton(Icons.add, () => setState(() => _persons = (_persons + 1).clamp(1, 10))),
                ],
              ),
              const SizedBox(height: 12),
              Text('personne${_persons > 1 ? 's' : ''}', style: TextStyle(fontSize: 16, color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepGoal(bool isDark, Color cardColor, Color textColor) {
    final options = [
      ('weight_loss', '🏃', 'Perte de poids', 'Recettes légères, moins de 500 kcal'),
      ('maintain', '⚖️', 'Maintien', 'Équilibre et variété'),
      ('muscle_gain', '💪', 'Prise de masse', 'Recettes riches en protéines'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quel est ton objectif\nnutritionnel ?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: textColor, height: 1.2)),
        const SizedBox(height: 8),
        Text('L\'IA adapte le contenu calorique de tes repas.', style: TextStyle(color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary, fontSize: 15)),
        const SizedBox(height: 32),
        ...options.map((o) => _optionCard(o.$1, o.$2, o.$3, o.$4, _goal == o.$1, isDark, cardColor, textColor, () => setState(() => _goal = o.$1))),
      ],
    );
  }

  Widget _stepBudget(bool isDark, Color cardColor, Color textColor) {
    final options = [
      (30, '💚', '30€ / semaine', 'Budget serré, cuisine maline'),
      (50, '💛', '50€ / semaine', 'Équilibre qualité-prix'),
      (80, '🧡', '80€ / semaine', 'Confort et plaisir'),
      (120, '❤️', '120€+ / semaine', 'Sans compromis'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quel est ton budget\nalimentaire ?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: textColor, height: 1.2)),
        const SizedBox(height: 8),
        Text('Pour des plans de repas adaptés à ton portefeuille.', style: TextStyle(color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary, fontSize: 15)),
        const SizedBox(height: 32),
        ...options.map((o) => _optionCard(o.$1.toString(), o.$2, o.$3, o.$4, _budget == o.$1, isDark, cardColor, textColor, () => setState(() => _budget = o.$1))),
      ],
    );
  }

  Widget _stepCuisines(bool isDark, Color cardColor, Color textColor) {
    final cuisines = [
      ('Française', '🇫🇷'), ('Italienne', '🇮🇹'), ('Japonaise', '🇯🇵'),
      ('Mexicaine', '🇲🇽'), ('Indienne', '🇮🇳'), ('Marocaine', '🇲🇦'),
      ('Américaine', '🇺🇸'), ('Grecque', '🇬🇷'), ('Chinoise', '🇨🇳'),
      ('Libanaise', '🇱🇧'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quelles cuisines\ntu aimes ?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: textColor, height: 1.2)),
        const SizedBox(height: 8),
        Text('Choisis plusieurs cuisines (optionnel).', style: TextStyle(color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary, fontSize: 15)),
        const SizedBox(height: 24),
        GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 3,
            children: cuisines.map((c) {
              final selected = _cuisines.contains(c.$1);
              return GestureDetector(
                onTap: () => setState(() {
                  selected ? _cuisines.remove(c.$1) : _cuisines.add(c.$1);
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary.withOpacity(0.15) : cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(c.$2, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(c.$1, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: selected ? AppColors.primary : textColor)),
                    ],
                  ),
                ),
              );
            }).toList(),
        ),
      ],
    );
  }

  Widget _optionCard(String value, String emoji, String title, String subtitle, bool selected, bool isDark, Color cardColor, Color textColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.12) : cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: selected ? AppColors.primary : textColor)),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary)),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle_rounded, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary, width: 1.5),
        ),
        child: Icon(icon, color: AppColors.primary, size: 24),
      ),
    );
  }
}
