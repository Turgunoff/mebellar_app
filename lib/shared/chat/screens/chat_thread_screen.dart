import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/i18n/i18n.dart';
import '../../../customer/features/home/widgets/premium/premium_tokens.dart';
import '../../models/chat.dart';
import '../../models/chat_message.dart';
import '../../repositories/chat_repository.dart';
import '../../widgets/error_state.dart';
import '../bloc/chat_thread_cubit.dart';
import '../widgets/chat_avatar.dart';
import '../widgets/chat_composer.dart';
import '../widgets/chat_status_banner.dart';
import '../widgets/message_bubble.dart';

/// Customer ↔ seller thread for a single order. The screen handles three
/// distinct startup paths:
///
/// * `chatId` known up front → bind directly
/// * `orderId` known, customer side → `openChatForOrder` lazy-creates
/// * neither → impossible (route guarantees one is set)
class ChatThreadScreen extends StatelessWidget {
  const ChatThreadScreen({
    super.key,
    required this.viewer,
    this.chatId,
    this.orderId,
    this.onOpenOrder,
  }) : assert(
          chatId != null || orderId != null,
          'Either chatId or orderId must be provided',
        );

  final ChatSenderRole viewer;
  final String? chatId;
  final String? orderId;

  /// Optional callback for the "View order" link in the app bar. When
  /// omitted, the link is hidden — useful when the thread was opened
  /// from the order detail itself (round-trip would be redundant).
  final void Function(String orderId)? onOpenOrder;

  @override
  Widget build(BuildContext context) {
    return _ChatThreadBootstrap(
      viewer: viewer,
      chatId: chatId,
      orderId: orderId,
      onOpenOrder: onOpenOrder,
    );
  }
}

/// Resolves the chat id (lazy-creating one when only an order id was
/// passed), then mounts the real thread screen. Kept as a separate
/// widget so the cubit's [chatId] is non-null at construction.
class _ChatThreadBootstrap extends StatefulWidget {
  const _ChatThreadBootstrap({
    required this.viewer,
    this.chatId,
    this.orderId,
    this.onOpenOrder,
  });

  final ChatSenderRole viewer;
  final String? chatId;
  final String? orderId;
  final void Function(String orderId)? onOpenOrder;

  @override
  State<_ChatThreadBootstrap> createState() => _ChatThreadBootstrapState();
}

class _ChatThreadBootstrapState extends State<_ChatThreadBootstrap> {
  late Future<Chat> _future;

  @override
  void initState() {
    super.initState();
    _future = _resolve();
  }

  Future<Chat> _resolve() async {
    final repo = sl<ChatRepository>();
    if (widget.chatId != null) {
      return repo.getChat(widget.chatId!);
    }
    return repo.openChatForOrder(orderId: widget.orderId!);
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Scaffold(
      backgroundColor: pt.background,
      body: FutureBuilder<Chat>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const _BootstrapLoading();
          }
          if (snap.hasError) {
            return SafeArea(
              child: ErrorState(
                message: snap.error.toString(),
                onRetry: () => setState(() => _future = _resolve()),
              ),
            );
          }
          final chat = snap.data!;
          return _ChatThreadView(
            chat: chat,
            viewer: widget.viewer,
            onOpenOrder: widget.onOpenOrder,
          );
        },
      ),
    );
  }
}

class _BootstrapLoading extends StatelessWidget {
  const _BootstrapLoading();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: CircularProgressIndicator(color: PremiumTokens.accent),
      ),
    );
  }
}

class _ChatThreadView extends StatelessWidget {
  const _ChatThreadView({
    required this.chat,
    required this.viewer,
    this.onOpenOrder,
  });

  final Chat chat;
  final ChatSenderRole viewer;
  final void Function(String orderId)? onOpenOrder;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ChatThreadCubit(
        repo: sl<ChatRepository>(),
        chatId: chat.id,
        viewer: viewer,
      )..load(),
      child: _ChatThreadBody(
        chat: chat,
        viewer: viewer,
        onOpenOrder: onOpenOrder,
      ),
    );
  }
}

class _ChatThreadBody extends StatelessWidget {
  const _ChatThreadBody({
    required this.chat,
    required this.viewer,
    this.onOpenOrder,
  });

