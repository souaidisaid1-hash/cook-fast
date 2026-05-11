import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/journal_entry.dart';
import '../../shared/models/recipe.dart';
import '../../shared/providers/app_providers.dart';

class JournalScreen extends ConsumerStatefulWidget {
  final Recipe? prefillRecipe;
  const JournalScreen({super.key, this.prefillRecipe});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.prefillRecipe != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openAddSheet(widget.prefillRecipe));
    }
  }

  void _openAddSheet([Recipe? recipe]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEntrySheet(recipe: recipe),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final entries = ref.watch(journalProvider);
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
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.yellow]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text('Mon Journal 📔', style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddSheet(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: entries.isEmpty ? _buildEmpty(isDark) : _buildList(entries, isDark),
    );
  }

  Widget _buildEmpty(bool isDark) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.15), AppColors.yellow.withValues(alpha: 0.08)]),
                shape: BoxShape.circle,
              ),
              child: const Center(child: Text('📔', style: TextStyle(fontSize: 40))),
            ),
            const SizedBox(height: 20),
            Text('Aucune entrée', style: TextStyle(color: isDark ? AppColors.textDark : AppColors.textLight, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Documentez vos créations\naprès chaque session de cuisine.',
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => _openAddSheet(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.yellow]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Première entrée', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildList(List<JournalEntry> entries, bool isDark) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: entries.length,
        itemBuilder: (_, i) => _JournalCard(
          entry: entries[i],
          isDark: isDark,
          onDelete: () => ref.read(journalProvider.notifier).remove(entries[i].id),
          onShare: () => _share(entries[i]),
        ),
      );

  void _share(JournalEntry entry) {
    final stars = List.filled(entry.rating, '⭐').join();
    final text = '🍽️ J\'ai cuisiné ${entry.recipeTitle} !\n'
        '${stars.isNotEmpty ? '$stars\n' : ''}'
        '${entry.notes.isNotEmpty ? '\n"${entry.notes}"\n' : ''}'
        '\n📅 ${_fmtDate(entry.cookedAt)}'
        '\n\nCuisiné avec CookFast 👨‍🍳';
    if (entry.photoPath != null) {
      Share.shareXFiles([XFile(entry.photoPath!)], text: text);
    } else {
      Share.share(text);
    }
  }
}

// ─── Card ─────────────────────────────────────────────────────────────────────

class _JournalCard extends StatelessWidget {
  final JournalEntry entry;
  final bool isDark;
  final VoidCallback onDelete;
  final VoidCallback onShare;

  const _JournalCard({required this.entry, required this.isDark, required this.onDelete, required this.onShare});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade800,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo or placeholder
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: entry.photoPath != null
                  ? Image.file(
                      File(entry.photoPath!),
                      width: 90,
                      height: 110,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 90,
                      height: 110,
                      color: AppColors.darkCard,
                      child: const Center(child: Text('🍽️', style: TextStyle(fontSize: 32))),
                    ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.recipeTitle,
                      style: const TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _fmtDate(entry.cookedAt),
                      style: const TextStyle(color: AppColors.textDarkSecondary, fontSize: 12),
                    ),
                    if (entry.rating > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        List.filled(entry.rating, '⭐').join(),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                    if (entry.notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        entry.notes,
                        style: const TextStyle(color: AppColors.textDarkSecondary, fontSize: 12, height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Share button
            IconButton(
              onPressed: onShare,
              icon: const Icon(Icons.share_outlined, size: 18, color: AppColors.textDarkSecondary),
              padding: const EdgeInsets.all(8),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Add entry sheet ──────────────────────────────────────────────────────────

class _AddEntrySheet extends ConsumerStatefulWidget {
  final Recipe? recipe;
  const _AddEntrySheet({this.recipe});

  @override
  ConsumerState<_AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends ConsumerState<_AddEntrySheet> {
  late final TextEditingController _titleCtrl;
  final TextEditingController _notesCtrl = TextEditingController();
  int _rating = 0;
  String? _photoPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.recipe?.title ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 80, maxWidth: 1200);
    if (file != null) setState(() => _photoPath = file.path);
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final entry = JournalEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      recipeTitle: _titleCtrl.text.trim(),
      category: widget.recipe?.category,
      cookedAt: DateTime.now(),
      photoPath: _photoPath,
      rating: _rating,
      notes: _notesCtrl.text.trim(),
    );
    ref.read(journalProvider.notifier).add(entry);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.darkBorder, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Nouvelle entrée', style: TextStyle(color: AppColors.textDark, fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  // Recipe name
                  TextField(
                    controller: _titleCtrl,
                    style: const TextStyle(color: AppColors.textDark),
                    decoration: InputDecoration(
                      hintText: 'Nom de la recette',
                      filled: true,
                      fillColor: AppColors.darkCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Photo picker
                  _buildPhotoSection(),
                  const SizedBox(height: 16),

                  // Rating
                  _buildRating(),
                  const SizedBox(height: 16),

                  // Notes
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 4,
                    style: const TextStyle(color: AppColors.textDark),
                    decoration: InputDecoration(
                      hintText: 'Tes notes (goût, texture, à améliorer...)',
                      filled: true,
                      fillColor: AppColors.darkCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Enregistrer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    if (_photoPath != null) {
      return Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(File(_photoPath!), height: 180, width: double.infinity, fit: BoxFit.cover),
          ),
          GestureDetector(
            onTap: () => setState(() => _photoPath = null),
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _photoBtn(Icons.camera_alt_outlined, 'Caméra', () => _pickPhoto(ImageSource.camera)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _photoBtn(Icons.photo_library_outlined, 'Galerie', () => _pickPhoto(ImageSource.gallery)),
        ),
      ],
    );
  }

  Widget _photoBtn(IconData icon, String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(color: AppColors.textDarkSecondary, fontSize: 12)),
            ],
          ),
        ),
      );

  Widget _buildRating() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Note', style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (i) {
              final filled = i < _rating;
              return GestureDetector(
                onTap: () => setState(() => _rating = i + 1),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: filled ? AppColors.yellow : AppColors.textDarkSecondary,
                    size: 36,
                  ),
                ),
              );
            }),
          ),
        ],
      );
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _fmtDate(DateTime dt) {
  const months = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}
