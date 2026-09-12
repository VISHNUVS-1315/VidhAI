import 'package:equatable/equatable.dart';
import 'package:vidhai/core/bloc/auth_status.dart';

class AuthState extends Equatable {
  final AuthStatus status;
  final String? name;
  final String? errorMessage;

  const AuthState({
    required this.status,
    this.name,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? name,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      name: name ?? this.name,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, name, errorMessage];
}

class AuthInitial extends AuthState {
  const AuthInitial() : super(status: AuthStatus.uninitialized);
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({
    required String name,
  }) : super(status: AuthStatus.authenticated, name: name);
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated() : super(status: AuthStatus.unauthenticated);
}

class GoogleSignInSuccess extends AuthState {
  final String email;
  final String? photoUrl;
  final bool resumeToMain;

  const GoogleSignInSuccess({
    required String name,
    required this.email,
    this.photoUrl,
    required this.resumeToMain,
  }) : super(status: AuthStatus.authenticated, name: name);

  @override
  List<Object?> get props => [name, email, photoUrl, resumeToMain, status];
}

class AuthErrorState extends AuthState {
  const AuthErrorState({required String message})
      : super(status: AuthStatus.authError, errorMessage: message);
}

class AuthProfileSaved extends AuthState {
  final String domain;

  const AuthProfileSaved({required this.domain})
      : super(status: AuthStatus.authenticated, name: domain);

  @override
  List<Object?> get props => [domain, status];
}

class AuthFarmDataSaved extends AuthState {
  const AuthFarmDataSaved()
      : super(status: AuthStatus.authenticated, name: 'farms');

  @override
  List<Object?> get props => [status, name];
}
