import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';

import '../../../../auth/auth_bottom_sheet.dart';
import '../../../../core/auth/auth_cubit.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../widgets/price_format.dart';
import '../../home/widgets/premium/premium_tokens.dart';
import '../cubit/ai_designer_cubit.dart';
import '../data/ai_designer_repository.dart';
import '../models/ai_chat_message.dart';

/// AI interior-designer chat. The user describes a room (optionally with a
/// photo) and the assistant replies in Uzbek with advice plus a shelf of
/// recommended products that deep-link to the catalog detail screen.
class AiAssistantChatScreen extends StatelessWidget {
  const AiAssistantChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Scaffold(
      backgroundColor: pt.background,
      appBar: AppBar(
        backgroundColor: pt.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: pt.dark,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: PremiumTokens.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Iconsax.magicpen,
                size: 20,
                color: PremiumTokens.accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr('ai_designer.title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PremiumTokens.body(
                      size: 15,
                      weight: FontWeight.w700,
                      color: pt.dark,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    tr('ai_designer.subtitle'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PremiumTokens.body(
                      size: 11,
                      weight: FontWeight.w500,
                      color: pt.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: const [
            Expanded(child: _MessageList()),
            _Composer(),
          ],
        ),
      ),
    );
  }
}

class _MessageList extends StatefulWidget {
  const _MessageList();

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AiDesignerCubit, AiDesignerState>(
      listenWhen: (a, b) =>
          a.messages.length != b.messages.length || a.sending != b.sending,
      listener: (context, state) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scroll.hasClients) return;
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut,
          );
        });
      },
      builder: (context, state) {
        if (state.messages.isEmpty && !state.sending) {
          return const _Greeting();
        }
        // +1 trailing slot for the typing indicator while a reply is in flight.
        final itemCount = state.messages.length + (state.sending ? 1 : 0);
        return ListView.builder(
          controller: _scroll,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: itemCount,
          itemBuilder: (context, i) {
            if (i >= state.messages.length) return const _TypingBubble();
            final message = state.messages[i];
            return _MessageRow(
              message: message,
              products: state.products[message.id] ?? const [],
              localImage: state.localImages[message.id],
            );
          },
        );
      },
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Lottie.asset(
                'assets/lottie/ai_chat_bot.json',
                repeat: true,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tr('ai_designer.greeting'),
              textAlign: TextAlign.center,
              style: PremiumTokens.body(size: 14, color: pt.grey, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.message,
    required this.products,
    this.localImage,
  });

  final AiChatMessage message;
  final List<AiRecommendedProduct> products;
  final Uint8List? localImage;

  @override
  Widget build(BuildContext context) {
    final mine = message.isUser;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          _Bubble(message: message, localImage: localImage),
          if (products.isNotEmpty) _ProductShelf(products: products),
          if (!mine && message.logId != null)
            _RatingRow(logId: message.logId!, rating: message.userRating),
        ],
      ),
    );
  }
}

