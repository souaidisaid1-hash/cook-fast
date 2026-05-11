import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/family_member.dart';
import '../models/fridge_item.dart';
import '../models/journal_entry.dart';
import '../models/recipe.dart';
import '../models/user_profile.dart';
import '../models/shopping_item.dart';

// ─── Language ────────────────────────────────────────────────────────────────

final langProvider = StateNotifierProvider<LangNotifier, String>((ref) {
  return LangNotifier();
});

class LangNotifier extends StateNotifier<String> {
  static const _boxKey = 'appLang';

  LangNotifier() : super('fr') {
    _load();
  }

  void _load() {
    final box = Hive.box('settings');
    state = box.get(_boxKey, defaultValue: 'fr') as String;
  }

  void set(String lang) {
    state = lang;
    Hive.box('settings').put(_boxKey, lang);
  }
}

// ─── Theme ───────────────────────────────────────────────────────────────────

final themeProvider = StateNotifierProvider<ThemeNotifier, bool>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<bool> {
  static const _boxKey = 'isDark';

  ThemeNotifier() : super(false) {
    _load();
  }

  void _load() {
    final box = Hive.box('settings');
    state = box.get(_boxKey, defaultValue: true) as bool;
  }

  void toggle() {
    state = !state;
    Hive.box('settings').put(_boxKey, state);
  }
}

// ─── Onboarding ──────────────────────────────────────────────────────────────

final onboardedProvider = StateNotifierProvider<OnboardedNotifier, bool>((ref) {
  return OnboardedNotifier();
});

class OnboardedNotifier extends StateNotifier<bool> {
  OnboardedNotifier() : super(false) {
    final box = Hive.box('settings');
    state = box.get('hasOnboarded', defaultValue: false) as bool;
  }

  void complete() {
    state = true;
    Hive.box('settings').put('hasOnboarded', true);
  }

  void reset() {
    state = false;
    Hive.box('settings').put('hasOnboarded', false);
  }
}

// ─── User Profile ─────────────────────────────────────────────────────────────

final userProfileProvider = StateNotifierProvider<UserProfileNotifier, UserProfile>((ref) {
  return UserProfileNotifier();
});

class UserProfileNotifier extends StateNotifier<UserProfile> {
  UserProfileNotifier() : super(const UserProfile()) {
    _load();
  }

  void _load() {
    final box = Hive.box('settings');
    final raw = box.get('userProfile');
    if (raw != null) {
      state = UserProfile.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
    }
  }

  void save(UserProfile profile) {
    state = profile;
    Hive.box('settings').put('userProfile', jsonEncode(profile.toJson()));
  }
}

// ─── Favorites ───────────────────────────────────────────────────────────────

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, List<Recipe>>((ref) {
  return FavoritesNotifier();
});

class FavoritesNotifier extends StateNotifier<List<Recipe>> {
  FavoritesNotifier() : super([]) {
    _load();
  }

  void _load() {
    final box = Hive.box('favorites');
    final raw = box.get('list');
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      state = list.map((e) => Recipe.fromJson(Map<String, dynamic>.from(e))).toList();
    }
  }

  void _save() {
    Hive.box('favorites').put('list', jsonEncode(state.map((r) => r.toJson()).toList()));
  }

  void toggle(Recipe recipe) {
    final exists = state.any((r) => r.id == recipe.id);
    state = exists ? state.where((r) => r.id != recipe.id).toList() : [...state, recipe];
    _save();
  }

  bool isFavorite(String id) => state.any((r) => r.id == id);
}

// ─── Collections ─────────────────────────────────────────────────────────────

class RecipeCollection {
  final String id;
  final String name;
  final List<String> recipeIds;

  const RecipeCollection({required this.id, required this.name, required this.recipeIds});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'recipeIds': recipeIds};

  factory RecipeCollection.fromJson(Map<String, dynamic> json) => RecipeCollection(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        recipeIds: List<String>.from(json['recipeIds'] ?? []),
      );

  RecipeCollection copyWith({String? name, List<String>? recipeIds}) =>
      RecipeCollection(id: id, name: name ?? this.name, recipeIds: recipeIds ?? this.recipeIds);
}

