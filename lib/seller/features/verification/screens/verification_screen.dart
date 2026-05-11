import 'package:mebellar_app/core/i18n/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/models/business_type.dart';
import '../../../../shared/models/verification_status.dart';
import '../../../../shared/repositories/seller_verification_repository.dart';
import '../bloc/verification_bloc.dart';
import '../widgets/document_upload_tile.dart';
import '../widgets/verification_status_banner.dart';

class VerificationScreen extends StatelessWidget {
  const VerificationScreen({
    super.key,
    required this.businessType,
    required this.initialStatus,
  });

  final BusinessType? businessType;
  final VerificationStatus initialStatus;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => VerificationBloc(sl<SellerVerificationRepository>())
        ..add(VerificationRequested(
          businessType: businessType,
          status: initialStatus,
        )),
      child: const _VerificationView(),
    );
  }
}

class _VerificationView extends StatelessWidget {
  const _VerificationView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VerificationBloc, VerificationState>(
      listenWhen: (a, b) =>
          a.flowStatus != b.flowStatus &&
          b.flowStatus == VerificationFlowStatus.submitted,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('verification.submitted_toast'))),
        );
      },
      builder: (context, state) {
        final docsLocked = !state.status.canSubmit;
        return Scaffold(
          appBar: AppBar(title: Text(tr('verification.title'))),
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              VerificationStatusBanner(status: state.status),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('verification.docs_title'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr('verification.docs_subtitle'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    for (final type in state.requiredDocuments) ...[
                      DocumentUploadTile(
                        type: type,
                        document: state.documentFor(type),
                        locked: docsLocked,
                        onPicked: (file, ext) {
                          context
                              .read<VerificationBloc>()
                              .add(VerificationDocumentUploadStarted(
                                type: type,
                                file: file,
                                fileExtension: ext,
                              ));
                        },
                        onRemove: () => context
                            .read<VerificationBloc>()
                            .add(VerificationDocumentRemoved(type)),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 16),
                    if (state.status.canSubmit) ...[
                      FilledButton.icon(
                        onPressed: state.canSubmit &&
                                state.flowStatus !=
                                    VerificationFlowStatus.submitting
                            ? () => context
                                .read<VerificationBloc>()
                                .add(const VerificationSubmitted())
                            : null,
                        icon: state.flowStatus ==
                                VerificationFlowStatus.submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_outlined),
                        label: Text(state.status == VerificationStatus.rejected
                            ? tr('verification.resubmit')
                            : tr('verification.submit')),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ],
                    if (!state.status.canSubmit) ...[
                      Text(
                        tr('verification.locked_hint'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
