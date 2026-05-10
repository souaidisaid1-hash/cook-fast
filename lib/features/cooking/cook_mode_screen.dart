import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/recipe.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/services/gemini_service.dart';
import '../../shared/services/notification_service.dart';

// ─── State ──────────────────────────────────────────────────────────────────

class _CookState {
  final List<CookingStep> steps;
  final bool loading;
  final int currentIndex;
  final bool isSpeaking;
  final bool isListening;
  final bool sttAvailable;
  final String? sousChefResponse;
  final bool sousChefLoading;
  final int elapsedSeconds;

  const _CookState({
    this.steps = const [],
    this.loading = true,
    this.currentIndex = 0,
    this.isSpeaking = false,
    this.isListening = false,
    this.sttAvailable = false,
    this.sousChefResponse,
    this.sousChefLoading = false,
    this.elapsedSeconds = 0,
  });

  _CookState copyWith({
    List<CookingStep>? steps,
    bool? loading,
    int? currentIndex,
    bool? isSpeaking,
    bool? isListening,
    bool? sttAvailable,
    String? sousChefResponse,
    bool clearSousChef = false,
    bool? sousChefLoading,
    int? elapsedSeconds,
  }) =>
      _CookState(
        steps: steps ?? this.steps,
        loading: loading ?? this.loading,
        currentIndex: currentIndex ?? this.currentIndex,
        isSpeaking: isSpeaking ?? this.isSpeaking,
        isListening: isListening ?? this.isListening,
        sttAvailable: sttAvailable ?? this.sttAvailable,
        sousChefResponse:
            clearSousChef ? null : (sousChefResponse ?? this.sousChefResponse),
        sousChefLoading: sousChefLoading ?? this.sousChefLoading,
        elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      );
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class _CookNotifier extends StateNotifier<_CookState> {
  final Recipe recipe;
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();
  Timer? _timer;

  _CookNotifier(this.recipe) : super(const _CookState()) {
    _init();
  }

  _CookState get currentState => state;

  Future<void> _init() async {
    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.45);
    _tts.setCompletionHandler(() {
      if (mounted) state = state.copyWith(isSpeaking: false);
    });

    final sttOk = await _stt.initialize();
    final steps = await _loadSteps();
    state = state.copyWith(steps: steps, loading: false, sttAvailable: sttOk);
    _startTimer();
  }

  Future<List<CookingStep>> _loadSteps() async {
    if (recipe.steps.isEmpty) return [];
    final gemini = await GeminiService.generateParallelTimeline(
      recipe.title,
      recipe.steps,
    );
    return gemini ?? _fallback();
  }

  List<CookingStep> _fallback() {
    int start = 0;
    return recipe.steps.take(10).toList().asMap().entries.map((e) {
      final dur = _estimate(e.value);
      final step = CookingStep(
        id: e.key + 1,
        description: e.value,
        startMinute: start,
        durationMinutes: dur,
      );
      start += dur;
      return step;
    }).toList();
  }

  int _estimate(String step) {
    final lower = step.toLowerCase();
    final match = RegExp(r'(\d+)\s*min').firstMatch(lower);
    if (match != null) return int.tryParse(match.group(1)!) ?? 5;
    if (lower.contains('heure') || lower.contains('hour')) return 60;
    if (lower.contains('mijoter') || lower.contains('simmer')) return 20;
    if (lower.contains('cuire') || lower.contains('bouillir')) return 15;
    return 5;
  }

  bool _timerNotifSent = false;

