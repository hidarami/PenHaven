import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/entry.dart';
import '../../providers/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/neumorphic_widgets.dart';
import 'entry_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY LIST
// Scrollable list of entry cards with staggered fade-in animation.
// "+ Add Entry" button sits at the bottom of the list.
// ─────────────────────────────────────────────────────────────────────────────

class EntryList extends StatelessWidget {
  final List<Entry> entries;
  final ScrollController? scrollController;
  final ValueChanged<Entry> onTapEntry;
  final VoidCallback onAddEntry;

  const EntryList({
    super.key,
    required this.entries,
    this.scrollController,
    required this.onTapEntry,
    required this.onAddEntry,
  });

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;

    return ListView.builder(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 100),
      // +1 for the Add Entry button at the end
      itemCount: entries.length + 1,
      itemBuilder: (context, index) {
        if (index == entries.length) {
          return _AddEntryButton(onTap: onAddEntry);
        }

        // Staggered entrance: 70ms per item
        return _StaggeredItem(
          delay: Duration(milliseconds: index * 70),
          child: Column(
            children: [
              Divider(
                color: dark ? AppColors.dividerDark : AppColors.dividerLight,
                thickness: 0.5,
                height: 0,
                indent: 24,
                endIndent: 24,
              ),
              EntryCard(
                entry: entries[index],
                index: index,
                onTap: () => onTapEntry(entries[index]),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAGGERED ITEM
// Fades and slides in with a delay for cascade reveal effect.
// ─────────────────────────────────────────────────────────────────────────────

class _StaggeredItem extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _StaggeredItem({required this.child, required this.delay});

  @override
  State<_StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<_StaggeredItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD ENTRY BUTTON
// Neumorphic small button at the bottom of the list.
// ─────────────────────────────────────────────────────────────────────────────

class _AddEntryButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddEntryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Align(
        alignment: Alignment.centerRight,
        child: NeumorphicButton(
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.add, size: 15, color: AppColors.teal),
              SizedBox(width: 6),
              Text(
                'Add Entry',
                style: TextStyle(
                  color: AppColors.teal,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
