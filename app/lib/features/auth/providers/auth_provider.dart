import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/user.dart';
import '../data/auth_repository.dart';

// Repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// Auth state
enum AuthStatus { initial, loading, authenticated, unauthenticated, profileSetup, childSetup }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(const AuthState());

  Future<void> checkAuth() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final user = await _repository.getMyProfile();
      if (!user.isProfileComplete) {
        state = state.copyWith(status: AuthStatus.profileSetup, user: user);
      } else if (user.children == null || user.children!.isEmpty) {
        state = state.copyWith(status: AuthStatus.childSetup, user: user);
      } else {
        state = state.copyWith(status: AuthStatus.authenticated, user: user);
      }
    } catch (e) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> emailLogin(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final result = await _repository.emailLogin(
        email: email,
        password: password,
      );
      if (result.isNewUser || !result.user.isProfileComplete) {
        state = state.copyWith(status: AuthStatus.profileSetup, user: result.user);
      } else {
        state = state.copyWith(status: AuthStatus.authenticated, user: result.user);
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: '로그인에 실패했습니다. 이메일과 비밀번호를 확인해 주세요.',
      );
    }
  }

  Future<void> emailRegister(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final result = await _repository.emailRegister(
        email: email,
        password: password,
      );
      state = state.copyWith(status: AuthStatus.profileSetup, user: result.user);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: '회원가입에 실패했습니다.',
      );
    }
  }

  Future<void> completeProfile({
    required String nickname,
    required String regionSido,
    required String regionSigungu,
    required String regionDong,
    String? profileImageUrl,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final user = await _repository.setupProfile(
        nickname: nickname,
        regionSido: regionSido,
        regionSigungu: regionSigungu,
        regionDong: regionDong,
        profileImageUrl: profileImageUrl,
      );
      state = state.copyWith(status: AuthStatus.childSetup, user: user);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.profileSetup,
        errorMessage: '프로필 설정에 실패했습니다.',
      );
    }
  }

  Future<void> addChild({
    required String nickname,
    required int birthYear,
    required int birthMonth,
    String? gender,
  }) async {
    try {
      await _repository.addChild(
        nickname: nickname,
        birthYear: birthYear,
        birthMonth: birthMonth,
        gender: gender,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> completeChildSetup() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final user = await _repository.getMyProfile();
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.childSetup,
        errorMessage: '오류가 발생했습니다.',
      );
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void setUnauthenticated() {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void updateUser(User user) {
    state = state.copyWith(user: user);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});