final collectionsProvider =
    StateNotifierProvider<CollectionsNotifier, List<RecipeCollection>>((ref) {
  return CollectionsNotifier();
});

class CollectionsNotifier extends StateNotifier<List<RecipeCollection>> {
  CollectionsNotifier() : super([]) {
    _load();
  }

  void _load() {
    final box = Hive.box('favorites');
    final raw = box.get('collections');
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      state = list
          .map((e) => RecipeCollection.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
  }

  void _save() {
    Hive.box('favorites')
        .put('collections', jsonEncode(state.map((c) => c.toJson()).toList()));
  }

  void create(String name) {
    state = [
      ...state,
      RecipeCollection(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          recipeIds: [])
    ];
    _save();
  }

  void delete(String id) {
    state = state.where((c) => c.id != id).toList();
    _save();
  }

  void rename(String id, String newName) {
    state = state.map((c) => c.id == id ? c.copyWith(name: newName) : c).toList();
    _save();
  }

  void addRecipe(String collectionId, String recipeId) {
    state = state.map((c) {
      if (c.id != collectionId) return c;
      if (c.recipeIds.contains(recipeId)) return c;
      return c.copyWith(recipeIds: [...c.recipeIds, recipeId]);
    }).toList();
    _save();
  }

  void removeRecipe(String collectionId, String recipeId) {
    state = state.map((c) {
      if (c.id != collectionId) return c;
      return c.copyWith(recipeIds: c.recipeIds.where((id) => id != recipeId).toList());
    }).toList();
    _save();
  }

  bool hasRecipe(String collectionId, String recipeId) =>
      state.any((c) => c.id == collectionId && c.recipeIds.contains(recipeId));
}

// ─── Shopping List ────────────────────────────────────────────────────────────

final shoppingProvider = StateNotifierProvider<ShoppingNotifier, List<ShoppingItem>>((ref) {
  return ShoppingNotifier();
});

class ShoppingNotifier extends StateNotifier<List<ShoppingItem>> {
  ShoppingNotifier() : super([]) {
    _load();
  }

  void _load() {
    final box = Hive.box('shopping');
    final raw = box.get('list');
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      state = list.map((e) => ShoppingItem.fromJson(Map<String, dynamic>.from(e))).toList();
    }
  }

  void _save() {
    Hive.box('shopping').put('list', jsonEncode(state.map((i) => i.toJson()).toList()));
  }

  void add(String name, {String measure = '', String? recipeTitle}) {
    final category = ShoppingItem.categorizeIngredient(name);
    state = [...state, ShoppingItem(name: name, measure: measure, category: category, recipeTitle: recipeTitle)];
    _save();
  }

  void addAll(List<ShoppingItem> items) {
    final merged = [...state];
    for (final item in items) {
      final existing = merged.indexWhere(
          (e) => e.name.toLowerCase() == item.name.toLowerCase());
      if (existing >= 0) {
        // Cumule la mesure si possible
        final old = merged[existing];
        merged[existing] = old.copyWith(
          measure: [old.measure, item.measure].where((s) => s.isNotEmpty).join(' + '),
        );
      } else {
        merged.add(item);
      }
    }
    state = merged;
    _save();
  }

  void toggle(String id) {
    state = state.map((i) => i.id == id ? i.copyWith(isChecked: !i.isChecked) : i).toList();
    _save();
  }

  void remove(String id) {
    state = state.where((i) => i.id != id).toList();
    _save();
  }

  void clearChecked() {
    state = state.where((i) => !i.isChecked).toList();
    _save();
  }

  void clear() {
    state = [];
    _save();
  }

  Map<String, List<ShoppingItem>> get byCategory {
    final map = <String, List<ShoppingItem>>{};
    for (final item in state) {
      map.putIfAbsent(item.category, () => []).add(item);
    }
    return map;
  }

