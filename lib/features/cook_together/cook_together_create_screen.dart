import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/recipe.dart';
import '../../shared/services/supabase_service.dart';
import 'cook_together_session_screen.dart';

const _emojis = ['👨‍🍳', '👩‍🍳', '🧑', '👨', '👩', '🧔', '👱', '🧒', '👦', '👧'];

class CookTogetherCreateScreen extends StatefulWidget {
  final Recipe recipe;
  const CookTogetherCreateScreen({super.key, required this.recipe});

  @override
  State<CookTogetherCreateScreen> createState() => _State();
}

class _State extends State<CookTogetherCreateScreen> {
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
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        title: const Text('Cuisiner ensemble 👥', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: _code == null ? _buildForm() : _buildLobby(),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recipe card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Text('🍳', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.recipe.title,
                          style: const TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.w700)),
                      if (widget.recipe.category != null)
                        Text(widget.recipe.category!,
                            style: const TextStyle(color: AppColors.textDarkSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          const Text('Ton avatar', style: TextStyle(color: AppColors.textDarkSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
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
                      color: sel ? AppColors.primary.withValues(alpha: 0.2) : AppColors.darkCard,
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
            style: const TextStyle(color: AppColors.textDark),
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Ton prénom',
              labelStyle: TextStyle(color: AppColors.textDarkSecondary),
              prefixIcon: Icon(Icons.person_outline, color: AppColors.textDarkSecondary),
            ),
          ),
          const SizedBox(height: 8),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _create,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Créer la session', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLobby() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Code display
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
            ),
            child: Column(
              children: [
                const Text('Code de session', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                  _code!,
                  style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 8),
                ),
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

          // Participants live
          Expanded(
            child: StreamBuilder(
              stream: SupabaseService.streamParticipants(_sessionId!),
              builder: (context, snap) {
                final participants = snap.data ?? [];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Participants (${participants.length})',
                        style: const TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.w600)),
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
                              color: AppColors.darkCard,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.darkBorder),
                            ),
                            child: Row(
                              children: [
                                Text(p['emoji'] as String? ?? '🧑', style: const TextStyle(fontSize: 22)),
                                const SizedBox(width: 12),
                                Text(p['name'] as String? ?? '',
                                    style: const TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.w600)),
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

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _start,
              icon: const Text('🍳', style: TextStyle(fontSize: 18)),
              label: const Text('Démarrer la cuisson', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
    );
  }
}