/// A subtle 👍/👎 row under an AI bubble. Once the user picks a verdict both
/// buttons lock and the chosen side is accented — the rating is a one-shot
/// soft signal, not a toggle.
class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.logId, required this.rating});

  final String logId;

  /// "liked" / "disliked" / null.
  final String? rating;

  @override
  Widget build(BuildContext context) {
    final rated = rating != null;
    final liked = rating == 'liked';
    final disliked = rating == 'disliked';
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4, bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RatingButton(
            icon: Iconsax.like_1,
            tooltip: tr('ai_designer.rate_like'),
            active: liked,
            enabled: !rated,
            onTap: () =>
                context.read<AiDesignerCubit>().rateAiMessage(logId, 'liked'),
          ),
          const SizedBox(width: 4),
          _RatingButton(
            icon: Iconsax.dislike,
            tooltip: tr('ai_designer.rate_dislike'),
            active: disliked,
            enabled: !rated,
            onTap: () => context.read<AiDesignerCubit>().rateAiMessage(
              logId,
              'disliked',
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    // Accented when chosen; muted otherwise. A rated-but-not-chosen button
    // fades to greyLight so the picked side reads as the single answer.
    final color = active
        ? PremiumTokens.accent
        : (enabled ? pt.grey : pt.greyLight);
    final button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? PremiumTokens.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 17, color: color),
      ),
    );
    return Tooltip(message: tooltip, child: button);
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.localImage});

  final AiChatMessage message;
  final Uint8List? localImage;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final mine = message.isUser;
    final bg = mine ? Theme.of(context).colorScheme.primary : pt.surface;
    final fg = mine ? Colors.white : pt.dark;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(mine ? 18 : 4),
      bottomRight: Radius.circular(mine ? 4 : 18),
    );
    return Row(
      mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.74,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: radius,
                boxShadow: mine ? null : PremiumTokens.softShadow,
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (localImage != null)
                      _BubbleImageBytes(bytes: localImage!)
                    else if (message.imageUrl != null)
                      _BubbleImage(url: message.imageUrl!),
                    if (message.text.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          14,
                          (localImage != null || message.imageUrl != null)
                              ? 8
                              : 10,
                          14,
                          10,
                        ),
                        child: Text(
                          message.text,
                          style: PremiumTokens.body(
                            size: 14,
                            color: fg,
                            height: 1.35,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BubbleImage extends StatelessWidget {
  const _BubbleImage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 260, minWidth: 180),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          memCacheWidth: 800,
          placeholder: (_, _) => Container(color: pt.imageBg),
          errorWidget: (_, _, _) => Container(color: pt.imageBg),
        ),
      ),
    );
  }
}

/// The user's own locally-picked room photo, rendered from bytes (no URL — it
/// is sent to the backend but never persisted, see [AiDesignerState.localImages]).
class _BubbleImageBytes extends StatelessWidget {
  const _BubbleImageBytes({required this.bytes});
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 260, minWidth: 180),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Image.memory(bytes, fit: BoxFit.cover),
      ),
    );
  }
}

/// Horizontal shelf of compact recommended-product cards under an AI bubble.
class _ProductShelf extends StatelessWidget {
  const _ProductShelf({required this.products});