  int get uncheckedCount => state.where((i) => !i.isChecked).length;
}

// ─── Fridge ───────────────────────────────────────────────────────────────────

final fridgeProvider = StateNotifierProvider<FridgeNotifier, List<FridgeItem>>((ref) {
  return FridgeNotifier();
});

final fridgeExpiringCountProvider = Provider<int>((ref) {
  return ref.watch(fridgeProvider).where((i) => i.needsAlert).length;
});

class FridgeNotifier extends StateNotifier<List<FridgeItem>> {
  FridgeNotifier() : super([]) {
    _load();
  }

  void _load() {
    final box = Hive.box('fridge');
    final raw = box.get('ingredients');
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      state = list.map((e) {
        if (e is String) return FridgeItem.simple(e);
        return FridgeItem.fromJson(Map<String, dynamic>.from(e));
      }).toList();
    }
  }

  void _save() {
    Hive.box('fridge').put('ingredients', jsonEncode(state.map((i) => i.toJson()).toList()));
  }

  void add(String name, {DateTime? expiryDate}) {
    if (!state.any((i) => i.name == name.trim())) {
      state = [...state, FridgeItem(name: name.trim(), addedAt: DateTime.now(), expiryDate: expiryDate)];
      _save();
    }
  }

  void addAll(List<String> names) {
    final filtered = names.where((n) => !state.any((i) => i.name == n.trim())).toList();
    state = [...state, ...filtered.map((n) => FridgeItem.simple(n))];
    _save();
  }

  void setExpiry(String name, DateTime? date) {
    state = state
        .map((i) => i.name == name ? i.copyWith(expiryDate: date, clearExpiry: date == null) : i)
        .toList();
    _save();
  }

  void remove(String name) {
    state = state.where((i) => i.name != name).toList();
    _save();
  }

  void clear() {
    state = [];
    _save();
  }
}

// ─── Cooking Journal ─────────────────────────────────────────────────────────

final journalProvider = StateNotifierProvider<JournalNotifier, List<JournalEntry>>((ref) {
  return JournalNotifier();
});

class JournalNotifier extends StateNotifier<List<JournalEntry>> {
  JournalNotifier() : super([]) {
    _load();
  }

  void _load() {
    final box = Hive.box('journal');
    final raw = box.get('entries');
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      state = list.map((e) => JournalEntry.fromJson(Map<String, dynamic>.from(e))).toList();
    }
  }

  void _save() {
    Hive.box('journal').put('entries', jsonEncode(state.map((e) => e.toJson()).toList()));
  }

  void add(JournalEntry entry) {
    state = [entry, ...state];
    _save();
  }

  void update(JournalEntry entry) {
    state = state.map((e) => e.id == entry.id ? entry : e).toList();
    _save();
  }

  void remove(String id) {
    state = state.where((e) => e.id != id).toList();
    _save();
  }
}

// ─── Skill Tree ──────────────────────────────────────────────────────────────

final skillTreeProvider = StateNotifierProvider<SkillTreeNotifier, Map<String, int>>((ref) {
  return SkillTreeNotifier();
});

class SkillTreeNotifier extends StateNotifier<Map<String, int>> {
  SkillTreeNotifier() : super({}) {
    _load();
  }

  void _load() {
    final box = Hive.box('skills');
    final raw = box.get('xp');
    if (raw != null) {
      state = Map<String, int>.from(Map<String, dynamic>.from(jsonDecode(raw)));
    }
  }

  void _save() {
    Hive.box('skills').put('xp', jsonEncode(state));
  }

  void addXp(String branchId, int amount) {
    state = {...state, branchId: (state[branchId] ?? 0) + amount};
    _save();
  }

  int xpFor(String branchId) => state[branchId] ?? 0;

  int get totalXp => state.values.fold(0, (a, b) => a + b);

