import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/cooking/cooking_screen.dart';
import '../../features/cooking/cook_mode_screen.dart';
import '../../features/leftover/leftover_brain_screen.dart';
import '../../features/skill_tree/skill_tree_screen.dart';
import '../../features/journal/journal_screen.dart';
import '../../features/batch/batch_select_screen.dart';
import '../../features/batch/batch_cook_screen.dart';
import '../../features/plan/plan_screen.dart';
import '../../features/shopping/shopping_screen.dart';
import '../../features/fridge/fridge_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/family_profiles_screen.dart';
import '../../features/challenge/challenge_screen.dart';
import '../../features/premium/premium_screen.dart';
import '../../features/cook_together/cook_together_create_screen.dart';
import '../../features/cook_together/cook_together_join_screen.dart';
import '../../features/cook_together/cook_together_session_screen.dart';
import '../../features/recipe/recipe_detail_screen.dart';
import '../../features/scanner/barcode_scanner_screen.dart';
import '../../features/stats/stats_screen.dart';
import '../../features/fridge/fridge_plan_screen.dart';
import '../../features/search/ingredient_search_screen.dart';
import '../../features/favorites/favorites_screen.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/models/recipe.dart';
import '../shell/main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final isOnboarded = ref.watch(onboardedProvider);

  return GoRouter(
    initialLocation: isOnboarded ? '/home' : '/onboarding',
    redirect: (context, state) {
      final onboarded = ref.read(onboardedProvider);
      if (!onboarded && state.matchedLocation != '/onboarding') return '/onboarding';
      if (onboarded && state.matchedLocation == '/onboarding') return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/cook', builder: (_, __) => const CookingScreen()),
          GoRoute(path: '/plan', builder: (_, __) => const PlanScreen()),
          GoRoute(path: '/shopping', builder: (_, __) => const ShoppingScreen()),
          GoRoute(path: '/fridge', builder: (_, __) => const FridgeScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/recipe/:id',
        builder: (context, state) {
          final recipe = state.extra as Recipe?;
          return RecipeDetailScreen(recipe: recipe, id: state.pathParameters['id']!);
        },
      ),
      GoRoute(
        path: '/cook-mode',
        builder: (context, state) {
          final recipe = state.extra as Recipe;
          return CookModeScreen(recipe: recipe);
        },
      ),
      GoRoute(
        path: '/leftover',
        builder: (context, state) {
          final recipe = state.extra as Recipe;
          return LeftoverBrainScreen(recipe: recipe);
        },
      ),
      GoRoute(
        path: '/skill-tree',
        builder: (_, __) => const SkillTreeScreen(),
      ),
      GoRoute(
        path: '/journal',
        builder: (context, state) => JournalScreen(prefillRecipe: state.extra as Recipe?),
      ),
      GoRoute(
        path: '/family-profiles',
        builder: (_, __) => const FamilyProfilesScreen(),
      ),
      GoRoute(
        path: '/challenge',
        builder: (_, __) => const ChallengeScreen(),
      ),
      GoRoute(
        path: '/premium',
        builder: (_, __) => const PremiumScreen(),
      ),
      GoRoute(
        path: '/cook-together-create',
        builder: (context, state) => CookTogetherCreateScreen(recipe: state.extra as Recipe),
      ),
      GoRoute(
        path: '/cook-together-join',
        builder: (_, __) => const CookTogetherJoinScreen(),
      ),
      GoRoute(
        path: '/cook-together-session',
        builder: (context, state) => CookTogetherSessionScreen(args: state.extra as CookTogetherArgs),
      ),
      GoRoute(
        path: '/scanner',
        builder: (_, __) => const BarcodeScannerScreen(),
      ),
      GoRoute(
        path: '/stats',
        builder: (_, __) => const StatsScreen(),
      ),
      GoRoute(
        path: '/fridge-plan',
        builder: (_, __) => const FridgePlanScreen(),
      ),
      GoRoute(
        path: '/ingredient-search',
        builder: (_, __) => const IngredientSearchScreen(),
      ),
      GoRoute(
        path: '/batch-select',
        builder: (_, __) => const BatchSelectScreen(),
      ),
      GoRoute(
        path: '/favorites',
        builder: (_, __) => const FavoritesScreen(),
      ),
      GoRoute(
        path: '/batch-cook',
        builder: (context, state) => BatchCookScreen(recipes: state.extra as List<Recipe>),
      ),
    ],
  );
});
