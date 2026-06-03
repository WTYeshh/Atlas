import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/auth_repository.dart';
import '../repositories/settings_repository.dart';

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? userName;
  final String? userEmail;
  final String? userPhotoUrl;
  final String? errorMessage;

  AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.userName,
    this.userEmail,
    this.userPhotoUrl,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? userName,
    String? userEmail,
    String? userPhotoUrl,
    String? errorMessage,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return AuthNotifier(authRepo);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepo;

  AuthNotifier(this._authRepo) : super(AuthState(isLoading: true)) {
    _init();
  }

  Future<void> _init() async {
    try {
      final settingsRepo = SettingsRepository();
      final syncEnabled = await settingsRepo.getExternalSyncEnabled();
      final profile = await _authRepo.getLocalProfile();

      if (!syncEnabled) {
        // If Google Sync is disabled, log in directly as offline user
        state = AuthState(
          isAuthenticated: true,
          isLoading: false,
          userName: profile['name'] ?? 'Offline User',
          userEmail: profile['email'] ?? 'No Google Account linked',
          userPhotoUrl: profile['photoUrl'],
        );
      } else if (profile['email'] != null) {
        state = AuthState(
          isAuthenticated: true,
          isLoading: false,
          userName: profile['name'],
          userEmail: profile['email'],
          userPhotoUrl: profile['photoUrl'],
        );
        // Try to silently refresh token in the background if possible
        _authRepo.checkCurrentUser();
      } else {
        final isLoggedIn = await _authRepo.checkCurrentUser();
        if (isLoggedIn) {
          final profile = await _authRepo.getLocalProfile();
          state = AuthState(
            isAuthenticated: true,
            isLoading: false,
            userName: profile['name'],
            userEmail: profile['email'],
            userPhotoUrl: profile['photoUrl'],
          );
        } else {
          state = AuthState(isAuthenticated: false, isLoading: false);
        }
      }
    } catch (e) {
      print('AuthNotifier init error: $e');
      state = AuthState(isAuthenticated: false, isLoading: false);
    }
  }

  Future<void> useOfflineMode() async {
    state = state.copyWith(isLoading: true);
    final settingsRepo = SettingsRepository();
    await settingsRepo.saveExternalSyncEnabled(false);
    state = AuthState(
      isAuthenticated: true,
      isLoading: false,
      userName: 'Offline User',
      userEmail: 'No Google Account linked',
    );
  }

  Future<void> signIn() async {
    state = state.copyWith(isLoading: true);
    final success = await _authRepo.signIn();
    if (success) {
      final profile = await _authRepo.getLocalProfile();
      state = AuthState(
        isAuthenticated: true,
        isLoading: false,
        userName: profile['name'],
        userEmail: profile['email'],
        userPhotoUrl: profile['photoUrl'],
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Google Sign-in failed. Please try again.',
      );
    }
  }

  Future<bool> signInAfterToggle() async {
    state = state.copyWith(isLoading: true);
    final success = await _authRepo.signIn();
    if (success) {
      final profile = await _authRepo.getLocalProfile();
      state = AuthState(
        isAuthenticated: true,
        isLoading: false,
        userName: profile['name'],
        userEmail: profile['email'],
        userPhotoUrl: profile['photoUrl'],
      );
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Google Sign-in failed. Please try again.',
      );
      return false;
    }
  }

  Future<void> refreshProfile() async {
    final profile = await _authRepo.getLocalProfile();
    if (profile['email'] != null) {
      state = AuthState(
        isAuthenticated: true,
        isLoading: false,
        userName: profile['name'],
        userEmail: profile['email'],
        userPhotoUrl: profile['photoUrl'],
      );
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    await _authRepo.signOut();
    final settingsRepo = SettingsRepository();
    // Reset external sync to default (true) so they can login/re-select on next start
    await settingsRepo.saveExternalSyncEnabled(true);
    state = AuthState(isAuthenticated: false, isLoading: false);
  }
}