  // Maps a MealDB category string to a branch ID
  static String branchForCategory(String? category) {
    switch ((category ?? '').toLowerCase()) {
      case 'dessert':
      case 'pasta': return 'pastry';
      case 'beef':
      case 'lamb':
      case 'pork':
      case 'chicken':
      case 'goat': return 'meat';
      case 'seafood': return 'seafood';
      case 'vegetarian': return 'veggie';
      case 'breakfast':
      case 'starter': return 'breakfast';
      default: return 'misc';
    }
  }
}

// ─── Premium ─────────────────────────────────────────────────────────────────

final premiumProvider = StateNotifierProvider<PremiumNotifier, bool>((ref) {
  return PremiumNotifier();
});

class PremiumNotifier extends StateNotifier<bool> {
  PremiumNotifier() : super(false) {
    _load();
  }

  void _load() {
    state = Hive.box('settings').get('isPremium', defaultValue: false) as bool;
  }

  void activate() {
    state = true;
    Hive.box('settings').put('isPremium', true);
  }

  void deactivate() {
    state = false;
    Hive.box('settings').put('isPremium', false);
  }
}

// ─── Family Profiles ─────────────────────────────────────────────────────────

final familyProfilesProvider = StateNotifierProvider<FamilyProfilesNotifier, List<FamilyMember>>((ref) {
  return FamilyProfilesNotifier();
});

class FamilyProfilesNotifier extends StateNotifier<List<FamilyMember>> {
  FamilyProfilesNotifier() : super([]) {
    _load();
  }

  void _load() {
    final box = Hive.box('family');
    final raw = box.get('members');
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      state = list.map((e) => FamilyMember.fromJson(Map<String, dynamic>.from(e))).toList();
    }
  }

  void _save() {
    Hive.box('family').put('members', jsonEncode(state.map((m) => m.toJson()).toList()));
  }

  void add(FamilyMember member) {
    if (state.length >= 5) return;
    state = [...state, member];
    _save();
  }

  void update(FamilyMember updated) {
    state = state.map((m) => m.id == updated.id ? updated : m).toList();
    _save();
  }

  void remove(String id) {
    state = state.where((m) => m.id != id).toList();
    _save();
  }

  void toggleActive(String id) {
    state = state.map((m) => m.id == id ? m.copyWith(isActive: !m.isActive) : m).toList();
    _save();
  }

  List<FamilyMember> get activeMembers => state.where((m) => m.isActive).toList();

  String get combinedDiet {
    final active = activeMembers;
    if (active.any((m) => m.diet == 'vegan')) return 'vegan';
    if (active.any((m) => m.diet == 'vegetarian')) return 'vegetarian';
    if (active.any((m) => m.diet == 'gluten_free')) return 'gluten_free';
    return 'omnivore';
  }

  List<String> get allAllergies =>
      activeMembers.expand((m) => m.allergies).toSet().toList();

  static const _meatCategories = {'beef', 'chicken', 'lamb', 'pork', 'seafood', 'side'};
  static const _veganExcluded = ['milk', 'egg', 'butter', 'cheese', 'cream', 'honey', 'yogurt', 'lard'];
  static const _glutenSources = ['flour', 'wheat', 'barley', 'rye', 'bread', 'pasta', 'soy sauce', 'semolina'];

  bool isCompatible(Recipe recipe) {
    final active = activeMembers;
    if (active.isEmpty) return true;

    final cat = (recipe.category ?? '').toLowerCase();
    final ings = recipe.ingredients.map((i) => i.toLowerCase()).toList();
    final diet = combinedDiet;

    if (diet == 'vegan' || diet == 'vegetarian') {
      if (_meatCategories.contains(cat)) return false;
    }
    if (diet == 'vegan') {
      if (ings.any((i) => _veganExcluded.any((e) => i.contains(e)))) return false;
    }
    if (diet == 'gluten_free') {
      if (ings.any((i) => _glutenSources.any((e) => i.contains(e)))) return false;
    }

    final allergies = allAllergies;
    if (allergies.isNotEmpty) {
      if (ings.any((i) => allergies.any((a) => i.contains(a.toLowerCase())))) return false;
    }
    return true;
  }
}

