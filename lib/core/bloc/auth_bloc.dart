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
  String _currentEmail = '';

  AuthBloc({
    required AuthRepository authRepository,
  })  : _authRepository = authRepository,
        super(const AuthState(status: AuthStatus.uninitialized)) {
    on<AuthLoginPressed>(_onLoginSubmit);
    on<AuthSignupPressed>(_onSignupSubmit);
    on<AuthCheckSessionPressed>(_onCheckSession);
    on<EmailEntrySubmitted>(_onEmailEntrySubmitted);
    on<EmailVerificationSubmitted>(_onEmailVerificationSubmitted);
    on<EmailVerificationCheck>(_onEmailVerificationCheck);
    on<EmailVerificationResent>(_onEmailVerificationResent);
    on<EmailSkipped>(_onEmailSkipped);
    on<ProfileSaved>(_onProfileSaved);
    on<FarmDataSaved>(_onFarmDataSaved);
  }

  bool get hasValidSession => _authRepository.hasValidSession;
  String get currentEmail => _currentEmail;

  String _friendlyMessage(Object error) {
    if (error is AppError) return error.message;
    return 'Something went wrong. Please try again.';
  }

  Future<void> _onLoginSubmit(
      AuthLoginPressed event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.uninitialized));
    try {
      await _authRepository.registerEmail(event.email);
      emit(AuthVerificationRequired(
        email: event.email,
        maskedEmail: _maskEmail(event.email),
      ));
    } catch (e) {
      emit(AuthErrorState(message: _friendlyMessage(e)));
    }
  }

  Future<void> _onSignupSubmit(
      AuthSignupPressed event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.uninitialized));
    try {
      await _authRepository.registerEmail(event.email);
      emit(AuthVerificationRequired(
        email: event.email,
        maskedEmail: _maskEmail(event.email),
      ));
    } catch (e) {
      emit(AuthErrorState(message: _friendlyMessage(e)));
    }
  }

  Future<void> _onCheckSession(
      AuthCheckSessionPressed event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.uninitialized));

    if (_authRepository.hasValidSession) {
      emit(const AuthAuthenticated(name: 'User'));
    } else if (_authRepository.isLoggedIn) {
      emit(const AuthUnverifiedEmail());
    } else {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onEmailEntrySubmitted(
      EmailEntrySubmitted event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.uninitialized));
    _currentEmail = event.email;

    try {
      final existingUser = await _authRepository.checkEmailExists(event.email);

      if (existingUser != null && existingUser['isEmailVerified'] == true) {
        await _authRepository.saveSession(
          email: event.email,
          displayName: existingUser['displayName'] ?? '',
          role: existingUser['role'] ?? '',
          isEmailVerified: true,
        );
        emit(AuthOnboardingRequired(
          email: event.email,
          userId: existingUser['uid'] ?? '',
        ));
        return;
      }

      await _authRepository.registerEmail(event.email);

      emit(AuthVerificationRequired(
        email: event.email,
        maskedEmail: _maskEmail(event.email),
      ));
    } catch (e) {
      emit(AuthErrorState(message: _friendlyMessage(e)));
    }
  }

  Future<void> _onEmailVerificationSubmitted(
      EmailVerificationSubmitted event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.uninitialized));

    try {
      final isVerified = await _authRepository.checkIfEmailVerified();

      if (isVerified) {
        await _authRepository.saveSession(
          email: _currentEmail,
          displayName: '',
          role: '',
          isEmailVerified: true,
        );
        emit(AuthOnboardingRequired(
          email: _currentEmail,
          userId: _authRepository.currentUser?.uid ?? '',
        ));
      } else {
        emit(AuthVerificationRequired(
          email: _currentEmail,
          maskedEmail: _maskEmail(_currentEmail),
        ));
      }
    } catch (e) {
      emit(AuthVerificationRequired(
        email: _currentEmail,
        maskedEmail: _maskEmail(_currentEmail),
      ));
    }
  }

  Future<void> _onEmailVerificationCheck(
      EmailVerificationCheck event, Emitter<AuthState> emit) async {
    try {
      final isVerified = await _authRepository.checkIfEmailVerified();

      if (isVerified) {
        await _authRepository.saveSession(
          email: _currentEmail,
          displayName: '',
          role: '',
          isEmailVerified: true,
        );
        emit(AuthOnboardingRequired(
          email: _currentEmail,
          userId: _authRepository.currentUser?.uid ?? '',
        ));
      }
      // If not verified yet, don't emit anything — keep current state
    } catch (_) {
      // Non-critical poll failure
    }
  }

  Future<void> _onEmailVerificationResent(
      EmailVerificationResent event, Emitter<AuthState> emit) async {
    try {
      await _authRepository.sendVerificationEmail();
      emit(AuthVerificationResentSuccess(
        email: _currentEmail,
        maskedEmail: _maskEmail(_currentEmail),
      ));
    } catch (e) {
      emit(AuthVerificationRequired(
        email: _currentEmail,
        maskedEmail: _maskEmail(_currentEmail),
        errorMessage: _friendlyMessage(e),
      ));
    }
  }

  Future<void> _onEmailSkipped(
      EmailSkipped event, Emitter<AuthState> emit) async {
    try {
      await _authRepository.saveGuestSession(email: _currentEmail);
      emit(const AuthGuestMode());
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
          email: _currentEmail,
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
    _currentEmail = '';
    emit(const AuthUnauthenticated());
  }

  String _maskEmail(String email) {
    if (email.length < 3) return email;
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return '${name[0]}***@$domain';
    return '${name.substring(0, 2)}***@$domain';
  }
}
