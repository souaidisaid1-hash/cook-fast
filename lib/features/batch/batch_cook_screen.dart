import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/recipe.dart';
import '../../shared/services/gemini_service.dart';

// ─── Colors ──────────────────────────────────────────────────────────────────

const _recipeColors = [
  AppColors.primary,
  AppColors.blue,
  AppColors.green,
  AppColors.purple,
  AppColors.yellow,
];

Color _colorFor(String recipeId, List<Recipe> recipes) {
  final idx = recipes.indexWhere((r) => r.id == recipeId);
  return _recipeColors[(idx < 0 ? 0 : idx).clamp(0, _recipeColors.length - 1)];
}

// ─── State ───────────────────────────────────────────────────────────────────

class _BatchCookState {
  final List<BatchStep> steps;
  final bool loading;
  final int currentIndex;
  final bool isSpeaking;
  final int elapsedSeconds;

  const _BatchCookState({
    this.steps = const [],
    this.loading = true,
    this.currentIndex = 0,
    this.isSpeaking = false,
    this.elapsedSeconds = 0,
  });

  _BatchCookState copyWith({
    List<BatchStep>? steps,
    bool? loading,
    int? currentIndex,
    bool? isSpeaking,
    int? elapsedSeconds,
  }) =>
      _BatchCookState(
        steps: steps ?? this.steps,
        loading: loading ?? this.loading,
        currentIndex: currentIndex ?? this.currentIndex,
        isSpeaking: isSpeaking ?? this.isSpeaking,
        elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      );
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class _BatchNotifier extends StateNotifier<_BatchCookState> {
  final List<Recipe> recipes;
  final FlutterTts _tts = FlutterTts();
  Timer? _timer;

  _BatchNotifier(this.recipes) : super(const _BatchCookState()) {
    _init();
  }

  Future<void> _init() async {
    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.45);
    _tts.setCompletionHandler(() {
      if (mounted) state = state.copyWith(isSpeaking: false);
    });

    final gemini = await GeminiService.generateBatchTimeline(recipes);
    final steps = gemini ?? _fallback();
    state = state.copyWith(steps: steps, loading: false);
    _startTimer();
  }

  List<BatchStep> _fallback() {
    final result = <BatchStep>[];
    int id = 1;
    int startMin = 0;
    final maxSteps = recipes.map((r) => r.steps.length).reduce(max);

    for (int stepIdx = 0; stepIdx < maxSteps && result.length < 15; stepIdx++) {
      for (final recipe in recipes) {
        if (stepIdx < recipe.steps.length && result.length < 15) {
          final dur = _estimate(recipe.steps[stepIdx]);
          result.add(BatchStep(
            id: id++,
            recipeId: recipe.id,
            recipeTitle: recipe.title,
            description: recipe.steps[stepIdx],
            startMinute: startMin,
            durationMinutes: dur,
          ));
          startMin += dur;
        }
      }
    }
    return result;
  }

  int _estimate(String step) {
    final lower = step.toLowerCase();
    final match = RegExp(r'(\d+)\s*min').firstMatch(lower);
    if (match != null) return int.tryParse(match.group(1)!) ?? 5;
    if (lower.contains('heure')) return 60;
    if (lower.contains('mijoter') || lower.contains('simmer')) return 20;
    if (lower.contains('cuire') || lower.contains('bouillir')) return 15;
    return 5;
  }