// ─── Notification Settings ────────────────────────────────────────────────────

class NotifSettings {
  final bool mealReminders;
  final bool challengeReminder;
  final bool timerDone;

  const NotifSettings({
    this.mealReminders = true,
    this.challengeReminder = true,
    this.timerDone = true,
  });

  NotifSettings copyWith({bool? mealReminders, bool? challengeReminder, bool? timerDone}) =>
      NotifSettings(
        mealReminders: mealReminders ?? this.mealReminders,
        challengeReminder: challengeReminder ?? this.challengeReminder,
        timerDone: timerDone ?? this.timerDone,
      );
}

final notifSettingsProvider =
    StateNotifierProvider<NotifSettingsNotifier, NotifSettings>((ref) {
  return NotifSettingsNotifier();
});

class NotifSettingsNotifier extends StateNotifier<NotifSettings> {
  NotifSettingsNotifier() : super(const NotifSettings()) {
    _load();
  }

  void _load() {
    final box = Hive.box('settings');
    state = NotifSettings(
      mealReminders: box.get('notif_meals', defaultValue: true) as bool,
      challengeReminder: box.get('notif_challenge', defaultValue: true) as bool,
      timerDone: box.get('notif_timer', defaultValue: true) as bool,
    );
  }

  void _save() {
    final box = Hive.box('settings');
    box.put('notif_meals', state.mealReminders);
    box.put('notif_challenge', state.challengeReminder);
    box.put('notif_timer', state.timerDone);
  }

  void setMealReminders(bool v) {
    state = state.copyWith(mealReminders: v);
    _save();
  }

  void setChallengeReminder(bool v) {
    state = state.copyWith(challengeReminder: v);
    _save();
  }

  void setTimerDone(bool v) {
    state = state.copyWith(timerDone: v);
    _save();
  }
}

// ─── Weekly Plan ─────────────────────────────────────────────────────────────

typedef DayPlan = Map<String, Recipe?>;
typedef WeekPlan = Map<String, DayPlan>;

final weekPlanProvider = StateNotifierProvider<WeekPlanNotifier, WeekPlan>((ref) {
  return WeekPlanNotifier();
});

class WeekPlanNotifier extends StateNotifier<WeekPlan> {
  static const days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
  static const slots = ['Petit-déj', 'Déjeuner', 'Dîner'];

  WeekPlanNotifier() : super(_emptyPlan()) {
    _load();
  }

  static WeekPlan _emptyPlan() => {
        for (final d in ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'])
          d: {'Petit-déj': null, 'Déjeuner': null, 'Dîner': null}
      };

  void _load() {
    final box = Hive.box('plan');
    final raw = box.get('week');
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        state = decoded.map((day, slots) {
          final slotMap = (slots as Map<String, dynamic>).map((slot, recipeJson) =>
              MapEntry(slot, recipeJson != null ? Recipe.fromJson(Map<String, dynamic>.from(recipeJson)) : null));
          return MapEntry(day, slotMap);
        });
      } catch (_) {
        state = _emptyPlan();
      }
    }
  }

  void _save() {
    final encoded = state.map((day, slots) =>
        MapEntry(day, slots.map((slot, recipe) =>
            MapEntry(slot, recipe?.toJson()))));
    Hive.box('plan').put('week', jsonEncode(encoded));
  }

  void setMeal(String day, String slot, Recipe? recipe) {
    state = {
      ...state,
      day: {...state[day]!, slot: recipe},
    };
    _save();
  }

  void clearDay(String day) {
    state = {
      ...state,
      day: {'Petit-déj': null, 'Déjeuner': null, 'Dîner': null},
    };
    _save();
  }

  void setPlan(WeekPlan plan) {
    state = plan;
    _save();
  }

  void clear() {
    state = _emptyPlan();
    _save();
  }

  List<Recipe> get allRecipes => state.values
      .expand((slots) => slots.values)
      .whereType<Recipe>()
      .toList();
}
