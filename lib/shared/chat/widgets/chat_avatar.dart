import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../customer/features/home/widgets/premium/premium_tokens.dart';

/// Circular avatar with image-or-initials fallback. Used by both the
/// chats list tiles and the thread app bar — same visual language for
/// the "other party" regardless of which side is looking.
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 44,
  });

  final String name;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: hasImage
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                memCacheWidth: (size * 2).round(),
                fit: BoxFit.cover,
                placeholder: (_, _) => _Initials(name: name, pt: pt, size: size),
                errorWidget: (_, _, _) =>
                    _Initials(name: name, pt: pt, size: size),
              )
            : _Initials(name: name, pt: pt, size: size),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.name, required this.pt, required this.size});

  final String name;
  final PremiumTokens pt;
  final double size;

  String get _initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts[1].characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PremiumTokens.accent.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: PremiumTokens.body(
          size: size * 0.38,
          weight: FontWeight.w700,
          color: PremiumTokens.accent,
        ),
      ),
    );
  }
}
