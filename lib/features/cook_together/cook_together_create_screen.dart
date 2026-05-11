import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/recipe.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/services/supabase_service.dart';
import 'cook_together_session_screen.dart';

const _emojis = ['👨‍🍳', '👩‍🍳', '🧑', '👨', '👩', '🧔', '👱', '🧒', '👦', '👧'];

class CookTogetherCreateScreen extends ConsumerStatefulWidget {
  final Recipe recipe;
  const CookTogetherCreateScreen({super.key, required this.recipe});

  @override
  ConsumerState<CookTogetherCreateScreen> createState() => _State();
}

class _State extends ConsumerState<CookTogetherCreateScreen> {
  final _nameCtrl = TextEditingController();
  String _emoji = '👨‍🍳';
  bool _loading = false;
  String? _error;

  // After creation
  String? _sessionId;
  String? _code;
  String? _participantId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final participantId = SupabaseService.generateParticipantId();
      final result = await SupabaseService.createSession(
        recipe: widget.recipe,
        hostName: name,
        hostEmoji: _emoji,
        participantId: participantId,
      );
      setState(() {
        _sessionId = result.sessionId;
        _code = result.code;
        _participantId = participantId;
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = 'Erreur de connexion. Vérifie ta connexion internet.'; });
    }
  }

  void _start() {
    if (_sessionId == null || _code == null || _participantId == null) return;
    context.push('/cook-together-session', extra: CookTogetherArgs(
      sessionId: _sessionId!,
      participantId: _participantId!,
      participantName: _nameCtrl.text.trim(),
      participantEmoji: _emoji,
      isHost: true,
      recipe: widget.recipe,
      code: _code!,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final bg = isDark ? AppColors.darkBg : const Color(0xFFF5F2EE);
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;

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
                gradient: const LinearGradient(colors: [Color(0xFF4A90D9), AppColors.purple], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text('Cuisiner ensemble 👥', style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
      ),
      body: SafeArea(
        child: _code == null ? _buildForm(isDark, textColor) : _buildLobby(isDark, textColor),
      ),
    );
  }

  Widget _buildForm(bool isDark, Color textColor) {
    final subColor = isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Row(
              children: [
                const Text('🍳', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.recipe.title, style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w700)),
                      if (widget.recipe.category != null)
                        Text(widget.recipe.category!, style: TextStyle(color: subColor, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          Text('Ton avatar', style: TextStyle(color: subColor, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _emojis.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final e = _emojis[i];
                final sel = e == _emoji;
                return GestureDetector(
                  onTap: () => setState(() => _emoji = e),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary.withValues(alpha: 0.2) : (isDark ? AppColors.darkCard : const Color(0xFFF5F2EE)),
                      shape: BoxShape.circle,
                      border: Border.all(color: sel ? AppColors.primary : Colors.transparent, width: 2),
                    ),
                    child: Center(child: Text(e, style: const TextStyle(fontSize: 24))),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _nameCtrl,
            style: TextStyle(color: textColor),
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Ton prénom',
              labelStyle: TextStyle(color: subColor),
              prefixIcon: Icon(Icons.person_outline, color: subColor),
            ),
          ),
          const SizedBox(height: 8),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ),

          const SizedBox(height: 32),

          GestureDetector(
            onTap: _loading ? null : _create,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: _loading ? null : const LinearGradient(colors: [AppColors.primary, AppColors.yellow]),
                color: _loading ? (isDark ? AppColors.darkBorder : AppColors.lightBorder) : null,
                borderRadius: BorderRadius.circular(14),
                boxShadow: _loading ? [] : [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Center(
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Créer la session', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLobby(bool isDark, Color textColor) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B35), Color(0xFF9B59B6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: const Color(0xFFFF6B35).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Column(
              children: [
                const Text('Code de session', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Text(_code!, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 8)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _code!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copié !'), duration: Duration(seconds: 1)),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy, size: 14, color: Colors.white),
                        SizedBox(width: 6),
                        Text('Copier le code', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Expanded(
            child: StreamBuilder(
              stream: SupabaseService.streamParticipants(_sessionId!),
              builder: (context, snap) {
                final participants = snap.data ?? [];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Participants (${participants.length})', style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: participants.length,
                        itemBuilder: (_, i) {
                          final p = participants[i] as Map<String, dynamic>;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkCard : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.05), blurRadius: 8, offset: const Offset(0, 2))],
                            ),
                            child: Row(
                              children: [
                                Text(p['emoji'] as String? ?? '🧑', style: const TextStyle(fontSize: 22)),
                                const SizedBox(width: 12),
                                Text(p['name'] as String? ?? '', style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600)),
                                const Spacer(),
                                const Text('Prêt ✓', style: TextStyle(color: AppColors.green, fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          GestureDetector(
            onTap: _start,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.yellow]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🍳', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Text('Démarrer la cuisson', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