  final List<AiRecommendedProduct> products;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: SizedBox(
        height: 196,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: products.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) => _ProductCard(product: products[i]),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final AiRecommendedProduct product;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/product-detail/${product.id}'),
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: pt.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: PremiumTokens.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: AspectRatio(
                aspectRatio: 1.2,
                child: product.imageUrl == null
                    ? Container(
                        color: pt.imageBg,
                        child: Icon(Iconsax.gallery_slash, color: pt.greyLight),
                      )
                    : CachedNetworkImage(
                        imageUrl: product.imageUrl!,
                        fit: BoxFit.cover,
                        memCacheWidth: 400,
                        placeholder: (_, _) => Container(color: pt.imageBg),
                        errorWidget: (_, _, _) => Container(
                          color: pt.imageBg,
                          child: Icon(
                            Iconsax.gallery_slash,
                            color: pt.greyLight,
                          ),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: PremiumTokens.body(
                      size: 12,
                      weight: FontWeight.w600,
                      color: pt.dark,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatUzsPrice(product.price),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PremiumTokens.body(
                      size: 12,
                      weight: FontWeight.w700,
                      color: PremiumTokens.accent,
                    ),
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

/// Left-aligned "AI is typing" bubble shown while a reply is in flight — an
/// animated ellipsis + the localized "AI Dizayner javob yozmoqda..." copy.
/// Non-blocking: the composer stays live underneath.
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: pt.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(18),
            ),
            boxShadow: PremiumTokens.softShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _TypingDots(),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  tr('ai_designer.typing'),
                  style: PremiumTokens.body(size: 13, color: pt.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A three-dot ellipsis that ripples — the classic chat "typing" cue.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot peaks at a staggered phase → a travelling ripple.
            final phase = (_controller.value - i * 0.18) % 1.0;
            final scale = 0.6 + 0.4 * (1 - (2 * phase - 1).abs());
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: PremiumTokens.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Text input + photo attachment + send. Gates guests behind the login flow on
/// send (mirrors the cart checkout gate).
class _Composer extends StatefulWidget {
  const _Composer();

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _ctrl = TextEditingController();
  Uint8List? _pendingImage;
  String? _pendingMime;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await _pickSource();
    if (source == null) return;
    XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
    } catch (_) {
      file = null;
    }
    final picked = file;
    if (picked == null) return;
    final original = await picked.readAsBytes();
    // Heavily downscale + recompress BEFORE base64: a multi-MB base64 image
    // overruns the AI endpoint / its nginx body limit, which surfaced as the
    // "Hozir javob bera olmadim..." failure. 800px @ q60 JPEG keeps the payload
    // tiny while staying legible for the vision model.
    final bytes = await _compress(original);
    if (!mounted) return;
    setState(() {
      _pendingImage = bytes;
      _pendingMime = 'image/jpeg';
    });
  }

  static Future<Uint8List> _compress(Uint8List input) async {
    try {
      final out = await FlutterImageCompress.compressWithList(
        input,
        minWidth: 800,
        minHeight: 800,
        quality: 60,
        format: CompressFormat.jpeg,
      );
      return out.isNotEmpty ? out : input;
    } catch (_) {
      return input; // never block sending on a compression hiccup
    }
  }

  Future<ImageSource?> _pickSource() {
    final pt = PremiumTokens.of(context);
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: pt.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: pt.greyLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(Iconsax.gallery, color: pt.dark),
                title: Text(
                  tr('ai_designer.pick_from_gallery'),
                  style: PremiumTokens.body(size: 15, color: pt.dark),
                ),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: Icon(Iconsax.camera, color: pt.dark),
                title: Text(
                  tr('ai_designer.pick_from_camera'),
                  style: PremiumTokens.body(size: 15, color: pt.dark),
                ),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty && _pendingImage == null) return;

    // Guest gate — the AI endpoint requires auth, so route a signed-out user
    // through the login flow instead of POSTing (mirrors cart checkout).
    final authState = context.read<AuthCubit>().state;
    if (authState is AppAuthUnauthenticated) {
      final ok = await showAuthScreen(context);
      if (!ok || !mounted) return;
    }

    final image = _pendingImage;
    final mime = _pendingMime;
    _ctrl.clear();
    setState(() {
      _pendingImage = null;
      _pendingMime = null;
    });
    if (!mounted) return;
    await context.read<AiDesignerCubit>().sendMessage(
      text: text,
      imageBytes: image,
      imageMime: mime,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    // No BlocBuilder + no `sending` gate: the input stays live so the user can
    // fire consecutive messages while a reply is still in flight. The in-list
    // typing bubble is the only "busy" affordance — the field never freezes.
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: pt.surface,
        boxShadow: PremiumTokens.softShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_pendingImage != null)
            _ImagePreview(
              bytes: _pendingImage!,
              onRemove: () => setState(() {
                _pendingImage = null;
                _pendingMime = null;
              }),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _IconButton(icon: Icons.camera_alt, onTap: _pickImage),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: pt.background,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _ctrl,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    style: PremiumTokens.body(size: 14, color: pt.dark),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: tr('ai_designer.composer_hint'),
                      hintStyle: PremiumTokens.body(size: 14, color: pt.grey),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _SendButton(onTap: _send),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.bytes, required this.onRemove});

  final Uint8List bytes;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                bytes,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: pt.dark.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 22,
          color: onTap == null ? pt.greyLight : pt.grey,
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onTap});

  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    // Always active — the busy state is shown by the in-list typing bubble, not
    // by disabling send. The user can queue consecutive messages.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(),
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: PremiumTokens.accent,
          shape: BoxShape.circle,
        ),
        child: const Icon(Iconsax.send_1, size: 20, color: Colors.white),
      ),
    );
  }
}
