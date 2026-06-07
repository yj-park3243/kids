import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/user.dart';
import '../../../providers/selected_child_provider.dart';
import '../../home/providers/home_provider.dart';
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
  final Ref _ref;

  AuthNotifier(this._repository, this._ref) : super(const AuthState());

  /// 로그아웃·탈퇴 시 이전 사용자에 종속된 캐시성 상태를 초기화한다.
  /// (selectedChild, 홈 목록 등 — 계정 전환 시 이전 데이터 잔존 방지)
  void _clearUserScopedState() {
    _ref.invalidate(selectedChildProvider);
    _ref.invalidate(homeProvider);
  }

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
    String? verificationPhotoUrl,
    String? napTime,
    List<String>? temperamentTags,
  }) async {
    final child = await _repository.addChild(
      nickname: nickname,
      birthYear: birthYear,
      birthMonth: birthMonth,
      gender: gender,
      photoUrl: photoUrl,
      verificationPhotoUrl: verificationPhotoUrl,
      napTime: napTime,
      temperamentTags: temperamentTags,
    );
    final user = state.user;
    if (user != null) {
      final next = [...(user.children ?? <Child>[]), child];
      state = state.copyWith(user: user.copyWith(children: next));
    }
    return child;
  }

  Future<Child> updateChild({
    required String childId,
    String? nickname,
    int? birthYear,
    int? birthMonth,
    String? gender,
    String? photoUrl,
  }) async {
    final child = await _repository.updateChild(
      childId: childId,
      nickname: nickname,
      birthYear: birthYear,
      birthMonth: birthMonth,
      gender: gender,
      photoUrl: photoUrl,
    );
    _replaceChildInState(childId, child);
    return child;
  }

  /// 기질 태그·낮잠 시간대 갱신. null/빈배열은 "비우기".
  Future<Child> updateChildTraits({
    required String childId,
    required String? napTime,
    required List<String> temperamentTags,
  }) async {
    final child = await _repository.updateChildTraits(
      childId: childId,
      napTime: napTime,
      temperamentTags: temperamentTags,
    );
    _replaceChildInState(childId, child);
    return child;
  }

  void _replaceChildInState(String childId, Child child) {
    final user = state.user;
    if (user != null && user.children != null) {
      final next = [
        for (final c in user.children!) c.id == childId ? child : c,
      ];
      state = state.copyWith(user: user.copyWith(children: next));
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
    _clearUserScopedState();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void setUnauthenticated() {
    _clearUserScopedState();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void updateUser(User user) {
    state = state.copyWith(user: user);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository, ref);
});
