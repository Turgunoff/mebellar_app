import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/models/review.dart';
import '../../../../shared/repositories/seller_reviews_repository.dart';

enum ReviewFilter { all, pending, fiveStar, critical }

extension ReviewFilterX on ReviewFilter {
  String get label => switch (this) {
        ReviewFilter.all => 'Barchasi',
        ReviewFilter.pending => 'Javob kutilmoqda',
        ReviewFilter.fiveStar => '5 Yulduz',
        ReviewFilter.critical => '1-2 Yulduz',
      };

  bool matches(Review review) => switch (this) {
        ReviewFilter.all => true,
        ReviewFilter.pending => !review.hasReply,
        ReviewFilter.fiveStar => review.rating == 5,
        ReviewFilter.critical => review.rating <= 2,
      };
}

class ReviewsState extends Equatable {
  const ReviewsState({
    this.isLoading = false,
    this.reviews = const [],
    this.filter = ReviewFilter.all,
    this.error,
    this.replyingId,
  });

  final bool isLoading;
  final List<Review> reviews;
  final ReviewFilter filter;
  final String? error;

  /// Non-null while a reply POST is in flight. The reply sheet disables its
  /// send button on this so the seller can't double-submit.
  final String? replyingId;

  List<Review> get visible =>
      reviews.where(filter.matches).toList(growable: false);

  int get pendingCount =>
      reviews.where((r) => !r.hasReply).length;

  ReviewsState copyWith({
    bool? isLoading,
    List<Review>? reviews,
    ReviewFilter? filter,
    String? error,
    bool clearError = false,
    String? replyingId,
    bool clearReplyingId = false,
  }) {
    return ReviewsState(
      isLoading: isLoading ?? this.isLoading,
      reviews: reviews ?? this.reviews,
      filter: filter ?? this.filter,
      error: clearError ? null : (error ?? this.error),
      replyingId: clearReplyingId ? null : (replyingId ?? this.replyingId),
    );
  }

  @override
  List<Object?> get props => [isLoading, reviews, filter, error, replyingId];
}

class ReviewsCubit extends Cubit<ReviewsState> {
  ReviewsCubit(this._repo) : super(const ReviewsState());

  final SellerReviewsRepository _repo;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));
    final result = await _repo.fetchReviews();
    result.fold(
      ok: (reviews) => emit(state.copyWith(
        isLoading: false,
        reviews: reviews,
      )),
      err: (failure) => emit(state.copyWith(
        isLoading: false,
        error: failure.message,
      )),
    );
  }

  void setFilter(ReviewFilter filter) {
    if (filter == state.filter) return;
    emit(state.copyWith(filter: filter));
  }

  Future<bool> postReply({
    required String reviewId,
    required String reply,
  }) async {
    emit(state.copyWith(replyingId: reviewId, clearError: true));
    final result = await _repo.postReply(reviewId: reviewId, reply: reply);
    return result.fold(
      ok: (updated) {
        final next = [
          for (final r in state.reviews) r.id == reviewId ? updated : r,
        ];
        emit(state.copyWith(reviews: next, clearReplyingId: true));
        return true;
      },
      err: (failure) {
        emit(state.copyWith(
          error: failure.message,
          clearReplyingId: true,
        ));
        return false;
      },
    );
  }
}
