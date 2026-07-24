import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/entry_version.dart';
import '../../data/version_dao.dart';
import '../../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VERSION HISTORY SCREEN
// Shows all saved versions of an entry. User can preview and restore.
// ─────────────────────────────────────────────────────────────────────────────

class VersionHistoryScreen extends StatefulWidget {
  final String entryId;
  final bool isDark;
  final void Function(EntryVersion) onRestore;

  const VersionHistoryScreen({
    super.key,
    required this.entryId,
    required this.isDark,
    required this.onRestore,
  });

  @override
  State<VersionHistoryScreen> createState() => _VersionHistoryScreenState();
}

class _VersionHistoryScreenState extends State<VersionHistoryScreen> {
  List<EntryVersion> _versions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final versions =
        await VersionDao.instance.getVersionsForEntry(widget.entryId);
    setState(() {
      _versions = versions;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? AppColors.warmDark : AppColors.warmWhite;
    final textColor = widget.isDark ? AppColors.textDark : AppColors.textLight;
    final mutedColor =
        widget.isDark ? AppColors.mutedDark : AppColors.mutedLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Version History',
          style: GoogleFonts.crimsonPro(
              fontSize: 22, fontWeight: FontWeight.w700, color: textColor),
        ),
        leading: IconButton(
          icon: Icon(Icons.chevron_left_rounded, color: mutedColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _versions.isEmpty
              ? Center(
                  child: Text(
                    'No versions saved yet.',
                    style: GoogleFonts.crimsonPro(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        color: mutedColor),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _versions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final version = _versions[index];
                    return _VersionTile(
                      version: version,
                      isDark: widget.isDark,
                      textColor: textColor,
                      mutedColor: mutedColor,
                      onRestore: () {
                        Navigator.pop(context);
                        widget.onRestore(version);
                      },
                      onLabel: () => _showLabelDialog(context, version),
                    );
                  },
                ),
    );
  }

  Future<void> _showLabelDialog(
      BuildContext context, EntryVersion version) async {
    final ctrl = TextEditingController(text: version.label ?? '');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Label this version'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Before major edit'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await VersionDao.instance
                  .updateLabel(version.id, ctrl.text.trim());
              Navigator.pop(ctx);
              _load();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _VersionTile extends StatelessWidget {
  final EntryVersion version;
  final bool isDark;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onRestore;
  final VoidCallback onLabel;

  const _VersionTile({
    required this.version,
    required this.isDark,
    required this.textColor,
    required this.mutedColor,
    required this.onRestore,
    required this.onLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.03);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (version.label != null && version.label!.isNotEmpty) ...[
                  Text(
                    version.label!,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.aqua),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  version.title.isEmpty ? 'Untitled' : version.title,
                  style: GoogleFonts.crimsonPro(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  version.relativeTime,
                  style: GoogleFonts.inter(fontSize: 11, color: mutedColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              GestureDetector(
                onTap: onRestore,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.aqua.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Restore',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.aqua),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onLabel,
                child: Text(
                  'Label',
                  style: GoogleFonts.inter(fontSize: 11, color: mutedColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
