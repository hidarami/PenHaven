import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../data/entry_dao.dart';
import '../../models/entry.dart';
import '../../providers/app_state.dart';
import '../../providers/atmosphere_state.dart';
import '../../theme/app_colors.dart';
import '../entry_read/entry_read_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH SCREEN
// Full-text search across all non-deleted entries.
// Swipe left-to-right to exit (spec rule — no back button).
// ─────────────────────────────────────────────────────────────────────────────

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<Entry> _allEntries = [];
  List<_SearchResult> _results = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadEntries();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    final entries = await EntryDao.instance.getAll();
    if (mounted) setState(() { _allEntries = entries; _loading = false; });
  }

  void _onQueryChanged(String q) {
    final query = q.toLowerCase().trim();
    setState(() {
      _query = query;
      if (query.isEmpty) { _results = []; return; }
      _results = _allEntries
          .where((e) =>
              e.title.toLowerCase().contains(query) ||
              e.content.toLowerCase().contains(query) ||
              (e.blocksJson?.toLowerCase().contains(query) ?? false))
          .map((e) => _SearchResult(entry: e, query: query))
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
              // ── Search bar ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(Icons.chevron_left_rounded, size: 28, color: mutedColor),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: dark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          onChanged: _onQueryChanged,
                          style: GoogleFonts.inter(fontSize: 15, color: textColor),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            hintText: 'Search your entries...',
                            hintStyle: GoogleFonts.inter(fontSize: 15, color: mutedColor),
                            prefixIcon: Icon(Icons.search_rounded, size: 18, color: mutedColor),
                            suffixIcon: _query.isNotEmpty
                                ? GestureDetector(
                                    onTap: () { _controller.clear(); _onQueryChanged(''); },
                                    child: Icon(Icons.close_rounded, size: 16, color: mutedColor),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Results ───────────────────────────────────────────────────
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _query.isEmpty
                        ? _SearchHint(mutedColor: mutedColor)
                        : _results.isEmpty
                            ? _NoResults(query: _query, mutedColor: mutedColor)
                            : ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 48),
                                itemCount: _results.length,
                                itemBuilder: (ctx, i) => _ResultTile(
                                  result: _results[i],
                                  textColor: textColor,
                                  mutedColor: mutedColor,
                                  isDark: dark,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => EntryReadScreen(entry: _results[i].entry)),
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

// ── Search result model ───────────────────────────────────────────────────────

class _SearchResult {
  final Entry entry;
  final String query;

  _SearchResult({required this.entry, required this.query});

  String get snippet {
    final text = entry.content;
    if (text.isEmpty) return '';
    final lower = text.toLowerCase();
    final idx = lower.indexOf(query);
    if (idx == -1) return entry.preview(120);
    final start = (idx - 40).clamp(0, text.length);
    final end = (idx + query.length + 80).clamp(0, text.length);
    return '${start > 0 ? '…' : ''}${text.substring(start, end)}${end < text.length ? '…' : ''}';
  }
}

class _ResultTile extends StatelessWidget {
  final _SearchResult result;
  final Color textColor;
  final Color mutedColor;
  final bool isDark;
  final VoidCallback onTap;

  const _ResultTile({
    required this.result,
    required this.textColor,
    required this.mutedColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.entry.title.isEmpty ? 'Untitled' : result.entry.title,
              style: GoogleFonts.crimsonPro(fontSize: 18, fontWeight: FontWeight.w700, color: textColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (result.snippet.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                result.snippet,
                style: GoogleFonts.inter(fontSize: 13, color: mutedColor, height: 1.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 6),
            Text(
              DateFormat('MMM d, yyyy').format(result.entry.createdAt),
              style: GoogleFonts.inter(fontSize: 11, color: mutedColor.withOpacity(0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchHint extends StatelessWidget {
  final Color mutedColor;
  const _SearchHint({required this.mutedColor});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.search_rounded, size: 52, color: mutedColor.withOpacity(0.25)),
        const SizedBox(height: 14),
        Text('Search your entries.', style: GoogleFonts.crimsonPro(
          fontSize: 18, fontStyle: FontStyle.italic, color: mutedColor.withOpacity(0.55),
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
        style: GoogleFonts.crimsonPro(fontSize: 18, fontStyle: FontStyle.italic, color: mutedColor.withOpacity(0.55), height: 1.6),
      ),
    ),
  );
}