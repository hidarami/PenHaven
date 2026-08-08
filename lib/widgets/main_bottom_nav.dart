import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../providers/atmosphere_state.dart';

class MainBottomNav extends StatelessWidget {
  final int currentIndex;
  final bool showSanctuary;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onAddPressed;

  const MainBottomNav({
    super.key,
    required this.currentIndex,
    required this.showSanctuary,
    required this.onTabSelected,
    required this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final accent = context.watch<AtmosphereState>().accentColor;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    final items = <_NavItem>[
      const _NavItem(icon: Icons.home_rounded, label: 'Home'),
      const _NavItem(icon: Icons.menu_book_rounded, label: 'Library'),
      if (showSanctuary)
        const _NavItem(icon: Icons.nightlight_rounded, label: 'Sanctuary'),
      const _NavItem(icon: Icons.person_rounded, label: 'Profile'),
    ];

    final splitAt = (items.length / 2).ceil();

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad + 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: (dark ? Colors.black : Colors.white).withOpacity(0.35),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: List.generate(items.length + 1, (i) {
                if (i == splitAt) {
                  return _CenterAddButton(accent: accent, onTap: onAddPressed);
                }
                final itemIndex = i < splitAt ? i : i - 1;
                final item = items[itemIndex];
                final selected = itemIndex == currentIndex;
                return Expanded(
                  child: _NavButton(
                    icon: item.icon,
                    label: item.label,
                    selected: selected,
                    accent: accent,
                    dark: dark,
                    onTap: () => onTabSelected(itemIndex),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color accent;
  final bool dark;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accent,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inactive = (dark ? Colors.white : Colors.black).withOpacity(0.45);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: selected ? accent : inactive),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: selected ? 5 : 0,
            height: 5,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}

class _CenterAddButton extends StatelessWidget {
  final Color accent;
  final VoidCallback onTap;
  const _CenterAddButton({required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.5),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
      ),
    );
  }
}