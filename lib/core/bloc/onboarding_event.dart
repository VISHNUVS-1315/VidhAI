import 'package:equatable/equatable.dart';

abstract class OnboardingEvent extends Equatable {
  const OnboardingEvent();

  @override
  List<Object> get props => [];
}

class OnboardingSubmitPressed extends OnboardingEvent {
  final String fullName;
  final int age;
  final String gender;
  final String address;
  final String role;
  final String userId;

  const OnboardingSubmitPressed({
    required this.fullName,
    required this.age,
    required this.gender,
    required this.address,
    required this.role,
    required this.userId,
  });

  @override
  List<Object> get props =>
      [fullName, age, gender, address, role, userId];
}