  void _startTimer() {
    _timer?.cancel();
    _timerNotifSent = false;
    state = state.copyWith(elapsedSeconds: 0);
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;
        state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
        final step = state.steps.elementAtOrNull(state.currentIndex);
        if (!_timerNotifSent && step != null) {
          final limitSecs = step.durationMinutes * 60;
          if (limitSecs > 0 && state.elapsedSeconds >= limitSecs) {
            _timerNotifSent = true;
            NotificationService.showTimerDone(recipe.title, step.description);
          }
        }
      },
    );
  }

  Future<void> goTo(int index) async {
    if (index < 0 || index >= state.steps.length) return;
    await _tts.stop();
    state = state.copyWith(
      currentIndex: index,
      isSpeaking: false,
      clearSousChef: true,
    );
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
    if (state.isListening) {
      await _stt.stop();
      state = state.copyWith(isListening: false);
    }
    state = state.copyWith(isSpeaking: true);
    await _tts.speak(step.description);
  }

  Future<void> toggleListening() async {
    if (state.isListening) {
      await _stt.stop();
      state = state.copyWith(isListening: false);
      return;
    }
    if (!state.sttAvailable) return;
    if (state.isSpeaking) {
      await _tts.stop();
      state = state.copyWith(isSpeaking: false);
    }
    state = state.copyWith(isListening: true, clearSousChef: true);
    await _stt.listen(
      onResult: (result) {
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          if (mounted) state = state.copyWith(isListening: false);
          _askSousChef(result.recognizedWords);
        }
      },
      localeId: 'fr_FR',
    );
  }

  Future<void> _askSousChef(String question) async {
    final step = state.steps.elementAtOrNull(state.currentIndex);
    state = state.copyWith(sousChefLoading: true, clearSousChef: true);
    final answer = await GeminiService.askSousChef(
      question,
      recipeTitle: recipe.title,
      ingredients: recipe.ingredients,
      currentStep: state.currentIndex + 1,
      currentStepDescription: step?.description ?? '',
    );
    final reply = answer ?? 'Désolé, je n\'ai pas pu répondre.';
    state = state.copyWith(sousChefLoading: false, sousChefResponse: reply);
    state = state.copyWith(isSpeaking: true);
    await _tts.speak(reply);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tts.stop();
    _stt.stop();
    super.dispose();
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class CookModeScreen extends ConsumerStatefulWidget {
  final Recipe recipe;
  const CookModeScreen({super.key, required this.recipe});

  @override
  ConsumerState<CookModeScreen> createState() => _CookModeScreenState();
}

class _CookModeScreenState extends ConsumerState<CookModeScreen> {
  late final _CookNotifier _notifier;
  late _CookState _s;
  late void Function() _removeListener;
  final _timelineCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _notifier = _CookNotifier(widget.recipe);
    _s = _notifier.currentState;
    _removeListener = _notifier.addListener(
      (s) {
        if (!mounted) return;
        final oldIndex = _s.currentIndex;
        setState(() => _s = s);
        if (s.currentIndex != oldIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_timelineCtrl.hasClients &&
                _timelineCtrl.position.hasContentDimensions) {
              _timelineCtrl.animateTo(
                (s.currentIndex * 60.0).clamp(
                  0.0,
                  _timelineCtrl.position.maxScrollExtent,
                ),
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
        title: Text(
          widget.recipe.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textDark, fontSize: 16),
        ),
      ),
      floatingActionButton: _s.loading
          ? null
          : FloatingActionButton(
              onPressed: _notifier.toggleListening,
              backgroundColor:
                  _s.isListening ? Colors.red : AppColors.primary,
              tooltip: _s.sttAvailable
                  ? 'Demander au sous-chef'
                  : 'Micro non disponible',
              child: Icon(
                _s.isListening ? Icons.mic : Icons.mic_none,
                color: Colors.white,
              ),
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
            Text(
              'Analyse de la recette avec l\'IA...',
              style: TextStyle(color: AppColors.textDarkSecondary, fontSize: 14),
            ),
          ],
        ),
      );

  Widget _buildBody() {
    final step = _s.steps.elementAtOrNull(_s.currentIndex);
    if (step == null) {
      return const Center(
        child: Text(
          'Aucune étape disponible',
          style: TextStyle(color: AppColors.textDarkSecondary),
        ),
      );
    }
    final isLastStep = _s.currentIndex == _s.steps.length - 1;
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(step),
          Expanded(child: _buildStepCard(step)),
          _buildNavigation(),
          _buildTimeline(),
          if (_s.isListening || _s.sousChefLoading || _s.sousChefResponse != null)
            _buildSousChefPanel(),
          if (isLastStep) _buildFinishButton(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildHeader(CookingStep step) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Étape ${_s.currentIndex + 1} / ${_s.steps.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const Spacer(),
            _headerChip(
              Icons.timer_outlined,
              _fmt(_s.elapsedSeconds),
              AppColors.textDark,
            ),
            const SizedBox(width: 8),
            _headerChip(
              Icons.schedule,
              '~${step.durationMinutes} min',
              AppColors.textDarkSecondary,
            ),
          ],
        ),
      );

  Widget _headerChip(IconData icon, String label, Color textColor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.textDarkSecondary),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      );

  Widget _buildStepCard(CookingStep step) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (step.parallel) _parallelBadge(step),
                Text(
                  step.description,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 18,
                    height: 1.65,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (step.tip != null && step.tip!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _tipCard(step.tip!),
                ],
              ],
            ),
          ),
        ),
      );

  Widget _parallelBadge(CookingStep step) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.purple.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.purple.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.call_split, size: 13, color: AppColors.purple),
              const SizedBox(width: 6),
              Text(
                step.parallelWith != null
                    ? '⚡ En parallèle avec étape ${step.parallelWith}'
                    : '⚡ Peut être fait en parallèle',
                style: const TextStyle(
                  color: AppColors.purple,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _tipCard(String tip) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('💡', style: TextStyle(fontSize: 15)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tip,
                style: const TextStyle(
                  color: AppColors.primaryLight,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildNavigation() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _navBtn(
              icon: Icons.chevron_left,
              label: 'Préc.',
              isLeft: true,
              enabled: _s.currentIndex > 0,
              onTap: () => _notifier.goTo(_s.currentIndex - 1),
            ),
            GestureDetector(
              onTap: _notifier.toggleSpeak,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _s.isSpeaking ? AppColors.primary : AppColors.darkCard,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _s.isSpeaking ? AppColors.primary : AppColors.darkBorder,
                    width: 2,
                  ),
                ),
                child: Icon(
                  _s.isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
                  color: _s.isSpeaking ? Colors.white : AppColors.primary,
                  size: 28,
                ),
              ),
            ),
            _navBtn(
              icon: Icons.chevron_right,
              label: 'Suiv.',
              isLeft: false,
              enabled: _s.currentIndex < _s.steps.length - 1,
              onTap: () => _notifier.goTo(_s.currentIndex + 1),
            ),
          ],
        ),
      );

  Widget _navBtn({
    required IconData icon,
    required String label,
    required bool isLeft,
    required bool enabled,
    required VoidCallback onTap,
  }) {
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
          itemBuilder: (context, i) {
            final isCurrent = i == _s.currentIndex;
            final step = _s.steps[i];
            return GestureDetector(
              onTap: () => _notifier.goTo(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isCurrent ? AppColors.primary : AppColors.darkCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isCurrent ? AppColors.primary : AppColors.darkBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (step.parallel)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.call_split, size: 10, color: AppColors.purple),
                      ),
                    Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: isCurrent ? Colors.white : AppColors.textDarkSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

  Widget _buildFinishButton() {
    void grantXp() {
      final branch = SkillTreeNotifier.branchForCategory(widget.recipe.category);
      ref.read(skillTreeProvider.notifier).addXp(branch, 25);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                grantXp();
                context.push('/leftover', extra: widget.recipe);
              },
              icon: const Text('🧠', style: TextStyle(fontSize: 15)),
              label: const Text('Restes'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.green,
                side: const BorderSide(color: AppColors.green),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                grantXp();
                context.push('/journal', extra: widget.recipe);
              },
              icon: const Text('📔', style: TextStyle(fontSize: 15)),
              label: const Text('Journal'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSousChefPanel() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('👨‍🍳', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  const Text(
                    'Sous-Chef IA',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  if (_s.sousChefLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                ],
              ),
              if (_s.isListening) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Je vous écoute...',
                      style: TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ],
                ),
              ],
              if (_s.sousChefResponse != null) ...[
                const SizedBox(height: 10),
                Text(
                  _s.sousChefResponse!,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}
