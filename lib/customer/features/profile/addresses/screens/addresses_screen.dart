import 'package:woody_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/di/service_locator.dart';
import '../../../../../shared/repositories/address_repository.dart';
import '../../../../../shared/widgets/empty_state.dart';
import '../../../../../shared/widgets/error_state.dart';
import '../bloc/addresses_bloc.dart';
import 'address_edit_screen.dart';

class AddressesScreen extends StatelessWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AddressesBloc(sl<AddressRepository>())
        ..add(const AddressesRequested()),
      child: const _AddressesView(),
    );
  }
}

class _AddressesView extends StatelessWidget {
  const _AddressesView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AddressesBloc, AddressesState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: Text(tr('address.title'))),
          body: switch (state.status) {
            AddressesStatus.initial ||
            AddressesStatus.loading =>
              const Center(child: CircularProgressIndicator()),
            AddressesStatus.failure => ErrorState(
                message: state.error,
                onRetry: () => context
                    .read<AddressesBloc>()
                    .add(const AddressesRequested()),
              ),
            AddressesStatus.ready ||
            AddressesStatus.mutating =>
              state.addresses.isEmpty
                  ? EmptyState(
                      icon: Icons.location_off_outlined,
                      title: tr('address.empty'),
                      message: tr('address.empty_hint'),
                      action: () => _openCreate(context),
                      actionLabel: tr('address.add'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: state.addresses.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final addr = state.addresses[i];
                        final lang = context.locale.languageCode;
                        final scheme = Theme.of(context).colorScheme;
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: addr.isDefault
                                  ? scheme.primary
                                  : scheme.outlineVariant,
                              width: addr.isDefault ? 1.5 : 1,
                            ),
                          ),
                          child: ListTile(
                            leading: Icon(
                              Icons.location_on_outlined,
                              color: addr.isDefault ? scheme.primary : null,
                            ),
                            title: Row(
                              children: [
                                Text(addr.label),
                                if (addr.isDefault) ...[
                                  const SizedBox(width: 6),
                                  Chip(
                                    visualDensity: VisualDensity.compact,
                                    label: Text(
                                      tr('address.default_chip'),
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(addr.recipientName),
                                Text(addr.phone),
                                Text(addr.formatted(lang)),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) =>
                                  _onMenu(context, value, addr.id),
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text(tr('common.next')),
                                ),
                                if (!addr.isDefault)
                                  PopupMenuItem(
                                    value: 'default',
                                    child: Text(tr('address.set_default')),
                                  ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(tr('cart.remove')),
                                ),
                              ],
                            ),
                            onTap: () => _openEdit(context, i),
                          ),
                        );
                      },
                    ),
          },
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openCreate(context),
            icon: const Icon(Icons.add),
            label: Text(tr('address.add')),
          ),
        );
      },
    );
  }

  void _onMenu(BuildContext context, String action, String id) {
    final bloc = context.read<AddressesBloc>();
    switch (action) {
      case 'edit':
        final addr = bloc.state.addresses.firstWhere((a) => a.id == id);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: bloc,
              child: AddressEditScreen(address: addr),
            ),
          ),
        );
      case 'default':
        bloc.add(AddressDefaultSet(id));
      case 'delete':
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(tr('address.delete_title')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(tr('common.cancel')),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  bloc.add(AddressDeleted(id));
                },
                child: Text(tr('common.ok')),
              ),
            ],
          ),
        );
    }
  }

  void _openCreate(BuildContext context) {
    final bloc = context.read<AddressesBloc>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: const AddressEditScreen(),
        ),
      ),
    );
  }

  void _openEdit(BuildContext context, int i) {
    final bloc = context.read<AddressesBloc>();
    final addr = bloc.state.addresses[i];
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: AddressEditScreen(address: addr),
        ),
      ),
    );
  }
}
