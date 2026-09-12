// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidhai/data/repositories/auth_repository.dart';
import 'package:vidhai/core/bloc/auth_event.dart';
import 'package:vidhai/core/bloc/auth_state.dart';
import 'package:vidhai/core/bloc/auth_status.dart';
import 'package:vidhai/core/error/app_error.dart';
import 'package:vidhai/data/models/farm_profile.dart';
import 'package:vidhai/services/data_service.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc({
    required AuthRepository authRepository,
  })  : _authRepository = authRepository,
        super(const AuthState(status: AuthStatus.uninitialized)) {
    on<AuthCheckSessionPressed>(_onCheckSession);
    on<GoogleSignInPressed>(_onGoogleSignInPressed);
    on<ProfileSaved>(_onProfileSaved);
    on<FarmDataSaved>(_onFarmDataSaved);
  }

  bool get hasValidSession => _authRepository.hasValidSession;

  String _friendlyMessage(Object error) {
    if (error is AppError) return error.message;
    return 'Something went wrong. Please try again.';
  }

  Future<void> _onCheckSession(
      AuthCheckSessionPressed event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.uninitialized));

    if (_authRepository.hasValidSession || _authRepository.isLoggedIn) {
      emit(const AuthAuthenticated(name: ''));
    } else {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onGoogleSignInPressed(
      GoogleSignInPressed event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.uninitialized));
    try {
      final result = await _authRepository.signInWithGoogle();
      emit(GoogleSignInSuccess(
        name: result.displayName,
        email: result.email,
        photoUrl: result.photoUrl,
        resumeToMain: result.onboardingComplete,
      ));
    } catch (e) {
      emit(AuthErrorState(message: _friendlyMessage(e)));
    }
  }

  Future<void> _onProfileSaved(
      ProfileSaved event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.uninitialized));
    try {
      final prefs = await SharedPreferences.getInstance();
      final domain = prefs.getString('selected_domain') ?? 'farmer';

      // Cache profile locally so it survives even if Firestore fails
      await prefs.setString('user_display_name', event.fullName);
      await prefs.setString('selected_domain', domain);

      try {
        await _authRepository.saveFullProfile(
          email: _authRepository.currentUser?.email ?? '',
          fullName: event.fullName,
          gender: event.gender,
          dateOfBirth: event.dateOfBirth,
          age: event.age,
          address: event.address,
          avatarUrl: event.avatarUrl,
          role: domain,
        );
      } catch (e) {
        // Firestore save may fail; local SP cache above is sufficient
      }

      if (domain == 'farmer') {
        emit(const AuthProfileSaved(domain: 'farmer'));
      } else {
        await prefs.setBool('onboarding_complete', true);
        await DataService().setOnboardingComplete(true);
        emit(const AuthProfileSaved(domain: 'consumer'));
      }
    } catch (e) {
      emit(AuthErrorState(message: _friendlyMessage(e)));
    }
  }

  Future<void> _onFarmDataSaved(
      FarmDataSaved event, Emitter<AuthState> emit) async {
    debugPrint('=== AuthBloc._onFarmDataSaved called ===');
    debugPrint('Farms count: ${event.farms.length}');
    emit(state.copyWith(status: AuthStatus.uninitialized));
    try {
      final farms = event.farms
          .map((m) => FarmProfile.fromMap(Map<String, dynamic>.from(m)))
          .toList();
      debugPrint('Deserialized ${farms.length} farms');
      try {
        await DataService().saveFarms(farms);
        debugPrint('saveFarms completed');
      } catch (e) {
        debugPrint('saveFarms failed: $e');
      }
      await DataService().setOnboardingComplete(true);
      debugPrint('setOnboardingComplete(true) done');
      debugPrint('Emitting AuthFarmDataSaved...');
      emit(const AuthFarmDataSaved());
      debugPrint('AuthFarmDataSaved emitted');
    } catch (e) {
      debugPrint('CRITICAL error in _onFarmDataSaved: $e');
      // Even if save fails, try to complete onboarding with local cache
      try {
        await DataService().setOnboardingComplete(true);
        emit(const AuthFarmDataSaved());
      } catch (_) {
        emit(AuthErrorState(message: _friendlyMessage(e)));
      }
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    emit(const AuthUnauthenticated());
  }
}
