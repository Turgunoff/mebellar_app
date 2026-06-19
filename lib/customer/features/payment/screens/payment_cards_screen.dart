import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/i18n/i18n.dart';
import '../../../../shared/repositories/payment_cards_repository.dart';
import '../../home/widgets/premium/premium_tokens.dart';
import '../cubit/payment_cards_cubit.dart';
import 'add_card_screen.dart';

/// Saved-cards management: list, add (→ [AddCardScreen]), and remove.
class PaymentCardsScreen extends StatelessWidget {
  const PaymentCardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The cubit is a customer-scope singleton; (re)load on open.
    sl<PaymentCardsCubit>().load();
    return BlocProvider.value(
      value: sl<PaymentCardsCubit>(),
      child: const _CardsView(),
    );
  }
}

class _CardsView extends StatelessWidget {
  const _CardsView();

  Future<void> _addCard(BuildContext context) async {
    final added = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AddCardScreen()));
    if (added == true && context.mounted) {
      context.read<PaymentCardsCubit>().load(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Scaffold(
      backgroundColor: pt.background,
      appBar: AppBar(
        backgroundColor: pt.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Iconsax.arrow_left, color: pt.dark),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          tr('payment.cards_title'),
          style: PremiumTokens.display(size: 20, letterSpacing: -0.4),
        ),
        centerTitle: false,
      ),
      body: BlocBuilder<PaymentCardsCubit, PaymentCardsState>(
        builder: (context, state) {
          if (state.status == PaymentCardsStatus.loading && !state.hasCards) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [
              if (!state.hasCards)
                _EmptyState(pt: pt)
              else
                for (final card in state.cards) ...[
                  _CardTile(card: card, pt: pt),
                  const SizedBox(height: 12),
                ],
              const SizedBox(height: 8),
              _AddCardButton(pt: pt, onTap: () => _addCard(context)),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.pt});
  final PremiumTokens pt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: pt.imageBg,
              shape: BoxShape.circle,
            ),
            child: Icon(Iconsax.cards, size: 36, color: pt.greyLight),
          ),
          const SizedBox(height: 20),
          Text(
            tr('payment.no_cards'),
            style: PremiumTokens.body(size: 15, weight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            tr('payment.no_cards_hint'),
            textAlign: TextAlign.center,
            style: PremiumTokens.body(size: 13, color: pt.grey),
          ),
        ],
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.card, required this.pt});
  final SavedCard card;
  final PremiumTokens pt;

  Future<void> _confirmRemove(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final p = PremiumTokens.of(ctx);
        return AlertDialog(
          backgroundColor: p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            tr('payment.remove_card'),
            style: PremiumTokens.body(size: 17, weight: FontWeight.w700),
          ),
          content: Text(
            tr('payment.remove_confirm'),
            style: PremiumTokens.body(size: 14, color: p.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('common.cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('payment.remove_card')),
            ),
          ],
        );
      },
    );
    if (ok == true && context.mounted) {
      context.read<PaymentCardsCubit>().remove(card.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: pt.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: PremiumTokens.cardShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: PremiumTokens.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Iconsax.card,
              color: PremiumTokens.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              card.maskedNumber,
              style: PremiumTokens.body(
                size: 15,
                weight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Iconsax.trash,
              size: 20,
              color: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => _confirmRemove(context),
          ),
        ],
      ),
    );
  }
}

class _AddCardButton extends StatelessWidget {
  const _AddCardButton({required this.pt, required this.onTap});
  final PremiumTokens pt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: PremiumTokens.accent.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Iconsax.add, size: 20, color: PremiumTokens.accent),
              const SizedBox(width: 8),
              Text(
                tr('payment.add_card'),
                style: PremiumTokens.body(
                  size: 15,
                  weight: FontWeight.w700,
                  color: PremiumTokens.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
