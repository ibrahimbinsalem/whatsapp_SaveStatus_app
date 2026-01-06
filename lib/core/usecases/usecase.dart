import 'package:dartz/dartz.dart';
import '../errors/failure.dart';

/// Base UseCase class
/// Implements the Single Responsibility Principle
/// Each use case represents a single business operation
///
/// [Type] - Return type of the use case
/// [Params] - Parameters required by the use case
abstract class UseCase<Type, Params> {
  /// Executes the use case
  ///
  /// Returns [Either<Failure, Type>]
  /// - Left: Failure if operation failed
  /// - Right: Type if operation succeeded
  Future<Either<Failure, Type>> call(Params params);
}

/// No Parameters class
/// Used when a use case doesn't require parameters
class NoParams {
  const NoParams();
}

/// Example: Login Use Case
///
/// ```dart
/// class LoginUseCase extends UseCase<User, LoginParams> {
///   final AuthRepository repository;
///
///   LoginUseCase(this.repository);
///
///   @override
///   Future<Either<Failure, User>> call(LoginParams params) async {
///     return await repository.login(
///       email: params.email,
///       password: params.password,
///     );
///   }
/// }
///
/// class LoginParams {
///   final String email;
///   final String password;
///
///   LoginParams({required this.email, required this.password});
/// }
/// ```