  void _startTimer() {
    _timer?.cancel();
    state = state.copyWith(elapsedSeconds: 0);
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
      },
    );
  }

  Future<void> goTo(int index) async {
    if (index < 0 || index >= state.steps.length) return;
    await _tts.stop();
    state = state.copyWith(currentIndex: index, isSpeaking: false);
    _startTimer();
  }

  Future<void> toggleSpeak() async {
    if (state.isSpeaking) {
      await _tts.stop();
      state = state.copyWith(isSpeaking: false);
      return;
    }
    final step = state.steps.elementAtOrNull(state.currentIndex);
    if (step == null) return;
    state = state.copyWith(isSpeaking: true);
    await _tts.speak('${step.recipeTitle}. ${step.description}');
  }

  _BatchCookState get currentState => state;

  @override
  void dispose() {
    _timer?.cancel();
    _tts.stop();
    super.dispose();
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class BatchCookScreen extends StatefulWidget {
  final List<Recipe> recipes;
  const BatchCookScreen({super.key, required this.recipes});

  @override
  State<BatchCookScreen> createState() => _BatchCookScreenState();
}

class _BatchCookScreenState extends State<BatchCookScreen> {
  late final _BatchNotifier _notifier;
  late _BatchCookState _s;
  late void Function() _removeListener;
  final _timelineCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _notifier = _BatchNotifier(widget.recipes);
    _s = _notifier.currentState;
    _removeListener = _notifier.addListener(
      (s) {
        if (!mounted) return;
        final oldIdx = _s.currentIndex;
        setState(() => _s = s);
        if (s.currentIndex != oldIdx) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_timelineCtrl.hasClients && _timelineCtrl.position.hasContentDimensions) {
              _timelineCtrl.animateTo(
                (s.currentIndex * 72.0).clamp(0.0, _timelineCtrl.position.maxScrollExtent),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
      },
      fireImmediately: false,
    );
  }

  @override
  void dispose() {
    _removeListener();
    _notifier.dispose();
    _timelineCtrl.dispose();
    super.dispose();
  }

  String _fmt(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        title: const Text('Batch Cooking 🍳', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(_fmt(_s.elapsedSeconds), style: const TextStyle(color: AppColors.textDarkSecondary, fontSize: 14)),
            ),
          ),
        ],
      ),
      body: _s.loading ? _buildLoading() : _buildBody(),
    );
  }

  Widget _buildLoading() => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text('Optimisation de la session...', style: TextStyle(color: AppColors.textDarkSecondary, fontSize: 14)),
            SizedBox(height: 6),
            Text('L\'IA organise vos recettes en parallèle', style: TextStyle(color: AppColors.textDarkSecondary, fontSize: 12)),
          ],
        ),
      );

  Widget _buildBody() {
    final step = _s.steps.elementAtOrNull(_s.currentIndex);
    if (step == null) return _buildDone();

    final isLast = _s.currentIndex == _s.steps.length - 1;
    return SafeArea(
      child: Column(
        children: [
          _buildRecipeBar(),
          _buildStepHeader(step),
          Expanded(child: _buildStepCard(step)),
          _buildNavigation(isLast),
          _buildTimeline(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildRecipeBar() => SizedBox(
        height: 44,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: widget.recipes.length,
          itemBuilder: (_, i) {
            final recipe = widget.recipes[i];
            final color = _recipeColors[i.clamp(0, _recipeColors.length - 1)];
            final doneCount = _s.steps
                .take(_s.currentIndex + 1)
                .where((s) => s.recipeId == recipe.id)
                .length;
            final totalCount = _s.steps.where((s) => s.recipeId == recipe.id).length;
            final pct = totalCount > 0 ? doneCount / totalCount : 0.0;

            return Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(value: pct, strokeWidth: 2.5, color: color, backgroundColor: Colors.white12),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    recipe.title,
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
      );

  Widget _buildStepHeader(BatchStep step) {
    final color = _colorFor(step.recipeId, widget.recipes);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
            child: Text(
              '${step.recipeTitle} · ${_s.currentIndex + 1}/${_s.steps.length}',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(20)),
            child: Text('~${step.durationMinutes} min', style: const TextStyle(color: AppColors.textDarkSecondary, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(BatchStep step) {
    final color = _colorFor(step.recipeId, widget.recipes);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (step.isParallel)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.purple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.purple.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.call_split, size: 13, color: AppColors.purple),
                        SizedBox(width: 6),
                        Text('⚡ En parallèle avec une autre recette', style: TextStyle(color: AppColors.purple, fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              Text(step.description, style: const TextStyle(color: AppColors.textDark, fontSize: 18, height: 1.65, fontWeight: FontWeight.w400)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigation(bool isLast) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _navBtn(Icons.chevron_left, 'Préc.', true, _s.currentIndex > 0, () => _notifier.goTo(_s.currentIndex - 1)),
            GestureDetector(
              onTap: _notifier.toggleSpeak,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _s.isSpeaking ? AppColors.primary : AppColors.darkCard,
                  shape: BoxShape.circle,
                  border: Border.all(color: _s.isSpeaking ? AppColors.primary : AppColors.darkBorder, width: 2),
                ),
                child: Icon(_s.isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded, color: _s.isSpeaking ? Colors.white : AppColors.primary, size: 28),
              ),
            ),
            isLast
                ? GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(14)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Terminé ! 🎉', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                        ],
                      ),
                    ),
                  )
                : _navBtn(Icons.chevron_right, 'Suiv.', false, _s.currentIndex < _s.steps.length - 1, () => _notifier.goTo(_s.currentIndex + 1)),
          ],
        ),
      );

  Widget _navBtn(IconData icon, String label, bool isLeft, bool enabled, VoidCallback onTap) {
    final color = enabled ? AppColors.textDark : AppColors.darkBorder;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: enabled ? AppColors.darkCard : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: enabled ? AppColors.darkBorder : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLeft) Icon(icon, color: color, size: 20),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500, fontSize: 14)),
            if (!isLeft) Icon(icon, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline() => SizedBox(
        height: 52,
        child: ListView.builder(
          controller: _timelineCtrl,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _s.steps.length,
          itemBuilder: (_, i) {
            final isCurrent = i == _s.currentIndex;
            final step = _s.steps[i];
            final color = _colorFor(step.recipeId, widget.recipes);
            return GestureDetector(
              onTap: () => _notifier.goTo(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isCurrent ? color : AppColors.darkCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isCurrent ? color : color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    color: isCurrent ? Colors.white : color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          },
        ),
      );

  Widget _buildDone() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text('Session terminée !', style: TextStyle(color: AppColors.textDark, fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('${widget.recipes.length} recettes cuisinées', style: const TextStyle(color: AppColors.textDarkSecondary, fontSize: 15)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.pop(),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('Retour'),
            ),
          ],
        ),
      );
}
