import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/services/supabase_service.dart';
import 'cook_together_session_screen.dart';

const _emojis = ['👨‍🍳', '👩‍🍳', '🧑', '👨', '👩', '🧔', '👱', '🧒', '👦', '👧'];

class CookTogetherJoinScreen extends StatefulWidget {
  const CookTogetherJoinScreen({super.key});

  @override
  State<CookTogetherJoinScreen> createState() => _State();
}

class _State extends State<CookTogetherJoinScreen> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  String _emoji = '🧑';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (code.length < 6 || name.isEmpty) {
      setState(() => _error = 'Entre un code valide et ton prénom.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final participantId = SupabaseService.generateParticipantId();
      final result = await SupabaseService.joinSession(
        code: code,
        name: name,
        emoji: _emoji,
        participantId: participantId,
      );
      if (result == null) {
        setState(() { _loading = false; _error = 'Session introuvable ou terminée. Vérifie le code.'; });
        return;
      }
      if (!mounted) return;
      context.push('/cook-together-session', extra: CookTogetherArgs(
        sessionId: result.sessionId,
        participantId: participantId,
        participantName: name,
        participantEmoji: _emoji,
        isHost: false,
        recipe: result.recipe,
        code: result.code,
      ));
    } catch (_) {
      setState(() { _loading = false; _error = 'Erreur de connexion. Vérifie ta connexion internet.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final navBar = MediaQuery.of(context).viewPadding.bottom;
    final keyboard = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        title: const Text('Rejoindre une session', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + keyboard + navBar),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.blue.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Text('💡', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Demande le code à l\'hôte de la session et rejoins sa cuisine en temps réel.',
                      style: TextStyle(color: AppColors.textDarkSecondary, fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            const Text('Code de session', style: TextStyle(color: AppColors.textDarkSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: _codeCtrl,
              style: const TextStyle(color: AppColors.textDark, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 6),
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              decoration: InputDecoration(
                counterText: '',
                hintText: 'ABCDEF',
                hintStyle: TextStyle(color: AppColors.darkBorder, fontSize: 24, letterSpacing: 6),
                filled: true,
                fillColor: AppColors.darkCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.darkBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 24),

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

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _join,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Rejoindre la session', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
