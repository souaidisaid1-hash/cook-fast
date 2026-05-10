import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../../shared/providers/app_providers.dart';

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = [
    (path: '/home', icon: Icons.home_rounded, label: 'Accueil'),
    (path: '/cook', icon: Icons.restaurant_rounded, label: 'Cuisson'),
    (path: '/plan', icon: Icons.calendar_month_rounded, label: 'Plan'),
    (path: '/shopping', icon: Icons.shopping_cart_rounded, label: 'Courses'),
    (path: '/fridge', icon: Icons.kitchen_rounded, label: 'Frigo'),
    (path: '/profile', icon: Icons.person_rounded, label: 'Profil'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final idx = _tabs.indexWhere((t) => location.startsWith(t.path));
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    final unchecked = ref.watch(shoppingProvider).where((i) => !i.isChecked).length;
    final fridgeAlerts = 0; // TODO: expiry alerts
    final current = _currentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              children: _tabs.asMap().entries.map((entry) {
                final i = entry.key;
                final tab = entry.value;
                final isSelected = current == i;
                final badge = i == 3 ? unchecked : (i == 4 ? fridgeAlerts : 0);

                return Expanded(
                  child: GestureDetector(
                    onTap: () => context.go(tab.path),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  tab.icon,
                                  size: 22,
                                  color: isSelected
                                      ? AppColors.primary
                                      : (isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary),
                                ),
                              ),
                              if (badge > 0)
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      badge > 9 ? '9+' : '$badge',
                                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tab.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
