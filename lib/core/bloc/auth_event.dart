import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

class AuthLoginPressed extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginPressed({required this.email, required this.password});

  @override
  List<Object> get props => [email, password];
}

class AuthSignupPressed extends AuthEvent {
  final String email;
  final String password;
  final String displayName;

  const AuthSignupPressed({
    required this.email,
    required this.password,
    required this.displayName,
  });

  @override
  List<Object> get props => [email, password, displayName];
}

class AuthCheckSessionPressed extends AuthEvent {
  const AuthCheckSessionPressed();

  @override
  List<Object> get props => [];
}

class EmailEntrySubmitted extends AuthEvent {
  final String email;

  const EmailEntrySubmitted({required this.email});

  @override
  List<Object> get props => [email];
}

class EmailVerificationSubmitted extends AuthEvent {
  const EmailVerificationSubmitted();

  @override
  List<Object> get props => [];
}

class EmailVerificationCheck extends AuthEvent {
  const EmailVerificationCheck();

  @override
  List<Object> get props => [];
}

class EmailVerificationResent extends AuthEvent {
  const EmailVerificationResent();

  @override
  List<Object> get props => [];
}

class EmailSkipped extends AuthEvent {
  const EmailSkipped();

  @override
  List<Object> get props => [];
}

class ProfileSaved extends AuthEvent {
  final String fullName;
  final String gender;
  final DateTime? dateOfBirth;
  final int age;
  final Map<String, dynamic>? address;
  final String? avatarUrl;

  const ProfileSaved({
    required this.fullName,
    required this.gender,
    this.dateOfBirth,
    required this.age,
    this.address,
    this.avatarUrl,
  });

  @override
  List<Object> get props => [fullName, gender, age];
}

class FarmDataSaved extends AuthEvent {
  final List<Map<String, dynamic>> farms;

  const FarmDataSaved({required this.farms});

  @override
  List<Object> get props => [farms];
}
