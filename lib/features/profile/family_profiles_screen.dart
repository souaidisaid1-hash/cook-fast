import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/family_member.dart';
import '../../shared/providers/app_providers.dart';

const _emojis = ['👨', '👩', '👦', '👧', '🧑', '👴', '👵', '🧒', '🧔', '👱'];

const _diets = [
  ('omnivore', 'Omnivore', '🍖'),
  ('vegetarian', 'Végétarien', '🥗'),
  ('vegan', 'Vegan', '🌱'),
  ('gluten_free', 'Sans gluten', '🌾'),
];

class FamilyProfilesScreen extends ConsumerWidget {
  const FamilyProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    final members = ref.watch(familyProfilesProvider);
    final notifier = ref.read(familyProfilesProvider.notifier);
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
                gradient: const LinearGradient(
                  colors: [AppColors.blue, Color(0xFF2980B9)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text('Profils Famille 👨‍👩‍👧', style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Text('👨‍👩‍👧', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Les recettes incompatibles avec votre famille seront signalées avec ⚠️',
                    style: TextStyle(color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: members.isEmpty
                ? _buildEmpty(isDark, textColor)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: members.length,
                    itemBuilder: (_, i) => _MemberCard(
                      member: members[i],
                      isDark: isDark,
                      onToggle: () => notifier.toggleActive(members[i].id),
                      onEdit: () => _openSheet(context, ref, existing: members[i]),
                      onDelete: () => notifier.remove(members[i].id),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: members.length < 5
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: GestureDetector(
                  onTap: () => _openSheet(context, ref),
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
                        Icon(Icons.person_add_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Ajouter un membre', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildEmpty(bool isDark, Color textColor) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.blue.withValues(alpha: 0.15), AppColors.primary.withValues(alpha: 0.08)]),
                shape: BoxShape.circle,
              ),
              child: const Center(child: Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 40))),
            ),
            const SizedBox(height: 20),
            Text('Aucun profil famille', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Ajoutez les membres de votre famille\npour filtrer les recettes compatibles.',
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      );

  void _openSheet(BuildContext context, WidgetRef ref, {FamilyMember? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MemberSheet(existing: existing, ref: ref),
    );
  }
}

// ─── Member Card ──────────────────────────────────────────────────────────────

class _MemberCard extends StatelessWidget {
  final FamilyMember member;
  final bool isDark;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MemberCard({
    required this.member,
    required this.isDark,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dietEntry = _diets.firstWhere((d) => d.$1 == member.diet, orElse: () => _diets[0]);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: member.isActive ? 1.0 : 0.5,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: member.isActive ? AppColors.primary.withValues(alpha: 0.3) : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: Text(member.emoji, style: const TextStyle(fontSize: 24))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(member.name, style: TextStyle(color: isDark ? AppColors.textDark : AppColors.textLight, fontSize: 16, fontWeight: FontWeight.w700)),
                          if (member.isChild) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.blue.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('enfant', style: TextStyle(color: AppColors.blue, fontSize: 10, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(dietEntry.$3, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(dietEntry.$2, style: TextStyle(color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: member.isActive,
                  onChanged: (_) => onToggle(),
                  activeThumbColor: AppColors.primary,
                  inactiveThumbColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  inactiveTrackColor: isDark ? AppColors.darkSurface : const Color(0xFFE0DDD8),
                ),
              ],
            ),
            if (member.allergies.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: member.allergies.map((a) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.yellow.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.yellow.withValues(alpha: 0.4)),
                  ),
                  child: Text('⚠️ $a', style: const TextStyle(color: AppColors.yellow, fontSize: 11)),
                )).toList(),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _iconBtn(Icons.edit_outlined, isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary, onEdit),
                const SizedBox(width: 8),
                _iconBtn(Icons.delete_outline, Colors.red.withValues(alpha: 0.7), onDelete),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      );
}

// ─── Add / Edit Sheet ─────────────────────────────────────────────────────────

class _MemberSheet extends StatefulWidget {
  final FamilyMember? existing;
  final WidgetRef ref;

  const _MemberSheet({this.existing, required this.ref});

  @override
  State<_MemberSheet> createState() => _MemberSheetState();
}

class _MemberSheetState extends State<_MemberSheet> {
  late final TextEditingController _nameCtrl;
  late String _emoji;
  late String _diet;
  late bool _isChild;
  late List<String> _allergies;
  final _allergyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final m = widget.existing;
    _nameCtrl = TextEditingController(text: m?.name ?? '');
    _emoji = m?.emoji ?? '🧑';
    _diet = m?.diet ?? 'omnivore';
    _isChild = m?.isChild ?? false;
    _allergies = List<String>.from(m?.allergies ?? []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _allergyCtrl.dispose();
    super.dispose();
  }

  void _addAllergy() {
    final val = _allergyCtrl.text.trim();
    if (val.isEmpty || _allergies.contains(val)) return;
    setState(() => _allergies.add(val));
    _allergyCtrl.clear();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final notifier = widget.ref.read(familyProfilesProvider.notifier);
    if (widget.existing != null) {
      notifier.update(widget.existing!.copyWith(
        name: name,
        emoji: _emoji,
        diet: _diet,
        isChild: _isChild,
        allergies: _allergies,
      ));
    } else {
      notifier.add(FamilyMember(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        emoji: _emoji,
        diet: _diet,
        isChild: _isChild,
        allergies: _allergies,
      ));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.ref.read(themeProvider);
    final sheetBg = isDark ? AppColors.darkCard : Colors.white;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final subColor = isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary;
    final insets = MediaQuery.of(context).viewInsets.bottom;
    final navBar = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + insets + navBar),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(width: 36, height: 4, decoration: BoxDecoration(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            Text(
              widget.existing != null ? 'Modifier le profil' : 'Nouveau membre',
              style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),

            Text('Avatar', style: TextStyle(color: subColor, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _emojis.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final e = _emojis[i];
                  final selected = e == _emoji;
                  return GestureDetector(
                    onTap: () => setState(() => _emoji = e),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary.withValues(alpha: 0.2) : (isDark ? AppColors.darkSurface : const Color(0xFFF5F2EE)),
                        shape: BoxShape.circle,
                        border: Border.all(color: selected ? AppColors.primary : Colors.transparent, width: 2),
                      ),
                      child: Center(child: Text(e, style: const TextStyle(fontSize: 22))),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _nameCtrl,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Prénom',
                labelStyle: TextStyle(color: subColor),
              ),
            ),
            const SizedBox(height: 16),

            Text('Régime alimentaire', style: TextStyle(color: subColor, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _diets.map((d) {
                final selected = _diet == d.$1;
                return GestureDetector(
                  onTap: () => setState(() => _diet = d.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary.withValues(alpha: 0.2) : (isDark ? AppColors.darkSurface : const Color(0xFFF5F2EE)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                    ),
                    child: Text(
                      '${d.$3} ${d.$2}',
                      style: TextStyle(color: selected ? AppColors.primary : subColor, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            GestureDetector(
              onTap: () => setState(() => _isChild = !_isChild),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _isChild ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _isChild ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder), width: 2),
                    ),
                    child: _isChild ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 10),
                  Text('Enfant (moins de 12 ans)', style: TextStyle(color: textColor, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text('Allergies / ingrédients à éviter', style: TextStyle(color: subColor, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _allergyCtrl,
                    style: TextStyle(color: textColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'ex: arachides, lactose...',
                      hintStyle: TextStyle(color: subColor, fontSize: 13),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (_) => _addAllergy(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _addAllergy,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            if (_allergies.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _allergies.map((a) => GestureDetector(
                  onTap: () => setState(() => _allergies.remove(a)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.yellow.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.yellow.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(a, style: const TextStyle(color: AppColors.yellow, fontSize: 12)),
                        const SizedBox(width: 4),
                        const Icon(Icons.close, size: 12, color: AppColors.yellow),
                      ],
                    ),
                  ),
                )).toList(),
              ),
            ],
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _nameCtrl.text.trim().isNotEmpty ? _save : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: _nameCtrl.text.trim().isNotEmpty
                        ? const LinearGradient(colors: [AppColors.primary, AppColors.yellow])
                        : null,
                    color: _nameCtrl.text.trim().isEmpty ? (isDark ? AppColors.darkBorder : AppColors.lightBorder) : null,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _nameCtrl.text.trim().isNotEmpty
                        ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))]
                        : [],
                  ),
                  child: Center(
                    child: Text(
                      widget.existing != null ? 'Enregistrer' : 'Ajouter le membre',
                      style: TextStyle(
                        color: _nameCtrl.text.trim().isNotEmpty ? Colors.white : subColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
