import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Backend-aligned codes for the documents Woody collects during manual
/// seller verification. The icon/label keys are local to the mobile app.
enum VerificationDocumentType {
  passportFront(
    'passport_front',
    Icons.badge_outlined,
    requiredForAll: true,
  ),
  passportBack(
    'passport_back',
    Icons.flip_to_back_outlined,
    requiredForAll: true,
  ),
  selfieWithPassport(
    'selfie_with_passport',
    Icons.person_pin_circle_outlined,
    requiredForAll: true,
  ),
  businessCertificate(
    'business_certificate',
    Icons.workspace_premium_outlined,
  ),
  taxId(
    'tax_id',
    Icons.receipt_long_outlined,
  );

  const VerificationDocumentType(
    this.code,
    this.icon, {
    this.requiredForAll = false,
  });

  final String code;
  final IconData icon;
  final bool requiredForAll;

  static VerificationDocumentType? fromCode(String code) {
    for (final t in values) {
      if (t.code == code) return t;
    }
    return null;
  }
}

class VerificationDocument extends Equatable {
  const VerificationDocument({
    required this.type,
    this.localPath,
    this.remoteUrl,
    this.uploading = false,
    this.error,
  });

  final VerificationDocumentType type;

  /// Local file path immediately after picker — used to render the preview
  /// while upload is in progress.
  final String? localPath;

  /// Remote URL after successful upload to Supabase Storage. Required for
  /// the submit step.
  final String? remoteUrl;

  final bool uploading;
  final String? error;

  bool get isUploaded => remoteUrl != null;
  bool get hasLocal => localPath != null;

  VerificationDocument copyWith({
    String? localPath,
    String? remoteUrl,
    bool? uploading,
    String? error,
    bool clearError = false,
    bool clearLocalPath = false,
    bool clearRemoteUrl = false,
  }) {
    return VerificationDocument(
      type: type,
      localPath: clearLocalPath ? null : (localPath ?? this.localPath),
      remoteUrl: clearRemoteUrl ? null : (remoteUrl ?? this.remoteUrl),
      uploading: uploading ?? this.uploading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [type, localPath, remoteUrl, uploading, error];
}
