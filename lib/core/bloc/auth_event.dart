import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

class AuthCheckSessionPressed extends AuthEvent {
  const AuthCheckSessionPressed();

  @override
  List<Object> get props => [];
}

class GoogleSignInPressed extends AuthEvent {
  const GoogleSignInPressed();

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
