import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_error.dart';
import '../../../models/user.dart';
import '../../../providers/selected_child_provider.dart';
import '../../home/providers/dashboard_provider.dart';
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
  profileSetup,
  childSetup,
  // 토큰은 있는데 서버에 닿지 못함(오프라인/5xx). 로그인 화면으로 튕기지 않고 재시도.
  unreachable,
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
    // 홈 대시보드 데이터도 유저 스코프 — 안 지우면 재로그인 후
    // 이전 세션의 목록/에러 상태를 그대로 물고 홈이 렌더된다.
    _ref.invalidate(joinedRoomsProvider);
    _ref.invalidate(dashboardProvider);
    _ref.invalidate(hasPastRoomsProvider);
  }

  Future<void> checkAuth() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final user = await _repository.getMyProfile();
      // 본인인증은 가입 관문이 아니라 모임 만들기·참여 시점의 게이트로 옮겼다
      // (phone_verification_gate.dart) — 여기서는 확인하지 않는다.
      if (!user.isProfileComplete) {
        state = state.copyWith(status: AuthStatus.profileSetup, user: user);
      } else if (user.children == null || user.children!.isEmpty) {
        state = state.copyWith(status: AuthStatus.childSetup, user: user);
      } else {
        state = state.copyWith(status: AuthStatus.authenticated, user: user);
      }
    } catch (e) {
      if (isUnreachableError(e)) {
        // 네트워크 문제는 로그아웃 사유가 아니다. 이미 로그인된 상태(앱 내 재조회)면
        // 그대로 두고, 콜드 스타트면 재시도 화면으로.
        state = state.copyWith(
          status: state.user != null ? AuthStatus.authenticated : AuthStatus.unreachable,
        );
        return;
      }
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  /// 로그인 응답의 user 에는 children 같은 관계가 빠져 있다(서버 sanitizeUser).
  /// 그대로 쓰면 앱 재시작 전까지 마이페이지 '우리 아이'·아이 기준 필터가 비어 보이므로
  /// 프로필을 한 번 더 받아 채운다. 실패하면 응답의 user 로 진행한다.
  Future<User> _hydrate(User fromLogin) async {
    try {
      return await _repository.getMyProfile();
    } catch (_) {
      return fromLogin;
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
      if (result.isNewUser || !result.user.isProfileComplete) {
        state =
            state.copyWith(status: AuthStatus.profileSetup, user: result.user);
      } else {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: await _hydrate(result.user),
        );
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
      if (result.isNewUser || !result.user.isProfileComplete) {
        state =
            state.copyWith(status: AuthStatus.profileSetup, user: result.user);
      } else {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: await _hydrate(result.user),
        );
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
      // 회원가입 직후 프로필 설정으로 — 본인인증은 모임 만들기·참여 때 받는다.
      state = state.copyWith(
        status: AuthStatus.profileSetup,
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
    String? regionSido,
    String? regionSigungu,
    String? regionDong,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final user = await _repository.setupProfile(
        nickname: nickname,
        profileImageUrl: profileImageUrl,
        parentGender: parentGender,
        isSingleParent: isSingleParent,
        regionSido: regionSido,
        regionSigungu: regionSigungu,
        regionDong: regionDong,
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

  Future<void> deleteChild(String childId) async {
    await _repository.deleteChild(childId);
    final user = state.user;
    if (user != null && user.children != null) {
      final next = [
        for (final c in user.children!)
          if (c.id != childId) c,
      ];
      state = state.copyWith(user: user.copyWith(children: next));
    }
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
