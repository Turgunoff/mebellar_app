enum VerificationStatus {
  none('none'),
  pending('pending'),
  inReview('in_review'),
  approved('approved'),
  rejected('rejected');

  const VerificationStatus(this.code);
  final String code;

  static VerificationStatus fromCode(String? code) {
    return values.firstWhere(
      (s) => s.code == code,
      orElse: () => VerificationStatus.none,
    );
  }

  bool get isApproved => this == VerificationStatus.approved;
  bool get isRejected => this == VerificationStatus.rejected;
  bool get isPending =>
      this == VerificationStatus.pending || this == VerificationStatus.inReview;
  bool get canSubmit =>
      this == VerificationStatus.none || this == VerificationStatus.rejected;
}
