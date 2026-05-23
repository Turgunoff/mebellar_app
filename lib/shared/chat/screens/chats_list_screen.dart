import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/i18n/i18n.dart';
import '../../../customer/features/home/widgets/premium/premium_tokens.dart';
import '../../models/chat.dart';
import '../../repositories/chat_repository.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../bloc/chats_list_cubit.dart';
import '../widgets/chat_list_tile.dart';

/// Single screen used by both customer and seller — the only thing that
/// changes between them is [viewer] (which side of the chat tile to
/// label "other party") and the route path the tap navigates to. The
/// caller wires those in via the route definition.
class ChatsListScreen extends StatelessWidget {
  const ChatsListScreen({
    super.key,
    required this.viewer,
    required this.threadRouteBuilder,
  });

  /// Which side of the conversation the local user is on.
  final ChatSenderRole viewer;

  /// Builds the destination route for tapping a chat — e.g.
  /// `/chats/$id` for customer, `/seller/chats/$id` for seller.
  final String Function(Chat chat) threadRouteBuilder;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return BlocProvider(
      create: (_) => ChatsListCubit(sl<ChatRepository>()),
      child: Scaffold(
        backgroundColor: pt.background,
        appBar: AppBar(
          backgroundColor: pt.background,
          surfaceTintColor: Colors.transparent,
          foregroundColor: pt.dark,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: pt.dark),
            onPressed: () => context.pop(),
          ),
          title: Text(
            tr('chat.title'),
            style: PremiumTokens.display(size: 22, letterSpacing: -0.4),
          ),
        ),
        body: BlocBuilder<ChatsListCubit, ChatsListState>(
          builder: (context, state) {
            if (state.status == ChatsListStatus.failure) {
              return ErrorState(
                message: state.error,
                onRetry: () => context.read<ChatsListCubit>().refresh(),
              );
            }
            if (state.status == ChatsListStatus.loading && state.chats.isEmpty) {
              return const _Skeleton();
            }
            if (state.chats.isEmpty) {
              return EmptyState(
                icon: Iconsax.message,
                title: tr('chat.empty_title'),
                message: tr('chat.empty_message'),
              );
            }
            return RefreshIndicator(
              color: PremiumTokens.accent,
              onRefresh: context.read<ChatsListCubit>().refresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: state.chats.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  thickness: 0.6,
                  indent: 76,
                  color: pt.divider,
                ),
                itemBuilder: (context, i) {
                  final chat = state.chats[i];
                  return ChatListTile(
                    chat: chat,
                    viewer: viewer,
                    onTap: () => context.push(threadRouteBuilder(chat)),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 6,
      itemBuilder: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: pt.imageBg,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 140,
                    height: 12,
                    decoration: BoxDecoration(
                      color: pt.imageBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 10,
                    decoration: BoxDecoration(
                      color: pt.imageBg,
                      borderRadius: BorderRadius.circular(4),
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
