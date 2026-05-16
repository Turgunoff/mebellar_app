import 'package:equatable/equatable.dart';

import '../error/failure.dart';

/// Generic outcome wrapper for any operation that can fail with a [Failure].
///
/// Repositories return `Future<Result<T>>` instead of throwing — callers then
/// get a value they MUST pattern-match, so a forgotten error branch is a
/// compile-time hole rather than an uncaught exception at runtime.
///
/// The ROADMAP (B.6) phrases this as `Result<T, Failure>`. The error arm is
/// pinned to [Failure] rather than a second type parameter on purpose:
/// [Failure] is already a `sealed` union ([NetworkFailure], [ServerFailure],
/// [AuthFailure], [UnknownFailure]), so a free `F` parameter would only add
/// call-site noise without buying any extra exhaustiveness.
///
/// ```dart
/// final result = await repo.fetchOrders();
/// final widget = result.fold(
///   ok: (orders) => OrderList(orders),
///   err: (failure) => ErrorView(failure.message),
/// );
/// ```
sealed class Result<T> extends Equatable {
  const Result();

  /// Wraps a success value.
  const factory Result.ok(T value) = Ok<T>;

  /// Wraps a [Failure].
  const factory Result.err(Failure failure) = Err<T>;

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  /// The value when this is an [Ok], otherwise `null`.
  T? get valueOrNull => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>() => null,
      };

  /// The failure when this is an [Err], otherwise `null`.
  Failure? get failureOrNull => switch (this) {
        Ok<T>() => null,
        Err<T>(:final failure) => failure,
      };

  /// Collapses both arms into a single [R]. The exhaustive `switch` makes
  /// omitting either branch a compile error.
  R fold<R>({
    required R Function(T value) ok,
    required R Function(Failure failure) err,
  }) =>
      switch (this) {
        Ok<T>(:final value) => ok(value),
        Err<T>(:final failure) => err(failure),
      };

  /// Transforms the success value, leaving an [Err] untouched.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
        Ok<T>(:final value) => Ok<R>(transform(value)),
        Err<T>(:final failure) => Err<R>(failure),
      };

  /// Chains another fallible step; short-circuits on the first [Err].
  Result<R> flatMap<R>(Result<R> Function(T value) transform) =>
      switch (this) {
        Ok<T>(:final value) => transform(value),
        Err<T>(:final failure) => Err<R>(failure),
      };

  /// The success value, or the result of [orElse] when this is an [Err].
  T getOrElse(T Function(Failure failure) orElse) => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>(:final failure) => orElse(failure),
      };
}

/// Success arm of [Result].
final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  List<Object?> get props => [value];
}

/// Failure arm of [Result].
final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

/// Runs [body] and funnels any thrown error into an [Err], so a repository
/// method can be written as a flat happy path:
///
/// ```dart
/// Future<Result<List<Order>>> fetchOrders() => runCatching(() async {
///   final rows = await _client.from('orders').select();
///   return rows.map(Order.fromJson).toList();
/// });
/// ```
///
/// A thrown [Failure] is preserved as-is; anything else is mapped through
/// [onError] (or wrapped in an [UnknownFailure] when [onError] is omitted).
Future<Result<T>> runCatching<T>(
  Future<T> Function() body, {
  Failure Function(Object error, StackTrace stackTrace)? onError,
}) async {
  try {
    return Ok<T>(await body());
  } on Failure catch (failure) {
    return Err<T>(failure);
  } catch (error, stackTrace) {
    return Err<T>(
      onError?.call(error, stackTrace) ??
          UnknownFailure(message: error.toString()),
    );
  }
}
