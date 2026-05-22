import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/error/error_reporter.dart';
import '../../../models/user.dart';
import '../data/auth_repository.dart';

// Repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// Auth state
enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  phoneVerification,
  profileSetup,
  childSetup,
}

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
      if (!user.isPhoneVerified) {
        state = state.copyWith(status: AuthStatus.phoneVerification, user: user);
      } else if (!user.isProfileComplete) {
        state = state.copyWith(status: AuthStatus.profileSetup, user: user);
      } else if (user.children == null || user.children!.isEmpty) {
        state = state.copyWith(status: AuthStatus.childSetup, user: user);
      } else {
        state = state.copyWith(status: AuthStatus.authenticated, user: user);
      }
    } catch (e) {
      unawaited(ErrorReporter.instance.report(
        '[checkAuth-diag] getMyProfile failed: $e',
        screenName: 'checkAuth-diag',
      ));
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> socialLogin({
    required String provider,
    required String accessToken,
    String? idToken,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final result = await _repository.socialLogin(
        provider: provider,
        accessToken: accessToken,
        idToken: idToken,
      );
      if (!result.user.isPhoneVerified) {
        state = state.copyWith(
          status: AuthStatus.phoneVerification,
          user: result.user,
        );
      } else if (result.isNewUser || !result.user.isProfileComplete) {
        state =
            state.copyWith(status: AuthStatus.profileSetup, user: result.user);
      } else {
        state =
            state.copyWith(status: AuthStatus.authenticated, user: result.user);
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: '소셜 로그인에 실패했습니다.',
      );
    }
  }

  Future<void> emailLogin(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final result = await _repository.emailLogin(
        email: email,
        password: password,
      );
      if (!result.user.isPhoneVerified) {
        state = state.copyWith(
          status: AuthStatus.phoneVerification,
          user: result.user,
        );
      } else if (result.isNewUser || !result.user.isProfileComplete) {
        state =
            state.copyWith(status: AuthStatus.profileSetup, user: result.user);
      } else {
        state =
            state.copyWith(status: AuthStatus.authenticated, user: result.user);
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
      // 회원가입 직후 본인인증 단계로
      state = state.copyWith(
        status: AuthStatus.phoneVerification,
        user: result.user,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: '회원가입에 실패했습니다.',
      );
    }
  }

  Future<void> completeProfile({
    required String nickname,
    String? profileImageUrl,
    String? parentGender,
    bool? isSingleParent,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final user = await _repository.setupProfile(
        nickname: nickname,
        profileImageUrl: profileImageUrl,
        parentGender: parentGender,
        isSingleParent: isSingleParent,
      );
      state = state.copyWith(status: AuthStatus.childSetup, user: user);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.profileSetup,
        errorMessage: '프로필 설정에 실패했습니다.',
      );
    }
  }

  Future<Child> addChild({
    required String nickname,
    required int birthYear,
    required int birthMonth,
    String? gender,
    String? photoUrl,
  }) async {
    final child = await _repository.addChild(
      nickname: nickname,
      birthYear: birthYear,
      birthMonth: birthMonth,
      gender: gender,
      photoUrl: photoUrl,
    );
    final user = state.user;
    if (user != null) {
      final next = [...(user.children ?? <Child>[]), child];
      state = state.copyWith(user: user.copyWith(children: next));
    }
    return child;
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
