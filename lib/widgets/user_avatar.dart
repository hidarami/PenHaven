import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/community_state.dart';
import '../services/supabase_service.dart';

/// Canonical avatar circle. Automatically resolves to the CURRENT user's
/// live profile photo when [userId] is null or matches the signed-in user
/// (and stays live via CommunityState — no manual wiring needed), otherwise
/// shows [remoteImageUrl] for other users. Any new screen needing an avatar
/// should use this instead of building a custom circle.
class UserAvatar extends StatelessWidget {
  final String name;
  final double size;
  final String? userId; // null = "current user"
  final String? remoteImageUrl; // used only when userId != current user

  const UserAvatar({
    super.key,
    required this.name,
    this.size = 32,
    this.userId,
    this.remoteImageUrl,
  });

  static const _palette = [
    Color(0xFF7BA591), Color(0xFF5B8DB8), Color(0xFFD4820A),
    Color(0xFF9472D4), Color(0xFFE87FA0), Color(0xFFD44A28),
    Color(0xFF5A8A5C), Color(0xFF1B9B8D),
  ];

  Color _color(String n) =>
      _palette[n.codeUnits.fold(0, (a, b) => a + b) % _palette.length];

  @override
  Widget build(BuildContext context) {
    final isSelf =
        userId == null || userId == SupabaseService.instance.userId;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    if (isSelf) {
      final community = context.watch<CommunityState>();
      final path = community.profileImagePath;
      final hasLocal =
          path != null && path.isNotEmpty && File(path).existsSync();
      if (hasLocal) {
        return ClipOval(
          child: Image.file(File(path), width: size, height: size, fit: BoxFit.cover),
        );
      }
      final url = community.profileImageUrl;
      if (url != null && url.isNotEmpty) {
        return ClipOval(
          child: Image.network(url, width: size, height: size, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback(initial)),
        );
      }
      return _fallback(initial);
    }

    if (remoteImageUrl != null && remoteImageUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(remoteImageUrl!, width: size, height: size, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallback(initial)),
      );
    }
    return _fallback(initial);
  }

  Widget _fallback(String initial) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: _color(name), shape: BoxShape.circle),
        child: Center(
          child: Text(initial,
              style: GoogleFonts.inter(
                  fontSize: size * 0.42,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ),
      );
}