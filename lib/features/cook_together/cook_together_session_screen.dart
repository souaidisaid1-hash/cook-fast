import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/recipe.dart';
import '../../shared/services/supabase_service.dart';

// ─── Args ─────────────────────────────────────────────────────────────────────

class CookTogetherArgs {
  final String sessionId;
  final String participantId;
  final String participantName;
  final String participantEmoji;
  final bool isHost;
  final Recipe recipe;
  final String code;

  const CookTogetherArgs({
    required this.sessionId,
    required this.participantId,
    required this.participantName,
    required this.participantEmoji,
    required this.isHost,
    required this.recipe,
    required this.code,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class CookTogetherSessionScreen extends StatefulWidget {
  final CookTogetherArgs args;
  const CookTogetherSessionScreen({super.key, required this.args});

  @override
  State<CookTogetherSessionScreen> createState() => _State();
}

class _State extends State<CookTogetherSessionScreen> {
  int _currentStep = 0;
  List<Map<String, dynamic>> _lastReactions = [];
  _FloatingReaction? _activeReaction;
  Timer? _reactionTimer;
  StreamSubscription<List<Map<String, dynamic>>>? _reactionSub;

  @override
  void initState() {
    super.initState();
    _reactionSub = SupabaseService.streamReactions(widget.args.sessionId).listen((reactions) {
      if (reactions.length > _lastReactions.length && mounted) {
        final newest = reactions.last;
        _showReaction(
          newest['participant_name'] as String? ?? '',
          newest['emoji'] as String? ?? '👍',
        );
      }
      _lastReactions = reactions;
    });
  }

  @override
  void dispose() {
    _reactionTimer?.cancel();
    _reactionSub?.cancel();
    if (widget.args.isHost) {
      SupabaseService.endSession(widget.args.sessionId);
    } else {
      SupabaseService.leaveSession(widget.args.sessionId, widget.args.participantId);
    }
    super.dispose();
  }

  void _showReaction(String name, String emoji) {
    _reactionTimer?.cancel();
    setState(() => _activeReaction = _FloatingReaction(name: name, emoji: emoji));
    _reactionTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _activeReaction = null);
    });
  }

  Future<void> _goTo(int index) async {
    if (index < 0 || index >= widget.args.recipe.steps.length) return;
    setState(() => _currentStep = index);
    await SupabaseService.updateStep(widget.args.sessionId, widget.args.participantId, index);
  }

  Future<void> _sendReaction(String emoji) async {
    await SupabaseService.sendReaction(widget.args.sessionId, widget.args.participantName, emoji);
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.args.recipe;
    final steps = recipe.steps;
    final isLast = _currentStep == steps.length - 1;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 4, height: 20,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF4A90D9), AppColors.purple], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe.title,
                      style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Row(
                    children: [
                      const Text('👥 Code : ', style: TextStyle(color: AppColors.textDarkSecondary, fontSize: 11)),
                      Text(widget.args.code,
                          style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildParticipantsBar(),
            if (_activeReaction != null) _buildReactionBubble(_activeReaction!),
            _buildStepHeader(steps),
            Expanded(child: _buildStepCard(steps[_currentStep])),
            _buildNavigation(isLast),
            _buildReactionBar(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsBar() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.streamParticipants(widget.args.sessionId),
      builder: (context, snap) {
        final participants = snap.data ?? [];
        final total = widget.args.recipe.steps.length;
        return SizedBox(
          height: 56,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: participants.length,
            itemBuilder: (_, i) {
              final p = participants[i];
              final isSelf = p['participant_id'] == widget.args.participantId;
              final step = (p['current_step'] as int? ?? 0) + 1;
              return Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelf ? AppColors.primary.withValues(alpha: 0.2) : AppColors.darkCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelf ? AppColors.primary : AppColors.darkBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(p['emoji'] as String? ?? '🧑', style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['name'] as String? ?? '',
                            style: TextStyle(
                                color: isSelf ? AppColors.primary : AppColors.textDark,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                        Text('$step/$total',
                            style: const TextStyle(color: AppColors.textDarkSecondary, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildReactionBubble(_FloatingReaction r) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(r.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(r.name, style: const TextStyle(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildStepHeader(List<String> steps) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          Text('Étape ${_currentStep + 1} / ${steps.length}',
              style: const TextStyle(color: AppColors.textDarkSecondary, fontSize: 13)),
          const Spacer(),
          SizedBox(
            width: 80,
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / steps.length,
              backgroundColor: AppColors.darkBorder,
              color: AppColors.primary,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(String step) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Text(step,
              style: const TextStyle(color: AppColors.textDark, fontSize: 17, height: 1.65)),
        ),
      ),
    );
  }

  Widget _buildNavigation(bool isLast) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _navBtn(Icons.chevron_left, 'Préc.', true, _currentStep > 0, () => _goTo(_currentStep - 1)),
          if (isLast)
            GestureDetector(
              onTap: () async {
                if (widget.args.isHost) await SupabaseService.endSession(widget.args.sessionId);
                if (mounted) context.pop();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(14)),
                child: const Text('Terminer 🎉',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            )
          else
            _navBtn(Icons.chevron_right, 'Suiv.', false,
                _currentStep < widget.args.recipe.steps.length - 1, () => _goTo(_currentStep + 1)),
        ],
      ),
    );
  }

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

  Widget _buildReactionBar() {
    const emojis = ['👍', '😮', '😂', '🔥', '👨‍🍳'];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: emojis
            .map((e) => GestureDetector(
                  onTap: () => _sendReaction(e),
                  child: Container(
                    width: 52,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.darkCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.darkBorder),
                    ),
                    child: Center(child: Text(e, style: const TextStyle(fontSize: 22))),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _FloatingReaction {
  final String name;
  final String emoji;
  _FloatingReaction({required this.name, required this.emoji});
}
