import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/published_entry.dart';
import '../../providers/app_state.dart';
import '../../providers/atmosphere_state.dart';
import '../../providers/community_state.dart';
import '../../theme/app_colors.dart';
import 'community_entry_viewer.dart';

class CommunitySearchScreen extends StatefulWidget {
  const CommunitySearchScreen({super.key});

  @override
  State<CommunitySearchScreen> createState() =>
      _CommunitySearchScreenState();
}

class _CommunitySearchScreenState extends State<CommunitySearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<PublishedEntry> _results = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    final query = q.toLowerCase().trim();
    setState(() {
      _query = query;
      if (query.isEmpty) {
        _results = [];
        return;
      }
      final feed = context.read<CommunityState>().feed;
      _results = feed
          .where((e) =>
              e.title.toLowerCase().contains(query) ||
              e.content.toLowerCase().contains(query) ||
              (e.category?.toLowerCase().contains(query) ?? false) ||
              e.authorLabel.toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final bg = context.watch<AtmosphereState>().backgroundFor(dark);
    final textColor = AppColors.readableText(bg);
    final mutedColor = AppColors.readableMuted(bg);

    return GestureDetector(
      onHorizontalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 300) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(Icons.chevron_left_rounded,
                          size: 28, color: mutedColor),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: dark
                              ? Colors.white.withOpacity(0.07)
                              : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          onChanged: _onQueryChanged,
                          style: GoogleFonts.inter(
                              fontSize: 15, color: textColor),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            hintText: 'Search community entries...',
                            hintStyle: GoogleFonts.inter(
                                fontSize: 15, color: mutedColor),
                            prefixIcon: Icon(Icons.search_rounded,
                                size: 18, color: mutedColor),
                            suffixIcon: _query.isNotEmpty
                                ? GestureDetector(
                                    onTap: () {
                                      _controller.clear();
                                      _onQueryChanged('');
                                    },
                                    child: Icon(Icons.close_rounded,
                                        size: 16, color: mutedColor),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Results
              Expanded(
                child: _query.isEmpty
                    ? _Hint(mutedColor: mutedColor)
                    : _results.isEmpty
                        ? _NoResults(
                            query: _query, mutedColor: mutedColor)
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding:
                                const EdgeInsets.fromLTRB(16, 4, 16, 48),
                            itemCount: _results.length,
                            itemBuilder: (ctx, i) => _ResultTile(
                              entry: _results[i],
                              textColor: textColor,
                              mutedColor: mutedColor,
                              isDark: dark,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => CommunityEntryViewer(
                                        entry: _results[i])),
                              ),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final PublishedEntry entry;
  final Color textColor;
  final Color mutedColor;
  final bool isDark;
  final VoidCallback onTap;

  const _ResultTile({
    required this.entry,
    required this.textColor,
    required this.mutedColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = entry.headerImage != null &&
        entry.headerImage!.isNotEmpty &&
        File(entry.headerImage!).existsSync();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.04)
              : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImage) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(entry.headerImage!),
                    width: 54, height: 54, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title.isEmpty ? 'Untitled' : entry.title,
                    style: GoogleFonts.crimsonPro(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: textColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.preview(80),
                    style: GoogleFonts.inter(
                        fontSize: 12, color: mutedColor, height: 1.45),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'by ${entry.authorLabel}  ·  ${DateFormat("MMM d").format(entry.createdAt)}',
                    style: GoogleFonts.inter(
                        fontSize: 10, color: mutedColor.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final Color mutedColor;
  const _Hint({required this.mutedColor});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded,
                size: 52, color: mutedColor.withOpacity(0.25)),
            const SizedBox(height: 14),
            Text('Search community entries.',
                style: GoogleFonts.crimsonPro(
                  fontSize: 18,
                  fontStyle: FontStyle.italic,
                  color: mutedColor.withOpacity(0.55),
                )),
          ],
        ),
      );
}

class _NoResults extends StatelessWidget {
  final String query;
  final Color mutedColor;
  const _NoResults({required this.query, required this.mutedColor});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Nothing found for\n"$query"',
            textAlign: TextAlign.center,
            style: GoogleFonts.crimsonPro(
                fontSize: 18,
                fontStyle: FontStyle.italic,
                color: mutedColor.withOpacity(0.55),
                height: 1.6),
          ),
        ),
      );
}