  final Chat chat;
  final ChatSenderRole viewer;
  final void Function(String orderId)? onOpenOrder;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Scaffold(
      backgroundColor: pt.background,
      appBar: _ThreadAppBar(
        chat: chat,
        viewer: viewer,
        onOpenOrder: onOpenOrder,
      ),
      body: SafeArea(
        top: false,
        child: BlocBuilder<ChatThreadCubit, ChatThreadState>(
          builder: (context, state) {
            // Status banner reflects the *latest* chat row — when the
            // bloc's stream refresh updates `state.chat`, the banner
            // re-renders automatically (e.g. order moves to delivered).
            final activeChat = state.chat ?? chat;
            return Column(
              children: [
                ChatStatusBanner(
                  chat: activeChat,
                  viewer: viewer,
                  // Customer-side delivered orders get a "Leave a review"
                  // CTA that jumps to the order detail (where the existing
                  // review composer lives). Seller-side and other statuses
                  // skip the CTA.
                  onLeaveReview: viewer == ChatSenderRole.customer &&
                          onOpenOrder != null
                      ? () => onOpenOrder!(activeChat.orderId)
                      : null,
                ),
                Expanded(
                  child: switch (state.status) {
                    ChatThreadStatus.initial ||
                    ChatThreadStatus.loading =>
                      const _LoadingBody(),
                    ChatThreadStatus.failure => ErrorState(
                        message: state.error,
                        onRetry: () =>
                            context.read<ChatThreadCubit>().load(),
                      ),
                    ChatThreadStatus.ready => _MessageList(
                        messages: state.messages,
                        viewer: viewer,
                      ),
                  },
                ),
                ChatComposer(
                  sending: state.sending,
                  onSendText: (body) =>
                      context.read<ChatThreadCubit>().sendText(body),
                  onSendImage: (bytes, mime, caption) async =>
                      context.read<ChatThreadCubit>().sendImage(
                            bytes: bytes,
                            mimeType: mime,
                            caption: caption,
                          ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ThreadAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ThreadAppBar({
    required this.chat,
    required this.viewer,
    this.onOpenOrder,
  });

  final Chat chat;
  final ChatSenderRole viewer;
  final void Function(String orderId)? onOpenOrder;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final name = chat.displayNameFor(viewer);
    return AppBar(
      backgroundColor: pt.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: pt.dark,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 64,
      titleSpacing: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: pt.dark),
        onPressed: () => context.pop(),
      ),
      title: Row(
        children: [
          ChatAvatar(
            name: name,
            imageUrl: chat.avatarFor(viewer),
            size: 38,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
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
                  '${tr('chat.order_label')} #${_shortId(chat.orderId)}',
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
      actions: [
        if (onOpenOrder != null)
          IconButton(
            tooltip: tr('chat.view_order'),
            icon: Icon(Iconsax.receipt_2_1, color: PremiumTokens.accent, size: 22),
            onPressed: () => onOpenOrder!(chat.orderId),
          ),
        const SizedBox(width: 4),
      ],
    );
  }

  static String _shortId(String id) =>
      id.length <= 8 ? id : id.substring(0, 8).toUpperCase();
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: PremiumTokens.accent),
    );
  }
}

class _MessageList extends StatefulWidget {
  const _MessageList({required this.messages, required this.viewer});

  final List<ChatMessage> messages;
  final ChatSenderRole viewer;

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(covariant _MessageList old) {
    super.didUpdateWidget(old);
    if (widget.messages.length != old.messages.length) {
      // New message arrived — scroll to the bottom on next frame so the
      // user sees the freshest content without manual interaction.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    if (widget.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: PremiumTokens.accent.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Iconsax.message_text,
                  size: 36,
                  color: PremiumTokens.accent,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tr('chat.composer_hint'),
                textAlign: TextAlign.center,
                style: PremiumTokens.body(size: 13, color: pt.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Build a flat list of items: messages + day separators when the
    // calendar date changes. Use a reverse ListView so new messages
    // can append visually-at-the-bottom while we iterate newest-first.
    final messagesNewestFirst = widget.messages.reversed.toList();
    final items = <Widget>[];
    for (var i = 0; i < messagesNewestFirst.length; i++) {
      final m = messagesNewestFirst[i];
      items.add(MessageBubble(message: m, viewer: widget.viewer));
      final isLast = i == messagesNewestFirst.length - 1;
      final next = isLast ? null : messagesNewestFirst[i + 1];
      if (next == null || !_sameDay(m.createdAt, next.createdAt)) {
        items.add(MessageDateSeparator(date: m.createdAt));
      }
    }

    return ListView(
      controller: _scroll,
      reverse: true,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: items,
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
