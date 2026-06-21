import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../core/notifications/active_support_tracker.dart';
import '../../../../core/notifications/push_service.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../home/widgets/premium/premium_tokens.dart';
import '../bloc/support_chat_cubit.dart';
import '../models/support_message.dart';
import '../repository/support_chat_repository.dart';
import '../widgets/support_composer.dart';
import '../widgets/support_message_bubble.dart';

/// Customer support thread — a single per-user conversation with the support
/// team. Mirrors the per-order [ChatThreadScreen] but with no order, no status
/// banner, and no client-supplied chat id (the backend resolves one thread).
class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen>
    with WidgetsBindingObserver {
  // Owned here (not via BlocProvider's `create`) so the lifecycle callback can
  // reach it on resume; closed in dispose since `BlocProvider.value` won't.
  late final SupportChatCubit _cubit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Tell PushService we're on the support thread so a foreground push for it
    // is suppressed (the open thread already shows the message live).
    ActiveSupportTracker.instance.enter();
    _cubit = SupportChatCubit(repo: sl<SupportChatRepository>())..load();
    // Opening the thread == reading it — clear any support tray notifications.
    _dismissSupportNotifications();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _dismissSupportNotifications();
      unawaited(_cubit.refresh());
    }
  }

  void _dismissSupportNotifications() {
    if (!sl.isRegistered<PushService>()) return;
    unawaited(sl<PushService>().dismissSupportNotifications());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ActiveSupportTracker.instance.leave();
    unawaited(_cubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocListener<SupportChatCubit, SupportChatState>(
        listenWhen: (prev, curr) =>
            curr.error != null && curr.error != prev.error,
        listener: (context, state) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.error!)));
        },
        child: const _SupportChatBody(),
      ),
    );
  }
}

class _SupportChatBody extends StatelessWidget {
  const _SupportChatBody();

  void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/');
  }

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
        leading: IconButton(
          icon: Icon(
            Iconsax.arrow_left_2_copy,
            size: 20,
            color: pt.dark,
          ),
          onPressed: () => _handleBack(context),
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Iconsax.headphone,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr('support.title'),
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
                    tr('support.subtitle'),
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
        child: BlocBuilder<SupportChatCubit, SupportChatState>(
          builder: (context, state) {
            return Column(
              children: [
                Expanded(
                  child: switch (state.status) {
                    SupportChatStatus.initial ||
                    SupportChatStatus.loading => _LoadingBody(),
                    SupportChatStatus.failure => ErrorState(
                      message: state.error,
                      onRetry: () => context.read<SupportChatCubit>().load(),
                    ),
                    SupportChatStatus.ready => _MessageList(
                      messages: state.messages,
                    ),
                  },
                ),
                SupportComposer(
                  sending: state.sending,
                  onSendText: (text) =>
                      context.read<SupportChatCubit>().sendText(text),
                  onSendImage: (bytes, mime) async =>
                      context.read<SupportChatCubit>().sendImage(
                        bytes: bytes,
                        mimeType: mime,
                      ),
                  onSendAudio: (bytes, contentType, durationMs) async =>
                      context.read<SupportChatCubit>().sendAudio(
                        bytes: bytes,
                        contentType: contentType,
                        durationMs: durationMs,
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

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _MessageList extends StatefulWidget {
  const _MessageList({required this.messages});

  final List<SupportMessage> messages;

  @override
  State<_MessageList> createState() => _MessageListState();
}

sealed class _Row {
  const _Row();
}

class _MessageRow extends _Row {
  const _MessageRow(this.message);
  final SupportMessage message;
}

class _SeparatorRow extends _Row {
  const _SeparatorRow(this.date);
  final DateTime date;
}

class _MessageListState extends State<_MessageList> {
  final _scroll = ScrollController();
  late List<_Row> _rows;

  @override
  void initState() {
    super.initState();
    _rows = _buildRows(widget.messages);
  }

  @override
  void didUpdateWidget(covariant _MessageList old) {
    super.didUpdateWidget(old);
    if (!listEquals(widget.messages, old.messages)) {
      _rows = _buildRows(widget.messages);
    }
    if (widget.messages.length != old.messages.length) {
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

  static List<_Row> _buildRows(List<SupportMessage> messages) {
    final newestFirst = messages.reversed.toList(growable: false);
    final rows = <_Row>[];
    for (var i = 0; i < newestFirst.length; i++) {
      final m = newestFirst[i];
      rows.add(_MessageRow(m));
      final next = i == newestFirst.length - 1 ? null : newestFirst[i + 1];
      if (next == null || !_sameDay(m.createdAt, next.createdAt)) {
        rows.add(_SeparatorRow(m.createdAt));
      }
    }
    return rows;
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
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Iconsax.message_text,
                  size: 36,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tr('support.empty_message'),
                textAlign: TextAlign.center,
                style: PremiumTokens.body(size: 13, color: pt.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scroll,
      reverse: true,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _rows.length,
      itemBuilder: (context, i) {
        final row = _rows[i];
        return switch (row) {
          _MessageRow(:final message) => SupportMessageBubble(message: message),
          _SeparatorRow(:final date) => SupportDateSeparator(date: date),
        };
      },
    );
  }

  static bool _sameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }
}
